from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import run_eval_v2 as evaluator


def rescore_agent(case: dict[str, Any], previous: dict[str, Any]) -> dict[str, Any]:
    answer = str(previous.get("actualAnswer") or "")
    names = [str(name) for name in previous.get("actualTools") or []]
    calls = previous.get("toolCalls") or []
    status = str(previous.get("actualStatus") or "MISSING")
    scores, diagnostics = evaluator.evaluate_answer(case, answer, names)
    status_match = status in case.get("expected_statuses", ["COMPLETED"])
    tool_execution_ok = all(call.get("success") for call in calls)
    scores["taskCompletion"] = round(
        (float(status_match) + scores["toolF1"] + float(tool_execution_ok)) / 3, 4
    )
    thresholds = evaluator.DATASET["thresholds"]
    passed = (
        status_match
        and scores["toolF1"] >= thresholds["tool_f1"]
        and scores["relevance"] >= thresholds["semantic_similarity"]
        and scores["completeness"] >= thresholds["fact_coverage"]
        and scores["coherence"] == 1.0
        and not diagnostics["forbiddenClaimsFound"]
        and tool_execution_ok
    )
    classification = "PASS"
    if not passed:
        if status == "FAILED" or not tool_execution_ok:
            classification = "SYSTEM_OR_TOOL_ERROR"
        elif diagnostics["forbiddenClaimsFound"]:
            classification = "POSSIBLE_HALLUCINATION"
        elif case["category"] == "out_of_scope" and names:
            classification = "OUT_OF_SCOPE_TOOL_USE"
        else:
            classification = "QUALITY_MISMATCH"
    return {
        **previous,
        "category": case["category"],
        "question": case["question"],
        "expectedAnswer": case["expected_answer"],
        "expectedTools": case.get("expected_tools", []),
        "expectedStatuses": case.get("expected_statuses", []),
        "scores": scores,
        "diagnostics": diagnostics,
        "classification": classification,
        "passed": passed,
    }


def main() -> None:
    base = Path(__file__).parent
    parser = argparse.ArgumentParser(description="Re-score captured eval responses without new API calls")
    parser.add_argument("--dataset", default=str(base / "gold_dataset_v2.json"))
    parser.add_argument("--chunks", default=str(base / "rag_chunks_v2.jsonl"))
    parser.add_argument("--input", default=str(base / "eval_v2_results.json"))
    parser.add_argument("--output", default=str(base / "eval_v2_results.json"))
    args = parser.parse_args()

    evaluator.DATASET = json.loads(Path(args.dataset).read_text(encoding="utf-8"))
    previous_report = json.loads(Path(args.input).read_text(encoding="utf-8"))
    previous_by_id = {item["id"]: item for item in previous_report["results"]}
    chunks = evaluator.load_chunks(Path(args.chunks))
    results = []
    for case in evaluator.DATASET["cases"]:
        if case["category"] == "rag_mock":
            results.append(evaluator.run_rag_case(case, chunks))
        else:
            results.append(rescore_agent(case, previous_by_id[case["id"]]))

    report = {
        **previous_report,
        "mode": "REPLAY_RESCORE",
        "summary": evaluator.aggregate(
            results, float(previous_report.get("summary", {}).get("durationSeconds") or 0)
        ),
        "results": results,
    }
    Path(args.output).write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(report["summary"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
