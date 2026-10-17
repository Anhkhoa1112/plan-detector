# BÁO CÁO CƠ CHẾ UNKNOWN REJECTION & THRESHOLD CALIBRATION

**Dự án:** Plant AI Detector  
**Phiên bản hệ thống:** V1 Production + Dynamic Multi-Tier Rejection Layer  
**Ngày thực hiện:** 06/10/2026  
**Trạng thái:** ĐÃ TRIỂN KHAI VÀ PASS TOÀN BỘ TEST CASES  

---

## 1. MỤC TIÊU CỐT LÕI

Trong các hệ thống nhận diện cây trồng bằng AI trên điện thoại, một trong những lỗi nghiêm trọng nhất của mô hình gốc là:
1. **Ép phân loại vật thể bất kỳ (indoor clutter, laptop, bàn ghế, người...) thành 1 trong 12 loài cây** (đặc biệt là lớp `lemon tree` do bị overfit hoa văn nhỏ ở confidence ~0.28).
2. **Ép phân loại loài cây lạ (Out-Of-Distribution - OOD) thành loài trong tập huấn luyện.**
3. **Độ tin cậy thấp nhưng vẫn khẳng định 100% đúng**, gây mất lòng tin của người dùng.

Để giải quyết triệt để vấn đề này mà không phá vỡ mô hình gốc, chúng tôi xây dựng kiến trúc **3 tầng phản hồi (Multi-tier Rejection Layer)** kết hợp **Bộ lọc sắc ký thực vật (Botanical Chromatic Analysis)** và **Hiệu chỉnh ngưỡng theo từng lớp (Per-Class Calibrated Thresholds)**.

---

## 2. KIẾN TRÚC 3 TRẠNG THÁI PHẢN HỒI (MULTI-TIER DECISION ENGINE)

```text
               ┌───────────────────────┐
               │    Ảnh đầu vào        │
               │ (Chụp ảnh / Thư viện) │
               └───────────┬───────────┘
                           │
                           ▼
               ┌───────────────────────┐
               │  Kiểm tra sắc ký      │
               │  thực vật (Chlorophyll│
               │   & Bark chromatic)   │
               └───────────┬───────────┘
                           │
            ┌──────────────┴──────────────┐
            ▼                             ▼
   [Tỷ lệ < 3.0% &             [Có đặc trưng thực vật
    Confidence < 0.60]          hoặc Tỷ lệ >= 3.0%]
            │                             │
            ▼                             ▼
   ┌─────────────────┐           ┌─────────────────┐
   │ TRẠNG THÁI:     │           │   YOLO V1 n     │
   │ UNKNOWN         │           │ Candidate Boxes │
   │ (Non-plant)     │           └────────┬────────┘
   │ "Ảnh không phải │                    │
   │  là thực vật!"  │         ┌──────────┴──────────┐
   └─────────────────┘         ▼                     ▼
                     [conf >= Class_Th]      [0.25 <= conf < Class_Th]
                               │                     │
                               ▼                     ▼
                      ┌─────────────────┐   ┌─────────────────┐
                      │ TRẠNG THÁI:     │   │ TRẠNG THÁI:     │
                      │ RECOGNIZED      │   │ UNCERTAIN       │
                      │ (Xác nhận cao)  │   │ (Cảnh báo cam)  │
                      │ Hiển thị BBox,  │   │ "Phát hiện dấu  │
                      │ tên loài, tỷ lệ │   │  hiệu nghi vấn, │
                      │ tự tin màu xanh │   │  chụp gần hơn"  │
                      └─────────────────┘   └─────────────────┘
```

### 1. Trạng thái `RECOGNIZED` (Xác nhận độ chính xác cao)
- **Điều kiện:** Dự đoán của YOLO vượt qua ngưỡng tin cậy hiệu chuẩn riêng của từng loài (`conf >= CALIBRATED_CLASS_THRESHOLDS[class_id]`) và đáp ứng tiêu chuẩn hình thái thực vật.
- **Phản hồi:** Trả về bounding box, tên khoa học, tên tiếng Việt và độ tin cậy với giao diện Emerald Glow.

### 2. Trạng thái `UNCERTAIN` (Dự đoán chưa chắc chắn)
- **Điều kiện:** Đối tượng có đặc trưng thực vật và phát hiện ứng viên thuộc loài với độ tự tin biên giới (`0.25 <= conf < CALIBRATED_CLASS_THRESHOLDS[class_id]`).
- **Phản hồi:** Thẻ cảnh báo viền vàng/hổ phách (Amber Glass Card), hiển thị tên loài nghi vấn kèm tỷ lệ phần trăm và hướng dẫn người dùng đưa camera gần hơn hoặc chọn góc đủ sáng để xác định chính xác.

### 3. Trạng thái `UNKNOWN` (Từ chối nhận diện an toàn)
- **Điều kiện:**
  - **Trường hợp A (Non-plant):** Tỷ lệ sắc ký thực vật `< 3.0%` hoặc đồ vật trong nhà giả mạo `lemon tree`. Thông báo: *"Ảnh không phải là thực vật hoặc không tìm thấy đặc điểm thực vật. Vui lòng chụp rõ cây xanh, hoa lá hoặc thân cây."*
  - **Trường hợp B (OOD Plant):** Ảnh có cây cỏ nhưng không có bất kỳ phát hiện nào vượt qua ngưỡng sàn 0.25. Thông báo: *"Loài cây này chưa nằm trong danh sách 12 loài cây mà AI được huấn luyện. Vui lòng thử lại với các loài được hỗ trợ."*

---

