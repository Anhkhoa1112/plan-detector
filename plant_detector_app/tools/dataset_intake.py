"""
Tool tiep nhan va thong ke du lieu moi thu thap (Dataset Intake Tool).

Su dung:
    python tools/dataset_intake.py --dataset dataset/real_world_train
    python tools/dataset_intake.py --dataset dataset/real_world_test
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
    parser = argparse.ArgumentParser(description="Dataset Intake summary and intake validator")
    parser.add_argument(
        "--dataset",
        type=str,
        required=True,
        help="Path to intake dataset directory (e.g. dataset/real_world_train)",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    dataset_dir = Path(args.dataset)

    if not dataset_dir.exists():
        print(f"[ERROR] Thu muc dataset khong ton tai: {dataset_dir}")
        sys.exit(1)

    total_images = 0
    valid_images = 0
    corrupt_images = 0
    duplicate_images = 0

    class_counts = {c: 0 for c in VALID_CLASSES}
    seen_hashes = set()

    for class_name in VALID_CLASSES:
        class_dir = dataset_dir / class_name
        if not class_dir.exists():
            continue

        for item in win_long(class_dir).iterdir():
            if item.name.lower() in IGNORED_FILES:
                continue

            if not item.is_file():
                continue

            total_images += 1

            ext = item.suffix.lower()
            if ext not in ALLOWED_EXTENSIONS or item.stat().st_size == 0:
                corrupt_images += 1
                continue

            try:
                with Image.open(win_long(item)) as im:
                    im.verify()
            except Exception:
                corrupt_images += 1
                continue

            # Kiem tra trung hash
            try:
                h = compute_sha256(item)
                if h in seen_hashes:
                    duplicate_images += 1
                    continue
                seen_hashes.add(h)
            except Exception:
                corrupt_images += 1
                continue

            valid_images += 1
            class_counts[class_name] += 1

    print("Dataset Summary")
    print("----------------")
    print(f"Total images:     {total_images}")
    print(f"Valid images:     {valid_images}")
    print(f"Corrupt images:   {corrupt_images}")
    print(f"Duplicate images: {duplicate_images}\n")

    for c in VALID_CLASSES:
        print(f"{c:<16}: {class_counts[c]}")

    if total_images == 0:
        print("\n[STATUS] Waiting for real-world images. (Chua co anh nao duoc nap vao)")
        return

    # Kiem tra mat can bang du lieu (Class imbalance)
    counts = list(class_counts.values())
    max_c = max(counts)
    min_c = min(counts)

    if max_c > 0 and (min_c == 0 or max_c / max(1, min_c) > 2.5):
        print("\n" + "=" * 48)
        print("WARNING:")
        print("Class imbalance detected")
        print("=" * 48)
        weak_classes = [c for c, cnt in class_counts.items() if cnt < max_c * 0.4]
        print(f"Cac class can bo sung them anh: {', '.join(weak_classes)}")


if __name__ == "__main__":
    main()
