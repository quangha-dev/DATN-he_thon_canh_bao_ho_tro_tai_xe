from __future__ import annotations

import argparse
import json
import os
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from evaluate_agent_gold import semantic_similarity, tool_score


def _request(
    url: str,
    method: str,
    payload: dict[str, Any] | None = None,
    token: str | None = None,
    timeout: int = 180,
) -> dict[str, Any]:
    body = None if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
    headers = {"Accept": "application/json", "Content-Type": "application/json; charset=utf-8"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exception:
        detail = exception.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exception.code}: {detail}") from exception


def _normalize(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: _normalize(item) for key, item in sorted(value.items())}
    if isinstance(value, list):
        return [_normalize(item) for item in value]
    return value


def _argument_score(expected: list[dict[str, Any]], actual: list[dict[str, Any]]) -> float:
    if not expected:
        return 1.0 if not actual else 0.0
    matched = 0
    consumed: set[int] = set()
    for wanted in expected:
        for index, received in enumerate(actual):
            if index in consumed or received["name"] != wanted["name"]:
                continue
            if _normalize(received["arguments"]) == _normalize(wanted.get("arguments", {})):
                matched += 1
                consumed.add(index)
                break
    return matched / len(expected)


def _order_score(expected: list[str], actual: list[str]) -> float:
    if not expected:
        return 1.0 if not actual else 0.0
    cursor = 0
    for tool in actual:
        if cursor < len(expected) and tool == expected[cursor]:
            cursor += 1
    return cursor / len(expected)


def _fact_coverage(answer: str, facts: list[str]) -> tuple[float, list[str]]:
    if not facts:
        return 1.0, []
    missing = [fact for fact in facts if semantic_similarity(answer, fact) < 0.22]
    return (len(facts) - len(missing)) / len(facts), missing


def _actual_calls(steps: list[dict[str, Any]]) -> list[dict[str, Any]]:
    calls: list[dict[str, Any]] = []
    for step in steps:
        raw = step.get("arguments") or "{}"
        try:
            arguments = json.loads(raw) if isinstance(raw, str) else raw
        except json.JSONDecodeError:
            arguments = {"_invalid": raw}
        calls.append(
            {
                "name": str(step.get("tool") or ""),
                "arguments": arguments,
                "success": bool(step.get("success")),
                "planCheck": step.get("planCheck"),
                "reason": step.get("reason"),
            }
        )
    return calls


def _failure_reasons(
    case: dict[str, Any],
    response: dict[str, Any],
    calls: list[dict[str, Any]],
    scores: dict[str, float],
    missing_facts: list[str],
) -> list[str]:
    reasons: list[str] = []
    forbidden = set(case.get("forbidden_tools", []))
    actual_names = {call["name"] for call in calls}
    if actual_names & forbidden:
        reasons.append("FORBIDDEN_TOOL_CALLED")
    if scores["toolSelection"] < 1.0:
        reasons.append("TOOL_SELECTION_MISMATCH")
    if scores["toolArguments"] < 1.0:
        reasons.append("TOOL_ARGUMENT_MISMATCH")
    if scores["toolOrder"] < 1.0:
        reasons.append("TOOL_ORDER_MISMATCH")
    if any(not call["success"] for call in calls):
        reasons.append("TOOL_EXECUTION_FAILED")
    if response.get("status") not in {"COMPLETED", "AWAITING_CONFIRMATION"}:
        reasons.append(f"AGENT_STATUS_{response.get('status') or 'MISSING'}")
    if scores["semanticSimilarity"] < 0.8:
        reasons.append("ANSWER_SEMANTIC_MISMATCH")
    if missing_facts:
        reasons.append("EXPECTED_FACTS_MISSING")
    return reasons


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("dataset")
    parser.add_argument("output")
    parser.add_argument("--base-url", default="http://localhost:8080/api/v1")
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()

    username = os.environ.get("SAFEFLEET_EVAL_USERNAME")
    password = os.environ.get("SAFEFLEET_EVAL_PASSWORD")
    if not username or not password:
        raise SystemExit("Cần SAFEFLEET_EVAL_USERNAME và SAFEFLEET_EVAL_PASSWORD")

    dataset = json.loads(Path(args.dataset).read_text(encoding="utf-8"))
    login = _request(
        f"{args.base_url}/auth/login",
        "POST",
        {"usernameOrEmail": username, "password": password},
        timeout=args.timeout,
    )
    token = str((login.get("data") or {}).get("accessToken") or "")
    if not token:
        raise SystemExit("Đăng nhập không trả access token")

    results: list[dict[str, Any]] = []
    started = time.time()
    for index, case in enumerate(dataset["qa_pairs"], start=1):
        print(f"[{index:02d}/{len(dataset['qa_pairs'])}] {case['id']}", flush=True)
        before = time.time()
        try:
            envelope = _request(
                f"{args.base_url}/mobile/agent/chat",
                "POST",
                {"messages": [{"role": "user", "content": case["question"]}]},
                token=token,
                timeout=args.timeout,
            )
            response = envelope.get("data") or {}
            calls = _actual_calls(response.get("steps") or [])
            expected_calls = case.get("expected_tool_calls", [])
            expected_names = [item["name"] for item in expected_calls]
            actual_names = [item["name"] for item in calls]
            answer = str(response.get("responseText") or "")
            fact_coverage, missing_facts = _fact_coverage(
                answer, case.get("expected_facts", [])
            )
            scores = {
                "toolSelection": tool_score(
                    actual_names, expected_names, case.get("forbidden_tools", [])
                ),
                "toolArguments": _argument_score(expected_calls, calls),
                "toolOrder": _order_score(expected_names, actual_names),
                "semanticSimilarity": semantic_similarity(
                    answer, case.get("expected_answer", "")
                ),
                "factCoverage": fact_coverage,
            }
            failures = _failure_reasons(case, response, calls, scores, missing_facts)
            results.append(
                {
                    "id": case["id"],
                    "question": case["question"],
                    "status": response.get("status"),
                    "plan": response.get("plan") or [],
                    "expectedToolCalls": expected_calls,
                    "actualToolCalls": calls,
                    "expectedAnswer": case.get("expected_answer"),
                    "actualAnswer": answer,
                    "scores": scores,
                    "missingFacts": missing_facts,
                    "failureReasons": failures,
                    "passed": not failures,
                    "durationSeconds": round(time.time() - before, 3),
                }
            )
        except Exception as exception:  # noqa: BLE001 - evaluator must keep running
            results.append(
                {
                    "id": case["id"],
                    "question": case["question"],
                    "passed": False,
                    "failureReasons": ["API_REQUEST_FAILED"],
                    "error": str(exception),
                    "durationSeconds": round(time.time() - before, 3),
                }
            )

    passed = sum(1 for item in results if item["passed"])
    reason_counts: dict[str, int] = {}
    for result in results:
        for reason in result.get("failureReasons", []):
            reason_counts[reason] = reason_counts.get(reason, 0) + 1
    report = {
        "dataset": dataset["corpus_id"],
        "mode": "LIVE_BACKEND",
        "baseUrl": args.base_url,
        "summary": {
            "total": len(results),
            "passed": passed,
            "failed": len(results) - passed,
            "passRate": round(passed / max(1, len(results)), 4),
            "durationSeconds": round(time.time() - started, 3),
            "failureReasonCounts": reason_counts,
        },
        "results": results,
    }
    Path(args.output).write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(report["summary"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
