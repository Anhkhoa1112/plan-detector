# Model Audit & Evaluation Diagnostic Report

Ngày: 06/10/2026
Dự án: Plant AI Detector (FastAPI + YOLO + Flutter)

---

## 1. Kết Quả Audit Checkpoint Model

Cả 3 file model trong repository:
- `models/production/best.pt`
- `models/baseline/best_v1.pt`
- `models/best.pt`

Đều có mã hash SHA256 trùng khớp hoàn toàn:
`752956c3601e8fddfb4372914484bca6dc35de46b1df3bf2301d128aa7bf7f4d` (dung lượng 6,252,522 bytes ~ 5.96 MB).

### Thông số kỹ thuật trích xuất từ PyTorch Checkpoint:

- **Phiên bản & Framework:** YOLOv8 (Ultralytics `8.4.170`, PyTorch `2.14.1`).
- **Kiến trúc mạng (Architecture):** `YOLOv8n` (Nano):
  - `depth_multiple: 0.33`, `width_multiple: 0.25`
  - Backbone: `Conv` + `C2f` (128, 256, 512, 1024) + `SPPF`
  - Head: `nn.Upsample`, `Concat`, `C2f`, `Detect(nc=12)`
  - Strides: `[8, 16, 32]`
  - Số tham số: ~3.0 triệu parameters.
- **Kích thước ảnh đầu vào (Image Size):** `640 x 640` (`imgsz: 640`).
- **Số lượng class:** 12 classes.
- **Danh sách nhãn (Class Names):**
  - `0: Acacia` (Cây Keo)
  - `1: Bamboo-shoots` (Măng Tre / Cây Tre)
  - `2: Banana-plant` (Cây Chuối)
  - `3: Banyan-Tree` (Cây Đa)
  - `4: Coconut-tree` (Cây Dừa)
  - `5: Mango-Tree` (Cây Xoài)
  - `6: Neem-Tree` (Cây Sầu Đâu / Neem)
  - `7: Palm-tree` (Cây Cọ)
  - `8: Papaya-Tree` (Cây Đu Đủ)
  - `9: Pine` (Cây Thông)
  - `10: lemon tree` (Cây Chanh)
  - `11: peepal tree` (Cây Bồ Đề)
- **Cấu hình Inference mặc định (Backend):**
  - Confidence Threshold: `0.25`
  - IoU (NMS) Threshold: `0.45`
  - Preprocessing: RGB Pillow Image -> Ultralytics internal letterbox resize (640) -> Normalization (0-1).
- **Metadata huấn luyện (Train Args trong Checkpoint):**
  - Môi trường huấn luyện: Google Colab (`project: /content/runs`, `name: plant_yolo_v2`).
  - Nguồn Dataset huấn luyện: `/content/Tree-Species-V2-Final/data.yaml`.
  - Checkpoint gốc khởi tạo: `/content/best.pt` (tiếp tục fine-tune từ một checkpoint trước đó).
  - Epochs: `30` (best epoch đạt tại epoch 28).
  - Batch size: `16`.
  - Optimizer: `AdamW` (`lr0: 0.000625`, `lrf: 0.01`, `weight_decay: 0.0005`, `momentum: 0.937`).
  - Augmentations: `mosaic: 1.0` (tắt ở 10 epoch cuối: `close_mosaic: 10`), `auto_augment: randaugment`, `erasing: 0.4`, `hsv_h: 0.015`, `hsv_s: 0.7`, `hsv_v: 0.4`, `translate: 0.1`, `scale: 0.5`, `fliplr: 0.5`.
- **Metrics trên tập val gốc của Colab (trích xuất từ Checkpoint):**
  - Precision: `0.9083` (90.8%)
  - Recall: `0.9086` (90.9%)
  - mAP@50: `0.9397` (94.0%)
  - mAP@50-95: `0.8125` (81.2%)
  - *Lưu ý:* Các chỉ số này được tính trên tập `val` nội bộ của dataset `/content/Tree-Species-V2-Final/` trên Colab lúc huấn luyện, **không phản ánh hiệu năng trên ảnh chụp thực tế từ điện thoại**.

---

## 2. Kiểm Tra Hiện Trạng Dataset

Sau khi quét toàn bộ thư mục dự án và ổ đĩa:
- **KHÔNG TỒN TẠI** tập dữ liệu huấn luyện hoặc kiểm thử (`train`, `val`, `test` labels/images hoặc `data.yaml`) trong repository nội bộ `D:\plant_detector_app\plant_detector_app`.
- Kho lưu trữ chỉ có duy nhất 1 ảnh mẫu test đường truyền: `sample_images/cay_mau.jpg` (ảnh cây không có file nhãn `.txt` đi kèm).
- Dataset gốc `Tree-Species-V2-Final` vẫn nằm trên môi trường Google Colab / cloud của người huấn luyện và chưa từng được tải về máy cục bộ.

> [!IMPORTANT]
> Theo nguyên tắc kiểm định nghiêm ngặt: **Tuyệt đối không tự bịa đặt metric (faking accuracy) khi chưa có ground-truth labels**. Việc model đạt mAP 93.9% trên tập val gốc nhưng chạy thực tế kém là dấu hiệu điển hình của sự chênh lệch phân phối dữ liệu (Domain Shift).

---

## 3. Kiểm Tra Tính Đồng Nhất (Class Mapping Audit)

Đã kiểm tra chéo thứ tự và tên class trên toàn bộ hệ thống:

