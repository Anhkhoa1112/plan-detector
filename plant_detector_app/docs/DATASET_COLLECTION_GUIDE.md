# Hướng Dẫn Thu Thập Ảnh Thực Tế (Dataset Collection Guide)

Dành cho thiết bị: Điện thoại Xiaomi (Android 14) hoặc Smartphone tương đương  
Dự án: **Plant AI Detector (Hybrid V3 Pipeline)**  
Ngày cập nhật: 06/10/2026

---

## 1. Mức Độ Ưu Tiên Các Loài Cây (Class Priority)

Dựa trên kết quả Benchmark độc lập của Baseline Model V1 (xem [docs/MODEL_EVALUATION_REPORT.md](file:///d:/plant_detector_app/plant_detector_app/docs/MODEL_EVALUATION_REPORT.md)), một số loài cây đang có tỷ lệ bỏ sót (Recall) cực kỳ nghiêm trọng. Khi chụp ảnh, **bắt buộc phải ưu tiên thu thập theo thứ tự sau**:

### 🔴 NHÓM ƯU TIÊN CAO (HIGH PRIORITY) - BẮT BUỘC CHỤP NHIỀU NHẤT
| Class Name | Tên Tiếng Việt | Recall Baseline | Đánh giá hiện trạng |
| :--- | :--- | :---: | :--- |
| **`Coconut-tree`** | Cây Dừa | **25.7%** | **BÁO ĐỘNG ĐỎ:** Cứ 4 cây dừa ngoài đời thì model bỏ qua 3 cây. Rất dễ nhầm với cây cọ. |
| **`Banana-plant`** | Cây Chuối | **38.6%** | **BÁO ĐỘNG:** Bỏ sót hơn 61% cá thể chuối. Cần chụp cả bụi chuối, buồng chuối và phiến lá to. |
| **`Banyan-Tree`** | Cây Đa | **41.8%** | **KÉM:** Nhận diện thân rễ phụ và tán lá rất yếu. |

### 🟡 NHÓM ƯU TIÊN TRUNG BÌNH (MEDIUM PRIORITY)
| Class Name | Tên Tiếng Việt | Recall Baseline | Ghi chú thu thập |
| :--- | :--- | :---: | :--- |
| **`lemon tree`** | Cây Chanh | 75.5% | Chụp chậu cây chanh, cành có gai, chùm quả xanh/vàng. |
| **`Mango-Tree`** | Cây Xoài | 85.2% | Chụp lá tía non, hoa chùm và quả xoài. |
| **`Papaya-Tree`** | Cây Đu Đủ | 87.5% | Chụp quả bám quanh thân và cuống lá xẻ thùy. |
| **`Neem-Tree`** | Cây Sầu Đâu / Neem | 60.6% | Chụp lá răng cưa kép lông chim đặc trưng. |

### 🟢 NHÓM BÌNH THƯỜNG (NORMAL PRIORITY)
Các loài còn lại: **`Acacia`** (Keo/tràm), **`Bamboo-shoots`** (Măng/tre), **`Palm-tree`** (Cây cọ), **`Pine`** (Thông), **`peepal tree`** (Bồ đề).

---

## 2. Tiêu Chuẩn Mục Tiêu Số Lượng Ảnh

> **NGUYÊN TẮC BẤT DI BẤT DỊCH:** Tuyệt đối **KHÔNG** copy ảnh từ Real-World Test sang Real-World Train để lấp số lượng. Hai tập này phải độc lập 100%.

* **Tập Real-World Test Set (`dataset/real_world_test/`):**
  * **Mục tiêu:** **150 – 200 ảnh** (khoảng 12 – 18 ảnh / class).
  * Tập trung nhiều hơn vào 3 class ưu tiên cao (`Coconut-tree`, `Banana-plant`, `Banyan-Tree`).
  * Chỉ dùng để kiểm thử khách quan, không bao giờ dùng để huấn luyện.
* **Tập Real-World Train Set (`dataset/real_world_train/`):**
  * **Mục tiêu:** **300 – 500 ảnh** (khoảng 25 – 45 ảnh / class).
  * Dùng để phối trộn cùng `dataset/original_v1_clean/` tạo thành bộ dữ liệu Hybrid V3.

---

## 3. Quy Chuẩn Kỹ Thuật Khi Chụp Ảnh

Để AI không bị thiên lệch, mỗi cây bắt buộc phải được chụp đa dạng theo các ma trận sau:

### 3.1. Khoảng cách chụp (6 mốc bắt buộc)
Không được chỉ chụp toàn bộ cây từ xa hoặc chỉ dí sát vào một chiếc lá. Hãy chia đều các khoảng cách:
1. **0.3m:** Cực cận cảnh vân lá, gân lá, răng cưa mép lá, gai nhọn hoặc hoa nhỏ.
2. **0.5m:** Cận cảnh một chùm lá, nhánh cành hoặc chùm quả.
3. **1.0m:** Trung cảnh bao quát một nhánh cây lớn, chậu cây cảnh hoặc thân cây.
4. **1.5m:** Cự ly sử dụng điện thoại thông thường của người dùng đứng trước cây.
5. **2.0m:** Bao quát nửa trên thân cây hoặc toàn bộ bụi cây tầm thấp.
6. **3.0m:** Bao quát toàn cảnh cây từ mặt đất lên tới đỉnh ngọn.

### 3.2. Góc chụp đa hướng (5 góc)
1. **Chính diện:** Vuông góc với thân cây hoặc tán lá.
2. **Nghiêng trái (30° - 45°):** Cho thấy chiều sâu của tán cây.
3. **Nghiêng phải (30° - 45°):**
4. **Chụp hất từ dưới lên (Low-angle):** Đứng dưới gốc ngước lên thấy vòm lá và nền trời (đặc biệt hiệu quả cho dừa, cọ, thông).
5. **Chụp chúc từ trên xuống (High-angle):** Chụp các chậu cây, măng non hoặc tán lá thấp.

### 3.3. Nội dung trong khung hình (Content Priority)
Ưu tiên sắp xếp nội dung ảnh theo thứ tự:
1. **Toàn cây:** Thấy được dáng cây và thế cây.
2. **Cây ở khoảng cách trung bình:** Thấy được thân và nhánh tán chính.
3. **Cận cảnh chùm lá:** Cách các phiến lá mọc đan xen.
4. **Cận cảnh thân cây:** Vỏ cây, đốt tre, rễ phụ cây đa, vết sẹo cuống lá đu đủ.
5. **Cành & nhánh phụ:**
6. **Hoa / Quả:** (Nếu có) Quả dừa, quả xoài, quả đu đủ bám thân, quả chanh.

> ⚠️ **LƯU Ý:** Tuyệt đối không để toàn bộ dataset chỉ gồm ảnh lá chụp cận cảnh macro. AI Object Detection cần học cả dáng cây, cành và thân để định vị chính xác bounding box.

### 3.4. Điều kiện ánh sáng & Bối cảnh môi trường
* **Ánh sáng:** Đa dạng giữa:
  * Ánh sáng ban ngày nắng gắt.
  * Ánh sáng râm mát / chiều muộn.
  * Ánh sáng ngược nắng (chụp tán lá xuyên sáng).
  * Ánh sáng yếu / bóng râm trong hiên nhà.
* **Môi trường:**
  * Sân vườn gia đình, ban công chậu cảnh.
  * Công viên, đường phố đô thị, vườn ươm nông nghiệp.

---

## 4. Hướng Dẫn Cấu Hình Camera Xiaomi & Quy Trình Nạp Ảnh

1. **Cài đặt Camera Xiaomi:**
   * Tỷ lệ khung hình: **`4:3`** (độ phân giải tối đa).
   * Tắt tính năng đóng dấu: **Tắt Hình mờ thiết bị (Device Watermark)** và **Tắt Dấu thời gian**.
   * Chế độ màu: Tiêu chuẩn / Tự nhiên (không dùng filter làm đẹp).
   * Luôn **chạm vào màn hình để lấy nét (Tap to focus)** trước khi bấm chụp.
2. **Phân phối ảnh sau khi chụp:**
   * Chuyển ảnh từ điện thoại vào máy tính.
   * **150 – 200 ảnh độc lập đầu tiên** -> Copy vào:
     ```text
     dataset/real_world_test/<tên_class>/
     ```
   * **Các ảnh chụp bổ sung tiếp theo** -> Copy vào:
     ```text
     dataset/real_world_train/<tên_class>/
     ```
3. **Kiểm tra tự động sau khi nạp ảnh:**
   Sau khi chép ảnh, chạy 2 lệnh sau để kiểm tra lỗi file và độ cân bằng:
   ```bash
   .\venv\Scripts\python.exe tools/validate_real_world_dataset.py --dataset dataset/real_world_test
   .\venv\Scripts\python.exe tools/dataset_intake.py --dataset dataset/real_world_test
   ```
