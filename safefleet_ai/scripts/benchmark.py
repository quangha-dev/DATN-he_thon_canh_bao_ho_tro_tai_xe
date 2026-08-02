"""CPU benchmark for the deterministic temporal inference stage."""

from __future__ import annotations

import json
import statistics
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from service.temporal import Observation, TemporalSafetyDetector  # noqa: E402


def main() -> None:
    detector = TemporalSafetyDetector()
    durations: list[float] = []
    for index in range(10_000):
        observation = Observation(
            timestamp_seconds=index * 0.5,
            speed_kph=35,
            left_eye_open=0.8 if index % 20 else 0.1,
            right_eye_open=0.8 if index % 20 else 0.1,
            phone_confidence=0.1,
        )
        started = time.perf_counter()
        detector.ingest(observation)
        durations.append((time.perf_counter() - started) * 1000)
    ordered = sorted(durations)
    report = {
        "observations": len(durations),
        "meanMs": statistics.fmean(durations),
        "p95Ms": ordered[int(len(ordered) * 0.95)],
        "maxMs": max(durations),
    }
    print(json.dumps(report))
    if report["p95Ms"] > 10:
        raise SystemExit("Temporal inference p95 exceeds 10 ms")


if __name__ == "__main__":
    main()
