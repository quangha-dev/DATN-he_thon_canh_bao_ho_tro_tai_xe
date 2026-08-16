import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'temporal_safety_engine.dart';

typedef StgtScorePredictor = double Function(List<List<double>> rows);

int drowsinessRiskLevel(double score) {
  if (!score.isFinite) return 1;
  return score.clamp(0.0, 10.0).ceil().clamp(1, 10).toInt();
}

String drowsinessRiskLabel(int level) => switch (level.clamp(1, 10)) {
  <= 3 => 'Tỉnh táo',
  <= 5 => 'Cần chú ý',
  <= 7 => 'Nguy hiểm',
  _ => 'Báo động',
};

class StgtDrowsinessEngine {
  StgtDrowsinessEngine({
    this.scorePredictor,
    this.baselineStorage,
    this.calibrationFrames = 75,
    this.windowSize = 75,
    this.inferenceInterval = 5,
    this.dangerScore = 6,
    this.cooldown = const Duration(seconds: 20),
  });

  static const assetPath = 'assets/models/drowsiness_model.tflite';
  static const modelSource = 'stgt-fold-1-tflite';
  static const _baselineKey = 'cabin_mesh468_stgt25_baseline_v3';
  static const _featureExtractorVersion = 'mlkit-face-mesh-468-stgt25-v3';
  static const _samplePeriod = Duration(milliseconds: 40);
  static const _maximumInterpolationGap = Duration(milliseconds: 440);
  static const _minimumStandardDeviation = [0.003, 0.01, 0.5, 0.5, 0.5, 0.003];

  final int calibrationFrames;
  final int windowSize;
  final int inferenceInterval;
  final double dangerScore;
  final Duration cooldown;
  final StgtScorePredictor? scorePredictor;
  final FlutterSecureStorage? baselineStorage;

  final List<List<double>> _calibration = [];
  final List<List<double>?> _window = [];
  final List<double> _scoreHistory = [];
  Interpreter? _interpreter;
  List<double>? _mean;
  List<double>? _standardDeviation;
  DateTime? _lastDetection;
  DateTime? _holdUntil;
  DateTime? _lastObservationAt;
  DateTime? _nextSampleAt;
  List<double>? _lastObservedFeatures;
  int _framesSinceCalibration = 0;
  int _lastInferenceFrame = 0;
  double _rawScore = 0;
  double _smoothedScore = 0;
  double _predictedScore = 0;
  double _trend = 0;
  double _drowsyAccumulator = 0;
  double? _liveEar;
  double? _liveMar;
  int _severity = 0;
  String _statusText = 'Đang chờ khuôn mặt';
  bool _initialized = false;

  bool get ready => scorePredictor != null || _interpreter != null;
  bool get calibrated => _mean != null && _standardDeviation != null;
  int get calibrationProgress =>
      math.min(_calibration.length, calibrationFrames);
  double get rawScore => _rawScore;
  double get score => _smoothedScore;
  double get predictedScore => _predictedScore;
  double get trend => _trend;
  double? get liveEar => _liveEar;
  double? get liveMar => _liveMar;
  int get severity => _severity;
  String get statusText => _statusText;
  List<double> get scoreHistory => List.unmodifiable(_scoreHistory);

  Future<void> initialize() async {
    if (_initialized) return;
    if (!ready) {
      final interpreter = await Interpreter.fromAsset(assetPath);
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;
      if (!_sameShape(inputShape, [1, windowSize, 12]) ||
          !_sameShape(outputShape, [1, 1])) {
        interpreter.close();
        throw StateError(
          'Sai tensor model: input=$inputShape, output=$outputShape',
        );
      }
      _interpreter = interpreter;
    }
    await _loadBaseline();
    _initialized = true;
  }

