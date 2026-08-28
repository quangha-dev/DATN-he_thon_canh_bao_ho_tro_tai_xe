from __future__ import annotations

import argparse
import hashlib
import json
import os
import time
from datetime import datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlencode
from zoneinfo import ZoneInfo

try:
    from run_eval_v2 import request_json
except ModuleNotFoundError:
    from evaluation.run_eval_v2 import request_json


HERE = Path(__file__).resolve().parent
STATUSES = [
    "DRAFT",
    "ASSIGNED",
    "ACCEPTED",
    "IN_PROGRESS",
    "RESTING",
    "COMPLETED",
    "DELAYED",
    "INCIDENT",
    "CANCELLED",
]


def data(envelope: dict[str, Any]) -> Any:
    return envelope.get("data")


def get(base_url: str, path: str, token: str, timeout: int) -> Any:
    last_error: OSError | TimeoutError | None = None
    for attempt in range(4):
        try:
            return data(request_json(f"{base_url}{path}", token=token, timeout=timeout))
        except (OSError, TimeoutError) as exception:
            last_error = exception
            if attempt < 3:
                time.sleep(0.5 * (2**attempt))
    if last_error is not None:
        raise last_error
    raise RuntimeError("Không thể đọc dữ liệu snapshot")


def optional_get(base_url: str, path: str, token: str, timeout: int) -> Any:
    try:
        return get(base_url, path, token, timeout)
    except RuntimeError as exception:
        return {"unavailable": str(exception).split(":", 1)[0]}


def capture(base_url: str, username: str, password: str, timeout: int) -> dict[str, Any]:
    login = request_json(
        f"{base_url}/auth/login",
        "POST",
        {"usernameOrEmail": username, "password": password},
        timeout=timeout,
    )
    token = str((login.get("data") or {}).get("accessToken") or "")
    if not token:
        raise RuntimeError("Đăng nhập snapshot không trả access token")
    query = urlencode([*(('statuses', status) for status in STATUSES), ("limit", "50")])
    trips = get(base_url, f"/mobile/trips?{query}", token, timeout) or []
    trips = sorted(trips, key=lambda item: int(item.get("id") or 0))
    details = {
        str(trip["id"]): optional_get(base_url, f"/mobile/trips/{trip['id']}", token, timeout)
        for trip in trips
    }
    summaries = {
        str(trip["id"]): optional_get(
            base_url, f"/mobile/trips/{trip['id']}/summary", token, timeout
        )
        for trip in trips
    }
    warehouse = {
        str(trip["id"]): value
        for trip in trips
        if not isinstance(
            value := optional_get(
                base_url, f"/mobile/trips/{trip['id']}/warehouse-issue", token, timeout
            ),
            dict,
        )
        or "unavailable" not in value
    }
    captured_at = datetime.now(ZoneInfo("Asia/Ho_Chi_Minh")).isoformat(timespec="seconds")
    mutable = {
        "captured_at": captured_at,
        "actor": get(base_url, "/auth/me", token, timeout),
        "trips": trips,
        "trip_details": details,
        "trip_summaries": summaries,
        "warehouse_issues": warehouse,
        "current_assignment": optional_get(base_url, "/mobile/current-assignment", token, timeout),
        "current_session": optional_get(base_url, "/mobile/driving-sessions/current", token, timeout),
        "safety_summary": get(base_url, "/mobile/safety-summary", token, timeout),
        "monthly_2026_08": get(
            base_url, "/mobile/activity/monthly?month=2026-08", token, timeout
        ),
        "notifications": get(
            base_url, "/mobile/notifications?page=0&size=100", token, timeout
        ),
    }
    fingerprint_source = {key: value for key, value in mutable.items() if key != "captured_at"}
    fingerprint = hashlib.sha256(
        json.dumps(fingerprint_source, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode(
            "utf-8"
        )
    ).hexdigest()
    return {"snapshot_id": f"safefleet-v4-{fingerprint[:16]}", "fingerprint": fingerprint, **mutable}


def main() -> None:
    parser = argparse.ArgumentParser(description="Capture immutable live data for Gold Dataset V4")
    parser.add_argument("--base-url", default="http://127.0.0.1:8080/api/v1")
    parser.add_argument("--output", default=str(HERE / "gold_dataset_v4_live_snapshot.json"))
    parser.add_argument("--timeout", type=int, default=60)
    args = parser.parse_args()
    username = os.getenv("SAFEFLEET_EVAL_USERNAME")
    password = os.getenv("SAFEFLEET_EVAL_PASSWORD")
    if not username or not password:
        raise SystemExit("Cần SAFEFLEET_EVAL_USERNAME và SAFEFLEET_EVAL_PASSWORD")
    snapshot = capture(args.base_url, username, password, args.timeout)
    Path(args.output).write_text(
        json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(
        json.dumps(
            {
                "snapshotId": snapshot["snapshot_id"],
                "capturedAt": snapshot["captured_at"],
                "tripCount": len(snapshot["trips"]),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
