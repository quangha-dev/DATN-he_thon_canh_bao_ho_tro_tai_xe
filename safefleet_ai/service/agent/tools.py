from __future__ import annotations

import json
import os
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


ALLOWED_TOOLS = (
    "list_completed_trips",
    "list_upcoming_trips",
    "list_active_trips",
    "get_trip_detail",
    "get_monthly_report",
)

_STATUS_GROUPS = {
    "list_completed_trips": ["COMPLETED"],
    "list_upcoming_trips": ["DRAFT", "ASSIGNED", "ACCEPTED", "DELAYED"],
    "list_active_trips": ["IN_PROGRESS", "RESTING", "INCIDENT"],
}


class ToolError(RuntimeError):
    pass


class SafeFleetToolExecutor:
    def __init__(self, user_authorization: str):
        self._authorization = user_authorization
        self._base_url = os.getenv("BACKEND_INTERNAL_URL", "http://backend:8080").rstrip("/")

    def execute(self, name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        if name in _STATUS_GROUPS:
            return self._list_trips(name, arguments)
        if name == "get_trip_detail":
            trip_id = int(arguments.get("trip_id") or 0)
            if trip_id <= 0:
                raise ToolError("trip_id không hợp lệ")
            return {"ok": True, "trip": self._get(f"/api/v1/mobile/trips/{trip_id}")}
        if name == "get_monthly_report":
            year = int(arguments.get("year") or 0)
            month = int(arguments.get("month") or 0)
            if year < 2020 or year > 2100 or month < 1 or month > 12:
                raise ToolError("Tháng báo cáo không hợp lệ")
            report = self._get(f"/api/v1/mobile/activity/monthly?month={year:04d}-{month:02d}")
            return {"ok": True, "report": report}
        raise ToolError(f"Tool không được phép: {name}")

    def _list_trips(self, name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        limit = max(1, min(50, int(arguments.get("limit") or 20)))
        query: list[tuple[str, str]] = [("statuses", status) for status in _STATUS_GROUPS[name]]
        query.append(("limit", str(limit)))
        for source, target in (("start_date", "startDate"), ("end_date", "endDate")):
            value = arguments.get(source)
            if value:
                query.append((target, str(value)))
        trips = self._get(f"/api/v1/mobile/trips?{urllib.parse.urlencode(query)}")
        return {
            "ok": True,
            "category": name.removeprefix("list_").removesuffix("_trips").upper(),
            "count": len(trips),
            "limitedTo": limit,
            "trips": trips,
        }

    def _get(self, path: str) -> Any:
        request = urllib.request.Request(
            f"{self._base_url}{path}",
            headers={"Authorization": self._authorization, "Accept": "application/json"},
            method="GET",
        )
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                payload = json.loads(response.read().decode("utf-8"))
            if not payload.get("success", False):
                raise ToolError(payload.get("message") or "Backend từ chối yêu cầu dữ liệu")
            return payload.get("data")
        except urllib.error.HTTPError as exception:
            try:
                message = json.loads(exception.read().decode("utf-8")).get("message")
            except Exception:
                message = None
            raise ToolError(message or f"Backend trả về lỗi {exception.code}") from exception
        except (OSError, TimeoutError, json.JSONDecodeError) as exception:
            raise ToolError("Không thể đọc dữ liệu từ backend SafeFleet") from exception


def tool_definitions() -> list[dict[str, Any]]:
    nullable_date = {"type": ["string", "null"], "description": "YYYY-MM-DD; null nếu không giới hạn"}
    list_schema = _object_schema(
        {
            "start_date": nullable_date,
            "end_date": nullable_date,
            "limit": {"type": "integer", "minimum": 1, "maximum": 50},
        },
        ["start_date", "end_date", "limit"],
    )
    return [
        _function("list_completed_trips", "Danh sách chuyến đã hoàn thành, lọc ngày tùy chọn.", list_schema),
        _function("list_upcoming_trips", "Danh sách chuyến chưa khởi hành hoặc đang trì hoãn.", list_schema),
        _function("list_active_trips", "Danh sách chuyến đang đi, đang nghỉ hoặc có sự cố.", list_schema),
        _function(
            "get_trip_detail",
            "Chi tiết một chuyến thuộc tài xế hiện tại.",
            _object_schema({"trip_id": {"type": "integer", "minimum": 1}}, ["trip_id"]),
        ),
        _function(
            "get_monthly_report",
            "Báo cáo hoạt động tháng: chuyến, giờ lái, cảnh báo, đúng giờ, quãng đường.",
            _object_schema(
                {
                    "year": {"type": "integer", "minimum": 2020, "maximum": 2100},
                    "month": {"type": "integer", "minimum": 1, "maximum": 12},
                },
                ["year", "month"],
            ),
        ),
    ]


def _function(name: str, description: str, parameters: dict[str, Any]) -> dict[str, Any]:
    return {"type": "function", "function": {"name": name, "description": description, "strict": True, "parameters": parameters}}


def _object_schema(properties: dict[str, Any], required: list[str]) -> dict[str, Any]:
    return {"type": "object", "properties": properties, "required": required, "additionalProperties": False}
