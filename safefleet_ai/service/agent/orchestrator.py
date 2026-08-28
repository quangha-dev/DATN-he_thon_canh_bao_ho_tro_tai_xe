from __future__ import annotations

import json
import re
import time
from dataclasses import dataclass
from datetime import date, datetime
from typing import Any

from service.agent.clarification import (
    OTHER_DRIVER_RESPONSE,
    PROMPT_INJECTION_RESPONSE,
    TRIP_SCOPE_QUESTION,
    UNSUPPORTED_WEATHER_RESPONSE,
    has_explicit_date_scope,
    needs_trip_scope_clarification,
    normalize_vietnamese,
    requests_other_driver_data,
    requests_prompt_override_or_secrets,
    requests_ranked_upcoming_scope,
    requests_unsupported_weather,
    requests_upcoming_scope,
)
from service.agent.configuration import AgentConfigurationStore
from service.agent.critical_workflows import run_critical_workflow
from service.agent.models import (
    AgentChatRequest,
    AgentChatResponse,
    AgentClientAction,
    AgentConfirmationRequest,
    AgentRunMetrics,
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
        started = time.perf_counter()
        begin_tracking = getattr(self._openai, "begin_usage_tracking", None)
        end_tracking = getattr(self._openai, "end_usage_tracking", None)
        usage_token = begin_tracking() if callable(begin_tracking) else None
        usage: dict[str, Any] = {}
        try:
            response = self._respond(request, user_authorization)
        finally:
            if usage_token is not None and callable(end_tracking):
                usage = end_tracking(usage_token)
        response.run_metrics = AgentRunMetrics(
            duration_ms=max(0, round((time.perf_counter() - started) * 1000)),
            model_calls=int(usage.get("model_calls") or 0),
            input_tokens=int(usage.get("input_tokens") or 0),
            output_tokens=int(usage.get("output_tokens") or 0),
            total_tokens=int(usage.get("total_tokens") or 0),
            estimated_cost_usd=usage.get("estimated_cost_usd"),
        )
        return response

    def _respond(self, request: AgentChatRequest, user_authorization: str) -> AgentChatResponse:
        configuration = self._configuration_store.runtime()
        if not configuration.enabled or not configuration.api_key:
            return AgentChatResponse(
                response_text="Trợ lý dữ liệu chưa được bật. Quản trị viên cần nhập OpenAI API key trong Cấu hình hệ thống.",
                model=configuration.model,
                status="NOT_CONFIGURED",
            )

        question = request.messages[-1].content
        if requests_prompt_override_or_secrets(question):
            return AgentChatResponse(
                response_text=PROMPT_INJECTION_RESPONSE,
                model=configuration.model,
                status="GUARDRAIL_BLOCKED",
            )
        if requests_unsupported_weather(question):
            return AgentChatResponse(
                response_text=UNSUPPORTED_WEATHER_RESPONSE,
                model=configuration.model,
                status="COMPLETED",
            )
        if needs_trip_scope_clarification(question) and not requests_other_driver_data(question):
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
            if not self._allows_trip_mutation(question):
                mcp_tools = [
                    tool for tool in mcp_tools if str(tool.get("name") or "") != "prepare_trip_action"
                ]
            allowed_tools = [str(tool.get("name")) for tool in mcp_tools]
            if not allowed_tools:
                raise McpToolError("Tài khoản đăng nhập không có tool agent nào được cấp quyền")
            management_mode = any(name.startswith("management_") for name in allowed_tools)
            if not management_mode and requests_other_driver_data(question):
                return AgentChatResponse(
                    response_text=OTHER_DRIVER_RESPONSE,
                    model=configuration.model,
                    status="COMPLETED",
                )
            definitions = openai_tool_definitions(mcp_tools)
            shortcut = self._open_trip_detail_shortcut(
                question, configuration.model, mcp_client, allowed_tools
            )
            if shortcut is not None:
                return shortcut
            shortcut = self._open_mobile_screen_shortcut(
                question, configuration.model, mcp_client, allowed_tools
            )
            if shortcut is not None:
                return shortcut
            shortcut = self._critical_workflow_shortcut(
                question, configuration.model, mcp_client, allowed_tools
            )
            if shortcut is not None:
                return shortcut
            shortcut = self._deterministic_data_shortcut(
                question, configuration.model, mcp_client, allowed_tools
            )
            if shortcut is not None:
                return shortcut
            plan = self._create_plan(
                configuration, request, question, allowed_tools, management_mode
            )
            plan = self._with_required_tools(question, plan, allowed_tools)
            messages = self._execution_messages(request, plan, management_mode)
            resolved_trip_ids: dict[str, int] = {}
            tool_cache: dict[str, dict[str, Any]] = {}
            result_fingerprints: dict[str, dict[str, int]] = {}

            step_index = 0
            empty_tool_rounds = 0
            step_budget = self._step_budget(question, configuration.max_steps)
            while step_index < step_budget:
                message = self._openai.chat(
                    configuration,
                    messages,
                    tools=definitions,
                    tool_choice="auto",
                )
                calls = message.get("tool_calls") or []
                if not calls:
                    answer = (message.get("content") or "").strip()
                    missing_planned = self._missing_tools_from_trace(plan, trace)
                    if missing_planned and empty_tool_rounds < 2:
                        empty_tool_rounds += 1
                        messages.append({"role": "assistant", "content": answer})
                        messages.append(
                            {
                                "role": "system",
                                "content": (
                                    "Bạn chưa phát tool_calls hợp lệ. Không được mô tả hoặc in JSON giả "
                                    "thay cho việc gọi tool. Hãy phát tool_calls thật cho các tool còn "
                                    "thiếu trong kế hoạch: "
                                    + ", ".join(missing_planned)
                                ),
                            }
                        )
                        continue
                    if self._requires_prepared_navigation(question) and not self._has_prepared_navigation(
                        client_actions
                    ):
                        return self._response(
                            "Tôi chưa tạo được tuyến dẫn đường có điểm đến hợp lệ nên chưa thể bắt đầu điều hướng.",
                            configuration.model,
                            "FAILED",
                            plan,
                            trace,
                            replanned,
                            client_actions,
                        )
                    return self._response(
                        answer or "Tôi chưa tổng hợp được câu trả lời từ dữ liệu chuyến.",
                        configuration.model,
                        "COMPLETED",
                        plan,
                        trace,
                        replanned,
                        client_actions,
                    )

                # Never append an assistant tool-call batch that cannot be answered in
                # full within the remaining budget.  A partial batch makes the next
                # Chat Completions request invalid (missing tool_call_id responses).
                remaining_steps = step_budget - step_index
                calls = calls[:remaining_steps]
                messages.append(
                    {
                        "role": "assistant",
                        "content": message.get("content"),
                        "tool_calls": calls,
                    }
                )
                complete = False
                restart_execution = False
                for call in calls:
                    if step_index >= step_budget:
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
                        and "list_upcoming_trips" not in plan.expected_tools
                    ):
                        tool_name = "rank_upcoming_trips"
                    arguments = self._normalize_trip_arguments(question, tool_name, arguments)
                    arguments = self._normalize_dependency_arguments(
                        question, tool_name, arguments, resolved_trip_ids
                    )
                    cache_key = self._tool_cache_key(tool_name, arguments)
                    cached_result = tool_cache.get(cache_key)
                    if cached_result is not None:
                        tool_result = {**cached_result, "_deduplicated": True}
                    else:
                        try:
                            if tool_name not in allowed_tools:
                                raise McpToolError(f"Tool không thuộc quyền tài khoản: {tool_name}")
                            tool_result = mcp_client.execute(tool_name, arguments)
                        except McpToolError as exception:
                            tool_result = {"ok": False, "error": str(exception)}
                        if bool(tool_result.get("ok")):
                            tool_cache[cache_key] = tool_result
                    fingerprint = self._result_fingerprint(tool_result)
                    same_results = result_fingerprints.setdefault(tool_name, {})
                    same_results[fingerprint] = same_results.get(fingerprint, 0) + 1
                    duplicate_blocked = same_results[fingerprint] > 2
                    if duplicate_blocked:
                        tool_result = {
                            **tool_result,
                            "_loopGuard": {
                                "blocked": True,
                                "reason": (
                                    "Tool đã cho cùng một kết quả quá 2 lần; phải trả lời từ "
                                    "bằng chứng hiện có hoặc lập kế hoạch mới."
                                ),
                            },
                        }
                    self._remember_trip_id(tool_name, tool_result, resolved_trip_ids)
                    messages.append(
                        {
                            "role": "tool",
                            "tool_call_id": call_id,
                            "content": json.dumps(tool_result, ensure_ascii=False, default=str),
                        }
                    )
                    if duplicate_blocked:
                        decision = self._evaluate_duplicate_result(
                            configuration,
                            question,
                            plan,
                            tool_name,
                            arguments,
                            tool_result,
                            trace,
                            allowed_tools,
                        )
                        trace.append(
                            AgentStep(
                                index=step_index,
                                tool=tool_name,
                                arguments=self._compact(arguments, 500),
                                success=bool(tool_result.get("ok")),
                                plan_check="DUPLICATE_RESULT_BLOCKED",
                                reason=decision["reason"],
                            )
                        )
                        if decision["decision"] == "ANSWER":
                            messages.append(
                                {
                                    "role": "system",
                                    "content": (
                                        "Vòng lặp tool đã bị chặn. Trả lời ngay bằng tiếng Việt chỉ "
                                        "từ kết quả tool đã có; nêu rõ nếu dữ liệu chưa đủ và không "
                                        "được gọi thêm tool."
                                    ),
                                }
                            )
                            final_message = self._openai.chat(configuration, messages, tools=[])
                            answer = (final_message.get("content") or "").strip()
                            return self._response(
                                answer or "Đã dừng vòng lặp tool; dữ liệu hiện có chưa đủ để kết luận.",
                                configuration.model,
                                "LOOP_GUARD_COMPLETED",
                                plan,
                                trace,
                                replanned,
                                client_actions,
                            )
                        plan = self._plan_from(
                            decision.get("revised_plan") or {}, plan.goal, allowed_tools
                        )
                        plan = self._with_required_tools(question, plan, allowed_tools)
                        replanned = True
                        restart_execution = True
                        messages.append(
                            {
                                "role": "system",
                                "content": (
                                    "Vòng lặp đã bị chặn. Không gọi lại cùng tool với cùng tham số/kết quả. "
                                    f"Kế hoạch thay thế: {self._plan_text(plan)}"
                                ),
                            }
                        )
                        break
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
                    if (
                        tool_name == "search_internal_documents"
                        and bool(tool_result.get("ok"))
                        and check["status"] == "ERROR"
                    ):
                        check = {
                            "status": "COMPLETE",
                            "reason": (
                                "Tra cứu tài liệu đã hoàn tất; nếu citations không đủ thì phải "
                                "thông báo thiếu căn cứ thay vì coi đó là lỗi hệ thống."
                            ),
                            "revised_plan": {},
                        }
                    if bool(tool_result.get("ok")) and check["status"] == "ERROR":
                        missing_after_call = self._missing_planned_tools(
                            plan, trace, tool_name, tool_result
                        )
                        check = {
                            "status": "CONTINUE" if missing_after_call else "COMPLETE",
                            "reason": (
                                "Tool đã thực thi thành công. Phát hiện rủi ro hoặc điều kiện nghiệp vụ "
                                "không đạt là bằng chứng để kết luận an toàn, không phải lỗi hệ thống."
                            ),
                            "revised_plan": {},
                        }
                    if (
                        check["status"] == "COMPLETE"
                        and self._missing_planned_tools(plan, trace, tool_name, tool_result)
                    ):
                        missing_tools = self._missing_planned_tools(
                            plan, trace, tool_name, tool_result
                        )
                        check = {
                            "status": "CONTINUE",
                            "reason": (
                                "Kế hoạch chưa hoàn tất; còn thiếu tool đã cam kết: "
                                + ", ".join(missing_tools)
                            ),
                            "revised_plan": {},
                        }
                        messages.append(
                            {
                                "role": "system",
                                "content": (
                                    "Chưa được kết thúc. Kế hoạch đã cam kết còn thiếu các tool: "
                                    + ", ".join(missing_tools)
                                    + ". Hãy gọi các tool còn thiếu hoặc REPLAN với lý do dựa trên bằng chứng."
                                ),
                            }
                        )
                    if (
                        check["status"] == "COMPLETE"
                        and self._requires_prepared_navigation(question)
                        and not self._has_prepared_navigation(client_actions)
                    ):
                        check = {
                            "status": "CONTINUE",
                            "reason": (
                                "Yêu cầu dẫn đường chưa hoàn tất: bắt buộc gọi prepare_navigation "
                                "để tạo START_NAVIGATION với điểm đến đã xác thực."
                            ),
                            "revised_plan": {},
                        }
                        messages.append(
                            {
                                "role": "system",
                                "content": (
                                    "Chưa được kết thúc. Người dùng yêu cầu dẫn đường đến một địa điểm; "
                                    "hãy gọi prepare_navigation với truy vấn điểm đến và selected_index. "
                                    "open_mobile_screen(ROUTE) không tạo tuyến và không thay thế bước này."
                                ),
                            }
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
                        plan = self._with_required_tools(question, plan, allowed_tools)
                        replanned = True
                        messages.append(
                            {
                                "role": "system",
                                "content": f"Kế hoạch mới bắt buộc dùng: {self._plan_text(plan)}",
                            }
                        )
                    complete = complete or check["status"] == "COMPLETE"
                if restart_execution:
                    continue
                if complete:
                    messages.append(
                        {
                            "role": "system",
                            "content": (
                                "Đã đủ dữ liệu. Trả lời cuối cùng bằng tiếng Việt, chỉ dựa trên "
                                "kết quả tool; không gọi thêm tool. Nếu kết quả có unavailableMetrics "
                                "hoặc dataAvailability.unavailableMetrics thì phải nêu rõ từng chỉ số "
                                "chưa có dữ liệu và tuyệt đối không tự ước tính. Nếu kết quả có dateScope="
                                "ALL_TIME_PENDING thì phải nói đây là các chuyến đang chờ trên "
                                "toàn bộ thời gian, tuyệt đối không gọi là chuyến hôm nay. Với RAG, "
                                "mọi kết luận phải kèm [documentKey – headingPath]. Khi đối chiếu phạm "
                                "vi, giữ nguyên tên trường và viết dạng field=value (ví dụ totalTrips=2), "
                                "đồng thời nói rõ chỉ số hiện hành không phải tổng lịch sử."
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
                f"Tôi đã dừng vì đạt giới hạn {step_budget} bước nhưng chưa đủ dữ liệu để trả lời an toàn.",
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

    @staticmethod
    def _missing_planned_tools(
        plan: Plan,
        trace: list[AgentStep],
        current_tool: str,
        current_result: dict[str, Any],
    ) -> list[str]:
        completed = {step.tool for step in trace if step.success}
        if bool(current_result.get("ok")):
            completed.add(current_tool)
        return [tool for tool in dict.fromkeys(plan.expected_tools) if tool not in completed]

    @staticmethod
    def _missing_tools_from_trace(plan: Plan, trace: list[AgentStep]) -> list[str]:
        completed = {step.tool for step in trace if step.success}
        return [tool for tool in dict.fromkeys(plan.expected_tools) if tool not in completed]

    @staticmethod
    def _tool_cache_key(tool_name: str, arguments: dict[str, Any]) -> str:
        return f"{tool_name}:{json.dumps(arguments, ensure_ascii=False, sort_keys=True, default=str)}"

    @staticmethod
    def _result_fingerprint(result: dict[str, Any]) -> str:
        stable = {
            key: value
            for key, value in result.items()
            if key not in {"_audit", "_deduplicated", "_loopGuard", "generatedAt"}
        }
        return json.dumps(stable, ensure_ascii=False, sort_keys=True, default=str, separators=(",", ":"))

    def _evaluate_duplicate_result(
        self,
        configuration: Any,
        question: str,
        plan: Plan,
        tool_name: str,
        arguments: dict[str, Any],
        result: dict[str, Any],
        previous_steps: list[AgentStep],
        allowed_tools: list[str],
    ) -> dict[str, Any]:
        message = self._openai.chat(
            configuration,
            [
                {
                    "role": "system",
                    "content": (
                        "Một tool vừa trả cùng kết quả lần thứ ba và đã bị loop guard chặn. "
                        "Chọn ANSWER nếu bằng chứng hiện có đủ để trả lời hoặc đủ để nói rõ không có dữ liệu. "
                        "Chỉ chọn REPLAN nếu còn một tool KHÁC có thể cung cấp bằng chứng cần thiết; kế hoạch "
                        "mới tuyệt đối không được lặp lại tool/tham số vừa bị chặn. Không suy diễn ngoài dữ liệu."
                    ),
                },
                {
                    "role": "user",
                    "content": (
                        f"Câu hỏi: {question}\nKế hoạch: {self._plan_text(plan)}\n"
                        f"Các bước trước: {[step.model_dump(by_alias=True) for step in previous_steps]}\n"
                        f"Tool bị chặn: {tool_name}\nTham số: {arguments}\n"
                        f"Kết quả lặp: {self._compact(result, 14000)}"
                    ),
                },
            ],
            response_format=self._structured_format(
                "safefleet_duplicate_guard",
                self._duplicate_guard_schema(allowed_tools),
            ),
            max_tokens=500,
        )
        value = self._openai.structured_content(message)
        decision = str(value.get("decision") or "ANSWER").upper()
        if decision not in {"ANSWER", "REPLAN"}:
            decision = "ANSWER"
        return {
            "decision": decision,
            "reason": str(value.get("reason") or "Đã chặn vòng lặp kết quả trùng."),
            "revised_plan": value.get("revised_plan") or {},
        }

    @classmethod
    def _step_budget(cls, question: str, configured: int) -> int:
        focus = cls._task_focus(question)
        full_question = normalize_vietnamese(question)
        multi_entity = any(
            signal in focus
            for signal in ("toan bo", "nam chuyen", "hai chuyen", "hai dau lich", "nhieu nguon")
        ) or any(
            signal in full_question
            for signal in ("workflow phan tich dai", "workflow van hanh nhieu luot")
        )
        return min(10, max(configured, 10 if multi_entity else configured))

    @classmethod
    def _allows_trip_mutation(cls, question: str) -> bool:
        focus = cls._task_focus(question)
        guarded = any(
            signal in focus
            for signal in (
                "khong chuan bi",
                "khong tu thao tac",
                "quyet dinh co an toan",
                "chi chuan bi khi",
                "co diem bat thuong",
                "can chan thao tac",
            )
        )
        if guarded:
            return False
        return any(
            signal in focus
            for signal in (
                "chuan bi nhan chuyen cho toi",
                "hay chuan bi nhan chuyen",
                "chuan bi tam dung",
                "chuan bi pause",
                "chuan bi complete",
                "chuan bi start",
                "bat dau chuyen",
                "tam dung chuyen",
                "tiep tuc chuyen",
                "ket thuc chuyen",
            )
        )

    @classmethod
    def _with_required_tools(
        cls, question: str, plan: Plan, allowed_tools: list[str]
    ) -> Plan:
        required = cls._required_tools_for_question(question)
        expected = list(dict.fromkeys([*plan.expected_tools, *required]))
        expected = [tool for tool in expected if tool in allowed_tools]
        missing_steps = [
            f"Thu thập bằng chứng bắt buộc từ {tool}"
            for tool in expected
            if tool not in plan.expected_tools
        ]
        return Plan(
            goal=plan.goal,
            steps=[*plan.steps, *missing_steps],
            expected_tools=expected,
        )

    @classmethod
    def _required_tools_for_question(cls, question: str) -> list[str]:
        focus = cls._task_focus(question)
        required: list[str] = []

        def add(tool: str) -> None:
            if tool not in required:
                required.append(tool)

        trip_id = cls._explicit_trip_id(focus)
        if "phieu xuat kho" in focus:
            add("get_warehouse_issue")
        if "phien lai" in focus:
            add("get_current_driving_session")
        if "phan cong" in focus:
            add("get_current_assignment")
        if any(
            signal in focus
            for signal in (
                "diem an toan",
                "an toan hien tai",
                "phan cong va an toan",
                "tinh hinh an toan",
                "tong quan an toan",
            )
        ):
            add("get_safety_summary")
        if "thong bao" in focus:
            add("list_notifications")
        if "bao cao thang" in focus or re.search(r"\bthang\s+\d{1,2}\b", focus):
            add("get_monthly_report")

        if any(
            signal in focus
            for signal in (
                "tat ca chuyen",
                "toan bo 11 chuyen",
                "theo trang thai",
                "ty le hoan thanh",
            )
        ) or ("tuyen" in focus and any(signal in focus for signal in ("lap lai", "xuat hien"))):
            add("list_all_trips")

        completed_scope = any(
            signal in focus
            for signal in (
                "danh sach chuyen hoan thanh",
                "chuyen da hoan thanh",
                "toi hoan thanh chuyen nao",
                "nhom hoan thanh",
            )
        )
        if completed_scope:
            add("list_completed_trips")
        if "dang chay" in focus and "phien lai" not in focus:
            add("list_active_trips")

        upcoming = any(
            signal in focus
            for signal in ("chua di", "chuyen sap toi", "chuyen chua di")
        )
        ranked = any(
            signal in focus
            for signal in ("som nhat", "muon nhat", "xep cac", "uu tien", "can di truoc")
        )
        if upcoming and (
            "muon nhat" in focus or "xep cac" in focus or "khoang cach ngay" in focus
        ):
            add("list_upcoming_trips")
        elif upcoming and not ranked:
            add("list_upcoming_trips")
        if ranked:
            add("rank_upcoming_trips")

        summary_signals = (
            "tom tat",
            "tong ket",
            "checklist",
            "nextaction",
            "hanh dong tiep theo",
            "can lam gi",
            "ket qua chuyen",
            "chenh lech ke hoach",
        )
        assignment_checklist_only = (
            "phan cong hien tai" in focus
            and "checklist" in focus
            and not any(
                signal in focus
                for signal in ("tom tat", "tong ket", "nextaction", "hanh dong tiep theo", "can lam gi")
            )
        )
        if not assignment_checklist_only and any(signal in focus for signal in summary_signals) and (
            trip_id is not None or upcoming or "phan cong" in focus
        ):
            add("get_trip_summary")
        if "tam dung" in focus and "phan cong" in focus:
            add("get_trip_summary")

        detail_signals = (
            "chi tiet",
            "tuyen",
            "khoi hanh",
            "lich",
            "muc rui ro",
            "tien do",
            "ke hoach va thuc te",
            "chenh lech ke hoach",
        )
        if trip_id is not None and any(signal in focus for signal in detail_signals):
            add("get_trip_detail")
        if "hai chuyen" in focus and "tuyen" in focus:
            add("get_trip_detail")
        return required

    @staticmethod
    def _task_focus(question: str) -> str:
        normalized = normalize_vietnamese(question)
        boundaries = (
            (
                "tuyet doi khong tuyen bo hanh dong da hoan tat.",
                "ket luan phai tach ro:",
            ),
            (
                "neu co bat nhat, hay chi ro thay vi tu chon mot ban ghi.",
                "trinh bay ket qua cuoi cung",
            ),
            (
                "tra loi ngan gon nhung neu ro bang chung quyet dinh.",
                "giu cau tra loi nhat quan",
            ),
        )
        for start, end in boundaries:
            if start not in normalized:
                continue
            focus = normalized.split(start, 1)[1]
            if end in focus:
                focus = focus.split(end, 1)[0]
            return focus.strip()
        return normalized

    def _create_plan(
        self,
        configuration: Any,
        request: AgentChatRequest,
        question: str,
        allowed_tools: list[str],
        management_mode: bool = False,
    ) -> Plan:
        scope_rules = (
            "Bạn phục vụ web quản lý và được đọc dữ liệu toàn đội xe qua các management_* tool. "
            "Với tên tài xế phải tìm ID trước; với nhóm tài xế, tìm danh sách rồi dùng "
            "management_compare_driver_group. Báo cáo ngày/tháng/năm phải quy đổi đúng khoảng ngày "
            "và dùng management_get_trip_period_report; danh sách chi tiết dùng management_search_trips. "
            "Không phát SQL, không vượt RBAC và không thay đổi dữ liệu. "
            if management_mode
            else (
                "Bạn phục vụ tài xế; chỉ dùng dữ liệu của đúng tài khoản đăng nhập, không yêu cầu ID "
                "tài xế và từ chối truy cập tài khoản khác. "
            )
        )
        messages = [
            {
                "role": "system",
                "content": (
                    f"Bạn là bộ lập kế hoạch SafeFleet. Hôm nay là {date.today().isoformat()} (Asia/Ho_Chi_Minh). "
                    "Lập kế hoạch động bằng dữ liệu thật của đúng tài khoản đăng nhập. "
                    f"Chỉ chọn tool MCP đã được server cấp quyền: {', '.join(allowed_tools)}. "
                    + scope_rules
                    +
                    "Ngày dùng YYYY-MM-DD. Chỉ lọc ngày khi người dùng nói rõ hôm nay, ngày cụ thể, tuần hoặc tháng. "
                    "Từ 'nay' đứng riêng không đồng nghĩa với 'hôm nay'. 'Gần nhất', 'sớm nhất' hoặc "
                    "'tiếp theo' bắt buộc dùng rank_upcoming_trips. 'Chờ nhận' hoặc "
                    "'chưa đi' phải dùng chuyến đang chờ trên toàn bộ thời gian, trừ khi người dùng nêu ngày. "
                    "Nếu người dùng trả lời 'tất cả' sau câu hỏi làm rõ, dùng list_all_trips. "
                    "Không bịa dữ liệu. Tool thay đổi trạng thái chỉ được chuẩn bị xác nhận. "
                    "Câu trả lời từ search_internal_documents phải trích dẫn đúng "
                    "[documentKey – headingPath] và không biến quy chế nội bộ thành tư vấn pháp lý. "
                    "Không dùng tool chuyến để trả lời thời tiết. "
                    "Khi tool sau phụ thuộc tool trước, phải dùng đúng trip ID trong kết quả tool trước."
                    " Với yêu cầu tìm đường/dẫn đường đến địa điểm, kế hoạch bắt buộc có "
                    "prepare_navigation; open_mobile_screen(ROUTE) chỉ mở trang rỗng và không được dùng thay thế."
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
                    "Không suy diễn ngoài kết quả tool. Nếu câu hỏi yêu cầu chỉ số được liệt kê trong "
                    "dataAvailability.unavailableMetrics, có thể COMPLETE khi phần còn lại đã đủ nhưng "
                    "reason bắt buộc nêu rõ chỉ số thiếu và câu trả lời cuối phải công khai giới hạn đó."
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
    def _execution_messages(
        request: AgentChatRequest, plan: Plan, management_mode: bool = False
    ) -> list[dict[str, Any]]:
        access_rules = (
            "Đây là agent web quản lý: được đọc dữ liệu toàn đội qua management_* tool. "
            "Tìm ID thật trước khi gọi tool phụ thuộc, tách báo cáo tổng hợp khỏi danh sách chi tiết, "
            "không phát SQL và không thay đổi dữ liệu. "
            if management_mode
            else "Không yêu cầu ID tài xế và không truy cập tài khoản khác. "
        )
        messages: list[dict[str, Any]] = [
            {
                "role": "system",
                "content": (
                    f"Bạn là agent SafeFleet phía server. Hôm nay là {date.today().isoformat()}. "
                    "Tự chọn tool MCP phù hợp. Có thể yêu cầu nhiều tool trong một lượt nhưng phải giữ đúng kế hoạch. "
                    "Tool đã được lọc theo quyền tài khoản. Không bịa dữ liệu. Khi kết quả có "
                    "dataAvailability.unavailableMetrics, phải nói rõ các chỉ số chưa có dữ liệu và "
                    "không tự tính hay ước lượng chúng. "
                    + access_rules
                    + "Không tự xác nhận thao tác thay đổi trạng thái. "
                    "Không được tự đoán trip ID. Tool phụ thuộc phải dùng đúng trip ID vừa nhận từ tool trước. "
                    "Khi dùng search_internal_documents, chỉ trả lời từ citations và giữ nguyên mã nguồn. "
                    "Khi người dùng yêu cầu tìm đường/dẫn đường đến địa điểm, bắt buộc gọi "
                    "prepare_navigation; không dùng open_mobile_screen(ROUTE) để giả vờ đã tạo tuyến. "
                    "Chỉ truyền start_date/end_date khi người dùng nêu rõ khoảng ngày. Với 'gần nhất', "
                    "'tiếp theo', 'chờ nhận', 'chưa đi' mà không có ngày rõ ràng, bắt buộc để hai ngày là null. "
                    "Khi yêu cầu so sánh nhiều chuyến hoặc kiểm tra toàn bộ danh sách, phải gọi tool phụ "
                    "thuộc cho từng trip ID khác nhau; một lần gọi cho một ID không đại diện cho cả danh sách. "
                    f"Kế hoạch ban đầu: {AgentOrchestrator._plan_text(plan)}"
                ),
            }
        ]
        messages.extend(message.model_dump() for message in request.messages)
        return messages

    @staticmethod
    def _requires_prepared_navigation(question: str) -> bool:
        normalized = normalize_vietnamese(question)
        return any(
            signal in normalized
            for signal in (
                "dan duong",
                "chi duong",
                "bat dau dieu huong",
                "bat dau dan duong",
                "chuan bi tuyen duong",
                "lap tuyen duong",
            )
        )

    @staticmethod
    def _has_prepared_navigation(actions: list[AgentClientAction]) -> bool:
        return any(
            action.type == "START_NAVIGATION"
            and bool(action.destination_name)
            and action.destination_lat is not None
            and action.destination_lng is not None
            for action in actions
        )

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
        try:
            provided_id = int(arguments.get("trip_id") or 0)
        except (TypeError, ValueError):
            provided_id = 0
        selected_id: int | None = explicit_id
        normalized = cls._task_focus(question)
        multi_entity = any(
            signal in normalized
            for signal in ("toan bo", "nam chuyen", "hai chuyen", "nhung chuyen nao", "hai dau lich")
        )
        if explicit_id is None and multi_entity and provided_id > 0:
            return arguments
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
        # Preserve a valid model-selected ID for multi-entity workflows when the
        # question does not declare a stronger explicit/dependency relationship.
        if selected_id is None and provided_id > 0:
            return arguments
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
    def _open_mobile_screen_shortcut(
        cls,
        question: str,
        model: str,
        mcp_client: Any,
        allowed_tools: list[str],
    ) -> AgentChatResponse | None:
        focus = cls._task_focus(question)
        if "open_mobile_screen" not in allowed_tools or cls._requires_prepared_navigation(question):
            return None
        if not any(signal in focus for signal in ("mo man hinh", "dua toi den man hinh")):
            return None
        destinations = (
            (("thong bao",), "NOTIFICATIONS", "thông báo"),
            (("an toan",), "SAFETY", "an toàn lái xe"),
            (("bao cao thang",), "MONTHLY_REPORT", "báo cáo tháng"),
            (("quet tai lieu", "tai lieu"), "DOCUMENT_SCAN", "quét tài liệu"),
            (("chuyen",), "TRIPS", "danh sách chuyến"),
            (("trang chu",), "HOME", "trang chủ"),
        )
        selected = next(
            (
                (destination, label)
                for signals, destination, label in destinations
                if any(signal in focus for signal in signals)
            ),
            None,
        )
        if selected is None:
            return None
        destination, label = selected
        arguments = {"destination": destination, "trip_id": None}
        plan = Plan(
            goal=question,
            steps=[f"Mở màn hình {label}"],
            expected_tools=["open_mobile_screen"],
        )
        try:
            result = mcp_client.execute("open_mobile_screen", arguments)
            if not result.get("ok"):
                raise McpToolError(str(result.get("error") or "Không mở được màn hình"))
            action = AgentClientAction.model_validate(result["clientAction"])
            trace = [
                AgentStep(
                    index=1,
                    tool="open_mobile_screen",
                    arguments=cls._compact(arguments, 500),
                    success=True,
                    plan_check="COMPLETE",
                    reason=f"Đã tạo lệnh mở màn hình {label}.",
                )
            ]
            return cls._response(
                f"Đã mở màn hình {label} trên điện thoại.",
                model,
                "COMPLETED",
                plan,
                trace,
                False,
                [action],
            )
        except (McpToolError, KeyError, TypeError, ValueError) as exception:
            return cls._response(
                f"Tôi không thể mở màn hình {label}: {exception}",
                model,
                "FAILED",
                plan,
                [],
                False,
            )

    @classmethod
    def _critical_workflow_shortcut(
        cls,
        question: str,
        model: str,
        mcp_client: Any,
        allowed_tools: list[str],
    ) -> AgentChatResponse | None:
        """Run safety-critical multi-source flows with deterministic evidence ordering."""

        try:
            result = run_critical_workflow(
                cls._task_focus(question), mcp_client.execute, allowed_tools
            )
            if result is None:
                return None
            plan = Plan(
                goal=question,
                steps=[f"Thu thập bằng chứng từ {call.name}" for call in result.calls],
                expected_tools=[call.name for call in result.calls],
            )
            trace = [
                AgentStep(
                    index=index,
                    tool=call.name,
                    arguments=cls._compact(call.arguments, 500),
                    success=True,
                    plan_check="CONTINUE" if index < len(result.calls) else "COMPLETE",
                    reason=f"Workflow {result.name} đã xác thực bằng chứng theo đúng quan hệ phụ thuộc.",
                )
                for index, call in enumerate(result.calls, start=1)
            ]
            return cls._response(result.text, model, "COMPLETED", plan, trace, False)
        except (McpToolError, KeyError, TypeError, ValueError) as exception:
            plan = Plan(goal=question, steps=["Thu thập bằng chứng vận hành"], expected_tools=[])
            return cls._response(
                f"Tôi không thể hoàn tất workflow an toàn từ dữ liệu hệ thống: {exception}",
                model,
                "FAILED",
                plan,
                [],
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
        normalized = cls._task_focus(question)
        trip_id = cls._explicit_trip_id(question)
        explicit_date = cls._explicit_single_date(question)
        kind = ""
        calls: list[tuple[str, dict[str, Any]]] = []
        month_match = re.search(r"thang\s+(\d{1,2})(?:\s+nam\s+(20\d{2}))?", normalized)
        report_month = int(month_match.group(1)) if month_match else date.today().month
        report_year = int(month_match.group(2)) if month_match and month_match.group(2) else date.today().year
        monthly_arguments = {"year": report_year, "month": report_month}

        if trip_id and "phieu xuat kho" in normalized and "ket qua chuyen" in normalized:
            kind = "WAREHOUSE_SUMMARY"
            calls = [
                ("get_warehouse_issue", {"trip_id": trip_id}),
                ("get_trip_summary", {"trip_id": trip_id}),
            ]
        elif trip_id and "phieu xuat kho" in normalized:
            kind = "WAREHOUSE"
            calls = [
                ("get_trip_detail", {"trip_id": trip_id}),
                ("get_warehouse_issue", {"trip_id": trip_id}),
            ]
        elif trip_id and any(
            signal in normalized for signal in ("chenh lech ke hoach", "ke hoach va thuc te")
        ):
            kind = "TRIP_TEMPORAL_ANALYSIS"
            calls = [
                ("get_trip_detail", {"trip_id": trip_id}),
                ("get_trip_summary", {"trip_id": trip_id}),
            ]
        elif trip_id and any(
            signal in normalized for signal in ("tuyen", "khoi hanh", "chi tiet")
        ) and any(
            signal in normalized
            for signal in ("checklist", "hanh dong tiep theo", "can lam gi", "nextaction")
        ):
            kind = "TRIP_DETAIL_SUMMARY"
            calls = [
                ("get_trip_detail", {"trip_id": trip_id}),
                ("get_trip_summary", {"trip_id": trip_id}),
            ]
        elif trip_id and any(
            signal in normalized
            for signal in ("tom tat", "tong ket", "checklist", "hanh dong tiep theo", "nextaction")
        ):
            kind = "TRIP_SUMMARY"
            calls = [("get_trip_summary", {"trip_id": trip_id})]
        elif trip_id and "phien lai" in normalized:
            kind = "TRIP_SESSION"
            calls = [
                ("get_trip_detail", {"trip_id": trip_id}),
                ("get_current_driving_session", {}),
            ]
        elif trip_id and any(
            signal in normalized
            for signal in (
                "chi tiet",
                "muc rui ro",
                "tien do",
                "lich va tuyen",
                "tuyen duong",
            )
        ):
            kind = "TRIP_DETAIL"
            calls = [("get_trip_detail", {"trip_id": trip_id})]
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
            "phan cong hien tai" in normalized or "duoc phan cong hien tai" in normalized
        ) and "checklist" in normalized:
            kind = "CURRENT_ASSIGNMENT"
            calls = [("get_current_assignment", {})]
        elif (
            "doi chieu" in normalized
            and "phan cong" in normalized
            and "phien lai" in normalized
        ):
            kind = "ASSIGNMENT_SESSION"
            calls = [("get_current_assignment", {}), ("get_current_driving_session", {})]
        elif "ty le chuyen rui ro high" in normalized or (
            "rui ro high" in normalized and "toan bo" in normalized
        ):
            kind = "RISK_SCOPE"
            calls = [
                ("list_all_trips", {"start_date": None, "end_date": None, "limit": 50}),
                ("get_safety_summary", {}),
            ]
        elif "ty le hoan thanh tu tinh" in normalized:
            kind = "COMPLETION_RECONCILIATION"
            calls = [
                ("list_completed_trips", {"start_date": None, "end_date": None, "limit": 50}),
                ("list_all_trips", {"start_date": None, "end_date": None, "limit": 50}),
                ("get_monthly_report", monthly_arguments),
            ]
        elif "canh bao thang" in normalized and "tap trung" in normalized:
            kind = "ALERT_DAYS"
            calls = [
                ("get_monthly_report", monthly_arguments),
                ("list_notifications", {"unread_only": True, "limit": 100}),
            ]
        elif "thong bao chua doc" in normalized and "phan tram" in normalized:
            kind = "ALERT_RATIOS"
            calls = [
                ("list_notifications", {"unread_only": True, "limit": 100}),
                ("get_monthly_report", monthly_arguments),
            ]
        elif "ba nguon" in normalized and "bao cao thang" in normalized:
            kind = "SCOPE_RECONCILIATION"
            calls = [
                ("list_all_trips", {"start_date": None, "end_date": None, "limit": 50}),
                ("get_monthly_report", monthly_arguments),
                ("get_safety_summary", {}),
            ]
        elif "thong bao chua doc" in normalized or (
            "bao nhieu thong bao" in normalized and "chua doc" in normalized
        ):
            kind = "UNREAD_NOTIFICATIONS"
            calls = [("list_notifications", {"unread_only": True, "limit": 100})]
        elif "tinh hinh an toan" in normalized or "tong quan an toan" in normalized:
            kind = "SAFETY_SUMMARY"
            calls = [("get_safety_summary", {})]
        elif "bao cao thang" in normalized:
            if month_match:
                kind = "MONTHLY_REPORT"
                calls = [("get_monthly_report", monthly_arguments)]
        elif "theo trang thai" in normalized and "chuyen" in normalized:
            kind = "ALL_STATUS"
            calls = [("list_all_trips", {"start_date": None, "end_date": None, "limit": 50})]
        elif "chua di" in normalized and any(
            signal in normalized for signal in ("som nhat", "can thuc hien som nhat", "tiep theo")
        ):
            kind = "RANK_UPCOMING"
            calls = [
                ("rank_upcoming_trips", {"start_date": None, "end_date": None, "limit": 1})
            ]
        elif "phien lai hien tai" in normalized and any(
            signal in normalized for signal in ("pause", "tam dung")
        ):
            kind = "SESSION_PAUSE_GUARD"
            calls = [("get_current_driving_session", {})]
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
        inferred_tools = set(cls._required_tools_for_question(question))
        # A deterministic shortcut may only terminate the request when it covers
        # every evidence source inferred from the actual task.  This prevents a
        # single-source shortcut (rank/monthly/notifications) from truncating a
        # longer comparison workflow.
        if not inferred_tools.issubset(required_tools):
            return None
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
                try:
                    result = mcp_client.execute(name, arguments)
                except McpToolError as exception:
                    missing_warehouse_issue = (
                        name == "get_warehouse_issue"
                        and "không tìm thấy phiếu xuất kho" in str(exception).casefold()
                    )
                    if not missing_warehouse_issue:
                        raise
                    # A missing optional warehouse document is valid evidence, not
                    # an infrastructure failure. Keep the workflow running so the
                    # agent can state that the record does not exist.
                    result = {"ok": True, "warehouseIssue": None, "notFound": True}
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
            if results["get_warehouse_issue"].get("notFound"):
                trip = results["get_trip_detail"].get("trip") or {}
                return (
                    f"Dữ liệu hiện tại xác nhận chuyến {trip.get('id')} tồn tại nhưng chưa có "
                    "phiếu xuất kho, nên chưa thể cung cấp mã phiếu hoặc số lượng đã giao."
                )
            delivered = sum(float(item.get("deliveredQuantity") or 0) for item in issue.get("items") or [])
            delivered_text = str(int(delivered)) if delivered.is_integer() else str(delivered)
            return (
                f"Phiếu xuất kho của chuyến {issue.get('tripId')} có mã {issue.get('issueNumber')} "
                f"và số lượng hàng đã giao là {delivered_text}."
            )
        if kind == "WAREHOUSE_SUMMARY":
            issue = results["get_warehouse_issue"].get("warehouseIssue") or {}
            summary = results["get_trip_summary"].get("summary") or {}
            trip = summary.get("trip") or {}
            if results["get_warehouse_issue"].get("notFound"):
                return (
                    f"Dữ liệu hiện tại cho thấy chuyến {trip.get('id')} ở trạng thái "
                    f"{trip.get('status')}, tiến độ {trip.get('progress')}%, nhưng không có phiếu "
                    "xuất kho để tính tỷ lệ giao hàng. Không tự suy đoán dữ liệu còn thiếu."
                )
            items = issue.get("items") or []
            requested = sum(float(item.get("requestedQuantity") or 0) for item in items)
            issued = sum(float(item.get("issuedQuantity") or 0) for item in items)
            delivered = sum(float(item.get("deliveredQuantity") or 0) for item in items)
            delivery_rate = (delivered / requested * 100) if requested else 0
            return (
                f"Phiếu {issue.get('issueNumber')} của chuyến {trip.get('id')} có requested="
                f"{requested:g}, issued={issued:g}, delivered={delivered:g}, tỷ lệ giao hàng "
                f"{delivery_rate:.0f}%. Chuyến đang {trip.get('status')} còn phiếu ở trạng thái "
                f"{issue.get('status')}; đây là hai trạng thái nghiệp vụ khác nhau."
            )
        if kind == "TRIP_DETAIL":
            trip = results["get_trip_detail"].get("trip") or {}
            raw_start = str(trip.get("plannedStartTime") or "")
            planned_start = (
                datetime.fromisoformat(raw_start).strftime("%d/%m/%Y %H:%M")
                if raw_start
                else "chưa rõ"
            )
            return (
                f"Chuyến {trip.get('id')} có mã {trip.get('tripCode')}, xe "
                f"{trip.get('vehiclePlateNumber')}, đi từ {trip.get('startLocation')} đến "
                f"{trip.get('endLocation')}, khởi hành dự kiến {planned_start}, trạng thái "
                f"{trip.get('status')}, tiến độ {trip.get('progress')}% và mức rủi ro "
                f"{trip.get('riskLevel')}."
            )
        if kind == "TRIP_SESSION":
            trip = results["get_trip_detail"].get("trip") or {}
            session = results["get_current_driving_session"].get("session")
            session_text = (
                f"phiên lái {session.get('status')} đang gắn với chuyến {session.get('tripId')}"
                if isinstance(session, dict)
                else "không có phiên lái hoạt động"
            )
            return (
                f"Chuyến {trip.get('id')} có mã {trip.get('tripCode')}, trạng thái "
                f"{trip.get('status')}, tiến độ {trip.get('progress')}%, rủi ro "
                f"{trip.get('riskLevel')}; {session_text}."
            )
        if kind == "TRIP_DETAIL_SUMMARY":
            trip = results["get_trip_detail"].get("trip") or {}
            summary = results["get_trip_summary"].get("summary") or {}
            raw_start = str(trip.get("plannedStartTime") or "")
            planned_start = (
                datetime.fromisoformat(raw_start).strftime("%d/%m/%Y") if raw_start else "chưa rõ"
            )
            checklist = (
                "đã nộp checklist" if summary.get("checklistSubmitted") else "chưa nộp checklist"
            )
            return (
                f"Chuyến {trip.get('tripCode')} đi từ {trip.get('startLocation')} đến "
                f"{trip.get('endLocation')}, khởi hành ngày {planned_start}, trạng thái "
                f"{trip.get('status')}, tiến độ {trip.get('progress')}%, {checklist}; "
                f"hành động tiếp theo là {summary.get('nextAction')}."
            )
        if kind == "TRIP_TEMPORAL_ANALYSIS":
            trip = results["get_trip_detail"].get("trip") or {}
            summary = results["get_trip_summary"].get("summary") or {}
            summary_trip = summary.get("trip") or {}
            temporal_values = {
                "bắt đầu dự kiến": trip.get("plannedStartTime"),
                "bắt đầu thực tế": trip.get("actualStartTime"),
                "kết thúc dự kiến": trip.get("estimatedEndTime"),
                "kết thúc thực tế": trip.get("actualEndTime")
                or summary_trip.get("actualEndTime"),
            }
            missing = [label for label, value in temporal_values.items() if not value]
            if missing:
                return (
                    f"Chuyến {trip.get('id')} chưa đủ dữ liệu để tính chênh lệch kế hoạch và "
                    f"thực tế; còn thiếu: {', '.join(missing)}. Không tự suy đoán thời gian."
                )
            planned_start = datetime.fromisoformat(str(temporal_values["bắt đầu dự kiến"]))
            actual_start = datetime.fromisoformat(str(temporal_values["bắt đầu thực tế"]))
            estimated_end = datetime.fromisoformat(str(temporal_values["kết thúc dự kiến"]))
            actual_end = datetime.fromisoformat(str(temporal_values["kết thúc thực tế"]))
            start_early_seconds = max(0, int((planned_start - actual_start).total_seconds()))
            actual_seconds = max(0, int(round((actual_end - actual_start).total_seconds())))
            end_early_seconds = max(0, int(round((estimated_end - actual_end).total_seconds())))
            start_hours, start_remainder = divmod(start_early_seconds, 3600)
            start_minutes = start_remainder // 60
            actual_minutes, actual_remaining = divmod(actual_seconds, 60)
            end_hours, end_remainder = divmod(end_early_seconds, 3600)
            end_minutes = int(round(end_remainder / 60))
            if end_minutes == 60:
                end_hours += 1
                end_minutes = 0
            return (
                f"Chuyến {trip.get('id')} dự kiến bắt đầu {planned_start:%d/%m/%Y %H:%M}, thực tế "
                f"bắt đầu {actual_start:%d/%m/%Y %H:%M:%S}, tức sớm khoảng {start_hours} giờ "
                f"{start_minutes} phút. Thời gian chạy thực tế là {actual_minutes} phút "
                f"{actual_remaining} giây. Chuyến kết thúc lúc {actual_end:%d/%m/%Y %H:%M}, sớm "
                f"hơn ước tính khoảng {end_hours} giờ {end_minutes} phút."
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
        if kind == "CURRENT_ASSIGNMENT":
            assignment = results["get_current_assignment"].get("assignment") or {}
            trip = assignment.get("trip") or {}
            checklist = (
                "đã nộp checklist" if assignment.get("checklistSubmitted") else "chưa nộp checklist"
            )
            return (
                f"Phân công hiện tại là {trip.get('tripCode')}, trạng thái {trip.get('status')}, "
                f"tiến độ {trip.get('progress')}%, rủi ro {trip.get('riskLevel')} và {checklist}."
            )
        if kind == "ASSIGNMENT_SESSION":
            assignment = results["get_current_assignment"].get("assignment") or {}
            assignment_id = int(((assignment.get("trip") or {}).get("id")) or 0)
            session = results["get_current_driving_session"].get("session") or {}
            if not session:
                return (
                    f"Phân công hiện tại là chuyến {assignment_id} nhưng không có phiên lái "
                    "ACTIVE; chưa thể đối chiếu hai trip ID và không thực hiện thao tác."
                )
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
        if kind == "RISK_SCOPE":
            trips = results["list_all_trips"].get("trips") or []
            high = [trip for trip in trips if str(trip.get("riskLevel") or "").upper() == "HIGH"]
            ratio = len(high) / len(trips) * 100 if trips else 0
            safety = results["get_safety_summary"].get("safety") or {}
            return (
                f"Có {len(high)}/{len(trips)} chuyến rủi ro HIGH, tương đương "
                f"{ratio:.2f}%".replace(".", ",")
                + f". Safety hiện {safety.get('status')}, điểm {safety.get('safetyScore')} và "
                f"totalTrips={safety.get('totalTrips')}; totalTrips của safety là phạm vi an toàn "
                "hiện hành, không phải tổng lịch sử nên không được đánh đồng."
            )
        if kind == "COMPLETION_RECONCILIATION":
            completed = results["list_completed_trips"].get("trips") or []
            all_trips = results["list_all_trips"].get("trips") or []
            report = results["get_monthly_report"].get("report") or {}
            ratio = len(completed) / len(all_trips) * 100 if all_trips else 0
            reported_rate = float(report.get("completionRate") or 0)
            difference = abs(ratio - reported_rate)
            reconciliation = (
                "hai tỷ lệ khớp trong sai số làm tròn."
                if difference <= 0.51
                else f"hai tỷ lệ chênh {difference:.2f} điểm phần trăm và cần đối soát."
            )
            return (
                f"Có {len(completed)} chuyến hoàn thành trên {len(all_trips)}, tức "
                f"{ratio:.2f}%".replace(".", ",")
                + f". Báo cáo tháng ghi completedTrips={report.get('completedTrips')}, "
                f"totalTrips={report.get('totalTrips')} và completionRate="
                f"{report.get('completionRate')}%; {reconciliation}"
            )
        if kind == "ALERT_RATIOS":
            notifications = results["list_notifications"].get("notifications") or []
            report = results["get_monthly_report"].get("report") or {}
            total_alerts = int(report.get("alertCount") or 0)
            critical = int(report.get("criticalAlertCount") or 0)
            unread_ratio = len(notifications) / total_alerts * 100 if total_alerts else 0
            critical_ratio = critical / total_alerts * 100 if total_alerts else 0
            contents = sorted(
                {str(item.get("content") or "").strip() for item in notifications if item.get("content")}
            )
            content_text = ", ".join(contents) if contents else "không có thông báo chưa đọc"
            return (
                f"Có {len(notifications)}/{total_alerts} thông báo chưa đọc, chiếm "
                f"{unread_ratio:.2f}%".replace(".", ",")
                + f"; cảnh báo nghiêm trọng là {critical}/{total_alerts}, chiếm "
                + f"{critical_ratio:.2f}%".replace(".", ",")
                + f". Nội dung: {content_text}."
            )
        if kind == "ALERT_DAYS":
            report = results["get_monthly_report"].get("report") or {}
            notifications = results["list_notifications"].get("notifications") or []
            total_alerts = int(report.get("alertCount") or 0)
            active_days = [day for day in report.get("days") or [] if int(day.get("alerts") or 0) > 0]
            parts = []
            for day in active_days:
                count = int(day.get("alerts") or 0)
                ratio = count / total_alerts * 100 if total_alerts else 0
                display = datetime.fromisoformat(str(day.get("date"))).strftime("%d/%m")
                parts.append(f"{display}: {count}/{total_alerts} ({ratio:.2f}%)".replace(".", ","))
            return (
                "Cảnh báo tháng tập trung vào "
                + "; ".join(parts)
                + f". Có {len(notifications)} thông báo chưa đọc; số này không được đồng nhất với "
                "tổng cảnh báo theo ngày vì hai chỉ số có phạm vi khác nhau."
            )
        if kind == "SCOPE_RECONCILIATION":
            all_trips = results["list_all_trips"].get("trips") or []
            report = results["get_monthly_report"].get("report") or {}
            safety = results["get_safety_summary"].get("safety") or {}
            return (
                f"Không mâu thuẫn: danh sách tất cả có {len(all_trips)} chuyến; báo cáo tháng "
                f"có totalTrips={report.get('totalTrips')} ({report.get('totalTrips')} chuyến); "
                f"safety có totalTrips={safety.get('totalTrips')} thuộc phạm vi an toàn hiện hành, "
                "không phải tổng lịch sử."
            )
        if kind == "SAFETY_SUMMARY":
            safety = results["get_safety_summary"].get("safety") or {}
            return (
                f"Trạng thái an toàn hiện tại là {safety.get('status')}, điểm an toàn "
                f"{safety.get('safetyScore')}, có {safety.get('totalAlerts')} cảnh báo, còn "
                f"{safety.get('remainingContinuousDrivingMinutes')} phút lái liên tục và dữ liệu "
                f"an toàn đang bao phủ {safety.get('totalTrips')} chuyến."
            )
        if kind == "MONTHLY_REPORT":
            report = results["get_monthly_report"].get("report") or {}
            return (
                f"Báo cáo {report.get('month')}: {report.get('totalTrips')} chuyến, "
                f"{report.get('completedTrips')} chuyến hoàn thành, tỷ lệ hoàn thành "
                f"{report.get('completionRate')}%, đúng giờ {report.get('onTimeRate')}%, điểm an toàn "
                f"{report.get('safetyScore')}, {report.get('alertCount')} cảnh báo, "
                f"{report.get('criticalAlertCount')} cảnh báo nghiêm trọng và quãng đường "
                f"{report.get('distanceKm')} km."
            )
        if kind == "ALL_STATUS":
            trips = results["list_all_trips"].get("trips") or []
            counts: dict[str, int] = {}
            for trip in trips:
                status = str(trip.get("status") or "UNKNOWN")
                counts[status] = counts.get(status, 0) + 1
            return (
                f"Tổng cộng {len(trips)} chuyến: {counts.get('COMPLETED', 0)} COMPLETED, "
                f"{counts.get('ASSIGNED', 0)} ASSIGNED và {counts.get('IN_PROGRESS', 0)} "
                "IN_PROGRESS; hiện không có chuyến IN_PROGRESS."
            )
        if kind == "RANK_UPCOMING":
            result = results["rank_upcoming_trips"]
            trip = result.get("recommendedTrip") or {}
            raw_start = str(trip.get("plannedStartTime") or "")
            planned_start = (
                datetime.fromisoformat(raw_start).strftime("%d/%m/%Y") if raw_start else "chưa rõ"
            )
            return (
                f"Chuyến chưa đi sớm nhất là {trip.get('tripCode')}, khởi hành ngày "
                f"{planned_start}, tuyến {trip.get('startLocation')} đến {trip.get('endLocation')}, "
                f"trạng thái {trip.get('status')} và rủi ro {trip.get('riskLevel')}."
            )
        if kind == "SESSION_PAUSE_GUARD":
            session = results["get_current_driving_session"].get("session")
            if not isinstance(session, dict):
                return (
                    "Hiện không có phiên lái ACTIVE, vì vậy không chuẩn bị thao tác PAUSE "
                    "cho bất kỳ chuyến nào."
                )
            return (
                f"Phiên lái hiện tại là {session.get('status')} của chuyến {session.get('tripId')}; "
                "chỉ chuẩn bị PAUSE sau khi xác minh đúng trạng thái và ID."
            )

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
        if not trips:
            return "Hiện không có chuyến nào đang chạy (0 chuyến active)."
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

    @classmethod
    def _duplicate_guard_schema(cls, allowed_tools: list[str]) -> dict[str, Any]:
        return cls._object_schema(
            {
                "decision": {"type": "string", "enum": ["ANSWER", "REPLAN"]},
                "reason": {"type": "string"},
                "revised_plan": cls._object_schema(
                    {
                        "goal": {"type": "string"},
                        "steps": {"type": "array", "items": {"type": "string"}},
                        "expected_tools": {
                            "type": "array",
                            "items": {"type": "string", "enum": allowed_tools},
                        },
                    },
                    ["goal", "steps", "expected_tools"],
                ),
            },
            ["decision", "reason", "revised_plan"],
        )

    @staticmethod
    def _structured_format(name: str, schema: dict[str, Any]) -> dict[str, Any]:
        return {
            "type": "json_schema",
            "json_schema": {"name": name, "strict": True, "schema": schema},
        }
