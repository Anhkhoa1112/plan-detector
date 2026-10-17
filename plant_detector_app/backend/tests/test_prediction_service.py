from PIL import Image

from backend.services.prediction_service import run_prediction


class _FakeTensor:
    def __init__(self, value):
        self._value = value

    def item(self):
        return self._value


class _FakeXYXY:
    def __init__(self, values):
        self._values = values

    def tolist(self):
        return self._values


class _FakeBox:
    cls = [_FakeTensor(5)]
    conf = [_FakeTensor(0.93)]
    xyxy = [_FakeXYXY([120, 80, 720, 650])]


class _FakeResult:
    boxes = [_FakeBox()]


class _FakeModelService:
    names = {5: "Mango-Tree"}

    def predict(self, image, confidence, iou):
        return _FakeResult()


def test_run_prediction_maps_yolo_result_to_api_schema():
    image = Image.new("RGB", (1920, 1080), "white")

    response = run_prediction(
        image=image,
        model_service=_FakeModelService(),
        confidence=0.25,
        iou=0.45,
    )

    assert response.success is True
    assert response.image_width == 1920
    assert response.image_height == 1080
    assert len(response.detections) == 1
    assert response.detections[0].class_id == 5
    assert response.detections[0].class_name == "Mango-Tree"
    assert response.detections[0].name_vi == "Cây Xoài"
    assert response.detections[0].confidence == 0.93
    assert response.detections[0].bbox.x1 == 120
