from __future__ import annotations

import json
import os

from fastapi.testclient import TestClient

os.environ.setdefault(
    "AGENT_ENCRYPTION_SECRET",
    "test-suite-encryption-secret-with-at-least-32-characters",
)
os.environ.setdefault("AI_INTERNAL_TOKEN", "test-internal-token")

from service.agent.clarification import (
    has_explicit_date_scope,
    needs_trip_scope_clarification,
    requests_other_driver_data,
    requests_unsupported_weather,
)
from service.agent.configuration import AgentConfigurationStore
from service.agent.models import (
    AgentChatRequest,
    AgentClientAction,
    AgentConfigurationUpdate,
    AgentStep,
)
from service.agent.orchestrator import AgentOrchestrator, Plan
from service.main import app


def _enabled_store(tmp_path) -> AgentConfigurationStore:
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


def test_generic_trip_question_requests_scope_before_calling_model(tmp_path) -> None:
    class NoOpenAi:
        def chat(self, *_args, **_kwargs):
            raise AssertionError("Không được gọi model khi câu hỏi chưa đủ phạm vi")

    class NoMcp:
        def __init__(self, _authorization):
            raise AssertionError("Không được gọi MCP khi câu hỏi chưa đủ phạm vi")

    result = AgentOrchestrator(_enabled_store(tmp_path), NoOpenAi(), NoMcp).respond(
        AgentChatRequest(messages=[{"role": "user", "content": "Tôi có chuyến nào không?"}]),
        "Bearer driver-token",
    )

    assert result.status == "NEEDS_CLARIFICATION"
    assert result.response_text == (
        "Bạn muốn xem tất cả chuyến hay chỉ các chuyến tiếp theo đang chờ nhận?"
    )
    assert result.steps == []


def test_trip_scope_clarification_only_applies_to_ambiguous_questions() -> None:
    assert needs_trip_scope_clarification("Cho tôi xem danh sách chuyến") is True
    assert needs_trip_scope_clarification("Tất cả chuyến của tôi") is False
    assert needs_trip_scope_clarification("Các chuyến tiếp theo đang chờ nhận") is False
    assert needs_trip_scope_clarification("Hôm nay tôi có chuyến nào?") is False
    assert needs_trip_scope_clarification("Bắt đầu chuyến 21") is False
    assert needs_trip_scope_clarification("Xem chuyến DEMO-001-M09") is False
    assert needs_trip_scope_clarification("Chuyến đi đến Hà Nội") is False
    assert has_explicit_date_scope("nay có chuyến nào gần nhất") is False
    assert has_explicit_date_scope("hôm nay có chuyến nào gần nhất") is True
    assert needs_trip_scope_clarification(
        "Tổng hợp số chuyến của tôi theo trạng thái, không giới hạn ngày"
    ) is False


def test_nearest_trip_without_explicit_date_clears_model_date_filter() -> None:
    arguments = AgentOrchestrator._normalize_trip_arguments(
        "nay có chuyến nào gần nhất",
        "rank_upcoming_trips",
        {"start_date": "2026-08-13", "end_date": "2026-08-13", "limit": 50},
    )

    assert arguments == {"start_date": None, "end_date": None, "limit": 50}


def test_navigation_completion_requires_verified_destination_action() -> None:
    assert AgentOrchestrator._requires_prepared_navigation(
        "Hãy tìm Bệnh viện Bạch Mai và bắt đầu dẫn đường ngay"
    )
    assert not AgentOrchestrator._has_prepared_navigation(
        [AgentClientAction(type="NAVIGATE", destination="ROUTE")]
    )
    assert AgentOrchestrator._has_prepared_navigation(
        [
            AgentClientAction(
                type="START_NAVIGATION",
                destination="Bệnh viện Bạch Mai",
                destination_name="Bệnh viện Bạch Mai",
                destination_lat=21.0018168,
                destination_lng=105.8396722,
            )
        ]
    )


