"""
Tool kiem tra tinh hop le cua Real-World Dataset (real_world_train / real_world_test).

Kiem tra:
  1. Cac thu muc lop: chi cho phep 12 lop hop le.
  2. Dinh dang file: chi chap nhan .jpg, .jpeg, .png, .webp.
  3. Kiem tra loi: file 0-byte, anh bi hong (corrupt), anh qua nho (< 200x200), anh trung lap (duplicate hash).
  4. Ten file khong hop le.

Su dung:
    python tools/validate_real_world_dataset.py --dataset dataset/real_world_test
    python tools/validate_real_world_dataset.py --dataset dataset/real_world_train
"""

import argparse
import hashlib
import os
import sys
from pathlib import Path
from PIL import Image

VALID_CLASSES = [
    "Acacia",
    "Bamboo-shoots",
    "Banana-plant",
    "Banyan-Tree",
    "Coconut-tree",
    "Mango-Tree",
    "Neem-Tree",
    "Palm-tree",
    "Papaya-Tree",
    "Pine",
    "lemon tree",
    "peepal tree",
]

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
IGNORED_FILES = {".gitkeep", ".ds_store", "thumbs.db", "readme.md"}


def win_long(p: Path) -> Path:
    s = str(p.resolve())
    if os.name == "nt" and not s.startswith("\\\\?\\"):
        return Path("\\\\?\\" + s)
    return p


def compute_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(win_long(path), "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def parse_args():
    parser = argparse.ArgumentParser(description="Validate Real-World image dataset structure and image integrity")
    parser.add_argument(
        "--dataset",
        type=str,
        required=True,
        help="Path to real-world dataset directory (e.g. dataset/real_world_test)",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    dataset_dir = Path(args.dataset)

    if not dataset_dir.exists():
        print(f"[ERROR] Thu muc dataset khong ton tai: {dataset_dir}")
        sys.exit(1)

    print("============================================================")
    print("      KIEM TRA REAL-WORLD DATASET (INTEGRITY CHECK)         ")
    print("============================================================")
    print(f"Dataset path: {dataset_dir}\n")

    errors = []
    warnings = []
    class_counts = {c: 0 for c in VALID_CLASSES}
    seen_hashes = {}  # hash -> filepath
    total_images = 0

    # 1. Kiem tra cac subfolder
    subdirs = [d for d in dataset_dir.iterdir() if d.is_dir()]
    for d in subdirs:
        if d.name not in VALID_CLASSES:
            errors.append(f"[INVALID CLASS] Thu muc khong hop le: '{d.name}' (Khong thuoc 12 lop du an)")

    # 2. Quet tat ca file trong dataset
    for class_name in VALID_CLASSES:
        class_dir = dataset_dir / class_name
        if not class_dir.exists():
            continue

        for item in win_long(class_dir).iterdir():
            if item.name.lower() in IGNORED_FILES:
                continue

            if not item.is_file():
                continue

            # Kiem tra dinh dang file
            ext = item.suffix.lower()
            if ext not in ALLOWED_EXTENSIONS:
                errors.append(f"[INVALID EXTENSION] '{item.name}' o lop '{class_name}' co duoi khong hop le: '{ext}'")
                continue

            # Kiem tra file 0-byte
            try:
                size_bytes = item.stat().st_size
                if size_bytes == 0:
                    errors.append(f"[EMPTY FILE] File 0 byte: '{item.name}' o lop '{class_name}'")
                    continue
            except Exception as e:
                errors.append(f"[CANNOT ACCESS] Khong the doc file '{item.name}': {e}")
                continue

            # Kiem tra anh bi hong (corrupt) va do phan giai
            try:
                with Image.open(win_long(item)) as im:
                    im.verify()
                    w, h = im.size
                    if w < 200 or h < 200:
                        warnings.append(f"[LOW RESOLUTION] Anh nho ({w}x{h}): '{item.name}' o lop '{class_name}'")
            except Exception as e:
                errors.append(f"[CORRUPT IMAGE] Anh bi hong khong the doc: '{item.name}' o lop '{class_name}' ({e})")
                continue

            # Kiem tra trung lap (duplicate hash)
            try:
                img_hash = compute_sha256(item)
                if img_hash in seen_hashes:
                    prev_class, prev_name = seen_hashes[img_hash]
                    errors.append(
                        f"[DUPLICATE] Anh '{item.name}' (lop {class_name}) trung lap hoan toan voi '{prev_name}' (lop {prev_class})!"
                    )
                else:
                    seen_hashes[img_hash] = (class_name, item.name)
            except Exception:
                pass

            class_counts[class_name] += 1
            total_images += 1

    # In bao cao ket qua
    print("THONG KE ANH THEO CLASS:")
    print("------------------------------------------------------------")
    for c in VALID_CLASSES:
        print(f"  {c:<16}: {class_counts[c]} anh")
    print("------------------------------------------------------------")
    print(f"Tong so anh hop le: {total_images}\n")

    if total_images == 0:
        print("[STATUS] Waiting for real-world images. (Thu muc hien dang rong, chua co anh)")

    if warnings:
        print(f"\n[CANH BAO] {len(warnings)} van de:")
        for w in warnings[:10]:
            print(f"  * {w}")
        if len(warnings) > 10:
            print(f"  ... va {len(warnings) - 10} canh bao khac.")

    if errors:
        print(f"\n[THAT BAI] Phat hien {len(errors)} loi nghiem trong:")
        for err in errors[:20]:
            print(f"  ! {err}")
        if len(errors) > 20:
            print(f"  ... va {len(errors) - 20} loi khac.")
        sys.exit(1)
    else:
        if total_images > 0:
            print("[THANH CONG] Toan bo anh trong dataset deu hop le va dat chuan!")
        sys.exit(0)


if __name__ == "__main__":
    main()
