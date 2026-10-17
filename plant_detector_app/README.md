# 🌿 Web App AI Nhận Dạng 12 Loại Cây (YOLOv8 & Streamlit)

Ứng dụng nhận diện và phân loại 12 loại cây tự động sử dụng mô hình thị giác máy tính **Ultralytics YOLOv8** kết hợp với giao diện tương tác **Streamlit**.

---

## 🎯 12 Loại Cây Mô Hình Hỗ Trợ Nhận Dạng

Mô hình đã được nạp và đọc trực tiếp từ `models/best.pt`:
1. `0: Acacia` (Cây keo / tràm)
2. `1: Bamboo-shoots` (Măng tre / tre)
3. `2: Banana-plant` (Cây chuối)
4. `3: Banyan-Tree` (Cây đa / bồ đề)
5. `4: Coconut-tree` (Cây dừa)
6. `5: Mango-Tree` (Cây xoài)
7. `6: Neem-Tree` (Cây sầu đâu / neem)
8. `7: Palm-tree` (Cây cọ)
9. `8: Papaya-Tree` (Cây đu đủ)
10. `9: Pine` (Cây thông)
11. `10: lemon tree` (Cây chanh)
12. `11: peepal tree` (Cây bồ đề)

---

## 📁 Cấu Trúc Dự Án

```
plant_detector_app/
│
├── app.py                  # Mã nguồn chính Streamlit & YOLOv8
├── requirements.txt        # Danh sách thư viện Python
├── run.bat                 # Khởi động nhanh bằng 1 click trên Windows
├── README.md               # Tài liệu dự án
│
├── models/
│   └── best.pt             # File model YOLOv8 12 classes đã tích hợp
│
├── sample_images/
│   └── cay_mau.jpg         # Ảnh cây mẫu để test nhanh
│
└── venv/                   # Môi trường ảo Python độc lập
```

---

## 🚀 Cách Chạy Ứng Dụng

- **Cách 1 (Nhanh nhất):** Nhấp đúp chuột vào file `run.bat`.
- **Cách 2 (Dòng lệnh):**
  ```powershell
  # Mở terminal tại thư mục chứa dự án:
  .\venv\Scripts\python.exe -m streamlit run app.py
  ```
- Mở trình duyệt tại: `http://localhost:8501`

---

## ✨ Tính Năng Nổi Bật

- **Tự động nhận diện & vẽ Bounding Box:** Khoanh vùng chính xác vị trí từng cây trên ảnh.
- **Không hard-code kết quả:** Toàn bộ nhãn loài cây được đọc động từ `model.names`.
- **Slider Confidence Threshold:** Mặc định `0.25`, dễ dàng tinh chỉnh từ `0.05` đến `1.00`.
- **Thống kê chi tiết:** Số lượng cây, độ tin cậy trung bình, phân loại theo loài, bảng tọa độ chi tiết `[xmin, ymin, xmax, ymax]`.
- **Thông báo rõ ràng:** Báo "Không phát hiện được cây" khi không có đối tượng nào đạt ngưỡng tin cậy.
- **Giao diện Tiếng Việt 100%:** Thiết kế sinh thái, thân thiện, dễ sử dụng.
