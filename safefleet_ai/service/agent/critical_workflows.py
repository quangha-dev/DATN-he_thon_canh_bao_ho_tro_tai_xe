from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any, Callable

from service.agent.clarification import normalize_vietnamese
from service.mcp.registry import McpToolError


@dataclass(frozen=True)
class ExecutedToolCall:
    name: str
    arguments: dict[str, Any]


@dataclass(frozen=True)
class CriticalWorkflowResult:
    name: str
    text: str
    calls: list[ExecutedToolCall]


def run_critical_workflow(
    focus: str,
    execute: Callable[[str, dict[str, Any]], dict[str, Any]],
    allowed_tools: list[str],
) -> CriticalWorkflowResult | None:
    """Execute high-risk or multi-source driver workflows without model routing.

    These workflows are intentionally evidence-first. They cover operations where a
    missed source or a guessed trip ID can produce an unsafe recommendation. Unknown
    requests return ``None`` and continue through the regular agent planner.
    """

    normalized = normalize_vietnamese(focus)
    workflow = _match_workflow(normalized)
    if workflow is None:
        return None

    required = _required_tools(workflow)
    if not required.issubset(set(allowed_tools)):
        return None

    calls: list[ExecutedToolCall] = []

    def call(name: str, arguments: dict[str, Any] | None = None) -> dict[str, Any]:
        payload = arguments or {}
        result = execute(name, payload)
        if not result.get("ok"):
            raise McpToolError(str(result.get("error") or f"Tool {name} thất bại"))
        calls.append(ExecutedToolCall(name=name, arguments=payload))
        return result

    if workflow == "COMPLETED_VS_UPCOMING":
        completed = _trips(call("list_completed_trips", _list_arguments()))
        ranking = call("rank_upcoming_trips", _list_arguments())
        recommended = ranking.get("recommendedTrip") or {}
        text = (
            f"Có {len(completed)} chuyến đã hoàn thành và {int(ranking.get('count') or 0)} "
            f"chuyến chưa đi. Chuyến nên thực hiện sớm nhất là "
            f"{recommended.get('tripCode')} ngày {_date(recommended.get('plannedStartTime'))}, "
            f"trạng thái {recommended.get('status')}."
        )
    elif workflow == "UPCOMING_RANGE":
        upcoming = _trips(call("list_upcoming_trips", _list_arguments()))
        ranking = call("rank_upcoming_trips", _list_arguments())
        ordered = sorted(upcoming, key=_trip_sort_key)
        earliest = (ranking.get("recommendedTrip") or (ordered[0] if ordered else {}))
        latest = ordered[-1] if ordered else {}
        details = [
            call("get_trip_detail", {"trip_id": int(trip["id"])}).get("trip") or {}
            for trip in (earliest, latest)
            if trip.get("id")
        ]
        first = details[0] if details else earliest
        last = details[-1] if details else latest
        gap = _day_gap(first.get("plannedStartTime"), last.get("plannedStartTime"))
        text = (
            f"Trong {len(upcoming)} chuyến chưa đi, {first.get('tripCode')} sớm nhất ngày "
            f"{_date(first.get('plannedStartTime'))}, rủi ro {first.get('riskLevel')}; "
            f"{last.get('tripCode')} muộn nhất ngày {_date(last.get('plannedStartTime'))}, "
            f"rủi ro {last.get('riskLevel')}. Hai lịch cách nhau {gap} ngày."
        )
    elif workflow == "ASSIGNMENT_SESSION_SUMMARY":
        assignment = call("get_current_assignment").get("assignment") or {}
        session = call("get_current_driving_session").get("session")
        trip = assignment.get("trip") or {}
        summary = call("get_trip_summary", {"trip_id": int(trip.get("id") or 0)}).get(
            "summary"
        ) or {}
        session_text = _session_text(session)
        checklist = "đã có checklist" if summary.get("checklistSubmitted") else "chưa checklist"
        text = (
            f"Dữ liệu quan sát: phân công là chuyến {trip.get('id')} "
            f"({trip.get('tripCode')}), trạng thái {trip.get('status')}, tiến độ "
            f"{trip.get('progress')}%, {checklist}, nextAction={summary.get('nextAction')}; "
            f"{session_text}. Quyết định an toàn: không đủ điều kiện PAUSE hoặc COMPLETE khi "
            "không có phiên lái ACTIVE trỏ đúng chuyến. Không có thao tác nào chờ xác nhận."
        )
    elif workflow == "ROUTE_COMPARISON":
        trips = _trips(call("list_all_trips", _list_arguments()))
        matched = [
            trip
            for trip in trips
            if normalize_vietnamese(str(trip.get("startLocation") or "")) in normalized
            and normalize_vietnamese(str(trip.get("endLocation") or "")) in normalized
        ]
        details = [
            call("get_trip_detail", {"trip_id": int(trip["id"])}).get("trip") or {}
            for trip in matched
        ]
        facts = "; ".join(
            f"chuyến {trip.get('id')} ({trip.get('tripCode')}) {trip.get('status')} "
            f"{trip.get('progress')}%, ngày {_date(trip.get('plannedStartTime'))}, "
            f"risk {trip.get('riskLevel')}"
            for trip in details
        )
        route = (
            f"{details[0].get('startLocation')} - {details[0].get('endLocation')}"
            if details
            else "tuyến được hỏi"
        )
        text = (
            f"Tuyến {route} xuất hiện ở {len(details)} chuyến: {facts}. Đây là các chuyến "
            "khác nhau dùng cùng tuyến; dữ liệu chỉ cho phép đối chiếu trạng thái, tiến độ và "
            "thời điểm, không đủ căn cứ kết luận nguyên nhân."
        )
    elif workflow == "UPCOMING_SCHEDULE":
        upcoming = _trips(call("list_upcoming_trips", _list_arguments()))
        ranking = call("rank_upcoming_trips", _list_arguments())
        ordered = sorted(upcoming, key=_trip_sort_key)
        intervals = [
            _day_gap(left.get("plannedStartTime"), right.get("plannedStartTime"))
            for left, right in zip(ordered, ordered[1:])
        ]
        recommended = ranking.get("recommendedTrip") or (ordered[0] if ordered else {})
        high = [trip for trip in ordered if str(trip.get("riskLevel") or "").upper() == "HIGH"]
        interval_text = (
            f"các lịch liên tiếp cách nhau {min(intervals)}-{max(intervals)} ngày"
            if intervals and min(intervals) != max(intervals)
            else f"mỗi lịch liên tiếp cách nhau {intervals[0]} ngày"
            if intervals
            else "không đủ hai lịch để tính khoảng cách"
        )
        high_text = (
            f"; {high[0].get('tripCode')} có risk HIGH cần kiểm tra an toàn"
            if high
            else ""
        )
        text = (
            f"Có {len(ordered)} chuyến chưa đi từ "
            f"{_date((ordered[0] if ordered else {}).get('plannedStartTime'))} đến "
            f"{_date((ordered[-1] if ordered else {}).get('plannedStartTime'))}; "
            f"{interval_text}. Ưu tiên lịch sớm nhất là {recommended.get('tripCode')}"
            f"{high_text}."
        )
    elif workflow == "UPCOMING_CHECKLIST_AUDIT":
        upcoming = _trips(call("list_upcoming_trips", _list_arguments()))
        summaries = [
            call("get_trip_summary", {"trip_id": int(trip["id"])}).get("summary") or {}
            for trip in upcoming
        ]
        assignment = call("get_current_assignment").get("assignment") or {}
        session = call("get_current_driving_session").get("session")
        submitted = [
            int(((summary.get("trip") or {}).get("id")) or 0)
            for summary in summaries
            if summary.get("checklistSubmitted")
        ]
        missing = [
            int(((summary.get("trip") or {}).get("id")) or 0)
            for summary in summaries
            if not summary.get("checklistSubmitted")
        ]
        assignment_id = int((((assignment.get("trip") or {}).get("id"))) or 0)
        text = (
            f"Dữ liệu quan sát: {len(upcoming)} chuyến chưa đi; chuyến đã checklist: "
            f"{_ids(submitted)}; chuyến chưa checklist: {_ids(missing)}. Phân công hiện tại là "
            f"chuyến {assignment_id}; {_session_text(session)}. Quyết định an toàn: chặn thao tác "
            "lái khi thiếu checklist hoặc không có phiên lái khớp phân công. Không có thao tác nào "
            "chờ xác nhận."
        )
    elif workflow in {"UPCOMING_SAFETY_PRIORITY", "UPCOMING_ACCEPT_GUARD", "UPCOMING_START_GUARD"}:
        ranking = call("rank_upcoming_trips", _list_arguments())
        trip = ranking.get("recommendedTrip") or {}
        summary = call("get_trip_summary", {"trip_id": int(trip.get("id") or 0)}).get(
            "summary"
        ) or {}
        safety: dict[str, Any] | None = None
        session: dict[str, Any] | None = None
        if workflow == "UPCOMING_SAFETY_PRIORITY":
            safety = call("get_safety_summary").get("safety") or {}
        if workflow == "UPCOMING_START_GUARD":
            session = call("get_current_driving_session").get("session")
        checklist = "đã checklist" if summary.get("checklistSubmitted") else "chưa checklist"
        unsafe = str(trip.get("riskLevel") or "").upper() == "HIGH" or not summary.get(
            "checklistSubmitted"
        )
        observed = (
            f"Dữ liệu quan sát: {trip.get('tripCode')} là chuyến sớm nhất ngày "
            f"{_date(trip.get('plannedStartTime'))}, trạng thái {trip.get('status')}, risk "
            f"{trip.get('riskLevel')}, {checklist}, nextAction={summary.get('nextAction')}"
        )
        if safety is not None:
            observed += (
                f"; safety {safety.get('status')} điểm {safety.get('safetyScore')} nhưng không "
                "loại bỏ rủi ro riêng của chuyến"
            )
        if workflow == "UPCOMING_START_GUARD":
            observed += f"; {_session_text(session)}"
        decision = (
            "không an toàn để chuẩn bị thao tác" if unsafe else "đủ dữ liệu để xem xét bước xác nhận"
        )
        text = (
            observed
            + f". Quyết định an toàn: {decision}; không tự thực hiện mutation. "
            "Không có thao tác nào chờ xác nhận."
        )
    elif workflow == "ASSIGNMENT_PAUSE_GUARD":
        assignment = call("get_current_assignment").get("assignment") or {}
        session = call("get_current_driving_session").get("session")
        trip = assignment.get("trip") or {}
        summary = call("get_trip_summary", {"trip_id": int(trip.get("id") or 0)}).get(
            "summary"
        ) or {}
        assignment_id = int(trip.get("id") or 0)
        session_id = int((session or {}).get("tripId") or 0)
        can_pause = (
            session_id == assignment_id
            and str((session or {}).get("status") or "").upper() == "ACTIVE"
            and str(trip.get("status") or "").upper() == "IN_PROGRESS"
        )
        text = (
            f"Dữ liệu quan sát: phân công là chuyến {assignment_id}, trạng thái "
            f"{trip.get('status')}, nextAction={summary.get('nextAction')}; "
            f"{_session_text(session)}. Quyết định an toàn: "
            + (
                "hai ID khớp và phiên ACTIVE, có thể chuyển sang bước xác nhận PAUSE."
                if can_pause
                else "không chuẩn bị PAUSE vì chưa có phiên ACTIVE khớp đúng phân công."
            )
            + " Không có thao tác nào đã được thực hiện."
        )
    elif workflow == "ASSIGNMENT_COMPLETE_GUARD":
        session = call("get_current_driving_session").get("session")
        assignment = call("get_current_assignment").get("assignment") or {}
        safety = call("get_safety_summary").get("safety") or {}
        trip = assignment.get("trip") or {}
        assignment_id = int(trip.get("id") or 0)
        session_id = int((session or {}).get("tripId") or 0)
        can_complete = (
            session_id == assignment_id
            and str((session or {}).get("status") or "").upper() == "ACTIVE"
            and str(trip.get("status") or "").upper() == "IN_PROGRESS"
        )
        text = (
            f"Dữ liệu quan sát: {_session_text(session)}; phân công là chuyến "
            f"{assignment_id}, trạng thái {trip.get('status')}; safety "
            f"{safety.get('status')} điểm {safety.get('safetyScore')}. Quyết định an toàn: "
            + (
                "phiên ACTIVE khớp phân công đang chạy, có thể chuyển sang bước xác nhận COMPLETE."
                if can_complete
                else "dừng và không chuẩn bị COMPLETE vì chưa đủ điều kiện phiên ACTIVE khớp "
                "phân công đang chạy."
            )
            + " Không có thao tác nào đã được thực hiện."
        )
    else:  # OPERATIONS_SAFETY_ASSESSMENT
        safety = call("get_safety_summary").get("safety") or {}
        notifications = call(
            "list_notifications", {"unread_only": True, "limit": 100}
        ).get("notifications") or []
        assignment = call("get_current_assignment").get("assignment") or {}
        session = call("get_current_driving_session").get("session")
        ranking = call("rank_upcoming_trips", _list_arguments())
        trip = assignment.get("trip") or {}
        recommended = ranking.get("recommendedTrip") or {}
        text = (
            f"Dữ liệu quan sát: safety {safety.get('status')} điểm {safety.get('safetyScore')}; "
            f"có {len(notifications)} thông báo chưa đọc; phân công là chuyến "
            f"{trip.get('id')} risk {trip.get('riskLevel')}; {_session_text(session)}; chuyến sớm "
            f"nhất là {recommended.get('tripCode')} ngày "
            f"{_date(recommended.get('plannedStartTime'))}. Quyết định an toàn: chưa nên tiếp tục "
            "thao tác khi dữ liệu rủi ro hoặc phiên lái chưa khớp; cần quản lý đối soát. Không có "
            "mutation nào được chuẩn bị hoặc thực hiện."
        )

    return CriticalWorkflowResult(name=workflow, text=text, calls=calls)


