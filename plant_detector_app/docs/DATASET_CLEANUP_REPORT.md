# Báo Cáo Làm Sạch Dữ Liệu (Dataset Cleanup Report)

Ngày lập: 06/10/2026  
Dự án: Plant AI Detector (YOLOv8 + FastAPI + Flutter)  
Mục đích: Loại bỏ triệt để 19 ảnh trùng lặp gây rò rỉ dữ liệu (Data Leakage) giữa các tập Train, Validation, Test từ Dataset V1 gốc sang `dataset/original_v1_clean/`.

---

## 1. Tóm Tắt Quy Mô Dữ Liệu Trước và Sau Cleanup

> **Nguyên tắc bảo toàn:** Thư mục gốc `dataset/original_v1/` được **giữ nguyên 100% không chỉnh sửa** để bảo toàn tính đối chiếu. Tất cả quá trình làm sạch được ghi vào thư mục chuẩn mới: `dataset/original_v1_clean/`.

| Tập (Split) | Số ảnh trước Cleanup (`original_v1`) | Số ảnh bị loại bỏ (Duplicates) | Số ảnh sau Cleanup (`original_v1_clean`) | Tỷ lệ giữ lại |
| :--- | :---: | :---: | :---: | :---: |
| **Train** | `1.666` | `0` *(Ưu tiên giữ lại)* | `1.666` | 100.0% |
| **Validation** | `433` | `9` *(Rò rỉ với Train)* | `424` | 97.9% |
| **Test** | `237` | `10` *(8 rò rỉ với Train, 2 với Val)* | `227` | 95.8% |
| **TỔNG CỘNG** | **2.336** | **19** | **2.317** | **99.2%** |

- **Tổng số bounding box sau cleanup:** `3.428` hộp (Train: 2.393 | Val: 657 | Test: 378).
- **Kết quả xác thực từ `tools/validate_dataset.py`:** **Pass 100% (0 lỗi rò rỉ dữ liệu, 0 lỗi format nhãn).**

---

## 2. Danh Sách Chi Tiết 19 Ảnh Duplicate Bị Loại Bỏ

| STT | SHA-256 Hash (8 ký tự đầu) | Split bị loại | Tên File bị loại | Split được giữ | Tên File được giữ | Lý do loại bỏ khỏi clean dataset |
| :---: | :--- | :---: | :--- | :---: | :--- | :--- |
| 1 | `5e33daa4` | `test` | `DJI_0027_JPG.rf.819c2bcadfe1475ca3fc1c9ab5d9b1e4.jpg` | `train` | `DJI_0027_JPG.rf.bd00a56f883e5aa5f0bcfc19b3c2af2f.jpg` | Trùng lặp chéo giữa Train và Test (Ưu tiên Train) |
| 2 | `bf0eb746` | `test` | `DJI_0028_JPG.rf.7b1ae50cd6ee9bd8fd4a87c917a86f50.jpg` | `train` | `DJI_0028_JPG.rf.e8e0495bf0ab30fb0c8a7891f57a21c5.jpg` | Trùng lặp chéo giữa Train và Test (Ưu tiên Train) |
| 3 | `14f0e6ce` | `valid` | `DJI_0030_JPG.rf.6fd958a044c6e18618b12a28cac50cd8.jpg` | `train` | `DJI_0030_JPG.rf.aa68b5926124e6ce1c1adf5440e2ca01.jpg` | Trùng lặp chéo giữa Train và Validation (Ưu tiên Train) |
| 4 | `1b5e4954` | `test` | `DJI_0034_JPG.rf.86d18da7a2d2e7b4f8b91046575856b0.jpg` | `train` | `DJI_0034_JPG.rf.e8f002568d03254a8a8b8ba6ebe56371.jpg` | Trùng lặp chéo giữa Train và Test (Ưu tiên Train) |
| 5 | `17b85638` | `valid` | `DJI_0035_JPG.rf.9596898f090d6dd02e27bc96f47406a7.jpg` | `train` | `DJI_0035_JPG.rf.3491c3044beded33bd90f4660b423739.jpg` | Trùng lặp chéo giữa Train và Validation (Ưu tiên Train) |
| 6 | `0deaa936` | `test` | `DJI_0036_JPG.rf.1078c36dd87983e81bfc6025a0e1a48b.jpg` | `train` | `DJI_0036_JPG.rf.7c8aa3702406e11ed4028116649bad16.jpg` | Trùng lặp chéo giữa Train và Test (Ưu tiên Train) |
| 7 | `9e2cfc2c` | `test` | `DJI_0040_JPG.rf.73a8ba4902a3996a8f9769a28131c465.jpg` | `train` | `DJI_0040_JPG.rf.10f1434bd5c3e972648160ae8002eef6.jpg` | Trùng lặp chéo giữa Train và Test (Ưu tiên Train) |
| 8 | `d6453931` | `valid` | `IMG_20231004_103200_jpg.rf.a40f71ad34005271ac0f5d3fbe9f2b23.jpg` | `train` | `IMG_20231004_103200_jpg.rf.ebf1deb4cad6c2af8338ff41929f37ed.jpg` | Trùng lặp chéo giữa Train và Validation (Ưu tiên Train) |
| 9 | `96153895` | `valid` | `IMG_20231004_103201_jpg.rf.028414eddbd0832f3ccca574a95e5c96.jpg` | `train` | `IMG_20231004_103201_jpg.rf.d6cdb803beab9aca82a8ae4e18552d6a.jpg` | Trùng lặp chéo giữa Train và Validation (Ưu tiên Train) |
| 10 | `8bad24eb` | `test` | `IMG_20231004_103400_jpg.rf.c56c981c3fc59cd07d9c3dfaad54ed2a.jpg` | `train` | `IMG_20231004_103400_jpg.rf.3c76624cf449a455bca618b0685bddd3.jpg` | Trùng lặp chéo giữa Train và Test (Ưu tiên Train) |
| 11 | `5ef42363` | `valid` | `IMG_20231004_103415_jpg.rf.e98ba723053a25e627c37a86ee0a8ed1.jpg` | `train` | `IMG_20231004_103415_jpg.rf.9d92985ac033e43ffea50911d9d4adf2.jpg` | Trùng lặp chéo giữa Train và Validation (Ưu tiên Train) |
| 12 | `a61c548e` | `valid` | `IMG_20231004_104848_jpg.rf.123bd4773f88244507ad283a69f54b4f.jpg` | `train` | `IMG_20231004_104848_jpg.rf.83507220f293107962baea6aa23a331b.jpg` | Trùng lặp chéo giữa Train và Validation (Ưu tiên Train) |
| 13 | `9ce105a2` | `test` | `large-7-_jpg.rf.4575b391954da84b2af0c2cee23c4fa7.jpg` | `train` | `mango-tree-8_jpg.rf.bb052839f89e2f98451f960f5490ae6e.jpg` | Trùng lặp chéo giữa Train và Test (Ưu tiên Train) |
| 14 | `0bbbbc6c` | `test` | `large-80-_jpeg.rf.2ef4ac7fbe263a61da91f025e4e16058.jpg` | `train` | `papaya-tree-5_jpeg.rf.30c40f982f4262dba2a1beabc729ef02.jpg` | Trùng lặp chéo giữa Train và Test (Ưu tiên Train) |
| 15 | `a2facc99` | `valid` | `Screenshot-2023-10-04-120621_png.rf.f6220e53571b472ae4299dde8cb8f0fc.jpg` | `train` | `Screenshot-2023-10-04-120621_png.rf.521d4276dde238b56a94741002ab14a9.jpg` | Trùng lặp chéo giữa Train và Validation (Ưu tiên Train) |
| 16 | `9e731b69` | `valid` | `Screenshot-2023-10-04-120733_png.rf.99376588a4d7368303ee1c4be5ccbead.jpg` | `train` | `Screenshot-2023-10-04-120733_png.rf.b23ffb64327aa21d25b58d3071d2d08b.jpg` | Trùng lặp chéo giữa Train và Validation (Ưu tiên Train) |
| 17 | `8473c742` | `valid` | `Screenshot-2023-10-04-120743_png.rf.a6111b24556692e0a5ce4e895f3f9dea.jpg` | `train` | `Screenshot-2023-10-04-120743_png.rf.04d8130ac5703d369c8dd136e47420bc.jpg` | Trùng lặp chéo giữa Train và Validation (Ưu tiên Train) |
| 18 | `ce8324d4` | `test` | `DJI_0039_JPG.rf.50c9746167fef8e85a3e74865be16c69.jpg` | `valid` | `DJI_0039_JPG.rf.c49af27765df3c2af0b24e0714890b2f.jpg` | Trùng lặp chéo giữa Validation và Test (Ưu tiên Validation) |
| 19 | `3b066d8f` | `test` | `Screenshot-2023-10-04-120611_png.rf.d0f543ab6a0628f39e26e1d0dfdca094.jpg` | `valid` | `Screenshot-2023-10-04-120611_png.rf.d2ca7e814bd6ed9ffb52326a4ad85506.jpg` | Trùng lặp chéo giữa Validation và Test (Ưu tiên Validation) |

