# AI Evaluation

## Status

Blocked by missing labeled validation/test dataset.

## Required Metrics

- Precision
- Recall
- mAP@50
- mAP@50-95
- F1 if supported by the evaluation pipeline
- Confusion matrix
- AP by class
- Validation/test image count
- Object count by class

## Current Available Evidence

Only one smoke-test image exists in the repository:

- `sample_images/cay_mau.jpg`
- Baseline model returned one detection: `lemon tree`, confidence `0.3267`.

This result is not a model quality metric.

## Required Dataset Layout

Recommended future layout:

```text
datasets/
└── plant_v1_eval/
    ├── data.yaml
    ├── images/
    │   ├── val/
    │   └── test/
    └── labels/
        ├── val/
        └── test/
```

When the dataset exists, run Ultralytics validation against `models/baseline/best_v1.pt` and store outputs under `runs/evaluate/baseline_v1/`.
