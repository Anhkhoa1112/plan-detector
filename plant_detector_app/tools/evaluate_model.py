"""
Script danh gia mo hinh YOLO cho du an Plant AI Detector.
Su dung Ultralytics validation API de tinh toan cac chi so chuan xac:
Precision, Recall, mAP50, mAP50-95, Per-class AP, va Confusion Matrix.

Su dung:
    python tools/evaluate_model.py --data path/to/data.yaml [--model models/production/best.pt]
"""

import argparse
import json
import os
import sys
from pathlib import Path

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = PROJECT_ROOT / "models" / "production" / "best.pt"
DEFAULT_OUTPUT_DOC = PROJECT_ROOT / "docs" / "MODEL_EVALUATION_REPORT.md"
DEFAULT_ANALYSIS_DIR = PROJECT_ROOT / "docs" / "model_analysis"


def parse_args():
    parser = argparse.ArgumentParser(description="Evaluate YOLO model on validation/test dataset.")
    parser.add_argument(
        "--model",
        type=str,
        default=str(DEFAULT_MODEL),
        help="Path to YOLO model checkpoint (.pt)",
    )
    parser.add_argument(
        "--data",
        type=str,
        required=False,
        default=None,
        help="Path to dataset data.yaml file",
    )
    parser.add_argument(
        "--split",
        type=str,
        default="val",
        choices=["val", "test"],
        help="Dataset split to evaluate (val or test)",
    )
    parser.add_argument(
        "--imgsz",
        type=int,
        default=640,
        help="Inference image size (default: 640)",
    )
    parser.add_argument(
        "--conf",
        type=float,
        default=0.25,
        help="Confidence threshold (default: 0.25)",
    )
    parser.add_argument(
        "--iou",
        type=float,
        default=0.45,
        help="IoU threshold (default: 0.45)",
    )
    parser.add_argument(
        "--output-doc",
        type=str,
        default=str(DEFAULT_OUTPUT_DOC),
        help="Path to output markdown report",
    )
    parser.add_argument(
        "--append",
        action="store_true",
        help="Append evaluation results to existing report instead of overwriting",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    model_path = Path(args.model)

    if not model_path.exists():
        print(f"[ERROR] Model file not found at: {model_path}")
        sys.exit(1)

    if not args.data:
        print("[WARNING] Parameter --data pointing to data.yaml is missing.")
        print("Usage:")
        print("    python tools/evaluate_model.py --data datasets/plant_val/data.yaml")
        print("\nNotice: The local repository does not currently contain an independent validation dataset.")
        sys.exit(2)

    data_path = Path(args.data)
    if not data_path.exists():
        print(f"[ERROR] data.yaml not found at: {data_path}")
        sys.exit(1)

    print("=== STARTING MODEL EVALUATION ===")
    print(f"Model: {model_path}")
    print(f"Dataset: {data_path} (split: {args.split})")
    print(f"Image Size: {args.imgsz}, Conf: {args.conf}, IoU: {args.iou}")

    from ultralytics import YOLO

    model = YOLO(str(model_path))

    results = model.val(
        data=str(data_path),
        split=args.split,
        imgsz=args.imgsz,
        conf=args.conf,
        iou=args.iou,
        plots=True,
        save_json=True,
        project=str(PROJECT_ROOT / "runs" / "val"),
        name="eval_report",
        exist_ok=True,
    )

    box = results.box
    names = model.names or {}

    precision = float(box.mp)
    recall = float(box.mr)
    map50 = float(box.map50)
    map50_95 = float(box.map)

    print("\n--- OVERALL METRICS ---")
    print(f"Precision: {precision:.4f}")
    print(f"Recall:    {recall:.4f}")
    print(f"mAP@50:    {map50:.4f}")
    print(f"mAP@50-95: {map50_95:.4f}")

    per_class_rows = []
    for cid in range(len(names)):
        cname = names.get(cid, f"Class {cid}")
        p_c = float(box.p[cid]) if len(box.p) > cid else 0.0
        r_c = float(box.r[cid]) if len(box.r) > cid else 0.0
        ap50_c = float(box.ap50[cid]) if len(box.ap50) > cid else 0.0
        ap_c = float(box.ap[cid]) if len(box.ap) > cid else 0.0
        per_class_rows.append({
            "id": cid,
            "name": cname,
            "precision": p_c,
            "recall": r_c,
            "map50": ap50_c,
            "map50_95": ap_c,
        })

    output_doc_path = Path(args.output_doc)
    output_doc_path.parent.mkdir(parents=True, exist_ok=True)
    is_append = args.append and output_doc_path.exists()

    with open(output_doc_path, "a" if is_append else "w", encoding="utf-8") as f:
        if not is_append:
            f.write("# Báo Cáo Đánh Giá Mô Hình (Model Evaluation Report)\n\n")
        f.write(f"## Đánh Giá: `{model_path.name}` ({model_path.parent.name})\n\n")
        f.write(f"- **Model Path:** `{model_path}`\n")
        f.write(f"- **Dataset:** `{data_path}` (split: `{args.split}`)\n")
        f.write(f"- **Image Size:** `{args.imgsz}x{args.imgsz}`\n")
        f.write(f"- **Confidence Threshold:** `{args.conf}`\n")
        f.write(f"- **IoU Threshold:** `{args.iou}`\n\n")
        f.write("### Metrics Tổng Quan\n\n")
        f.write("| Chỉ số | Giá trị |\n")
        f.write("| :--- | :--- |\n")
        f.write(f"| Precision (B) | `{precision:.4f}` ({precision * 100:.1f}%) |\n")
        f.write(f"| Recall (B) | `{recall:.4f}` ({recall * 100:.1f}%) |\n")
        f.write(f"| mAP@50 (B) | `{map50:.4f}` ({map50 * 100:.1f}%) |\n")
        f.write(f"| mAP@50-95 (B) | `{map50_95:.4f}` ({map50_95 * 100:.1f}%) |\n\n")
        f.write("### Chi Tiết Từng Class\n\n")
        f.write("| ID | Class Name | Precision | Recall | mAP50 | mAP50-95 |\n")
        f.write("| :--- | :--- | :--- | :--- | :--- | :--- |\n")
        for r in per_class_rows:
            f.write(f"| {r['id']} | `{r['name']}` | {r['precision']:.4f} | {r['recall']:.4f} | {r['map50']:.4f} | {r['map50_95']:.4f} |\n")
        f.write("\n---\n")

    print(f"\nReport written to: {output_doc_path}")


if __name__ == "__main__":
    main()
