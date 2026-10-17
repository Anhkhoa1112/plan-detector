# Báo Cáo Khôi Phục Dữ Liệu (Dataset Recovery Report)

Ngày lập: 06/10/2026  
Dự án: Plant AI Detector (YOLOv8 + FastAPI + Flutter)  
Trọng tâm: Truy vết 100% nguồn gốc, mã nguồn huấn luyện và khả năng khôi phục dataset `Tree-Species-V2-Final` từ Google Colab

---

## 1. Tóm Tắt Điều Tra & Trạng Thái Khôi Phục

> ### **TRẠNG THÁI: RECOVERABLE (Khôi Phục Hoàn Toàn 100%)**

Nhờ phân tích trực tiếp mã nguồn và đầu ra thực thi từ file **Google Colab Notebook** (`1CtffANP4N3g8mNIor1Cpyj-F_7g5HCR-`), toàn bộ quy trình sinh dữ liệu, mã nguồn gán nhãn, tài khoản Roboflow, API Key, số lượng ảnh và phân chia tập dữ liệu của model hiện tại (`models/production/best.pt`) đã được làm sáng tỏ tuyệt đối.

---

## 2. Toàn Bộ Phả Hệ Dữ Liệu (Dataset Lineage & Pipeline)

Hệ thống nhận diện hiện tại trải qua 2 giai đoạn (Model V1 và Model V2) với quy trình chi tiết như sau:

```
[Roboflow: tree-species-hace3-an24k (v1)]
       │ (Detection Dataset - 12 classes có nhãn gốc)
       ▼
[Train YOLOv8n V1 (50 epochs)] ──► Sinh ra Checkpoint V1 (best.pt / best_v1.pt)
                                              │
[Roboflow: tree-classification-qghzz-k09by]  │ (Dùng V1 để auto-label)
       │ (Classification Dataset - 4.633 ảnh) │
       ▼                                      ▼
[Thuật toán Pseudo-Labeling] ◄────────────────┘
       │ Giữ lại 3.774 ảnh (V1 đoán đúng tên thư mục)
       │ Chuyển 859 ảnh vào folder review
       ▼
[Tạo dataset Tree-Species-V2-Final]
       │ Split: 80% train (3.019) / 10% valid (377) / 10% test (378)
       ▼
[Fine-tune YOLOv8n V2 (30 epochs)] ──► Sinh ra models/production/best.pt
```

---

## 3. Chi Tiết Các Nguồn Dữ Liệu Gốc Trên Roboflow

Tất cả dữ liệu được lưu trữ trực tiếp trên tài khoản Roboflow được tích hợp trong notebook:

### 3.1. Nguồn Dataset Gốc V1 (Object Detection chuẩn)
- **Tài khoản / Workspace:** `mlinn2045-gmail-com`
- **Tên Project:** `tree-species-hace3-an24k`
- **Phiên bản:** `version(1)`
- **Định dạng tải:** `yolov8`
- **Đường dẫn Colab khi train:** `/content/Tree-Species-1`
- **Số ảnh Validation:** 433 ảnh (663 bounding box instances)
- **Kết quả nghiệm thu V1 (Epoch 50):**
  - **mAP50:** `80.69%`
  - **mAP50-95:** `51.97%`
  - **Precision:** `80.34%`
  - **Recall:** `76.60%`

### 3.2. Nguồn Dataset Bổ Sung V2 (Classification gốc)
- **Tài khoản / Workspace:** `mlinn2045-gmail-com`
- **Tên Project:** `tree-classification-qghzz-k09by`
- **Phiên bản:** `version(1)`
- **Định dạng tải:** `folder` (ảnh phân cấp theo từng thư mục loài cây)
- **Tổng số ảnh ban đầu:** 4.633 ảnh (đã lọc bỏ loài thứ 13 là `Mangrove`)

---

## 4. Cơ Chế Sinh Dataset `Tree-Species-V2-Final` (Cell 18 – 22)

Bộ dữ liệu `Tree-Species-V2-Final` mà model `models/production/best.pt` đang sử dụng **không phải do con người gán nhãn thủ công**, mà được sinh ra hoàn toàn tự động bằng kỹ thuật **Pseudo-labeling (Tự gán nhãn bằng model V1)**:

1. **Thuật toán Auto-labeling:**
   - Dùng Model V1 (`/content/best.pt`) dự đoán trên toàn bộ 4.633 ảnh phân loại của 12 loài cây với ngưỡng `conf = 0.25`, `imgsz = 640`.
   - Nếu Model V1 phát hiện bounding box có nhãn trùng với tên thư mục loài cây (Ground-truth folder):
     - **Chấp nhận (Accepted):** Lưu bounding box đó vào `/content/Tree-Species-V2/labels/`.
   - Nếu Model V1 không phát hiện được gì hoặc dự đoán nhãn khác:
     - **Loại trừ (Review):** Chuyển ảnh vào `/content/Tree-Species-V2/review/`.

2. **Thống kê ảnh Accepted / Review thực tế từ Colab:**
   | Lớp Đối Tượng (Class Name) | Accepted (Được gán nhãn) | Review (Bị loại bỏ) | Tổng số ảnh nguồn |
   | :--- | :---: | :---: | :---: |
   | `Acacia` | 356 | 46 | 402 |
   | `Bamboo-shoots` | 367 | 148 | 515 |
   | `Banana-plant` | 305 | 179 | 484 |
   | `Banyan-Tree` | 109 | 13 | 122 |
   | `Coconut-tree` | 300 | 53 | 353 |
   | `Mango-Tree` | 249 | 164 | 413 |
   | `Neem-Tree` | 348 | 58 | 406 |
   | `Palm-tree` | 91 | 41 | 132 |
   | `Papaya-Tree` | 362 | 125 | 487 |
   | `Pine` | 276 | 5 | 281 |
   | `lemon tree` | 508 | 16 | 524 |
   | `peepal tree` | 503 | 11 | 514 |
   | **TỔNG CỘNG** | **3.774 ảnh** | **859 ảnh** | **4.633 ảnh** |

