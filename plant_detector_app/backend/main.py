from contextlib import asynccontextmanager

from fastapi import FastAPI

from backend.api.predict import router as prediction_router
from backend.api.retrain import router as retrain_router
from backend.services.model_service import model_service


@asynccontextmanager
async def lifespan(app: FastAPI):
    model_service.load()
    yield


app = FastAPI(
    title="Plant AI Detection API",
    version="1.0.0",
    description="FastAPI server for YOLO-based plant detection.",
    lifespan=lifespan,
)

app.include_router(prediction_router)
app.include_router(retrain_router)

