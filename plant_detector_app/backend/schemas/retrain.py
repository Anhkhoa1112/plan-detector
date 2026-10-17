from typing import Any
from pydantic import BaseModel, Field


class RetrainRequest(BaseModel):
    task_type: str = Field(
        default="ripeness",
        description="Loại tác vụ train: 'ripeness' | 'multi_angle' | 'part_fine_grained' | 'full'",
    )
    epochs: int = Field(default=20, ge=1, le=200, description="Số epoch huấn luyện")
    learning_rate: float = Field(default=0.005, ge=1e-5, le=0.1, description="Tốc độ học (learning rate)")
    batch_size: int = Field(default=16, ge=4, le=128)
    augment_angles: bool = Field(default=True, description="Kích hoạt data augmentation đa góc độ")
    dataset_dir: str | None = Field(default=None, description="Đường dẫn thư mục tập dữ liệu bổ sung")
    notes: str | None = Field(default=None, description="Ghi chú phiên huấn luyện")


class RetrainStatusResponse(BaseModel):
    task_id: str
    task_type: str
    status: str  # "idle" | "running" | "completed" | "failed"
    progress_percent: float = 0.0
    current_epoch: int = 0
    total_epochs: int = 0
    metrics: dict[str, Any] = {}
    started_at: str | None = None
    completed_at: str | None = None
    error_message: str | None = None
    model_artifact: str | None = None
    log_history: list[dict[str, Any]] = []


class RetrainHistoryResponse(BaseModel):
    total_tasks: int
    tasks: list[RetrainStatusResponse]
