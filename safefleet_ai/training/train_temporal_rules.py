"""Calibrate SafeFleet temporal thresholds from labelled JSONL observations."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def load_rows(path: Path) -> list[dict[str, object]]:
    rows = [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    if not rows:
        raise ValueError("training dataset is empty")
    return rows


def balanced_accuracy(rows: list[dict[str, object]], field: str, threshold: float) -> float:
    true_positive = true_negative = positive = negative = 0
    label_field = "drowsy" if field == "eyeOpen" else "phoneUsage"
    for row in rows:
        expected = bool(row[label_field])
        value = float(row[field])
        predicted = value < threshold if field == "eyeOpen" else value >= threshold
        if expected:
            positive += 1
            true_positive += int(predicted)
        else:
            negative += 1
            true_negative += int(not predicted)
    sensitivity = true_positive / positive if positive else 1.0
    specificity = true_negative / negative if negative else 1.0
    return (sensitivity + specificity) / 2


def calibrate(rows: list[dict[str, object]]) -> dict[str, float]:
    eye_candidates = [value / 100 for value in range(15, 41)]
    phone_candidates = [value / 100 for value in range(45, 91)]
    eye = max(
        eye_candidates,
        key=lambda value: (balanced_accuracy(rows, "eyeOpen", value), -value),
    )
    phone = max(
        phone_candidates,
        key=lambda value: (balanced_accuracy(rows, "phoneConfidence", value), value),
    )
    return {
        "eyeOpenThreshold": eye,
        "phoneConfidenceThreshold": phone,
        "eyeBalancedAccuracy": balanced_accuracy(rows, "eyeOpen", eye),
        "phoneBalancedAccuracy": balanced_accuracy(rows, "phoneConfidence", phone),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", type=Path, required=True)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("models/calibration.json"),
    )
    args = parser.parse_args()
    result = calibrate(load_rows(args.dataset))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result))


if __name__ == "__main__":
    main()
