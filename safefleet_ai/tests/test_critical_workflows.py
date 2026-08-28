from __future__ import annotations

from service.agent.configuration import AgentConfigurationStore
from service.agent.models import AgentChatRequest, AgentConfigurationUpdate
from service.agent.orchestrator import AgentOrchestrator


def _store(tmp_path) -> AgentConfigurationStore:
    store = AgentConfigurationStore(
        str(tmp_path / "agent.json"),
        "test-encryption-secret-with-at-least-32-characters",
    )
    store.update(
        AgentConfigurationUpdate(
            enabled=True,
            api_key="sk-test-key-that-is-long-enough-for-validation",
            max_steps=6,
        )
    )
    return store


class NoOpenAi:
    def chat(self, *_args, **_kwargs):
        raise AssertionError("Critical workflow must not call the language model")


class FakeMcp:
    calls: list[tuple[str, dict]] = []

    def __init__(self, _authorization):
        type(self).calls = []

    def list_tools(self):
        names = (
            "list_all_trips",
            "list_completed_trips",
            "list_upcoming_trips",
            "rank_upcoming_trips",
            "get_trip_detail",
            "get_trip_summary",
            "get_current_assignment",
            "get_current_driving_session",
            "get_safety_summary",
            "list_notifications",
        )
        schema = {"type": "object", "properties": {}, "required": []}
        return [{"name": name, "description": name, "inputSchema": schema} for name in names]

    @staticmethod
    def _upcoming():
        return [
            {
                "id": trip_id,
                "tripCode": f"DEMO-TRIP-{trip_id:03d}",
                "startLocation": "Ha Dong" if trip_id == 6 else "Dai lo Thang Long",
                "endLocation": "Kieu Mai" if trip_id == 6 else "Cau Giay",
                "plannedStartTime": f"2026-08-{trip_id + 9:02d}T00:14:39",
                "status": "ASSIGNED",
                "progress": 0,
                "riskLevel": "HIGH" if trip_id == 6 else "LOW",
            }
            for trip_id in range(6, 11)
        ]

    def execute(self, name, arguments):
        type(self).calls.append((name, arguments))
        upcoming = self._upcoming()
        if name == "list_completed_trips":
            return {"ok": True, "count": 6, "trips": [{"id": value} for value in range(1, 7)]}
        if name == "list_upcoming_trips":
            return {"ok": True, "count": 5, "trips": upcoming}
        if name == "rank_upcoming_trips":
            return {
                "ok": True,
                "count": 5,
                "recommendedTrip": upcoming[0],
                "rankedTrips": upcoming,
            }
        if name == "list_all_trips":
            repeated = [
                {
                    "id": 5,
                    "tripCode": "DEMO-TRIP-005",
                    "startLocation": "Dai lo Thang Long",
                    "endLocation": "Cau Giay",
                    "plannedStartTime": "2026-08-14T00:14:39",
                    "status": "COMPLETED",
                    "progress": 100,
                    "riskLevel": "LOW",
                },
                upcoming[-1],
            ]
            return {"ok": True, "count": 11, "trips": repeated}
        if name == "get_trip_detail":
            all_trips = [
                {
                    "id": 5,
                    "tripCode": "DEMO-TRIP-005",
                    "startLocation": "Dai lo Thang Long",
                    "endLocation": "Cau Giay",
                    "plannedStartTime": "2026-08-14T00:14:39",
                    "status": "COMPLETED",
                    "progress": 100,
                    "riskLevel": "LOW",
                },
                *upcoming,
            ]
            return {
                "ok": True,
                "trip": next(item for item in all_trips if item["id"] == arguments["trip_id"]),
            }
        if name == "get_trip_summary":
            trip_id = int(arguments["trip_id"])
            trip = next(item for item in upcoming if item["id"] == trip_id)
            return {
                "ok": True,
                "summary": {
                    "trip": trip,
                    "checklistSubmitted": trip_id == 9,
                    "nextAction": "ACCEPT",
                },
            }
        if name == "get_current_assignment":
            return {"ok": True, "assignment": {"trip": upcoming[0], "checklistSubmitted": False}}
        if name == "get_current_driving_session":
            return {"ok": True, "session": None}
        if name == "get_safety_summary":
            return {
                "ok": True,
                "safety": {"status": "AVAILABLE", "safetyScore": 57, "totalTrips": 2},
            }
        if name == "list_notifications":
            return {"ok": True, "count": 14, "notifications": [{"id": value} for value in range(14)]}
        raise AssertionError(name)


def _respond(tmp_path, question: str):
    return AgentOrchestrator(_store(tmp_path), NoOpenAi(), FakeMcp).respond(
        AgentChatRequest(messages=[{"role": "user", "content": question}]),
        "Bearer driver-token",
    )


def test_upcoming_range_resolves_both_endpoint_ids_without_model(tmp_path) -> None:
    result = _respond(
        tmp_path,
        "Trong 5 chuyến chưa đi, chuyến nào sớm nhất và chuyến nào muộn nhất? "
        "Tính chênh lệch ngày và kiểm tra chi tiết mức rủi ro của hai đầu lịch.",
    )

    assert result.status == "COMPLETED"
    assert [step.tool for step in result.steps] == [
        "list_upcoming_trips",
        "rank_upcoming_trips",
        "get_trip_detail",
        "get_trip_detail",
    ]
    assert FakeMcp.calls[-2][1]["trip_id"] == 6
    assert FakeMcp.calls[-1][1]["trip_id"] == 10
    assert "4 ngày" in result.response_text
    assert result.run_metrics is not None and result.run_metrics.model_calls == 0


