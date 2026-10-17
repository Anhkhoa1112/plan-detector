# Flutter MVP - Plant AI Detector

Ngày cập nhật: 06/10/2026

## 1. Tổng quan hệ thống (System Overview)

Ứng dụng Flutter hoàn thiện pipeline nhận dạng cây trồng kết nối với FastAPI và YOLO:

```text
[Thiết bị Mobile Android 14]
       │
       ├──> Chọn ảnh (Gallery hoặc Camera)
       │
       ├──> Kiểm tra hợp lệ (MIME, < 10MB, kích thước)
       │
       ├──> Multipart/form-data POST /predict?confidence=0.25&iou=0.45
       │
[FastAPI Backend - LAN IP: 192.168.100.245:8000]
       │
       ├──> Kiểm tra ảnh bằng Pillow (JPEG/PNG)
       ├──> Chạy YOLO model (models/production/best.pt)
       └──> Trả về JSON Detection
       │
[Flutter Mobile App]
       │
       ├──> Parse dữ liệu JSON (PredictionResponse, Detection, BoundingBox)
       ├──> Overlay Bounding Box chính xác lên ảnh preview (không biến dạng)
       ├──> Hiển thị nhãn loài cây (Tiếng Việt & Scientific name), độ tin cậy (%)
       └──> Đồng bộ tương tác giữa danh sách kết quả và khung nhận dạng
```

---

## 2. Kiến trúc Flutter (Architecture)

```text
lib/
├── config/
│   └── app_config.dart            # Cấu hình BACKEND_BASE_URL mặc định & dart-define
├── models/
│   ├── bounding_box.dart          # Tọa độ x1, y1, x2, y2, kích thước width/height, area, Rect
│   ├── detection.dart             # class_id, class_name, name_vi, confidence, bbox, formatters
│   ├── health_status.dart         # Trạng thái backend, model_loaded, load_error
│   └── prediction_response.dart   # Dữ liệu response đầy đủ: success, image_width, image_height, detections
├── services/
│   └── plant_api_client.dart      # Client HTTP với pre-validation, typed error handling, timeout
├── screens/
│   └── home_screen.dart           # Màn hình chính hoàn chỉnh (Header, Status, Picker, Preview, BBox, Cards)
├── widgets/
│   ├── bounding_box_overlay.dart  # CustomPainter vẽ BBox, corner accents, label badges, tap detection
│   └── detection_card.dart        # Card hiển thị từng loài cây: thanh độ tin cậy, màu sắc đồng bộ, kích thước
└── main.dart                      # Entrypoint ứng dụng Flutter
```

---

## 3. Luồng API (API Flow)

### 3.1. Health Check (`GET /health`)
- **Tần suất**: Tự động gọi khi khởi động ứng dụng hoặc khi nhấn vào badge trạng thái / nút làm mới.
- **Mục đích**: Xác nhận FastAPI đang chạy và YOLO model đã sẵn sàng trong RAM.
- **Response**:
  ```json
  {
    "status": "ok",
    "model_loaded": true,
    "model_path": "models/production/best.pt",
    "load_error": null
  }
  ```
- **Xử lý trên Flutter**:
  - `isReady == true`: Badge hiển thị màu xanh lá (`Đã kết nối`).
  - Lỗi kết nối / timeout: Badge hiển thị màu đỏ (`Mất kết nối`) và hiển thị banner cảnh báo kèm nút `Thử lại` và `Cài đặt IP`.

### 3.2. Inference (`POST /predict`)
- **Endpoint**: `/predict?confidence=0.25&iou=0.45`
- **Method**: `POST` (multipart/form-data)
- **Field name**: `image` (kèm header `Content-Type: image/jpeg` hoặc `image/png`)
- **Response**:
  ```json
  {
    "success": true,
    "image_width": 1200,
    "image_height": 896,
    "detections": [
      {
        "class_id": 10,
        "class_name": "lemon tree",
        "name_vi": "Cây Chanh",
        "confidence": 0.892,
        "bbox": {
          "x1": 532.01,
          "y1": 22.69,
          "x2": 1200.0,
          "y2": 849.46
        }
      }
    ]
  }
  ```

