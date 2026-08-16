from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
import uuid
from typing import Any

from service.mcp.registry import McpToolError


class SafeFleetMcpClient:
    """Streamable-HTTP JSON-RPC client used by the agent runtime."""

    def __init__(self, user_authorization: str):
        self._authorization = user_authorization
        self._url = os.getenv("MCP_INTERNAL_URL", "http://127.0.0.1:8000/mcp")
        self._service_token = os.getenv("AI_INTERNAL_TOKEN", "")

    def list_tools(self) -> list[dict[str, Any]]:
        return list(self._call("tools/list", {}).get("tools") or [])

    def execute(self, name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        result = self._call("tools/call", {"name": name, "arguments": arguments})
        structured = result.get("structuredContent")
        if isinstance(structured, dict):
            return structured
        raise McpToolError("MCP server không trả structuredContent")

    def _call(self, method: str, params: dict[str, Any]) -> dict[str, Any]:
        payload = {
            "jsonrpc": "2.0",
            "id": str(uuid.uuid4()),
            "method": method,
            "params": params,
        }
        request = urllib.request.Request(
            self._url,
            data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json, text/event-stream",
                "X-SafeFleet-Service-Token": self._service_token,
                "X-User-Authorization": self._authorization,
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                value = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exception:
            raise McpToolError(f"MCP server trả về lỗi {exception.code}") from exception
        except (OSError, TimeoutError, json.JSONDecodeError) as exception:
            raise McpToolError("Không thể kết nối MCP server SafeFleet") from exception
        if value.get("error"):
            raise McpToolError(str(value["error"].get("message") or "MCP tool thất bại"))
        return value.get("result") or {}


def openai_tool_definitions(mcp_tools: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "type": "function",
            "function": {
                "name": tool["name"],
                "description": tool.get("description") or "",
                "strict": True,
                "parameters": tool.get("inputSchema")
                or {"type": "object", "properties": {}, "required": []},
            },
        }
        for tool in mcp_tools
    ]
