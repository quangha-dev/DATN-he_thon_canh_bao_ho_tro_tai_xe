from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from enum import Enum


class DetectionType(str, Enum):
    DROWSINESS = "DROWSINESS"
    PHONE_USAGE = "PHONE_USAGE"


@dataclass(frozen=True)
class Observation:
    timestamp_seconds: float
    speed_kph: float
    left_eye_open: float | None = None
    right_eye_open: float | None = None
    head_pitch_degrees: float = 0.0
    head_yaw_degrees: float = 0.0
    mouth_open_ratio: float = 0.0
    phone_confidence: float = 0.0
    fixed_device: bool = False


@dataclass(frozen=True)
class Detection:
    type: DetectionType
    confidence: float
    reason: str
    timestamp_seconds: float


class TemporalSafetyDetector:
    def __init__(
        self,
        *,
        eye_open_threshold: float = 0.25,
        eye_closed_seconds: float = 2.0,
        perclos_window_seconds: float = 30.0,
        perclos_threshold: float = 0.4,
        phone_threshold: float = 0.65,
        minimum_speed_kph: float = 5.0,
        phone_duration_seconds: float = 2.0,
        cooldown_seconds: float = 30.0,
    ) -> None:
        self.eye_open_threshold = eye_open_threshold
        self.eye_closed_seconds = eye_closed_seconds
        self.perclos_window_seconds = perclos_window_seconds
        self.perclos_threshold = perclos_threshold
        self.phone_threshold = phone_threshold
        self.minimum_speed_kph = minimum_speed_kph
        self.phone_duration_seconds = phone_duration_seconds
        self.cooldown_seconds = cooldown_seconds
        self._eyes_closed_since: float | None = None
        self._phone_since: float | None = None
        self._eye_history: deque[tuple[float, bool]] = deque()
        self._last_detection: dict[DetectionType, float] = {}

    def ingest(self, observation: Observation) -> list[Detection]:
        detections: list[Detection] = []
        eye_values = [
            value
            for value in (observation.left_eye_open, observation.right_eye_open)
            if value is not None
        ]
        if eye_values:
            eye_open = sum(eye_values) / len(eye_values)
            closed = eye_open < self.eye_open_threshold
            self._eye_history.append((observation.timestamp_seconds, closed))
            cutoff = observation.timestamp_seconds - self.perclos_window_seconds
            while self._eye_history and self._eye_history[0][0] < cutoff:
                self._eye_history.popleft()
            if closed:
                if self._eyes_closed_since is None:
                    self._eyes_closed_since = observation.timestamp_seconds
            else:
                self._eyes_closed_since = None

        perclos = (
            sum(1 for _, closed in self._eye_history if closed) / len(self._eye_history)
            if self._eye_history
            else 0.0
        )
        closed_long = (
            self._eyes_closed_since is not None
            and observation.timestamp_seconds - self._eyes_closed_since
            >= self.eye_closed_seconds
        )
        repeated_microsleeps = len(self._eye_history) >= 6 and perclos >= self.perclos_threshold
        pose_and_yawn = (
            max(abs(observation.head_pitch_degrees), abs(observation.head_yaw_degrees))
            >= 25.0
            and observation.mouth_open_ratio >= 0.09
        )
        if closed_long or repeated_microsleeps or pose_and_yawn:
            reason = (
                "continuous eye closure"
                if closed_long
                else f"PERCLOS {perclos:.2f}"
                if repeated_microsleeps
                else "yawn with abnormal head pose"
            )
            self._emit(
                detections,
                Detection(
                    DetectionType.DROWSINESS,
                    min(0.98, 0.92 if closed_long else 0.75 + perclos * 0.2),
                    reason,
                    observation.timestamp_seconds,
                ),
            )

        phone_candidate = (
            not observation.fixed_device
            and observation.speed_kph >= self.minimum_speed_kph
            and observation.phone_confidence >= self.phone_threshold
        )
        if phone_candidate:
            if self._phone_since is None:
                self._phone_since = observation.timestamp_seconds
        else:
            self._phone_since = None
        if (
            self._phone_since is not None
            and observation.timestamp_seconds - self._phone_since
            >= self.phone_duration_seconds
        ):
            self._emit(
                detections,
                Detection(
                    DetectionType.PHONE_USAGE,
                    min(1.0, max(0.0, observation.phone_confidence)),
                    "phone visible while vehicle is moving",
                    observation.timestamp_seconds,
                ),
            )
        return detections

    def _emit(self, target: list[Detection], detection: Detection) -> None:
        previous = self._last_detection.get(detection.type)
        if previous is not None and detection.timestamp_seconds - previous < self.cooldown_seconds:
            return
        self._last_detection[detection.type] = detection.timestamp_seconds
        target.append(detection)