  List<SafetyDetection> ingest(CabinObservation observation) {
    final features = _features(observation);
    _liveEar = features?[0];
    _liveMar = features?[1];

    if (!ready) return const [];
    if (!calibrated) {
      if (features != null && _validCalibrationFrame(features)) {
        _calibration.add(features);
        _statusText = 'Đang hiệu chuẩn $calibrationProgress/$calibrationFrames';
        if (_calibration.length >= calibrationFrames) _finishCalibration();
      } else {
        _statusText = features == null
            ? 'Không tìm thấy đủ landmark khuôn mặt'
            : 'Nhìn thẳng, mở mắt tự nhiên để hiệu chuẩn';
      }
      return const [];
    }

    _appendResampledFeatures(observation.at, features);
    if (_window.length < windowSize ||
        _framesSinceCalibration - _lastInferenceFrame < inferenceInterval) {
      return const [];
    }
    _lastInferenceFrame = _framesSinceCalibration;

    final input = _buildModelInput();
    if (input == null) {
      _statusText = 'Không thấy rõ khuôn mặt';
      return const [];
    }

    var rawScore = _predict(input.rows).clamp(0.0, 10.0);
    var logicSeverity = 0;
    var logicMessage = 'Tỉnh táo · STGT đang theo dõi';

    // Same safety guardrails as the desktop pipeline. The desktop z-score
    // comparison used the wrong sign: a drooping eyelid lowers EAR, therefore
    // the normalized value must be negative.
    if (input.recentEar < 0.10) {
      rawScore = 10;
      logicSeverity = 3;
      logicMessage = 'Báo động · mắt nhắm sâu';
    } else if (input.recentMar > 0.60) {
      rawScore = math.max(rawScore, 6);
      logicSeverity = 2;
      logicMessage = 'Cảnh báo · phát hiện ngáp';
    } else if (input.recentEarZScore <= -2.2 && !input.headTurning) {
      rawScore = math.max(rawScore, 5);
      logicSeverity = 2;
      logicMessage = 'Cảnh báo · mí mắt sụp kéo dài';
    } else if (input.recentEarZScore > -0.5 && rawScore > 6) {
      rawScore = 2;
    }

    _updateScores(rawScore, logicSeverity, logicMessage, observation.at);
    if (_severity < 2 || !_cooldownElapsed(observation.at)) return const [];

    _lastDetection = observation.at;
    return [
      SafetyDetection(
        type: SafetyDetectionType.drowsiness,
        confidence: (_smoothedScore / 10).clamp(0.0, 1.0),
        severity: _severity >= 3 ? 'CRITICAL' : 'HIGH',
        reason: _statusText,
        detectedAt: observation.at,
        source: modelSource,
      ),
    ];
  }

  void reset() {
    _calibration.clear();
    _window.clear();
    _scoreHistory.clear();
    _mean = null;
    _standardDeviation = null;
    _lastDetection = null;
    _holdUntil = null;
    _lastObservationAt = null;
    _nextSampleAt = null;
    _lastObservedFeatures = null;
    _framesSinceCalibration = 0;
    _lastInferenceFrame = 0;
    _rawScore = 0;
    _smoothedScore = 0;
    _predictedScore = 0;
    _trend = 0;
    _drowsyAccumulator = 0;
    _liveEar = null;
    _liveMar = null;
    _severity = 0;
    _statusText = 'Đang chờ khuôn mặt';
    _initialized = false;
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    reset();
  }

  List<double>? _features(CabinObservation observation) {
    final eyeAspectRatio = observation.averageEyeOpen;
    if (eyeAspectRatio == null || !eyeAspectRatio.isFinite) return null;
    return [
      eyeAspectRatio,
      observation.mouthOpenRatio,
      observation.headPitchDegrees,
      observation.headYawDegrees,
      observation.headRollDegrees,
      observation.irisMovement,
    ];
  }

  bool _validCalibrationFrame(List<double> features) =>
      features[0] >= 0.18 &&
      features[0] <= 0.45 &&
      features[1] >= 0 &&
      features[1] < 0.55 &&
      features[2].abs() < 25 &&
      features[3].abs() < 25;

