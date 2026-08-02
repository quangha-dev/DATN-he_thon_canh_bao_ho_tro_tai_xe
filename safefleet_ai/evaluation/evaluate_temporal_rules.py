"""Evaluate event-level temporal detection metrics on JSONL sequences."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from service.temporal import Observation, TemporalSafetyDetector  # noqa: E402


def safe_ratio(numerator: int, denominator: int) -> float:
    return numerator / denominator if denominator else 1.0


def evaluate(path: Path) -> dict[str, float | int]:
    detector = TemporalSafetyDetector()
    true_positive = false_positive = false_negative = 0
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw.strip():
            continue
        row = json.loads(raw)
        detections = detector.ingest(
            Observation(
                timestamp_seconds=float(row["timestampSeconds"]),
                speed_kph=float(row.get("speedKph", 0)),
                left_eye_open=row.get("leftEyeOpen"),
                right_eye_open=row.get("rightEyeOpen"),
                head_pitch_degrees=float(row.get("headPitchDegrees", 0)),
                head_yaw_degrees=float(row.get("headYawDegrees", 0)),
                mouth_open_ratio=float(row.get("mouthOpenRatio", 0)),
                phone_confidence=float(row.get("phoneConfidence", 0)),
                fixed_device=bool(row.get("fixedDevice", False)),
            )
        )
        expected = set(row.get("expectedDetections", []))
        actual = {item.type.value for item in detections}
        true_positive += len(expected & actual)
        false_positive += len(actual - expected)
        false_negative += len(expected - actual)
    precision = safe_ratio(true_positive, true_positive + false_positive)
    recall = safe_ratio(true_positive, true_positive + false_negative)
    return {
        "truePositive": true_positive,
        "falsePositive": false_positive,
        "falseNegative": false_negative,
        "precision": precision,
        "recall": recall,
        "f1": safe_ratio(2 * precision * recall, precision + recall),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", type=Path, required=True)
    parser.add_argument("--minimum-f1", type=float, default=0.75)
    args = parser.parse_args()
    metrics = evaluate(args.dataset)
    print(json.dumps(metrics))
    if float(metrics["f1"]) < args.minimum_f1:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
