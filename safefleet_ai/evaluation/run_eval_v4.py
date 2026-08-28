from __future__ import annotations

import argparse
import json
import math
import os
import time
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    import run_eval_v2 as base
    from capture_gold_dataset_v4_snapshot import capture
    from run_eval_v3 import tool_call_contract
except ModuleNotFoundError:
    from evaluation import run_eval_v2 as base
    from evaluation.capture_gold_dataset_v4_snapshot import capture
    from evaluation.run_eval_v3 import tool_call_contract


HERE = Path(__file__).resolve().parent


def run_case(
    case: dict[str, Any],
    messages: list[dict[str, str]],
    base_url: str,
    token: str,
    timeout: int,
) -> dict[str, Any]:
    started = time.time()
    request_messages = [*messages, {"role": "user", "content": case["question"]}]
    envelope = base.request_json(
        f"{base_url}/mobile/agent/chat",
        "POST",
        {"messages": request_messages},
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
    run_metrics = response.get("runMetrics") or {}
    status_match = status in case.get("expected_statuses", ["COMPLETED"])
    tool_execution_ok = all(call.get("success") for call in calls)
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
    if passed:
        classification = "PASS"
    elif status == "FAILED" or not tool_execution_ok:
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
        "sourceCaseId": case["source_case_id"],
        "difficultyLevel": case["difficulty_level"],
        "difficulty": case["difficulty"],
        "workflowId": case["workflow_id"],
        "turnIndex": case["turn_index"],
        "historyUserTurns": sum(message["role"] == "user" for message in messages),
        "requestMessageCount": len(request_messages),
        "category": case["category"],
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
        "runMetrics": run_metrics,
    }


def gold_histories(cases: list[dict[str, Any]]) -> dict[str, list[dict[str, str]]]:
    histories: dict[str, list[dict[str, str]]] = defaultdict(list)
    result: dict[str, list[dict[str, str]]] = {}
    for case in cases:
        workflow_id = case["workflow_id"]
        result[case["id"]] = list(histories[workflow_id])
        histories[workflow_id].extend(
            [
                {"role": "user", "content": case["question"]},
                {"role": "assistant", "content": case["expected_answer"]},
            ]
        )
    return result


def level_summary(results: list[dict[str, Any]]) -> dict[str, Any]:
    grouped: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for result in results:
        grouped[int(result["difficultyLevel"])].append(result)
    return {
        str(level): {
            "total": len(items),
            "passed": sum(bool(item["passed"]) for item in items),
            "passRate": round(sum(bool(item["passed"]) for item in items) / max(1, len(items)), 4),
            "averageDurationSeconds": round(
                sum(float(item.get("durationSeconds") or 0) for item in items) / max(1, len(items)), 3
            ),
        }
        for level, items in sorted(grouped.items())
    }


def compare_snapshot(dataset: dict[str, Any], live_snapshot: dict[str, Any]) -> dict[str, Any]:
    expected = str(dataset.get("snapshot_fingerprint") or "")
    actual = str(live_snapshot.get("fingerprint") or "")
    return {
        "matches": bool(expected) and expected == actual,
        "expectedSnapshotId": dataset.get("snapshot_id"),
        "actualSnapshotId": live_snapshot.get("snapshot_id"),
        "expectedFingerprint": expected,
        "actualFingerprint": actual,
        "capturedAt": live_snapshot.get("captured_at"),
    }


def runtime_metrics(results: list[dict[str, Any]]) -> dict[str, Any]:
    metrics = [item.get("runMetrics") or {} for item in results]
    known_costs = [
        float(item["estimatedCostUsd"])
        for item in metrics
        if item.get("estimatedCostUsd") is not None
    ]
    return {
        "modelCalls": sum(int(item.get("modelCalls") or 0) for item in metrics),
        "inputTokens": sum(int(item.get("inputTokens") or 0) for item in metrics),
        "outputTokens": sum(int(item.get("outputTokens") or 0) for item in metrics),
        "totalTokens": sum(int(item.get("totalTokens") or 0) for item in metrics),
        "estimatedCostUsd": round(sum(known_costs), 8) if len(known_costs) == len(metrics) else None,
        "costCoverageCases": len(known_costs),
    }


