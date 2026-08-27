from __future__ import annotations

import json
import time
import urllib.error
import urllib.request
from typing import Any

from service.agent.models import RuntimeConfiguration


class OpenAiError(RuntimeError):
    pass


class OpenAiClient:
    def response_text(
        self,
        configuration: RuntimeConfiguration,
        instructions: str,
        input_value: str | list[dict[str, Any]],
        max_output_tokens: int = 500,
    ) -> str:
        self._require_key(configuration)
        payload = {
            "model": configuration.model,
            "store": False,
            "instructions": instructions,
            "input": input_value,
            "max_output_tokens": max_output_tokens,
        }
        return self._extract_response_text(
            self._request(configuration, "/responses", "POST", payload)
        ).strip()

    def structured_response(
        self,
        configuration: RuntimeConfiguration,
        instructions: str,
        input_text: str,
        schema_name: str,
        schema: dict[str, Any],
        max_output_tokens: int,
    ) -> dict[str, Any]:
        self._require_key(configuration)
        payload = {
            "model": configuration.model,
            "store": False,
            "instructions": instructions,
            "input": input_text,
            "text": {
                "format": {
                    "type": "json_schema",
                    "name": schema_name,
                    "strict": True,
                    "schema": schema,
                }
            },
            "max_output_tokens": max_output_tokens,
        }
        text = self._extract_response_text(
            self._request(configuration, "/responses", "POST", payload)
        )
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError as exception:
            raise OpenAiError("OpenAI trả về JSON không hợp lệ") from exception
        if not isinstance(parsed, dict):
            raise OpenAiError("OpenAI trả về JSON không hợp lệ")
        return parsed

    def chat(
        self,
        configuration: RuntimeConfiguration,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]] | None = None,
        tool_choice: Any = None,
        response_format: dict[str, Any] | None = None,
        max_tokens: int = 900,
    ) -> dict[str, Any]:
        self._require_key(configuration)
        payload: dict[str, Any] = {
            "model": configuration.model,
            "messages": messages,
            "temperature": 0.1,
            "max_tokens": max_tokens,
        }
        if tools:
            # The orchestrator evaluates tool results sequentially because later calls may
            # depend on IDs returned by earlier calls.  Disabling parallel calls also keeps
            # the Chat Completions history valid: every assistant tool_call_id is answered
            # before the next model turn.
            payload.update(tools=tools, parallel_tool_calls=False, tool_choice=tool_choice or "auto")
        elif tool_choice is not None:
            payload["tool_choice"] = tool_choice
        if response_format:
            payload["response_format"] = response_format
        response = self._request(configuration, "/chat/completions", "POST", payload)
        try:
            return response["choices"][0]["message"]
        except (KeyError, IndexError, TypeError) as exception:
            raise OpenAiError("OpenAI không trả về nội dung agent") from exception

    def test_connection(self, configuration: RuntimeConfiguration) -> None:
        self._require_key(configuration)
        self._request(configuration, f"/models/{configuration.model}", "GET", None)

    @staticmethod
    def _extract_response_text(payload: dict[str, Any]) -> str:
        direct = payload.get("output_text")
        if isinstance(direct, str) and direct.strip():
            return direct
        for output in payload.get("output", []):
            if not isinstance(output, dict):
                continue
            for content in output.get("content", []):
                if isinstance(content, dict) and content.get("type") == "output_text":
                    text = content.get("text")
                    if isinstance(text, str) and text.strip():
                        return text
        raise OpenAiError("OpenAI không trả về nội dung")

    def _request(
        self,
        configuration: RuntimeConfiguration,
        path: str,
        method: str,
        payload: dict[str, Any] | None,
    ) -> dict[str, Any]:
        for attempt in range(3):
            request = urllib.request.Request(
                f"{configuration.base_url.rstrip('/')}{path}",
                data=None
                if payload is None
                else json.dumps(payload, ensure_ascii=False).encode("utf-8"),
                headers={
                    "Authorization": f"Bearer {configuration.api_key}",
                    "Content-Type": "application/json",
                },
                method=method,
            )
            try:
                with urllib.request.urlopen(request, timeout=35) as response:
                    content = response.read()
                return json.loads(content.decode("utf-8")) if content else {}
            except urllib.error.HTTPError as exception:
                detail = self._http_error_detail(exception)
                retryable = exception.code == 429 or 500 <= exception.code < 600
                if retryable and attempt < 2:
                    time.sleep(0.5 * (2**attempt))
                    continue
                if exception.code in (401, 403):
                    message = "OpenAI API key không hợp lệ hoặc không có quyền dùng gpt-4o-mini"
                elif exception.code == 429:
                    message = "OpenAI đang giới hạn lượt gọi hoặc tài khoản đã hết hạn mức"
                else:
                    message = f"OpenAI trả về lỗi {exception.code}: {detail}"
                raise OpenAiError(message) from exception
            except (OSError, TimeoutError, json.JSONDecodeError) as exception:
                if attempt < 2:
                    time.sleep(0.5 * (2**attempt))
                    continue
                raise OpenAiError("Không thể kết nối OpenAI") from exception
        raise OpenAiError("Không thể kết nối OpenAI")

    @staticmethod
    def _http_error_detail(exception: urllib.error.HTTPError) -> str:
        try:
            raw = exception.read().decode("utf-8", errors="replace")
            payload = json.loads(raw)
            message = str((payload.get("error") or {}).get("message") or raw)
        except (OSError, json.JSONDecodeError, AttributeError):
            message = "yêu cầu không hợp lệ"
        # Không đưa request, API key hoặc payload người dùng vào log/response lỗi.
        return " ".join(message.split())[:500]

    @staticmethod
    def structured_content(message: dict[str, Any]) -> dict[str, Any]:
        content = (message.get("content") or "").strip()
        if not content:
            raise OpenAiError("OpenAI không trả về JSON theo yêu cầu")
        try:
            parsed = json.loads(content)
        except json.JSONDecodeError as exception:
            raise OpenAiError("OpenAI trả về JSON không hợp lệ") from exception
        if not isinstance(parsed, dict):
            raise OpenAiError("OpenAI trả về JSON không hợp lệ")
        return parsed

    @staticmethod
    def _require_key(configuration: RuntimeConfiguration) -> None:
        if not configuration.api_key:
            raise OpenAiError("OpenAI API key chưa được cấu hình trên web quản lý")