def test_explicit_date_is_locked_across_every_trip_list_tool() -> None:
    for tool in ("list_completed_trips", "list_active_trips", "list_all_trips"):
        arguments = AgentOrchestrator._normalize_trip_arguments(
            "Trong ngày 15/08/2026 tôi hoàn thành chuyến nào và có chuyến nào đang chạy?",
            tool,
            {"start_date": None, "end_date": None, "limit": 50},
        )
        assert arguments["start_date"] == "2026-08-15"
        assert arguments["end_date"] == "2026-08-15"


def test_access_control_and_weather_requests_are_handled_without_model_or_mcp(tmp_path) -> None:
    class NoOpenAi:
        def chat(self, *_args, **_kwargs):
            raise AssertionError("Không được gọi model cho guard xác định")

    class DriverMcp:
        def __init__(self, _authorization):
            pass

        def list_tools(self):
            return [{"name": "list_all_trips", "description": "", "inputSchema": {}}]

    orchestrator = AgentOrchestrator(_enabled_store(tmp_path), NoOpenAi(), DriverMcp)
    other_driver = orchestrator.respond(
        AgentChatRequest(
            messages=[{"role": "user", "content": "Cho tôi xem chuyến của tài xế khác"}]
        ),
        "Bearer driver-token",
    )
    weather = orchestrator.respond(
        AgentChatRequest(
            messages=[{"role": "user", "content": "Ngày mai thời tiết có mưa không?"}]
        ),
        "Bearer driver-token",
    )

    assert requests_other_driver_data("dữ liệu tài xế khác") is True
    assert other_driver.status == "COMPLETED"
    assert "không thể truy cập" in other_driver.response_text.lower()
    assert requests_unsupported_weather("nhiệt độ hôm nay") is True
    assert weather.status == "COMPLETED"
    assert "không có công cụ dữ liệu thời tiết" in weather.response_text.lower()


def test_dependent_trip_id_is_locked_to_previous_tool_evidence() -> None:
    assignment_ids = {"assignment": 5}
    session_ids = {"driving_session": 9}

    summary = AgentOrchestrator._normalize_dependency_arguments(
        "Tóm tắt chuyến đang được phân công hiện tại",
        "get_trip_summary",
        {"trip_id": 1},
        assignment_ids,
    )
    pause = AgentOrchestrator._normalize_dependency_arguments(
        "Tạm dừng phiên lái đang chạy",
        "prepare_trip_action",
        {"action": "PAUSE", "trip_id": 1, "note": None},
        session_ids,
    )
    explicit = AgentOrchestrator._normalize_dependency_arguments(
        "Tạm dừng chuyến 8",
        "prepare_trip_action",
        {"action": "PAUSE", "trip_id": 1, "note": None},
        session_ids,
    )

    assert summary["trip_id"] == 5
    assert pause["trip_id"] == 9
    assert explicit["trip_id"] == 8


def test_multi_entity_workflow_preserves_each_model_selected_trip_id() -> None:
    arguments = AgentOrchestrator._normalize_dependency_arguments(
        "Kiểm tra checklist của toàn bộ năm chuyến chưa đi rồi đối chiếu với phân công",
        "get_trip_summary",
        {"trip_id": 9},
        {"assignment": 6, "detail": 6},
    )

    assert arguments["trip_id"] == 9


def test_required_tools_are_merged_from_multi_source_intent() -> None:
    required = AgentOrchestrator._required_tools_for_question(
        "Trong các chuyến chưa đi, ưu tiên quản lý kiểm tra chuyến nào nếu xét đồng thời "
        "lịch, risk và checklist? Liên hệ với điểm an toàn nhưng không tự thao tác."
    )

    assert set(required) == {
        "rank_upcoming_trips",
        "get_safety_summary",
        "get_trip_summary",
    }


