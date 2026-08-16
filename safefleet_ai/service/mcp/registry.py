from __future__ import annotations

import json
import os
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Callable


class McpToolError(RuntimeError):
    pass


@dataclass(frozen=True)
class ToolSpec:
    name: str
    description: str
    input_schema: dict[str, Any]
    roles: frozenset[str]
    handler: Callable[["BackendClient", dict[str, Any]], dict[str, Any]]
    read_only: bool = True
    requires_confirmation: bool = False
    client_side: bool = False
    enabled: bool = True

    def mcp_definition(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "description": self.description,
            "inputSchema": self.input_schema,
            "annotations": {
                "readOnlyHint": self.read_only,
                "destructiveHint": not self.read_only,
                "idempotentHint": self.read_only or self.client_side,
                "openWorldHint": False,
            },
            "_meta": {
                "roles": sorted(self.roles),
                "requiresConfirmation": self.requires_confirmation,
                "clientSide": self.client_side,
                "enabled": self.enabled,
            },
        }


class BackendClient:
    def __init__(self, user_authorization: str):
        self.authorization = user_authorization
        self.base_url = os.getenv("BACKEND_INTERNAL_URL", "http://backend:8080").rstrip("/")

    def identity(self) -> dict[str, Any]:
        identity = self.get("/api/v1/auth/me")
        role = str(identity.get("role") or "").upper()
        if not role:
            raise McpToolError("Không xác định được vai trò của tài khoản đăng nhập")
        identity["role"] = role
        return identity

    def get(self, path: str) -> Any:
        return self._request(path, "GET")

    def _request(self, path: str, method: str) -> Any:
        request = urllib.request.Request(
            f"{self.base_url}{path}",
            headers={"Authorization": self.authorization, "Accept": "application/json"},
            method=method,
        )
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                payload = json.loads(response.read().decode("utf-8"))
            if not payload.get("success", False):
                raise McpToolError(payload.get("message") or "Backend từ chối yêu cầu")
            return payload.get("data")
        except urllib.error.HTTPError as exception:
            try:
                message = json.loads(exception.read().decode("utf-8")).get("message")
            except Exception:
                message = None
            raise McpToolError(message or f"Backend trả về lỗi {exception.code}") from exception
        except (OSError, TimeoutError, json.JSONDecodeError) as exception:
            raise McpToolError("Không thể kết nối backend SafeFleet") from exception


DRIVER = frozenset({"DRIVER"})
ALL_ROLES = frozenset(
    {"ADMIN", "FLEET_MANAGER", "DISPATCHER", "SAFETY_OFFICER", "RESCUE_TEAM", "DRIVER"}
)


def _object(properties: dict[str, Any], required: list[str] | None = None) -> dict[str, Any]:
    return {
        "type": "object",
        "properties": properties,
        "required": required or [],
        "additionalProperties": False,
    }


DATE = {"type": ["string", "null"], "description": "Ngày YYYY-MM-DD hoặc null"}
LIMIT = {"type": "integer", "minimum": 1, "maximum": 50}
LIST_SCHEMA = _object(
    {"start_date": DATE, "end_date": DATE, "limit": LIMIT},
    ["start_date", "end_date", "limit"],
)

STATUS_GROUPS = {
    "list_all_trips": [
        "DRAFT",
        "ASSIGNED",
        "ACCEPTED",
        "IN_PROGRESS",
        "RESTING",
        "COMPLETED",
        "DELAYED",
        "INCIDENT",
        "CANCELLED",
    ],
    "list_completed_trips": ["COMPLETED"],
    "list_upcoming_trips": ["DRAFT", "ASSIGNED", "ACCEPTED", "DELAYED"],
    "list_active_trips": ["IN_PROGRESS", "RESTING", "INCIDENT"],
}


def _list_trips(name: str) -> Callable[[BackendClient, dict[str, Any]], dict[str, Any]]:
    def handler(client: BackendClient, arguments: dict[str, Any]) -> dict[str, Any]:
        limit = max(1, min(50, int(arguments.get("limit") or 20)))
        query: list[tuple[str, str]] = [("statuses", item) for item in STATUS_GROUPS[name]]
        query.append(("limit", str(limit)))
        for source, target in (("start_date", "startDate"), ("end_date", "endDate")):
            if arguments.get(source):
                query.append((target, str(arguments[source])))
        trips = client.get(f"/api/v1/mobile/trips?{urllib.parse.urlencode(query)}") or []
        return {"ok": True, "count": len(trips), "trips": trips}

    return handler


