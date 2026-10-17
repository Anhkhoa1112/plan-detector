# Test Report

Date: 2026-10-05

## Planned Verification

- Python syntax/module import check.
- Backend unit tests.
- FastAPI `/health` smoke test.
- FastAPI `/predict` smoke test with `sample_images/cay_mau.jpg`.

## Results

PASS.

- `.\venv\Scripts\python.exe -m pip install -r requirements.txt`: completed after network approval.
- `.\venv\Scripts\python.exe -m pytest backend\tests -q`: `3 passed, 1 warning in 3.26s`.
- Backend import smoke test: loaded `Plant AI Detection API` with 5 routes.
- FastAPI `/predict` smoke test with `sample_images/cay_mau.jpg`: HTTP `200`, one real YOLO detection returned.
- Live server `/health` at `http://127.0.0.1:8000/health`: HTTP `200`, `model_loaded: true`.
- Live server `/predict` at `http://127.0.0.1:8000/predict`: HTTP `200`, one real YOLO detection returned.

Smoke-test response summary:

```json
{
  "success": true,
  "image_width": 1200,
  "image_height": 896,
  "detections": [
    {
      "class_id": 10,
      "class_name": "lemon tree",
      "name_vi": "Cây Chanh",
      "confidence": 0.326685,
      "bbox": {
        "x1": 532.01,
        "y1": 22.69,
        "x2": 1200.0,
        "y2": 849.46
      }
    }
  ]
}
```

Warning observed:

- `StarletteDeprecationWarning`: FastAPI TestClient reports that Starlette's current httpx integration is deprecated and recommends `httpx2`. It does not block tests.
- PowerShell displayed Vietnamese output with mojibake in one direct print, but escaped JSON confirmed the API response contains `C\u00e2y Chanh` correctly.

## Known Gaps

- No validation/test dataset, so AI quality metrics are not available.
- No Flutter app yet, so mobile UI, camera, gallery, and bounding-box rendering are not verified.