def test_start_safety_wording_does_not_add_unrequested_safety_summary() -> None:
    required = AgentOrchestrator._required_tools_for_question(
        "Tìm chuyến chưa đi sớm nhất, kiểm tra checklist và phiên lái hiện tại rồi "
        "quyết định có an toàn để chuẩn bị START không."
    )

    assert "get_safety_summary" not in required
    assert set(required) == {
        "rank_upcoming_trips",
        "get_trip_summary",
        "get_current_driving_session",
    }


def test_mutation_tool_is_only_available_for_direct_positive_request() -> None:
    assert AgentOrchestrator._allows_trip_mutation(
        "Kiểm tra chuyến 8 rồi chuẩn bị nhận chuyến cho tôi"
    )
    assert not AgentOrchestrator._allows_trip_mutation(
        "Kiểm tra checklist; nếu thiếu thì không chuẩn bị nhận chuyến"
    )
    assert not AgentOrchestrator._allows_trip_mutation(
        "Quyết định có an toàn để chuẩn bị START không"
    )


def test_long_workflow_receives_extended_but_bounded_step_budget() -> None:
    question = (
        "Tiếp tục workflow vận hành nhiều lượt và xử lý yêu cầu này như một chuỗi quyết định "
        "có kiểm soát. Kiểm tra các nguồn dữ liệu."
    )

    assert AgentOrchestrator._step_budget(question, 6) == 10
    assert AgentOrchestrator._step_budget("Tra cứu chuyến 1", 6) == 6


def test_open_trip_detail_uses_verified_deterministic_flow(tmp_path) -> None:
    class NoOpenAi:
        def chat(self, *_args, **_kwargs):
            raise AssertionError("Luồng mở chi tiết có ID rõ ràng không cần gọi model")

    class FakeMcp:
        calls: list[tuple[str, dict]] = []

        def __init__(self, _authorization):
            pass

        def list_tools(self):
            schema = {"type": "object", "properties": {}, "required": []}
            return [
                {"name": "get_trip_detail", "description": "Chi tiết", "inputSchema": schema},
                {"name": "open_mobile_screen", "description": "Mở màn hình", "inputSchema": schema},
            ]

        def execute(self, name, arguments):
            self.calls.append((name, arguments))
            if name == "get_trip_detail":
                return {"ok": True, "trip": {"id": 8, "tripCode": "SF-008"}}
            return {
                "ok": True,
                "clientAction": {
                    "type": "NAVIGATE",
                    "destination": "TRIP_DETAIL",
                    "tripId": 8,
                },
            }

    result = AgentOrchestrator(_enabled_store(tmp_path), NoOpenAi(), FakeMcp).respond(
        AgentChatRequest(
            messages=[{"role": "user", "content": "Kiểm tra rồi mở chi tiết chuyến 8"}]
        ),
        "Bearer driver-token",
    )

    assert result.status == "COMPLETED"
    assert [step.tool for step in result.steps] == ["get_trip_detail", "open_mobile_screen"]
    assert result.client_actions[0].trip_id == 8
    assert FakeMcp.calls[-1][1]["trip_id"] == 8


def test_deterministic_detail_and_summary_keep_enum_facts() -> None:
    detail = AgentOrchestrator._render_deterministic_data(
        "TRIP_DETAIL",
        {
            "get_trip_detail": {
                "trip": {
                    "id": 5,
                    "tripCode": "DEMO-TRIP-005",
                    "vehiclePlateNumber": "001",
                    "startLocation": "Đại lộ Thăng Long",
                    "endLocation": "Cầu Giấy",
                    "status": "IN_PROGRESS",
                    "progress": 65,
                    "riskLevel": "LOW",
                }
            }
        },
    )
    summary = AgentOrchestrator._render_deterministic_data(
        "TRIP_SUMMARY",
        {
            "get_trip_summary": {
                "summary": {
                    "trip": {
                        "tripCode": "TRIP-011",
                        "status": "COMPLETED",
                        "actualEndTime": "2026-08-15T04:18:00",
                        "progress": 100,
                    },
                    "checklistSubmitted": True,
                    "nextAction": "NONE",
                }
            }
        },
    )

    assert "IN_PROGRESS" in detail and "LOW" in detail and "65%" in detail
    assert "04:18 ngày 15/08/2026" in summary
    assert "checklist đã nộp" in summary
    assert "không còn hành động tiếp theo" in summary