  void _finishCalibration() {
    _mean = List<double>.generate(6, (column) {
      return _calibration.map((row) => row[column]).reduce((a, b) => a + b) /
          _calibration.length;
    });
    _standardDeviation = List<double>.generate(6, (column) {
      final mean = _mean![column];
      final squared = _calibration
          .map((row) => math.pow(row[column] - mean, 2).toDouble())
          .reduce((a, b) => a + b);
      final sampleDeviation = math.sqrt(
        squared / math.max(1, _calibration.length - 1),
      );
      return math.max(_minimumStandardDeviation[column], sampleDeviation);
    });
    _statusText = 'Hiệu chuẩn hoàn tất · đang giám sát';
    final storage = baselineStorage;
    if (storage != null) {
      unawaited(
        storage.write(
          key: _baselineKey,
          value: jsonEncode({
            'mean': _mean,
            'std': _standardDeviation,
            'featureExtractor': _featureExtractorVersion,
            'samplePeriodMs': _samplePeriod.inMilliseconds,
          }),
        ),
      );
    }
  }

  Future<void> _loadBaseline() async {
    final storage = baselineStorage;
    if (storage == null) return;
    try {
      final raw = await storage.read(key: _baselineKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map ||
          decoded['featureExtractor'] != _featureExtractorVersion ||
          decoded['samplePeriodMs'] != _samplePeriod.inMilliseconds) {
        return;
      }
      final mean = (decoded['mean'] as List?)
          ?.map((value) => (value as num).toDouble())
          .toList();
      final deviation = (decoded['std'] as List?)
          ?.map((value) => (value as num).toDouble())
          .toList();
      if (mean?.length != 6 || deviation?.length != 6) return;
      if (mean!.any((value) => !value.isFinite) ||
          deviation!.any((value) => !value.isFinite || value <= 0)) {
        return;
      }
      _mean = mean;
      _standardDeviation = deviation;
      _statusText = 'Đã tải hiệu chuẩn cá nhân · đang giám sát';
    } catch (_) {
      // Corrupt or unavailable secure storage falls back to fresh calibration.
    }
  }

  _ModelInput? _buildModelInput() {
    final interpolated = _interpolateWindow();
    if (interpolated == null) return null;
    final smoothed = _savitzkyGolay(interpolated);
    final recentEar = _meanOf(smoothed, 0, 8);
    final recentMar = _meanOf(smoothed, 1, 8);
    final normalized = List.generate(windowSize, (row) {
      return List.generate(
        6,
        (column) =>
            (smoothed[row][column] - _mean![column]) /
            _standardDeviation![column],
      );
    });
    // Roughly 0.8 seconds at the fixed 25 FPS input rate. This ignores a
    // normal blink but reacts to the sustained partial closure requested by
    // the desktop behavior.
    final recentEarZScore = _meanOf(normalized, 0, 20);
    final recentPitchZScore = _meanOf(normalized, 2, 20);
    final recentYawZScore = _meanOf(normalized, 3, 20);
    final rows = List.generate(windowSize, (row) {
      final delta = List.generate(
        6,
        (column) => row == 0
            ? 0.0
            : normalized[row][column] - normalized[row - 1][column],
      );
      return [...normalized[row], ...delta];
    });
    return _ModelInput(
      rows: rows,
      recentEar: recentEar,
      recentMar: recentMar,
      recentEarZScore: recentEarZScore,
      headTurning: recentPitchZScore.abs() > 1.5 || recentYawZScore.abs() > 1.5,
    );
  }

