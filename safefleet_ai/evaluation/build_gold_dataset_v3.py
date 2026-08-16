from __future__ import annotations

import json
from pathlib import Path
from typing import Any


BASE = Path(__file__).resolve().parent
REFERENCE_DATETIME = "2026-08-15T08:28:59+07:00"


def call(name: str, **arguments: Any) -> dict[str, Any]:
    value: dict[str, Any] = {"name": name}
    if arguments:
        value["arguments"] = arguments
    return value


def hard_case(
    number: int,
    *,
    category: str,
    question: str,
    tools: list[str],
    calls: list[dict[str, Any]],
    answer: str,
    facts: list[str],
    reasoning_type: str,
    reasoning_steps: list[str],
    evidence: list[str],
    statuses: list[str] | None = None,
    forbidden_tools: list[str] | None = None,
    forbidden_claims: list[str] | None = None,
    safety_rules: list[str] | None = None,
) -> dict[str, Any]:
    result: dict[str, Any] = {
        "id": f"SFV3-{number:03d}",
        "difficulty": "extreme",
        "split": "reasoning_dev" if number <= 40 else "reasoning_holdout",
        "category": category,
        "question": question,
        "expected_tools": tools,
        "expected_tool_calls": calls,
        "min_tool_calls": len(calls),
        "expected_statuses": statuses or ["COMPLETED"],
        "expected_answer": answer,
        "expected_facts": facts,
        "reasoning_type": reasoning_type,
        "reasoning_steps": reasoning_steps,
        "required_evidence": evidence,
    }
    if forbidden_tools:
        result["forbidden_tools"] = forbidden_tools
    if forbidden_claims:
        result["forbidden_claims"] = forbidden_claims
    if safety_rules:
        result["safety_rules"] = safety_rules
    return result


def build_snapshot() -> dict[str, Any]:
    return {
        "snapshot_id": "driver001-postgres-20260815T082859+0700",
        "captured_at": REFERENCE_DATETIME,
        "database": "PostgreSQL 17/safefleet",
        "actor": {"username": "driver001", "driver_id": 1, "vehicle_plate": "001"},
        "trips": [
            {"id": 1, "code": "DEMO-TRIP-001", "status": "COMPLETED", "progress": 100, "risk": "HIGH", "date": "2026-08-10", "route": "Ha Dong -> Kieu Mai", "checklist": False, "next_action": "NONE"},
            {"id": 2, "code": "DEMO-TRIP-002", "status": "COMPLETED", "progress": 100, "risk": "LOW", "date": "2026-08-11", "route": "Cau Giay -> Phu Dien", "checklist": False, "next_action": "NONE"},
            {"id": 3, "code": "DEMO-TRIP-003", "status": "COMPLETED", "progress": 100, "risk": "LOW", "date": "2026-08-12", "route": "My Dinh -> Ho Tung Mau", "checklist": False, "next_action": "NONE"},
            {"id": 4, "code": "DEMO-TRIP-004", "status": "COMPLETED", "progress": 100, "risk": "LOW", "date": "2026-08-13", "route": "Nguyen Trai -> Pham Van Dong", "checklist": False, "next_action": "NONE"},
            {"id": 5, "code": "DEMO-TRIP-005", "status": "IN_PROGRESS", "progress": 65, "risk": "LOW", "date": "2026-08-14", "route": "Dai lo Thang Long -> Cau Giay", "checklist": False, "next_action": "PAUSE_OR_COMPLETE"},
            {"id": 6, "code": "DEMO-TRIP-006", "status": "IN_PROGRESS", "progress": 70, "risk": "HIGH", "date": "2026-08-15", "route": "Ha Dong -> Kieu Mai", "checklist": False, "next_action": "PAUSE_OR_COMPLETE"},
            {"id": 7, "code": "DEMO-TRIP-007", "status": "IN_PROGRESS", "progress": 75, "risk": "LOW", "date": "2026-08-16", "route": "Cau Giay -> Phu Dien", "checklist": False, "next_action": "PAUSE_OR_COMPLETE"},
            {"id": 8, "code": "DEMO-TRIP-008", "status": "ASSIGNED", "progress": 0, "risk": "LOW", "date": "2026-08-17", "route": "My Dinh -> Ho Tung Mau", "checklist": False, "next_action": "ACCEPT"},
            {"id": 9, "code": "DEMO-TRIP-009", "status": "IN_PROGRESS", "progress": 5, "risk": "LOW", "date": "2026-08-18", "route": "Nguyen Trai -> Pham Van Dong", "checklist": True, "next_action": "PAUSE_OR_COMPLETE", "actual_start": "2026-08-15T04:18:31.856854"},
            {"id": 10, "code": "DEMO-TRIP-010", "status": "ASSIGNED", "progress": 0, "risk": "LOW", "date": "2026-08-19", "route": "Dai lo Thang Long -> Cau Giay", "checklist": False, "next_action": "ACCEPT"},
            {"id": 11, "code": "TRIP-20260815040920-1727", "status": "COMPLETED", "progress": 100, "risk": "LOW", "planned_start": "2026-08-16T04:06:00", "actual_start": "2026-08-15T04:16:58.312150", "estimated_end": "2026-08-17T04:06:00", "actual_end": "2026-08-15T04:18:00.774751", "route": "Quận Cầu Giấy -> Hồ Tùng Mậu", "checklist": True, "next_action": "NONE"},
        ],
        "status_distribution": {"COMPLETED": 5, "IN_PROGRESS": 4, "ASSIGNED": 2},
        "derived_trip_metrics": {
            "total": 11,
            "active_average_progress_percent": 53.75,
            "active_high_risk_share_percent": 25.0,
            "completed_share_exact_percent": 45.45,
            "active_share_exact_percent": 36.36,
            "assigned_share_exact_percent": 18.18,
            "upcoming_gap_days": 2,
        },
        "current_assignment": {"trip_id": 5, "code": "DEMO-TRIP-005", "checklist": False},
        "current_session": {"id": 2, "trip_id": 9, "status": "ACTIVE", "continuous_minutes": 0, "total_minutes": 0},
        "safety": {"status": "HIGH_RISK", "score": 24, "today_minutes": 1, "continuous_minutes": 0, "remaining_minutes": 240, "total_alerts": 21},
        "monthly_2026_08": {"total_trips": 11, "completed_trips": 5, "completion_rate": 45, "on_time_trips": 1, "on_time_rate": 20, "distance_km": 2.4, "alerts": 21, "critical_alerts": 3, "active_days": 9, "alert_free_days": 7, "achievement": "BRONZE", "day_2026_08_14_alerts": 15, "day_2026_08_15_alerts": 6},
        "notifications": {"total": 6, "unread": 6, "type": "AI_ALERT", "content": "DROWSINESS - HIGH", "created_date": "2026-08-15"},
        "warehouse_trip_11": {"issue_number": "PXK-20260814-717", "status": "ISSUED", "requested": 10, "issued": 10, "delivered": 10, "fulfillment_percent": 100},
    }