---

## 3. Bảng Phân Bố Class Sau Khi Làm Sạch (`dataset/original_v1_clean`)

Thống kê chính xác số lượng **Images** và **Bounding Boxes** cho từng class sau khi loại bỏ 19 duplicate:

| Class | Train Images | Train Boxes | Val Images | Val Boxes | Test Images | Test Boxes |
| :--- | -----------: | ----------: | ---------: | --------: | ----------: | ---------: |
| `Acacia` | 139 | 166 | 37 | 49 | 23 | 28 |
| `Bamboo-shoots` | 176 | 190 | 43 | 47 | 23 | 25 |
| `Banana-plant` | 167 | 587 | 47 | 186 | 26 | 98 |
| `Banyan-Tree` | 42 | 84 | 12 | 19 | 6 | 14 |
| `Coconut-tree` | 125 | 206 | 30 | 72 | 15 | 29 |
| `Mango-Tree` | 144 | 159 | 42 | 47 | 13 | 13 |
| `Neem-Tree` | 148 | 175 | 25 | 27 | 7 | 31 |
| `Palm-tree` | 46 | 82 | 11 | 13 | 6 | 12 |
| `Papaya-Tree` | 171 | 201 | 47 | 48 | 23 | 31 |
| `Pine` | 98 | 171 | 24 | 49 | 16 | 25 |
| `lemon tree` | 179 | 195 | 47 | 53 | 24 | 29 |
| `peepal tree` | 174 | 177 | 47 | 47 | 43 | 43 |
| **TỔNG CỘNG** | **1.666** | **2.393** | **424** | **657** | **227** | **378** |

---

## 4. Kết Luận & Ứng Dụng
1. Bộ dữ liệu sạch `dataset/original_v1_clean/` đã loại bỏ hoàn toàn các trường hợp ảnh giống nhau bị chia rải rác giữa Train và Test/Validation.
2. Đây sẽ là tập dữ liệu nền móng (Base clean dataset) dùng để trộn cùng dữ liệu chụp thực tế điện thoại nhằm tạo ra **Hybrid V3 Dataset** trong các bước tiếp theo.
