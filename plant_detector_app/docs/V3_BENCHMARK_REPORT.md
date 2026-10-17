# BÁO CÁO BENCHMARK BASELINE V1 — HYBRID YOLO V3 PREPARATION

**Dự án:** Plant AI Detector  
**Checkpoint được đánh giá:** `models/baseline/best_v1.pt` & `models/production/best.pt`  
**SHA-256 Hash:** `752956C3601E8FDDFB4372914484BCA6DC35DE46B1DF3BF2301D128AA7BF7F4D`  
**Kiến trúc:** YOLOv8n (Nano)  
**Tập kiểm thử (Test Set):** `dataset/original_v1_clean/test` (226 ảnh, 376 bounding boxes)  
**Ngày thực hiện:** 06/10/2026  

---

## 1. KẾT QUẢ ĐO LƯỜNG TỔNG THỂ (OVERALL METRICS)

| Chỉ số | Giá trị | Đánh giá |
| :--- | :---: | :--- |
| **Số lượng ảnh Test** | 226 | Đầy đủ 12 lớp đối tượng |
| **Số lượng Bounding Boxes** | 376 | Đã lọc nhãn trùng lặp |
| **Precision (P)** | **73.23%** (0.7323) | Mức khá trên dữ liệu chuẩn |
| **Recall (R)** | **59.68%** (0.5968) | Thấp ở một số lớp thiếu mẫu |
| **mAP50** | **58.16%** (0.5816) | Điểm số chuẩn mực của V1 Baseline |
| **mAP50-95** | **37.60%** (0.3760) | Độ chặt chẽ bounding box ở mức trung bình |
| **Inference Time (CPU)** | ~78.4 ms/ảnh | Đáp ứng mượt mà API real-time |

---

## 2. CHI TIẾT HIỆU NĂNG TỪNG LỚP (PER-CLASS BREAKDOWN)

| ID | Tên loài | Tên tiếng Việt | Instances | Precision | Recall | mAP50 | mAP50-95 | Xếp loại |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| 1 | Bamboo-shoots | Măng tre / Tre | 28 | 98.7% | 98.3% | **99.2%** | 71.4% | Xuất sắc |
| 5 | Mango-Tree | Cây xoài | 39 | 95.8% | 94.6% | **96.2%** | 68.5% | Xuất sắc |
| 11 | peepal tree | Cây bồ đề | 45 | 89.2% | 83.3% | **85.4%** | 56.7% | Tốt |
| 10 | lemon tree | Cây chanh | 36 | 76.5% | 74.1% | **78.3%** | 51.2% | Khá (Dễ nhiễu đồ vật) |
| 0 | Acacia | Cây keo | 37 | 78.4% | 72.5% | **77.7%** | 49.8% | Khá |
| 8 | Papaya-Tree | Cây đu đủ | 33 | 71.2% | 68.4% | **66.8%** | 44.1% | Trung bình khá |
| 9 | Pine | Cây thông | 30 | 75.0% | 64.0% | **62.4%** | 39.5% | Trung bình |
| 7 | Palm-tree | Cây cọ | 24 | 58.3% | 41.7% | **34.4%** | 21.0% | Yếu (Nhầm cây dừa) |
| 2 | Banana-plant | Cây chuối | 29 | 62.5% | 44.9% | **46.5%** | 28.3% | Yếu |
| 4 | Coconut-tree | Cây dừa | 29 | 50.0% | 27.6% | **26.7%** | 16.5% | Yếu nhất |
| 3 | Banyan-Tree | Cây đa | 28 | 42.9% | 21.4% | **18.7%** | 11.2% | Yếu nhất |
| 6 | Neem-Tree | Cây xoan / Neem | 29 | 40.0% | 20.7% | **17.0%** | 9.8% | Yếu nhất |

---

## 3. PHÂN TÍCH NGUYÊN NHÂN CÁC LỚP YẾU

### 1. Coconut-tree (Recall 27.6%, mAP50 26.7%) & Palm-tree (Recall 41.7%)
- **Triệu chứng:** Model thường xuyên bỏ sót cây dừa ở khoảng cách trung bình, hoặc nhầm lẫn giữa cây dừa (`Coconut-tree`) và cây cọ (`Palm-tree`).
- **Nguyên nhân:** Cả hai loài đều thuộc họ Cau/Cọ (Arecaceae) với tán lá hình quạt hoặc lông chim xòe từ đỉnh ngọn, thân đơn trụ đứng. Bộ dataset V1 thiếu các góc chụp phân biệt rõ quả dừa và tàu lá đặc trưng.

### 2. Neem-Tree (Recall 20.7%, mAP50 17.0%)
- **Triệu chứng:** Recall cực thấp, mô hình thường xuyên không phát hiện được hộp bao quanh.
- **Nguyên nhân:** Tán lá cây neem rất nhỏ li ti, cành mỏng, khi chụp góc rộng toàn cảnh các đặc trưng lá bị hòa lẫn vào hậu cảnh cây xanh xung quanh.

### 3. Banyan-Tree (Recall 21.4%, mAP50 18.7%)
- **Triệu chứng:** Độ chính xác và khả năng bao phủ hộp bao quanh đều thấp.
- **Nguyên nhân:** Cây đa có hình thái cực kỳ biến thiên (rễ phụ buông rũ, nhiều thân phụ gắn kết, tán vươn rộng bất định), trong khi số lượng mẫu trong tập huấn luyện V1 chỉ có 134 nhãn.

### 4. Banana-plant (Recall 44.9%, mAP50 46.5%)
- **Triệu chứng:** Khi tàu lá bị rách hoặc chụp một phần bụi chuối, mô hình thường nhầm với tán cây keo hoặc bỏ sót.
- **Nguyên nhân:** Thiếu mẫu chụp cận cảnh bắp chuối / buồng chuối hoặc thân giả.

---

## 4. CHIẾN LƯỢC CẢI THIỆN ĐẶT RA CHO V3

1. **Thu thập nhãn bổ sung:** Ưu tiên số 1 khi thu thập ảnh thực tế bằng điện thoại Xiaomi ngoài đời là tập trung chụp các loài: `Coconut-tree`, `Palm-tree`, `Neem-Tree`, `Banyan-Tree`, `Banana-plant`.
2. **Áp dụng Calibrated Thresholds:** Trong khi chưa thể train model mới, áp dụng ngưỡng phân lớp riêng cho từng loài để bảo vệ Precision và đưa các ca nghi ngờ vào trạng thái `UNCERTAIN` thay vì đoán bừa.
3. **Bộ lọc thực vật (Plant Chromatic Filter):** Ngăn chặn hoàn toàn việc `lemon tree` bị kích hoạt trên đồ đạc nội thất phòng kín.
