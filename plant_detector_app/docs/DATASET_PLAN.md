# Kế Hoạch Xây Dựng Dataset Lai Có Kiểm Soát (Controlled Hybrid Dataset Plan)

Ngày cập nhật: 06/10/2026  
Dự án: Plant AI Detector (YOLOv8 + FastAPI + Flutter)  
Chiến lược chủ đạo: **Phương án C có kiểm soát (Controlled Hybrid Dataset)**

---

## 1. Mục Tiêu & Nguyên Tắc Cốt Lõi

1. **Không đụng vào Model Production hiện tại:** Giữ nguyên `models/production/best.pt` và `models/baseline/best_v1.pt` cho tới khi có kết quả benchmark thực tế vượt trội.
2. **Không dùng chỉ số 94.02% làm tiêu chuẩn:** Điểm số 94% mAP50 trên Colab là kết quả tự chấm điểm trên nhãn do chính AI sinh ra (pseudo-labeling). Mọi đánh giá tương lai phải dựa trên **Real-World Test Set** độc lập.
3. **Ground Truth do con người xác thực:** Dữ liệu bổ sung phải được gán nhãn thủ công cẩn thận, loại bỏ hoàn toàn cơ chế tự sinh nhãn sai lệch.
4. **Trả lời được câu hỏi:** *"Model V3 tốt hơn Model V2 bao nhiêu % trên điện thoại thật?"*

---

## 2. Quy Trình 12 Bước Triển Khai Chi Tiết

```
① Bảo vệ / Rotate Roboflow API Key
       │
② Khôi phục Dataset V1 (Tree-Species-1) ──► dataset/original_v1/
       │
③ Benchmark Baseline best_v1.pt trên V1 Valid Set
       │
④ Benchmark Production best.pt trên V1 Valid Set
       │
⑤ Thiết lập Real-World Test Set (100–200 ảnh) ──► dataset/real_world_test/
       │   (Độc lập 100%, KHÔNG BAO GIỜ dùng để train)
       │
⑥ Thu thập 300–500 ảnh thực tế từ điện thoại Xiaomi (25–40 ảnh / class)
       │
⑦ Gán nhãn thủ công (Human Ground Truth Annotation)
       │
⑧ Huấn luyện Hybrid V3 (Thử nghiệm Experiment A và B)
       │   Experiment A: V1 + Real-World
       │   Experiment B: V2 + Real-World
       │
⑨ Benchmark so sánh 3 Model (V1 vs V2 vs V3) trên CÙNG Real-World Test Set
       │
⑩ Nghiệm thu & Lựa chọn Model xuất sắc nhất
       │
⑪ Cập nhật Model vào FastAPI Backend
       │
⑫ Kiểm thử toàn diện & tinh chỉnh UI / Threshold trên Flutter App
```

---

## 3. Cấu Trúc Thư Mục Dự Án Chuẩn Hóa

```text
plant_detector_app/
│
├── dataset/
│   ├── original_v1/          # Dataset gốc V1 từ Roboflow (Tree-Species-1)
│   │   ├── train/
│   │   ├── valid/
│   │   ├── test/
│   │   └── data.yaml
│   ├── hybrid_v3/            # Dataset hỗn hợp V3 (Gốc + Dữ liệu thực tế)
│   └── real_world_test/      # Tập test thực tế (12 classes, chỉ dùng để test)
│       ├── Acacia/
│       ├── Bamboo-shoots/
│       ├── Banana-plant/
│       ├── Banyan-Tree/
│       ├── Coconut-tree/
│       ├── Mango-Tree/
│       ├── Neem-Tree/
│       ├── Palm-tree/
│       ├── Papaya-Tree/
│       ├── Pine/
│       ├── lemon tree/
│       └── peepal tree/
│
├── models/
│   ├── baseline/
│   │   └── best_v1.pt        # Model V1 ban đầu (mAP50 reported: 80.69%)
│   ├── production/
│   │   └── best.pt           # Model V2 hiện tại đang phục vụ FastAPI
│   └── experiments/
│       ├── v2_retrain/       # Thử nghiệm tái huấn luyện V2
│       └── hybrid_v3/        # Model V3 lai ghép đề xuất
│           └── best.pt
│
├── tools/
│   ├── download_v1_dataset.py # Tải dataset V1 tự động với API Key
│   ├── evaluate_model.py      # Nghiệm thu và so sánh benchmark
│   └── validate_dataset.py    # Kiểm tra tính toàn vẹn dataset
│
├── backend/                  # FastAPI service
├── lib/                      # Flutter app source code
├── docs/                     # Báo cáo kỹ thuật và tài liệu hướng dẫn
├── .env.example              # Mẫu cấu hình môi trường
└── .env                      # File chứa API Key bảo mật (đã ignore)
```