---

## 4. Luồng xử lý và Upload ảnh (Image Upload Flow)

1. **Nguồn ảnh**:
   - `Chụp ảnh từ Camera`: Sử dụng `ImagePicker().pickImage(source: ImageSource.camera)` (nhận ảnh trực tiếp từ camera phần cứng).
   - `Chọn từ Thư viện`: Sử dụng `ImagePicker().pickImage(source: ImageSource.gallery)` (hỗ trợ Android Photo Picker).
2. **Tiền kiểm tra (Pre-validation)**:
   - Kiểm tra tệp tồn tại (`exists()`).
   - Kiểm tra dung lượng: Nếu tệp > 10MB, thông báo ngay lập tức cho người dùng, ngăn chặn việc gửi request gây tốn băng thông.
   - Trích xuất kích thước gốc (`decodeImageDimensions`) để đảm bảo tỷ lệ khung hình.
3. **MIME type streaming**:
   - Đặt `MediaType('image', 'jpeg')` hoặc `MediaType('image', 'png')` tương ứng định dạng để FastAPI chấp nhận.

---

## 5. Hiển thị Bounding Box (Bounding Box Rendering)

### 5.1. Thuật toán Scale tọa độ (Coordinate Scaling)
Backend trả về tọa độ `bbox` dựa trên kích thước pixel gốc của ảnh (`image_width`, `image_height`).
Để vẽ chính xác lên widget preview mà không làm méo ảnh:
1. Tính tỷ lệ khung hình chuẩn: `aspect = imageWidth / imageHeight`.
2. Giới hạn chiều cao hiển thị tối đa (`maxHeight = 360`) trong khi tôn trọng chiều rộng màn hình.
3. Tính kích thước hiển thị thực tế: `renderWidth` và `renderHeight` sao cho `renderWidth / renderHeight == aspect`.
4. Tính hệ số tỷ lệ:
   $$	ext{scaleX} = rac{	ext{renderWidth}}{	ext{imageWidth}}, \quad 	ext{scaleY} = rac{	ext{renderHeight}}{	ext{imageHeight}}$$
   Vì tỷ lệ khung hình được giữ nguyên, $	ext{scaleX} == 	ext{scaleY}$.
5. Tọa độ hộp sau khi scale:
   $$	ext{left} = 	ext{bbox.x1} 	imes 	ext{scaleX}, \quad 	ext{top} = 	ext{bbox.y1} 	imes 	ext{scaleY}$$
   $$	ext{right} = 	ext{bbox.x2} 	imes 	ext{scaleX}, \quad 	ext{bottom} = 	ext{bbox.y2} 	imes 	ext{scaleY}$$

### 5.2. Tính năng hiển thị BBox
- **Bảng màu phân biệt**: Mỗi detection được gán một màu tương phản cao riêng biệt (Emerald, Amber, Vivid Blue, Coral, Purple, Gold, Cyan, Lime).
- **Điểm nhấn góc (Corner Accents)**: Vẽ các góc định vị công nghệ cao.
- **Label Badge**: Hiển thị `#SốTựTự TênCây ĐộTinCậy%` (ví dụ: `#1 Cây Chanh 89.2%`). Badge tự động dịch chuyển vào trong nếu nằm sát mép trên ảnh để tránh bị cắt.
- **Tương tác 2 chiều**:
  - Nhấp vào BBox trên ảnh -> Card tương ứng bên dưới được chọn.
  - Nhấp vào Card bên dưới -> BBox tương ứng trên ảnh được làm nổi bật với viền sáng và nền mờ.
  - Nút chuyển đổi (Visibility icon) cho phép ẩn/hiện toàn bộ BBox linh hoạt.

---

## 6. Xử lý lỗi (Error Handling)