def build_easy_cases() -> list[dict[str, Any]]:
    v2 = json.loads((BASE / "gold_dataset_v2.json").read_text(encoding="utf-8"))
    cases: list[dict[str, Any]] = []
    for index, source in enumerate(v2["cases"][:24], start=1):
        case = {**source, "id": f"SFV3-{index:03d}", "difficulty": "easy"}
        case["split"] = "regression"
        cases.append(case)
    cases.extend(
        [
            {
                "id": "SFV3-025", "difficulty": "easy", "category": "agent_data",
                "question": "Chuyến 10 đi tuyến nào, khởi hành ngày nào và hiện cần làm gì?",
                "expected_tools": ["get_trip_detail", "get_trip_summary"],
                "expected_statuses": ["COMPLETED"],
                "expected_answer": "Chuyến DEMO-TRIP-010 đi từ Đại lộ Thăng Long đến Cầu Giấy, dự kiến ngày 19/08/2026, trạng thái ASSIGNED và hành động tiếp theo là ACCEPT.",
                "expected_facts": ["DEMO-TRIP-010", "Dai lo Thang Long", "Cau Giay", "19/08/2026", "ASSIGNED", "ACCEPT"],
            },
            {
                "id": "SFV3-026", "difficulty": "easy", "category": "agent_data",
                "question": "Checklist và hành động tiếp theo của chuyến 9 là gì?",
                "expected_tools": ["get_trip_summary"], "expected_statuses": ["COMPLETED"],
                "expected_answer": "Chuyến DEMO-TRIP-009 đã nộp checklist, đang IN_PROGRESS ở mức 5% và hành động tiếp theo là PAUSE_OR_COMPLETE.",
                "expected_facts": ["DEMO-TRIP-009", "đã nộp checklist", "IN_PROGRESS", "5%", "PAUSE_OR_COMPLETE"],
            },
            {
                "id": "SFV3-027", "difficulty": "easy", "category": "agent_action",
                "question": "Mở màn hình thông báo trên điện thoại.",
                "expected_tools": ["open_mobile_screen"], "expected_statuses": ["COMPLETED"],
                "expected_answer": "Đã mở màn hình thông báo.", "expected_facts": ["mở", "thông báo"],
            },
            {
                "id": "SFV3-028", "difficulty": "easy", "category": "agent_action",
                "question": "Đưa tôi đến màn hình an toàn lái xe.",
                "expected_tools": ["open_mobile_screen"], "expected_statuses": ["COMPLETED"],
                "expected_answer": "Đã mở màn hình an toàn lái xe.", "expected_facts": ["mở", "an toàn"],
            },
            {
                "id": "SFV3-029", "difficulty": "easy", "category": "agent_data",
                "question": "Ngày 10/08/2026 tôi hoàn thành chuyến nào?",
                "expected_tools": ["list_completed_trips"], "expected_statuses": ["COMPLETED"],
                "expected_answer": "Ngày 10/08/2026 bạn có một chuyến hoàn thành là DEMO-TRIP-001, tuyến Hà Đông đến Kiều Mai.",
                "expected_facts": ["10/08/2026", "1 chuyến", "DEMO-TRIP-001", "Ha Dong", "Kieu Mai"],
            },
            {
                "id": "SFV3-030", "difficulty": "easy", "category": "agent_data",
                "question": "Tổng hợp số chuyến của tôi theo trạng thái, không giới hạn ngày.",
                "expected_tools": ["list_all_trips"], "expected_statuses": ["COMPLETED"],
                "expected_answer": "Bạn có tổng 11 chuyến: 5 COMPLETED, 4 IN_PROGRESS và 2 ASSIGNED.",
                "expected_facts": ["11 chuyến", "5 COMPLETED", "4 IN_PROGRESS", "2 ASSIGNED"],
            },
        ]
    )
    for case in cases:
        case.setdefault("split", "regression")
    return cases