def test_nearest_trip_redirects_plain_upcoming_tool_to_ranker(tmp_path) -> None:
    class FakeOpenAi:
        responses = iter(
            [
                {
                    "content": json.dumps(
                        {
                            "goal": "Tìm chuyến gần nhất",
                            "steps": ["Xếp hạng chuyến chờ"],
                            "expected_tools": ["rank_upcoming_trips"],
                        }
                    )
                },
                {
                    "content": None,
                    "tool_calls": [
                        {
                            "id": "call-1",
                            "function": {
                                "name": "list_upcoming_trips",
                                "arguments": json.dumps(
                                    {
                                        "start_date": "2026-08-13",
                                        "end_date": "2026-08-13",
                                        "limit": 50,
                                    }
                                ),
                            },
                        }
                    ],
                },
                {
                    "content": json.dumps(
                        {
                            "status": "COMPLETE",
                            "reason": "Đã xếp hạng",
                            "revised_plan": {
                                "goal": "Tìm chuyến gần nhất",
                                "steps": [],
                                "expected_tools": [],
                            },
                        }
                    )
                },
                {"content": "Chuyến gần nhất là DEMO-001-M09."},
            ]
        )

        def chat(self, *_args, **_kwargs):
            return next(self.responses)

        @staticmethod
        def structured_content(message):
            return json.loads(message["content"])

    class FakeMcpClient:
        def __init__(self, _authorization):
            pass

        def list_tools(self):
            schema = {"type": "object", "properties": {}, "required": []}
            return [
                {
                    "name": "list_upcoming_trips",
                    "description": "Chuyến chờ",
                    "inputSchema": schema,
                },
                {
                    "name": "rank_upcoming_trips",
                    "description": "Xếp hạng chuyến chờ",
                    "inputSchema": schema,
                },
            ]

        def execute(self, name, arguments):
            assert name == "rank_upcoming_trips"
            assert arguments["start_date"] is None
            assert arguments["end_date"] is None
            return {"ok": True, "count": 2, "recommendedTrip": {"id": 25}}

    result = AgentOrchestrator(_enabled_store(tmp_path), FakeOpenAi(), FakeMcpClient).respond(
        AgentChatRequest(messages=[{"role": "user", "content": "nay có chuyến nào gần nhất"}]),
        "Bearer driver-token",
    )

    assert result.status == "COMPLETED"
    assert result.steps[0].tool == "rank_upcoming_trips"


def test_configuration_key_is_encrypted_and_masked(tmp_path) -> None:
    path = tmp_path / "agent.json"
    store = AgentConfigurationStore(str(path), "test-encryption-secret-with-at-least-32-characters")
    result = store.update(
        AgentConfigurationUpdate(
            enabled=True,
            api_key="sk-test-key-that-is-long-enough-for-validation",
            max_steps=7,
        )
    )

    persisted = path.read_text(encoding="utf-8")
    assert "sk-test-key" not in persisted
    assert "gcm:v1:" in persisted
    assert result.api_key_configured is True
    assert result.api_key_hint == "••••tion"
    assert store.runtime().api_key == "sk-test-key-that-is-long-enough-for-validation"


def test_environment_configuration_overrides_disabled_stored_configuration(
    tmp_path, monkeypatch
) -> None:
    path = tmp_path / "agent.json"
    store = AgentConfigurationStore(str(path), "test-encryption-secret-with-at-least-32-characters")
    store.update(
        AgentConfigurationUpdate(
            enabled=True,
            api_key="sk-database-key-that-is-long-enough-for-validation",
            max_steps=5,
        )
    )
    store.update(AgentConfigurationUpdate(enabled=False, max_steps=5))
    monkeypatch.setenv("OPENAI_API_KEY", "sk-environment-key-that-is-long-enough-for-validation")
    monkeypatch.setenv("OPENAI_ENABLED", "true")
    monkeypatch.setenv("AGENT_MAX_STEPS", "8")

    runtime = store.runtime()

    assert runtime.enabled is True
    assert runtime.api_key == "sk-environment-key-that-is-long-enough-for-validation"
    assert runtime.max_steps == 8
    assert runtime.source == "ENVIRONMENT"


