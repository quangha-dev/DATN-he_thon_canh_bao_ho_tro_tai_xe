from __future__ import annotations

import os

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from service.core.security import require_internal_service
from service.ocr.models import DocumentOcrResponse

router = APIRouter(
    prefix="/ocr",
    tags=["ocr"],
    dependencies=[Depends(require_internal_service)],
)


@router.post("/driving-log", response_model=DocumentOcrResponse)
def driving_log(file: UploadFile = File(...)) -> DocumentOcrResponse:
    allowed = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}
    if file.content_type not in allowed:
        raise HTTPException(status_code=415, detail="Chỉ chấp nhận ảnh JPEG, PNG hoặc WebP")
    maximum = int(os.getenv("OCR_MAX_UPLOAD_BYTES", str(10 * 1024 * 1024)))
    content = file.file.read(maximum + 1)
    if not content:
        raise HTTPException(status_code=400, detail="Ảnh tải lên rỗng")
    if len(content) > maximum:
        raise HTTPException(status_code=413, detail="Ảnh vượt quá dung lượng cho phép")
    try:
        from service.ocr.service import recognize_document

        return DocumentOcrResponse.model_validate(
            recognize_document(content, allowed[file.content_type])
        )
    except HTTPException:
        raise
    except Exception as exception:
        raise HTTPException(status_code=422, detail="Không thể nhận dạng phiếu") from exception