---

## 4. Chi Tiết Thực Hiện Từng Giai Đoạn

### Giai đoạn 1: Đóng băng Model & Bảo vệ API Key (Hoàn thành)
- Không ghi đè lên `models/production/best.pt`.
- Che toàn bộ API key trong tài liệu, cấu hình `.gitignore` và `.env.example`.
- Tạo sẵn các nhánh thư mục `models/experiments/` và `dataset/`.

### Giai đoạn 2: Khôi phục Dataset V1 & Benchmark Baseline
- Chạy công cụ:
  ```bash
  python tools/download_v1_dataset.py
  ```
- Chạy nghiệm thu Model V1:
  ```bash
  python tools/evaluate_model.py --model models/baseline/best_v1.pt --data dataset/original_v1/data.yaml
  ```
- Chạy nghiệm thu Model V2 (production) trên cùng tập V1:
  ```bash
  python tools/evaluate_model.py --model models/production/best.pt --data dataset/original_v1/data.yaml --append
  ```
- Đối chiếu kết quả với các thông số ghi nhận từ Google Colab.

### Giai đoạn 3: Xây dựng Real-World Test Set Độc Lập
- Thu thập **100 – 200 ảnh chụp thực tế đầu tiên** từ điện thoại Xiaomi.
- Phân bổ đều vào 12 thư mục lớp tại `dataset/real_world_test/`.
- Gán nhãn thủ công chuẩn bounding box YOLO.
- **Quy tắc bất di bất dịch:** Tập ảnh này không bao giờ được chạm vào tập huấn luyện của bất kỳ model nào.

### Giai đoạn 4: Thu thập Dữ liệu Huấn luyện Mới (300 – 500 ảnh)
- Thu thập **25 – 40 ảnh / class** theo đúng tiêu chuẩn đa dạng:
  - **Khoảng cách:** 0.3m, 0.5m, 1m, 1.5m, 2m, 3m.
  - **Góc chụp:** Chính diện, nghiêng trái/phải, chụp hất từ dưới lên, chụp từ trên xuống.
  - **Bộ phận:** Lá, chùm lá non/già, thân, cành, hoa, quả.
  - **Ánh sáng:** Nắng gắt, bóng râm, ngược sáng, sáng yếu, trong nhà, ngoài trời.

### Giai đoạn 5: Gán nhãn Thủ công (Human Ground Truth)
- Tuyệt đối không dùng AI để auto-label.
- Người thực hiện kiểm tra và đóng khung sát tán lá / thân cây.
- Format chuẩn YOLO:
  ```text
  <class_id> <x_center> <y_center> <width> <height>
  ```

### Giai đoạn 6: Phân chia Tập dữ liệu Lai (Hybrid Dataset Split)
- Tập dữ liệu lai (ví dụ ~3.500 – 4.000 ảnh):
  - **Train (70%):** Học đặc trưng.
  - **Validation (20%):** Tinh chỉnh hyperparameter và early stopping.
  - **Test Set:** Duy trì Real-World Test Set riêng biệt đã khóa từ Giai đoạn 3.

### Giai đoạn 7: Huấn luyện 2 Thử Nghiệm Model V3
- **Experiment A:** Dataset V1 + Real-World Dataset.
- **Experiment B:** Dataset V2 (sau khi lọc) + Real-World Dataset.
- Lưu kết quả tốt nhất vào `models/experiments/hybrid_v3/best.pt`.

### Giai đoạn 8: So sánh Benchmark 3 Chiều (V1 vs V2 vs V3)
Đánh giá cả 3 mô hình trên **cùng một Real-World Test Set**:

| Model | Bộ Dữ Liệu Huấn Luyện | mAP50 (Real-World) | Recall (Real-World) | Độ Chính Xác Thực Tế |
| :--- | :--- | :---: | :---: | :--- |
| **V1** | Dataset gốc Roboflow | ... | ... | Baseline |
| **V2** | Pseudo-label Colab | ... | ... | Model hiện tại |
| **V3** | Hybrid + Human-labeled | ... | ... | Model đề xuất |

> Tiêu chí chọn lựa: Dù mAP50 trên ảnh web có thể thấp hơn 94%, model nào có **Recall và mAP50 cao nhất trên Real-World Test Set** sẽ được chọn làm Model Production.

### Giai đoạn 9: Tích hợp & Tinh chỉnh Toàn diện
- Chuyển model chiến thắng sang `models/production/best.pt` (có sao lưu bản cũ).
- Tinh chỉnh các tham số backend: `conf_threshold`, `iou_threshold`, `max_det`.
- Kiểm thử luồng ảnh thực tế từ Camera Xiaomi -> FastAPI -> Bounding Box Flutter UI.
