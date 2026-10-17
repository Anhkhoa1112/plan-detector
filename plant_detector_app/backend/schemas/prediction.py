from pydantic import BaseModel, Field


class BoundingBox(BaseModel):
    x1: float
    y1: float
    x2: float
    y2: float


class RipenessInfo(BaseModel):
    status: str = "not_applicable"  # "ripe" | "unripe" | "not_applicable"
    confidence: float = 0.0
    visual_evidence: str = ""
    color_metrics: dict[str, float] = {}


class ViewAngleInfo(BaseModel):
    angle: str = "frontal"  # "frontal" | "tilted" | "low_angle" | "top_down"
    confidence: float = 0.0
    description: str = ""


class PlantPartInfo(BaseModel):
    part: str = "whole_plant"  # "whole_plant" | "leaf" | "fruit" | "bark" | "branch"
    is_crop: bool = False
    confidence: float = 0.0
    characteristics: str = ""


class Detection(BaseModel):
    class_id: int
    class_name: str
    name_vi: str | None = None
    confidence: float = Field(ge=0.0, le=1.0)
    bbox: BoundingBox
    ripeness: RipenessInfo | None = None
    view_angle: ViewAngleInfo | None = None
    plant_part: PlantPartInfo | None = None


class PredictionResponse(BaseModel):
    success: bool
    status: str = "recognized"  # "recognized" | "unknown" | "uncertain"
    image_width: int
    image_height: int
    detections: list[Detection]
    is_plant: bool = True
    is_part_crop: bool = False
    overall_view_angle: str = "frontal"
    message: str | None = None


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    model_path: str
    load_error: str | None = None