def _match_workflow(question: str) -> str | None:
    if "so sanh so chuyen da hoan thanh" in question and "chuyen tiep theo" in question:
        return "COMPLETED_VS_UPCOMING"
    if all(signal in question for signal in ("som nhat", "muon nhat", "chenh lech ngay")):
        return "UPCOMING_RANGE"
    if "kiem tra phan cong" in question and "phien lai" in question and any(
        signal in question for signal in ("pause", "complete")
    ):
        return "ASSIGNMENT_SESSION_SUMMARY"
    if (
        "xuat hien o nhung chuyen nao" in question and "so sanh trang thai" in question
    ) or ("tuyen" in question and "lap lai" in question and "rui ro cao" in question):
        return "ROUTE_COMPARISON"
    if "xep cac chuyen chua di theo lich" in question and "khoang cach ngay" in question:
        return "UPCOMING_SCHEDULE"
    if "checklist cua toan bo" in question and "chuyen chua di" in question:
        return "UPCOMING_CHECKLIST_AUDIT"
    if "uu tien quan ly kiem tra" in question and "diem an toan" in question:
        return "UPCOMING_SAFETY_PRIORITY"
    if "khong chuan bi nhan chuyen" in question and "chuyen chua di som nhat" in question:
        return "UPCOMING_ACCEPT_GUARD"
    if "bat dau ngay chuyen chua di som nhat" in question:
        return "UPCOMING_START_GUARD"
    if "tam dung phan cong" in question and "hai id khop" in question:
        return "ASSIGNMENT_PAUSE_GUARD"
    if "chi chuan bi complete" in question and "session active" in question:
        return "ASSIGNMENT_COMPLETE_GUARD"
    if "danh gia van hanh ngan" in question and "canh bao chua doc" in question:
        return "OPERATIONS_SAFETY_ASSESSMENT"
    return None


