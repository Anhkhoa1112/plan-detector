from fastapi import APIRouter, File, HTTPException, Query, UploadFile

from backend.schemas.prediction import HealthResponse, PredictionResponse
from backend.services.image_service import ImageValidationError, read_image_upload
from backend.services.model_service import model_service
from backend.services.prediction_service import run_prediction


router = APIRouter()


@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    model_service.load()
    return HealthResponse(
        status="ok",
        model_loaded=model_service.model_loaded,
        model_path=str(model_service.model_path),
        load_error=model_service.load_error,
    )


@router.post("/predict", response_model=PredictionResponse)
async def predict(
    image: UploadFile = File(...),
    confidence: float = Query(default=0.25, ge=0.05, le=1.0),
    iou: float = Query(default=0.45, ge=0.1, le=0.9),
) -> PredictionResponse:
    try:
        pil_image = await read_image_upload(image)
        return run_prediction(
            image=pil_image,
            model_service=model_service,
            confidence=confidence,
            iou=iou,
        )
    except ImageValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