def performance_metrics(results: list[dict[str, Any]]) -> dict[str, Any]:
    """Report tail latency and executed tool volume for acceptance/cost analysis."""
    values = sorted(float(item.get("durationSeconds") or 0) for item in results)

    def percentile(fraction: float) -> float:
        if not values:
            return 0.0
        rank = max(0, math.ceil(fraction * len(values)) - 1)
        return round(values[rank], 3)

    tool_calls = sum(len(item.get("toolCalls") or []) for item in results)
    return {
        "p50LatencySeconds": percentile(0.50),
        "p95LatencySeconds": percentile(0.95),
        "p99LatencySeconds": percentile(0.99),
        "maxLatencySeconds": round(max(values), 3) if values else 0.0,
        "executedToolCalls": tool_calls,
        "averageToolCallsPerCase": round(tool_calls / max(1, len(results)), 3),
    }


def selection_metadata(
    dataset: dict[str, Any],
    *,
    base_url: str,
    history_mode: str,
    level: int,
    split: str,
    selected_ids: set[str],
) -> dict[str, Any]:
    """Describe the inputs that must remain stable across resumed sessions."""
    return {
        "corpusId": dataset["corpus_id"],
        "snapshotId": dataset["snapshot_id"],
        "baseUrl": base_url.rstrip("/"),
        "historyMode": history_mode,
        "level": level,
        "split": split,
        "ids": sorted(selected_ids),
    }


def is_retryable_result(result: dict[str, Any]) -> bool:
    """Retry interrupted/quota failures, while preserving genuine evaluated failures."""
    if result.get("classification") == "EVALUATOR_ERROR":
        return True
    if result.get("actualStatus") == "NOT_CONFIGURED":
        return True
    diagnostic_text = " ".join(
        str(result.get(key) or "") for key in ("actualAnswer", "error")
    ).casefold()
    transient_markers = (
        "429",
        "quota",
        "rate limit",
        "hạn mức",
        "giới hạn lượt gọi",
        "too many requests",
    )
    return any(marker in diagnostic_text for marker in transient_markers)


def reusable_results(
    cases: list[dict[str, Any]],
    previous_results: list[dict[str, Any]],
    history_mode: str,
) -> dict[str, dict[str, Any]]:
    """Keep only results whose conversational history is still reproducible."""
    previous = {str(item.get("id")): item for item in previous_results}
    reusable: dict[str, dict[str, Any]] = {}
    blocked_workflows: set[str] = set()
    for case in cases:
        workflow_id = str(case["workflow_id"])
        result = previous.get(case["id"])
        if result is None or is_retryable_result(result):
            if history_mode == "actual":
                blocked_workflows.add(workflow_id)
            continue
        if history_mode == "actual" and workflow_id in blocked_workflows:
            continue
        reusable[case["id"]] = result
    return reusable


def build_report(
    dataset: dict[str, Any],
    results: list[dict[str, Any]],
    cases: list[dict[str, Any]],
    preflight: dict[str, Any],
    selection: dict[str, Any],
    elapsed_seconds: float,
) -> dict[str, Any]:
    completed_ids = {str(item.get("id")) for item in results}
    remaining_ids = [case["id"] for case in cases if case["id"] not in completed_ids]
    return {
        "status": "COMPLETED" if not remaining_ids else "IN_PROGRESS",
        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "completedCases": len(results),
        "remainingCases": len(remaining_ids),
        "remainingCaseIds": remaining_ids,
        "dataset": dataset["corpus_id"],
        "snapshotId": dataset["snapshot_id"],
        "referenceDatetime": dataset["reference_datetime"],
        "mode": "LIVE_AGENT_V4_MULTI_TURN",
        "historyMode": selection["historyMode"],
        "snapshotPreflight": preflight,
        "selection": selection,
        "summary": base.aggregate(results, elapsed_seconds),
        "performanceMetrics": performance_metrics(results),
        "runtimeMetrics": runtime_metrics(results),
        "levels": level_summary(results),
        "results": results,
    }


