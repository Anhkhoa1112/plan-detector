import numpy as np
from PIL import Image

from backend.core.plants import CLASS_NAMES, PLANT_VI_NAMES
from backend.schemas.prediction import (
    BoundingBox,
    Detection,
    PlantPartInfo,
    PredictionResponse,
    RipenessInfo,
    ViewAngleInfo,
)
from backend.services.model_service import ModelService
from backend.services.part_recognition_service import part_recognition_service
from backend.services.ripeness_service import ripeness_service
from backend.services.view_angle_service import view_angle_service

# Class-specific calibrated thresholds derived from validation set PR-curve calibration
CALIBRATED_CLASS_THRESHOLDS: dict[int, float] = {
    0: 0.45,   # Acacia
    1: 0.50,   # Bamboo-shoots
    2: 0.40,   # Banana-plant
    3: 0.40,   # Banyan-Tree
    4: 0.40,   # Coconut-tree
    5: 0.50,   # Mango-Tree
    6: 0.40,   # Neem-Tree
    7: 0.40,   # Palm-tree
    8: 0.45,   # Papaya-Tree
    9: 0.45,   # Pine
    10: 0.55,  # lemon tree (prevents false alarms on indoor clutter)
    11: 0.50,  # peepal tree
}


def calculate_plant_features(image: Image.Image, box_coords=None) -> float:
    """Calculate ratio of pixels that exhibit plant/vegetation/bark characteristics."""
    try:
        arr = np.array(image.convert("RGB"))
        if box_coords is not None:
            x1, y1, x2, y2 = [int(v) for v in box_coords]
            x1, y1 = max(0, x1), max(0, y1)
            x2, y2 = min(arr.shape[1], x2), min(arr.shape[0], y2)
            if x2 > x1 and y2 > y1:
                arr = arr[y1:y2, x1:x2]

        if arr.size == 0:
            return 0.0

        r = arr[:, :, 0].astype(float)
        g = arr[:, :, 1].astype(float)
        b = arr[:, :, 2].astype(float)

        # Foliage green tones
        green_mask = (g > r * 0.90) & (g > b * 1.05) & (g > 35)
        # Tree trunk / bark organic earth tones
        bark_mask = (r > g) & (g > b) & (r > 40) & (r < 180) & ((r - b) > 18) & ((g - b) > 8)
        # Ripe fruits yellow/orange tones
        fruit_mask = (r > 120) & (g > 95) & (b < 110) & (r > b * 1.35)

        plant_ratio = float(np.mean(green_mask | bark_mask | fruit_mask))
        return plant_ratio
    except Exception:
        return 0.5


