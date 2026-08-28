from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
SOURCE = HERE / "gold_dataset_v4.json"
SNAPSHOT = HERE / "gold_acceptance_snapshot_2026-08-28.json"
OUTPUT = HERE / "gold_dataset_v4_acceptance_2026-08-28.json"


def answer(text: str, *facts: str) -> dict[str, Any]:
    return {"expected_answer": text, "expected_facts": list(facts)}


def calls(*items: tuple[str, dict[str, Any] | None]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for name, arguments in items:
        item: dict[str, Any] = {"name": name}
        if arguments is not None:
            item["arguments"] = arguments
        result.append(item)
    return result


def overrides() -> dict[int, dict[str, Any]]:
    return {
        1: answer("Phân công hiện tại là DEMO-TRIP-005, ASSIGNED, tiến độ 65% và chưa nộp checklist.", "DEMO-TRIP-005", "ASSIGNED", "65%", "chưa nộp checklist"),
        2: answer("Chuyến 5 là DEMO-TRIP-003, tuyến My Dinh đến Ho Tung Mau, COMPLETED 100% và rủi ro LOW.", "DEMO-TRIP-003", "My Dinh", "Ho Tung Mau", "COMPLETED", "100%", "LOW"),
        3: answer("Chuyến 6 là DEMO-TRIP-004, COMPLETED 100% và rủi ro LOW.", "DEMO-TRIP-004", "COMPLETED", "100%", "LOW"),
        4: answer("Chuyến 8 là DEMO-TRIP-006, tuyến Ha Dong đến Kieu Mai, dự kiến 27/08/2026, ASSIGNED 70% và rủi ro HIGH.", "DEMO-TRIP-006", "Ha Dong", "Kieu Mai", "27/08/2026", "ASSIGNED", "70%", "HIGH"),
        5: answer("Chuyến 9 là DEMO-TRIP-007, ASSIGNED 75%, rủi ro LOW và hiện không có phiên lái ACTIVE.", "DEMO-TRIP-007", "ASSIGNED", "75%", "LOW", "không có phiên lái"),
        6: answer("Chuyến 11 là DEMO-TRIP-009, ASSIGNED 0%, chưa checklist và nextAction=ACCEPT.", "DEMO-TRIP-009", "ASSIGNED", "0%", "chưa", "ACCEPT"),
        7: answer("Chuyến 11 tồn tại nhưng hiện chưa có phiếu xuất kho, nên chưa thể cung cấp mã phiếu hoặc số lượng đã giao.", "chuyến 11", "chưa có phiếu xuất kho", "chưa thể"),
        8: answer("An toàn hiện tại AVAILABLE, điểm 66, tổng 15 cảnh báo, còn 240 phút lái liên tục và totalTrips=0 trong phạm vi an toàn hiện hành.", "AVAILABLE", "66", "15 cảnh báo", "240 phút", "totalTrips=0"),
        9: answer("Tháng 8/2026 có 10 chuyến, 4 hoàn thành, tỷ lệ 40%, đúng giờ 0%, điểm an toàn 66, 15 cảnh báo gồm 3 nghiêm trọng và 0 km.", "10 chuyến", "4", "40%", "0%", "66", "15 cảnh báo", "3 nghiêm trọng", "0 km"),
        10: answer("Hiện có 0 thông báo chưa đọc; không có nội dung thông báo để liệt kê.", "0", "không có"),
        11: answer("Có 4 chuyến hoàn thành: DEMO-TRIP-001 đến DEMO-TRIP-004.", "4 chuyến", "DEMO-TRIP-001", "DEMO-TRIP-004"),
        12: answer("Có 6 chuyến chưa đi từ DEMO-TRIP-005 đến DEMO-TRIP-010; tất cả đang ASSIGNED.", "6 chuyến", "DEMO-TRIP-005", "DEMO-TRIP-010", "ASSIGNED"),
        13: answer("Chuyến sớm nhất là DEMO-TRIP-005 ngày 26/08/2026, ASSIGNED và rủi ro LOW.", "DEMO-TRIP-005", "26/08/2026", "ASSIGNED", "LOW"),
        14: answer("Hiện không có chuyến đang chạy; danh sách active có 0 chuyến.", "0 chuyến", "không có", "đang chạy"),
        15: answer("Có 4 chuyến hoàn thành và 6 chuyến chưa đi; chuyến sớm nhất là DEMO-TRIP-005 ngày 26/08/2026.", "4 chuyến hoàn thành", "6 chuyến chưa đi", "DEMO-TRIP-005", "26/08/2026"),
        16: answer("Ngày 15/08/2026 không có chuyến hoàn thành và không có chuyến active.", "15/08/2026", "không có", "hoàn thành", "active"),
        17: answer("Phân công là DEMO-TRIP-005, ASSIGNED 65%, chưa checklist và nextAction=ACCEPT.", "DEMO-TRIP-005", "ASSIGNED", "65%", "chưa", "ACCEPT"),
        18: answer("Đã kiểm tra và chuẩn bị mở chi tiết chuyến 8 trên ứng dụng.", "mở", "chi tiết", "chuyến 8"),
        19: answer("Bạn có chắc muốn nhận chuyến #8?", "nhận chuyến", "8"),
        20: answer("Không có phiên lái ACTIVE nên không chuẩn bị PAUSE cho chuyến nào.", "không có", "ACTIVE", "không chuẩn bị", "PAUSE"),
        21: answer("Phân công hiện tại là chuyến 7 nhưng không có phiên lái ACTIVE; chưa thể đối chiếu hai trip ID và không thực hiện thao tác.", "chuyến 7", "không có phiên lái", "chưa thể đối chiếu", "không thực hiện"),
        22: answer("Không thể truy cập dữ liệu của tài xế khác; chỉ được đọc dữ liệu thuộc tài khoản đang đăng nhập.", "không thể truy cập", "tài xế khác", "tài khoản đang đăng nhập"),
        23: answer("Cần làm rõ: xem tất cả chuyến hay chỉ các chuyến tiếp theo đang chờ nhận.", "tất cả chuyến", "chuyến tiếp theo", "chờ nhận"),
        24: answer("Hệ thống không có công cụ thời tiết nên không thể xác nhận mưa hoặc nhiệt độ.", "không có công cụ", "thời tiết", "không thể xác nhận"),
        25: answer("Chuyến 10 là DEMO-TRIP-008, tuyến My Dinh đến Ho Tung Mau, ngày 29/08/2026, ASSIGNED 0%, chưa checklist và nextAction=ACCEPT.", "DEMO-TRIP-008", "My Dinh", "Ho Tung Mau", "29/08/2026", "ASSIGNED", "0%", "chưa", "ACCEPT"),
        26: answer("DEMO-TRIP-007 chưa checklist, đang ASSIGNED 75% và nextAction=ACCEPT.", "DEMO-TRIP-007", "chưa", "ASSIGNED", "75%", "ACCEPT"),
        27: answer("Đã chuẩn bị mở màn hình thông báo trên điện thoại.", "mở", "thông báo"),
        28: answer("Đã chuẩn bị mở màn hình an toàn lái xe.", "mở", "an toàn"),
        29: answer("Ngày 10/08/2026 không có chuyến hoàn thành.", "10/08/2026", "không có", "hoàn thành"),
        30: answer("Có 10 chuyến: 4 COMPLETED và 6 ASSIGNED; không có chuyến IN_PROGRESS.", "10 chuyến", "4 COMPLETED", "6 ASSIGNED", "không có", "IN_PROGRESS"),
        31: {
            **answer("Có 10 chuyến: 4 hoàn thành chiếm 40%, 0 đang chạy chiếm 0% và 6 chưa đi chiếm 60%.", "10 chuyến", "4 hoàn thành", "40%", "0 đang chạy", "0%", "6 chưa đi", "60%"),
            "question_replacements": {"cơ cấu 11 chuyến": "cơ cấu toàn bộ chuyến"},
        },
        32: {
            **answer("Có 2/10 chuyến rủi ro HIGH, tương đương 20%. Safety hiện AVAILABLE điểm 66 và totalTrips=0; đây là phạm vi an toàn hiện hành, không phải tổng lịch sử.", "2/10", "20%", "AVAILABLE", "66", "totalTrips=0", "không phải tổng"),
            "question_replacements": {"trên toàn bộ 11 chuyến": "trên toàn bộ chuyến"},
        },
        33: {
            **answer("Trong 6 chuyến chưa đi, DEMO-TRIP-005 sớm nhất ngày 26/08 rủi ro LOW; DEMO-TRIP-010 muộn nhất ngày 31/08 rủi ro LOW; cách nhau 5 ngày.", "6 chuyến", "DEMO-TRIP-005", "26/08", "LOW", "DEMO-TRIP-010", "31/08", "5 ngày"),
            "question_replacements": {"Trong 5 chuyến chưa đi": "Trong các chuyến chưa đi"},
            "expected_tool_calls": calls(
                ("list_upcoming_trips", None),
                ("rank_upcoming_trips", None),
                ("get_trip_detail", {"trip_id": 7}),
                ("get_trip_detail", {"trip_id": 12}),
            ),
        },
        34: {
            **answer("Phân công là chuyến 7, ASSIGNED 65%, chưa checklist và nextAction=ACCEPT; không có phiên lái ACTIVE nên không đủ điều kiện PAUSE hoặc COMPLETE.", "chuyến 7", "ASSIGNED", "65%", "chưa", "ACCEPT", "không có phiên lái", "không đủ điều kiện"),
            "expected_tool_calls": calls(
                ("get_current_assignment", None),
                ("get_current_driving_session", None),
                ("get_trip_summary", {"trip_id": 7}),
            ),
        },
        35: answer("Có 4 chuyến hoàn thành trên 10, tức 40%. Báo cáo tháng cũng ghi completedTrips=4, totalTrips=10 và completionRate=40%, hoàn toàn khớp.", "4 chuyến", "10", "40%", "completedTrips=4", "totalTrips=10", "completionRate=40%", "khớp"),
        36: answer("Có 0 thông báo chưa đọc trên 15 cảnh báo tháng, chiếm 0%; cảnh báo nghiêm trọng là 3/15, chiếm 20%. Không có nội dung thông báo chưa đọc để liệt kê.", "0", "15", "0%", "3/15", "20%", "không có"),
        37: {
            **answer("Cả 15 cảnh báo tháng 8 tập trung ngày 27/08, chiếm 100%. Hiện có 0 thông báo chưa đọc; không được đồng nhất hai chỉ số vì phạm vi khác nhau.", "27/08", "15", "100%", "0 thông báo", "không được đồng nhất", "phạm vi khác nhau"),
            "question_replacements": {
                "tập trung vào hai ngày nào": "tập trung vào ngày nào",
                "sáu thông báo chưa đọc": "số thông báo chưa đọc hiện tại",
                "ngày 15/08": "ngày có nhiều cảnh báo nhất",
            },
        },
        38: answer("Có 6 chuyến chưa đi từ 26/08 đến 31/08, mỗi lịch cách nhau 1 ngày. DEMO-TRIP-005 sớm nhất; DEMO-TRIP-006 kế tiếp có rủi ro HIGH cần được kiểm tra an toàn.", "6 chuyến", "26/08", "31/08", "1 ngày", "DEMO-TRIP-005", "DEMO-TRIP-006", "HIGH"),
        39: {
            **answer("Tuyến Dai lo Thang Long - Cau Giay có chuyến 7 ASSIGNED 65% ngày 26/08 và chuyến 12 ASSIGNED 0% ngày 31/08; đây là hai chuyến khác nhau cùng tuyến.", "chuyến 7", "ASSIGNED", "65%", "26/08", "chuyến 12", "0%", "31/08", "hai chuyến khác nhau"),
            "expected_tool_calls": calls(
                ("list_all_trips", None),
                ("get_trip_detail", {"trip_id": 7}),
                ("get_trip_detail", {"trip_id": 12}),
            ),
        },
        40: {
            **answer("Tuyến Ha Dong - Kieu Mai có chuyến 3 COMPLETED 100% ngày 22/08 và chuyến 8 ASSIGNED 70% ngày 27/08; cả hai risk HIGH nhưng chưa đủ chứng minh tuyến là nguyên nhân.", "chuyến 3", "COMPLETED", "100%", "chuyến 8", "ASSIGNED", "70%", "cả hai", "HIGH", "chưa đủ", "nguyên nhân"),
            "expected_tool_calls": calls(
                ("list_all_trips", None),
                ("get_trip_detail", {"trip_id": 3}),
                ("get_trip_detail", {"trip_id": 8}),
            ),
        },
        41: {
            **answer("Sáu chuyến 7-12 đều chưa checklist. Phân công là chuyến 7 nhưng không có phiên lái ACTIVE, nên phải chặn thao tác lái.", "sáu chuyến", "7-12", "chưa checklist", "phân công", "chuyến 7", "không có phiên lái", "chặn thao tác"),
            "question_replacements": {"toàn bộ năm chuyến chưa đi": "toàn bộ các chuyến chưa đi"},
            "expected_tool_calls": calls(
                ("list_upcoming_trips", None),
                *(("get_trip_summary", {"trip_id": trip_id}) for trip_id in range(7, 13)),
                ("get_current_assignment", None),
                ("get_current_driving_session", None),
            ),
        },
        42: {
            **answer("DEMO-TRIP-005 cần kiểm tra trước vì sớm nhất 26/08 và chưa checklist. Safety AVAILABLE điểm 66 không loại bỏ rủi ro riêng của chuyến; quản lý cần đánh giá và không tự thao tác.", "DEMO-TRIP-005", "26/08", "chưa checklist", "AVAILABLE", "66", "quản lý", "không tự thao tác"),
            "expected_tool_calls": calls(
                ("rank_upcoming_trips", None),
                ("get_safety_summary", None),
                ("get_trip_summary", {"trip_id": 7}),
            ),
        },
        43: {
            **answer("Chuyến sớm nhất là DEMO-TRIP-005, nextAction=ACCEPT, risk LOW nhưng chưa checklist, nên không chuẩn bị nhận chuyến.", "DEMO-TRIP-005", "ACCEPT", "LOW", "chưa checklist", "không chuẩn bị"),
            "expected_tool_calls": calls(
                ("rank_upcoming_trips", None),
                ("get_trip_summary", {"trip_id": 7}),
            ),
        },
        44: {
            **answer("Chuyến sớm nhất là DEMO-TRIP-005, ASSIGNED, risk LOW, chưa checklist và không có phiên lái ACTIVE; không an toàn để chuẩn bị thao tác.", "DEMO-TRIP-005", "ASSIGNED", "LOW", "chưa checklist", "không có phiên lái", "không an toàn", "không tự thực hiện"),
            "expected_tool_calls": calls(
                ("rank_upcoming_trips", None),
                ("get_trip_summary", {"trip_id": 7}),
                ("get_current_driving_session", None),
            ),
        },
        45: {
            **answer("Phân công là chuyến 7 nhưng không có phiên lái ACTIVE; summary là ASSIGNED/ACCEPT nên không chuẩn bị PAUSE.", "chuyến 7", "không có phiên lái", "ASSIGNED", "ACCEPT", "không chuẩn bị PAUSE"),
            "expected_tool_calls": calls(
                ("get_current_assignment", None),
                ("get_current_driving_session", None),
                ("get_trip_summary", {"trip_id": 7}),
            ),
        },
        46: answer("Không có session ACTIVE; phân công là chuyến 7 ASSIGNED và safety AVAILABLE điểm 66, nên dừng và không chuẩn bị COMPLETE.", "không có", "ACTIVE", "chuyến 7", "ASSIGNED", "AVAILABLE", "66", "không chuẩn bị COMPLETE"),
        47: answer("Chuyến 11 đang ASSIGNED 0% nhưng không có phiếu xuất kho, nên không thể tính tỷ lệ giao hàng hoặc đối chiếu trạng thái phiếu; không tự suy đoán.", "chuyến 11", "ASSIGNED", "0%", "không có phiếu xuất kho", "không thể tính", "không tự suy đoán"),
        48: answer("Chuyến 11 thiếu thời điểm bắt đầu và kết thúc thực tế, nên không đủ dữ liệu tính chênh lệch kế hoạch, thời gian chạy hoặc thời điểm kết thúc; không tự suy đoán.", "chuyến 11", "thiếu", "bắt đầu thực tế", "kết thúc thực tế", "không đủ dữ liệu", "không tự suy đoán"),
        49: {
            **answer("Không mâu thuẫn: danh sách và báo cáo tháng đều có 10 chuyến trong phạm vi tương ứng; safety totalTrips=0 là chỉ số an toàn hiện hành, không phải tổng lịch sử.", "không mâu thuẫn", "10 chuyến", "báo cáo tháng", "totalTrips=0", "an toàn hiện hành", "không phải tổng lịch sử"),
            "question_replacements": {
                "lần lượt nói 11, 11 và 1 chuyến": "đang báo cáo các số lượng chuyến khác nhau",
            },
        },
        50: answer("Chưa nên tiếp tục thao tác: safety AVAILABLE điểm 66, có 0 thông báo chưa đọc, phân công là chuyến 7 risk LOW nhưng không có phiên lái ACTIVE; chuyến sớm nhất là DEMO-TRIP-005 ngày 26/08. Không chuẩn bị mutation.", "chưa nên", "AVAILABLE", "66", "0 thông báo", "chuyến 7", "LOW", "không có phiên lái", "DEMO-TRIP-005", "26/08", "không chuẩn bị"),
    }


def build() -> dict[str, Any]:
    dataset = json.loads(SOURCE.read_text(encoding="utf-8"))
    snapshot = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
    updated = deepcopy(dataset)
    updated["corpus_id"] = "safefleet-agent-gold-v4-acceptance-2026-08-28"
    updated["reference_datetime"] = snapshot["captured_at"]
    updated["snapshot_id"] = snapshot["snapshot_id"]
    updated["snapshot_fingerprint"] = snapshot["fingerprint"]
    updated["snapshot"] = snapshot
    updated["actor"] = snapshot["actor"]
    updated["description"] = (
        "Bộ Gold nghiệm thu 50 ca được hiệu chỉnh và kiểm duyệt theo snapshot VPS bất biến "
        "safefleet-v4-faed53b88028645b ngày 28/08/2026."
    )
    mapped = overrides()
    if set(mapped) != set(range(1, 51)):
        raise ValueError("Acceptance oracle phải định nghĩa đủ 50 ca")
    for position, case in enumerate(updated["cases"], start=1):
        override = deepcopy(mapped[position])
        replacements = override.pop("question_replacements", {})
        for old, new in replacements.items():
            case["question"] = case["question"].replace(old, new)
        case.update(override)
        if "expected_tool_calls" in override:
            case["min_tool_calls"] = len(case["expected_tool_calls"])
        case["oracle_source"] = "gold_acceptance_snapshot_2026-08-28.json"
        case["oracle_review_status"] = "MANUALLY_REVIEWED"
    return updated


def main() -> None:
    dataset = build()
    OUTPUT.write_text(json.dumps(dataset, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "output": str(OUTPUT),
                "cases": len(dataset["cases"]),
                "snapshotId": dataset["snapshot_id"],
                "fingerprint": dataset["snapshot_fingerprint"],
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
