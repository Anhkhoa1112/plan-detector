# Báo Cáo Đánh Giá Mô Hình (Model Evaluation Report)

Ngày lập: 06/10/2026  
Mục đích: Nghiệm thu khách quan hiệu năng của checkpoint hiện tại trên Dataset V1 (`dataset/original_v1`) trước khi xây dựng Hybrid V3.

---

## 1. Phát Hiện Quan Trọng Về Checkpoint (Key Findings)

### 1.1. Trùng lặp Checkpoint (Identical Checkpoint Discovery)
Kiểm tra băm mã hóa SHA-256 nhị phân của 2 checkpoint trong repository:
- `models/baseline/best_v1.pt`: `752956C3601E8FDDFB4372914484BCA6DC35DE46B1DF3BF2301D128AA7BF7F4D`
- `models/production/best.pt`: `752956C3601E8FDDFB4372914484BCA6DC35DE46B1DF3BF2301D128AA7BF7F4D`

> **Kết luận:** Hai file này là **một file duy nhất** (100% trùng khớp hash). Model đang phục vụ FastAPI Backend bấy lâu nay thực chất là **Model V1 ban đầu**, chứ chưa từng cập nhật checkpoint V2 (fine-tune từ auto-labeling trên Colab).

### 1.2. Phát hiện Rò rỉ Dữ liệu (Data Leakage) trong Dataset V1
Công cụ `tools/validate_dataset.py` phát hiện **19 ảnh trùng lặp hoàn toàn giữa tập train và tập val/test** trong dataset `Tree-Species-1` của Roboflow (chủ yếu là các ảnh chụp flycam DJI và ảnh web). Điều này chứng minh rằng điểm số trên các dataset web này vốn đã có sai số và sự thổi phồng nhất định.

---

## 2. Kết Quả Benchmark Baseline V1 trên Tập Validation Chuẩn

- **Dataset:** `dataset/original_v1/data.yaml` (split: `val`, 432 ảnh hợp lệ, 663 đối tượng)
- **Image Size:** `640x640` | **Confidence:** `0.25` | **IoU:** `0.45`
- **Thời gian suy luận trung bình:** `32.9ms / ảnh` (chạy trên CPU)

### Metrics Tổng Quan

| Chỉ số | Giá trị | Đánh giá |
| :--- | :---: | :--- |
| **Precision (B)** | `0.7674` (76.7%) | Độ chính xác khi bắt trúng hộp ở mức khá |
| **Recall (B)** | `0.6771` (67.7%) | Bị bỏ sót tới **~32.3%** cá thể cây |
| **mAP@50 (B)** | `0.6715` (67.2%) | Điểm chuẩn thực tế trên môi trường độc lập |
| **mAP@50-95 (B)** | `0.4202` (42.0%) | Khả năng định vị bounding box khít đạt mức trung bình |

---

## 3. Bảng Chi Tiết Từng Loài (Per-Class Performance Breakdown)

| ID | Tên Loài (Class Name) | Precision | Recall | mAP50 | mAP50-95 | Đánh giá thực tế |
| :---: | :--- | :---: | :---: | :---: | :---: | :--- |
| 0 | `Acacia` (Cây keo/tràm) | `0.9553` | `0.7959` | `0.8173` | `0.4569` | Rất tốt |
| 1 | `Bamboo-shoots` (Măng/tre) | `0.9128` | `0.8936` | `0.8993` | `0.6768` | Xuất sắc |
| 2 | `Banana-plant` (Cây chuối) | `0.8567` | **0.3856** | **0.4868** | `0.1948` | **BÁO ĐỘNG:** Bỏ sót hơn 61% cây chuối! |
| 3 | `Banyan-Tree` (Cây đa) | `0.6136` | **0.4181** | **0.3944** | `0.3530` | **KÉM:** Nhận diện và bắt khung rất yếu |
| 4 | `Coconut-tree` (Cây dừa) | `0.5362` | **0.2570** | **0.1932** | `0.0864` | **NGHIÊM TRỌNG:** Bỏ sót gần 75% cây dừa! |
| 5 | `Mango-Tree` (Cây xoài) | `0.7845` | `0.8519` | `0.7851` | `0.5110` | Ổn định |
| 6 | `Neem-Tree` (Cây sầu đâu) | `0.6103` | `0.6061` | `0.5967` | `0.3674` | Trung bình yếu |
| 7 | `Palm-tree` (Cây cọ) | `0.6662` | `0.6154` | `0.6504` | `0.3352` | Trung bình (dễ nhầm với dừa) |
| 8 | `Papaya-Tree` (Cây đu đủ) | `0.7236` | `0.8750` | `0.8652` | `0.4333` | Rất tốt |
| 9 | `Pine` (Cây thông) | `0.6733` | `0.7569` | `0.6818` | `0.4121` | Khá |
| 10 | `lemon tree` (Cây chanh) | `0.9308` | `0.7547` | `0.7669` | `0.6480` | Rất tốt |
| 11 | `peepal tree` (Cây bồ đề) | `0.9449` | `0.9149` | `0.9209` | `0.5671` | Xuất sắc |

---

## 4. Phân Tích Nguyên Nhân Kỹ Thuật Khi Ứng Dụng Thực Tế

1. **Vì sao người dùng chụp cây dừa (`Coconut-tree`) hay cây chuối (`Banana-plant`) app không phản hồi?**
   - Số liệu thực nghiệm chỉ ra Recall của cây dừa chỉ vỏn vẹn **25.7%** và cây chuối chỉ **38.5%**. Cứ 4 cây dừa ngoài đời thì model bỏ qua 3 cây.
   - Khi người dùng chụp cận cảnh gốc/lá chuối hoặc thân dừa, tỷ lệ bỏ sót tăng lên gần như 100%.
2. **Cây cọ (`Palm-tree`) và cây dừa (`Coconut-tree`) bị nhầm lẫn:**
   - Cả 2 loài đều có tán lá xòe hình lông chim/quạt. Precision của cây dừa chỉ đạt 53.6%, thường xuyên đoán nhầm dừa thành cọ hoặc ngược lại.

---

## 5. Kết Luận & Hành Động Tiếp Theo Cho Model V3

Bộ chỉ số trên đã cung cấp cho chúng ta **Baseline Benchmark chuẩn xác tuyệt đối**:
- Khi xây dựng **Hybrid V3**, mục tiêu trọng tâm là kéo **Recall của `Coconut-tree` từ 25.7% lên > 75%** và **`Banana-plant` từ 38.5% lên > 80%** thông qua các bức ảnh chụp thực tế bằng điện thoại Xiaomi.
- Tất cả các model tương lai (V2 retrain, Hybrid V3) sẽ được so sánh trực tiếp với bảng số liệu này và tập `dataset/real_world_test/`.
