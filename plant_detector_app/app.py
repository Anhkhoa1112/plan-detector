import os
from pathlib import Path
from PIL import Image
import streamlit as st

# Cấu hình trang Streamlit
st.set_page_config(
    page_title="AI Nhận Dạng 12 Loại Cây | YOLOv8",
    page_icon="🌿",
    layout="wide",
    initial_sidebar_state="expanded",
)

# Custom CSS cho giao diện hiện đại, chuyên nghiệp
st.markdown(
    """
    <style>
    #MainMenu {visibility: hidden;}
    
    .main-header {
        background: linear-gradient(135deg, #1b5e20 0%, #2e7d32 60%, #388e3c 100%);
        padding: 24px 28px;
        border-radius: 14px;
        color: #ffffff;
        margin-bottom: 24px;
        box-shadow: 0 6px 18px rgba(27, 94, 32, 0.15);
    }
    .main-header h1 {
        color: #ffffff !important;
        font-size: 2.2rem;
        font-weight: 700;
        margin: 0 0 8px 0;
        display: flex;
        align-items: center;
        gap: 12px;
    }
    .main-header p {
        color: #e8f5e9 !important;
        font-size: 1.05rem;
        margin: 0;
    }
    
    .metric-container {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
        gap: 16px;
        margin: 16px 0;
    }
    .metric-card {
        background: #ffffff;
        border: 1px solid #e0e0e0;
        border-left: 5px solid #2e7d32;
        border-radius: 10px;
        padding: 16px 20px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.04);
    }
    .metric-card-label {
        font-size: 0.9rem;
        color: #666;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }
    .metric-card-value {
        font-size: 2rem;
        font-weight: 800;
        color: #1b5e20;
        margin-top: 4px;
    }
    
    .status-badge {
        display: inline-block;
        padding: 6px 14px;
        border-radius: 20px;
        font-size: 0.88rem;
        font-weight: 600;
        margin-bottom: 12px;
    }
    .status-ready {
        background-color: #d4edda;
        color: #155724;
        border: 1px solid #c3e6cb;
    }
    .status-missing {
        background-color: #fff3cd;
        color: #856404;
        border: 1px solid #ffeeba;
    }

    .custom-table {
        width: 100%;
        border-collapse: collapse;
        margin-top: 12px;
        margin-bottom: 20px;
        border-radius: 8px;
        overflow: hidden;
        background-color: #ffffff !important;
        border: 1px solid #dcdcdc;
        box-shadow: 0 2px 8px rgba(0,0,0,0.06);
    }
    .custom-table th {
        background-color: #2e7d32 !important;
        color: #ffffff !important;
        padding: 14px 18px;
        text-align: left;
        font-weight: 700;
        font-size: 1.05rem;
    }
    .custom-table td {
        padding: 12px 18px;
        border-bottom: 1px solid #eeeeee;
        color: #222222 !important;
        background-color: #ffffff;
        font-size: 1rem;
    }
    .custom-table tr:nth-child(even) td {
        background-color: #f8faf8 !important;
    }
    .custom-table tr:hover td {
        background-color: #edf7ed !important;
    }
    .badge-species {
        background-color: #e8f5e9;
        color: #1b5e20;
        padding: 6px 14px;
        border-radius: 20px;
        font-weight: 600;
        font-size: 1rem;
        border: 1px solid #a5d6a7;
        display: inline-block;
    }
    .badge-conf {
        background-color: #e3f2fd;
        color: #0d47a1;
        padding: 6px 14px;
        border-radius: 20px;
        font-weight: 600;
        font-size: 0.95rem;
        border: 1px solid #90caf9;
        display: inline-block;
    }
    </style>
    """,
    unsafe_allow_html=True,
)

# Đường dẫn thư mục gốc và model mặc định
BASE_DIR = Path(__file__).resolve().parent
MODELS_DIR = BASE_DIR / "models"
DEFAULT_MODEL_PATH = MODELS_DIR / "best.pt"

# Đảm bảo thư mục models luôn tồn tại
MODELS_DIR.mkdir(parents=True, exist_ok=True)

