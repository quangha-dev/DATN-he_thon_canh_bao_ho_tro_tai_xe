from __future__ import annotations

import json
import os
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import date, datetime, time, timezone
from typing import Any, Callable

from service.rag.knowledge_base import KnowledgeBaseError, knowledge_base


class McpToolError(RuntimeError):
    pass


@dataclass(frozen=True)
class ToolSpec:
    name: str
    description: str
    input_schema: dict[str, Any]
    roles: frozenset[str]
    handler: Callable[["BackendClient", dict[str, Any]], dict[str, Any]]
    output_description: str = ""
    read_only: bool = True
    requires_confirmation: bool = False
    client_side: bool = False
    enabled: bool = True

    def mcp_definition(self) -> dict[str, Any]:
        description = self.description
        if self.output_description:
            description += f" Đầu ra gồm: {self.output_description}"
        return {
            "name": self.name,
            "description": description,
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
                "outputDescription": self.output_description,
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

    def post(self, path: str, payload: dict[str, Any]) -> Any:
        return self._request(path, "POST", payload)

    def _request(
        self, path: str, method: str, payload: dict[str, Any] | None = None
    ) -> Any:
        request = urllib.request.Request(
            f"{self.base_url}{path}",
            data=None
            if payload is None
            else json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            headers={
                "Authorization": self.authorization,
                "Accept": "application/json",
                "Content-Type": "application/json",
            },
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
MANAGEMENT = frozenset({"ADMIN", "FLEET_MANAGER", "DISPATCHER", "SAFETY_OFFICER"})
MANAGERS = frozenset({"ADMIN", "FLEET_MANAGER"})
OPERATIONS = frozenset({"ADMIN", "FLEET_MANAGER", "DISPATCHER"})
ALL_ROLES = frozenset(
    {"ADMIN", "FLEET_MANAGER", "DISPATCHER", "SAFETY_OFFICER", "RESCUE_TEAM", "DRIVER"}
)


def _nullable(schema: dict[str, Any]) -> dict[str, Any]:
    result = dict(schema)
    value_type = result.get("type", "string")
    result["type"] = [value_type, "null"] if isinstance(value_type, str) else value_type
    return result


def _enum(values: list[str], description: str, nullable: bool = True) -> dict[str, Any]:
    return {
        "type": ["string", "null"] if nullable else "string",
        "enum": [*values, None] if nullable else values,
        "description": description,
    }


def _query(path: str, parameters: dict[str, Any]) -> str:
    normalized: list[tuple[str, str]] = []
    for key, value in parameters.items():
        if value is None or value == "":
            continue
        if isinstance(value, bool):
            normalized.append((key, str(value).lower()))
        elif isinstance(value, list):
            normalized.extend((key, str(item)) for item in value)
        else:
            normalized.append((key, str(value)))
    return path if not normalized else f"{path}?{urllib.parse.urlencode(normalized)}"


def _page_arguments(arguments: dict[str, Any]) -> tuple[int, int]:
    return (
        max(0, int(arguments.get("page") or 0)),
        max(1, min(100, int(arguments.get("limit") or 20))),
    )


def _page_payload(payload: Any, key: str) -> dict[str, Any]:
    page = payload if isinstance(payload, dict) else {}
    items = page.get("items") or []
    return {
        "ok": True,
        "count": len(items),
        "totalCount": int(page.get("totalElements") or len(items)),
        "page": int(page.get("page") or 0),
        "pageSize": int(page.get("size") or len(items)),
        "totalPages": int(page.get("totalPages") or (1 if items else 0)),
        key: items,
    }


def _management_page(
    path: str,
    result_key: str,
    argument_mapping: dict[str, str],
) -> Callable[[BackendClient, dict[str, Any]], dict[str, Any]]:
    def handler(client: BackendClient, arguments: dict[str, Any]) -> dict[str, Any]:
        page, size = _page_arguments(arguments)
        parameters = {
            target: arguments.get(source) for source, target in argument_mapping.items()
        }
        parameters.update({"page": page, "size": size})
        return _page_payload(client.get(_query(path, parameters)), result_key)

    return handler


def _management_overview(client: BackendClient, _arguments: dict[str, Any]) -> dict[str, Any]:
    return {
        "ok": True,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "summary": client.get("/api/v1/dashboard/summary"),
        "highRiskDrivers": client.get("/api/v1/reports/drivers/high-risk") or [],
    }


def _management_driver_detail(
    client: BackendClient, arguments: dict[str, Any]
) -> dict[str, Any]:
    driver_id = int(arguments.get("driver_id") or 0)
    if driver_id <= 0:
        raise McpToolError("driver_id không hợp lệ")
    return {
        "ok": True,
        "driverReport": client.get(f"/api/v1/reports/drivers/{driver_id}"),
        "drivingTimeToday": client.get(f"/api/v1/drivers/{driver_id}/driving-time-today"),
    }


def _period(arguments: dict[str, Any]) -> tuple[date, date]:
    try:
        start = date.fromisoformat(str(arguments.get("from_date") or ""))
        end = date.fromisoformat(str(arguments.get("to_date") or ""))
    except ValueError as exception:
        raise McpToolError("from_date/to_date phải theo định dạng YYYY-MM-DD") from exception
    if end < start:
        raise McpToolError("to_date không được nhỏ hơn from_date")
    if (end - start).days > 366:
        raise McpToolError("Một báo cáo chỉ hỗ trợ tối đa 367 ngày")
    return start, end


def _management_driver_group_report(
    client: BackendClient, arguments: dict[str, Any]
) -> dict[str, Any]:
    raw_ids = arguments.get("driver_ids") or []
    driver_ids = list(dict.fromkeys(int(value) for value in raw_ids))
    if not driver_ids or any(value <= 0 for value in driver_ids) or len(driver_ids) > 20:
        raise McpToolError("driver_ids phải có từ 1 đến 20 ID tài xế hợp lệ")
    start, end = _period(arguments)
    from_time = datetime.combine(start, time.min).isoformat()
    to_time = datetime.combine(end, time.max).isoformat()
    rows: list[dict[str, Any]] = []
    for driver_id in driver_ids:
        driver = client.get(f"/api/v1/drivers/{driver_id}")
        trips = client.get(
            _query(
                "/api/v1/trips",
                {
                    "driverId": driver_id,
                    "fromDate": start.isoformat(),
                    "toDate": end.isoformat(),
                    "page": 0,
                    "size": 1,
                },
            )
        ) or {}
        alerts = client.get(
            _query(
                "/api/v1/safety-events",
                {
                    "driverId": driver_id,
                    "from": from_time,
                    "to": to_time,
                    "page": 0,
                    "size": 1,
                },
            )
        ) or {}
        rows.append(
            {
                "driver": driver,
                "periodTripCount": int(trips.get("totalElements") or 0),
                "periodSafetyEventCount": int(alerts.get("totalElements") or 0),
            }
        )
    return {
        "ok": True,
        "scope": {"fromDate": start.isoformat(), "toDate": end.isoformat()},
        "count": len(rows),
        "drivers": rows,
    }


def _management_trip_detail(
    client: BackendClient, arguments: dict[str, Any]
) -> dict[str, Any]:
    trip_id = int(arguments.get("trip_id") or 0)
    if trip_id <= 0:
        raise McpToolError("trip_id không hợp lệ")
    return {
        "ok": True,
        "trip": client.get(f"/api/v1/trips/{trip_id}"),
        "timeline": client.get(f"/api/v1/trips/{trip_id}/timeline") or [],
    }


def _management_active_trips(
    client: BackendClient, arguments: dict[str, Any]
) -> dict[str, Any]:
    page, limit = _page_arguments(arguments)
    if page != 0:
        raise McpToolError("management_list_active_trips chỉ hỗ trợ page=0")
    collected: list[dict[str, Any]] = []
    total = 0
    by_status: dict[str, int] = {}
    for status in ("IN_PROGRESS", "RESTING", "INCIDENT"):
        payload = client.get(
            _query(
                "/api/v1/trips",
                {"status": status, "page": 0, "size": limit, "sort": "plannedStartTime,asc"},
            )
        ) or {}
        by_status[status] = int(payload.get("totalElements") or 0)
        total += by_status[status]
        collected.extend(payload.get("items") or [])
    collected.sort(key=lambda item: str(item.get("plannedStartTime") or ""))
    return {
        "ok": True,
        "count": min(len(collected), limit),
        "totalCount": total,
        "byStatus": by_status,
        "trips": collected[:limit],
    }


def _management_trip_period_report(
    client: BackendClient, arguments: dict[str, Any]
) -> dict[str, Any]:
    start, end = _period(arguments)
    common = {"fromDate": start.isoformat(), "toDate": end.isoformat(), "page": 0, "size": 1}
    by_status: dict[str, int] = {}
    statuses = [
        "DRAFT", "ASSIGNED", "ACCEPTED", "IN_PROGRESS", "RESTING",
        "COMPLETED", "DELAYED", "INCIDENT", "REJECTED", "CANCELLED",
    ]
    for status in statuses:
        payload = client.get(_query("/api/v1/trips", {**common, "status": status})) or {}
        by_status[status] = int(payload.get("totalElements") or 0)
    daily = client.get(
        _query(
            "/api/v1/reports/trips/by-day",
            {"from": start.isoformat(), "to": end.isoformat()},
        )
    ) or []
    total = sum(by_status.values())
    completed = by_status["COMPLETED"]
    return {
        "ok": True,
        "scope": {"fromDate": start.isoformat(), "toDate": end.isoformat(), "days": (end - start).days + 1},
        "dataAvailability": {
            "availableMetrics": [
                "totalTrips", "completedTrips", "activeTrips", "completionRate",
                "byStatus", "byDay",
            ],
            "unavailableMetrics": ["totalDistanceKm", "actualDrivingMinutes"],
            "reason": (
                "Trip/report API hiện chưa lưu hoặc chưa tổng hợp ổn định tổng quãng đường "
                "và thời gian lái thực tế theo kỳ; agent phải nói rõ là chưa có dữ liệu, không tự ước tính."
            ),
        },
        "totalTrips": total,
        "completedTrips": completed,
        "activeTrips": by_status["IN_PROGRESS"] + by_status["RESTING"] + by_status["INCIDENT"],
        "completionRate": round(completed * 100 / total, 2) if total else 0.0,
        "byStatus": by_status,
        "byDay": daily,
    }


def _management_operational_risks(
    client: BackendClient, _arguments: dict[str, Any]
) -> dict[str, Any]:
    return {
        "ok": True,
        "maintenanceDue": client.get("/api/v1/maintenance-orders/due-alerts") or [],
        "documentExpiry": client.get("/api/v1/maintenance-orders/document-expiry-alerts") or [],
        "floodSummary": client.get("/api/v1/reports/flood") or {},
        "incidentSummary": client.get("/api/v1/reports/incidents") or {},
    }


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
    if destination == "TRIP_DETAIL" and (
        not isinstance(trip_id, int) or trip_id <= 0
    ):
        raise McpToolError("Mở chi tiết chuyến cần trip_id")
    return {
        "ok": True,
        "clientAction": {
            "type": "NAVIGATE",
            "destination": destination,
            "tripId": trip_id,
        },
    }


def _search_destinations(client: BackendClient, arguments: dict[str, Any]) -> dict[str, Any]:
    query = " ".join(str(arguments.get("query") or "").split()).strip()
    if len(query) < 2:
        raise McpToolError("Tên điểm đến quá ngắn")
    limit = max(1, min(6, int(arguments.get("limit") or 5)))
    destinations = client.get(
        "/api/v1/mobile/locations/autocomplete?"
        + urllib.parse.urlencode({"query": query, "limit": limit})
    ) or []
    return {"ok": True, "query": query, "count": len(destinations), "destinations": destinations}


def _prepare_navigation(client: BackendClient, arguments: dict[str, Any]) -> dict[str, Any]:
    query = " ".join(str(arguments.get("destination_query") or "").split()).strip()
    selected_index = int(arguments.get("selected_index") or 0)
    search = _search_destinations(client, {"query": query, "limit": 6})
    destinations = search["destinations"]
    if not destinations:
        raise McpToolError(f"Không tìm thấy điểm đến phù hợp với '{query}'")
    if selected_index < 0 or selected_index >= len(destinations):
        raise McpToolError("Vị trí lựa chọn không nằm trong danh sách tìm kiếm")
    selected = destinations[selected_index]
    try:
        lat = float(selected["lat"])
        lng = float(selected["lng"])
    except (KeyError, TypeError, ValueError) as exception:
        raise McpToolError("Điểm đến không có tọa độ hợp lệ") from exception
    return {
        "ok": True,
        "selectedDestination": selected,
        "clientAction": {
            "type": "START_NAVIGATION",
            "destination": "ROUTE",
            "destinationName": str(selected.get("name") or query),
            "destinationAddress": str(selected.get("address") or ""),
            "destinationLat": lat,
            "destinationLng": lng,
            "autoStart": True,
        },
    }


def _prepare_flood_report(
    _client: BackendClient, arguments: dict[str, Any]
) -> dict[str, Any]:
    severity = str(arguments.get("severity") or "HIGH").upper()
    if severity not in {"LOW", "MEDIUM", "HIGH", "BLOCKED"}:
        raise McpToolError("Mức ngập phải là LOW, MEDIUM, HIGH hoặc BLOCKED")
    labels = {
        "LOW": "ngập nhẹ",
        "MEDIUM": "ngập vừa",
        "HIGH": "ngập nặng",
        "BLOCKED": "không thể đi qua",
    }
    description = " ".join(str(arguments.get("description") or "").split()).strip() or None
    return {
        "ok": True,
        "confirmationRequest": {
            "type": "FLOOD_REPORT",
            "action": "CREATE",
            "severity": severity,
            "description": description,
            "prompt": f"Xác nhận báo {labels[severity]} tại vị trí GPS hiện tại?",
        },
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


def _rag_search(_client: BackendClient, arguments: dict[str, Any]) -> dict[str, Any]:
    try:
        return knowledge_base.search(
            str(arguments.get("query") or ""),
            int(arguments.get("limit") or 5),
        )
    except KnowledgeBaseError as exception:
        raise McpToolError(str(exception)) from exception


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
        "search_destinations",
        "Tìm điểm đến theo tên hoặc địa chỉ bằng dịch vụ geocoding của SafeFleet. Luôn dùng dữ liệu trả về, không tự đoán tọa độ.",
        _object(
            {
                "query": {"type": "string", "minLength": 2, "maxLength": 300},
                "limit": {"type": "integer", "minimum": 1, "maximum": 6},
            },
            ["query", "limit"],
        ),
        DRIVER,
        _search_destinations,
    ),
    ToolSpec(
        "prepare_navigation",
        "Tìm lại và chọn một kết quả điểm đến đã xác thực, sau đó yêu cầu ứng dụng lập tuyến và bắt đầu dẫn đường.",
        _object(
            {
                "destination_query": {
                    "type": "string",
                    "minLength": 2,
                    "maxLength": 300,
                },
                "selected_index": {"type": "integer", "minimum": 0, "maximum": 5},
            },
            ["destination_query", "selected_index"],
        ),
        DRIVER,
        _prepare_navigation,
        client_side=True,
    ),
    ToolSpec(
        "prepare_flood_report",
        "Chuẩn bị báo điểm ngập tại GPS hiện tại. Ứng dụng chỉ gửi sau khi tài xế xác nhận; không yêu cầu model tự tạo tọa độ.",
        _object(
            {
                "severity": {
                    "type": "string",
                    "enum": ["LOW", "MEDIUM", "HIGH", "BLOCKED"],
                },
                "description": {"type": ["string", "null"], "maxLength": 500},
            },
            ["severity", "description"],
        ),
        DRIVER,
        _prepare_flood_report,
        read_only=False,
        requires_confirmation=True,
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
        "management_get_fleet_overview",
        "Lấy ảnh chụp tổng quan toàn hệ thống tại thời điểm gọi; dùng làm bước đầu cho câu hỏi điều hành tổng quát, không dùng thay báo cáo theo kỳ.",
        EMPTY,
        MANAGEMENT,
        _management_overview,
        "generatedAt; summary với tổng và phân bố trạng thái của xe, tài xế, chuyến, số cảnh báo/sự cố đang mở; highRiskDrivers gồm hồ sơ 10 tài xế điểm an toàn thấp nhất.",
    ),
    ToolSpec(
        "management_search_drivers",
        "Tìm một hoặc một nhóm tài xế trên toàn đội xe. Có thể lọc tên/số điện thoại/email/giấy phép bằng keyword, trạng thái, hạng bằng và khoảng điểm an toàn. Truyền null cho bộ lọc không dùng.",
        _object(
            {
                "keyword": _nullable({"type": "string", "maxLength": 200}),
                "status": _enum(
                    ["AVAILABLE", "DRIVING", "RESTING", "SUSPENDED", "HIGH_RISK", "INACTIVE"],
                    "Trạng thái vận hành của tài xế",
                ),
                "license_class": _nullable({"type": "string", "maxLength": 20}),
                "min_safety_score": _nullable({"type": "integer", "minimum": 0, "maximum": 100}),
                "max_safety_score": _nullable({"type": "integer", "minimum": 0, "maximum": 100}),
                "page": {"type": "integer", "minimum": 0},
                "limit": {"type": "integer", "minimum": 1, "maximum": 100},
            },
            ["keyword", "status", "license_class", "min_safety_score", "max_safety_score", "page", "limit"],
        ),
        MANAGEMENT,
        _management_page(
            "/api/v1/drivers",
            "drivers",
            {
                "keyword": "keyword", "status": "status", "license_class": "licenseClass",
                "min_safety_score": "minSafetyScore", "max_safety_score": "maxSafetyScore",
            },
        ),
        "count/totalCount/page/totalPages; drivers với ID, họ tên, liên hệ, giấy phép và hạn, trạng thái, xe hiện tại, safetyScore, phút lái hôm nay/liên tục, tổng chuyến và tổng cảnh báo.",
    ),
    ToolSpec(
        "management_get_driver_report",
        "Lấy hồ sơ và báo cáo chi tiết của đúng một tài xế theo driver_id; dùng sau management_search_drivers khi người dùng chỉ nêu tên.",
        _object({"driver_id": {"type": "integer", "minimum": 1}}, ["driver_id"]),
        frozenset({"ADMIN", "FLEET_MANAGER", "SAFETY_OFFICER"}),
        _management_driver_detail,
        "driverReport gồm hồ sơ, totalTrips, totalSafetyEvents, safetyScore; drivingTimeToday gồm thời gian lái/nghỉ còn lại trong ngày.",
    ),
    ToolSpec(
        "management_compare_driver_group",
        "Đối chiếu từ 1 đến 20 tài xế trong một khoảng ngày bao gồm cả hai đầu mốc. ID phải lấy từ management_search_drivers, không tự đoán. Dùng cho câu hỏi nhóm, xếp ưu tiên hoặc so sánh tải công việc/an toàn.",
        _object(
            {
                "driver_ids": {"type": "array", "items": {"type": "integer", "minimum": 1}, "minItems": 1, "maxItems": 20},
                "from_date": {"type": "string", "description": "Ngày đầu kỳ YYYY-MM-DD"},
                "to_date": {"type": "string", "description": "Ngày cuối kỳ YYYY-MM-DD"},
            },
            ["driver_ids", "from_date", "to_date"],
        ),
        MANAGEMENT,
        _management_driver_group_report,
        "scope; mỗi phần tử drivers gồm toàn bộ hồ sơ tài xế, periodTripCount và periodSafetyEventCount đúng trong kỳ để agent tự so sánh có căn cứ.",
    ),
    ToolSpec(
        "management_search_trips",
        "Tra cứu chuyến của toàn đội xe theo trạng thái, xe, tài xế và khoảng ngày kế hoạch. Dùng cho danh sách chuyến hôm nay/tháng/năm, lịch sử hoặc truy vấn kết hợp; truyền null cho bộ lọc không dùng.",
        _object(
            {
                "status": _enum(
                    ["DRAFT", "ASSIGNED", "ACCEPTED", "IN_PROGRESS", "RESTING", "COMPLETED", "DELAYED", "INCIDENT", "REJECTED", "CANCELLED"],
                    "Trạng thái vòng đời chuyến",
                ),
                "vehicle_id": _nullable({"type": "integer", "minimum": 1}),
                "driver_id": _nullable({"type": "integer", "minimum": 1}),
                "from_date": DATE,
                "to_date": DATE,
                "page": {"type": "integer", "minimum": 0},
                "limit": {"type": "integer", "minimum": 1, "maximum": 100},
            },
            ["status", "vehicle_id", "driver_id", "from_date", "to_date", "page", "limit"],
        ),
        MANAGEMENT,
        _management_page(
            "/api/v1/trips",
            "trips",
            {"status": "status", "vehicle_id": "vehicleId", "driver_id": "driverId", "from_date": "fromDate", "to_date": "toDate"},
        ),
        "count/totalCount và trips với mã, tài xế, xe, điểm đi/đến, tọa độ, lịch dự kiến/thực tế, trạng thái, tiến độ và riskLevel.",
    ),
    ToolSpec(
        "management_get_trip_detail",
        "Lấy đầy đủ một chuyến và toàn bộ timeline thay đổi trạng thái. Dùng ID thật từ kết quả tìm chuyến khi câu hỏi cần nguyên nhân, diễn biến hoặc mốc thực tế.",
        _object({"trip_id": {"type": "integer", "minimum": 1}}, ["trip_id"]),
        MANAGEMENT,
        _management_trip_detail,
        "trip có tuyến, tài xế, xe, thời gian, tiến độ, rủi ro; timeline có trạng thái cũ/mới, người thao tác, thời điểm và ghi chú.",
    ),
    ToolSpec(
        "management_list_active_trips",
        "Lấy nhanh mọi chuyến toàn đội đang IN_PROGRESS, RESTING hoặc INCIDENT ở thời điểm hiện tại. Không dùng bộ lọc ngày vì đây là trạng thái hiện hành.",
        _object(
            {"page": {"type": "integer", "enum": [0]}, "limit": {"type": "integer", "minimum": 1, "maximum": 100}},
            ["page", "limit"],
        ),
        MANAGEMENT,
        _management_active_trips,
        "totalCount, byStatus và trips đã sắp theo giờ khởi hành; mỗi chuyến có tài xế, xe, tuyến, tiến độ và mức rủi ro.",
    ),
    ToolSpec(
        "management_get_trip_period_report",
        "Lập báo cáo chuyến cho một ngày, tháng, năm hoặc khoảng tùy chọn bằng from_date/to_date bao gồm cả hai đầu mốc. Agent phải tự quy đổi yêu cầu ngày/tháng/năm thành mốc ISO chính xác.",
        _object(
            {"from_date": {"type": "string", "description": "Ngày đầu kỳ YYYY-MM-DD"}, "to_date": {"type": "string", "description": "Ngày cuối kỳ YYYY-MM-DD"}},
            ["from_date", "to_date"],
        ),
        OPERATIONS,
        _management_trip_period_report,
        "scope và số ngày; dataAvailability chỉ rõ metric có/thiếu; totalTrips, completedTrips, activeTrips, completionRate; byStatus đủ 10 trạng thái; byDay là chuỗi số chuyến từng ngày, kể cả ngày bằng 0. Không tự ước tính metric nằm trong unavailableMetrics.",
    ),
    ToolSpec(
        "management_search_safety_events",
        "Tra cứu cảnh báo AI/an toàn toàn hệ thống theo loại, mức nghiêm trọng, trạng thái xử lý, xe, tài xế và thời gian tạo. from/to dùng ISO datetime; truyền null cho bộ lọc không dùng.",
        _object(
            {
                "event_type": _enum(["DROWSINESS", "PHONE_USAGE", "DISTRACTION", "SPEEDING", "OVER_DRIVING_TIME", "ROUTE_DEVIATION", "ABNORMAL_STOP", "GPS_LOST", "FLOOD_RISK"], "Loại cảnh báo"),
                "severity": _enum(["LOW", "MEDIUM", "HIGH", "CRITICAL"], "Mức nghiêm trọng"),
                "status": _enum(["NEW", "ACKNOWLEDGED", "PROCESSING", "RESOLVED", "DISMISSED"], "Trạng thái xử lý"),
                "vehicle_id": _nullable({"type": "integer", "minimum": 1}),
                "driver_id": _nullable({"type": "integer", "minimum": 1}),
                "from_time": _nullable({"type": "string", "description": "ISO datetime"}),
                "to_time": _nullable({"type": "string", "description": "ISO datetime"}),
                "page": {"type": "integer", "minimum": 0},
                "limit": {"type": "integer", "minimum": 1, "maximum": 100},
            },
            ["event_type", "severity", "status", "vehicle_id", "driver_id", "from_time", "to_time", "page", "limit"],
        ),
        MANAGEMENT,
        _management_page(
            "/api/v1/safety-events", "safetyEvents",
            {"event_type": "eventType", "severity": "severity", "status": "status", "vehicle_id": "vehicleId", "driver_id": "driverId", "from_time": "from", "to_time": "to"},
        ),
        "count/totalCount và safetyEvents với loại, độ nghiêm trọng, tài xế, xe, chuyến, GPS, tốc độ, confidence, bằng chứng, trạng thái/người xử lý và thời điểm.",
    ),
    ToolSpec(
        "management_search_incidents",
        "Tra cứu SOS/sự cố toàn hệ thống theo loại, độ nghiêm trọng, trạng thái, xe hoặc tài xế. Truyền null cho bộ lọc không dùng.",
        _object(
            {
                "type": _enum(["SOS", "ACCIDENT", "VEHICLE_BREAKDOWN", "DRIVER_UNRESPONSIVE", "FLOOD_STUCK", "GPS_LOST", "MANUAL"], "Loại sự cố"),
                "severity": _enum(["LOW", "MEDIUM", "HIGH", "CRITICAL"], "Mức nghiêm trọng"),
                "status": _enum(["OPEN", "ACCEPTED", "PROCESSING", "ESCALATED", "RESOLVED", "CLOSED", "CANCELLED"], "Trạng thái sự cố"),
                "vehicle_id": _nullable({"type": "integer", "minimum": 1}),
                "driver_id": _nullable({"type": "integer", "minimum": 1}),
                "page": {"type": "integer", "minimum": 0},
                "limit": {"type": "integer", "minimum": 1, "maximum": 100},
            },
            ["type", "severity", "status", "vehicle_id", "driver_id", "page", "limit"],
        ),
        MANAGEMENT,
        _management_page(
            "/api/v1/incidents", "incidents",
            {"type": "type", "severity": "severity", "status": "status", "vehicle_id": "vehicleId", "driver_id": "driverId"},
        ),
        "count/totalCount và incidents với mã, loại, mức độ, tài xế/xe/chuyến, GPS, mô tả, trạng thái, người phụ trách và các mốc tiếp nhận/giải quyết.",
    ),
    ToolSpec(
        "management_search_vehicles",
        "Tìm phương tiện toàn đội theo biển số, loại xe, trạng thái và trạng thái GPS. Truyền null cho bộ lọc không dùng.",
        _object(
            {
                "plate_number": _nullable({"type": "string", "maxLength": 30}),
                "vehicle_type": _enum(["TRUCK", "VAN", "BUS", "CAR", "PICKUP", "MOTORBIKE"], "Loại phương tiện"),
                "status": _enum(["AVAILABLE", "RUNNING", "RESTING", "MAINTENANCE", "OFFLINE", "INACTIVE"], "Trạng thái phương tiện"),
                "gps_online": _nullable({"type": "boolean"}),
                "page": {"type": "integer", "minimum": 0},
                "limit": {"type": "integer", "minimum": 1, "maximum": 100},
            },
            ["plate_number", "vehicle_type", "status", "gps_online", "page", "limit"],
        ),
        MANAGEMENT,
        _management_page(
            "/api/v1/vehicles", "vehicles",
            {"plate_number": "plateNumber", "vehicle_type": "vehicleType", "status": "status", "gps_online": "gpsOnline"},
        ),
        "count/totalCount và vehicles với biển số, đặc tính/kích thước/tải trọng, nhiên liệu, hàng nguy hiểm, trạng thái, tài xế và thiết bị hiện tại, hạn đăng kiểm/bảo hiểm, GPS/tốc độ cuối.",
    ),
    ToolSpec(
        "management_search_accounts",
        "Tìm tài khoản nội bộ theo username, họ tên, email hoặc số điện thoại. Chỉ ADMIN/FLEET_MANAGER được sử dụng; đây là tool đọc và không trả mật khẩu/token.",
        _object(
            {"keyword": _nullable({"type": "string", "maxLength": 200}), "page": {"type": "integer", "minimum": 0}, "limit": {"type": "integer", "minimum": 1, "maximum": 100}},
            ["keyword", "page", "limit"],
        ),
        MANAGERS,
        _management_page("/api/v1/accounts", "accounts", {"keyword": "keyword"}),
        "count/totalCount và accounts với ID, username, họ tên, liên hệ, vai trò, trạng thái, lần đăng nhập và thời điểm tạo/cập nhật; không có bí mật xác thực.",
    ),
    ToolSpec(
        "management_search_maintenance_orders",
        "Tra cứu lệnh bảo trì theo xe, trạng thái và ngày dự kiến. Truyền null cho bộ lọc không dùng.",
        _object(
            {
                "vehicle_id": _nullable({"type": "integer", "minimum": 1}),
                "status": _enum(["OPEN", "SCHEDULED", "IN_PROGRESS", "COMPLETED", "CANCELLED"], "Trạng thái bảo trì"),
                "from_date": DATE,
                "to_date": DATE,
                "page": {"type": "integer", "minimum": 0},
                "limit": {"type": "integer", "minimum": 1, "maximum": 100},
            },
            ["vehicle_id", "status", "from_date", "to_date", "page", "limit"],
        ),
        OPERATIONS,
        _management_page(
            "/api/v1/maintenance-orders", "maintenanceOrders",
            {"vehicle_id": "vehicleId", "status": "status", "from_date": "from", "to_date": "to"},
        ),
        "count/totalCount và maintenanceOrders với xe, nội dung/lý do, lịch, trạng thái, chi phí, nhà cung cấp và mốc hoàn tất.",
    ),
    ToolSpec(
        "management_search_devices",
        "Tra cứu thiết bị GPS/camera/điện thoại/cảm biến theo loại, trạng thái và xe đang gắn. Truyền null cho bộ lọc không dùng.",
        _object(
            {
                "type": _enum(["GPS_TRACKER", "CABIN_CAMERA", "DASH_CAMERA", "DRIVER_PHONE", "IOT_FLOOD_SENSOR"], "Loại thiết bị"),
                "status": _enum(["ONLINE", "OFFLINE", "MAINTENANCE", "INACTIVE"], "Trạng thái kết nối"),
                "vehicle_id": _nullable({"type": "integer", "minimum": 1}),
                "page": {"type": "integer", "minimum": 0},
                "limit": {"type": "integer", "minimum": 1, "maximum": 100},
            },
            ["type", "status", "vehicle_id", "page", "limit"],
        ),
        OPERATIONS,
        _management_page(
            "/api/v1/devices", "devices",
            {"type": "type", "status": "status", "vehicle_id": "vehicleId"},
        ),
        "count/totalCount và devices với mã/serial, loại, trạng thái, xe gắn, firmware, IP, pin, tín hiệu và lần cuối online.",
    ),
    ToolSpec(
        "management_get_operational_risks",
        "Tổng hợp các rủi ro cần xử lý: bảo trì đến hạn, giấy tờ xe sắp hết hạn, phân bố điểm ngập và phân bố sự cố. Dùng cho câu hỏi ưu tiên vận hành, không thay chi tiết từng bản ghi.",
        EMPTY,
        OPERATIONS,
        _management_operational_risks,
        "maintenanceDue, documentExpiry, floodSummary theo severity/status và incidentSummary theo type/status.",
    ),
    ToolSpec(
        "management_get_system_settings",
        "Đọc toàn bộ cấu hình nghiệp vụ hiện hành để giải thích ngưỡng/chính sách kỹ thuật của hệ thống; không dùng tool này để sửa cấu hình hoặc lấy API key bí mật.",
        EMPTY,
        MANAGERS,
        _simple_get("/api/v1/settings", "settings"),
        "settings gồm key, group, value, valueType, description và updatedAt; backend không trả bí mật OpenAI đã mã hóa.",
    ),
    ToolSpec(
        "search_internal_documents",
        "Tra cứu ngữ nghĩa các điều khoản nội bộ bằng RAG. Kết quả có mã văn bản, điều, khoản và điểm liên quan; câu trả lời bắt buộc trích dẫn nguồn.",
        _object(
            {
                "query": {"type": "string", "minLength": 2, "maxLength": 1000},
                "limit": {"type": "integer", "minimum": 1, "maximum": 10},
            },
            ["query", "limit"],
        ),
        ALL_ROLES,
        _rag_search,
        output_description=(
            "query/count/embeddingModel; citations gồm documentKey, title, version, "
            "effectiveDate, chunkKey, headingPath (Điều/Khoản), nguyên văn content và score; "
            "answerPolicy bắt buộc trả lời có trích dẫn hoặc nói thiếu căn cứ."
        ),
        enabled=knowledge_base.enabled,
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