def write_checkpoint(path: Path, report: dict[str, Any]) -> None:
    """Atomically replace a checkpoint so an interrupted write cannot corrupt it."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f"{path.name}.tmp")
    temporary.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    os.replace(temporary, path)


def load_checkpoint(path: Path, selection: dict[str, Any]) -> list[dict[str, Any]]:
    if not path.exists():
        raise SystemExit(f"Không tìm thấy checkpoint để tiếp tục: {path}")
    report = json.loads(path.read_text(encoding="utf-8"))
    if report.get("selection") != selection:
        raise SystemExit(
            "Checkpoint không cùng dataset/server/bộ lọc/history-mode. "
            "Hãy dùng đúng tham số cũ hoặc chọn tệp output khác."
        )
    return list(report.get("results") or [])


def main() -> None:
    parser = argparse.ArgumentParser(description="SafeFleet progressive 50-question multi-turn evaluation V4")
    parser.add_argument("--dataset", default=str(HERE / "gold_dataset_v4.json"))
    parser.add_argument("--output", default=str(HERE / "eval_v4_results.json"))
    parser.add_argument("--base-url", default="http://127.0.0.1:8080/api/v1")
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--level", type=int, choices=[0, 1, 2, 3, 4, 5], default=0)
    parser.add_argument("--split", choices=["all", "development", "holdout"], default="all")
    parser.add_argument("--ids", default="", help="Comma-separated case IDs")
    parser.add_argument("--history-mode", choices=["actual", "gold"], default="actual")
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Tiếp tục từ checkpoint output và chỉ chạy các case còn thiếu/lỗi tạm thời.",
    )
    parser.add_argument(
        "--max-new-cases",
        type=int,
        default=0,
        help="Giới hạn số case mới trong phiên này; 0 nghĩa là chạy đến hết.",
    )
    parser.add_argument(
        "--skip-snapshot-check",
        action="store_true",
        help="Chỉ dùng khi cố ý đo data drift; kết quả không được coi là Gold score.",
    )
    args = parser.parse_args()

    dataset = json.loads(Path(args.dataset).read_text(encoding="utf-8"))
    base.DATASET = dataset
    all_cases = list(dataset["cases"])
    cases = all_cases
    if args.level:
        cases = [case for case in cases if case["difficulty_level"] == args.level]
    if args.split != "all":
        cases = [case for case in cases if case["split"] == args.split]
    selected_ids = {value.strip() for value in args.ids.split(",") if value.strip()}
    if selected_ids:
        cases = [case for case in cases if case["id"] in selected_ids]

    selection = selection_metadata(
        dataset,
        base_url=args.base_url,
        history_mode=args.history_mode,
        level=args.level,
        split=args.split,
        selected_ids=selected_ids,
    )
    output_path = Path(args.output)
    previous_results = load_checkpoint(output_path, selection) if args.resume else []
    preserved = reusable_results(cases, previous_results, args.history_mode)

    username = os.getenv("SAFEFLEET_EVAL_USERNAME")
    password = os.getenv("SAFEFLEET_EVAL_PASSWORD")
    if not username or not password:
        raise SystemExit("Cần SAFEFLEET_EVAL_USERNAME và SAFEFLEET_EVAL_PASSWORD")
    live_snapshot = capture(args.base_url, username, password, args.timeout)
    preflight = compare_snapshot(dataset, live_snapshot)
    if not preflight["matches"] and not args.skip_snapshot_check:
        raise SystemExit(
            "Snapshot live không khớp Gold Dataset V4; hãy capture/build lại dataset hoặc dùng "
            "--skip-snapshot-check chỉ để phân tích data drift."
        )
    login = base.request_json(
        f"{args.base_url}/auth/login",
        "POST",
        {"usernameOrEmail": username, "password": password},
        timeout=args.timeout,
    )
    token = str((login.get("data") or {}).get("accessToken") or "")
    if not token:
        raise SystemExit("Đăng nhập eval không trả access token")

    gold = gold_histories(all_cases)
    actual: dict[str, list[dict[str, str]]] = defaultdict(list)
    started = time.time()
    results_by_id: dict[str, dict[str, Any]] = dict(preserved)
    if args.history_mode == "actual":
        for case in cases:
            preserved_result = preserved.get(case["id"])
            if preserved_result is None:
                continue
            actual[case["workflow_id"]].extend(
                [
                    {"role": "user", "content": case["question"]},
                    {
                        "role": "assistant",
                        "content": preserved_result.get("actualAnswer")
                        or "Không thể hoàn tất lượt trước.",
                    },
                ]
            )

    cases_to_run = [case for case in cases if case["id"] not in preserved]
    if args.max_new_cases > 0:
        cases_to_run = cases_to_run[: args.max_new_cases]
    if preserved:
        print(f"Đã khôi phục {len(preserved)}/{len(cases)} case từ checkpoint.", flush=True)
    initial_results = [
        results_by_id[selected["id"]]
        for selected in cases
        if selected["id"] in results_by_id
    ]
    write_checkpoint(
        output_path,
        build_report(
            dataset,
            initial_results,
            cases,
            preflight,
            selection,
            time.time() - started,
        ),
    )
    for index, case in enumerate(cases_to_run, start=1):
        print(
            f"[{index:02d}/{len(cases_to_run)}] {case['id']} L{case['difficulty_level']} "
            f"{case['workflow_id']} turn={case['turn_index']}",
            flush=True,
        )
        messages = gold[case["id"]] if args.history_mode == "gold" else list(actual[case["workflow_id"]])
        exception: Exception | None = None
        result: dict[str, Any] | None = None
        for attempt in range(4):
            try:
                result = run_case(case, messages, args.base_url, token, args.timeout)
                break
            except Exception as caught:
                exception = caught
                if attempt < 3:
                    delay = 5 * (attempt + 1)
                    print(
                        f"  retry {attempt + 1}/3 sau {delay}s vì evaluator mất kết nối: {caught}",
                        flush=True,
                    )
                    time.sleep(delay)
        if result is None:
            result = {
                "id": case["id"],
                "sourceCaseId": case["source_case_id"],
                "difficultyLevel": case["difficulty_level"],
                "difficulty": case["difficulty"],
                "workflowId": case["workflow_id"],
                "turnIndex": case["turn_index"],
                "category": case["category"],
                "question": case["question"],
                "actualAnswer": "",
                "classification": "EVALUATOR_ERROR",
                "passed": False,
                "error": str(exception or "Không xác định"),
                "scores": {},
                "durationSeconds": 0.0,
            }
        results_by_id[case["id"]] = result
        if args.history_mode == "actual":
            actual[case["workflow_id"]].extend(
                [
                    {"role": "user", "content": case["question"]},
                    {
                        "role": "assistant",
                        "content": result.get("actualAnswer")
                        or "Không thể hoàn tất lượt trước.",
                    },
                ]
            )
        ordered_results = [
            results_by_id[selected["id"]]
            for selected in cases
            if selected["id"] in results_by_id
        ]
        report = build_report(
            dataset,
            ordered_results,
            cases,
            preflight,
            selection,
            time.time() - started,
        )
        write_checkpoint(output_path, report)

    ordered_results = [
        results_by_id[selected["id"]]
        for selected in cases
        if selected["id"] in results_by_id
    ]
    report = build_report(
        dataset,
        ordered_results,
        cases,
        preflight,
        selection,
        time.time() - started,
    )
    write_checkpoint(output_path, report)
    print(json.dumps({"summary": report["summary"], "levels": report["levels"]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
