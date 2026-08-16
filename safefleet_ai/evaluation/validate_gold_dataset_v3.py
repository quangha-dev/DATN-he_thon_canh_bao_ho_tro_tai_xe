from __future__ import annotations

import json
from collections import Counter
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
KNOWN_TOOLS = {
    "list_all_trips",
    "list_completed_trips",
    "list_upcoming_trips",
    "list_active_trips",
    "rank_upcoming_trips",
    "get_current_assignment",
    "get_trip_detail",
    "get_trip_summary",
    "get_warehouse_issue",
    "get_monthly_report",
    "get_safety_summary",
    "get_current_driving_session",
    "list_notifications",
    "open_mobile_screen",
    "prepare_trip_action",
}


def validate(dataset: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    cases = dataset.get("cases") or []
    difficulties = Counter(case.get("difficulty") for case in cases)
    splits = Counter(case.get("split") for case in cases)
    if len(cases) != 50:
        errors.append(f"Cần đúng 50 ca, hiện có {len(cases)}")
    if difficulties != Counter({"easy": 30, "extreme": 20}):
        errors.append(f"Phân bổ difficulty sai: {dict(difficulties)}")
    if splits != Counter({"regression": 30, "reasoning_dev": 10, "reasoning_holdout": 10}):
        errors.append(f"Phân bổ split sai: {dict(splits)}")

    ids = [case.get("id") for case in cases]
    expected_ids = [f"SFV3-{index:03d}" for index in range(1, 51)]
    if ids != expected_ids:
        errors.append("ID phải liên tục SFV3-001..SFV3-050 và đúng thứ tự")
    questions = [str(case.get("question") or "").strip().lower() for case in cases]
    if len(set(questions)) != len(questions):
        errors.append("Có câu hỏi trùng lặp")

    required = {
        "id",
        "difficulty",
        "split",
        "category",
        "question",
        "expected_tools",
        "expected_statuses",
        "expected_answer",
        "expected_facts",
    }
    for case in cases:
        case_id = str(case.get("id") or "UNKNOWN")
        missing_fields = sorted(required - set(case))
        if missing_fields:
            errors.append(f"{case_id}: thiếu field {missing_fields}")
            continue
        unknown = set(case["expected_tools"]) - KNOWN_TOOLS
        unknown |= set(case.get("forbidden_tools", [])) - KNOWN_TOOLS
        if unknown:
            errors.append(f"{case_id}: tool không tồn tại {sorted(unknown)}")
        if len(case["expected_facts"]) < 2:
            errors.append(f"{case_id}: expected_facts quá ít")

        if case["difficulty"] != "extreme":
            continue
        contracts = case.get("expected_tool_calls") or []
        if len(contracts) < 2:
            errors.append(f"{case_id}: ca extreme cần ít nhất 2 tool calls")
        if int(case.get("min_tool_calls") or 0) < 2:
            errors.append(f"{case_id}: min_tool_calls phải >= 2")
        if int(case.get("min_tool_calls") or 0) != len(contracts):
            errors.append(f"{case_id}: min_tool_calls phải bằng số contract")
        if int(case.get("min_tool_calls") or 0) > 6:
            errors.append(f"{case_id}: vượt giới hạn agent 6 bước")
        if len(case.get("reasoning_steps") or []) < 2:
            errors.append(f"{case_id}: thiếu chuỗi reasoning_steps")
        if len(case.get("required_evidence") or []) < 2:
            errors.append(f"{case_id}: cần ít nhất 2 nguồn bằng chứng")
        if not case.get("reasoning_type"):
            errors.append(f"{case_id}: thiếu reasoning_type")
        if len(case["expected_facts"]) < 4:
            errors.append(f"{case_id}: ca extreme cần ít nhất 4 gold facts")
        for contract in contracts:
            name = contract.get("name")
            if name not in KNOWN_TOOLS:
                errors.append(f"{case_id}: contract tool không tồn tại {name}")
            if name not in case["expected_tools"]:
                errors.append(f"{case_id}: contract {name} không có trong expected_tools")
        if "prepare_trip_action" in case.get("forbidden_tools", []) and not case.get(
            "safety_rules"
        ):
            errors.append(f"{case_id}: chặn mutation nhưng thiếu safety_rules")
        if any(call.get("name") == "prepare_trip_action" for call in contracts):
            if "AWAITING_CONFIRMATION" not in case["expected_statuses"]:
                errors.append(f"{case_id}: mutation phải dừng ở AWAITING_CONFIRMATION")
            if not case.get("safety_rules"):
                errors.append(f"{case_id}: mutation cần safety_rules")

    snapshot = dataset.get("snapshot") or {}
    trips = snapshot.get("trips") or []
    status_counts = Counter(trip.get("status") for trip in trips)
    expected_distribution = snapshot.get("status_distribution") or {}
    if dict(status_counts) != expected_distribution:
        errors.append(
            f"Snapshot status_distribution sai: computed={dict(status_counts)}, "
            f"stored={expected_distribution}"
        )
    active = [trip for trip in trips if trip.get("status") == "IN_PROGRESS"]
    average = round(sum(float(trip["progress"]) for trip in active) / max(1, len(active)), 2)
    stored_average = float(
        (snapshot.get("derived_trip_metrics") or {}).get("active_average_progress_percent", -1)
    )
    if average != stored_average:
        errors.append(f"Snapshot average active progress sai: {average} != {stored_average}")
    if dataset.get("snapshot_id") != snapshot.get("snapshot_id"):
        errors.append("snapshot_id cấp dataset không khớp snapshot")
    return errors


def main() -> None:
    path = HERE / "gold_dataset_v3.json"
    dataset = json.loads(path.read_text(encoding="utf-8"))
    errors = validate(dataset)
    if errors:
        print("Gold Dataset V3 INVALID")
        for error in errors:
            print(f"- {error}")
        raise SystemExit(1)
    counts = Counter(case["category"] for case in dataset["cases"])
    print("Gold Dataset V3 VALID")
    print("- total: 50")
    print("- easy: 30")
    print("- extreme: 20")
    print(f"- categories: {dict(counts)}")


if __name__ == "__main__":
    main()
