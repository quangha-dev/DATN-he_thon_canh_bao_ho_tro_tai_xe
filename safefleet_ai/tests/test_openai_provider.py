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


def test_usage_tracking_aggregates_tokens_and_optional_cost(monkeypatch) -> None:
    monkeypatch.setenv("OPENAI_INPUT_COST_PER_MILLION_USD", "0.15")
    monkeypatch.setenv("OPENAI_OUTPUT_COST_PER_MILLION_USD", "0.60")
    client = OpenAiClient()
    token = client.begin_usage_tracking()

    client._record_usage(
        {"usage": {"prompt_tokens": 1_000, "completion_tokens": 200, "total_tokens": 1_200}}
    )
    client._record_usage(
        {"usage": {"input_tokens": 500, "output_tokens": 100, "total_tokens": 600}}
    )
    usage = client.end_usage_tracking(token)

    assert usage["model_calls"] == 2
    assert usage["input_tokens"] == 1_500
    assert usage["output_tokens"] == 300
    assert usage["total_tokens"] == 1_800
    assert usage["estimated_cost_usd"] == 0.000405
