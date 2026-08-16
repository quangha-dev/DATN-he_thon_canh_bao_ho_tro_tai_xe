from service.ocr.pipeline.common import OcrLine
from service.ocr.pipeline.run_hybrid import extract_common_fields


def _line(text: str, top: int) -> OcrLine:
    return OcrLine(
        text=text,
        left=0,
        top=top,
        right=500,
        bottom=top + 20,
        confidence=91,
    )


def test_extracts_printed_header_fields() -> None:
    fields = extract_common_fields(
        [
            _line("PHIẾU XUẤT KHO  Số: 77029", 0),
            _line("Ngày 5 tháng 7 năm 2026", 25),
            _line("Mã số xe: 29C-646.84", 50),
            _line("Họ tên người nhận hàng: Nguyễn Văn An", 75),
        ],
        "CT xây dựng nhà máy Công ty cổ phần bao bì",
    )

    assert fields["voucher_date"] == "2026-07-05"
    assert fields["voucher_number"] == "77029"
    assert fields["vehicle_plate"] == "29C64684"
    assert fields["driver_name"] == "Nguyễn Văn An"
    assert fields["trip_count"] == 1
    assert fields["confidences"]["voucher_date"] == 0.93


def test_does_not_treat_template_or_vehicle_code_as_voucher_number() -> None:
    fields = extract_common_fields(
        [
            _line("Mẫu số: 02-VT", 0),
            _line("Mã số xe: 29C-646.84", 25),
        ],
        "Công trình thử nghiệm",
    )

    assert fields["voucher_number"] == ""
    assert fields["vehicle_plate"] == "29C64684"