def _get(path: str, key: str) -> Callable[[BackendClient, dict[str, Any]], dict[str, Any]]:
    def handler(client: BackendClient, arguments: dict[str, Any]) -> dict[str, Any]:
        trip_id = int(arguments.get("trip_id") or 0)
        if trip_id <= 0:
            raise McpToolError("trip_id không hợp lệ")
        return {"ok": True, key: client.get(path.format(trip_id=trip_id))}

    return handler


def _simple_get(path: str, key: str) -> Callable[[BackendClient, dict[str, Any]], dict[str, Any]]:
    def handler(client: BackendClient, _arguments: dict[str, Any]) -> dict[str, Any]:
        return {"ok": True, key: client.get(path)}

    return handler


def _monthly(client: BackendClient, arguments: dict[str, Any]) -> dict[str, Any]:
    year, month = int(arguments.get("year") or 0), int(arguments.get("month") or 0)
    if year < 2020 or year > 2100 or month < 1 or month > 12:
        raise McpToolError("Tháng báo cáo không hợp lệ")
    return {
        "ok": True,
        "report": client.get(f"/api/v1/mobile/activity/monthly?month={year:04d}-{month:02d}"),
    }


def _notifications(client: BackendClient, arguments: dict[str, Any]) -> dict[str, Any]:
    unread_only = bool(arguments.get("unread_only"))
    size = max(1, min(100, int(arguments.get("limit") or 20)))
    page = client.get(f"/api/v1/mobile/notifications?page=0&size={size}") or {}
    items = page.get("items") or []
    if unread_only:
        items = [item for item in items if not item.get("readAt") and not item.get("read")]
    return {"ok": True, "count": len(items), "notifications": items}


def _rank_upcoming(client: BackendClient, arguments: dict[str, Any]) -> dict[str, Any]:
    requested_limit = max(1, min(50, int(arguments.get("limit") or 20)))
    fetch_arguments = {**arguments, "limit": 50}
    trips = _list_trips("list_upcoming_trips")(client, fetch_arguments)["trips"]

    def key(item: dict[str, Any]) -> tuple[str, int]:
        planned = str(
            item.get("plannedStartTime")
            or item.get("plannedStartAt")
            or item.get("startTime")
            or "9999-12-31T23:59:59"
        )
        return planned, int(item.get("id") or 0)

    all_ranked = sorted(trips, key=key)
    ranked = all_ranked[:requested_limit]
    return {
        "ok": True,
        "count": len(all_ranked),
        "dateScope": (
            "FILTERED"
            if arguments.get("start_date") or arguments.get("end_date")
            else "ALL_TIME_PENDING"
        ),
        "rankingCriterion": "Thời điểm khởi hành dự kiến sớm nhất, sau đó theo mã chuyến",
        "recommendedTrip": all_ranked[0] if all_ranked else None,
        "rankedTrips": ranked,
    }


def _open_screen(_client: BackendClient, arguments: dict[str, Any]) -> dict[str, Any]:
    destination = str(arguments.get("destination") or "").upper()
    allowed = {
        "HOME",
        "DOCUMENT_SCAN",
        "TRIPS",
        "TRIP_DETAIL",
        "ROUTE",
        "MONTHLY_REPORT",
        "SAFETY",
        "NOTIFICATIONS",
    }
    if destination not in allowed:
        raise McpToolError("Màn hình không được phép")
    trip_id = arguments.get("trip_id")
    if destination == "TRIP_DETAIL" and (not isinstance(trip_id, int) or trip_id <= 0):
        raise McpToolError("Mở chi tiết chuyến cần trip_id")
    return {
        "ok": True,
        "clientAction": {"type": "NAVIGATE", "destination": destination, "tripId": trip_id},
    }


