# Migration Plan

## Goal

Migrate the current Streamlit-first YOLO app toward the approved architecture:

`Flutter Mobile -> FastAPI -> YOLO model`

## Current Scope Implemented

- Preserved `models/best.pt`.
- Copied baseline model to `models/baseline/best_v1.pt`.
- Copied API production model to `models/production/best.pt`.
- Added FastAPI backend under `backend/`.
- Kept Streamlit available as the legacy UI.
- Removed the Streamlit UI path that directly overwrote `models/best.pt`.

## Next Phases

1. Add a labeled validation/test dataset.
2. Run model evaluation and create confusion matrix/error analysis.
3. Build Dataset v2 from real model errors.
4. Train model v2 into `models/experiments/`.
5. Benchmark v1 vs v2 before changing production model.
6. Build Flutter Android app and integrate with FastAPI.

## Non-Negotiable Constraints

- Do not overwrite `models/best.pt`.
- Do not change class IDs or class names without an explicit migration.
- Do not fake detections, confidence, or metrics.
- Do not call model v2 better without validation/test metrics.
