import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'temporal_safety_engine.dart';

typedef StgtScorePredictor = double Function(List<List<double>> rows);

class StgtDrowsinessEngine {
  StgtDrowsinessEngine({
    this.scorePredictor,
    this.baselineStorage,
    this.calibrationFrames = 1500,
    this.windowSize = 75,
    this.inferenceInterval = 5,
    this.dangerScore = 6,
    this.cooldown = const Duration(seconds: 20),
  });

  static const assetPath = 'assets/models/drowsiness_model.tflite';
  static const modelSource = 'stgt-fold-1-tflite';
  static const _baselineKey = 'cabin_mesh468_baseline_v1';
  static const _minimumStandardDeviation = [0.015, 0.04, 2.0, 2.0, 2.0, 0.01];

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
  int _framesSinceCalibration = 0;
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
      if (!_sameShape(inputShape, [1, 1, windowSize, 12]) ||
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
            ? 'Đưa khuôn mặt vào giữa khung hình'
            : 'Nhìn thẳng, mở mắt tự nhiên để hiệu chuẩn';
      }
      return const [];
    }

    _window.add(features);
    if (_window.length > windowSize) _window.removeAt(0);
    _framesSinceCalibration++;
    if (_window.length < windowSize ||
        _framesSinceCalibration % inferenceInterval != 0) {
      return const [];
    }

    final input = _buildModelInput();
    if (input == null) {
      _statusText = 'Không thấy rõ khuôn mặt';
      return const [];
    }

    var rawScore = _predict(input.rows).clamp(0.0, 10.0);
    var logicSeverity = 0;
    var logicMessage = 'Tỉnh táo · tập trung';

    if (input.recentEar < 0.10) {
      rawScore = 10;
      logicSeverity = 3;
      logicMessage = 'Nguy hiểm · mắt nhắm lâu';
    } else if (input.recentMar > 0.60) {
      rawScore = math.max(rawScore, 6);
      logicSeverity = 2;
      logicMessage = 'Cảnh báo · phát hiện ngáp';
    } else if (input.recentEarZScore < -2.2 && !input.headTurning) {
      rawScore = math.max(rawScore, 5);
      logicSeverity = 2;
      logicMessage = 'Cảnh báo · mắt có dấu hiệu cụp';
    } else if (input.recentEarZScore > -0.5 && rawScore > 6) {
      rawScore = 2;
    }

    _updateScores(rawScore, logicSeverity, logicMessage, observation.at);
    if (_severity < 2 || !_cooldownElapsed(observation.at)) return const [];

    _lastDetection = observation.at;
    return [
      SafetyDetection(
        type: SafetyDetectionType.drowsiness,
        confidence: (math.max(_smoothedScore, _predictedScore) / 10).clamp(
          0.0,
          1.0,
        ),
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
    _framesSinceCalibration = 0;
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
      features[0] >= 0.14 &&
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
            'featureExtractor': 'mlkit-face-mesh-468-v1',
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
          decoded['featureExtractor'] != 'mlkit-face-mesh-468-v1') {
        return;
      }
      final mean = (decoded['mean'] as List?)
          ?.map((value) => (value as num).toDouble())
          .toList();
      final deviation = (decoded['std'] as List?)
          ?.map((value) => (value as num).toDouble())
          .toList();
      if (mean?.length != 6 || deviation?.length != 6) return;
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
    final recentEarZ = _meanOf(normalized, 0, 5);
    final recentPitchZ = _meanOf(normalized, 2, 5);
    final recentYawZ = _meanOf(normalized, 3, 5);
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
      recentEarZScore: recentEarZ,
      headTurning: recentPitchZ.abs() > 1.5 || recentYawZ.abs() > 1.5,
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
    } else if (logicSeverity == 3) {
      _smoothedScore = 10;
    } else {
      final up = _smoothedScore >= 4.5
          ? 0.05
          : _smoothedScore >= 4
          ? 0.02
          : 0.01;
      final down = _smoothedScore >= 4.5 ? 0.85 : 0.60;
      final factor = rawScore < _smoothedScore ? down : up;
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
    var calculatedStatus = logicMessage;
    if (calculatedSeverity == 0) {
      if (_smoothedScore >= dangerScore) {
        calculatedSeverity = 3;
        calculatedStatus = 'Nguy hiểm · nguy cơ ngủ gật';
      } else if (_predictedScore >= 6.6 && _smoothedScore >= 3.5) {
        calculatedSeverity = 2;
        calculatedStatus = 'Cảnh báo sớm · nguy cơ tăng nhanh';
      } else if (_smoothedScore >= 4 && _trend > 0.15) {
        calculatedSeverity = 1;
        calculatedStatus = 'Chú ý · mức tỉnh táo đang giảm';
      } else if (_smoothedScore >= 3.5) {
        calculatedSeverity = 1;
        calculatedStatus = 'Chú ý · có dấu hiệu lơ mơ';
      } else {
        calculatedStatus = 'Tỉnh táo · tập trung';
      }
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
    final input = [
      [rows],
    ];
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
