from __future__ import annotations

import argparse
import json
import math
import re
import unicodedata
from collections import Counter
from pathlib import Path
from typing import Any


def load_dataset(path: str | Path) -> list[dict[str, Any]]:
    with Path(path).open(encoding="utf-8") as stream:
        return [json.loads(line) for line in stream if line.strip()]


def tool_score(actual: list[str], expected: list[str], forbidden: list[str]) -> float:
    actual_set, expected_set = set(actual), set(expected)
    if actual_set.intersection(forbidden):
        return 0.0
    if not expected_set:
        return 1.0 if not actual_set else 0.0
    precision = len(actual_set & expected_set) / max(1, len(actual_set))
    recall = len(actual_set & expected_set) / len(expected_set)
    return 0.0 if precision + recall == 0 else 2 * precision * recall / (precision + recall)


def semantic_similarity(left: str, right: str) -> float:
    """Offline cosine baseline; can be replaced by an embedding scorer later."""
    a, b = Counter(_tokens(left)), Counter(_tokens(right))
    if not a or not b:
        return 0.0
    dot = sum(value * b[token] for token, value in a.items())
    norm_a = math.sqrt(sum(value * value for value in a.values()))
    norm_b = math.sqrt(sum(value * value for value in b.values()))
    return dot / (norm_a * norm_b)


def evaluate_case(case: dict[str, Any], actual_tools: list[str], answer: str) -> dict[str, Any]:
    return {
        "id": case["id"],
        "toolScore": tool_score(
            actual_tools,
            case.get("expected_tools", []),
            case.get("forbidden_tools", []),
        ),
        "semanticSimilarity": semantic_similarity(answer, case.get("expected_answer", "")),
    }


def _tokens(value: str) -> list[str]:
    normalized = unicodedata.normalize("NFD", value.lower().replace("đ", "d"))
    normalized = "".join(character for character in normalized if unicodedata.category(character) != "Mn")
    return re.findall(r"[a-z0-9]+", normalized)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("dataset")
    parser.add_argument("results", help="JSONL: id, actual_tools, answer")
    args = parser.parse_args()
    gold = {case["id"]: case for case in load_dataset(args.dataset)}
    results = load_dataset(args.results)
    scores = [
        evaluate_case(gold[item["id"]], item.get("actual_tools", []), item.get("answer", ""))
        for item in results
    ]
    print(json.dumps(scores, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
