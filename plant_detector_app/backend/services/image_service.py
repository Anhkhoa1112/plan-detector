from io import BytesIO

from PIL import Image, ImageOps, UnidentifiedImageError


ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/jpg", "image/webp"}
MAX_IMAGE_BYTES = 10 * 1024 * 1024


class ImageValidationError(ValueError):
    pass


async def read_image_upload(upload_file) -> Image.Image:
    raw_ct = (upload_file.content_type or "").split(";")[0].strip().lower()
    if raw_ct not in ALLOWED_CONTENT_TYPES:
        raise ImageValidationError("Only JPEG, PNG, and WebP images are supported.")

    data = await upload_file.read()
    if not data:
        raise ImageValidationError("Image file is empty.")
    if len(data) > MAX_IMAGE_BYTES:
        raise ImageValidationError("Image file is too large. Max size is 10 MB.")

    try:
        image = Image.open(BytesIO(data))
        # Chuẩn hóa hướng xoay ảnh EXIF để không bị xoay sai trên mobile
        image = ImageOps.exif_transpose(image)
        image.load()
    except (UnidentifiedImageError, OSError) as exc:
        raise ImageValidationError("Image file is invalid or corrupted.") from exc

    return image.convert("RGB")
