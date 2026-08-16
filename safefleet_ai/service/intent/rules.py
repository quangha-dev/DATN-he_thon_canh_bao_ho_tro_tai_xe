from __future__ import annotations

import re

from service.intent.models import Intent, IntentResponse


RULES: list[tuple[Intent, tuple[str, ...], bool]] = [
    (Intent.SEND_SOS, ("sos", "cứu hộ", "cuu ho", "khẩn cấp", "khan cap"), True),
    (Intent.REPORT_FLOOD, ("báo ngập", "bao ngap", "điểm ngập", "diem ngap", "đang ngập", "dang ngap"), True),
    (Intent.PAUSE_TRIP, ("tạm dừng", "tam dung", "tạm nghỉ", "tam nghi"), True),
    (Intent.RESUME_TRIP, ("tiếp tục", "tiep tuc"), True),
    (Intent.COMPLETE_TRIP, ("hoàn thành", "hoan thanh", "kết thúc chuyến", "ket thuc chuyen"), True),
    (Intent.START_TRIP, ("bắt đầu chuyến", "bat dau chuyen", "khởi hành", "khoi hanh"), True),
    (Intent.GET_DRIVING_TIME, ("giờ lái", "gio lai", "còn lái", "con lai", "lái bao lâu", "lai bao lau", "thời gian lái", "thoi gian lai"), False),
    (Intent.READ_LATEST_WARNING, ("cảnh báo mới", "canh bao moi", "đọc cảnh báo", "doc canh bao"), False),
]

CONFIRMATION_REQUIRED = {
    Intent.START_TRIP,
    Intent.PAUSE_TRIP,
    Intent.RESUME_TRIP,
    Intent.COMPLETE_TRIP,
    Intent.REPORT_FLOOD,
    Intent.SEND_SOS,
}


def normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def classify_locally(transcript: str) -> IntentResponse:
    normalized = normalize(transcript)
    for intent, phrases, confirmation in RULES:
        if any(phrase in normalized for phrase in phrases):
            return IntentResponse(intent=intent, confidence=0.95, requires_confirmation=confirmation)
    return IntentResponse(intent=Intent.UNKNOWN, confidence=0.0, requires_confirmation=False)
