from __future__ import annotations

import json
from pathlib import Path

from evaluation.run_eval_v4 import compare_snapshot, gold_histories
from evaluation.validate_gold_dataset_v4 import validate


BASE = Path(__file__).resolve().parents[1] / "evaluation"


def load_dataset() -> dict:
    return json.loads((BASE / "gold_dataset_v4.json").read_text(encoding="utf-8"))


def test_gold_dataset_v4_is_progressive_and_valid() -> None:
    dataset = load_dataset()
    assert validate(dataset) == []
    assert [case["difficulty_level"] for case in dataset["cases"]] == [
        level for level in range(1, 6) for _ in range(10)
    ]


def test_gold_history_contains_all_preceding_workflow_turns() -> None:
    dataset = load_dataset()
    histories = gold_histories(dataset["cases"])
    first_workflow = dataset["cases"][:5]
    assert [len(histories[case["id"]]) for case in first_workflow] == [0, 2, 4, 6, 8]
    last = first_workflow[-1]
    assert histories[last["id"]][0]["role"] == "user"
    assert histories[last["id"]][1]["role"] == "assistant"


def test_snapshot_preflight_rejects_data_drift() -> None:
    dataset = load_dataset()
    assert compare_snapshot(dataset, dataset["snapshot"])["matches"] is True
    drifted = {**dataset["snapshot"], "fingerprint": "changed"}
    assert compare_snapshot(dataset, drifted)["matches"] is False