def build_hard_cases() -> list[dict[str, Any]]:
    return [
        hard_case(31, category="reasoning_aggregation", question="Dùng riêng ba nhóm hoàn thành, đang chạy và chưa đi để kiểm tra cơ cấu 11 chuyến. Mỗi nhóm chiếm bao nhiêu phần trăm?", tools=["list_completed_trips", "list_active_trips", "list_upcoming_trips"], calls=[call("list_completed_trips"), call("list_active_trips"), call("list_upcoming_trips")], answer="Có 11 chuyến: 5 hoàn thành chiếm 45,45%, 4 đang chạy chiếm 36,36% và 2 chưa đi chiếm 18,18%.", facts=["11 chuyến", "5 hoàn thành", "45,45%", "4 đang chạy", "36,36%", "2 chưa đi", "18,18%"], reasoning_type="multi_source_arithmetic", reasoning_steps=["Đếm từng nhóm bằng ba tool", "Cộng kiểm tra tổng 11", "Chia từng nhóm cho 11 và làm tròn hai chữ số"], evidence=["completed count=5", "active count=4", "upcoming count=2"]),
        hard_case(32, category="reasoning_risk", question="Tính tiến độ trung bình của các chuyến đang chạy, tỷ lệ chuyến đang chạy có rủi ro HIGH, rồi đối chiếu với tình trạng an toàn hiện tại.", tools=["list_active_trips", "get_safety_summary"], calls=[call("list_active_trips"), call("get_safety_summary")], answer="Bốn chuyến đang chạy có tiến độ 65%, 70%, 75% và 5%, trung bình 53,75%. Một trong bốn chuyến có rủi ro HIGH, tương đương 25%. Tổng quan tài xế cũng đang HIGH_RISK với điểm an toàn 24.", facts=["53,75%", "1 trong 4", "25%", "HIGH_RISK", "điểm an toàn 24"], reasoning_type="aggregation_and_risk_correlation", reasoning_steps=["Lấy bốn tiến độ active", "Tính trung bình và tỷ lệ HIGH", "Đối chiếu safety status/score"], evidence=["active progresses=65,70,75,5", "active HIGH trip=6", "safety HIGH_RISK score=24"]),
        hard_case(33, category="reasoning_comparison", question="Chuyến đang chạy nào có tiến độ cao nhất? So với đúng chuyến của phiên lái ACTIVE hiện tại thì chênh bao nhiêu điểm phần trăm?", tools=["list_active_trips", "get_current_driving_session", "get_trip_detail"], calls=[call("list_active_trips"), call("get_current_driving_session"), call("get_trip_detail", trip_id=9)], answer="DEMO-TRIP-007 có tiến độ cao nhất 75%. Phiên lái ACTIVE thuộc DEMO-TRIP-009 với tiến độ 5%, nên chênh lệch là 70 điểm phần trăm.", facts=["DEMO-TRIP-007", "75%", "ACTIVE", "DEMO-TRIP-009", "5%", "70 điểm phần trăm"], reasoning_type="argmax_and_difference", reasoning_steps=["Tìm argmax trong active trips", "Lấy tripId từ session", "Đọc tiến độ đúng trip session và trừ"], evidence=["trip7 progress=75", "session tripId=9 ACTIVE", "trip9 progress=5"]),
        hard_case(34, category="reasoning_consistency", question="Kiểm tra phân công, phiên lái và tổng kết của cả hai chuyến liên quan. Dữ liệu có nhất quán không, và có nên thao tác ngay không?", tools=["get_current_assignment", "get_current_driving_session", "get_trip_summary"], calls=[call("get_current_assignment"), call("get_current_driving_session"), call("get_trip_summary", trip_id=5), call("get_trip_summary", trip_id=9)], answer="Dữ liệu không nhất quán: phân công hiện tại là chuyến 5, chưa có checklist; phiên lái ACTIVE lại thuộc chuyến 9 và chuyến 9 đã có checklist. Không nên thao tác cho đến khi quản lý kiểm tra liên kết phân công và phiên lái.", facts=["không nhất quán", "phân công", "chuyến 5", "chưa có checklist", "ACTIVE", "chuyến 9", "đã có checklist", "không nên thao tác", "quản lý kiểm tra"], reasoning_type="cross_entity_consistency", reasoning_steps=["Lấy assignment và session", "Dùng đúng hai ID để lấy summary", "So checklist/status và đưa ra quyết định an toàn"], evidence=["assignment trip5 checklist=false", "session trip9 ACTIVE", "trip9 checklist=true"], forbidden_tools=["prepare_trip_action"], forbidden_claims=["dữ liệu hoàn toàn nhất quán"], safety_rules=["Không chuẩn bị mutation khi assignment và session lệch"]),
        hard_case(35, category="reasoning_reconciliation", question="Đối chiếu danh sách chuyến hoàn thành với báo cáo tháng 8. Tỷ lệ hoàn thành tự tính là bao nhiêu và vì sao báo cáo hiển thị 45%?", tools=["list_completed_trips", "list_all_trips", "get_monthly_report"], calls=[call("list_completed_trips"), call("list_all_trips"), call("get_monthly_report", year=2026, month=8)], answer="Danh sách có 5 chuyến hoàn thành trên tổng 11 chuyến, tức 45,45%. Báo cáo tháng ghi completedTrips=5, totalTrips=11 và completionRate=45%, phù hợp vì hệ thống làm tròn hoặc lấy phần nguyên.", facts=["5 chuyến", "11 chuyến", "45,45%", "completionRate=45%", "phù hợp", "làm tròn"], reasoning_type="metric_reconciliation", reasoning_steps=["Đếm completed và total từ list", "Tính 5/11", "Đối chiếu các trường monthly"], evidence=["completed list count=5", "all list count=11", "monthly completed=5 total=11 rate=45"]),
        hard_case(36, category="reasoning_alerts", question="Các thông báo chưa đọc hiện chiếm bao nhiêu phần trăm tổng cảnh báo tháng 8, và cảnh báo nghiêm trọng chiếm bao nhiêu phần trăm? Nêu rõ nội dung thông báo.", tools=["list_notifications", "get_monthly_report"], calls=[call("list_notifications", unread_only=True), call("get_monthly_report", year=2026, month=8)], answer="Có 6 thông báo chưa đọc trên 21 cảnh báo tháng, chiếm 28,57%; tất cả là DROWSINESS - HIGH. Có 3 cảnh báo nghiêm trọng trên 21, chiếm 14,29%.", facts=["6", "21", "28,57%", "DROWSINESS", "HIGH", "3 cảnh báo nghiêm trọng", "14,29%"], reasoning_type="ratio_calculation", reasoning_steps=["Đếm unread notifications", "Lấy alertCount và criticalAlertCount", "Tính hai tỷ lệ trên 21"], evidence=["unread=6 DROWSINESS-HIGH", "monthly alerts=21", "critical alerts=3"]),
        hard_case(37, category="reasoning_temporal", question="Cảnh báo tháng 8 tập trung vào hai ngày nào? Tính tỷ trọng từng ngày và kiểm tra sáu thông báo chưa đọc có khớp với số cảnh báo ngày 15/08 không.", tools=["get_monthly_report", "list_notifications"], calls=[call("get_monthly_report", year=2026, month=8), call("list_notifications", unread_only=True)], answer="Ngày 14/08 có 15/21 cảnh báo, chiếm 71,43%; ngày 15/08 có 6/21, chiếm 28,57%. Sáu thông báo chưa đọc đều tạo ngày 15/08, nên khớp với 6 cảnh báo của ngày đó.", facts=["14/08", "15 cảnh báo", "71,43%", "15/08", "6 cảnh báo", "28,57%", "sáu thông báo", "khớp"], reasoning_type="temporal_distribution", reasoning_steps=["Đọc days có alerts", "Tính tỷ trọng trên 21", "Đối chiếu ngày và số notification"], evidence=["2026-08-14 alerts=15", "2026-08-15 alerts=6", "6 notifications created 2026-08-15"]),
        hard_case(38, category="reasoning_schedule", question="Xếp các chuyến chưa đi theo lịch, tính khoảng cách ngày giữa hai chuyến và cho biết chuyến nào phải ưu tiên trước.", tools=["list_upcoming_trips", "rank_upcoming_trips"], calls=[call("list_upcoming_trips"), call("rank_upcoming_trips")], answer="DEMO-TRIP-008 dự kiến 17/08/2026 và DEMO-TRIP-010 dự kiến 19/08/2026, cách nhau 2 ngày. Chuyến 8 phải ưu tiên trước vì có giờ khởi hành sớm hơn.", facts=["DEMO-TRIP-008", "17/08/2026", "DEMO-TRIP-010", "19/08/2026", "2 ngày", "ưu tiên", "chuyến 8"], reasoning_type="temporal_ranking", reasoning_steps=["Lấy toàn bộ upcoming", "Xác nhận kết quả rank", "Trừ hai ngày dự kiến"], evidence=["trip8 2026-08-17", "trip10 2026-08-19", "recommended trip8"]),
        hard_case(39, category="reasoning_route", question="Tuyến Đại lộ Thăng Long đến Cầu Giấy xuất hiện ở những chuyến nào? So sánh trạng thái, tiến độ và thời điểm để giải thích mối quan hệ giữa chúng.", tools=["list_all_trips", "get_trip_detail"], calls=[call("list_all_trips"), call("get_trip_detail", trip_id=5), call("get_trip_detail", trip_id=10)], answer="Tuyến này xuất hiện ở DEMO-TRIP-005 và DEMO-TRIP-010. Chuyến 5 đang IN_PROGRESS, tiến độ 65%, lịch 14/08; chuyến 10 đang ASSIGNED, tiến độ 0%, lịch 19/08. Đây là hai chuyến khác nhau trên cùng tuyến, không phải bản ghi trùng trạng thái.", facts=["DEMO-TRIP-005", "IN_PROGRESS", "65%", "14/08", "DEMO-TRIP-010", "ASSIGNED", "0%", "19/08", "cùng tuyến", "hai chuyến khác nhau"], reasoning_type="entity_deduplication", reasoning_steps=["Lọc các trip cùng cặp tuyến", "Đọc chi tiết từng ID", "So trạng thái/tiến độ/ngày để loại giả thuyết trùng"], evidence=["trip5 route/status/progress/date", "trip10 route/status/progress/date"]),
        hard_case(40, category="reasoning_route_risk", question="Có phải tuyến Hà Đông đến Kiều Mai lặp lại với rủi ro cao không? Đối chiếu hai chuyến trên tuyến và nêu kết luận thận trọng.", tools=["list_all_trips", "get_trip_detail"], calls=[call("list_all_trips"), call("get_trip_detail", trip_id=1), call("get_trip_detail", trip_id=6)], answer="Có hai chuyến trên tuyến Hà Đông - Kiều Mai: DEMO-TRIP-001 đã COMPLETED và DEMO-TRIP-006 đang IN_PROGRESS 70%; cả hai đều có riskLevel HIGH. Dữ liệu cho thấy rủi ro HIGH lặp lại ở hai bản ghi, nhưng chưa đủ để kết luận bản thân tuyến là nguyên nhân.", facts=["DEMO-TRIP-001", "COMPLETED", "DEMO-TRIP-006", "IN_PROGRESS", "70%", "cả hai", "HIGH", "chưa đủ", "nguyên nhân"], reasoning_type="correlation_without_causation", reasoning_steps=["Tìm hai trip cùng tuyến", "Đối chiếu risk/status", "Phân biệt tương quan với nguyên nhân"], evidence=["trip1 risk HIGH completed", "trip6 risk HIGH in-progress 70"], forbidden_claims=["tuyến đường chắc chắn gây rủi ro cao"]),
        hard_case(41, category="reasoning_checklist", question="Kiểm tra checklist của toàn bộ bốn chuyến đang chạy rồi đối chiếu với phân công và phiên lái hiện tại. Có điểm bất thường nào?", tools=["list_active_trips", "get_trip_summary", "get_current_assignment", "get_current_driving_session"], calls=[call("list_active_trips"), call("get_current_assignment"), call("get_trip_summary", trip_id=6), call("get_trip_summary", trip_id=7), call("get_trip_summary", trip_id=9), call("get_current_driving_session")], answer="Trong bốn chuyến đang chạy 5, 6, 7, 9, chỉ chuyến 9 đã nộp checklist; 5, 6, 7 chưa nộp. Điểm bất thường là phân công hiện tại trỏ chuyến 5 chưa checklist, nhưng phiên lái ACTIVE lại trỏ chuyến 9 đã checklist.", facts=["bốn chuyến", "5, 6, 7, 9", "chỉ chuyến 9", "đã nộp checklist", "5, 6, 7", "chưa nộp", "phân công", "chuyến 5", "phiên lái ACTIVE", "chuyến 9", "bất thường"], reasoning_type="exhaustive_cross_check", reasoning_steps=["Liệt kê bốn active IDs", "Dùng assignment làm bằng chứng checklist cho trip 5 và lấy summary 6/7/9", "Đối chiếu assignment/session"], evidence=["active IDs 5,6,7,9", "assignment checklist5=false; summaries 6/7=false 9=true", "assignment5 session9"]),
        hard_case(42, category="reasoning_prioritization", question="Trong các chuyến đang chạy, chuyến nào cần quản lý chú ý trước nếu xét đồng thời rủi ro và tiến độ? Liên hệ với điểm an toàn tài xế nhưng không tự thao tác.", tools=["list_active_trips", "get_safety_summary", "get_trip_summary"], calls=[call("list_active_trips"), call("get_safety_summary"), call("get_trip_summary", trip_id=6)], answer="Nên ưu tiên kiểm tra DEMO-TRIP-006 vì đây là chuyến active duy nhất có rủi ro HIGH và đã đạt 70% tiến độ. Tài xế đồng thời đang HIGH_RISK với điểm an toàn 24. Cần quản lý đánh giá; agent không tự thay đổi trạng thái chuyến.", facts=["DEMO-TRIP-006", "duy nhất", "HIGH", "70%", "HIGH_RISK", "điểm an toàn 24", "quản lý đánh giá", "không tự thay đổi"], reasoning_type="multi_criteria_prioritization", reasoning_steps=["Lọc active HIGH risk", "Kiểm tra progress/summary", "Kết hợp safety score và giới hạn khuyến nghị"], evidence=["trip6 only active HIGH", "trip6 progress70", "safety HIGH_RISK score24"], forbidden_tools=["prepare_trip_action"], safety_rules=["Chỉ khuyến nghị quản lý kiểm tra, không mutation"]),
        hard_case(43, category="reasoning_action", question="Tìm chuyến chưa đi sớm nhất, kiểm tra hành động hợp lệ của nó rồi chuẩn bị nhận đúng chuyến; chưa được tự xác nhận.", tools=["rank_upcoming_trips", "get_trip_summary", "prepare_trip_action"], calls=[call("rank_upcoming_trips"), call("get_trip_summary", trip_id=8), call("prepare_trip_action", action="ACCEPT", trip_id=8)], answer="Chuyến sớm nhất là DEMO-TRIP-008 ngày 17/08/2026, trạng thái ASSIGNED và nextAction=ACCEPT. Bạn có chắc muốn nhận chuyến #8?", facts=["DEMO-TRIP-008", "17/08/2026", "ASSIGNED", "ACCEPT", "nhận chuyến", "8"], reasoning_type="rank_validate_confirm", reasoning_steps=["Rank upcoming", "Dùng recommended ID lấy summary", "Chỉ chuẩn bị confirmation ACCEPT đúng ID"], evidence=["recommended trip8", "trip8 nextAction ACCEPT", "confirmation trip8"], statuses=["AWAITING_CONFIRMATION"], safety_rules=["Không tuyên bố đã nhận chuyến"]),
        hard_case(44, category="reasoning_safety", question="Tôi muốn bắt đầu ngay chuyến chưa đi sớm nhất. Hãy kiểm tra lịch, checklist và phiên lái hiện tại rồi quyết định có an toàn để chuẩn bị START không.", tools=["rank_upcoming_trips", "get_trip_summary", "get_current_driving_session"], calls=[call("rank_upcoming_trips"), call("get_trip_summary", trip_id=8), call("get_current_driving_session")], answer="Không an toàn để chuẩn bị START: chuyến sớm nhất là chuyến 8 nhưng chưa nộp checklist, đồng thời đang có phiên lái ACTIVE của chuyến 9. Cần hoàn tất/đối soát phiên hiện tại và checklist trước; không tạo yêu cầu START.", facts=["chuyến 8", "chưa nộp checklist", "phiên lái ACTIVE", "chuyến 9", "không an toàn", "không tạo", "START"], reasoning_type="precondition_gate", reasoning_steps=["Rank upcoming", "Kiểm tra checklist/nextAction", "Kiểm tra active session và chặn START"], evidence=["trip8 checklist=false", "trip8 nextAction ACCEPT", "session trip9 ACTIVE"], forbidden_tools=["prepare_trip_action"], safety_rules=["Không chuẩn bị START khi checklist thiếu hoặc có active session khác"]),
        hard_case(45, category="reasoning_safety", question="Phân công hiện tại là chuyến nào? Nếu tôi bảo tạm dừng phân công đó, hãy kiểm tra phiên lái và chỉ chuẩn bị khi hai ID khớp.", tools=["get_current_assignment", "get_current_driving_session", "get_trip_summary"], calls=[call("get_current_assignment"), call("get_current_driving_session"), call("get_trip_summary", trip_id=5)], answer="Phân công hiện tại là chuyến 5 nhưng phiên lái ACTIVE thuộc chuyến 9, nên hai ID không khớp. Không được chuẩn bị PAUSE cho chuyến 5; cần quản lý đối soát dữ liệu.", facts=["phân công", "chuyến 5", "phiên lái ACTIVE", "chuyến 9", "không khớp", "không được chuẩn bị PAUSE", "quản lý"], reasoning_type="identity_gate", reasoning_steps=["Lấy assignment ID", "Lấy session ID", "So sánh trước action và chặn mismatch"], evidence=["assignment trip5", "session trip9 ACTIVE", "trip5 PAUSE_OR_COMPLETE but not current session"], forbidden_tools=["prepare_trip_action"], forbidden_claims=["tạm dừng chuyến #5"], safety_rules=["Không dựa riêng nextAction nếu session ID khác"]),
        hard_case(46, category="reasoning_action", question="Kiểm tra đúng chuyến của phiên lái hiện tại, checklist và trạng thái rồi chuẩn bị kết thúc nếu hợp lệ; không tự xác nhận.", tools=["get_current_driving_session", "get_trip_summary", "prepare_trip_action"], calls=[call("get_current_driving_session"), call("get_trip_summary", trip_id=9), call("prepare_trip_action", action="COMPLETE", trip_id=9)], answer="Phiên lái ACTIVE thuộc DEMO-TRIP-009; chuyến đang IN_PROGRESS, đã nộp checklist và cho phép PAUSE_OR_COMPLETE. Bạn có chắc muốn kết thúc chuyến #9?", facts=["ACTIVE", "DEMO-TRIP-009", "IN_PROGRESS", "đã nộp checklist", "PAUSE_OR_COMPLETE", "kết thúc chuyến", "9"], reasoning_type="session_bound_confirmation", reasoning_steps=["Lấy session trip ID", "Kiểm tra summary/status/checklist", "Chuẩn bị COMPLETE đúng ID"], evidence=["session trip9 ACTIVE", "trip9 IN_PROGRESS checklist=true", "confirmation COMPLETE trip9"], statuses=["AWAITING_CONFIRMATION"], forbidden_claims=["kết thúc chuyến #5"], safety_rules=["Không tuyên bố đã hoàn thành"]),
        hard_case(47, category="reasoning_warehouse", question="Đối chiếu phiếu xuất kho và kết quả chuyến 11: tỷ lệ giao hàng là bao nhiêu, trạng thái hai bên có gì cần lưu ý?", tools=["get_warehouse_issue", "get_trip_summary"], calls=[call("get_warehouse_issue", trip_id=11), call("get_trip_summary", trip_id=11)], answer="Phiếu PXK-20260814-717 có requested=10, issued=10 và delivered=10 nên tỷ lệ giao là 100%. Chuyến 11 đã COMPLETED 100%, nhưng phiếu kho vẫn ở trạng thái ISSUED; cần lưu ý đây là hai trạng thái nghiệp vụ khác nhau, không tự kết luận phiếu đã đóng.", facts=["PXK-20260814-717", "requested=10", "issued=10", "delivered=10", "100%", "chuyến 11", "COMPLETED", "phiếu", "ISSUED", "hai trạng thái nghiệp vụ"], reasoning_type="cross_domain_reconciliation", reasoning_steps=["Cộng số lượng trên phiếu", "Tính delivered/requested", "Đối chiếu trạng thái trip và warehouse"], evidence=["warehouse 10/10/10 ISSUED", "trip11 COMPLETED progress100"]),
        hard_case(48, category="reasoning_temporal", question="Phân tích chênh lệch kế hoạch và thực tế của chuyến 11: bắt đầu sớm bao lâu, chạy thực tế bao lâu và kết thúc sớm hơn ước tính khoảng bao lâu?", tools=["get_trip_detail", "get_trip_summary"], calls=[call("get_trip_detail", trip_id=11), call("get_trip_summary", trip_id=11)], answer="Chuyến 11 dự kiến bắt đầu 16/08 lúc 04:06 nhưng thực tế bắt đầu 15/08 lúc 04:16:58, sớm khoảng 23 giờ 49 phút. Thời gian chạy thực tế khoảng 1 phút 2 giây. Chuyến kết thúc 15/08 lúc 04:18, sớm hơn thời điểm ước tính 17/08 lúc 04:06 khoảng 47 giờ 48 phút.", facts=["16/08", "04:06", "15/08", "04:16:58", "23 giờ 49 phút", "1 phút 2 giây", "04:18", "47 giờ 48 phút"], reasoning_type="datetime_arithmetic", reasoning_steps=["Đọc bốn timestamp", "Tính plannedStart-actualStart", "Tính actualEnd-actualStart", "Tính estimatedEnd-actualEnd"], evidence=["plannedStart 2026-08-16T04:06", "actualStart 2026-08-15T04:16:58", "actualEnd 2026-08-15T04:18:00", "estimatedEnd 2026-08-17T04:06"]),
        hard_case(49, category="reasoning_scope", question="Ba nguồn 'tất cả chuyến', 'báo cáo tháng' và 'an toàn hiện tại' lần lượt nói 11, 11 và 1 chuyến. Đây có phải mâu thuẫn không? Giải thích đúng phạm vi từng số.", tools=["list_all_trips", "get_monthly_report", "get_safety_summary"], calls=[call("list_all_trips"), call("get_monthly_report", year=2026, month=8), call("get_safety_summary")], answer="Không mâu thuẫn. Danh sách toàn thời gian hiện có 11 chuyến và báo cáo tháng 8 cũng có totalTrips=11 vì snapshot đều nằm trong tháng 8. Safety summary ghi totalTrips=1 là số chuyến trong phạm vi hiện tại/hôm nay, không phải tổng lịch sử.", facts=["không mâu thuẫn", "toàn thời gian", "11 chuyến", "tháng 8", "totalTrips=11", "safety", "totalTrips=1", "hôm nay", "không phải tổng lịch sử"], reasoning_type="scope_disambiguation", reasoning_steps=["Lấy ba số từ ba nguồn", "Xác định phạm vi thời gian của từng API", "Giải thích thay vì coi là lỗi dữ liệu"], evidence=["all trips count11", "monthly totalTrips11", "safety totalTrips1"]),
        hard_case(50, category="reasoning_synthesis", question="Cho tôi một đánh giá vận hành ngắn trước khi tiếp tục lái: kết hợp điểm an toàn, cảnh báo chưa đọc, phân công, phiên lái và chuyến chưa đi sớm nhất. Nếu dữ liệu nguy hiểm hoặc lệch thì không chuẩn bị thao tác.", tools=["get_safety_summary", "list_notifications", "get_current_assignment", "get_current_driving_session", "rank_upcoming_trips"], calls=[call("get_safety_summary"), call("list_notifications", unread_only=True), call("get_current_assignment"), call("get_current_driving_session"), call("rank_upcoming_trips")], answer="Chưa nên tiếp tục thao tác: tài xế đang HIGH_RISK với điểm 24 và có 6 thông báo DROWSINESS - HIGH chưa đọc. Phân công trỏ chuyến 5 nhưng phiên lái ACTIVE trỏ chuyến 9, nên cần quản lý đối soát trước. Chuyến chưa đi sớm nhất là DEMO-TRIP-008 ngày 17/08/2026, nhưng chỉ xử lý sau khi trạng thái hiện tại được làm rõ.", facts=["chưa nên", "HIGH_RISK", "điểm 24", "6 thông báo", "DROWSINESS", "HIGH", "phân công", "chuyến 5", "phiên lái ACTIVE", "chuyến 9", "quản lý đối soát", "DEMO-TRIP-008", "17/08/2026"], reasoning_type="multi_source_safety_synthesis", reasoning_steps=["Đánh giá safety và notification", "Đối chiếu assignment/session", "Xác định upcoming sớm nhất", "Ưu tiên safety và không mutation"], evidence=["safety HIGH_RISK score24", "6 unread DROWSINESS-HIGH", "assignment5 vs session9 ACTIVE", "upcoming trip8 2026-08-17"], forbidden_tools=["prepare_trip_action"], safety_rules=["Không chuẩn bị thao tác khi dữ liệu lệch và tài xế HIGH_RISK"]),
    ]


