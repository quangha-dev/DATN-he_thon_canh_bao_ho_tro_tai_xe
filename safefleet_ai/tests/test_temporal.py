from service.temporal import (
    DetectionType,
    Observation,
    TemporalSafetyDetector,
)
from training.train_temporal_rules import calibrate, load_rows
from pathlib import Path


def test_eye_closure_and_cooldown() -> None:
    detector = TemporalSafetyDetector()
    assert detector.ingest(
        Observation(0.0, 40, left_eye_open=0.1, right_eye_open=0.1)
    ) == []
    detection = detector.ingest(
        Observation(2.1, 40, left_eye_open=0.1, right_eye_open=0.1)
    )
    assert detection[0].type is DetectionType.DROWSINESS
    assert detector.ingest(
        Observation(3.0, 40, left_eye_open=0.1, right_eye_open=0.1)
    ) == []


def test_phone_requires_motion_duration_and_non_fixed_device() -> None:
    detector = TemporalSafetyDetector()
    detector.ingest(Observation(0.0, 35, phone_confidence=0.9))
    detection = detector.ingest(Observation(2.1, 35, phone_confidence=0.9))
    assert detection[0].type is DetectionType.PHONE_USAGE

    fixed = TemporalSafetyDetector()
    fixed.ingest(Observation(0.0, 35, phone_confidence=0.9, fixed_device=True))
    assert fixed.ingest(
        Observation(3.0, 35, phone_confidence=0.9, fixed_device=True)
    ) == []


def test_training_calibration_is_deterministic() -> None:
    path = Path(__file__).resolve().parents[1] / "training" / "sample_observations.jsonl"
    first = calibrate(load_rows(path))
    second = calibrate(load_rows(path))
    assert first == second
    assert first["eyeBalancedAccuracy"] == 1.0
    assert first["phoneBalancedAccuracy"] == 1.0