def test_internal_configuration_endpoint_rejects_missing_service_token(monkeypatch) -> None:
    monkeypatch.setenv("AI_INTERNAL_TOKEN", "test-internal-token")
    response = TestClient(app).get("/agent/config")
    assert response.status_code == 403


def test_agent_plans_executes_tool_checks_and_returns_final_answer(tmp_path, monkeypatch) -> None:
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

    class FakeOpenAi:
        def __init__(self):
            self.responses = iter(
                [
                    {
                        "content": json.dumps(
                            {
                                "goal": "Xem chuyến",
                                "steps": ["Lấy chuyến"],
                                "expected_tools": ["list_completed_trips"],
                            }
                        )
                    },
                    {
                        "content": None,
                        "tool_calls": [
                            {
                                "id": "call-1",
                                "function": {
                                    "name": "list_completed_trips",
                                    "arguments": json.dumps(
                                        {"start_date": None, "end_date": None, "limit": 20}
                                    ),
                                },
                            }
                        ],
                    },
                    {
                        "content": json.dumps(
                            {
                                "status": "COMPLETE",
                                "reason": "Đã đủ",
                                "revised_plan": {
                                    "goal": "Xem chuyến",
                                    "steps": ["Đã lấy"],
                                    "expected_tools": ["list_completed_trips"],
                                },
                            }
                        )
                    },
                    {"content": "Bạn đã hoàn thành 2 chuyến."},
                ]
            )

        def chat(self, *_args, **_kwargs):
            return next(self.responses)

        @staticmethod
        def structured_content(message):
            return json.loads(message["content"])

    class FakeMcpClient:
        def __init__(self, authorization):
            assert authorization == "Bearer driver-token"

        def list_tools(self):
            return [
                {
                    "name": "list_completed_trips",
                    "description": "Danh sách chuyến hoàn thành",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "start_date": {"type": ["string", "null"]},
                            "end_date": {"type": ["string", "null"]},
                            "limit": {"type": "integer"},
                        },
                        "required": ["start_date", "end_date", "limit"],
                        "additionalProperties": False,
                    },
                }
            ]

        def execute(self, name, arguments):
            assert name == "list_completed_trips"
            return {"ok": True, "count": 2, "trips": []}

    orchestrator = AgentOrchestrator(store, FakeOpenAi(), FakeMcpClient)
    result = orchestrator.respond(
        AgentChatRequest(messages=[{"role": "user", "content": "Tôi đã đi những chuyến nào?"}]),
        "Bearer driver-token",
    )

    assert result.status == "COMPLETED"
    assert result.response_text == "Bạn đã hoàn thành 2 chuyến."
    assert result.steps[0].tool == "list_completed_trips"
    assert result.steps[0].plan_check == "COMPLETE"