3. **Phân chia tập (Dataset Split):**
   - **Tỉ lệ:** 80% Train, 10% Valid, 10% Test (Seed: 42).
   - **Train:** 3.019 ảnh
   - **Valid:** 377 ảnh (506 instances)
   - **Test:** 378 ảnh
   - **Tổng cộng:** 3.774 ảnh trong `/content/Tree-Species-V2-Final`

4. **Kết quả Validation của V2 trên Colab:**
   - **mAP50:** `94.02%`
   - **mAP50-95:** `81.35%`
   - **Precision:** `91.25%`
   - **Recall:** `90.89%`

---

## 5. Nguyên Nhân Gốc Rễ Khiến Model Nhận Diện Kém Trên Điện Thoại Thật

Mặc dù điểm kiểm định trên Google Colab đạt tới **94.02% mAP50**, ứng dụng thực tế trên điện thoại Xiaomi vẫn nhận diện sai, bỏ sót hoặc có độ tự tin bất thường. Qua audit, 2 nguyên nhân cốt lõi được xác định:

### 5.1. Sai lệch do cơ chế tự gán nhãn (Pseudo-Labeling Confirmation Bias)
- Tập kiểm định `Tree-Species-V2-Final/valid` được tạo ra từ chính dự đoán của Model V1, chứ **không phải nhãn chuẩn do con người xác thực**.
- Khi Model V2 được đánh giá trên tập này, điểm số 94% mAP chỉ phản ánh việc Model V2 học vẹt lại đúng các bounding box mà Model V1 đã sinh ra.
- Nếu Model V1 đóng khung lệch, cắt mất thân cây hoặc nhận nhầm một phần tán lá, nhãn sai đó trở thành "Ground Truth" tuyệt đối cho V2.

### 5.2. Lệch miền dữ liệu nghiêm trọng (Severe Domain Shift)
- Toàn bộ dữ liệu của Roboflow (`tree-species` và `tree-classification`) đều là **ảnh phong cảnh chụp từ khoảng cách xa (10m – 50m)** bao quát toàn bộ cây đứng trong tự nhiên, công viên hoặc đường phố.
- Trong khi đó, người dùng thực tế cầm điện thoại Xiaomi thường chụp:
  - Cận cảnh cành, lá, thân cây, hoa hoặc quả (khoảng cách 0.3m – 1.5m).
  - Góc nghiêng, ánh sáng ngược, bóng râm trong nhà hoặc sân vườn.
- Model chưa từng được học đặc trưng hoa văn của lá, gân lá hay cấu trúc cành cây ở cự ly gần!

---

## 6. Hướng Dẫn Tải & Tái Tạo Lại Dataset Cục Bộ

Do đã có đủ thông tin mã nguồn và khóa truy cập Roboflow từ Colab, có thể tái lập dataset bất kỳ lúc nào:

### Cách 1: Tải trực tiếp dataset V1 (Chuẩn Object Detection gốc)
```python
import os
from roboflow import Roboflow

api_key = os.getenv("ROBOFLOW_API_KEY", "YOUR_ROBOFLOW_API_KEY")
rf = Roboflow(api_key=api_key)
project = rf.workspace("mlinn2045-gmail-com").project("tree-species-hace3-an24k")
dataset = project.version(1).download("yolov8", location="./dataset/original_v1")
```

### Cách 2: Tái tạo lại chính xác `Tree-Species-V2-Final` (3.774 ảnh)
Chạy script auto-label từ chính Notebook Colab bằng cách tải `tree-classification-qghzz-k09by` và cho model V1 suy luận gán nhãn.

---

## 7. Đề Xuất 3 Phương Án Hành Động Tiếp Theo (Đợi Quyết Định)

1. **Phương án A: Khôi phục dataset `Tree-Species-V2-Final` cũ (hoặc V1)**
   - Tải về và đưa vào `dataset/` cục bộ để chạy nghiệm thu độc lập bằng [tools/evaluate_model.py](file:///D:/plant_detector_app/plant_detector_app/tools/evaluate_model.py).
   - Đảm bảo tính tái lập 100% của bài báo cáo/đồ án.

2. **Phương án B: Tìm dataset mở rộng tương đương có nhãn chuẩn do người gán**
   - Tìm kiếm các dataset thực vật mã nguồn mở trên Kaggle / Roboflow Universe có nhiều ảnh cận cảnh lá cây, quả và thân cây để thay thế dữ liệu auto-label.

3. **Phương án C (Khuyên dùng): Chiến lược lai ghép (Hybrid Dataset)**
   - Giữ lại tập dữ liệu gốc làm nền tảng phát hiện cây từ xa.
   - Bổ sung **300 – 500 ảnh chụp thực tế từ điện thoại Xiaomi** (cận cảnh lá, thân cây, trong nhiều điều kiện ánh sáng thực tế tại Việt Nam) theo đúng hướng dẫn tại [docs/DATASET_COLLECTION_GUIDE.md](file:///D:/plant_detector_app/plant_detector_app/docs/DATASET_COLLECTION_GUIDE.md).
   - Gán nhãn thủ công chuẩn xác để loại bỏ hoàn toàn lỗi gán nhãn của model V1.