def test_checklist_audit_expands_every_trip_and_applies_safety_gate(tmp_path) -> None:
    result = _respond(
        tmp_path,
        "Kiểm tra checklist của toàn bộ năm chuyến chưa đi rồi đối chiếu với phân công "
        "và phiên lái hiện tại. Có điểm bất thường nào cần chặn thao tác?",
    )

    summary_ids = [
        arguments["trip_id"]
        for name, arguments in FakeMcp.calls
        if name == "get_trip_summary"
    ]
    assert summary_ids == [6, 7, 8, 9, 10]
    assert "đã checklist: 9" in result.response_text
    assert "chưa checklist: 6, 7, 8, 10" in result.response_text
    assert "chặn thao tác" in result.response_text


def test_assignment_pause_guard_never_prepares_mutation_without_active_session(tmp_path) -> None:
    result = _respond(
        tmp_path,
        "Phân công hiện tại là chuyến nào? Nếu tôi bảo tạm dừng phân công đó, hãy kiểm "
        "tra phiên lái và chỉ chuẩn bị khi hai ID khớp.",
    )

    assert [step.tool for step in result.steps] == [
        "get_current_assignment",
        "get_current_driving_session",
        "get_trip_summary",
    ]
    assert "không chuẩn bị PAUSE" in result.response_text
    assert all(step.tool != "prepare_trip_action" for step in result.steps)


def test_assignment_complete_guard_uses_evidence_without_model_or_mutation(tmp_path) -> None:
    result = _respond(
        tmp_path,
        "Kiểm tra phiên lái hiện tại, phân công và an toàn; chỉ chuẩn bị COMPLETE khi có "
        "session ACTIVE trỏ đúng một chuyến hợp lệ, nếu không thì dừng.",
    )

    assert [step.tool for step in result.steps] == [
        "get_current_driving_session",
        "get_current_assignment",
        "get_safety_summary",
    ]
    assert "không chuẩn bị COMPLETE" in result.response_text
    assert all(step.tool != "prepare_trip_action" for step in result.steps)
    assert result.run_metrics is not None and result.run_metrics.model_calls == 0


def test_route_comparison_fetches_detail_for_every_matching_trip(tmp_path) -> None:
    result = _respond(
        tmp_path,
        "Tuyến Đại lộ Thăng Long đến Cầu Giấy xuất hiện ở những chuyến nào? "
        "So sánh trạng thái, tiến độ và thời điểm.",
    )

    assert [step.tool for step in result.steps] == [
        "list_all_trips",
        "get_trip_detail",
        "get_trip_detail",
    ]
    assert "chuyến 5 (DEMO-TRIP-005) COMPLETED 100%" in result.response_text
    assert "chuyến 10 (DEMO-TRIP-010) ASSIGNED 0%" in result.response_text


def test_upcoming_schedule_calculates_intervals_and_high_risk_without_model(tmp_path) -> None:
    result = _respond(
        tmp_path,
        "Xếp các chuyến chưa đi theo lịch, tính khoảng cách ngày giữa các chuyến "
        "và chỉ ra chuyến rủi ro cao cần kiểm tra.",
    )

    assert [step.tool for step in result.steps] == [
        "list_upcoming_trips",
        "rank_upcoming_trips",
    ]
    assert "mỗi lịch liên tiếp cách nhau 1 ngày" in result.response_text
    assert "DEMO-TRIP-006" in result.response_text
    assert "risk HIGH" in result.response_text
    assert result.run_metrics is not None and result.run_metrics.model_calls == 0


def test_repeated_high_risk_route_reports_each_trip_and_avoids_causal_claim(tmp_path) -> None:
    result = _respond(
        tmp_path,
        "Ở bước tiếp theo, tuyến Đại lộ Thăng Long đến Cầu Giấy lặp lại; có phải tuyến này gây "
        "rủi ro cao không? Hãy đối chiếu hai chuyến trên tuyến.",
    )

    assert [step.tool for step in result.steps] == [
        "list_all_trips",
        "get_trip_detail",
        "get_trip_detail",
    ]
    assert "14/08/2026" in result.response_text
    assert "19/08/2026" in result.response_text
    assert "không đủ căn cứ kết luận nguyên nhân" in result.response_text
    assert result.run_metrics is not None and result.run_metrics.model_calls == 0


def test_operations_assessment_collects_all_sources_in_fixed_order(tmp_path) -> None:
    result = _respond(
        tmp_path,
        "Cho tôi một đánh giá vận hành ngắn trước khi tiếp tục lái: kết hợp điểm an toàn, "
        "cảnh báo chưa đọc, phân công, phiên lái và chuyến chưa đi sớm nhất.",
    )

    assert [step.tool for step in result.steps] == [
        "get_safety_summary",
        "list_notifications",
        "get_current_assignment",
        "get_current_driving_session",
        "rank_upcoming_trips",
    ]
    assert "điểm 57" in result.response_text
    assert "14 thông báo chưa đọc" in result.response_text
    assert "không có mutation" in result.response_text.lower()
