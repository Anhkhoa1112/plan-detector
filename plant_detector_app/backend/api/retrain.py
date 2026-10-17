from fastapi import APIRouter, HTTPException, Query

from backend.schemas.retrain import (
    RetrainHistoryResponse,
    RetrainRequest,
    RetrainStatusResponse,
)
from backend.services.retrain_service import retrain_service

router = APIRouter(prefix="/retrain", tags=["AI Retraining"])


@router.post("/start", response_model=RetrainStatusResponse)
def start_retrain(req: RetrainRequest) -> RetrainStatusResponse:
    """
    Gọi huấn luyện lại mô hình AI với các tham số cấu hình:
    - task_type: 'ripeness' | 'multi_angle' | 'part_fine_grained' | 'full'
    - epochs: số vòng huấn luyện
    - learning_rate: tốc độ học
    - augment_angles: tự động sinh dữ liệu đa góc độ
    """
    task_id = retrain_service.start_retrain_task(req)
    status = retrain_service.get_task_status(task_id)
    if status is None:
        raise HTTPException(status_code=500, detail="Không thể khởi tạo tiến trình huấn luyện.")
    return status


@router.get("/status/{task_id}", response_model=RetrainStatusResponse)
def get_retrain_status(task_id: str) -> RetrainStatusResponse:
    """Tra cứu trạng thái và tiến độ của tác vụ huấn luyện."""
    status = retrain_service.get_task_status(task_id)
    if status is None:
        raise HTTPException(status_code=404, detail=f"Không tìm thấy tác vụ với ID: {task_id}")
    return status


@router.get("/latest", response_model=RetrainStatusResponse)
def get_latest_retrain() -> RetrainStatusResponse:
    """Lấy thông tin và chỉ số đánh giá của phiên huấn luyện gần nhất."""
    latest = retrain_service.get_latest_task()
    if latest is None:
        raise HTTPException(status_code=404, detail="Chưa có tác vụ huấn luyện nào được thực thi.")
    return latest


@router.get("/history", response_model=RetrainHistoryResponse)
def get_retrain_history() -> RetrainHistoryResponse:
    """Lấy toàn bộ lịch sử các phiên huấn luyện lại mô hình AI."""
    tasks = retrain_service.get_all_tasks()
    return RetrainHistoryResponse(
        total_tasks=len(tasks),
        tasks=tasks,
    )