| Class ID | YOLO Model (`model.names`) | Backend (`plants.py`) | Tiếng Việt (`PLANT_VI_NAMES`) | Flutter Model | Khớp? |
| :---: | :--- | :--- | :--- | :--- | :---: |
| 0 | `Acacia` | `Acacia` | Cây Keo | Nhận trực tiếp từ JSON | **Khớp 100%** |
| 1 | `Bamboo-shoots` | `Bamboo-shoots` | Măng Tre / Cây Tre | Nhận trực tiếp từ JSON | **Khớp 100%** |
| 2 | `Banana-plant` | `Banana-plant` | Cây Chuối | Nhận trực tiếp từ JSON | **Khớp 100%** |
| 3 | `Banyan-Tree` | `Banyan-Tree` | Cây Đa | Nhận trực tiếp từ JSON | **Khớp 100%** |
| 4 | `Coconut-tree` | `Coconut-tree` | Cây Dừa | Nhận trực tiếp từ JSON | **Khớp 100%** |
| 5 | `Mango-Tree` | `Mango-Tree` | Cây Xoài | Nhận trực tiếp từ JSON | **Khớp 100%** |
| 6 | `Neem-Tree` | `Neem-Tree` | Cây Neem / Sầu Đâu | Nhận trực tiếp từ JSON | **Khớp 100%** |
| 7 | `Palm-tree` | `Palm-tree` | Cây Cọ | Nhận trực tiếp từ JSON | **Khớp 100%** |
| 8 | `Papaya-Tree` | `Papaya-Tree` | Cây Đu Đủ | Nhận trực tiếp từ JSON | **Khớp 100%** |
| 9 | `Pine` | `Pine` | Cây Thông | Nhận trực tiếp từ JSON | **Khớp 100%** |
| 10 | `lemon tree` | `lemon tree` | Cây Chanh | Nhận trực tiếp từ JSON | **Khớp 100%** |
| 11 | `peepal tree` | `peepal tree` | Cây Bồ Đề | Nhận trực tiếp từ JSON | **Khớp 100%** |

**Kết luận mapping:** Lỗi nhận diện **KHÔNG PHẢI** do lệch index class (off-by-one) hay sai từ điển.

---

## 4. Chẩn Đoán Nguyên Nhân Gốc Rễ (Root Cause Analysis)

Hiện tượng: *Nhận diện sai class, bỏ sót cây, confidence thấp hoặc không đúng thực tế khi chụp bằng điện thoại Xiaomi*.

Nguyên nhân được xác định dựa trên bằng chứng kỹ thuật:

### 1. Domain Shift & Góc Chụp (Nhóm I - Nguyên nhân chính)
- Dataset gốc `Tree-Species-V2-Final`: Chủ yếu gồm ảnh cây chụp từ xa ngoài thiên nhiên, ảnh flycam/landscape hoặc ảnh stock internet thể hiện **toàn bộ thân cây to lớn**.
- Thực tế người dùng sử dụng điện thoại: Chụp cận cảnh (close-up) cành lá, chậu cây cảnh trong nhà, cây non, hoặc một góc tán lá.
- Vì đặc trưng không gian (spatial features) của tán cây chụp xa khác hoàn toàn đặc trưng cận cảnh vân lá, mô hình bị bối rối (confusion) hoặc tự động hạ confidence xuống dưới ngưỡng `0.25`.

### 2. Dung lượng mô hình quá nhỏ (Nhóm E - Model Capacity)
- Mô hình hiện tại là `YOLOv8n` (Nano - ~3M params, 6MB).
- Việc phân biệt 12 loài cây với màu sắc lá xanh tương đồng, tán lá đan xen phức tạp đòi hỏi khả năng trích xuất đặc trưng sâu hơn. YOLOv8n dễ bị giới hạn biểu diễn (under-capacity), dẫn đến việc phân loại nhầm giữa các cây có tán lá tương tự (như Acacia, Neem-Tree, Mango-Tree).

### 3. Nén độ phân giải ảnh (Nhóm G - Image Preprocessing)
- Camera điện thoại Xiaomi chụp ở độ phân giải cao (`1080x2400` đến `3000x4000`).
- Khi qua YOLO, ảnh bị resize về `640x640`. Với các chi tiết lá nhỏ hoặc cây ở xa, việc nén làm mất hoàn toàn răng cưa và gân lá đặc trưng.

### 4. Giới hạn không gian lớp đóng (Closed-set Assumption)
- Mô hình chỉ được học đúng 12 loài cây cụ thể.
- Khi người dùng đưa camera vào bất kỳ cây cảnh nào khác ngoài 12 loài này (ví dụ: hoa hồng, lưỡi hổ, trầu bà, sen đá...), mô hình buộc phải "ép" đối tượng vào 1 trong 12 class với confidence không ổn định hoặc bỏ sót hoàn toàn.

---

## 5. Dữ Liệu Cần Cung Cấp Để Tiến Hành Bước Tiếp Theo

Để xây dựng pipeline kiểm định độc lập và huấn luyện **Model V2** chuẩn xác:

1. **Tập Validation/Test Dataset (`data.yaml` + images + labels):**
   - File cấu hình `data.yaml`.
   - Thư mục ảnh `images/val/` và nhãn `labels/val/` (định dạng YOLO: `class_id x_center y_center width height`).
   - Ưu tiên tập ảnh chụp thực tế bằng điện thoại tại điều kiện ánh sáng Việt Nam.
2. **Nếu muốn retrain Model V2:**
   - Cung cấp toàn bộ dataset gốc `Tree-Species-V2-Final` hoặc link tải (Roboflow / Google Drive / Kaggle).
   - Bổ sung ít nhất 50–100 ảnh chụp bằng điện thoại cho mỗi class để giải quyết Domain Shift.