def _prepare_trip_action(client: BackendClient, arguments: dict[str, Any]) -> dict[str, Any]:
    action = str(arguments.get("action") or "").upper()
    trip_id = int(arguments.get("trip_id") or 0)
    if action not in {"ACCEPT", "START", "PAUSE", "RESUME", "COMPLETE"} or trip_id <= 0:
        raise McpToolError("Thao tác chuyến không hợp lệ")
    trip = client.get(f"/api/v1/mobile/trips/{trip_id}")
    trip_status = str(trip.get("status") or "").upper()
    allowed_trip_statuses = {
        "ACCEPT": {"ASSIGNED"},
        "START": {"ASSIGNED", "ACCEPTED"},
        "PAUSE": {"IN_PROGRESS"},
        "RESUME": {"RESTING"},
        "COMPLETE": {"IN_PROGRESS", "RESTING"},
    }
    if trip_status not in allowed_trip_statuses[action]:
        allowed = ", ".join(sorted(allowed_trip_statuses[action]))
        raise McpToolError(
            f"Không thể {action} chuyến {trip_id} khi trạng thái là {trip_status or 'UNKNOWN'}; "
            f"trạng thái hợp lệ: {allowed}"
        )

    if action == "START":
        summary = client.get(f"/api/v1/mobile/trips/{trip_id}/summary")
        if not summary.get("checklistSubmitted"):
            raise McpToolError("Phải hoàn thành checklist trước khi chuẩn bị bắt đầu chuyến")

    if action in {"PAUSE", "RESUME", "COMPLETE"}:
        session = client.get("/api/v1/mobile/driving-sessions/current")
        if not session or int(session.get("tripId") or 0) != trip_id:
            current_trip_id = int((session or {}).get("tripId") or 0)
            raise McpToolError(
                f"Phiên lái hiện tại thuộc chuyến {current_trip_id or 'không xác định'}, "
                f"không phải chuyến {trip_id}"
            )
        session_status = str(session.get("status") or "").upper()
        allowed_session_statuses = {
            "PAUSE": {"ACTIVE"},
            "RESUME": {"PAUSED"},
            "COMPLETE": {"ACTIVE", "PAUSED"},
        }
        if session_status not in allowed_session_statuses[action]:
            allowed = ", ".join(sorted(allowed_session_statuses[action]))
            raise McpToolError(
                f"Phiên lái đang {session_status or 'UNKNOWN'}; thao tác {action} cần {allowed}"
            )

    labels = {
        "ACCEPT": "nhận chuyến",
        "START": "bắt đầu chuyến",
        "PAUSE": "tạm dừng chuyến",
        "RESUME": "tiếp tục chuyến",
        "COMPLETE": "kết thúc chuyến",
    }
    return {
        "ok": True,
        "trip": trip,
        "confirmationRequest": {
            "type": "TRIP_ACTION",
            "action": action,
            "tripId": trip_id,
            "note": arguments.get("note"),
            "prompt": f"Bạn có chắc muốn {labels[action]} #{trip_id}?",
        },
    }


def _rag_placeholder(_client: BackendClient, _arguments: dict[str, Any]) -> dict[str, Any]:
    return {
        "ok": False,
        "code": "RAG_NOT_CONFIGURED",
        "error": "Kho tài liệu nội bộ chưa được cấu hình. Tool đã được dành chỗ nhưng chưa bật.",
    }


TRIP_ID = _object({"trip_id": {"type": "integer", "minimum": 1}}, ["trip_id"])
EMPTY = _object({})

