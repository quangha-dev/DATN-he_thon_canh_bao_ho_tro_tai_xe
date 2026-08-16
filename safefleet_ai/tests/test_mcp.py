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
    _prepare_trip_action,
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
    assert "search_internal_documents" not in names


def test_registry_rejects_driver_tool_for_admin(monkeypatch) -> None:
    monkeypatch.setattr(
        BackendClient,
        "identity",
        lambda _self: {"userId": 1, "driverId": None, "role": "ADMIN"},
    )
    _identity, tools = ToolRegistry().list_for("Bearer admin-token")
    assert tools == []


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