  void _updateScores(
    double rawScore,
    int logicSeverity,
    String logicMessage,
    DateTime at,
  ) {
    _rawScore = rawScore;
    if (_smoothedScore == 0) {
      _smoothedScore = rawScore;
    } else if (logicSeverity >= 2 && rawScore > _smoothedScore) {
      // A sustained eyelid/yawn guardrail must be visible immediately on the
      // 1-10 gauge, not only in an invisible alert flag.
      _smoothedScore = rawScore;
    } else {
      // React within a few inference cycles. The former 0.01 upward factor
      // could hide a model score of 8/10 for tens of seconds.
      final factor = rawScore >= _smoothedScore ? 0.35 : 0.25;
      _smoothedScore = factor * rawScore + (1 - factor) * _smoothedScore;
    }

    _scoreHistory.add(_smoothedScore);
    if (_scoreHistory.length > 150) _scoreHistory.removeAt(0);
    _trend = _linearTrend(
      _scoreHistory.length > 10
          ? _scoreHistory.sublist(_scoreHistory.length - 10)
          : _scoreHistory,
    );

    var projectedGain = 0.0;
    var decayingTrend = _trend;
    for (var index = 0; index < 10; index++) {
      projectedGain += decayingTrend;
      decayingTrend *= 0.85;
    }
    final yawnPenalty = (_liveMar ?? 0) > 0.6
        ? math.min(2.0, ((_liveMar ?? 0) - 0.6) * 5)
        : 0.0;
    _drowsyAccumulator = _smoothedScore >= 3.5
        ? math.min(2.5, _drowsyAccumulator + 0.05)
        : math.max(0, _drowsyAccumulator - 0.1);
    _predictedScore =
        (_smoothedScore + projectedGain + yawnPenalty + _drowsyAccumulator)
            .clamp(0.0, 10.0);

    var calculatedSeverity = logicSeverity;
    var calculatedStatus = logicSeverity > 0
        ? logicMessage
        : 'Tỉnh táo · STGT ${_smoothedScore.toStringAsFixed(1)}/10';
    if (logicSeverity == 0 && _smoothedScore >= dangerScore) {
      calculatedSeverity = 3;
      calculatedStatus = 'Nguy hiểm · STGT phát hiện nguy cơ ngủ gật';
    } else if (logicSeverity == 0 &&
        _predictedScore >= 6.6 &&
        _smoothedScore >= 3.5) {
      calculatedSeverity = 2;
      calculatedStatus = 'Cảnh báo sớm · nguy cơ STGT tăng nhanh';
    } else if (logicSeverity == 0 && _smoothedScore >= 4 && _trend > 0.15) {
      calculatedSeverity = 1;
      calculatedStatus = 'Chú ý · điểm STGT đang tăng';
    } else if (logicSeverity == 0 && _smoothedScore >= 3.5) {
      calculatedSeverity = 1;
      calculatedStatus = 'Chú ý · STGT ghi nhận dấu hiệu lơ mơ';
    }

    if (calculatedSeverity > _severity) {
      _severity = calculatedSeverity;
      _statusText = calculatedStatus;
      _holdUntil = at.add(const Duration(seconds: 2));
    } else if (_holdUntil == null || !at.isBefore(_holdUntil!)) {
      _severity = calculatedSeverity;
      _statusText = calculatedStatus;
    }
  }

  void _appendResampledFeatures(DateTime at, List<double>? features) {
    final previousAt = _lastObservationAt;
    final previousFeatures = _lastObservedFeatures;
    if (previousAt == null ||
        _nextSampleAt == null ||
        at.isBefore(previousAt)) {
      _appendWindowValue(features);
      _lastObservationAt = at;
      _lastObservedFeatures = features;
      _nextSampleAt = at.add(_samplePeriod);
      return;
    }

    final gap = at.difference(previousAt);
    if (gap > _maximumInterpolationGap) {
      // Do not fabricate a long sequence after camera stalls or face loss.
      _appendWindowValue(null);
      _appendWindowValue(features);
      _lastObservationAt = at;
      _lastObservedFeatures = features;
      _nextSampleAt = at.add(_samplePeriod);
      return;
    }

    var next = _nextSampleAt!;
    while (!next.isAfter(at)) {
      List<double>? sampled;
      if (previousFeatures != null &&
          features != null &&
          gap.inMicroseconds > 0) {
        final ratio =
            next.difference(previousAt).inMicroseconds / gap.inMicroseconds;
        sampled = List.generate(
          6,
          (column) =>
              previousFeatures[column] +
              (features[column] - previousFeatures[column]) * ratio,
        );
      }
      _appendWindowValue(sampled);
      next = next.add(_samplePeriod);
    }
    _lastObservationAt = at;
    _lastObservedFeatures = features;
    _nextSampleAt = next;
  }

