"""
Tool tai Dataset V1 (Tree-Species-1) tu Roboflow ve may tinh cuc bo.

Su dung:
    python tools/download_v1_dataset.py
    hoac
    python tools/download_v1_dataset.py --api-key YOUR_KEY
"""

import argparse
import os
import sys
from pathlib import Path

# Load .env neu co
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DEST = PROJECT_ROOT / "dataset" / "original_v1"


def parse_args():
    parser = argparse.ArgumentParser(description="Download Dataset V1 (Tree-Species-1) from Roboflow")
    parser.add_argument(
        "--api-key",
        type=str,
        default=os.getenv("ROBOFLOW_API_KEY", ""),
        help="Roboflow API Key (or set in .env as ROBOFLOW_API_KEY)",
    )
    parser.add_argument(
        "--dest",
        type=str,
        default=str(DEFAULT_DEST),
        help="Destination directory for dataset",
    )
    parser.add_argument(
        "--workspace",
        type=str,
        default="mlinn2045-gmail-com",
        help="Roboflow workspace name",
    )
    parser.add_argument(
        "--project",
        type=str,
        default="tree-species-hace3-an24k",
        help="Roboflow project name",
    )
    parser.add_argument(
        "--version",
        type=int,
        default=1,
        help="Dataset version",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    api_key = args.api_key.strip()

    if not api_key:
        print("[ERROR] Roboflow API Key is missing!")
        print("Please provide it via:")
        print("  1. In .env file: ROBOFLOW_API_KEY=your_key")
        print("  2. Command line: python tools/download_v1_dataset.py --api-key your_key")
        sys.exit(1)

    dest_dir = Path(args.dest)
    dest_dir.mkdir(parents=True, exist_ok=True)

    print("=== BAT DAU TAI DATASET V1 TU ROBOFLOW ===")
    print(f"Workspace: {args.workspace}")
    print(f"Project:   {args.project} (version {args.version})")
    print(f"Luu tai:   {dest_dir}")

    try:
        from roboflow import Roboflow
    except ImportError:
        print("[ERROR] Thu vien roboflow chua duoc cai dat. Hay chay: pip install roboflow")
        sys.exit(1)

    try:
        rf = Roboflow(api_key=api_key)
        proj = rf.workspace(args.workspace).project(args.project)
        ver = proj.version(args.version)

        print("[INFO] Dang ket noi va tai du lieu tu Roboflow...")
        dataset = ver.download("yolov8", location=str(dest_dir))
        print(f"[SUCCESS] Da tai thanh cong dataset ve: {dataset.location}")

        # Kiem tra file data.yaml
        data_yaml = dest_dir / "data.yaml"
        if data_yaml.exists():
            print(f"[INFO] Tim thay {data_yaml}")
            with open(data_yaml, "r", encoding="utf-8") as f:
                content = f.read()
            print("--- data.yaml preview ---")
            print(content[:500])
        else:
            print(f"[WARNING] Chua tim thay data.yaml tai {data_yaml}")

    except Exception as e:
        print(f"[ERROR] Loi khi tai dataset: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
