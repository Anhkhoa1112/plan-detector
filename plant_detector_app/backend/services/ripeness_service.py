import os
from pathlib import Path
from typing import Any
import numpy as np
from PIL import Image
import torch
import torch.nn as nn

from backend.schemas.prediction import RipenessInfo

# Danh sách các loài cây ăn quả có thể phân loại độ chín quả
FRUIT_BEARING_CLASSES: set[str] = {
    "Banana-plant",
    "Mango-Tree",
    "Papaya-Tree",
    "lemon tree",
    "Coconut-tree",
}

DEFAULT_MODEL_DIR = Path(__file__).resolve().parent.parent.parent / "models"
RIPENESS_MODEL_PATH = DEFAULT_MODEL_DIR / "ripeness_classifier.pt"


class RipenessClassifierNet(nn.Module):
    """Mạng Neural Network gọn nhẹ (MLP) phân loại độ chín dựa trên vector đặc trưng màu sắc & quang phổ."""

    def __init__(self, input_dim: int = 12, hidden_dim: int = 32, num_classes: int = 2):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, hidden_dim),
            nn.BatchNorm1d(hidden_dim),
            nn.ReLU(),
            nn.Dropout(0.15),
            nn.Linear(hidden_dim, hidden_dim // 2),
            nn.ReLU(),
            nn.Linear(hidden_dim // 2, num_classes),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x)


class RipenessService:
    """Service chịu trách nhiệm phân tích, dự đoán và huấn luyện lại (retrain) trạng thái chín của cây."""

    def __init__(self, model_path: Path = RIPENESS_MODEL_PATH):
        self.model_path = model_path
        self.device = torch.device("cpu")
        self.model: RipenessClassifierNet | None = None
        self._load_or_init_model()

    def _load_or_init_model(self) -> None:
        """Tải mô hình nếu đã có checkpoint hoặc khởi tạo mô hình mới."""
        net = RipenessClassifierNet(input_dim=12, hidden_dim=32, num_classes=2)
        if self.model_path.exists():
            try:
                state_dict = torch.load(self.model_path, map_location=self.device)
                net.load_state_dict(state_dict)
                net.eval()
                self.model = net
                return
            except Exception:
                pass
        # Khởi tạo mô hình mặc định
        net.eval()
        self.model = net

    def extract_color_features(self, crop_arr: np.ndarray) -> np.ndarray:
        """
        Trích xuất 12 chỉ số đặc trưng quang học (Color spaces RGB, HSV, Lab):
        [0]: Mean Red
        [1]: Mean Green
        [2]: Mean Blue
        [3]: Red/Green ratio
        [4]: Yellow index: (R + G) / (2 * B + 1e-5)
        [5]: Green index: (2 * G - R - B) / (2 * G + R + B + 1e-5)
        [6]: Mean Hue (từ HSV)
        [7]: Mean Saturation (từ HSV)
        [8]: Mean Value / Lightness
        [9]: Tỷ lệ pixel chín (Yellow/Orange/Red dominance)
        [10]: Tỷ lệ pixel chưa chín (Deep Green dominance)
        [11]: Phương sai độ rực màu (color variance)
        """
        if crop_arr.size == 0:
            return np.zeros(12, dtype=np.float32)

        arr = crop_arr.astype(np.float32)
        h, w, _ = arr.shape
        r = arr[:, :, 0]
        g = arr[:, :, 1]
        b = arr[:, :, 2]

        r_mean = float(np.mean(r)) / 255.0
        g_mean = float(np.mean(g)) / 255.0
        b_mean = float(np.mean(b)) / 255.0

        rg_ratio = float(np.mean((r + 1e-5) / (g + 1e-5)))
        yellow_idx = float(np.mean((r + g + 1e-5) / (2.0 * b + 1.0)))

        # Normalized Difference Vegetative Index proxy
        green_idx = float(np.mean((2.0 * g - r - b) / (2.0 * g + r + b + 1e-5)))

        # Chuyển đổi sang HSV đơn giản
        max_c = np.maximum(np.maximum(r, g), b)
        min_c = np.minimum(np.minimum(r, g), b)
        delta = max_c - min_c + 1e-5

        # Saturation & Value
        sat = np.where(max_c == 0, 0, delta / (max_c + 1e-5))
        val = max_c / 255.0

        sat_mean = float(np.mean(sat))
        val_mean = float(np.mean(val))

        # Hue
        hue = np.zeros_like(max_c)
        mask_r = (max_c == r) & (delta > 0)
        mask_g = (max_c == g) & (delta > 0)
        mask_b = (max_c == b) & (delta > 0)

        hue[mask_r] = 60.0 * (((g[mask_r] - b[mask_r]) / delta[mask_r]) % 6)
        hue[mask_g] = 60.0 * (((b[mask_g] - r[mask_g]) / delta[mask_g]) + 2)
        hue[mask_b] = 60.0 * (((r[mask_b] - g[mask_b]) / delta[mask_b]) + 4)
        hue_mean = float(np.mean(hue)) / 360.0

        # Ripe mask: Vàng cam đỏ (Hue trong khoảng 15° - 65° hoặc > 340°, hoặc r > g và r > 100)
        ripe_mask = ((hue >= 15) & (hue <= 65) & (sat > 0.25)) | ((r > g * 1.1) & (r > 90) & (b < 120))
        ripe_ratio = float(np.mean(ripe_mask))

        # Unripe mask: Xanh lục tươi (Hue 70° - 160°, g > r và g > b)
        unripe_mask = ((hue >= 70) & (hue <= 160) & (sat > 0.20)) | ((g > r * 1.1) & (g > b * 1.05))
        unripe_ratio = float(np.mean(unripe_mask))

        color_var = float(np.std(val))

        features = np.array([
            r_mean, g_mean, b_mean, rg_ratio, yellow_idx, green_idx,
            hue_mean, sat_mean, val_mean, ripe_ratio, unripe_ratio, color_var
        ], dtype=np.float32)

        return features

    def analyze_ripeness(
        self,
        image: Image.Image,
        class_name: str,
        bbox_coords: tuple[float, float, float, float] | None = None,
    ) -> RipenessInfo:
        """
        Phân tích trạng thái chín cho vùng cây hoặc quả được phát hiện.
        Trả về RipenessInfo với status: 'ripe', 'unripe' hoặc 'not_applicable'.
        """
        # Nếu loài cây không phải cây ăn quả hoặc không có đặc tính phân loại chín
        is_fruit_bearing = any(f.lower() in class_name.lower() for f in FRUIT_BEARING_CLASSES)
        if not is_fruit_bearing:
            return RipenessInfo(
                status="not_applicable",
                confidence=1.0,
                visual_evidence="Loài cây thân gỗ/cảnh quan không phân loại trạng thái quả chín.",
                color_metrics={},
            )

        # Trích xuất vùng ảnh (bounding box crop)
        img_arr = np.array(image.convert("RGB"))
        if bbox_coords is not None:
            x1, y1, x2, y2 = [int(v) for v in bbox_coords]
            x1, y1 = max(0, x1), max(0, y1)
            x2, y2 = min(img_arr.shape[1], x2), min(img_arr.shape[0], y2)
            if x2 > x1 and y2 > y1:
                crop = img_arr[y1:y2, x1:x2]
            else:
                crop = img_arr
        else:
            crop = img_arr

        feats = self.extract_color_features(crop)
        metrics = {
            "red_mean": round(float(feats[0]), 3),
            "green_mean": round(float(feats[1]), 3),
            "blue_mean": round(float(feats[2]), 3),
            "yellow_index": round(float(feats[4]), 3),
            "green_index": round(float(feats[5]), 3),
            "ripe_ratio": round(float(feats[9]), 3),
            "unripe_ratio": round(float(feats[10]), 3),
        }

        # 1. Dự đoán qua Mạng Neural Network
        nn_confidence = 0.5
        nn_pred_idx = 0  # 0: unripe, 1: ripe
        if self.model is not None:
            try:
                self.model.eval()
                with torch.no_grad():
                    inp = torch.from_numpy(feats).unsqueeze(0).to(self.device)
                    logits = self.model(inp)
                    probs = torch.softmax(logits, dim=1).squeeze(0).cpu().numpy()
                    nn_pred_idx = int(np.argmax(probs))
                    nn_confidence = float(probs[nn_pred_idx])
            except Exception:
                pass

        # 2. Heuristic quang học theo từng loài để đảm bảo độ chính xác tối đa
        ripe_score = feats[9] * 1.5 + (feats[4] - 1.0) * 0.5 + (1.0 - feats[10]) * 0.3
        unripe_score = feats[10] * 1.5 + feats[5] * 0.8 + (1.0 - feats[9]) * 0.3

        # Điều chỉnh theo loài
        c_lower = class_name.lower()
        if "banana" in c_lower:
            # Chuối chín: sắc vàng vàng-nâu nổi trội
            is_ripe = (feats[9] > 0.18) or (feats[4] > 1.35 and feats[0] > feats[1] * 0.85)
            evidence = "Quả chuối vỏ vàng chuyển màu chín, đốm mật tự nhiên" if is_ripe else "Nải chuối còn vỏ xanh non, chưa chín"
        elif "mango" in c_lower:
            # Xoài chín: màu vàng cam má đỏ
            is_ripe = (feats[9] > 0.15) or (feats[0] > 0.40 and feats[4] > 1.25)
            evidence = "Xoài vỏ ngả vàng ươm/cam đậm đạt độ chín thu hoạch" if is_ripe else "Xoài vỏ xanh đậm giòn, còn non"
        elif "papaya" in c_lower:
            # Đu đủ: vàng cam
            is_ripe = (feats[9] > 0.14) or (feats[0] > 0.45 and feats[1] > 0.35)
            evidence = "Đu đủ chín vỏ vàng cam rực rỡ, thịt quả mềm ngọt" if is_ripe else "Đu đủ quả xanh đặc trưng, chưa chín"
        elif "lemon" in c_lower:
            # Chanh: vàng (chanh tây) hoặc xanh sáng căng mọng
            is_ripe = (feats[9] > 0.20) or (feats[4] > 1.40)
            evidence = "Chanh chín vỏ vàng mọng nước" if is_ripe else "Chanh vỏ xanh tươi đặc trưng"
        elif "coconut" in c_lower:
            # Dừa: khô nâu vs dừa xiêm xanh
            is_ripe = (feats[0] > feats[1] * 1.05 and feats[2] < 0.35) or (feats[9] > 0.25)
            evidence = "Dừa già/khô vỏ nâu sẫm cùi dày" if is_ripe else "Dừa non vỏ xanh mướt nhiều nước"
        else:
            is_ripe = (ripe_score > unripe_score) or (nn_pred_idx == 1 and nn_confidence > 0.6)
            evidence = "Đặc tính màu sắc cho thấy quả đã chín" if is_ripe else "Đặc tính màu xanh cho thấy cây/quả chưa chín"

        status = "ripe" if is_ripe else "unripe"
        confidence_val = round(min(0.98, max(0.68, float(0.5 + abs(ripe_score - unripe_score) * 0.4 + (nn_confidence - 0.5) * 0.3))), 4)

        return RipenessInfo(
            status=status,
            confidence=confidence_val,
            visual_evidence=evidence,
            color_metrics=metrics,
        )

    def train_ripeness_model(
        self,
        samples: list[tuple[np.ndarray, int]],  # (features_12d, label: 0=unripe, 1=ripe)
        epochs: int = 25,
        lr: float = 0.005,
        save_model: bool = True,
    ) -> dict[str, Any]:
        """Huấn luyện lại (Retrain) mạng nơ-ron phân loại độ chín với dữ liệu mẫu mới."""
        if len(samples) < 10:
            return {"success": False, "error": "Cần tối thiểu 10 mẫu dữ liệu để train lại."}

        X = np.stack([s[0] for s in samples]).astype(np.float32)
        y = np.array([s[1] for s in samples], dtype=np.int64)

        x_tensor = torch.from_numpy(X).to(self.device)
        y_tensor = torch.from_numpy(y).to(self.device)

        net = RipenessClassifierNet(input_dim=12, hidden_dim=32, num_classes=2).to(self.device)
        criterion = nn.CrossEntropyLoss()
        optimizer = torch.optim.Adam(net.parameters(), lr=lr, weight_decay=1e-4)

        net.train()
        history: list[dict[str, float]] = []

        for epoch in range(1, epochs + 1):
            optimizer.zero_grad()
            outputs = net(x_tensor)
            loss = criterion(outputs, y_tensor)
            loss.backward()
            optimizer.step()

            # Tính accuracy
            with torch.no_grad():
                preds = torch.argmax(outputs, dim=1)
                correct = (preds == y_tensor).sum().item()
                acc = correct / len(y)

            history.append({
                "epoch": epoch,
                "loss": round(float(loss.item()), 4),
                "accuracy": round(acc, 4),
            })

        net.eval()
        self.model = net

        if save_model:
            os.makedirs(self.model_path.parent, exist_ok=True)
            torch.save(net.state_dict(), self.model_path)

        final_loss = history[-1]["loss"]
        final_acc = history[-1]["accuracy"]

        return {
            "success": True,
            "epochs_trained": epochs,
            "final_loss": final_loss,
            "final_accuracy": final_acc,
            "history": history,
            "model_path": str(self.model_path),
        }


# Singleton instance
ripeness_service = RipenessService()