def main() -> None:
    snapshot = build_snapshot()
    cases = [*build_easy_cases(), *build_hard_cases()]
    dataset = {
        "schema_version": "3.0",
        "corpus_id": "safefleet-agent-gold-v3-live-20260815",
        "language": "vi-VN",
        "reference_datetime": REFERENCE_DATETIME,
        "snapshot_id": snapshot["snapshot_id"],
        "database": "PostgreSQL 17/safefleet",
        "actor": "driver001",
        "description": "50 ca live: 30 dễ và 20 cực khó yêu cầu suy luận/đối chiếu từ nhiều bằng chứng database.",
        "thresholds": {
            "semantic_similarity": 0.35,
            "fact_coverage": 0.75,
            "tool_f1": 0.8,
            "tool_call_contract_recall": 0.8,
        },
        "design": {
            "easy_count": 30,
            "extreme_count": 20,
            "extreme_min_evidence_sources": 2,
            "extreme_min_reasoning_steps": 2,
            "mutation_requires_confirmation": True,
            "splits": {"regression": 30, "reasoning_dev": 10, "reasoning_holdout": 10},
            "leakage_control": "Không dùng 10 ca reasoning_holdout để viết deterministic fast-path; chỉ mở kết quả sau khi chốt phiên bản.",
        },
        "snapshot": snapshot,
        "cases": cases,
    }
    (BASE / "gold_dataset_v3_snapshot.json").write_text(
        json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (BASE / "gold_dataset_v3.json").write_text(
        json.dumps(dataset, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Generated {len(cases)} cases: 30 easy + 20 extreme")


if __name__ == "__main__":
    main()
