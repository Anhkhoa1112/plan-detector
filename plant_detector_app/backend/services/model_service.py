from pathlib import Path
from threading import Lock
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MODEL_PATH = PROJECT_ROOT / "models" / "production" / "best.pt"
FALLBACK_MODEL_PATH = PROJECT_ROOT / "models" / "best.pt"


class ModelService:
    def __init__(self, model_path: Path | None = None) -> None:
        self.model_path = model_path or self._resolve_model_path()
        self._model: Any | None = None
        self._load_error: str | None = None
        self._lock = Lock()

    @staticmethod
    def _resolve_model_path() -> Path:
        if DEFAULT_MODEL_PATH.exists():
            return DEFAULT_MODEL_PATH
        return FALLBACK_MODEL_PATH

    @property
    def model_loaded(self) -> bool:
        return self._model is not None

    @property
    def load_error(self) -> str | None:
        return self._load_error

    def load(self) -> None:
        if self._model is not None:
            return

        with self._lock:
            if self._model is not None:
                return
            try:
                from ultralytics import YOLO

                if not self.model_path.exists():
                    raise FileNotFoundError(f"Model not found: {self.model_path}")
                self._model = YOLO(str(self.model_path))
                self._load_error = None
            except Exception as exc:
                self._model = None
                self._load_error = str(exc)

    def predict(self, image, confidence: float, iou: float):
        self.load()
        if self._model is None:
            raise RuntimeError(self._load_error or "Model is not loaded.")
        return self._model.predict(
            source=image,
            conf=confidence,
            iou=iou,
            verbose=False,
        )[0]

    @property
    def names(self) -> dict[int, str]:
        if self._model is None:
            return {}
        return dict(self._model.names or {})


model_service = ModelService()
