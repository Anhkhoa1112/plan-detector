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
    def __init__(self, cls_id, conf, xyxy):
        self.cls = [_FakeTensor(cls_id)]
        self.conf = [_FakeTensor(conf)]
        self.xyxy = [_FakeXYXY(xyxy)]


class _FakeResult:
    def __init__(self, boxes):
        self.boxes = boxes


class _MockModelService:
    def __init__(self, boxes=None):
        self.boxes = boxes or []
        self.names = {0: "Acacia", 5: "Mango-Tree", 10: "lemon tree"}

    def predict(self, image, confidence, iou):
        return _FakeResult(self.boxes)


def test_recognized_status_when_confidence_exceeds_threshold():
    box = _FakeBox(cls_id=0, conf=0.85, xyxy=[50, 50, 300, 300])
    mock = _MockModelService([box])
    img = Image.new("RGB", (640, 640), (40, 140, 40))

    resp = run_prediction(img, mock, confidence=0.25, iou=0.45)
    assert resp.success is True
    assert resp.status == "recognized"
    assert resp.is_plant is True
    assert len(resp.detections) == 1
    assert resp.detections[0].class_name == "Acacia"


def test_uncertain_status_when_confidence_is_marginal():
    box = _FakeBox(cls_id=5, conf=0.35, xyxy=[50, 50, 300, 300])
    mock = _MockModelService([box])
    img = Image.new("RGB", (640, 640), (40, 140, 40))

    resp = run_prediction(img, mock, confidence=0.25, iou=0.45)
    assert resp.success is True
    assert resp.status == "uncertain"
    assert resp.is_plant is True
    assert "chưa đủ cao" in resp.message


def test_unknown_status_for_non_plant_object():
    mock = _MockModelService([])
    img = Image.new("RGB", (640, 640), (120, 110, 105))

    resp = run_prediction(img, mock, confidence=0.25, iou=0.45)
    assert resp.success is True
    assert resp.status == "unknown"
    assert resp.is_plant is False
    assert len(resp.detections) == 0
    assert "không phải là thực vật" in resp.message
