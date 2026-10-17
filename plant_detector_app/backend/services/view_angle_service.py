import numpy as np
from PIL import Image

from backend.schemas.prediction import ViewAngleInfo


class ViewAngleService:
    """Service phân tích góc chụp của ảnh cây và thực hiện chuẩn hóa phối cảnh."""

    def analyze_view_angle(self, image: Image.Image) -> ViewAngleInfo:
        """
        Phân tích góc chụp ảnh:
        - 'frontal': Chụp chính diện ngang tầm mắt
        - 'low_angle': Chụp từ dưới lên (góc dưới, ngửa camera lên tán cây)
        - 'top_down': Chụp từ trên xuống (nhìn chúc xuống tán lá)
        - 'tilted': Chụp góc nghiêng / chéo
        """
        try:
            arr = np.array(image.convert("RGB"))
            h, w, _ = arr.shape
            if h < 10 or w < 10:
                return ViewAngleInfo(
                    angle="frontal",
                    confidence=0.85,
                    description="Góc chụp chuẩn ngang tầm mắt",
                )

            # Chia ảnh thành 3 phần theo chiều dọc: Đỉnh (Top), Giữa (Middle), Đáy (Bottom)
            third_h = h // 3
            top_part = arr[0:third_h, :, :]
            mid_part = arr[third_h : 2 * third_h, :, :]
            bot_part = arr[2 * third_h :, :, :]

            # Tính độ sáng và đặc trưng thực vật của từng phần
            def get_brightness(section: np.ndarray) -> float:
                return float(np.mean(section))

            def get_plant_density(section: np.ndarray) -> float:
                r = section[:, :, 0].astype(float)
                g = section[:, :, 1].astype(float)
                b = section[:, :, 2].astype(float)
                green_mask = (g > r * 0.92) & (g > b * 1.05) & (g > 35)
                bark_mask = (r > g) & (g > b) & (r > 40) & (r < 180) & ((r - b) > 18)
                return float(np.mean(green_mask | bark_mask))

            top_bright = get_brightness(top_part)
            bot_bright = get_brightness(bot_part)

            top_plant = get_plant_density(top_part)
            mid_plant = get_plant_density(mid_part)
            bot_plant = get_plant_density(bot_part)

            # Phân tích đường biên ngang/dọc (Sobel gradient proxy) để phát hiện độ xiên/nghiêng
            gray = np.mean(arr, axis=2)
            grad_x = np.abs(gray[:, 1:] - gray[:, :-1])
            grad_y = np.abs(gray[1:, :] - gray[:-1, :])

            # Tỷ lệ gradient x so với y (nếu có góc nghiêng đường chéo)
            mean_grad_x = float(np.mean(grad_x))
            mean_grad_y = float(np.mean(grad_y))

            # Phát hiện độ lệch trọng tâm ngang theo chiều dọc (Centroid skew)
            # Nếu thân cây chụp nghiêng, trọng tâm thực vật của đỉnh và đáy sẽ lệch nhau đáng kể
            def horizontal_plant_centroid(section: np.ndarray) -> float:
                r = section[:, :, 0].astype(float)
                g = section[:, :, 1].astype(float)
                b = section[:, :, 2].astype(float)
                mask = (g > r * 0.90) | ((r > g) & (r > 40))
                col_sums = np.sum(mask, axis=0)
                total = np.sum(col_sums)
                if total == 0:
                    return 0.5
                indices = np.arange(len(col_sums))
                return float(np.sum(indices * col_sums) / (total * len(col_sums)))

            top_centroid = horizontal_plant_centroid(top_part)
            bot_centroid = horizontal_plant_centroid(bot_part)
            centroid_tilt = abs(top_centroid - bot_centroid)

            # Quyết định góc chụp:
            # 1. Low angle (từ dưới lên):
            # - Đỉnh ảnh rất sáng (bầu trời ngược sáng: top_bright > bot_bright + 35)
            # - Hoặc mật độ cây ở đỉnh/giữa lớn (tán lá) vươn lên nền trời, phần dưới là gốc thân
            is_low_angle = (
                (top_bright > bot_bright + 30 and top_bright > 150)
                or (top_plant > 0.30 and bot_plant < 0.25 and top_bright > 130)
            )

            # 2. Top down (từ trên xuống):
            # - Toàn bộ ảnh phủ đầy tán lá thực vật (top_plant > 0.6 và mid_plant > 0.6)
            # - Không có nền trời sáng, độ sáng tương đối đồng đều
            is_top_down = (
                (top_plant > 0.55 and bot_plant > 0.55 and mid_plant > 0.6)
                and (top_bright < bot_bright + 15)
                and (top_bright < 160)
            )

            # 3. Tilted (góc nghiêng):
            # - Trọng tâm thực vật đỉnh và đáy lệch đáng kể (> 0.18 của chiều rộng)
            is_tilted = centroid_tilt > 0.20 or (mean_grad_x > mean_grad_y * 1.55)

            if is_low_angle:
                angle = "low_angle"
                confidence = round(min(0.96, max(0.72, float(0.65 + (top_bright - bot_bright) / 200.0))), 2)
                desc = "Góc chụp từ dưới lên (Low-angle view) hướng lên vòm tán cây và bầu trời."
            elif is_top_down:
                angle = "top_down"
                confidence = round(min(0.95, max(0.70, float(0.60 + mid_plant * 0.4))), 2)
                desc = "Góc chụp từ trên nhìn xuống (Top-down view) bao quát bề mặt tán lá."
            elif is_tilted:
                angle = "tilted"
                confidence = round(min(0.94, max(0.68, float(0.60 + centroid_tilt * 1.2))), 2)
                desc = "Góc chụp nghiêng / chéo (Tilted angle) thân và cành nghiêng so với phương thẳng đứng."
            else:
                angle = "frontal"
                confidence = 0.88
                desc = "Góc chụp chính diện ngang tầm mắt (Frontal eye-level view)."

            return ViewAngleInfo(
                angle=angle,
                confidence=confidence,
                description=desc,
            )

        except Exception:
            return ViewAngleInfo(
                angle="frontal",
                confidence=0.80,
                description="Góc chụp chính diện mặc định.",
            )

    def generate_multi_angle_variants(self, image: Image.Image) -> list[tuple[str, Image.Image]]:
        """
        Tạo các biến thể Test-Time Augmentation (TTA) cho ảnh khi cần kiểm tra đa góc độ:
        - frontal (gốc)
        - tilt_left (-15°)
        - tilt_right (+15°)
        - perspective_low (co dãn phối cảnh dưới lên)
        """
        variants = [("original", image)]
        try:
            w, h = image.size
            # Nghiêng trái nhẹ
            variants.append(("tilt_left", image.rotate(12, resample=Image.Resampling.BILINEAR)))
            # Nghiêng phải nhẹ
            variants.append(("tilt_right", image.rotate(-12, resample=Image.Resampling.BILINEAR)))
            # Lật gương ngang
            variants.append(("horizontal_flip", image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)))
        except Exception:
            pass
        return variants


# Singleton instance
view_angle_service = ViewAngleService()
