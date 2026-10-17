"""
Script kiem tra toan ven bo du lieu (Dataset Validator) cho du an Plant AI Detector.

Cac hang muc kiem tra:
1. Anh thieu file label tuong ung.
2. Label thieu file anh tuong ung.
3. Anh bi loi / hong / khong the mo (Image corruption).
4. Label sai dinh dang (khong du 5 tham so).
5. Class ID ngoai pham vi [0, nc - 1].
6. Bounding box ngoai pham vi [0.0, 1.0] hoac kich thuoc <= 0.
7. Anh trung lap (Duplicate hash) va ro ri du lieu (Data leakage) giua cac tap train/val/test.
8. Thong ke phan bo so luong anh va bounding box theo tung class.

Su dung:
    python tools/validate_dataset.py [--data dataset/data.yaml]
"""

import argparse
import hashlib
import os
import sys
from collections import defaultdict
from pathlib import Path
from PIL import Image

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATA_YAML = PROJECT_ROOT / "dataset" / "data.yaml"
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def parse_args():
    parser = argparse.ArgumentParser(description="Kiem tra tinh toan ven cua tap du lieu YOLO.")
    parser.add_argument(
        "--data",
        type=str,
        default=str(DEFAULT_DATA_YAML),
        help="Duong dan toi file data.yaml",
    )
    return parser.parse_args()


