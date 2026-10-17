# Hướng Dẫn Gán Nhãn Thủ Công (Human Annotation Guide)

Dự án: **Plant AI Detector (Hybrid V3 Pipeline)**  
Mục đích: Chuẩn hóa quy trình gán nhãn thủ công (Human-Verified Ground Truth) cho toàn bộ tập dữ liệu chụp thực tế từ điện thoại, loại bỏ hoàn toàn việc dùng AI tự sinh nhãn sai lệch.

---

## 1. Nguyên Tắc Cốt Lõi (Golden Rules)

1. **TUYỆT ĐỐI KHÔNG DÙNG MODEL V1 ĐỂ AUTO-LABEL:** 
   - Bài học từ việc Model V2 bị thổi phồng điểm số ảo (94% mAP) nhưng thực tế nhận diện sai ngoài đời là do dùng Model V1 tự sinh nhãn (pseudo-labeling).
   - Tập dữ liệu chụp từ điện thoại **phải được con người trực tiếp kiểm tra và đóng khung từng đối tượng**.
2. **NHÃN THỰC TẾ LÀ CHÂN LÝ (GROUND TRUTH TUYỆT ĐỐI):**
   - Mọi bounding box trong tập dữ liệu mới phải được vẽ cẩn thận, ôm sát thân/tán cây.

---

## 2. Bảng Mã Định Danh 12 Lớp Cố Định (Fixed Class Mapping)

Bắt buộc tuân thủ thứ tự và ID cố định từ [dataset/classes.yaml](file:///d:/plant_detector_app/plant_detector_app/dataset/classes.yaml):

| Class ID | Class Name (YOLO) | Tên Tiếng Việt | Đặc điểm nhận dạng chính |
| :---: | :--- | :--- | :--- |
| `0` | `Acacia` | Cây Keo / Tràm | Lá hình lưỡi liềm (lá giả) hoặc lá kép lông chim nhỏ, hoa bông vàng. |
| `1` | `Bamboo-shoots` | Măng Tre / Cây Tre | Thân đốt tròn rỗng màu xanh/vàng, mọc thành bụi dày. |
| `2` | `Banana-plant` | Cây Chuối | Thân giả, phiến lá to dài hình bầu dục, buồng chuối/hoa chuối. |
| `3` | `Banyan-Tree` | Cây Đa | Tán lá sum suê, rễ phụ buông rủ từ cành xuống đất. |
| `4` | `Coconut-tree` | Cây Dừa | Thân đơn độc thẳng tắp không cành, lá lông chim xẻ dài tập trung ở ngọn, buồng dừa. |
| `5` | `Mango-Tree` | Cây Xoài | Tán tròn sum suê, lá non màu tía đỏ sau chuyển xanh đậm dai bóng, mép gợn sóng. |
| `6` | `Neem-Tree` | Cây Sầu Đâu / Neem | Lá kép lông chim lẻ, mép lá có răng cưa nhọn rất rõ. |
| `7` | `Palm-tree` | Cây Cọ | Thân tròn xù xì, lá xòe tròn hình quạt có gai ở cuống lá. |
| `8` | `Papaya-Tree` | Cây Đu Đủ | Thân mềm có sẹo cuống lá, lá xẻ thùy chân vịt sâu 7-9 thùy, quả bám quanh thân. |
| `9` | `Pine` | Cây Thông | Lá hình kim mọc thành chùm 2-3 lá, quả nón hóa gỗ. |
| `10` | `lemon tree` | Cây Chanh | Cây bụi nhỏ, cành có gai nhọn, lá có mùi thơm tinh dầu, quả tròn mọng nước. |
| `11` | `peepal tree` | Cây Bồ Đề | Lá hình trái tim với chóp lá kéo dài thành đuôi nhọn đặc trưng. |

---

## 3. Quy Tắc Vẽ Bounding Box Chuẩn Xác

Khi sử dụng công cụ gán nhãn (Roboflow, LabelImg, CVAT hoặc AnyLabeling):

### 3.1. Độ vừa vặn của hộp (Snug Fit)
- **Vừa vặn:** Bounding box phải ôm sát tán lá và thân cây.
- **Không cắt xén:** Không được cắt mất các tán lá xòe hoặc thân chính của cây.
- **Không quá rộng:** Không vẽ bounding box quá rộng bao la bao trùm cả khoảng sân, bầu trời hoặc bức tường trống xung quanh.

### 3.2. Xử lý nhiều cây trong cùng 1 bức ảnh (Multi-Instance)
- Nếu trong ảnh có **nhiều cá thể cây cùng loài** (ví dụ: bụi chuối có 3 cây chuối tách biệt, hoặc hàng cây dừa có 2 cây):
  - **Bắt buộc vẽ 2 hoặc 3 bounding box riêng biệt** cho từng cây.
  - Tuyệt đối **KHÔNG** vẽ 1 hộp khổng lồ gộp cả hàng cây lại.

### 3.3. Xử lý nhiều loài trong cùng 1 bức ảnh (Multi-Class)
- Nếu trong ảnh có đồng thời cây dừa và cây chuối trồng cạnh nhau:
  - Đóng hộp cây dừa với nhãn `Coconut-tree` (Class 4).
  - Đóng hộp cây chuối với nhãn `Banana-plant` (Class 2).

### 3.4. Xử lý ảnh bị che khuất (Occlusion) & Cắt mép (Truncation)
- **Cắt mép ảnh:** Nếu cây mọc tràn ra ngoài rìa bức ảnh, kéo cạnh của bounding box ra sát đúng mép ảnh.
- **Bị che khuất:** Nếu cây bị cột điện, tường rào che khuất một phần:
  - Nếu phần nhìn thấy còn **> 30%** và nhận diện rõ nét loài cây -> Vẫn đóng hộp bao trùm phần nhìn thấy của cây đó.
  - Nếu bị che khuất quá **> 70%** hoặc quá xa mờ nhạt -> Không gán nhãn (bỏ qua).

### 3.5. Xử lý ảnh nghi ngờ / Không rõ loài (Review Policy)
- Nếu gặp một bức ảnh không chắc chắn 100% thuộc loài nào trong 12 class:
  - **Tuyệt đối không đoán mò.**
  - Chuyển ảnh đó vào thư mục riêng `review/` để tham khảo ý kiến hoặc loại bỏ khỏi tập dữ liệu.

---

## 4. Định Dạng File Nhãn YOLO (.txt)

Mỗi file ảnh `example.jpg` sẽ đi kèm đúng 1 file nhãn `example.txt` nằm trong thư mục `labels/`.  
Mỗi dòng trong file `.txt` đại diện cho một bounding box, định dạng:
```text
<class_id> <x_center> <y_center> <width> <height>
```
Trong đó:
- `class_id`: Số nguyên từ `0` đến `11` khớp với bảng danh mục trên.
- `x_center`, `y_center`: Tọa độ tâm của bounding box (chuẩn hóa từ `0.0` đến `1.0`).
- `width`, `height`: Chiều rộng và chiều cao của bounding box (chuẩn hóa từ `0.0` đến `1.0`).

Ví dụ nội dung file nhãn có 2 cây:
```text
2 0.450123 0.620456 0.350124 0.720890
4 0.820456 0.350123 0.280124 0.650124
```
*(Nếu là ảnh nền / negative sample không có cây nào: File `.txt` để rỗng dung lượng 0 bytes).*