| Tình huống | Mã lỗi / Ngoại lệ | Xử lý & Thông báo người dùng |
| :--- | :--- | :--- |
| Tệp ảnh > 10MB | Client-side Pre-check | `"Ảnh quá lớn (X MB). Vui lòng chọn ảnh dưới 10 MB."` (ngăn gửi request) |
| Tệp rỗng / không tồn tại | `PlantApiErrorCode.fileNotFound` | `"Tệp ảnh không tồn tại trên thiết bị."` |
| Không kết nối được LAN | `SocketException` | `"Không thể kết nối đến máy chủ backend (URL). Vui lòng kiểm tra Wi-Fi và đảm bảo backend đang chạy."` |
| Quá thời gian chờ (45s) | `TimeoutException` | `"Quá thời gian chờ phản hồi từ máy chủ (Timeout). Vui lòng kiểm tra lại kết nối mạng LAN."` |
| Ảnh lỗi / sai định dạng | HTTP 400 | `"Ảnh không hợp lệ: [chi tiết lỗi từ FastAPI]"` |
| Sai endpoint | HTTP 404 | `"Không tìm thấy API endpoint trên máy chủ (HTTP 404)."` |
| Backend/YOLO lỗi | HTTP 500 / 503 | `"Mô hình AI chưa sẵn sàng / Lỗi máy chủ: [chi tiết]"` |
| Không phát hiện cây | Detections rỗng `[]` | Empty state thân thiện: `"Không phát hiện cây nào đạt ngưỡng tin cậy (>25%). Gợi ý: Hãy chụp gần hơn và đủ sáng."` |

---

## 7. Hướng dẫn vận hành

### 7.1. Chạy Backend (FastAPI)
Mở PowerShell tại thư mục backend:
```powershell
cd D:\plant_detector_app\plant_detector_app
.\venv\Scripts\python.exe -m uvicorn backend.main:app --host 0.0.0.0 --port 8000
```
Kiểm tra sức khỏe backend từ máy tính:
```powershell
curl.exe http://192.168.100.245:8000/health
```

### 7.2. Chạy và kiểm tra Flutter trên máy tính
```powershell
cd D:\plant_detector_app
D:\Flutter\bin\flutter.bat analyze
D:\Flutter\bin\flutter.bat test
```

### 7.3. Cài đặt và build APK cho điện thoại Android
Build Debug APK với LAN IP cấu hình sẵn:
```powershell
cd D:\plant_detector_app
D:\Flutter\bin\flutter.bat build apk --debug --dart-define=BACKEND_BASE_URL=http://192.168.100.245:8000
```
Cài đặt lên điện thoại Xiaomi (đã kết nối USB Debugging):
```powershell
D:\Android\SDK\platform-tools\adb.exe install -r D:\plant_detector_app\build\app\outputs\flutter-apk\app-debug.apk
```

### 7.4. Đổi IP backend trực tiếp trên ứng dụng (In-app Runtime Configuration)
Người dùng không cần build lại APK khi đổi mạng Wi-Fi:
- Nhấn vào biểu tượng **Cài đặt (Settings)** ở góc phải AppBar.
- Nhập IP LAN mới của máy tính (ví dụ: `http://192.168.1.15:8000`).
- Nhấn **Lưu & Kết nối**, ứng dụng sẽ tự động ping lại backend và cập nhật trạng thái ngay lập tức.

---

## 8. Kết quả kiểm thử (Test Results)

- **`flutter analyze`**: Pass (0 issues).
- **`flutter test`**: Pass toàn bộ 16 tests:
  - 7 tests API client (health check, multipart upload, 400 bad request, 404 not found, 500 server error, file pre-validation, response parsing).
  - 7 tests Models (BoundingBox width/height/area/rect/json, Detection confidence formatting & Vietnamese titles, HealthStatus isReady, PredictionResponse multiple & empty detections).
  - 2 tests Bounding Box (Coordinate scaling math preservation, cycling color palette).
- **`flutter build apk --debug`**: Pass (`build\app\outputs\flutter-apk\app-debug.apk`).
- **`adb install -r`**: Pass (`Success` trên thiết bị Xiaomi 21121210C Android 14).
