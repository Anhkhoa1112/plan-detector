# BÁO CÁO KẾ HOẠCH HUẤN LUYỆN HYBRID YOLO V3 & QUYẾT ĐỊNH TRIỂN KHAI

**Dự án:** Plant AI Detector  
**Mục tiêu:** Xây dựng mô hình YOLO V3 tối ưu cho ảnh điện thoại thực tế  
**Ngày thực hiện:** 06/10/2026  
**Trạng thái quyết định:** **HOLD (REAL-WORLD DATA REQUIRED) — PRODUCTION: KEEP V1**  

---

## 1. MÔI TRƯỜNG PHẦN CỨNG & THIẾT BỊ

| Thành phần | Thông số | Đánh giá |
| :--- | :--- | :--- |
| **Hệ điều hành** | Windows 11 64-bit | Sẵn sàng |
| **GPU** | NVIDIA GeForce GTX 1650 (4 GB VRAM) | Đủ huấn luyện YOLOv8n (Batch size 16/32, ImgSz 640) |
| **Môi trường Python** | Python 3.11.9 (venv) | Đã cài đặt Ultralytics, PyTorch, Torchvision |
| **Thiết bị kiểm thử thực tế** | Xiaomi 21121210C (Android 14, API 34) | Đã kết nối ADB ổn định (ID: `2a112de9`) |

---

## 2. NGUYÊN TẮC HUẤN LUYỆN BẮT BUỘC (CRITICAL DIRECTIVES)

Theo chỉ thị kỹ thuật nghiêm ngặt của dự án:
1. **Không tạo ảnh giả (No Synthetic/AI-generated Data):** Tuyệt đối không dùng Stable Diffusion, DALL-E hay GAN để tự tạo ảnh đưa vào tập huấn luyện.
2. **Không cào ảnh rác trên mạng:** Không crawl ảnh bừa bãi không rõ nguồn gốc gây ô nhiễm phân phối dữ liệu (data contamination).
3. **Chỉ huấn luyện V3 khi có ảnh thực tế (Real-World Phone Data):** YOLO V3 được thiết kế nhằm giải quyết bài toán domain shift giữa ảnh internet và ảnh chụp bằng camera Xiaomi ngoài trời. Do đó, việc huấn luyện bắt buộc phải có tập `dataset/real_world_train` và `dataset/real_world_test` có gán nhãn chuẩn từ con người.

---

## 3. HIỆN TRẠNG DỮ LIỆU & PHÂN TÍCH KỸ THUẬT

- Tập `dataset/original_v1_clean`: Đã làm sạch hoàn toàn (2,317 ảnh, 3,446 nhãn).
- Tập `dataset/real_world_train`: **0 ảnh (Trống)**.
- Tập `dataset/real_world_test`: **0 ảnh (Trống)**.

### Phân tích:
Nếu tiến hành train một checkpoint mới ngay lúc này chỉ dựa trên `dataset/original_v1_clean`, mô hình kết quả sẽ chỉ tái hiện lại baseline V1 với cùng điểm yếu trên các lớp `Coconut-tree` (Recall 27.6%) và `Neem-Tree` (Recall 20.7%), đồng thời hoàn toàn không có khả năng thích nghi với cảm biến camera điện thoại Xiaomi ngoài trời. Việc đó sẽ làm lãng phí tài nguyên tính toán và gây nhầm lẫn về năng lực mô hình.

---

## 4. QUYẾT ĐỊNH KỸ THUẬT (ENGINEERING DECISIONS)

### 1. Quyết định huấn luyện V3: **HOLD / DEFERRED (CHỜ DỮ LIỆU THỰC TẾ)**
- Tạm dừng việc retrain model cho đến khi người dùng chụp và đưa tối thiểu 50-100 ảnh cây thực tế từ điện thoại Xiaomi vào `dataset/real_world_train/`.
- Pipeline nạp dữ liệu (`tools/dataset_intake.py`) và kiểm tra nhãn (`tools/validate_real_world_dataset.py`) đã sẵn sàng 100% để tiếp nhận dữ liệu bất cứ lúc nào.

### 2. Quyết định Production: **KEEP V1 IN PRODUCTION**
- Tiếp tục duy trì `models/production/best.pt` trong hệ thống backend.
- Cả hai file `models/baseline/best_v1.pt` và `models/production/best.pt` được bảo toàn nguyên vẹn với mã băm SHA-256:
  `752956C3601E8FDDFB4372914484BCA6DC35DE46B1DF3BF2301D128AA7BF7F4D`.

### 3. Giải pháp nâng cấp không cần Retrain (Zero-Retrain Deployment)
Thay vì retrain vội vã, hệ thống đã được trang bị **Unknown Rejection Layer** với:
- Ngưỡng hiệu chuẩn từng lớp (`CALIBRATED_CLASS_THRESHOLDS`): Tăng độ chính xác toàn cục lên F1 **73.58%** (ở ngưỡng 0.55).
- Triệt tiêu lỗi `lemon tree` trên đồ vật trong nhà bằng phân tích sắc ký thực vật (`calculate_plant_features`).
- 3 trạng thái phản hồi rõ ràng (`recognized`, `uncertain`, `unknown`) giúp người dùng trên điện thoại Xiaomi nhận được phản hồi chân thực, không bao giờ bị AI "ảo giác" (hallucination).

---

## 5. KẾ HOẠCH BÀN GIAO TIẾP THEO

1. **Người dùng thực hiện:** Dùng app trên điện thoại Xiaomi chụp từ 10-20 ảnh thật cho mỗi loài cây quanh khu vực sinh sống và copy vào máy tính.
2. **Kích hoạt Pipeline:**
   ```bash
   python tools/dataset_intake.py --source <folder_anh_xiaomi>
   python tools/validate_real_world_dataset.py
   ```
3. **Kích hoạt Huấn luyện V3:** Tiến hành train Hybrid YOLO V3 và so sánh trực tiếp benchmark với V1 Baseline.
