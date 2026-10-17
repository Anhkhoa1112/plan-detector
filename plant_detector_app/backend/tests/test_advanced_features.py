import time
import numpy as np
from PIL import Image
from starlette.testclient import TestClient

from backend.main import app
from backend.services.model_service import ModelService
from backend.services.part_recognition_service import part_recognition_service
from backend.services.prediction_service import run_prediction
from backend.services.ripeness_service import ripeness_service
from backend.services.view_angle_service import view_angle_service

client = TestClient(app)


class _MockEmptyModelService:
    """Mô phỏng mô hình YOLO không bắt được bounding box toàn cảnh (khi ảnh chỉ là ảnh crop nhỏ)."""
    def __init__(self):
        self.names = {0: "Acacia", 2: "Banana-plant", 9: "Pine", 11: "peepal tree"}

    def predict(self, image, confidence, iou):
        class _EmptyResult:
            boxes = []
        return _EmptyResult()


def test_ripeness_analysis_for_fruit_and_non_fruit():
    # 1. Quả chín (màu vàng cam rực rỡ)
    ripe_img = Image.new("RGB", (200, 200), (240, 190, 20))
    res_ripe = ripeness_service.analyze_ripeness(ripe_img, "Banana-plant")
    assert res_ripe.status == "ripe"
    assert res_ripe.confidence > 0.65

    # 2. Quả xanh (màu xanh lục non)
    unripe_img = Image.new("RGB", (200, 200), (35, 175, 40))
    res_unripe = ripeness_service.analyze_ripeness(unripe_img, "Banana-plant")
    assert res_unripe.status == "unripe"
    assert res_unripe.confidence > 0.65

    # 3. Cây không ăn quả (Cây thông - Pine)
    pine_img = Image.new("RGB", (200, 200), (30, 90, 30))
    res_pine = ripeness_service.analyze_ripeness(pine_img, "Pine")
    assert res_pine.status == "not_applicable"
    assert "thân gỗ" in res_pine.visual_evidence.lower()


def test_view_angle_detection():
    # 1. Góc chính diện tiêu chuẩn
    frontal_img = Image.new("RGB", (300, 300), (60, 120, 60))
    res_frontal = view_angle_service.analyze_view_angle(frontal_img)
    assert res_frontal.angle in ["frontal", "top_down"]

    # 2. Góc từ dưới lên (Low-angle): Đỉnh sáng rực rỡ (bầu trời), đáy tối (gốc cây)
    low_angle_arr = np.zeros((300, 300, 3), dtype=np.uint8)
    low_angle_arr[0:100, :, :] = 220  # Nền trời sáng ở trên đỉnh
    low_angle_arr[100:200, :, :] = [40, 140, 40]  # Tán lá ở giữa
    low_angle_arr[200:300, :, :] = [80, 50, 25]  # Gốc cây ở đáy
    low_angle_img = Image.fromarray(low_angle_arr)

    res_low = view_angle_service.analyze_view_angle(low_angle_img)
    assert res_low.angle == "low_angle"
    assert "dưới lên" in res_low.description.lower()


def test_part_crop_recognition_when_yolo_finds_no_boxes():
    """
    Khi người dùng chỉ crop 1 chiếc lá hoặc quả, YOLO toàn cảnh trả về 0 box,
    nhưng hệ thống tự động kích hoạt PartRecognitionService để phân loại chính xác loài.
    """
    mock_model = _MockEmptyModelService()

    # Tạo ảnh crop lá cây có tỷ lệ xanh lục cao
    leaf_crop_img = Image.new("RGB", (320, 320), (35, 160, 45))
    resp = run_prediction(leaf_crop_img, mock_model, confidence=0.25)

    assert resp.success is True
    assert resp.status == "recognized"
    assert resp.is_part_crop is True
    assert len(resp.detections) == 1
    assert resp.detections[0].plant_part is not None
    assert resp.detections[0].plant_part.is_crop is True
    assert resp.detections[0].plant_part.part == "leaf"


def test_retrain_api_lifecycle():
    # Khởi động tác vụ train lại
    payload = {
        "task_type": "ripeness",
        "epochs": 5,
        "learning_rate": 0.005,
        "augment_angles": True,
    }
    start_resp = client.post("/retrain/start", json=payload)
    assert start_resp.status_code == 200
    data = start_resp.json()
    task_id = data["task_id"]
    assert data["status"] in ["running", "completed"]

    # Tra cứu trạng thái
    status_resp = client.get(f"/retrain/status/{task_id}")
    assert status_resp.status_code == 200
    status_data = status_resp.json()
    assert status_data["task_id"] == task_id

    # Đợi tác vụ hoàn thành với polling
    final_status = {}
    for _ in range(30):
        time.sleep(0.1)
        final_status = client.get(f"/retrain/status/{task_id}").json()
        if final_status.get("status") == "completed":
            break

    assert final_status["status"] == "completed"
    assert final_status["progress_percent"] == 100.0
    assert "train_accuracy" in final_status["metrics"]

    # Tra cứu lịch sử
    hist_resp = client.get("/retrain/history")
    assert hist_resp.status_code == 200
    hist_data = hist_resp.json()
    assert hist_data["total_tasks"] >= 1
