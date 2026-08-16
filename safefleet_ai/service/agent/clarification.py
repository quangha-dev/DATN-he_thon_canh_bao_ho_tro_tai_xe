from __future__ import annotations

import re
import unicodedata

TRIP_SCOPE_QUESTION = "Bạn muốn xem tất cả chuyến hay chỉ các chuyến tiếp theo đang chờ nhận?"
OTHER_DRIVER_RESPONSE = (
    "Tôi không thể truy cập dữ liệu của tài xế khác; chỉ có thể đọc dữ liệu thuộc "
    "tài khoản đang đăng nhập."
)
UNSUPPORTED_WEATHER_RESPONSE = (
    "Tôi không có công cụ dữ liệu thời tiết nên không thể xác nhận dự báo mưa hoặc "
    "nhiệt độ. Hãy kiểm tra nguồn dự báo thời tiết chính thức."
)


def normalize_vietnamese(value: str) -> str:
    decomposed = unicodedata.normalize("NFD", value.lower())
    without_marks = "".join(
        character for character in decomposed if unicodedata.category(character) != "Mn"
    ).replace("đ", "d")
    return re.sub(r"\s+", " ", without_marks).strip()


def needs_trip_scope_clarification(question: str) -> bool:
    normalized = normalize_vietnamese(question)
    if not re.search(r"\bchuyen(?:\s+di)?\b", normalized):
        return False
    if re.search(
        r"\bchuyen(?:\s+di)?\s+(?:so\s+)?#?(?=[a-z0-9-]*\d)[a-z0-9-]+\b",
        normalized,
    ):
        return False
    return not any(signal in normalized for signal in _TRIP_SCOPE_SIGNALS)


def has_explicit_date_scope(question: str) -> bool:
    normalized = normalize_vietnamese(question)
    if any(signal in normalized for signal in _DATE_SIGNALS):
        return True
    return bool(
        re.search(
            r"\b(?:ngay\s+)?\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?\b|"
            r"\b\d{4}-\d{2}-\d{2}\b",
            normalized,
        )
    )


def requests_upcoming_scope(question: str) -> bool:
    normalized = normalize_vietnamese(question)
    return any(signal in normalized for signal in _UPCOMING_SIGNALS)


def requests_ranked_upcoming_scope(question: str) -> bool:
    normalized = normalize_vietnamese(question)
    return any(signal in normalized for signal in _RANKING_SIGNALS)


def requests_other_driver_data(question: str) -> bool:
    normalized = normalize_vietnamese(question)
    return any(signal in normalized for signal in _OTHER_DRIVER_SIGNALS)


def requests_unsupported_weather(question: str) -> bool:
    normalized = normalize_vietnamese(question)
    return any(signal in normalized for signal in _WEATHER_SIGNALS)


_DATE_SIGNALS = (
    "hom nay",
    "ngay hom nay",
    "ngay mai",
    "hom qua",
    "tuan nay",
    "tuan truoc",
    "tuan toi",
    "thang nay",
    "thang truoc",
    "thang toi",
    "tu ngay",
    "den ngay",
)

_UPCOMING_SIGNALS = (
    "tiep theo",
    "gan nhat",
    "sap toi",
    "cho nhan",
    "dang cho",
    "chua di",
    "chua chay",
    "chua khoi hanh",
    "duoc giao",
    "da giao",
    "phan cong",
)

_RANKING_SIGNALS = (
    "tiep theo",
    "gan nhat",
    "som nhat",
    "can di truoc",
    "uu tien",
)

_OTHER_DRIVER_SIGNALS = (
    "tai xe khac",
    "nguoi lai xe khac",
    "tai khoan khac",
    "dong nghiep cua toi",
)

_WEATHER_SIGNALS = (
    "thoi tiet",
    "du bao mua",
    "co mua",
    "nhiet do",
    "nang hay mua",
    "bao nhiet doi",
)

_TRIP_SCOPE_SIGNALS = (
    _DATE_SIGNALS
    + _UPCOMING_SIGNALS
    + (
        "tat ca",
        "toan bo",
        "moi chuyen",
        "da di",
        "da chay",
        "hoan thanh",
        "dang di",
        "dang chay",
        "dang nghi",
        "tam dung",
        "su co",
        "bi huy",
        "da huy",
        "chi tiet",
        "tom tat",
        "bao cao",
        "so sanh",
        "mo chuyen",
        "bat dau",
        "khoi hanh",
        "nhan chuyen",
        "tiep tuc",
        "ket thuc",
        "di den",
        "di dau",
    )
)
