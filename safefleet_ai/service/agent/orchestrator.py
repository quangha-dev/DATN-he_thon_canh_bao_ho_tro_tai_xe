from __future__ import annotations

import json
import re
from dataclasses import dataclass
from datetime import date, datetime
from typing import Any

from service.agent.clarification import (
    OTHER_DRIVER_RESPONSE,
    TRIP_SCOPE_QUESTION,
    UNSUPPORTED_WEATHER_RESPONSE,
    has_explicit_date_scope,
    needs_trip_scope_clarification,
    normalize_vietnamese,
    requests_other_driver_data,
    requests_ranked_upcoming_scope,
    requests_unsupported_weather,
    requests_upcoming_scope,
)
from service.agent.configuration import AgentConfigurationStore
from service.agent.models import (
    AgentChatRequest,
    AgentChatResponse,
    AgentClientAction,
    AgentConfirmationRequest,
    AgentStep,
)
from service.mcp.client import SafeFleetMcpClient, openai_tool_definitions
from service.mcp.registry import McpToolError
from service.providers.openai import OpenAiClient, OpenAiError


@dataclass(frozen=True)
class Plan:
    goal: str
    steps: list[str]
    expected_tools: list[str]


class AgentOrchestrator:
    def __init__(
        self,
        configuration_store: AgentConfigurationStore,
        openai_client: OpenAiClient | None = None,
        mcp_client_factory: Any | None = None,
    ):
        self._configuration_store = configuration_store
        self._openai = openai_client or OpenAiClient()
        self._mcp_client_factory = mcp_client_factory or SafeFleetMcpClient

    def respond(self, request: AgentChatRequest, user_authorization: str) -> AgentChatResponse:
        configuration = self._configuration_store.runtime()
        if not configuration.enabled or not configuration.api_key:
            return AgentChatResponse(
                response_text="Trợ lý dữ liệu chưa được bật. Quản trị viên cần nhập OpenAI API key trong Cấu hình hệ thống.",
                model=configuration.model,
                status="NOT_CONFIGURED",
            )

        question = request.messages[-1].content
        if requests_other_driver_data(question):
            return AgentChatResponse(
                response_text=OTHER_DRIVER_RESPONSE,
                model=configuration.model,
                status="COMPLETED",
            )
        if requests_unsupported_weather(question):
            return AgentChatResponse(
                response_text=UNSUPPORTED_WEATHER_RESPONSE,
                model=configuration.model,
                status="COMPLETED",
            )
        if needs_trip_scope_clarification(question):
            return AgentChatResponse(
                response_text=TRIP_SCOPE_QUESTION,
                model=configuration.model,
                status="NEEDS_CLARIFICATION",
            )
        trace: list[AgentStep] = []
        replanned = False
        client_actions: list[AgentClientAction] = []
        try:
            mcp_client = self._mcp_client_factory(user_authorization)
            mcp_tools = mcp_client.list_tools()
            allowed_tools = [str(tool.get("name")) for tool in mcp_tools]
            if not allowed_tools:
                raise McpToolError("Tài khoản đăng nhập không có tool agent nào được cấp quyền")
            definitions = openai_tool_definitions(mcp_tools)
            shortcut = self._open_trip_detail_shortcut(
                question, configuration.model, mcp_client, allowed_tools
            )
            if shortcut is not None:
                return shortcut
            shortcut = self._deterministic_data_shortcut(
                question, configuration.model, mcp_client, allowed_tools
            )
            if shortcut is not None:
                return shortcut
            plan = self._create_plan(configuration, request, question, allowed_tools)
            messages = self._execution_messages(request, plan)
            resolved_trip_ids: dict[str, int] = {}

            step_index = 0
            while step_index < configuration.max_steps:
                message = self._openai.chat(
                    configuration,
                    messages,
                    tools=definitions,
                    tool_choice="auto",
                )
                calls = message.get("tool_calls") or []
                if not calls:
                    answer = (message.get("content") or "").strip()
                    return self._response(
                        answer or "Tôi chưa tổng hợp được câu trả lời từ dữ liệu chuyến.",
                        configuration.model,
                        "COMPLETED",
                        plan,
                        trace,
                        replanned,
                        client_actions,
                    )

                messages.append(
                    {
                        "role": "assistant",
                        "content": message.get("content"),
                        "tool_calls": calls,
                    }
                )
                complete = False
                for call in calls:
                    if step_index >= configuration.max_steps:
                        break
                    step_index += 1
                    call_id = str(call.get("id") or "")
                    function = call.get("function") or {}
                    tool_name = str(function.get("name") or "")
                    arguments = self._arguments(function.get("arguments"))
                    if (
                        tool_name == "list_upcoming_trips"
                        and requests_ranked_upcoming_scope(question)
                        and "rank_upcoming_trips" in allowed_tools
                    ):
                        tool_name = "rank_upcoming_trips"
                    arguments = self._normalize_trip_arguments(question, tool_name, arguments)
                    arguments = self._normalize_dependency_arguments(
                        question, tool_name, arguments, resolved_trip_ids
                    )
                    try:
                        if tool_name not in allowed_tools:
                            raise McpToolError(f"Tool không thuộc quyền tài khoản: {tool_name}")
                        tool_result = mcp_client.execute(tool_name, arguments)
                    except McpToolError as exception:
                        tool_result = {"ok": False, "error": str(exception)}
                    self._remember_trip_id(tool_name, tool_result, resolved_trip_ids)
                    messages.append(
                        {
                            "role": "tool",
                            "tool_call_id": call_id,
                            "content": json.dumps(tool_result, ensure_ascii=False, default=str),
                        }
                    )
                    action = tool_result.get("clientAction")
                    if isinstance(action, dict):
                        client_actions.append(AgentClientAction.model_validate(action))
                    confirmation = tool_result.get("confirmationRequest")
                    if isinstance(confirmation, dict):
                        trace.append(
                            AgentStep(
                                index=step_index,
                                tool=tool_name,
                                arguments=self._compact(arguments, 500),
                                success=True,
                                plan_check="AWAITING_CONFIRMATION",
                                reason="Thao tác thay đổi trạng thái cần người dùng xác nhận.",
                            )
                        )
                        return self._response(
                            str(confirmation.get("prompt") or "Vui lòng xác nhận thao tác."),
                            configuration.model,
                            "AWAITING_CONFIRMATION",
                            plan,
                            trace,
                            replanned,
                            client_actions,
                            AgentConfirmationRequest.model_validate(confirmation),
                        )

                    check = self._check_plan(
                        configuration, question, plan, tool_name, arguments, tool_result, trace
                    )
                    trace.append(
                        AgentStep(
                            index=step_index,
                            tool=tool_name,
                            arguments=self._compact(arguments, 500),
                            success=bool(tool_result.get("ok")),
                            plan_check=check["status"],
                            reason=check["reason"],
                        )
                    )
                    if check["status"] == "ERROR":
                        return self._response(
                            f"Tôi không thể hoàn tất yêu cầu: {check['reason']}",
                            configuration.model,
                            "FAILED",
                            plan,
                            trace,
                            replanned,
                            client_actions,
                        )
                    if check["status"] == "REPLAN":
                        plan = self._plan_from(
                            check.get("revised_plan") or {}, plan.goal, allowed_tools
                        )
                        replanned = True
                        messages.append(
                            {
                                "role": "system",
                                "content": f"Kế hoạch mới bắt buộc dùng: {self._plan_text(plan)}",
                            }
                        )
                    complete = complete or check["status"] == "COMPLETE"
                if complete:
                    messages.append(
                        {
                            "role": "system",
                            "content": (
                                "Đã đủ dữ liệu. Trả lời cuối cùng bằng tiếng Việt, chỉ dựa trên "
                                "kết quả tool; không gọi thêm tool. Nếu kết quả có dateScope="
                                "ALL_TIME_PENDING thì phải nói đây là các chuyến đang chờ trên "
                                "toàn bộ thời gian, tuyệt đối không gọi là chuyến hôm nay."
                            ),
                        }
                    )
                    final_message = self._openai.chat(configuration, messages, tools=[])
                    answer = (final_message.get("content") or "").strip()
                    return self._response(
                        answer or "Đã lấy dữ liệu nhưng chưa thể tổng hợp câu trả lời.",
                        configuration.model,
                        "COMPLETED",
                        plan,
                        trace,
                        replanned,
                        client_actions,
                    )

            return self._response(
                f"Tôi đã dừng vì đạt giới hạn {configuration.max_steps} bước nhưng chưa đủ dữ liệu để trả lời an toàn.",
                configuration.model,
                "STEP_LIMIT",
                plan,
                trace,
                replanned,
                client_actions,
            )
        except (OpenAiError, McpToolError, ValueError) as exception:
            return AgentChatResponse(
                response_text=f"Agent phía server gặp lỗi: {exception}",
                model=configuration.model,
                status="FAILED",
                steps=trace,
                replanned=replanned,
            )

    def _create_plan(
        self,
        configuration: Any,
        request: AgentChatRequest,
        question: str,
        allowed_tools: list[str],
    ) -> Plan:
        messages = [
            {
                "role": "system",
                "content": (
                    f"Bạn là bộ lập kế hoạch SafeFleet. Hôm nay là {date.today().isoformat()} (Asia/Ho_Chi_Minh). "
                    "Lập kế hoạch động bằng dữ liệu thật của đúng tài khoản đăng nhập. "
                    f"Chỉ chọn tool MCP đã được server cấp quyền: {', '.join(allowed_tools)}. "
                    "Ngày dùng YYYY-MM-DD. Chỉ lọc ngày khi người dùng nói rõ hôm nay, ngày cụ thể, tuần hoặc tháng. "
                    "Từ 'nay' đứng riêng không đồng nghĩa với 'hôm nay'. 'Gần nhất', 'sớm nhất' hoặc "
                    "'tiếp theo' bắt buộc dùng rank_upcoming_trips. 'Chờ nhận' hoặc "
                    "'chưa đi' phải dùng chuyến đang chờ trên toàn bộ thời gian, trừ khi người dùng nêu ngày. "
                    "Nếu người dùng trả lời 'tất cả' sau câu hỏi làm rõ, dùng list_all_trips. "
                    "Không bịa dữ liệu. Tool thay đổi trạng thái chỉ được chuẩn bị xác nhận."
                    "Không dùng tool chuyến để trả lời thời tiết. Từ chối rõ yêu cầu xem dữ liệu tài xế khác. "
                    "Khi tool sau phụ thuộc tool trước, phải dùng đúng trip ID trong kết quả tool trước."
                ),
            },
            {
                "role": "user",
                "content": f"Ngữ cảnh hội thoại:\n{self._conversation(request)}\n\nCâu hỏi hiện tại: {question}",
            },
        ]
        message = self._openai.chat(
            configuration,
            messages,
            response_format=self._structured_format(
                "safefleet_agent_plan", self._plan_schema(allowed_tools)
            ),
            max_tokens=500,
        )
        return self._plan_from(self._openai.structured_content(message), question, allowed_tools)

    def _check_plan(
        self,
        configuration: Any,
        question: str,
        plan: Plan,
        tool_name: str,
        arguments: dict[str, Any],
        result: dict[str, Any],
        previous_steps: list[AgentStep],
    ) -> dict[str, Any]:
        evidence = self._compact(result, 14000)
        messages = [
            {
                "role": "system",
                "content": (
                    "Sau MỖI tool, so sánh bằng chứng với câu hỏi và kế hoạch. Chọn COMPLETE nếu đủ dữ liệu; "
                    "CONTINUE nếu còn bước; REPLAN nếu kế hoạch sai/thiếu; ERROR nếu lỗi không thể khắc phục. "
                    "Không suy diễn ngoài kết quả tool."
                ),
            },
            {
                "role": "user",
                "content": (
                    f"Câu hỏi: {question}\nKế hoạch: {self._plan_text(plan)}\nCác bước trước: "
                    f"{[step.model_dump(by_alias=True) for step in previous_steps]}\nTool vừa chạy: {tool_name}"
                    f"\nTham số: {arguments}\nKết quả: {evidence}"
                ),
            },
        ]
        message = self._openai.chat(
            configuration,
            messages,
            response_format=self._structured_format("safefleet_plan_check", self._check_schema()),
            max_tokens=500,
        )
        check = self._openai.structured_content(message)
        status = str(check.get("status") or "ERROR")
        if status not in {"CONTINUE", "COMPLETE", "REPLAN", "ERROR"}:
            status = "ERROR"
        return {
            "status": status,
            "reason": str(check.get("reason") or "Không xác định được tiến độ"),
            "revised_plan": check.get("revised_plan") or {},
        }

    @staticmethod
    def _execution_messages(request: AgentChatRequest, plan: Plan) -> list[dict[str, Any]]:
        messages: list[dict[str, Any]] = [
            {
                "role": "system",
                "content": (
                    f"Bạn là agent SafeFleet phía server. Hôm nay là {date.today().isoformat()}. "
                    "Tự chọn tool MCP phù hợp. Có thể yêu cầu nhiều tool trong một lượt nhưng phải giữ đúng kế hoạch. "
                    "Tool đã được lọc theo quyền tài khoản. Không bịa dữ liệu, không yêu cầu ID tài xế, "
                    "không truy cập tài khoản khác và không tự xác nhận thao tác thay đổi trạng thái. "
                    "Không được tự đoán trip ID. Tool phụ thuộc phải dùng đúng trip ID vừa nhận từ tool trước. "
                    "Chỉ truyền start_date/end_date khi người dùng nêu rõ khoảng ngày. Với 'gần nhất', "
                    "'tiếp theo', 'chờ nhận', 'chưa đi' mà không có ngày rõ ràng, bắt buộc để hai ngày là null. "
                    f"Kế hoạch ban đầu: {AgentOrchestrator._plan_text(plan)}"
                ),
            }
        ]
        messages.extend(message.model_dump() for message in request.messages)
        return messages

    @staticmethod
    def _response(
        text: str,
        model: str,
        status: str,
        plan: Plan,
        trace: list[AgentStep],
        replanned: bool,
        client_actions: list[AgentClientAction] | None = None,
        confirmation_request: AgentConfirmationRequest | None = None,
    ) -> AgentChatResponse:
        return AgentChatResponse(
            response_text=text,
            model=model,
            status=status,
            plan=plan.steps,
            steps=trace,
            replanned=replanned,
            client_actions=client_actions or [],
            confirmation_request=confirmation_request,
        )

    @staticmethod
    def _arguments(raw: Any) -> dict[str, Any]:
        try:
            parsed = json.loads(raw or "{}")
            return parsed if isinstance(parsed, dict) else {}
        except json.JSONDecodeError:
            return {}

    @staticmethod
    def _normalize_trip_arguments(
        question: str, tool_name: str, arguments: dict[str, Any]
    ) -> dict[str, Any]:
        explicit_date = AgentOrchestrator._explicit_single_date(question)
        if explicit_date and tool_name in {
            "list_all_trips",
            "list_completed_trips",
            "list_upcoming_trips",
            "list_active_trips",
            "rank_upcoming_trips",
        }:
            return {**arguments, "start_date": explicit_date, "end_date": explicit_date}
        if (
            tool_name in {"list_upcoming_trips", "rank_upcoming_trips"}
            and requests_upcoming_scope(question)
            and not has_explicit_date_scope(question)
        ):
            return {**arguments, "start_date": None, "end_date": None}
        return arguments

    @classmethod
    def _normalize_dependency_arguments(
        cls,
        question: str,
        tool_name: str,
        arguments: dict[str, Any],
        resolved_trip_ids: dict[str, int],
    ) -> dict[str, Any]:
        trip_tools = {
            "get_trip_detail",
            "get_trip_summary",
            "get_warehouse_issue",
            "open_mobile_screen",
            "prepare_trip_action",
        }
        if tool_name not in trip_tools:
            return arguments

        explicit_id = cls._explicit_trip_id(question)
        selected_id: int | None = explicit_id
        normalized = normalize_vietnamese(question)
        if selected_id is None and tool_name == "prepare_trip_action" and any(
            signal in normalized
            for signal in ("phien lai", "dang lai", "dang chay", "tam dung", "ket thuc")
        ):
            selected_id = resolved_trip_ids.get("driving_session")
        if selected_id is None and any(
            signal in normalized
            for signal in ("phan cong", "chuyen hien tai", "dang duoc giao", "duoc giao")
        ):
            selected_id = resolved_trip_ids.get("assignment")
        if selected_id is None:
            selected_id = resolved_trip_ids.get("detail") or resolved_trip_ids.get("recommended")
        if selected_id is None:
            return arguments

        if tool_name == "open_mobile_screen" and str(arguments.get("destination") or "").upper() != "TRIP_DETAIL":
            return arguments
        return {**arguments, "trip_id": selected_id}

    @staticmethod
    def _remember_trip_id(
        tool_name: str, result: dict[str, Any], resolved_trip_ids: dict[str, int]
    ) -> None:
        candidates: list[tuple[str, Any]] = []
        if tool_name == "get_current_assignment":
            assignment = result.get("assignment") or {}
            candidates.append(("assignment", (assignment.get("trip") or {}).get("id")))
        elif tool_name == "get_current_driving_session":
            candidates.append(("driving_session", (result.get("session") or {}).get("tripId")))
        elif tool_name == "get_trip_detail":
            candidates.append(("detail", (result.get("trip") or {}).get("id")))
        elif tool_name == "rank_upcoming_trips":
            candidates.append(("recommended", (result.get("recommendedTrip") or {}).get("id")))
        for key, raw_value in candidates:
            try:
                value = int(raw_value)
            except (TypeError, ValueError):
                continue
            if value > 0:
                resolved_trip_ids[key] = value

    @staticmethod
    def _explicit_trip_id(question: str) -> int | None:
        normalized = normalize_vietnamese(question)
        match = re.search(r"\bchuyen(?:\s+di)?(?:\s+so)?\s*#?(\d+)\b", normalized)
        return int(match.group(1)) if match else None

    @staticmethod
    def _explicit_single_date(question: str) -> str | None:
        normalized = normalize_vietnamese(question)
        iso = re.search(r"\b(20\d{2})-(\d{1,2})-(\d{1,2})\b", normalized)
        if iso:
            return f"{int(iso.group(1)):04d}-{int(iso.group(2)):02d}-{int(iso.group(3)):02d}"
        local = re.search(r"\b(\d{1,2})[/-](\d{1,2})[/-](20\d{2})\b", normalized)
        if local:
            return f"{int(local.group(3)):04d}-{int(local.group(2)):02d}-{int(local.group(1)):02d}"
        if "hom nay" in normalized or "ngay hom nay" in normalized:
            return date.today().isoformat()
        return None

    @classmethod
    def _open_trip_detail_shortcut(
        cls,
        question: str,
        model: str,
        mcp_client: Any,
        allowed_tools: list[str],
    ) -> AgentChatResponse | None:
        normalized = normalize_vietnamese(question)
        trip_id = cls._explicit_trip_id(question)
        if trip_id is None or not (
            "mo chi tiet" in normalized or "mo man hinh chi tiet" in normalized
        ):
            return None
        required = {"get_trip_detail", "open_mobile_screen"}
        if not required.issubset(set(allowed_tools)):
            return None

        plan = Plan(
            goal=f"Kiểm tra và mở chi tiết chuyến {trip_id}",
            steps=["Kiểm tra quyền truy cập chuyến", "Mở màn hình chi tiết chuyến"],
            expected_tools=["get_trip_detail", "open_mobile_screen"],
        )
        trace: list[AgentStep] = []
        try:
            detail_arguments = {"trip_id": trip_id}
            detail_result = mcp_client.execute("get_trip_detail", detail_arguments)
            trace.append(
                AgentStep(
                    index=1,
                    tool="get_trip_detail",
                    arguments=cls._compact(detail_arguments, 500),
                    success=bool(detail_result.get("ok")),
                    plan_check="CONTINUE",
                    reason="Đã xác minh chuyến thuộc tài khoản đăng nhập.",
                )
            )
            if not detail_result.get("ok"):
                raise McpToolError(str(detail_result.get("error") or "Không đọc được chuyến"))
            open_arguments = {"destination": "TRIP_DETAIL", "trip_id": trip_id}
            open_result = mcp_client.execute("open_mobile_screen", open_arguments)
            action = AgentClientAction.model_validate(open_result["clientAction"])
            trace.append(
                AgentStep(
                    index=2,
                    tool="open_mobile_screen",
                    arguments=cls._compact(open_arguments, 500),
                    success=bool(open_result.get("ok")),
                    plan_check="COMPLETE",
                    reason="Đã tạo lệnh mở màn hình chi tiết đúng chuyến.",
                )
            )
            trip = detail_result.get("trip") or {}
            code = trip.get("tripCode") or trip.get("code") or f"#{trip_id}"
            return cls._response(
                f"Đã kiểm tra chuyến {code} thuộc tài khoản của bạn và mở màn hình chi tiết chuyến {trip_id}.",
                model,
                "COMPLETED",
                plan,
                trace,
                False,
                [action],
            )
        except (McpToolError, KeyError, ValueError) as exception:
            return cls._response(
                f"Tôi không thể mở chi tiết chuyến {trip_id}: {exception}",
                model,
                "FAILED",
                plan,
                trace,
                False,
            )

    @classmethod
    def _deterministic_data_shortcut(
        cls,
        question: str,
        model: str,
        mcp_client: Any,
        allowed_tools: list[str],
    ) -> AgentChatResponse | None:
        normalized = normalize_vietnamese(question)
        trip_id = cls._explicit_trip_id(question)
        explicit_date = cls._explicit_single_date(question)
        kind = ""
        calls: list[tuple[str, dict[str, Any]]] = []

        if trip_id and "phieu xuat kho" in normalized:
            kind = "WAREHOUSE"
            calls = [
                ("get_trip_detail", {"trip_id": trip_id}),
                ("get_warehouse_issue", {"trip_id": trip_id}),
            ]
        elif trip_id and "chi tiet chuyen" in normalized:
            kind = "TRIP_DETAIL"
            calls = [("get_trip_detail", {"trip_id": trip_id})]
        elif trip_id and ("tom tat" in normalized or "tong ket" in normalized):
            kind = "TRIP_SUMMARY"
            calls = [("get_trip_summary", {"trip_id": trip_id})]
        elif explicit_date and "hoan thanh" in normalized and "dang chay" in normalized:
            kind = "DATE_COMPLETED_ACTIVE"
            date_arguments = {
                "start_date": explicit_date,
                "end_date": explicit_date,
                "limit": 50,
            }
            calls = [
                ("list_completed_trips", date_arguments),
                ("list_active_trips", date_arguments),
            ]
        elif "tong ket" in normalized and "phan cong" in normalized:
            kind = "ASSIGNMENT_SUMMARY"
            calls = [("get_current_assignment", {})]
        elif (
            "doi chieu" in normalized
            and "phan cong" in normalized
            and "phien lai" in normalized
        ):
            kind = "ASSIGNMENT_SESSION"
            calls = [("get_current_assignment", {}), ("get_current_driving_session", {})]
        elif "thong bao chua doc" in normalized or (
            "bao nhieu thong bao" in normalized and "chua doc" in normalized
        ):
            kind = "UNREAD_NOTIFICATIONS"
            calls = [("list_notifications", {"unread_only": True, "limit": 100})]
        elif "chua di" in normalized and "toan bo" in normalized:
            kind = "UPCOMING_LIST"
            calls = [
                (
                    "list_upcoming_trips",
                    {"start_date": None, "end_date": None, "limit": 50},
                )
            ]
        elif "liet ke" in normalized and "hoan thanh" in normalized:
            kind = "COMPLETED_LIST"
            calls = [
                (
                    "list_completed_trips",
                    {"start_date": None, "end_date": None, "limit": 50},
                )
            ]
        elif "nhung chuyen" in normalized and "dang chay" in normalized:
            kind = "ACTIVE_LIST"
            calls = [
                (
                    "list_active_trips",
                    {"start_date": None, "end_date": None, "limit": 50},
                )
            ]
        required_tools = {name for name, _ in calls}
        if kind == "ASSIGNMENT_SUMMARY":
            required_tools.add("get_trip_summary")
        if not calls or not required_tools.issubset(set(allowed_tools)):
            return None

        # Tổng kết phân công cần lấy ID thật trước, tuyệt đối không dùng ID do model đoán.
        plan = Plan(
            goal=question,
            steps=[f"Thực thi {name}" for name, _ in calls],
            expected_tools=[name for name, _ in calls],
        )
        trace: list[AgentStep] = []
        results: dict[str, dict[str, Any]] = {}
        try:
            for index, (name, arguments) in enumerate(calls, start=1):
                result = mcp_client.execute(name, arguments)
                if not result.get("ok"):
                    raise McpToolError(str(result.get("error") or f"Tool {name} thất bại"))
                results[name] = result
                trace.append(
                    AgentStep(
                        index=index,
                        tool=name,
                        arguments=cls._compact(arguments, 500),
                        success=True,
                        plan_check="CONTINUE" if index < len(calls) else "COMPLETE",
                        reason="Đã lấy dữ liệu có kiểm soát từ tài khoản đăng nhập.",
                    )
                )

            if kind == "DATE_COMPLETED_ACTIVE":
                results["_scope"] = {"date": explicit_date}

            if kind == "ASSIGNMENT_SUMMARY":
                assignment = results["get_current_assignment"].get("assignment") or {}
                trip = assignment.get("trip") or {}
                resolved_id = int(trip.get("id") or 0)
                summary_arguments = {"trip_id": resolved_id}
                summary = mcp_client.execute("get_trip_summary", summary_arguments)
                if not summary.get("ok"):
                    raise McpToolError(str(summary.get("error") or "Không lấy được tổng kết chuyến"))
                results["get_trip_summary"] = summary
                plan = Plan(
                    goal=question,
                    steps=["Lấy phân công hiện tại", "Lấy tổng kết đúng chuyến được phân công"],
                    expected_tools=["get_current_assignment", "get_trip_summary"],
                )
                trace[0].plan_check = "CONTINUE"
                trace.append(
                    AgentStep(
                        index=2,
                        tool="get_trip_summary",
                        arguments=cls._compact(summary_arguments, 500),
                        success=True,
                        plan_check="COMPLETE",
                        reason="Đã dùng đúng trip ID từ phân công hiện tại.",
                    )
                )

            text = cls._render_deterministic_data(kind, results)
            return cls._response(text, model, "COMPLETED", plan, trace, False)
        except (McpToolError, KeyError, TypeError, ValueError) as exception:
            return cls._response(
                f"Tôi không thể hoàn tất yêu cầu từ dữ liệu hệ thống: {exception}",
                model,
                "FAILED",
                plan,
                trace,
                False,
            )

    @staticmethod
    def _render_deterministic_data(
        kind: str, results: dict[str, dict[str, Any]]
    ) -> str:
        if kind == "WAREHOUSE":
            issue = results["get_warehouse_issue"].get("warehouseIssue") or {}
            delivered = sum(float(item.get("deliveredQuantity") or 0) for item in issue.get("items") or [])
            delivered_text = str(int(delivered)) if delivered.is_integer() else str(delivered)
            return (
                f"Phiếu xuất kho của chuyến {issue.get('tripId')} có mã {issue.get('issueNumber')} "
                f"và số lượng hàng đã giao là {delivered_text}."
            )
        if kind == "TRIP_DETAIL":
            trip = results["get_trip_detail"].get("trip") or {}
            return (
                f"Chuyến {trip.get('id')} có mã {trip.get('tripCode')}, xe "
                f"{trip.get('vehiclePlateNumber')}, đi từ {trip.get('startLocation')} đến "
                f"{trip.get('endLocation')}, trạng thái {trip.get('status')}, tiến độ "
                f"{trip.get('progress')}% và mức rủi ro {trip.get('riskLevel')}."
            )
        if kind == "TRIP_SUMMARY":
            summary = results["get_trip_summary"].get("summary") or {}
            trip = summary.get("trip") or {}
            raw_end = str(trip.get("actualEndTime") or "")
            ended = datetime.fromisoformat(raw_end).strftime("%H:%M ngày %d/%m/%Y") if raw_end else "chưa kết thúc"
            checklist = "checklist đã nộp" if summary.get("checklistSubmitted") else "checklist chưa nộp"
            next_action = str(summary.get("nextAction") or "NONE")
            action_text = "không còn hành động tiếp theo" if next_action == "NONE" else f"hành động tiếp theo là {next_action}"
            return (
                f"Chuyến {trip.get('tripCode')} có trạng thái {trip.get('status')}, hoàn thành lúc "
                f"{ended}, tiến độ {trip.get('progress')}%, {checklist} và {action_text}."
            )
        if kind == "DATE_COMPLETED_ACTIVE":
            completed = results["list_completed_trips"].get("trips") or []
            active = results["list_active_trips"].get("trips") or []
            raw_date = str((results.get("_scope") or {}).get("date") or "")
            display_date = datetime.fromisoformat(raw_date).strftime("%d/%m/%Y")
            completed_codes = ", ".join(str(trip.get("tripCode")) for trip in completed) or "không có"
            active_codes = ", ".join(str(trip.get("tripCode")) for trip in active) or "không có"
            return (
                f"Ngày {display_date} bạn hoàn thành {len(completed)} chuyến: {completed_codes}. "
                f"Có {len(active)} chuyến được tính là đang chạy trong ngày: {active_codes}."
            )
        if kind == "ASSIGNMENT_SUMMARY":
            assignment = results["get_current_assignment"].get("assignment") or {}
            trip = assignment.get("trip") or {}
            summary = results["get_trip_summary"].get("summary") or {}
            checklist = "đã nộp checklist" if assignment.get("checklistSubmitted") else "chưa nộp checklist"
            return (
                f"Phân công hiện tại là {trip.get('tripCode')}, tiến độ {trip.get('progress')}%, "
                f"{checklist}. Tổng kết cho biết hành động tiếp theo là {summary.get('nextAction')}."
            )
        if kind == "ASSIGNMENT_SESSION":
            assignment = results["get_current_assignment"].get("assignment") or {}
            assignment_id = int(((assignment.get("trip") or {}).get("id")) or 0)
            session = results["get_current_driving_session"].get("session") or {}
            session_id = int(session.get("tripId") or 0)
            session_status = str(session.get("status") or "UNKNOWN")
            if assignment_id != session_id:
                return (
                    f"Dữ liệu không khớp: phân công hiện tại trả chuyến {assignment_id} nhưng phiên lái "
                    f"{session_status} lại gắn với chuyến {session_id}. Cần quản lý kiểm tra dữ liệu "
                    "trước khi thao tác."
                )
            return f"Dữ liệu khớp: phân công và phiên lái {session_status} đều thuộc chuyến {session_id}."
        if kind == "UNREAD_NOTIFICATIONS":
            result = results["list_notifications"]
            notifications = result.get("notifications") or []
            contents = sorted({str(item.get("content") or "").strip() for item in notifications})
            subject = ", ".join(value for value in contents if value) or "không có nội dung"
            return f"Bạn có {len(notifications)} thông báo chưa đọc. Nội dung cảnh báo: {subject}."

        tool = {
            "UPCOMING_LIST": "list_upcoming_trips",
            "COMPLETED_LIST": "list_completed_trips",
            "ACTIVE_LIST": "list_active_trips",
        }[kind]
        trips = results[tool].get("trips") or []
        if kind == "UPCOMING_LIST":
            details = []
            for trip in trips:
                raw_date = str(trip.get("plannedStartTime") or "")
                formatted = datetime.fromisoformat(raw_date).strftime("%d/%m/%Y") if raw_date else "chưa rõ ngày"
                details.append(f"{trip.get('tripCode')} ngày {formatted}")
            statuses = sorted({str(trip.get("status") or "UNKNOWN") for trip in trips})
            return (
                f"Bạn còn {len(trips)} chuyến chưa đi: {', '.join(details)}; "
                f"trạng thái {', '.join(statuses)}."
            )
        codes = ", ".join(str(trip.get("tripCode")) for trip in trips)
        if kind == "COMPLETED_LIST":
            return f"Bạn có {len(trips)} chuyến đã hoàn thành: {codes}."
        statuses = sorted({str(trip.get("status") or "UNKNOWN") for trip in trips})
        return f"Dữ liệu hiện có {len(trips)} chuyến {', '.join(statuses)}: {codes}."

    @staticmethod
    def _plan_from(value: dict[str, Any], fallback_goal: str, allowed_tools: list[str]) -> Plan:
        return Plan(
            goal=str(value.get("goal") or fallback_goal),
            steps=[str(item) for item in value.get("steps") or []],
            expected_tools=[
                str(item) for item in value.get("expected_tools") or [] if item in allowed_tools
            ],
        )

    @staticmethod
    def _conversation(request: AgentChatRequest) -> str:
        return "\n".join(f"{message.role}: {message.content}" for message in request.messages)

    @staticmethod
    def _compact(value: Any, limit: int) -> str:
        text = json.dumps(value, ensure_ascii=False, default=str, separators=(",", ":"))
        return text if len(text) <= limit else text[:limit]

    @staticmethod
    def _plan_text(plan: Plan) -> str:
        return json.dumps(
            {"goal": plan.goal, "steps": plan.steps, "expectedTools": plan.expected_tools},
            ensure_ascii=False,
        )

    @staticmethod
    def _object_schema(properties: dict[str, Any], required: list[str]) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": properties,
            "required": required,
            "additionalProperties": False,
        }

    @classmethod
    def _plan_schema(cls, allowed_tools: list[str]) -> dict[str, Any]:
        return cls._object_schema(
            {
                "goal": {"type": "string"},
                "steps": {"type": "array", "items": {"type": "string"}},
                "expected_tools": {
                    "type": "array",
                    "items": {"type": "string", "enum": allowed_tools},
                },
            },
            ["goal", "steps", "expected_tools"],
        )

    @classmethod
    def _check_schema(cls) -> dict[str, Any]:
        return cls._object_schema(
            {
                "status": {"type": "string", "enum": ["CONTINUE", "COMPLETE", "REPLAN", "ERROR"]},
                "reason": {"type": "string"},
                "revised_plan": cls._object_schema(
                    {
                        "goal": {"type": "string"},
                        "steps": {"type": "array", "items": {"type": "string"}},
                        "expected_tools": {"type": "array", "items": {"type": "string"}},
                    },
                    ["goal", "steps", "expected_tools"],
                ),
            },
            ["status", "reason", "revised_plan"],
        )

    @staticmethod
    def _structured_format(name: str, schema: dict[str, Any]) -> dict[str, Any]:
        return {
            "type": "json_schema",
            "json_schema": {"name": name, "strict": True, "schema": schema},
        }
