from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path
from typing import Any

try:
    import run_eval_v2 as base
except ModuleNotFoundError:  # Imported as evaluation.run_eval_v3 in pytest.
    from evaluation import run_eval_v2 as base


HERE = Path(__file__).resolve().parent


def arguments_contain(actual: dict[str, Any], expected: dict[str, Any]) -> bool:
    for key, expected_value in expected.items():
        if key not in actual:
            return False
        actual_value = actual[key]
        if isinstance(expected_value, dict):
            if not isinstance(actual_value, dict) or not arguments_contain(actual_value, expected_value):
                return False
        elif actual_value != expected_value:
            return False
    return True


def tool_call_contract(
    actual_calls: list[dict[str, Any]], expected_calls: list[dict[str, Any]]
) -> dict[str, Any]:
    if not expected_calls:
        return {
            "recall": 1.0,
            "precision": 1.0,
            "f1": 1.0,
            "matched": [],
            "missing": [],
            "unexpected": [],
            "applicable": False,
        }
    unmatched = set(range(len(actual_calls)))
    matched: list[dict[str, Any]] = []
    missing: list[dict[str, Any]] = []
    for expected in expected_calls:
        found = None
        for index in sorted(unmatched):
            actual = actual_calls[index]
            if actual.get("name") != expected.get("name"):
                continue
            if not arguments_contain(
                actual.get("arguments") or {}, expected.get("arguments") or {}
            ):
                continue
            found = index
            break
        if found is None:
            missing.append(expected)
        else:
            unmatched.remove(found)
            matched.append(expected)
    recall = 1.0 if not expected_calls else len(matched) / len(expected_calls)
    precision = 1.0 if not actual_calls else len(matched) / len(actual_calls)
    f1 = 2 * precision * recall / max(1e-9, precision + recall)
    return {
        "recall": round(recall, 4),
        "precision": round(precision, 4),
        "f1": round(f1, 4),
        "matched": matched,
        "missing": missing,
        "unexpected": [actual_calls[index] for index in sorted(unmatched)],
        "applicable": True,
    }


def run_case(case: dict[str, Any], base_url: str, token: str, timeout: int) -> dict[str, Any]:
    started = time.time()
    envelope = base.request_json(
        f"{base_url}/mobile/agent/chat",
        "POST",
        {"messages": [{"role": "user", "content": case["question"]}]},
        token,
        timeout,
    )
    response = envelope.get("data") or {}
    names, calls = base.actual_tools(response.get("steps") or [])
    answer = str(response.get("responseText") or "")
    scores, diagnostics = base.evaluate_answer(case, answer, names)
    contract = tool_call_contract(calls, case.get("expected_tool_calls", []))
    scores.update(
        toolCallContractRecall=contract["recall"],
        toolCallContractPrecision=contract["precision"],
        toolCallContractF1=contract["f1"],
    )
    status = str(response.get("status") or "MISSING")
    status_match = status in case.get("expected_statuses", ["COMPLETED"])
    tool_execution_ok = all(item.get("success") for item in calls)
    minimum_calls_ok = len(calls) >= int(case.get("min_tool_calls") or 0)
    scores["taskCompletion"] = round(
        (
            float(status_match)
            + scores["toolF1"]
            + float(tool_execution_ok)
            + contract["recall"]
            + float(minimum_calls_ok)
        )
        / 5,
        4,
    )
    thresholds = base.DATASET["thresholds"]
    passed = (
        status_match
        and scores["toolF1"] >= thresholds["tool_f1"]
        and contract["recall"] >= thresholds["tool_call_contract_recall"]
        and minimum_calls_ok
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
        elif not minimum_calls_ok or contract["recall"] < thresholds["tool_call_contract_recall"]:
            classification = "TOOL_CALL_CONTRACT_MISMATCH"
        elif diagnostics["forbiddenClaimsFound"]:
            classification = "POSSIBLE_HALLUCINATION"
        elif case["category"] == "out_of_scope" and names:
            classification = "OUT_OF_SCOPE_TOOL_USE"
        else:
            classification = "QUALITY_MISMATCH"
    return {
        "id": case["id"],
        "difficulty": case["difficulty"],
        "category": case["category"],
        "reasoningType": case.get("reasoning_type"),
        "question": case["question"],
        "expectedAnswer": case["expected_answer"],
        "actualAnswer": answer,
        "expectedTools": case.get("expected_tools", []),
        "actualTools": names,
        "toolCalls": calls,
        "toolCallContract": contract,
        "expectedStatuses": case.get("expected_statuses", []),
        "actualStatus": status,
        "scores": scores,
        "diagnostics": diagnostics,
        "classification": classification,
        "passed": passed,
        "durationSeconds": round(time.time() - started, 3),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="SafeFleet 50-case live reasoning evaluation v3")
    parser.add_argument("--dataset", default=str(HERE / "gold_dataset_v3.json"))
    parser.add_argument("--output", default=str(HERE / "eval_v3_results.json"))
    parser.add_argument("--base-url", default="http://127.0.0.1:8080/api/v1")
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--difficulty", choices=["all", "easy", "extreme"], default="all")
    parser.add_argument(
        "--split",
        choices=["all", "regression", "reasoning_dev", "reasoning_holdout"],
        default="all",
    )
    parser.add_argument("--ids", default="", help="Comma-separated case IDs")
    args = parser.parse_args()

    dataset = json.loads(Path(args.dataset).read_text(encoding="utf-8"))
    base.DATASET = dataset
    cases = list(dataset["cases"])
    if args.difficulty != "all":
        cases = [case for case in cases if case["difficulty"] == args.difficulty]
    if args.split != "all":
        cases = [case for case in cases if case["split"] == args.split]
    selected_ids = {value.strip() for value in args.ids.split(",") if value.strip()}
    if selected_ids:
        cases = [case for case in cases if case["id"] in selected_ids]

    username = os.getenv("SAFEFLEET_EVAL_USERNAME")
    password = os.getenv("SAFEFLEET_EVAL_PASSWORD")
    if not username or not password:
        raise SystemExit("Cần SAFEFLEET_EVAL_USERNAME và SAFEFLEET_EVAL_PASSWORD")
    login = base.request_json(
        f"{args.base_url}/auth/login",
        "POST",
        {"usernameOrEmail": username, "password": password},
        timeout=args.timeout,
    )
    token = str((login.get("data") or {}).get("accessToken") or "")
    if not token:
        raise SystemExit("Đăng nhập eval không trả access token")

    started = time.time()
    results: list[dict[str, Any]] = []
    for index, case in enumerate(cases, start=1):
        print(
            f"[{index:02d}/{len(cases)}] {case['id']} {case['difficulty']} "
            f"{case['category']}",
            flush=True,
        )
        try:
            results.append(run_case(case, args.base_url, token, args.timeout))
        except Exception as exception:
            results.append(
                {
                    "id": case["id"],
                    "difficulty": case["difficulty"],
                    "category": case["category"],
                    "question": case["question"],
                    "classification": "EVALUATOR_ERROR",
                    "passed": False,
                    "error": str(exception),
                    "scores": {},
                    "durationSeconds": 0.0,
                }
            )
    report = {
        "dataset": dataset["corpus_id"],
        "snapshotId": dataset["snapshot_id"],
        "referenceDatetime": dataset["reference_datetime"],
        "mode": "LIVE_AGENT_V3",
        "selection": {
            "difficulty": args.difficulty,
            "split": args.split,
            "ids": sorted(selected_ids),
        },
        "summary": base.aggregate(results, time.time() - started),
        "results": results,
    }
    Path(args.output).write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(report["summary"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
