from __future__ import annotations

import json
import math
from pathlib import Path
from statistics import mean, pstdev
from typing import Any


HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "acceptance_summary_2026-08-28.json"


def wilson(successes: int, total: int, z: float = 1.96) -> list[float]:
    if total == 0:
        return [0.0, 0.0]
    p = successes / total
    denominator = 1 + z * z / total
    center = (p + z * z / (2 * total)) / denominator
    margin = z * math.sqrt((p * (1 - p) + z * z / (4 * total)) / total) / denominator
    return [round(center - margin, 4), round(center + margin, 4)]


def load(name: str) -> dict[str, Any]:
    return json.loads((HERE / name).read_text(encoding="utf-8"))


def main() -> None:
    gold = load("acceptance_gold_release_final_2026-08-28.json")
    guard = load("guardrail_acceptance_final_2026-08-28.json")
    rag = load("acceptance_rag_ragas_style_2026-08-28.json")
    stability = [load(f"acceptance_stability_run_{index}_2026-08-28.json") for index in range(1, 4)]
    judge_path = HERE / "llm_judge_acceptance_2026-08-28.json"
    judge = json.loads(judge_path.read_text(encoding="utf-8")) if judge_path.exists() else None
    run_rates = [float(item["summary"]["passRate"]) for item in stability]
    latencies = [float(item["summary"]["averageLatencySeconds"]) for item in stability]
    runtime = gold["runtimeMetrics"]
    official_input_rate = 0.15
    official_output_rate = 0.60
    estimated_cost = (
        int(runtime["inputTokens"]) * official_input_rate
        + int(runtime["outputTokens"]) * official_output_rate
    ) / 1_000_000
    judge_summary = judge["summary"] if judge else {}
    judge_cost = (
        int(judge_summary.get("inputTokens") or 0) * official_input_rate
        + int(judge_summary.get("outputTokens") or 0) * official_output_rate
    ) / 1_000_000
    payload: dict[str, Any] = {
        "status": "COMPLETED" if judge and judge.get("status") == "COMPLETED" else "IN_PROGRESS",
        "gold": {
            "total": gold["summary"]["total"],
            "passed": gold["summary"]["passed"],
            "passRate": gold["summary"]["passRate"],
            "wilson95": wilson(gold["summary"]["passed"], gold["summary"]["total"]),
            "averageScores": gold["summary"]["averageScores"],
            "performance": gold["performanceMetrics"],
        },
        "stability": {
            "runs": len(stability),
            "casesPerRun": stability[0]["summary"]["total"],
            "totalObservations": sum(item["summary"]["total"] for item in stability),
            "totalPassed": sum(item["summary"]["passed"] for item in stability),
            "meanPassRate": round(mean(run_rates), 4),
            "passRateStdDev": round(pstdev(run_rates), 4),
            "wilson95": wilson(
                sum(item["summary"]["passed"] for item in stability),
                sum(item["summary"]["total"] for item in stability),
            ),
            "meanLatencySeconds": round(mean(latencies), 3),
            "latencyStdDevSeconds": round(pstdev(latencies), 3),
        },
        "guardrails": guard["summary"],
        "ragasStyle": rag["summary"],
        "llmJudge": judge_summary if judge else None,
        "evalCost": {
            "model": "gpt-4o-mini",
            "inputTokens": runtime["inputTokens"],
            "outputTokens": runtime["outputTokens"],
            "totalTokens": runtime["totalTokens"],
            "modelCalls": runtime["modelCalls"],
            "inputUsdPerMillion": official_input_rate,
            "outputUsdPerMillion": official_output_rate,
            "estimatedModelCostUsd": round(estimated_cost, 8),
            "llmJudgeCostUsd": round(judge_cost, 8),
            "totalAcceptanceAndJudgeCostUsd": round(estimated_cost + judge_cost, 8),
            "wallClockSeconds": gold["summary"]["durationSeconds"],
            "averageSecondsPerCase": gold["summary"]["averageLatencySeconds"],
        },
    }
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
