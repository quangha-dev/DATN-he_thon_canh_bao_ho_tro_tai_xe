from __future__ import annotations

import argparse
import json
import unicodedata
from pathlib import Path


ROOT = Path(__file__).resolve().parent
GROUND_TRUTH_PATH = ROOT / "fixtures" / "ground_truth.json"


def normalize(value: str) -> str:
    return " ".join(unicodedata.normalize("NFC", value).strip().split())


def levenshtein(reference: list[str], hypothesis: list[str]) -> int:
    previous = list(range(len(hypothesis) + 1))
    for row, expected in enumerate(reference, start=1):
        current = [row]
        for column, actual in enumerate(hypothesis, start=1):
            current.append(
                min(
                    current[-1] + 1,
                    previous[column] + 1,
                    previous[column - 1] + (expected != actual),
                )
            )
        previous = current
    return previous[-1]


def score(expected: str, actual: str) -> dict[str, object]:
    expected = normalize(expected)
    actual = normalize(actual)
    char_distance = levenshtein(list(expected), list(actual))
    word_distance = levenshtein(expected.split(), actual.split())
    return {
        "actual": actual,
        "exact_match": actual == expected,
        "cer": char_distance / max(1, len(expected)),
        "wer": word_distance / max(1, len(expected.split())),
        "character_edits": char_distance,
        "word_edits": word_distance,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--results", type=Path, default=ROOT / "results")
    parser.add_argument("--output", type=Path, default=ROOT / "results" / "comparison.json")
    args = parser.parse_args()

    expected = json.loads(GROUND_TRUTH_PATH.read_text(encoding="utf-8"))["fields"][
        "project_address"
    ]
    reports: dict[str, object] = {}
    for result_path in sorted(args.results.glob("*.json")):
        if result_path.name == args.output.name:
            continue
        payload = json.loads(result_path.read_text(encoding="utf-8"))
        actual = payload.get("fields", {}).get("project_address", "")
        reports[result_path.stem] = {
            **score(expected, actual),
            "elapsed_ms": payload.get("elapsed_ms"),
            "engine": payload.get("engine", result_path.stem),
        }

    output = {
        "fixture": "phieutest.jpg",
        "expected": expected,
        "results": reports,
        "pass": any(item["exact_match"] for item in reports.values()),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 0 if output["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
