from __future__ import annotations

import json
from pathlib import Path

from evaluation.run_eval_v3 import tool_call_contract
from evaluation.validate_gold_dataset_v3 import validate


BASE = Path(__file__).resolve().parents[1] / "evaluation"


def test_gold_dataset_v3_has_valid_30_easy_20_extreme_design() -> None:
    dataset = json.loads((BASE / "gold_dataset_v3.json").read_text(encoding="utf-8"))
    assert validate(dataset) == []


def test_tool_call_contract_checks_repeated_tool_and_arguments() -> None:
    actual = [
        {"name": "get_trip_detail", "arguments": {"trip_id": 1}, "success": True},
        {"name": "get_trip_detail", "arguments": {"trip_id": 6}, "success": True},
    ]
    expected = [
        {"name": "get_trip_detail", "arguments": {"trip_id": 1}},
        {"name": "get_trip_detail", "arguments": {"trip_id": 6}},
    ]
    wrong = [
        {"name": "get_trip_detail", "arguments": {"trip_id": 1}},
        {"name": "get_trip_detail", "arguments": {"trip_id": 7}},
    ]

    assert tool_call_contract(actual, expected)["recall"] == 1.0
    assert tool_call_contract(actual, wrong)["recall"] == 0.5
    assert tool_call_contract(actual, [])["f1"] == 1.0
    assert tool_call_contract(actual, [])["applicable"] is False