# Bảng tra cứu tên tiếng Việt cho 12 loài cây
PLANT_VI_NAMES = {
    "Acacia": "Cây Keo",
    "Bamboo-shoots": "Măng Tre / Cây Tre",
    "Banana-plant": "Cây Chuối",
    "Banyan-Tree": "Cây Đa",
    "Coconut-tree": "Cây Dừa",
    "Mango-Tree": "Cây Xoài",
    "Neem-Tree": "Cây Neem / Sầu Đâu",
    "Palm-tree": "Cây Cọ",
    "Papaya-Tree": "Cây Đu Đủ",
    "Pine": "Cây Thông",
    "lemon tree": "Cây Chanh",
    "peepal tree": "Cây Bồ Đề",
}


@st.cache_resource(show_spinner=False)
def load_yolo_model(model_path: str):
    """Nạp model YOLO từ đường dẫn được chỉ định (có cache tài nguyên)."""
    try:
        from ultralytics import YOLO

        model = YOLO(model_path)
        return model, None
    except Exception as e:
        return None, str(e)


# ==========================================
# SIDEBAR: Cấu hình và Tùy chọn
# ==========================================
with st.sidebar:
    st.markdown("### 🌿 Cài Đặt Nhận Dạng")

    # Kiểm tra trạng thái file model models/best.pt
    model_exists = DEFAULT_MODEL_PATH.exists()

    if model_exists:
        st.markdown(
            '<div class="status-badge status-ready">🟢 Model: Sẵn sàng (models/best.pt)</div>',
            unsafe_allow_html=True,
        )
        active_model_path = str(DEFAULT_MODEL_PATH)
    else:
        st.markdown(
            '<div class="status-badge status-missing">🟠 Model: Chưa tìm thấy best.pt</div>',
            unsafe_allow_html=True,
        )
        active_model_path = None

    # Slider điều chỉnh Confidence Threshold (Mặc định 0.25)
    conf_threshold = st.slider(
        "🎯 Ngưỡng tin cậy (Confidence Threshold):",
        min_value=0.05,
        max_value=1.00,
        value=0.25,
        step=0.05,
        help="Chỉ những cây có độ tin cậy >= giá trị này mới được hiển thị.",
    )

    # Slider điều chỉnh IoU / NMS Threshold
    iou_threshold = st.slider(
        "📐 Ngưỡng trùng lặp (IoU / NMS):",
        min_value=0.10,
        max_value=0.90,
        value=0.45,
        step=0.05,
        help="Hỗ trợ loại bỏ các bounding box bị trùng lặp trên cùng một cây.",
    )

    # Nếu model đã nạp, hiển thị danh sách 12 classes lấy trực tiếp từ model.names
    if active_model_path:
        with st.spinner("Đang đọc thông tin model..."):
            loaded_model_info, _ = load_yolo_model(active_model_path)
            if loaded_model_info and loaded_model_info.names:
                with st.expander(f"📋 Danh Sách {len(loaded_model_info.names)} Loài Cây Hỗ Trợ", expanded=True):
                    for cid, cname in loaded_model_info.names.items():
                        st.markdown(f"• **{cid}:** `{cname}`")

    st.markdown("---")
    st.markdown("### 🛠️ Quản Lý File Model")
    st.info(
        "Baseline model đang được khóa theo kế hoạch migration. "
        "Không upload hoặc ghi đè trực tiếp `models/best.pt` từ giao diện này."
    )

    st.markdown("---")
    st.markdown(
        """
        **Vị trí file model:**  
        `models/best.pt`  
        
        **Định dạng ảnh:**  
        `JPG`, `JPEG`, `PNG`
        """
    )


# ==========================================
# MAIN CONTENT: Header & Giới thiệu
# ==========================================
st.markdown(
    """
    <div class="main-header">
        <h1>🌿 AI Nhận Dạng Các Loại Cây (YOLOv8)</h1>
        <p>Hệ thống tự động phát hiện, khoanh vùng Bounding Box và phân loại 12 loại cây với độ chính xác cao</p>
    </div>
    """,
    unsafe_allow_html=True,
)