def run_prediction(
    image: Image.Image,
    model_service: ModelService,
    confidence: float = 0.25,
    iou: float = 0.45,
) -> PredictionResponse:
    # 1. Phân tích góc chụp tổng quan của bức ảnh
    view_angle_result = view_angle_service.analyze_view_angle(image)
    overall_view_angle = view_angle_result.angle

    # 2. Chạy mô hình YOLOv8 phát hiện đối tượng
    candidate_conf = min(confidence, 0.25)
    result = model_service.predict(image, confidence=candidate_conf, iou=iou)
    model_names = model_service.names or CLASS_NAMES

    overall_plant_ratio = calculate_plant_features(image)

    confirmed_detections: list[Detection] = []
    uncertain_detections: list[Detection] = []

    boxes = result.boxes
    if boxes is not None and len(boxes) > 0:
        for box in boxes:
            class_id = int(box.cls[0].item())
            class_name = model_names.get(class_id, f"Class {class_id}")
            x1, y1, x2, y2 = [round(float(value), 2) for value in box.xyxy[0].tolist()]
            conf_val = round(float(box.conf[0].item()), 6)

            # Check plant characteristics in the detected bounding box
            box_plant_ratio = calculate_plant_features(image, (x1, y1, x2, y2))

            # Filter indoor clutter false positives (e.g. lemon tree on desk)
            is_lemon_tree = (class_id == 10) or ("lemon" in class_name.lower())
            if is_lemon_tree and (box_plant_ratio < 0.035 and overall_plant_ratio < 0.035):
                continue
            if overall_plant_ratio < 0.02 and conf_val < 0.60:
                continue

            # Phân tích độ chín cho đối tượng được nhận diện
            ripeness = ripeness_service.analyze_ripeness(image, class_name, (x1, y1, x2, y2))

            # Phân tích bộ phận của cây trong bounding box
            try:
                sub_crop = image.crop((max(0, int(x1)), max(0, int(y1)), min(image.width, int(x2)), min(image.height, int(y2))))
                part_type, is_crop, part_desc = part_recognition_service.detect_plant_part(sub_crop)
            except Exception:
                part_type, is_crop, part_desc = "whole_plant", False, "Cây toàn cảnh"

            part_info = PlantPartInfo(
                part=part_type,
                is_crop=is_crop,
                confidence=0.88,
                characteristics=part_desc,
            )

            detection_obj = Detection(
                class_id=class_id,
                class_name=class_name,
                name_vi=PLANT_VI_NAMES.get(class_name),
                confidence=conf_val,
                bbox=BoundingBox(x1=x1, y1=y1, x2=x2, y2=y2),
                ripeness=ripeness,
                view_angle=view_angle_result,
                plant_part=part_info,
            )

            # Determine if this detection passes class-specific calibrated threshold
            class_th = CALIBRATED_CLASS_THRESHOLDS.get(class_id, 0.45)
            effective_th = max(class_th, confidence)

            if conf_val >= effective_th:
                confirmed_detections.append(detection_obj)
            elif conf_val >= 0.25:
                uncertain_detections.append(detection_obj)

    # 3. KÍCH HOẠT NHẬN DIỆN ẢNH CẮT NHỎ BỘ PHẬN (PART RECOGNITION FALLBACK)
    # Khi YOLO không tìm thấy cây toàn cảnh nhưng ảnh có tỷ lệ thực vật cao và là ảnh chụp cận cảnh bộ phận
    is_part_crop = False
    if len(confirmed_detections) == 0 and len(uncertain_detections) == 0 and overall_plant_ratio >= 0.20:
        part_type, is_crop, part_desc = part_recognition_service.detect_plant_part(image)
        if is_crop:
            part_det = part_recognition_service.match_species_from_crop(image, part_type)
            if part_det is not None:
                is_part_crop = True
                # Bổ sung thông tin độ chín và góc chụp
                part_det.ripeness = ripeness_service.analyze_ripeness(image, part_det.class_name, None)
                part_det.view_angle = view_angle_result
                confirmed_detections.append(part_det)

    # Multi-tier decision layer
    if len(confirmed_detections) > 0:
        # Recognized state
        return PredictionResponse(
            success=True,
            status="recognized",
            image_width=image.width,
            image_height=image.height,
            detections=confirmed_detections,
            is_plant=True,
            is_part_crop=is_part_crop or (confirmed_detections[0].plant_part.is_crop if confirmed_detections[0].plant_part else False),
            overall_view_angle=overall_view_angle,
            message=None,
        )
    elif len(uncertain_detections) > 0:
        # Uncertain state: Detected something resembling a plant class, but below threshold
        best_cand = max(uncertain_detections, key=lambda d: d.confidence)
        vi_name = best_cand.name_vi or best_cand.class_name
        pct = round(best_cand.confidence * 100, 1)
        return PredictionResponse(
            success=True,
            status="uncertain",
            image_width=image.width,
            image_height=image.height,
            detections=uncertain_detections,
            is_plant=True,
            is_part_crop=False,
            overall_view_angle=overall_view_angle,
            message=f"AI phát hiện dấu hiệu tương tự '{vi_name}' ({pct}%) nhưng độ tự tin chưa đủ cao. Hãy thử chụp ảnh rõ hơn hoặc đưa camera gần cây hơn.",
        )
    else:
        # Unknown state: Non-plant or unsupported species
        is_plant = overall_plant_ratio >= 0.03
        if not is_plant:
            msg = "Ảnh không phải là thực vật hoặc không tìm thấy đặc điểm thực vật. Vui lòng chụp rõ cây xanh, hoa lá hoặc thân cây."
        else:
            msg = "Loại cây này chưa nằm trong danh sách 12 loài cây mà AI được huấn luyện. Vui lòng thử lại với các loài được hỗ trợ."

        return PredictionResponse(
            success=True,
            status="unknown",
            image_width=image.width,
            image_height=image.height,
            detections=[],
            is_plant=is_plant,
            is_part_crop=False,
            overall_view_angle=overall_view_angle,
            message=msg,
        )
