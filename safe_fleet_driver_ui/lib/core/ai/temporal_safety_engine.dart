enum SafetyDetectionType { drowsiness, phoneUsage }

enum DrowsinessModelMode { stgtTflite, mlKitTemporal }

extension DrowsinessModelModeLabel on DrowsinessModelMode {
  String get label => switch (this) {
    DrowsinessModelMode.stgtTflite => 'STGT học sâu',
    DrowsinessModelMode.mlKitTemporal => 'ML Kit luật thời gian',
  };
}

class CabinObservation {
  const CabinObservation({
    required this.at,
    required this.speedKph,
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.headPitchDegrees = 0,
    this.headYawDegrees = 0,
    this.headRollDegrees = 0,
    this.mouthOpenRatio = 0,
    this.irisMovement = 0,
    this.phoneConfidence = 0,
    this.fixedDevice = false,
  });

  final DateTime at;
  final double speedKph;
  final double? leftEyeOpen;
  final double? rightEyeOpen;
  final double headPitchDegrees;
  final double headYawDegrees;
  final double headRollDegrees;
  final double mouthOpenRatio;
  final double irisMovement;
  final double phoneConfidence;
  final bool fixedDevice;

  double? get averageEyeOpen {
    if (leftEyeOpen == null && rightEyeOpen == null) return null;
    if (leftEyeOpen == null) return rightEyeOpen;
    if (rightEyeOpen == null) return leftEyeOpen;
    return (leftEyeOpen! + rightEyeOpen!) / 2;
  }
}

class SafetyDetection {
  const SafetyDetection({
    required this.type,
    required this.confidence,
    required this.severity,
    required this.reason,
    required this.detectedAt,
    this.source = 'mlkit-temporal',
  });

  final SafetyDetectionType type;
  final double confidence;
  final String severity;
  final String reason;
  final DateTime detectedAt;
  final String source;

  String get apiEventType => switch (type) {
    SafetyDetectionType.drowsiness => 'DROWSINESS',
    SafetyDetectionType.phoneUsage => 'PHONE_USAGE',
  };
}

class TemporalSafetyEngine {
  TemporalSafetyEngine({
    this.eyeOpenThreshold = 0.16,
    this.eyeClosedDuration = const Duration(milliseconds: 1500),
    this.perclosWindow = const Duration(seconds: 30),
    this.perclosThreshold = 0.4,
    this.headPoseThresholdDegrees = 25,
    this.yawnMouthRatio = 0.6,
    this.phoneConfidenceThreshold = 0.65,
    this.minimumDrivingSpeedKph = 5,
    this.phoneDuration = const Duration(seconds: 2),
    this.cooldown = const Duration(seconds: 30),
    this.drowsinessEnabled = true,
  });

  final double eyeOpenThreshold;
  final Duration eyeClosedDuration;
  final Duration perclosWindow;
  final double perclosThreshold;
  final double headPoseThresholdDegrees;
  final double yawnMouthRatio;
  final double phoneConfidenceThreshold;
  final double minimumDrivingSpeedKph;
  final Duration phoneDuration;
  final Duration cooldown;
  final bool drowsinessEnabled;

  final List<({DateTime at, bool closed})> _eyeHistory = [];
  final Map<SafetyDetectionType, DateTime> _lastDetection = {};
  DateTime? _eyesClosedSince;
  DateTime? _phoneSince;

  List<SafetyDetection> ingest(CabinObservation observation) {
    final detections = <SafetyDetection>[];
    final eyeOpen = observation.averageEyeOpen;
    if (eyeOpen != null) {
      final closed = eyeOpen < eyeOpenThreshold;
      _eyeHistory.add((at: observation.at, closed: closed));
      _eyeHistory.removeWhere(
        (entry) => observation.at.difference(entry.at) > perclosWindow,
      );
      _eyesClosedSince = closed ? (_eyesClosedSince ?? observation.at) : null;
    }

    final perclos = _eyeHistory.isEmpty
        ? 0.0
        : _eyeHistory.where((entry) => entry.closed).length /
              _eyeHistory.length;
    final eyesClosedLongEnough =
        _eyesClosedSince != null &&
        observation.at.difference(_eyesClosedSince!) >= eyeClosedDuration;
    final perclosRisk = _eyeHistory.length >= 6 && perclos >= perclosThreshold;
    final poseRisk =
        observation.headPitchDegrees.abs() >= headPoseThresholdDegrees ||
        observation.headYawDegrees.abs() >= headPoseThresholdDegrees;
    final yawnRisk = observation.mouthOpenRatio >= yawnMouthRatio;

    if (drowsinessEnabled &&
        (eyesClosedLongEnough || perclosRisk || (poseRisk && yawnRisk))) {
      final reason = eyesClosedLongEnough
          ? 'Mắt nhắm liên tục ${observation.at.difference(_eyesClosedSince!).inMilliseconds / 1000}s'
          : perclosRisk
          ? 'PERCLOS ${(perclos * 100).round()}% trong cửa sổ ${perclosWindow.inSeconds}s'
          : 'Ngáp kết hợp tư thế đầu bất thường';
      final confidence = eyesClosedLongEnough
          ? 0.92
          : perclosRisk
          ? (0.75 + perclos * 0.2).clamp(0.0, 0.98)
          : 0.82;
      _emit(
        detections,
        SafetyDetection(
          type: SafetyDetectionType.drowsiness,
          confidence: confidence,
          severity: 'HIGH',
          reason: reason,
          detectedAt: observation.at,
        ),
      );
    }

    final phoneCandidate =
        !observation.fixedDevice &&
        observation.speedKph >= minimumDrivingSpeedKph &&
        observation.phoneConfidence >= phoneConfidenceThreshold;
    _phoneSince = phoneCandidate ? (_phoneSince ?? observation.at) : null;
    if (_phoneSince != null &&
        observation.at.difference(_phoneSince!) >= phoneDuration) {
      _emit(
        detections,
        SafetyDetection(
          type: SafetyDetectionType.phoneUsage,
          confidence: observation.phoneConfidence.clamp(0.0, 1.0),
          severity: 'HIGH',
          reason:
              'Điện thoại xuất hiện khi xe chạy ${observation.speedKph.toStringAsFixed(0)} km/h',
          detectedAt: observation.at,
        ),
      );
    }
    return detections;
  }

  void reset() {
    _eyeHistory.clear();
    _lastDetection.clear();
    _eyesClosedSince = null;
    _phoneSince = null;
  }

  void _emit(List<SafetyDetection> target, SafetyDetection detection) {
    final previous = _lastDetection[detection.type];
    if (previous != null &&
        detection.detectedAt.difference(previous) < cooldown) {
      return;
    }
    _lastDetection[detection.type] = detection.detectedAt;
    target.add(detection);
  }
}
