from __future__ import annotations

import json
from pathlib import Path

from evaluation.run_eval_v4 import (
    build_report,
    compare_snapshot,
    gold_histories,
    is_retryable_result,
    load_checkpoint,
    performance_metrics,
    reusable_results,
    runtime_metrics,
    selection_metadata,
    write_checkpoint,
)
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


def test_runtime_metrics_report_tokens_calls_and_cost_coverage() -> None:
    summary = runtime_metrics(
        [
            {
                "runMetrics": {
                    "modelCalls": 2,
                    "inputTokens": 100,
                    "outputTokens": 20,
                    "totalTokens": 120,
                    "estimatedCostUsd": 0.001,
                }
            },
            {
                "runMetrics": {
                    "modelCalls": 0,
                    "inputTokens": 0,
                    "outputTokens": 0,
                    "totalTokens": 0,
                    "estimatedCostUsd": 0.0,
                }
            },
        ]
    )

    assert summary == {
        "modelCalls": 2,
        "inputTokens": 100,
        "outputTokens": 20,
        "totalTokens": 120,
        "estimatedCostUsd": 0.001,
        "costCoverageCases": 2,
    }


def test_performance_metrics_reports_tail_latency_and_tool_volume() -> None:
    summary = performance_metrics(
        [
            {"durationSeconds": 0.1, "toolCalls": [{}, {}]},
            {"durationSeconds": 0.2, "toolCalls": [{}]},
            {"durationSeconds": 0.3, "toolCalls": []},
            {"durationSeconds": 1.2, "toolCalls": [{}, {}, {}]},
        ]
    )

    assert summary == {
        "p50LatencySeconds": 0.2,
        "p95LatencySeconds": 1.2,
        "p99LatencySeconds": 1.2,
        "maxLatencySeconds": 1.2,
        "executedToolCalls": 6,
        "averageToolCallsPerCase": 1.5,
    }


def test_resume_retries_quota_and_dependent_actual_history_turns() -> None:
    cases = [
        {"id": "A1", "workflow_id": "A"},
        {"id": "A2", "workflow_id": "A"},
        {"id": "B1", "workflow_id": "B"},
    ]
    previous = [
        {"id": "A1", "classification": "SYSTEM_OR_TOOL_ERROR", "actualAnswer": "429 quota"},
        {"id": "A2", "classification": "PASS", "actualAnswer": "later answer"},
        {"id": "B1", "classification": "PASS", "actualAnswer": "independent answer"},
    ]

    assert is_retryable_result(previous[0]) is True
    assert reusable_results(cases, previous, "actual") == {"B1": previous[2]}
    assert reusable_results(cases, previous, "gold") == {
        "A2": previous[1],
        "B1": previous[2],
    }


def test_checkpoint_is_atomic_and_validates_selection(tmp_path: Path) -> None:
    dataset = load_dataset()
    selection = selection_metadata(
        dataset,
        base_url="https://safeflee.duckdns.org/api/v1/",
        history_mode="actual",
        level=0,
        split="all",
        selected_ids={"SFV4-001"},
    )
    cases = [dataset["cases"][0]]
    result = {
        "id": "SFV4-001",
        "category": "navigation",
        "difficultyLevel": 1,
        "passed": True,
        "classification": "PASS",
        "scores": {},
        "durationSeconds": 0.1,
    }
    report = build_report(
        dataset,
        [result],
        cases,
        {"matches": True},
        selection,
        0.1,
    )
    checkpoint = tmp_path / "checkpoint.json"

    write_checkpoint(checkpoint, report)

    assert checkpoint.exists()
    assert not checkpoint.with_name("checkpoint.json.tmp").exists()
    assert load_checkpoint(checkpoint, selection) == [result]
    assert json.loads(checkpoint.read_text(encoding="utf-8"))["status"] == "COMPLETED"
