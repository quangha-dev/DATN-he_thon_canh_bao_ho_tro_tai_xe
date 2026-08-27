from __future__ import annotations

import os

from fastapi.testclient import TestClient

os.environ.setdefault("AI_INTERNAL_TOKEN", "test-internal-token")

from service.api.routers import mcp as mcp_router
from service.main import app
from service.mcp.registry import (
    BackendClient,
    McpToolError,
    ToolRegistry,
    _management_driver_group_report,
    _management_trip_period_report,
    _open_screen,
    _prepare_trip_action,
    _prepare_flood_report,
    _prepare_navigation,
    _rank_upcoming,
)
import pytest


def test_rank_upcoming_fetches_before_applying_requested_limit() -> None:
    class FakeBackend:
        def get(self, path):
            assert "limit=50" in path
            return [
                {"id": 33, "plannedStartTime": "2026-08-03T18:30:00"},
                {"id": 25, "plannedStartTime": "2026-08-03T07:00:00"},
            ]

    result = _rank_upcoming(
        FakeBackend(),
        {"start_date": None, "end_date": None, "limit": 1},
    )

    assert result["count"] == 2
    assert result["dateScope"] == "ALL_TIME_PENDING"
    assert result["recommendedTrip"]["id"] == 25
    assert [trip["id"] for trip in result["rankedTrips"]] == [25]


def test_prepare_pause_rejects_trip_that_is_not_current_driving_session() -> None:
    class FakeBackend:
        def get(self, path):
            if path.endswith("/trips/5"):
                return {"id": 5, "status": "IN_PROGRESS"}
            if path.endswith("/driving-sessions/current"):
                return {"tripId": 9, "status": "ACTIVE"}
            raise AssertionError(path)

    with pytest.raises(McpToolError, match="không phải chuyến 5"):
        _prepare_trip_action(
            FakeBackend(), {"action": "PAUSE", "trip_id": 5, "note": None}
        )


def test_prepare_pause_accepts_active_current_driving_session() -> None:
    class FakeBackend:
        def get(self, path):
            if path.endswith("/trips/9"):
                return {"id": 9, "status": "IN_PROGRESS"}
            if path.endswith("/driving-sessions/current"):
                return {"tripId": 9, "status": "ACTIVE"}
            raise AssertionError(path)

    result = _prepare_trip_action(
        FakeBackend(), {"action": "PAUSE", "trip_id": 9, "note": "nghỉ"}
    )

    assert result["ok"] is True
    assert result["confirmationRequest"]["tripId"] == 9
    assert result["confirmationRequest"]["action"] == "PAUSE"


def test_prepare_start_requires_submitted_checklist() -> None:
    class FakeBackend:
        def get(self, path):
            if path.endswith("/trips/8"):
                return {"id": 8, "status": "ASSIGNED"}
            if path.endswith("/trips/8/summary"):
                return {"checklistSubmitted": False}
            raise AssertionError(path)

    with pytest.raises(McpToolError, match="checklist"):
        _prepare_trip_action(
            FakeBackend(), {"action": "START", "trip_id": 8, "note": None}
        )


def test_prepare_navigation_uses_backend_coordinates_not_model_coordinates() -> None:
    class FakeBackend:
        def get(self, path):
            assert "locations/autocomplete" in path
            return [
                {
                    "id": "place-1",
                    "name": "Bến xe Mỹ Đình",
                    "address": "Nam Từ Liêm, Hà Nội",
                    "lat": 21.0281,
                    "lng": 105.7762,
                    "source": "PHOTON",
                }
            ]

    result = _prepare_navigation(
        FakeBackend(),
        {"destination_query": "Bến xe Mỹ Đình", "selected_index": 0},
    )

    action = result["clientAction"]
    assert action["type"] == "START_NAVIGATION"
    assert action["destinationLat"] == 21.0281
    assert action["destinationLng"] == 105.7762
    assert action["autoStart"] is True


def test_open_screen_returns_allowlisted_client_action() -> None:
    result = _open_screen(object(), {"destination": "TRIP_DETAIL", "trip_id": 42})

    assert result == {
        "ok": True,
        "clientAction": {
            "type": "NAVIGATE",
            "destination": "TRIP_DETAIL",
            "tripId": 42,
        },
    }


def test_open_screen_rejects_missing_trip_id() -> None:
    with pytest.raises(McpToolError, match="trip_id"):
        _open_screen(object(), {"destination": "TRIP_DETAIL"})


