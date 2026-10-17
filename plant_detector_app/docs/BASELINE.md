# Baseline Freeze

Date: 2026-10-05

## Repository State

- Git status: not available. The project directory is not currently a Git repository, so a baseline commit hash could not be recorded.
- Project root: `D:\plant_detector_app\plant_detector_app`
- Python: 3.11.9
- Baseline model: `models/best.pt`
- Baseline backup: `models/baseline/best_v1.pt`
- Production copy: `models/production/best.pt`
- Sample image backup: `backups/sample_images/cay_mau.jpg`
- Model SHA256: `752956c3601e8fddfb4372914484bca6dc35de46b1df3bf2301d128aa7bf7f4d`

## Dependencies

Captured with `.\venv\Scripts\python.exe -m pip freeze`.

Important runtime packages:

- streamlit 1.64.0
- ultralytics 8.4.170
- torch 2.14.1
- torchvision 0.29.1
- pillow 12.3.0
- numpy 2.4.6
- opencv-python 5.0.0.93
- uvicorn 0.54.0
- python-multipart 0.0.32
- httpx 0.28.1

## Class List

| ID | Class | Vietnamese |
|---:|---|---|
| 0 | Acacia | Cây Keo |
| 1 | Bamboo-shoots | Măng Tre / Cây Tre |
| 2 | Banana-plant | Cây Chuối |
| 3 | Banyan-Tree | Cây Đa |
| 4 | Coconut-tree | Cây Dừa |
| 5 | Mango-Tree | Cây Xoài |
| 6 | Neem-Tree | Cây Neem / Sầu Đâu |
| 7 | Palm-tree | Cây Cọ |
| 8 | Papaya-Tree | Cây Đu Đủ |
| 9 | Pine | Cây Thông |
| 10 | lemon tree | Cây Chanh |
| 11 | peepal tree | Cây Bồ Đề |

## Default Inference Settings

- Confidence threshold: `0.25`
- IoU threshold: `0.45`
- Input conversion: PIL RGB
- Model task: object detection

## Baseline Smoke Test

Image: `sample_images/cay_mau.jpg`

- Image size: `1200x896`
- Detection count: `1`
- Detection: class `10`, `lemon tree`, confidence `0.3267`, bbox `[532.0, 22.7, 1200.0, 849.5]`

This is only a smoke test. It is not an accuracy metric and must not be used to claim that the model is accurate.

## Known Issues

- No independent validation/test dataset is present in the repository.
- Precision, recall, mAP, confusion matrix, and AP by class cannot be computed until a labeled validation/test dataset is added.
- Git baseline commit could not be captured because the project is not initialized as a Git repository.
