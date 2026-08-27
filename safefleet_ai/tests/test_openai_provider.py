from __future__ import annotations

import io
import urllib.error
from types import SimpleNamespace

from service.providers.openai import OpenAiClient


def test_chat_disables_parallel_tool_calls(monkeypatch) -> None:
    captured = {}
    client = OpenAiClient()

    def fake_request(_configuration, _path, _method, payload):
        captured.update(payload)
        return {"choices": [{"message": {"content": "ok"}}]}

    monkeypatch.setattr(client, "_request", fake_request)
    configuration = SimpleNamespace(
        api_key="sk-test-key",
        model="gpt-4o-mini",
        base_url="https://api.openai.com/v1",
    )
    client.chat(
        configuration,
        [{"role": "user", "content": "test"}],
        tools=[{"type": "function", "function": {"name": "tool", "parameters": {}}}],
    )

    assert captured["parallel_tool_calls"] is False


def test_http_error_detail_extracts_message_without_echoing_request() -> None:
    error = urllib.error.HTTPError(
        "https://api.openai.com/v1/chat/completions",
        400,
        "Bad Request",
        {},
        io.BytesIO(b'{"error":{"message":"Missing tool response for call abc"}}'),
    )

    assert OpenAiClient._http_error_detail(error) == "Missing tool response for call abc"
