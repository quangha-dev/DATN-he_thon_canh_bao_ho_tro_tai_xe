from __future__ import annotations

import json
from collections import Counter, defaultdict
from pathlib import Path
from statistics import mean
from typing import Any

try:
    from validate_gold_dataset_v3 import KNOWN_TOOLS
except ModuleNotFoundError:
    from evaluation.validate_gold_dataset_v3 import KNOWN_TOOLS


HERE = Path(__file__).resolve().parent


def validate(dataset: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    cases = dataset.get("cases") or []
    if len(cases) != 50:
        errors.append(f"Cần đúng 50 câu, hiện có {len(cases)}")

    ids = [case.get("id") for case in cases]
    if ids != [f"SFV4-{index:03d}" for index in range(1, 51)]:
        errors.append("ID phải liên tục SFV4-001..SFV4-050")
    questions = [str(case.get("question") or "").strip() for case in cases]
    if len(set(question.lower() for question in questions)) != len(questions):
        errors.append("Có câu hỏi trùng lặp")

    levels = Counter(case.get("difficulty_level") for case in cases)
    if levels != Counter({level: 10 for level in range(1, 6)}):
        errors.append(f"Mỗi mức phải có 10 câu: {dict(levels)}")
    splits = Counter(case.get("split") for case in cases)
    if splits != Counter({"development": 25, "holdout": 25}):
        errors.append(f"Phân bổ split sai: {dict(splits)}")

    workflows: dict[str, list[dict[str, Any]]] = defaultdict(list)
    lengths: dict[int, list[int]] = defaultdict(list)
    required = {
        "id",
        "source_case_id",
        "difficulty_level",
        "difficulty",
        "workflow_id",
        "turn_index",
        "workflow_turns",
        "question",
        "expected_tools",
        "expected_tool_calls",
        "min_tool_calls",
        "expected_statuses",
        "expected_answer",
        "expected_facts",
        "complexity_contract",
    }
    for case in cases:
        case_id = str(case.get("id") or "UNKNOWN")
        missing = sorted(required - set(case))
        if missing:
            errors.append(f"{case_id}: thiếu field {missing}")
            continue
        level = int(case["difficulty_level"])
        workflows[str(case["workflow_id"])].append(case)
        lengths[level].append(len(str(case["question"])))
        unknown = set(case.get("expected_tools") or []) - KNOWN_TOOLS
        unknown |= set(case.get("forbidden_tools") or []) - KNOWN_TOOLS
        if unknown:
            errors.append(f"{case_id}: tool không tồn tại {sorted(unknown)}")
        calls = case.get("expected_tool_calls") or []
        if int(case["min_tool_calls"]) != len(calls):
            errors.append(f"{case_id}: min_tool_calls phải bằng số contract")
        for contract in calls:
            name = contract.get("name")
            if name not in KNOWN_TOOLS:
                errors.append(f"{case_id}: contract tool không tồn tại {name}")
            if name not in case.get("expected_tools", []):
                errors.append(f"{case_id}: contract {name} không nằm trong expected_tools")
        complexity = case["complexity_contract"]
        if complexity.get("level") != level:
            errors.append(f"{case_id}: complexity level không khớp")
        if complexity.get("minimum_prior_turns") != int(case["turn_index"]) - 1:
            errors.append(f"{case_id}: minimum_prior_turns không khớp turn_index")
        if len(case.get("expected_facts") or []) < 2:
            errors.append(f"{case_id}: cần ít nhất 2 expected facts")

    if len(workflows) != 10:
        errors.append(f"Cần đúng 10 workflow, hiện có {len(workflows)}")
    for workflow_id, workflow_cases in workflows.items():
        turns = [int(case["turn_index"]) for case in workflow_cases]
        if turns != [1, 2, 3, 4, 5]:
            errors.append(f"{workflow_id}: turn_index phải là 1..5, hiện là {turns}")
        if len({case["difficulty_level"] for case in workflow_cases}) != 1:
            errors.append(f"{workflow_id}: workflow không được trộn mức khó")

    average_lengths = [round(mean(lengths[level]), 2) for level in range(1, 6)]
    if any(left >= right for left, right in zip(average_lengths, average_lengths[1:])):
        errors.append(f"Độ dài trung bình chưa tăng nghiêm ngặt theo 5 mức: {average_lengths}")
    if dataset.get("snapshot_id") != (dataset.get("snapshot") or {}).get("snapshot_id"):
        errors.append("snapshot_id không khớp snapshot")
    if dataset.get("snapshot_fingerprint") != (dataset.get("snapshot") or {}).get("fingerprint"):
        errors.append("snapshot_fingerprint không khớp snapshot")
    return errors


def main() -> None:
    path = HERE / "gold_dataset_v4.json"
    dataset = json.loads(path.read_text(encoding="utf-8"))
    errors = validate(dataset)
    if errors:
        print("Gold Dataset V4 INVALID")
        for error in errors:
            print(f"- {error}")
        raise SystemExit(1)
    lengths = {
        level: round(mean(len(case["question"]) for case in dataset["cases"] if case["difficulty_level"] == level), 2)
        for level in range(1, 6)
    }
    print("Gold Dataset V4 VALID")
    print("- total: 50")
    print("- levels: 10/10/10/10/10")
    print("- workflows: 10 x 5 turns")
    print(f"- average question lengths: {lengths}")


if __name__ == "__main__":
    main()