def test_prepare_flood_report_never_accepts_coordinates_from_model() -> None:
    result = _prepare_flood_report(
        object(),
        {"severity": "BLOCKED", "description": "Nước chảy xiết"},
    )

    confirmation = result["confirmationRequest"]
    assert confirmation["type"] == "FLOOD_REPORT"
    assert confirmation["severity"] == "BLOCKED"
    assert "lat" not in confirmation
    assert "lng" not in confirmation


def test_registry_filters_tools_by_authenticated_role(monkeypatch) -> None:
    monkeypatch.setattr(
        BackendClient,
        "identity",
        lambda _self: {"userId": 9, "driverId": 4, "role": "DRIVER"},
    )
    identity, tools = ToolRegistry().list_for("Bearer driver-token")
    names = {tool["name"] for tool in tools}

    assert identity["role"] == "DRIVER"
    assert "list_completed_trips" in names
    assert "list_all_trips" in names
    assert "prepare_trip_action" in names
    assert "search_internal_documents" in names


def test_registry_gives_admin_management_tools_but_not_driver_tools(monkeypatch) -> None:
    monkeypatch.setattr(
        BackendClient,
        "identity",
        lambda _self: {"userId": 1, "driverId": None, "role": "ADMIN"},
    )
    _identity, tools = ToolRegistry().list_for("Bearer admin-token")
    names = {tool["name"] for tool in tools}
    assert "search_internal_documents" in names
    assert "management_search_drivers" in names
    assert "management_get_trip_period_report" in names
    assert "management_search_accounts" in names
    assert "list_all_trips" not in names
    driver_tool = next(tool for tool in tools if tool["name"] == "management_search_drivers")
    assert "safetyScore" in driver_tool["description"]
    assert driver_tool["_meta"]["outputDescription"]


def test_management_trip_period_report_aggregates_all_statuses_and_days() -> None:
    class FakeBackend:
        def get(self, path):
            if "/reports/trips/by-day" in path:
                return [
                    {"date": "2026-08-01", "totalTrips": 2},
                    {"date": "2026-08-02", "totalTrips": 1},
                ]
            if "status=COMPLETED" in path:
                return {"totalElements": 2, "items": []}
            if "status=IN_PROGRESS" in path:
                return {"totalElements": 1, "items": []}
            return {"totalElements": 0, "items": []}

    result = _management_trip_period_report(
        FakeBackend(), {"from_date": "2026-08-01", "to_date": "2026-08-02"}
    )

    assert result["totalTrips"] == 3
    assert result["completedTrips"] == 2
    assert result["activeTrips"] == 1
    assert result["completionRate"] == pytest.approx(66.67)
    assert result["scope"]["days"] == 2
    assert result["dataAvailability"]["unavailableMetrics"] == [
        "totalDistanceKm",
        "actualDrivingMinutes",
    ]


def test_management_driver_group_report_uses_explicit_ids_and_period() -> None:
    requested = []

    class FakeBackend:
        def get(self, path):
            requested.append(path)
            if path == "/api/v1/drivers/7":
                return {"id": 7, "fullName": "Nguyễn An", "safetyScore": 72}
            if path == "/api/v1/drivers/9":
                return {"id": 9, "fullName": "Trần Bình", "safetyScore": 61}
            if "/trips" in path:
                return {"totalElements": 4, "items": []}
            if "/safety-events" in path:
                return {"totalElements": 2, "items": []}
            raise AssertionError(path)

    result = _management_driver_group_report(
        FakeBackend(),
        {
            "driver_ids": [7, 9],
            "from_date": "2026-08-01",
            "to_date": "2026-08-31",
        },
    )

    assert result["count"] == 2
    assert [row["driver"]["id"] for row in result["drivers"]] == [7, 9]
    assert all(row["periodTripCount"] == 4 for row in result["drivers"])
    assert all(row["periodSafetyEventCount"] == 2 for row in result["drivers"])
    assert any("driverId=7" in path and "fromDate=2026-08-01" in path for path in requested)


def test_mcp_tools_list_uses_server_side_registry(monkeypatch) -> None:
    monkeypatch.setattr(
        mcp_router.registry,
        "list_for",
        lambda authorization: (
            {"userId": 9, "role": "DRIVER"},
            [{"name": "get_safety_summary", "inputSchema": {"type": "object"}}],
        ),
    )
    response = TestClient(app).post(
        "/mcp",
        headers={
            "X-SafeFleet-Service-Token": "test-internal-token",
            "X-User-Authorization": "Bearer driver-token",
        },
        json={"jsonrpc": "2.0", "id": "1", "method": "tools/list", "params": {}},
    )

    assert response.status_code == 200
    assert response.json()["result"]["tools"][0]["name"] == "get_safety_summary"