# Hiển thị hướng dẫn nếu chưa có models/best.pt
if not model_exists:
    st.warning(
        f"""
        ### ⚠️ Chưa tìm thấy file mô hình tại `models/best.pt`
        
        **Vị trí cần đặt file model:**  
        📂 **Thư mục:** `{MODELS_DIR.resolve()}`  
        📄 **Tên file:** `best.pt`  
        
        👉 **Hướng dẫn:** Vui lòng đặt file `best.pt` đã train của bạn vào đúng thư mục trên.
        """
    )

# ==========================================
# PHẦN TẢI ẢNH (FILE UPLOADER)
# ==========================================
st.markdown("### 📤 Tải Lên Hình Ảnh Cây Cần Nhận Dạng")

upload_col, sample_col = st.columns([3, 1], gap="medium")
with upload_col:
    uploaded_image_file = st.file_uploader(
        "Chọn file ảnh từ máy tính (định dạng JPG, JPEG, PNG):",
        type=["jpg", "jpeg", "png"],
        help="Hệ thống hỗ trợ các file ảnh JPG, JPEG, PNG",
    )

sample_image_path = BASE_DIR / "sample_images" / "cay_mau.jpg"
use_sample = False
with sample_col:
    if sample_image_path.exists():
        st.markdown("<div style='height: 28px;'></div>", unsafe_allow_html=True)
        use_sample = st.checkbox("🌱 Dùng ảnh mẫu", help="Sử dụng ảnh cây mẫu có sẵn trong thư mục sample_images")

# Xác định nguồn ảnh
original_image = None
image_caption_name = ""

if uploaded_image_file is not None:
    try:
        original_image = Image.open(uploaded_image_file).convert("RGB")
        image_caption_name = uploaded_image_file.name
    except Exception as e:
        st.error(f"❌ Không thể đọc file hình ảnh: {e}")
        st.stop()
elif use_sample and sample_image_path.exists():
    try:
        original_image = Image.open(sample_image_path).convert("RGB")
        image_caption_name = "cay_mau.jpg (Ảnh mẫu)"
    except Exception as e:
        st.error(f"❌ Không thể đọc ảnh mẫu: {e}")
        st.stop()