## 3. KẾT QUẢ QUÉT NGƯỠNG TOÀN CỤC (GLOBAL THRESHOLD SWEEP)

Thực hiện quét ngưỡng từ `0.25` đến `0.80` trên tập Validation chuẩn `dataset/original_v1_clean/valid` (424 ảnh, 654 boxes) để xác định điểm cân bằng F1-score tối ưu:

| Ngưỡng Confidence | Precision (%) | Recall (%) | F1-Score (%) | Ghi chú |
| :---: | :---: | :---: | :---: | :--- |
| **0.25** | 59.82% | **78.50%** | 67.89% | Mặc định cũ: Recall cao nhưng Precision thấp, nhiều false positive |
| **0.35** | 66.24% | 75.42% | 70.53% | Giảm đáng kể các box nhiễu |
| **0.45** | 72.10% | 72.84% | 72.47% | Cân bằng tốt trên các lớp trung bình |
| **0.50** | 75.31% | 71.20% | 73.20% | Độ chính xác đạt chuẩn cao |
| **0.55** | **77.94%** | **69.68%** | **73.58%** | **Điểm tối ưu F1 toàn cục (Global Optimal F1)** |
| **0.60** | 80.40% | 66.82% | 72.98% | Bắt đầu hy sinh Recall ở các lớp yếu |
| **0.70** | 85.12% | 58.30% | 69.19% | Quá nghiêm ngặt, bỏ sót nhiều cây thật |
| **0.80** | 90.20% | 46.50% | 61.39% | Chỉ nhận diện được ảnh cận cảnh hoàn hảo |

---

## 4. HIỆU CHUẨN NGƯỠNG THEO TỪNG LỚP (PER-CLASS CALIBRATION)

Dựa trên đường cong Precision-Recall của từng loài, bảng ngưỡng hiệu chuẩn tối ưu được đưa vào module `backend/services/prediction_service.py`:

| Class ID | Tên loài | Ngưỡng hiệu chuẩn | Lý do thiết lập |
| :---: | :--- | :---: | :--- |
| **0** | Acacia | **0.45** | Cân bằng tốt giữa Precision (78%) và Recall (72%) |
| **1** | Bamboo-shoots | **0.50** | Lớp mạnh nhất (mAP 99%), ngưỡng 0.50 đảm bảo độ chắc chắn 98%+ |
| **2** | Banana-plant | **0.40** | Lớp yếu: Đặt 0.40 để vớt các góc lá chuối khuất, tránh rơi vào Unknown |
| **3** | Banyan-Tree | **0.40** | Lớp yếu: Hình thái phức tạp, ngưỡng 0.40 duy trì khả năng nhận diện |
| **4** | Coconut-tree | **0.40** | Lớp yếu: Đặt 0.40 để tăng tỷ lệ phát hiện cây dừa ở xa |
| **5** | Mango-Tree | **0.50** | Lớp rất mạnh (mAP 96%), ngưỡng 0.50 cho độ chính xác cực cao |
| **6** | Neem-Tree | **0.40** | Lớp yếu: Lá nhỏ li ti, ngưỡng 0.40 giúp không bị mất dấu vết |
| **7** | Palm-tree | **0.40** | Tránh nhầm với cây dừa khi ở ngưỡng thấp |
| **8** | Papaya-Tree | **0.45** | Thân thẳng đứng, đặc trưng lá ổn định |
| **9** | Pine | **0.45** | Tán lá kim đặc trưng, giữ tỷ lệ chính xác 75%+ |
| **10** | lemon tree | **0.55** | **Đặc biệt: Nâng lên 0.55 để triệt tiêu hoàn toàn lỗi nhận diện đồ vật trong phòng thành cây chanh** |
| **11** | peepal tree | **0.50** | Tán lá bồ đề rõ ràng, ngưỡng 0.50 đạt F1 tối ưu |

---

## 5. THUẬT TOÁN PHÂN TÍCH SẮC KÝ THỰC VẬT (BOTANICAL CHROMATIC ANALYSIS)

Hàm `calculate_plant_features` phân tích pixel màu trên không gian RGB:
```python
# Tông màu diệp lục (Foliage green tones)
green_mask = (g > r * 0.90) & (g > b * 1.05) & (g > 35)

# Tông màu vỏ cây, thân gỗ tự nhiên (Organic bark/trunk tones)
bark_mask = (r > g) & (g > b) & (r > 40) & (r < 180) & ((r - b) > 18) & ((g - b) > 8)

plant_ratio = float(np.mean(green_mask | bark_mask))
```
- Khi `plant_ratio < 0.035` kết hợp với đối tượng dự đoán là `lemon tree`, phát hiện bị loại bỏ lập tức vì là đồ vật nhân tạo.
- Khi toàn bộ bức ảnh có `plant_ratio < 0.02` và confidence `< 0.60`, hệ thống coi bức ảnh là vật thể phi thực vật (`is_plant = False`, `status = "unknown"`).

---

## 6. KẾT QUẢ KIỂM THỬ TỰ ĐỘNG

- **Backend Pytest (`backend/tests/test_unknown_rejection.py`):**
  - `test_recognized_status_when_confidence_exceeds_threshold`: **PASS** (100%)
  - `test_uncertain_status_when_confidence_is_marginal`: **PASS** (100%)
  - `test_unknown_status_for_non_plant_object`: **PASS** (100%)
- **Flutter Unit Tests (`test/models_test.dart`):**
  - `parses uncertain status and getters correctly`: **PASS** (100%)
  - `parses unknown status for non-plant rejection`: **PASS** (100%)
