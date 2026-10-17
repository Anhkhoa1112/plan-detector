# BÁO CÁO AUDIT DATASET CHO HYBRID YOLO V3

**Dự án:** Plant AI Detector  
**Ngày thực hiện:** 06/10/2026  
**Trạng thái:** HOÀN TẤT AUDIT — REAL-WORLD DATA REQUIRED  

---

## 1. TỔNG QUAN TÀI NGUYÊN DỮ LIỆU HIỆN CÓ

| Bộ dữ liệu | Đường dẫn | Số ảnh | Bounding Boxes | Trạng thái |
| :--- | :--- | :---: | :---: | :--- |
| **Original V1 Clean (Train)** | `dataset/original_v1_clean/train` | 1,666 | 2,416 | Sạch, đã lọc duplicate/corrupt |
| **Original V1 Clean (Val)** | `dataset/original_v1_clean/valid` | 424 | 654 | Sạch, dùng làm calibration set |
| **Original V1 Clean (Test)** | `dataset/original_v1_clean/test` | 227 | 376 | Sạch, dùng làm benchmark set |
| **Tổng Original V1 Clean** | `dataset/original_v1_clean/` | **2,317** | **3,446** | Đầy đủ metadata Roboflow |
| **Real-World Train** | `dataset/real_world_train/` | **0** | **0** | **Trống (Cần thu thập ảnh thật)** |
| **Real-World Test** | `dataset/real_world_test/` | **0** | **0** | **Trống (Cần thu thập ảnh thật)** |

---

## 2. PHÂN BỐ 12 LỚP DỮ LIỆU (ORIGINAL V1 CLEAN)

| ID | Class Name | Tên tiếng Việt | Số nhãn Train | Tỷ lệ Train | Ghi chú |
| :---: | :--- | :--- | :---: | :---: | :--- |
| 0 | Acacia | Cây keo | 240 | 9.9% | Cân bằng tốt |
| 1 | Bamboo-shoots | Măng tre / Tre | 215 | 8.9% | Đặc trưng rõ rệt, mAP cao |
| 2 | Banana-plant | Cây chuối | 185 | 7.7% | Lá chuối hay bị che khuất |
| 3 | Banyan-Tree | Cây đa | 134 | 5.5% | Rễ phụ phức tạp, ít mẫu |
| 4 | Coconut-tree | Cây dừa | 128 | 5.3% | Thiếu góc chụp tầm gần |
| 5 | Mango-Tree | Cây xoài | 252 | 10.4% | Cân bằng tốt |
| 6 | Neem-Tree | Cây xoan / Neem | 130 | 5.4% | Lá nhỏ, tán mỏng, khó nhận |
| 7 | Palm-tree | Cây cọ | 148 | 6.1% | Dễ nhầm với cây dừa |
| 8 | Papaya-Tree | Cây đu đủ | 210 | 8.7% | Thân thẳng, lá xòe rõ |
| 9 | Pine | Cây thông | 192 | 7.9% | Tán lá kim đặc trưng |
| 10 | lemon tree | Cây chanh | 260 | 10.8% | Nhạy cảm với texture trong nhà |
| 11 | peepal tree | Cây bồ đề | 322 | 13.3% | Hình dáng lá trái tim đặc trưng |
| **Tổng** | **12 classes** | | **2,416** | **100%** | |

---

## 3. KIỂM TOÁN TẬP REAL-WORLD (ĐIỆN THOẠI XIAOMI)

### Hiện trạng
- Thư mục `dataset/real_world_train/`: **0 ảnh**.
- Thư mục `dataset/real_world_test/`: **0 ảnh**.
- Thư mục `dataset/real_world_yolo/`: Đã sẵn sàng cấu trúc thư mục `train/`, `valid/`, `test/` nhưng chưa có ảnh nhãn gán thủ công từ người dùng.

### Tuân thủ nguyên tắc cốt lõi
1. **Tuyệt đối KHÔNG sinh ảnh giả (synthetic images/AI-generated images).**
2. **Tuyệt đối KHÔNG cào ảnh ngẫu nhiên trên mạng không kiểm chứng.**
3. **Tuyệt đối KHÔNG tự động train V3 khi chưa có ảnh thực tế từ thiết bị Xiaomi chụp ngoài đời.**

---

## 4. KẾ HOẠCH NẠP DỮ LIỆU THỰC TẾ (REAL-WORLD INTAKE)

Để chuẩn bị cho việc huấn luyện V3 đạt độ chính xác thực tế cao nhất:
1. **Thiết bị thu thập:** Điện thoại Xiaomi (Camera 50MP/12MP chế độ Auto, không bật filter màu làm sai lệch).
2. **Số lượng mục tiêu:**
   - Tối thiểu 15-20 ảnh thực tế cho mỗi loài cây yếu (`Coconut-tree`, `Banana-plant`, `Banyan-Tree`, `Neem-Tree`, `Palm-tree`).
   - Tổng cộng: ~150 - 200 ảnh điện thoại thực tế ngoài trời tại Việt Nam.
3. **Quy trình nạp:** Sử dụng công cụ `tools/dataset_intake.py` để copy ảnh vào thư mục phân loại và `tools/validate_real_world_dataset.py` để kiểm tra độ phân giải, định dạng và tính toàn vẹn.

---

## 5. KẾT LUẬN

Bộ dữ liệu sạch `original_v1_clean` đã hoàn thiện và đóng vai trò chuẩn mực (ground truth baseline). Tuy nhiên, vì tập `real_world` chưa có ảnh nạp vào, quyết định chính thức là **REAL-WORLD DATA REQUIRED** trước khi kích hoạt huấn luyện V3.
