# Trạng Thái Bộ Dữ Liệu Hybrid V3 (Hybrid Dataset Status)

Ngày cập nhật: 06/10/2026  
Dự án: **Plant AI Detector**

---

## 1. Trạng Thái Hiện Tại (Current Status)

### 1.1. Baseline Model Performance (V1 Checkpoint)
- **Precision:** `76.7%`
- **Recall:** `67.7%`
- **mAP@50:** `67.2%`
- **mAP@50-95:** `42.0%`

### 1.2. Các Class Yếu Nhất Cần Cứu Vãn (Weak Classes)
- **`Coconut-tree` (Cây dừa):** **25.7% Recall** (mAP50: 19.3%) — Mức độ nghiêm trọng nhất.
- **`Banana-plant` (Cây chuối):** **38.6% Recall** (mAP50: 48.7%) — Bỏ sót hơn 61% cá thể.
- **`Banyan-Tree` (Cây đa):** **41.8% Recall** (mAP50: 39.4%) — Bắt khung và định vị rất kém.

---

## 2. Tình Trạng Các Tập Dữ Liệu (Dataset Inventory)

| Tên Tập Dữ Liệu | Đường dẫn thư mục | Số lượng ảnh | Số Bounding Boxes | Trạng thái hiện tại |
| :--- | :--- | :---: | :---: | :--- |
| **Dataset V1 Gốc** | `dataset/original_v1/` | `2.336` | `3.446` | Đã khôi phục từ Roboflow (giữ nguyên gốc) |
| **Dataset V1 Sạch** | `dataset/original_v1_clean/` | `2.317` | `3.428` | **Hoàn thành làm sạch** (đã loại bỏ 19 duplicates) |
| **Real-World Train** | `dataset/real_world_train/` | `0` | `0` | Đã tạo cấu trúc 12 classes *(Chờ nạp ảnh chụp thực tế)* |
| **Real-World Test** | `dataset/real_world_test/` | `0` | `0` | Đã tạo cấu trúc 12 classes *(Chờ nạp ảnh test độc lập)* |
| **Real-World YOLO** | `dataset/real_world_yolo/` | `0` | `0` | Đã tạo khung train/val/test/data.yaml *(Chờ gán nhãn)* |

---

## 3. Giai Đoạn Dự Án Hiện Tại (Current Phase)

> ### **PHASE: Human Data Collection / Annotation Preparation**
> *(Giai đoạn: Thu thập Dữ liệu Thực tế & Chuẩn bị Gán nhãn Thủ công)*

---

## 4. Trạng Thái Huấn Luyện (Training Status)

> ### **HYBRID V3: NOT TRAINED (Chưa Huấn Luyện)**
> 
> *Tuân thủ nguyên tắc không huấn luyện khi chưa hoàn thiện tập test thực tế và dữ liệu gán nhãn chuẩn từ con người.*
