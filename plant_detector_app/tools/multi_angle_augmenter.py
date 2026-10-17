import argparse
from pathlib import Path
import numpy as np
from PIL import Image, ImageEnhance


class MultiAngleAugmenter:
    """Công cụ mở rộng tập dữ liệu ảnh cây với đa dạng góc chụp: nghiêng, dưới lên, trên xuống."""

    def __init__(self, output_dir: Path | None = None):
        self.output_dir = output_dir

    def augment_tilt(self, image: Image.Image, angle_deg: float) -> Image.Image:
        """Tạo ảnh góc nghiêng chéo (Tilted angle)."""
        return image.rotate(angle_deg, resample=Image.Resampling.BICUBIC, expand=False)

    def augment_low_angle(self, image: Image.Image, intensity: float = 0.3) -> Image.Image:
        """
        Mô phỏng góc chụp từ dưới lên (Low-angle view / Worm's eye view):
        - Biến đổi phối cảnh hình thang: Đáy ảnh mở rộng, đỉnh ảnh thu hẹp
        - Tăng độ sáng phần đỉnh để mô phỏng ánh sáng nền trời
        """
        w, h = image.size
        dx = int(w * intensity * 0.5)

        # 4 điểm nguồn (hình chữ nhật)
        src = [(0, 0), (w, 0), (w, h), (0, h)]
        # 4 điểm đích (hình thang: ngọn hẹp lại, đáy giữ nguyên)
        dst = [(dx, 0), (w - dx, 0), (w, h), (0, h)]

        coeffs = self._find_perspective_coeffs(dst, src)
        warped = image.transform((w, h), Image.Transform.PERSPECTIVE, coeffs, Image.Resampling.BICUBIC)

        # Giả lập ánh sáng bầu trời phía trên
        enhancer = ImageEnhance.Brightness(warped)
        brightened = enhancer.enhance(1.15)
        return brightened

    def augment_top_down(self, image: Image.Image, intensity: float = 0.25) -> Image.Image:
        """
        Mô phỏng góc chụp từ trên nhìn xuống (Top-down view / Bird's eye view):
        - Đỉnh ảnh mở rộng, đáy ảnh thu hẹp
        """
        w, h = image.size
        dx = int(w * intensity * 0.4)

        src = [(0, 0), (w, 0), (w, h), (0, h)]
        dst = [(0, 0), (w, 0), (w - dx, h), (dx, h)]

        coeffs = self._find_perspective_coeffs(dst, src)
        return image.transform((w, h), Image.Transform.PERSPECTIVE, coeffs, Image.Resampling.BICUBIC)

    def generate_all_angles(self, image: Image.Image) -> dict[str, Image.Image]:
        """Tạo toàn bộ bộ sưu tập ảnh đa góc độ từ 1 ảnh gốc."""
        return {
            "frontal": image,
            "tilted_left_15": self.augment_tilt(image, 15.0),
            "tilted_right_15": self.augment_tilt(image, -15.0),
            "tilted_left_25": self.augment_tilt(image, 25.0),
            "low_angle_moderate": self.augment_low_angle(image, 0.25),
            "low_angle_steep": self.augment_low_angle(image, 0.40),
            "top_down": self.augment_top_down(image, 0.30),
        }

    def _find_perspective_coeffs(self, pa: list[tuple[int, int]], pb: list[tuple[int, int]]) -> list[float]:
        """Tính ma trận biến đổi phối cảnh 8 tham số cho PIL transform."""
        matrix = []
        for p1, p2 in zip(pa, pb):
            matrix.append([p1[0], p1[1], 1, 0, 0, 0, -p2[0] * p1[0], -p2[0] * p1[1]])
            matrix.append([0, 0, 0, p1[0], p1[1], 1, -p2[1] * p1[0], -p2[1] * p1[1]])

        A = np.matrix(matrix, dtype=float)
        B = np.array(pb).reshape(8)

        res = np.dot(np.linalg.pinv(A), B)
        return np.array(res).reshape(8).tolist()


def main():
    parser = argparse.ArgumentParser(description="Multi-Angle Dataset Augmentation Tool")
    parser.add_argument("--image", type=str, help="Đường dẫn ảnh nguồn để augment")
    parser.add_argument("--outdir", type=str, default="sample_images/augmented_angles", help="Thư mục xuất ảnh")
    args = parser.parse_args()

    augmenter = MultiAngleAugmenter()
    if args.image and Path(args.image).exists():
        img = Image.open(args.image).convert("RGB")
        angles = augmenter.generate_all_angles(img)
        out_path = Path(args.outdir)
        out_path.mkdir(parents=True, exist_ok=True)
        for name, aug_img in angles.items():
            save_file = out_path / f"{Path(args.image).stem}_{name}.jpg"
            aug_img.save(save_file, "JPEG", quality=90)
            print(f"Đã lưu ảnh góc {name} -> {save_file}")
    else:
        print("Tạo thử nghiệm với ảnh mẫu 640x640...")
        test_img = Image.new("RGB", (640, 640), (45, 135, 45))
        angles = augmenter.generate_all_angles(test_img)
        print(f"Đã sinh thành công {len(angles)} góc chụp phối cảnh đa dạng.")


if __name__ == "__main__":
    main()
