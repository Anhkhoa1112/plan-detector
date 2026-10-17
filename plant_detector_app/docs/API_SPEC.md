# API Specification

## Run

```powershell
.\venv\Scripts\python.exe -m uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

## GET `/health`

Response:

```json
{
  "status": "ok",
  "model_loaded": true,
  "model_path": "D:\\plant_detector_app\\plant_detector_app\\models\\production\\best.pt",
  "load_error": null
}
```

## POST `/predict`

Multipart form input:

- `image`: JPEG or PNG file
- `confidence`: optional query parameter, default `0.25`, range `0.05..1.0`
- `iou`: optional query parameter, default `0.45`, range `0.1..0.9`

Example:

```powershell
curl.exe -X POST "http://127.0.0.1:8000/predict?confidence=0.25&iou=0.45" -F "image=@sample_images/cay_mau.jpg"
```

For Android physical-device testing, replace `127.0.0.1` with the laptop LAN IPv4 address, for example `http://192.168.100.245:8000`.

Response:

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
      "confidence": 0.3267,
      "bbox": {
        "x1": 532.0,
        "y1": 22.7,
        "x2": 1200.0,
        "y2": 849.5
      }
    }
  ]
}
```

If no objects meet the threshold:

```json
{
  "success": true,
  "image_width": 1200,
  "image_height": 896,
  "detections": []
}
```

## Errors

- `400`: invalid content type, empty file, corrupted image, or image larger than 10 MB.
- `422`: invalid query parameter range.
- `503`: model unavailable or failed to load.