def test_agent_returns_confirmation_without_executing_mutation(tmp_path) -> None:
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

    class FakeOpenAi:
        responses = iter(
            [
                {
                    "content": json.dumps(
                        {
                            "goal": "Bắt đầu chuyến",
                            "steps": ["Xác nhận"],
                            "expected_tools": ["prepare_trip_action"],
                        }
                    )
                },
                {
                    "content": None,
                    "tool_calls": [
                        {
                            "id": "call-1",
                            "function": {
                                "name": "prepare_trip_action",
                                "arguments": json.dumps(
                                    {"action": "START", "trip_id": 21, "note": None}
                                ),
                            },
                        }
                    ],
                },
            ]
        )

        def chat(self, *_args, **_kwargs):
            return next(self.responses)

        @staticmethod
        def structured_content(message):
            return json.loads(message["content"])

    class FakeMcpClient:
        def __init__(self, _authorization):
            pass

        def list_tools(self):
            return [
                {
                    "name": "prepare_trip_action",
                    "description": "Chuẩn bị thao tác",
                    "inputSchema": {"type": "object", "properties": {}, "required": []},
                }
            ]

        def execute(self, _name, _arguments):
            return {
                "ok": True,
                "confirmationRequest": {
                    "type": "TRIP_ACTION",
                    "action": "START",
                    "tripId": 21,
                    "note": None,
                    "prompt": "Bạn có chắc muốn bắt đầu chuyến #21?",
                },
            }

    result = AgentOrchestrator(store, FakeOpenAi(), FakeMcpClient).respond(
        AgentChatRequest(messages=[{"role": "user", "content": "Bắt đầu chuyến 21"}]),
        "Bearer driver-token",
    )

    assert result.status == "AWAITING_CONFIRMATION"
    assert result.confirmation_request is not None
    assert result.confirmation_request.trip_id == 21
    assert result.steps[0].plan_check == "AWAITING_CONFIRMATION"


def test_agent_executes_and_checks_multiple_tools_in_one_model_turn(tmp_path) -> None:
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

    class FakeOpenAi:
        responses = iter(
            [
                {
                    "content": json.dumps(
                        {
                            "goal": "So sánh chuyến",
                            "steps": ["Lấy đã đi", "Lấy chưa đi"],
                            "expected_tools": ["list_completed_trips", "list_upcoming_trips"],
                        }
                    )
                },
                {
                    "content": None,
                    "tool_calls": [
                        {
                            "id": "call-1",
                            "function": {
                                "name": "list_completed_trips",
                                "arguments": json.dumps(
                                    {"start_date": None, "end_date": None, "limit": 20}
                                ),
                            },
                        },
                        {
                            "id": "call-2",
                            "function": {
                                "name": "list_upcoming_trips",
                                "arguments": json.dumps(
                                    {"start_date": None, "end_date": None, "limit": 20}
                                ),
                            },
                        },
                    ],
                },
                {
                    "content": json.dumps(
                        {
                            "status": "CONTINUE",
                            "reason": "Cần chuyến chưa đi",
                            "revised_plan": {"goal": "So sánh", "steps": [], "expected_tools": []},
                        }
                    )
                },
                {
                    "content": json.dumps(
                        {
                            "status": "COMPLETE",
                            "reason": "Đã đủ hai nhóm",
                            "revised_plan": {"goal": "So sánh", "steps": [], "expected_tools": []},
                        }
                    )
                },
                {"content": "Bạn đã đi 2 chuyến và còn 1 chuyến chưa đi."},
            ]
        )

        def chat(self, *_args, **_kwargs):
            return next(self.responses)

        @staticmethod
        def structured_content(message):
            return json.loads(message["content"])

    class FakeMcpClient:
        def __init__(self, _authorization):
            self.calls = []

        def list_tools(self):
            schema = {"type": "object", "properties": {}, "required": []}
            return [
                {"name": "list_completed_trips", "description": "Đã đi", "inputSchema": schema},
                {"name": "list_upcoming_trips", "description": "Chưa đi", "inputSchema": schema},
            ]

        def execute(self, name, _arguments):
            return {"ok": True, "count": 2 if name == "list_completed_trips" else 1, "trips": []}

    result = AgentOrchestrator(store, FakeOpenAi(), FakeMcpClient).respond(
        AgentChatRequest(messages=[{"role": "user", "content": "So sánh chuyến đã đi và chưa đi"}]),
        "Bearer driver-token",
    )

    assert result.status == "COMPLETED"
    assert [step.tool for step in result.steps] == [
        "list_completed_trips",
        "list_upcoming_trips",
    ]
    assert [step.plan_check for step in result.steps] == ["CONTINUE", "COMPLETE"]