TOOLS: tuple[ToolSpec, ...] = (
    ToolSpec(
        "list_all_trips",
        "Liệt kê tất cả chuyến của tài xế đăng nhập, gồm mọi trạng thái và có thể lọc ngày.",
        LIST_SCHEMA,
        DRIVER,
        _list_trips("list_all_trips"),
    ),
    ToolSpec(
        "list_completed_trips",
        "Liệt kê chuyến đã hoàn thành của tài xế đăng nhập, có thể lọc ngày.",
        LIST_SCHEMA,
        DRIVER,
        _list_trips("list_completed_trips"),
    ),
    ToolSpec(
        "list_upcoming_trips",
        "Liệt kê chuyến chưa khởi hành hoặc đang trì hoãn của tài xế đăng nhập.",
        LIST_SCHEMA,
        DRIVER,
        _list_trips("list_upcoming_trips"),
    ),
    ToolSpec(
        "list_active_trips",
        "Liệt kê chuyến đang chạy, đang nghỉ hoặc có sự cố của tài xế đăng nhập.",
        LIST_SCHEMA,
        DRIVER,
        _list_trips("list_active_trips"),
    ),
    ToolSpec(
        "rank_upcoming_trips",
        "Phân tích và xếp chuyến chưa đi theo thời điểm dự kiến để gợi ý chuyến nên làm sớm nhất.",
        LIST_SCHEMA,
        DRIVER,
        _rank_upcoming,
    ),
    ToolSpec(
        "get_current_assignment",
        "Lấy phân công hiện tại của tài xế đăng nhập.",
        EMPTY,
        DRIVER,
        _simple_get("/api/v1/mobile/current-assignment", "assignment"),
    ),
    ToolSpec(
        "get_trip_detail",
        "Lấy chi tiết một chuyến thuộc tài xế đăng nhập.",
        TRIP_ID,
        DRIVER,
        _get("/api/v1/mobile/trips/{trip_id}", "trip"),
    ),
    ToolSpec(
        "get_trip_summary",
        "Lấy tổng kết vận hành của một chuyến thuộc tài xế đăng nhập.",
        TRIP_ID,
        DRIVER,
        _get("/api/v1/mobile/trips/{trip_id}/summary", "summary"),
    ),
    ToolSpec(
        "get_warehouse_issue",
        "Lấy dữ liệu phiếu xuất kho gắn với chuyến của tài xế đăng nhập.",
        TRIP_ID,
        DRIVER,
        _get("/api/v1/mobile/trips/{trip_id}/warehouse-issue", "warehouseIssue"),
    ),
    ToolSpec(
        "get_monthly_report",
        "Lấy báo cáo tháng của tài xế: chuyến, giờ lái, cảnh báo, đúng giờ và quãng đường.",
        _object(
            {
                "year": {"type": "integer", "minimum": 2020, "maximum": 2100},
                "month": {"type": "integer", "minimum": 1, "maximum": 12},
            },
            ["year", "month"],
        ),
        DRIVER,
        _monthly,
    ),
    ToolSpec(
        "get_safety_summary",
        "Lấy tổng quan an toàn hiện tại của tài xế đăng nhập.",
        EMPTY,
        DRIVER,
        _simple_get("/api/v1/mobile/safety-summary", "safety"),
    ),
    ToolSpec(
        "get_current_driving_session",
        "Lấy phiên lái xe hiện tại nếu có.",
        EMPTY,
        DRIVER,
        _simple_get("/api/v1/mobile/driving-sessions/current", "session"),
    ),
    ToolSpec(
        "list_notifications",
        "Liệt kê thông báo của tài khoản đăng nhập.",
        _object(
            {
                "unread_only": {"type": "boolean"},
                "limit": {"type": "integer", "minimum": 1, "maximum": 100},
            },
            ["unread_only", "limit"],
        ),
        DRIVER,
        _notifications,
    ),
    ToolSpec(
        "open_mobile_screen",
        "Mở một màn hình được phép trên ứng dụng tài xế. Dùng khi người dùng yêu cầu mở/đi tới tính năng.",
        _object(
            {
                "destination": {
                    "type": "string",
                    "enum": [
                        "HOME",
                        "DOCUMENT_SCAN",
                        "TRIPS",
                        "TRIP_DETAIL",
                        "ROUTE",
                        "MONTHLY_REPORT",
                        "SAFETY",
                        "NOTIFICATIONS",
                    ],
                },
                "trip_id": {"type": ["integer", "null"], "minimum": 1},
            },
            ["destination", "trip_id"],
        ),
        DRIVER,
        _open_screen,
        client_side=True,
    ),
    ToolSpec(
        "prepare_trip_action",
        "Chuẩn bị nhận, bắt đầu, tạm dừng, tiếp tục hoặc kết thúc chuyến. Chỉ tạo yêu cầu xác nhận; tuyệt đối không tự thực thi.",
        _object(
            {
                "action": {
                    "type": "string",
                    "enum": ["ACCEPT", "START", "PAUSE", "RESUME", "COMPLETE"],
                },
                "trip_id": {"type": "integer", "minimum": 1},
                "note": {"type": ["string", "null"], "maxLength": 500},
            },
            ["action", "trip_id", "note"],
        ),
        DRIVER,
        _prepare_trip_action,
        read_only=False,
        requires_confirmation=True,
    ),
    ToolSpec(
        "search_internal_documents",
        "Tra cứu tài liệu nội bộ công ty bằng RAG. Hiện là contract dự phòng và chưa được bật.",
        _object(
            {
                "query": {"type": "string", "minLength": 2, "maxLength": 1000},
                "limit": {"type": "integer", "minimum": 1, "maximum": 10},
            },
            ["query", "limit"],
        ),
        ALL_ROLES,
        _rag_placeholder,
        enabled=False,
    ),
)


class ToolRegistry:
    def __init__(self, tools: tuple[ToolSpec, ...] = TOOLS):
        self._tools = {tool.name: tool for tool in tools}

    def list_for(self, authorization: str) -> tuple[dict[str, Any], list[dict[str, Any]]]:
        client = BackendClient(authorization)
        identity = client.identity()
        role = identity["role"]
        tools = [
            tool.mcp_definition()
            for tool in self._tools.values()
            if tool.enabled and role in tool.roles
        ]
        return identity, tools

    def call(self, authorization: str, name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        client = BackendClient(authorization)
        identity = client.identity()
        tool = self._tools.get(name)
        if tool is None or not tool.enabled:
            raise McpToolError(f"Tool không tồn tại hoặc chưa bật: {name}")
        if identity["role"] not in tool.roles:
            raise McpToolError(f"Vai trò {identity['role']} không được gọi tool {name}")
        result = tool.handler(client, arguments)
        return {
            **result,
            "_audit": {
                "tool": name,
                "userId": identity.get("userId"),
                "driverId": identity.get("driverId"),
                "role": identity["role"],
                "at": datetime.now(timezone.utc).isoformat(),
            },
        }


registry = ToolRegistry()
