from __future__ import annotations

import json
from typing import Any

from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse

from service.core.security import require_internal_service, require_user_authorization
from service.mcp.registry import McpToolError, registry


router = APIRouter(tags=["mcp"], dependencies=[Depends(require_internal_service)])


@router.post("/mcp")
def mcp_endpoint(
    request: dict[str, Any],
    authorization: str = Depends(require_user_authorization),
) -> JSONResponse:
    request_id = request.get("id")
    method = request.get("method")
    try:
        if method == "initialize":
            result = {
                "protocolVersion": "2025-03-26",
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": "safefleet-mcp", "version": "1.0.0"},
            }
        elif method == "tools/list":
            identity, tools = registry.list_for(authorization)
            result = {"tools": tools, "_meta": {"identity": identity}}
        elif method == "tools/call":
            params = request.get("params") or {}
            structured = registry.call(
                authorization,
                str(params.get("name") or ""),
                params.get("arguments") if isinstance(params.get("arguments"), dict) else {},
            )
            result = {
                "content": [
                    {
                        "type": "text",
                        "text": json.dumps(structured, ensure_ascii=False, default=str),
                    }
                ],
                "structuredContent": structured,
                "isError": not bool(structured.get("ok")),
            }
        else:
            return _error(request_id, -32601, f"MCP method không hỗ trợ: {method}")
        return JSONResponse({"jsonrpc": "2.0", "id": request_id, "result": result})
    except McpToolError as exception:
        return _error(request_id, -32001, str(exception))
    except (TypeError, ValueError) as exception:
        return _error(request_id, -32602, str(exception))


def _error(request_id: Any, code: int, message: str) -> JSONResponse:
    return JSONResponse(
        {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}
    )