if original_image is not None:
    # Tạo 2 cột để so sánh ảnh gốc và ảnh nhận dạng
    col_orig, col_pred = st.columns(2, gap="large")

    with col_orig:
        st.markdown("#### 📷 Ảnh Gốc Tải Lên")
        st.image(
            original_image,
            caption=f"File: {image_caption_name} ({original_image.width}x{original_image.height} px)",
            use_container_width=True,
        )

    # Xử lý nhận dạng với model
    if active_model_path is None:
        with col_pred:
            st.markdown("#### 🔍 Kết Quả Nhận Dạng (YOLO)")
            st.info(
                "⏳ Đang chờ model `models/best.pt` để tiến hành phát hiện cây. Vui lòng đặt model theo hướng dẫn ở trên."
            )
    else:
        with col_pred:
            st.markdown("#### 🔍 Kết Quả Nhận Dạng (YOLOv8)")
            with st.spinner("Đang chạy mô hình YOLOv8 để nhận dạng cây..."):
                model, load_err = load_yolo_model(active_model_path)

                if load_err:
                    st.error(f"❌ Lỗi khi nạp model: {load_err}")
                    num_detections = 0
                    detected_items = []
                elif model is None:
                    st.error("❌ Không thể khởi tạo mô hình YOLO.")
                    num_detections = 0
                    detected_items = []
                else:
                    try:
                        # Chạy nhận dạng YOLO (Inference)
                        results = model.predict(
                            source=original_image,
                            conf=conf_threshold,
                            iou=iou_threshold,
                            verbose=False,
                        )
                        result = results[0]

                        # Vẽ bounding box lên ảnh kết quả
                        # Ultralytics trả về mảng BGR, chuyển sang RGB cho PIL
                        res_bgr = result.plot()
                        res_rgb = res_bgr[..., ::-1]
                        result_image = Image.fromarray(res_rgb)

                        # Hiển thị ảnh kèm bounding box
                        st.image(
                            result_image,
                            caption="Ảnh sau khi nhận diện và khoanh vùng Bounding Box",
                            use_container_width=True,
                        )

                        # Trích xuất dữ liệu dự đoán trực tiếp từ model.names
                        boxes = result.boxes
                        num_detections = len(boxes) if boxes is not None else 0

                        detected_items = []
                        if boxes is not None and num_detections > 0:
                            # Lấy tên class trực tiếp từ model.names (Không hard-code)
                            names_dict = model.names or {}
                            for i, box in enumerate(boxes):
                                cls_id = int(box.cls[0].item())
                                class_name = names_dict.get(cls_id, f"Class {cls_id}")
                                conf_score = float(box.conf[0].item())
                                xyxy = [round(float(v), 1) for v in box.xyxy[0].tolist()]
                                vi_name = PLANT_VI_NAMES.get(class_name)
                                display_name = f"{class_name} ({vi_name})" if vi_name else class_name

                                detected_items.append(
                                    {
                                        "stt": i + 1,
                                        "class_name": class_name,
                                        "display_name": display_name,
                                        "confidence_pct": f"{conf_score * 100:.2f}%",
                                        "confidence_raw": conf_score,
                                        "bbox": f"[{xyxy[0]}, {xyxy[1]}, {xyxy[2]}, {xyxy[3]}]",
                                    }
                                )

                    except Exception as pred_err:
                        st.error(f"❌ Lỗi trong quá trình nhận dạng: {pred_err}")
                        num_detections = 0
                        detected_items = []

        # ==========================================
        # PHẦN KẾT QUẢ: DANH SÁCH CÂY NHẬN DẠNG ĐƯỢC
        # ==========================================
        st.markdown("---")
        st.markdown("### 📋 Danh Sách Cây Nhận Dạng Được")

        if active_model_path and "num_detections" in locals():
            if num_detections > 0:
                # Tạo các dòng bảng gồm: STT (1, 2, 3...), Tên loại cây và Độ tin cậy
                table_rows_html = "".join([
                    f"<tr><td style='text-align: center; font-weight: 700; font-size: 1.15rem; color: #1b5e20;'>{item['stt']}</td>"
                    f"<td style='font-size: 1.05rem; font-weight: 600;'><span class='badge-species'>🌿 {item['display_name']}</span></td>"
                    f"<td style='text-align: center;'><span class='badge-conf'>🎯 {item['confidence_pct']}</span></td></tr>"
                    for item in detected_items
                ])

                table_html = (
                    f"<table class='custom-table'>"
                    f"<thead><tr>"
                    f"<th style='width: 15%; text-align: center;'>STT</th>"
                    f"<th style='text-align: left;'>Tên loại cây</th>"
                    f"<th style='width: 25%; text-align: center;'>Độ tin cậy</th>"
                    f"</tr></thead>"
                    f"<tbody>{table_rows_html}</tbody>"
                    f"</table>"
                )
                st.markdown(table_html, unsafe_allow_html=True)

            else:
                # YÊU CẦU: Nếu không phát hiện được đối tượng thì thông báo rõ ràng
                st.warning("⚠️ **Không phát hiện được cây**")
                st.info(
                    f"Không tìm thấy đối tượng cây nào đạt ngưỡng tin cậy >= {conf_threshold:.2f}. "
                    "Hãy thử kéo giảm thanh trượt **Ngưỡng tin cậy (Confidence Threshold)** ở thanh bên trái xuống mức thấp hơn (ví dụ: 0.15 - 0.20)."
                )

else:
    # Hướng dẫn ban đầu khi chưa upload ảnh
    st.info(
        "👋 Vui lòng tải lên hình ảnh cây (định dạng **JPG, JPEG, PNG**) hoặc chọn **'Dùng ảnh mẫu'** ở trên để bắt đầu."
    )

# Footer
st.markdown("---")
st.markdown(
    """
    <div style="text-align: center; color: #777; font-size: 0.88rem; padding: 10px 0;">
        🌿 <b>Hệ Thống AI Nhận Dạng Các Loại Cây</b> &bull; YOLOv8 & Streamlit &bull; 12 Classes &bull; Giao diện Tiếng Việt
    </div>
    """,
    unsafe_allow_html=True,
)