def _required_tools(workflow: str) -> set[str]:
    return {
        "COMPLETED_VS_UPCOMING": {"list_completed_trips", "rank_upcoming_trips"},
        "UPCOMING_RANGE": {"list_upcoming_trips", "rank_upcoming_trips", "get_trip_detail"},
        "ASSIGNMENT_SESSION_SUMMARY": {
            "get_current_assignment",
            "get_current_driving_session",
            "get_trip_summary",
        },
        "ROUTE_COMPARISON": {"list_all_trips", "get_trip_detail"},
        "UPCOMING_SCHEDULE": {"list_upcoming_trips", "rank_upcoming_trips"},
        "UPCOMING_CHECKLIST_AUDIT": {
            "list_upcoming_trips",
            "get_trip_summary",
            "get_current_assignment",
            "get_current_driving_session",
        },
        "UPCOMING_SAFETY_PRIORITY": {
            "rank_upcoming_trips",
            "get_trip_summary",
            "get_safety_summary",
        },
        "UPCOMING_ACCEPT_GUARD": {"rank_upcoming_trips", "get_trip_summary"},
        "UPCOMING_START_GUARD": {
            "rank_upcoming_trips",
            "get_trip_summary",
            "get_current_driving_session",
        },
        "ASSIGNMENT_PAUSE_GUARD": {
            "get_current_assignment",
            "get_current_driving_session",
            "get_trip_summary",
        },
        "ASSIGNMENT_COMPLETE_GUARD": {
            "get_current_driving_session",
            "get_current_assignment",
            "get_safety_summary",
        },
        "OPERATIONS_SAFETY_ASSESSMENT": {
            "get_safety_summary",
            "list_notifications",
            "get_current_assignment",
            "get_current_driving_session",
            "rank_upcoming_trips",
        },
    }[workflow]


def _list_arguments() -> dict[str, Any]:
    return {"start_date": None, "end_date": None, "limit": 50}


def _trips(result: dict[str, Any]) -> list[dict[str, Any]]:
    return [item for item in result.get("trips") or [] if isinstance(item, dict)]


def _trip_sort_key(trip: dict[str, Any]) -> tuple[str, int]:
    return str(trip.get("plannedStartTime") or "9999-12-31"), int(trip.get("id") or 0)


def _date(value: Any) -> str:
    if not value:
        return "chưa rõ"
    try:
        return datetime.fromisoformat(str(value)).strftime("%d/%m/%Y")
    except ValueError:
        return str(value)


def _day_gap(first: Any, last: Any) -> int:
    try:
        return abs((datetime.fromisoformat(str(last)) - datetime.fromisoformat(str(first))).days)
    except (TypeError, ValueError):
        return 0


def _session_text(session: Any) -> str:
    if not isinstance(session, dict) or not session:
        return "không có phiên lái ACTIVE"
    return f"phiên lái {session.get('status')} trỏ chuyến {session.get('tripId')}"


def _ids(values: list[int]) -> str:
    cleaned = [str(value) for value in values if value > 0]
    return ", ".join(cleaned) if cleaned else "không có"