def load_yaml(yaml_path: Path) -> dict:
    import yaml
    with open(yaml_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def to_long_path(p: Path) -> Path:
    s = str(p.resolve())
    if os.name == "nt" and not s.startswith("\\\\?\\"):
        return Path("\\\\?\\" + s)
    return p


def compute_image_hash(image_path: Path) -> str:
    h = hashlib.sha256()
    with open(to_long_path(image_path), "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def main():
    args = parse_args()
    yaml_path = Path(args.data)

    if not yaml_path.exists():
        print(f"[LOI] Khong tim thay file cau hinh tai: {yaml_path}")
        sys.exit(1)

    print(f"============================================================")
    print(f"   KIEM TRA TINH TOAN VEN DU LIEU (DATASET VALIDATION)      ")
    print(f"============================================================")
    print(f"File cau hinh: {yaml_path}\n")

    cfg = load_yaml(yaml_path)
    dataset_root = Path(cfg.get("path", yaml_path.parent))

    nc = cfg.get("nc", 0)
    names = cfg.get("names", {})
    if isinstance(names, list):
        names = {i: n for i, n in enumerate(names)}
    elif isinstance(names, dict):
        names = {int(k): v for k, v in names.items()}

    print(f"So luong class khai bao (nc): {nc}")
    print(f"Danh sach class: {', '.join([f'{k}:{v}' for k, v in names.items()])}\n")

    splits = ["train", "val", "test"]
    split_paths = {}

    for split in splits:
        if split in cfg:
            rel = cfg[split]
            split_paths[split] = dataset_root / rel
        else:
            # Thu tim theo thu muc mac dinh
            candidate = dataset_root / "images" / split
            if candidate.exists():
                split_paths[split] = candidate

    all_errors = []
    all_warnings = []
    split_stats = {}
    class_box_counts = defaultdict(lambda: defaultdict(int))
    image_hashes = {}  # hash -> (split, filepath)
    total_images_found = 0

    for split, img_dir in split_paths.items():
        print(f"--- Kiem tra tap: {split.upper()} ---")
        print(f"Thu muc anh: {img_dir}")

        if not img_dir.exists():
            print(f"[CANH BAO] Thu muc chua ton tai: {img_dir}\n")
            continue

        # Xac dinh thu muc label tuong ung
        # Vi du: dataset/images/train -> dataset/labels/train
        parts = list(img_dir.parts)
        if "images" in parts:
            idx = len(parts) - 1 - parts[::-1].index("images")
            parts[idx] = "labels"
            label_dir = Path(*parts)
        else:
            label_dir = img_dir.parent.parent / "labels" / split

        print(f"Thu muc nhan: {label_dir}")

        # Tim tat ca file anh
        long_img_dir = to_long_path(img_dir)
        long_lbl_dir = to_long_path(label_dir)
        img_files = [f for f in long_img_dir.iterdir() if f.is_file() and f.suffix.lower() in IMAGE_EXTENSIONS]
        lbl_files = [f for f in long_lbl_dir.iterdir() if f.is_file() and f.suffix.lower() == ".txt"] if long_lbl_dir.exists() else []

        img_stems = {f.stem: f for f in img_files}
        lbl_stems = {f.stem: f for f in lbl_files}

        total_images_found += len(img_files)

        split_img_count = len(img_files)
        split_box_count = 0
        split_bg_count = 0

        # 1. Kiem tra anh khong co label
        for stem, img_path in img_stems.items():
            if stem not in lbl_stems:
                all_errors.append(f"[{split.upper()}] Anh thieu file nhan .txt: {img_path.name}")

        # 2. Kiem tra label khong co anh
        for stem, lbl_path in lbl_stems.items():
            if stem not in img_stems:
                all_errors.append(f"[{split.upper()}] File nhan thieu anh tuong ung: {lbl_path.name}")

        # 3. Kiem tra tinh hop le cua tung anh va label
        for stem, img_path in img_stems.items():
            # Kiem tra anh hong
            try:
                with Image.open(to_long_path(img_path)) as im:
                    im.verify()
                    w_px, h_px = im.size
                    if w_px < 200 or h_px < 200:
                        all_warnings.append(f"[{split.upper()}] Anh kich thuoc qua nho ({w_px}x{h_px}): {img_path.name}")
            except Exception as e:
                all_errors.append(f"[{split.upper()}] Anh bi hong / loi format: {img_path.name} ({e})")

            # Kiem tra trung lap va ro ri du lieu
            try:
                img_hash = compute_image_hash(img_path)
                if img_hash in image_hashes:
                    prev_split, prev_path = image_hashes[img_hash]
                    if prev_split != split:
                        all_errors.append(
                            f"[RO RI DU LIEU] Anh '{img_path.name}' o tap {split} bi TRUNG LAP hoan toan voi '{prev_path.name}' o tap {prev_split}!"
                        )
                    else:
                        all_warnings.append(
                            f"[{split.upper()}] Anh trung lap noi bo: '{img_path.name}' giong '{prev_path.name}'"
                        )
                else:
                    image_hashes[img_hash] = (split, img_path)
            except Exception:
                pass

            # Kiem tra noi dung file label
            if stem in lbl_stems:
                lbl_path = lbl_stems[stem]
                try:
                    with open(to_long_path(lbl_path), "r", encoding="utf-8") as lf:
                        lines = [line.strip() for line in lf if line.strip()]

                    if len(lines) == 0:
                        split_bg_count += 1
                        continue

                    for line_idx, line in enumerate(lines, start=1):
                        tokens = line.split()
                        if len(tokens) == 5:
                            is_polygon = False
                        elif len(tokens) > 5 and len(tokens) % 2 == 1:
                            is_polygon = True
                        else:
                            all_errors.append(
                                f"[{split.upper()}] Sai so luong tham so o {lbl_path.name} dong {line_idx}: '{line[:50]}...' (Can 5 tham so [class x y w h] hoac polygon segmentation)"
                            )
                            continue

                        # Parse class ID
                        try:
                            cid = int(tokens[0])
                            if cid < 0 or cid >= nc:
                                all_errors.append(
                                    f"[{split.upper()}] Class ID {cid} vuot ngoai pham vi [0, {nc-1}] tai {lbl_path.name}:{line_idx}"
                                )
                        except ValueError:
                            all_errors.append(
                                f"[{split.upper()}] Class ID khong phai so nguyen tai {lbl_path.name}:{line_idx}: '{tokens[0]}'"
                            )
                            cid = -1

                        # Parse coordinates
                        try:
                            if is_polygon:
                                coords = [float(v) for v in tokens[1:]]
                                xs = coords[0::2]
                                ys = coords[1::2]
                                x_min, x_max = min(xs), max(xs)
                                y_min, y_max = min(ys), max(ys)
                                w = x_max - x_min
                                h = y_max - y_min
                                x = x_min + w / 2
                                y = y_min + h / 2
                            else:
                                x, y, w, h = float(tokens[1]), float(tokens[2]), float(tokens[3]), float(tokens[4])

                            if not (0.0 <= x <= 1.0 and 0.0 <= y <= 1.0):
                                all_errors.append(
                                    f"[{split.upper()}] Toa do tam (x,y)=({x:.4f},{y:.4f}) vuot ngoai [0, 1] tai {lbl_path.name}:{line_idx}"
                                )
                            if not (0.0 < w <= 1.0 and 0.0 < h <= 1.0):
                                all_errors.append(
                                    f"[{split.upper()}] Kich thuoc (w,h)=({w},{h}) khong hop le tai {lbl_path.name}:{line_idx}"
                                )

                            # Kiem tra mep vuot ngoai vien anh
                            if (x - w/2) < -0.01 or (x + w/2) > 1.01 or (y - h/2) < -0.01 or (y + h/2) > 1.01:
                                all_warnings.append(
                                    f"[{split.upper()}] Bounding box cham/tran vien anh o {lbl_path.name}:{line_idx}"
                                )

                            if cid >= 0:
                                class_box_counts[cid][split] += 1
                                split_box_count += 1

                        except ValueError:
                            all_errors.append(
                                f"[{split.upper()}] Toa do bbox khong phai so thuc tai {lbl_path.name}:{line_idx}"
                            )

                except Exception as e:
                    all_errors.append(f"[{split.upper()}] Khong the doc file nhan {lbl_path.name}: {e}")

        split_stats[split] = {
            "images": split_img_count,
            "boxes": split_box_count,
            "background": split_bg_count,
        }
        print(f"  -> So anh: {split_img_count} | So Bounding Box: {split_box_count} | Anh nen (bg): {split_bg_count}\n")

    # ============================================================
    # IN KET QUA TONG KET
    # ============================================================
    print(f"============================================================")
    print(f"                   KET QUA TONG QUAN                        ")
    print(f"============================================================")

    if total_images_found == 0:
        print("[THONG BAO] Hien tai chua co anh nao trong cac thu muc dataset.")
        print("Cau truc thu muc da san sang de them anh va nhan:")
        print("  - dataset/images/train/ & dataset/labels/train/")
        print("  - dataset/images/val/   & dataset/labels/val/")
        print("  - dataset/images/test/  & dataset/labels/test/")
        print("\nHuong dan chi tiet: xem docs/DATASET_COLLECTION_GUIDE.md")
        sys.exit(0)

    # Bang thong ke phan bo theo class
    print("\nBANG PHAN BO BOUNDING BOX THEO TUNG CLASS:")
    print(f"{'ID':<4} | {'Class Name':<18} | {'Train':<7} | {'Val':<7} | {'Test':<7} | {'Total':<7}")
    print("-" * 62)

    total_all_boxes = 0
    for cid in range(nc):
        cname = names.get(cid, f"Class {cid}")
        tr_cnt = class_box_counts[cid]["train"]
        val_cnt = class_box_counts[cid]["val"]
        tst_cnt = class_box_counts[cid]["test"]
        tot = tr_cnt + val_cnt + tst_cnt
        total_all_boxes += tot

        print(f"{cid:<4} | {cname:<18} | {tr_cnt:<7} | {val_cnt:<7} | {tst_cnt:<7} | {tot:<7}")

        if tot == 0:
            all_warnings.append(f"Class '{cname}' (ID {cid}) chua co bat ky bounding box nao trong dataset!")
        elif tot < 20:
            all_warnings.append(f"Class '{cname}' (ID {cid}) co qua it mau ({tot} boxes < 20).")

    print("-" * 62)
    print(f"{'TONG':<25} | {sum(s['boxes'] for s in split_stats.values()):<7}")

    print(f"\nTong so anh tren toan bo dataset: {total_images_found}")

    # In loi va canh bao
    if all_warnings:
        print(f"\n[CANH BAO] Phat hien {len(all_warnings)} canh bao:")
        for w in all_warnings[:20]:
            print(f"  * {w}")
        if len(all_warnings) > 20:
            print(f"  ... va {len(all_warnings) - 20} canh bao khac.")

    if all_errors:
        print(f"\n[THAT BAI] Phat hien {len(all_errors)} loi nghiem trong can khac phuc:")
        for e in all_errors[:25]:
            print(f"  ! {e}")
        if len(all_errors) > 25:
            print(f"  ... va {len(all_errors) - 25} loi khac.")
        sys.exit(1)
    else:
        print(f"\n[THANH CONG] Toan bo anh va nhan deu hop le, khong co loi format hay ro ri du lieu!")
        sys.exit(0)


if __name__ == "__main__":
    main()