def test_missing_planned_tools_requires_every_committed_tool() -> None:
    plan = Plan(
        goal="Đối chiếu",
        steps=["Lấy chuyến", "Lấy an toàn"],
        expected_tools=["list_active_trips", "get_safety_summary"],
    )
    trace = [
        AgentStep(
            index=1,
            tool="list_active_trips",
            arguments="{}",
            success=True,
            plan_check="CONTINUE",
            reason="Còn thiếu an toàn",
        )
    ]

    assert AgentOrchestrator._missing_planned_tools(
        plan, trace, "list_active_trips", {"ok": True}
    ) == ["get_safety_summary"]
    assert AgentOrchestrator._missing_planned_tools(
        plan, trace, "get_safety_summary", {"ok": True}
    ) == []
    assert AgentOrchestrator._missing_tools_from_trace(plan, trace) == ["get_safety_summary"]


def test_management_agent_blocks_third_identical_tool_result_and_answers(tmp_path) -> None:
    def tool_call(call_id: str) -> dict:
        return {
            "content": None,
            "tool_calls": [
                {
                    "id": call_id,
                    "function": {
                        "name": "management_get_fleet_overview",
                        "arguments": "{}",
                    },
                }
            ],
        }

    class FakeOpenAi:
        def __init__(self):
            self.responses = iter(
                [
                    {
                        "content": json.dumps(
                            {
                                "goal": "Phân tích toàn đội xe",
                                "steps": ["Lấy tổng quan", "Đánh giá dữ liệu"],
                                "expected_tools": ["management_get_fleet_overview"],
                            }
                        )
                    },
                    tool_call("call-1"),
                    {
                        "content": json.dumps(
                            {
                                "status": "CONTINUE",
                                "reason": "Kiểm tra lại",
                                "revised_plan": {"goal": "", "steps": [], "expected_tools": []},
                            }
                        )
                    },
                    tool_call("call-2"),
                    {
                        "content": json.dumps(
                            {
                                "status": "CONTINUE",
                                "reason": "Kiểm tra lại lần nữa",
                                "revised_plan": {"goal": "", "steps": [], "expected_tools": []},
                            }
                        )
                    },
                    tool_call("call-3"),
                    {
                        "content": json.dumps(
                            {
                                "decision": "ANSWER",
                                "reason": "Hai kết quả trước đã đủ bằng chứng; chặn lần lặp thứ ba.",
                                "revised_plan": {"goal": "", "steps": [], "expected_tools": []},
                            }
                        )
                    },
                    {"content": "Toàn đội hiện có 12 chuyến và 1 sự cố đang mở."},
                ]
            )

        def chat(self, *_args, **_kwargs):
            return next(self.responses)

        @staticmethod
        def structured_content(message):
            return json.loads(message["content"])

    class FakeManagementMcp:
        executions = 0

        def __init__(self, _authorization):
            pass

        def list_tools(self):
            return [
                {
                    "name": "management_get_fleet_overview",
                    "description": "Tổng quan toàn đội",
                    "inputSchema": {"type": "object", "properties": {}, "required": []},
                }
            ]

        def execute(self, _name, _arguments):
            FakeManagementMcp.executions += 1
            return {"ok": True, "summary": {"totalTrips": 12, "openIncidents": 1}}

    result = AgentOrchestrator(
        _enabled_store(tmp_path), FakeOpenAi(), FakeManagementMcp
    ).respond(
        AgentChatRequest(
            messages=[{"role": "user", "content": "Phân tích tổng quan dữ liệu vận hành toàn đội."}]
        ),
        "Bearer admin-token",
    )

    assert result.status == "LOOP_GUARD_COMPLETED"
    assert result.response_text.startswith("Toàn đội hiện có 12 chuyến")
    assert result.steps[-1].plan_check == "DUPLICATE_RESULT_BLOCKED"
    assert FakeManagementMcp.executions == 1