  void _appendWindowValue(List<double>? features) {
    _window.add(features);
    if (_window.length > windowSize) _window.removeAt(0);
    _framesSinceCalibration++;
  }

  List<List<double>>? _interpolateWindow() {
    final result = List.generate(
      windowSize,
      (_) => List<double>.filled(6, double.nan),
    );
    for (var column = 0; column < 6; column++) {
      final known = <int>[];
      for (var row = 0; row < windowSize; row++) {
        final value = _window[row];
        if (value != null && value[column].isFinite) {
          result[row][column] = value[column];
          known.add(row);
        }
      }
      if (known.isEmpty) return null;
      for (var row = 0; row < windowSize; row++) {
        if (result[row][column].isFinite) continue;
        int? previous;
        int? next;
        for (final index in known) {
          if (index < row) previous = index;
          if (index > row) {
            next = index;
            break;
          }
        }
        final gapStart = previous == null ? 0 : previous + 1;
        final gapEnd = next == null ? windowSize - 1 : next - 1;
        if (gapEnd - gapStart + 1 > 10) return null;
        if (previous == null) {
          result[row][column] = result[next!][column];
        } else if (next == null) {
          result[row][column] = result[previous][column];
        } else {
          final ratio = (row - previous) / (next - previous);
          result[row][column] =
              result[previous][column] +
              (result[next][column] - result[previous][column]) * ratio;
        }
      }
    }
    return result;
  }

  List<List<double>> _savitzkyGolay(List<List<double>> rows) {
    const coefficients = [-36, 9, 44, 69, 84, 89, 84, 69, 44, 9, -36];
    const divisor = 429.0;
    return List.generate(rows.length, (row) {
      if (row < 5 || row >= rows.length - 5) return List.of(rows[row]);
      return List.generate(6, (column) {
        var value = 0.0;
        for (var offset = -5; offset <= 5; offset++) {
          value +=
              rows[row + offset][column] * coefficients[offset + 5] / divisor;
        }
        return value;
      });
    });
  }

  double _predict(List<List<double>> rows) {
    if (scorePredictor != null) return scorePredictor!(rows);
    final input = [rows];
    final output = [List<double>.filled(1, 0)];
    _interpreter!.run(input, output);
    return output[0][0];
  }

  double _meanOf(List<List<double>> rows, int column, int count) {
    final start = math.max(0, rows.length - count);
    var sum = 0.0;
    for (var index = start; index < rows.length; index++) {
      sum += rows[index][column];
    }
    return sum / math.max(1, rows.length - start);
  }

  double _linearTrend(List<double> values) {
    if (values.length < 4) return 0;
    final meanX = (values.length - 1) / 2;
    final meanY = values.reduce((a, b) => a + b) / values.length;
    var numerator = 0.0;
    var denominator = 0.0;
    for (var index = 0; index < values.length; index++) {
      numerator += (index - meanX) * (values[index] - meanY);
      denominator += math.pow(index - meanX, 2).toDouble();
    }
    return denominator == 0 ? 0 : numerator / denominator;
  }

  bool _cooldownElapsed(DateTime at) =>
      _lastDetection == null || at.difference(_lastDetection!) >= cooldown;

  bool _sameShape(List<int> actual, List<int> expected) {
    if (actual.length != expected.length) return false;
    for (var index = 0; index < actual.length; index++) {
      if (actual[index] != expected[index]) return false;
    }
    return true;
  }
}

class _ModelInput {
  const _ModelInput({
    required this.rows,
    required this.recentEar,
    required this.recentMar,
    required this.recentEarZScore,
    required this.headTurning,
  });

  final List<List<double>> rows;
  final double recentEar;
  final double recentMar;
  final double recentEarZScore;
  final bool headTurning;
}
