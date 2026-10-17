from fastapi.testclient import TestClient

from backend.main import app


def test_health_endpoint_returns_model_status():
    with TestClient(app) as client:
        response = client.get("/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert "model_loaded" in body
    assert "model_path" in body


def test_predict_rejects_invalid_image_content_type():
    with TestClient(app) as client:
        response = client.post(
            "/predict",
            files={"image": ("bad.txt", b"not an image", "text/plain")},
        )

    assert response.status_code == 400
