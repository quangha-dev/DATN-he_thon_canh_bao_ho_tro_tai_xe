import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart'
    as mesh;
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'temporal_safety_engine.dart';
import 'stgt_drowsiness_engine.dart';

enum CabinAiStatus { starting, active, unavailable, stopped }

class CabinMetrics {
  const CabinMetrics({
    required this.capturedAt,
    required this.faceDetected,
    required this.calibrated,
    required this.calibrationProgress,
    required this.calibrationFrames,
    required this.ear,
    required this.mar,
    required this.iris,
    required this.pitch,
    required this.yaw,
    required this.roll,
    required this.rawScore,
    required this.score,
    required this.predictedScore,
    required this.trend,
    required this.severity,
    required this.statusText,
    required this.fps,
    required this.scoreHistory,
  });

  final DateTime capturedAt;
  final bool faceDetected;
  final bool calibrated;
  final int calibrationProgress;
  final int calibrationFrames;
  final double? ear;
  final double? mar;
  final double iris;
  final double pitch;
  final double yaw;
  final double roll;
  final double rawScore;
  final double score;
  final double predictedScore;
  final double trend;
  final int severity;
  final String statusText;
  final double fps;
  final List<double> scoreHistory;
}

class CabinAiController {
  CabinAiController({
    required this.onStatus,
    required this.onDetection,
    required this.onMetrics,
    this.modelMode = DrowsinessModelMode.stgtTflite,
    TemporalSafetyEngine? temporalEngine,
    StgtDrowsinessEngine? stgtEngine,
  }) : _temporalEngine = temporalEngine ?? TemporalSafetyEngine(),
       _stgtEngine =
           stgtEngine ??
           StgtDrowsinessEngine(baselineStorage: const FlutterSecureStorage());

  final void Function(CabinAiStatus status, String message) onStatus;
  final Future<void> Function(SafetyDetection detection) onDetection;
  final void Function(CabinMetrics metrics) onMetrics;
  final DrowsinessModelMode modelMode;
  final TemporalSafetyEngine _temporalEngine;
  final StgtDrowsinessEngine _stgtEngine;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      enableContours: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.18,
    ),
  );
  final mesh.FaceMeshDetector _faceMeshDetector = mesh.FaceMeshDetector(
    option: mesh.FaceMeshDetectorOptions.faceMesh,
  );
  final ImageLabeler _imageLabeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.6),
  );

  CameraController? _camera;
  CameraDescription? _description;
  bool _processing = false;
  bool _disposed = false;
  double _speedKph = 0;
  DateTime? _lastFrameAt;
  DateTime? _lastMetricsAt;
  DateTime? _fpsStartedAt;
  int _processedFrames = 0;
  int _labelFrame = 0;
  double _cachedPhoneConfidence = 0;
  Face? _cachedFace;
  bool _useStgt = false;
  int _reportedCalibrationProgress = -1;
  bool _reportedCalibrationComplete = false;

  bool get active => _camera?.value.isStreamingImages == true;
  CameraController? get cameraController => _camera;

  void updateSpeed(double speedKph) {
    _speedKph = math.max(0, speedKph);
  }

  Future<void> start() async {
    if (_disposed || active) return;
    onStatus(CabinAiStatus.starting, 'Đang khởi động bảo vệ');
    try {
      if (modelMode == DrowsinessModelMode.stgtTflite) {
        try {
          await _stgtEngine.initialize();
          _useStgt = true;
        } catch (_) {
          _useStgt = false;
          onStatus(CabinAiStatus.starting, 'Đang khởi động chế độ tương thích');
        }
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        onStatus(CabinAiStatus.unavailable, 'Thiết bị không có camera');
        return;
      }
      _description = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final imageFormat = Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.nv21;
      _camera = CameraController(
        _description!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: imageFormat,
      );
      await _camera!.initialize();
      await _camera!.startImageStream(_processCameraImage);
      onStatus(CabinAiStatus.active, 'Đang theo dõi trạng thái tỉnh táo');
    } on CameraException catch (error) {
      onStatus(CabinAiStatus.unavailable, _cameraMessage(error));
    } catch (_) {
      onStatus(CabinAiStatus.unavailable, 'AI cabin không khả dụng');
    }
  }

  Future<void> stop() async {
    final camera = _camera;
    _camera = null;
    if (camera != null) {
      if (camera.value.isStreamingImages) {
        await camera.stopImageStream();
      }
      await camera.dispose();
    }
    _temporalEngine.reset();
    _stgtEngine.reset();
    _useStgt = false;
    _reportedCalibrationProgress = -1;
    _reportedCalibrationComplete = false;
    _lastMetricsAt = null;
    _fpsStartedAt = null;
    _processedFrames = 0;
    _labelFrame = 0;
    _cachedPhoneConfidence = 0;
    _cachedFace = null;
    if (!_disposed) onStatus(CabinAiStatus.stopped, 'AI cabin đã dừng');
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _faceDetector.close();
    await _faceMeshDetector.close();
    await _imageLabeler.close();
    _stgtEngine.close();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final now = DateTime.now();
    if (_processing ||
        (_lastFrameAt != null &&
            now.difference(_lastFrameAt!) < const Duration(milliseconds: 35))) {
      return;
    }
    _processing = true;
    _lastFrameAt = now;
    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) return;
      _labelFrame++;
      final meshes = await _faceMeshDetector.processImage(inputImage);
      if (_cachedFace == null || _labelFrame % 5 == 0) {
        final faces = await _faceDetector.processImage(inputImage);
        _cachedFace = faces.isEmpty
            ? null
            : faces.reduce(
                (largest, candidate) =>
                    candidate.boundingBox.width * candidate.boundingBox.height >
                        largest.boundingBox.width * largest.boundingBox.height
                    ? candidate
                    : largest,
              );
      }
      if (_labelFrame % 10 == 0) {
        final labels = await _imageLabeler.processImage(inputImage);
        _cachedPhoneConfidence = labels
            .where((label) => _isPhoneLabel(label.label))
            .fold<double>(
              0,
              (maximum, label) => math.max(maximum, label.confidence),
            );
      }
      final face = _cachedFace;
      final faceMesh = meshes.isEmpty
          ? null
          : meshes.reduce(
              (largest, candidate) =>
                  candidate.boundingBox.width * candidate.boundingBox.height >
                      largest.boundingBox.width * largest.boundingBox.height
                  ? candidate
                  : largest,
            );
      final exact = faceMesh == null ? null : _meshFeatures(faceMesh);
      final ear = exact?.ear ?? (face == null ? null : _eyeAspectRatio(face));
      final mar = exact?.mar ?? (face == null ? 0.0 : _mouthAspectRatio(face));
      final iris = exact?.iris ?? 0.0;
      final pitch = face?.headEulerAngleX ?? 0;
      final yaw = face?.headEulerAngleY ?? 0;
      final roll = face?.headEulerAngleZ ?? 0;
      final observation = CabinObservation(
        at: now,
        speedKph: _speedKph,
        leftEyeOpen: ear,
        rightEyeOpen: ear,
        headPitchDegrees: pitch,
        headYawDegrees: yaw,
        headRollDegrees: roll,
        mouthOpenRatio: mar,
        irisMovement: iris,
        phoneConfidence: _cachedPhoneConfidence,
      );
      final temporalDetections = _temporalEngine.ingest(observation);
      final modelDetections = _useStgt
          ? _stgtEngine.ingest(observation)
          : const <SafetyDetection>[];
      final strongest = <SafetyDetectionType, SafetyDetection>{};
      for (final detection in [...temporalDetections, ...modelDetections]) {
        final previous = strongest[detection.type];
        if (previous == null || detection.confidence > previous.confidence) {
          strongest[detection.type] = detection;
        }
      }
      _reportStgtProgress();
      _emitMetrics(
        now,
        faceMesh != null || face != null,
        ear,
        mar,
        iris,
        pitch,
        yaw,
        roll,
      );
      for (final detection in strongest.values) {
        await onDetection(detection);
      }
    } catch (_) {
      // A malformed camera frame is skipped; the next frame remains usable.
    } finally {
      _processing = false;
    }
  }

  void _reportStgtProgress() {
    if (!_useStgt) return;
    if (_stgtEngine.calibrated) {
      if (!_reportedCalibrationComplete) {
        _reportedCalibrationComplete = true;
        onStatus(
          CabinAiStatus.active,
          'Hiệu chuẩn hoàn tất · giám sát đang hoạt động',
        );
      }
      return;
    }
    final progress = _stgtEngine.calibrationProgress;
    if (progress == _reportedCalibrationProgress || progress % 5 != 0) return;
    _reportedCalibrationProgress = progress;
    onStatus(
      CabinAiStatus.starting,
      'Đang hiệu chuẩn khuôn mặt $progress/${_stgtEngine.calibrationFrames} · nhìn thẳng camera',
    );
  }

  InputImage? _toInputImage(CameraImage image) {
    final description = _description;
    if (description == null || image.planes.isEmpty) return null;
    final rotation = InputImageRotationValue.fromRawValue(
      description.sensorOrientation,
    );
    final format = switch (image.format.group) {
      ImageFormatGroup.nv21 => InputImageFormat.nv21,
      ImageFormatGroup.bgra8888 => InputImageFormat.bgra8888,
      ImageFormatGroup.yuv420 when Platform.isIOS => InputImageFormat.yuv420,
      _ => null,
    };
    if (rotation == null || format == null || image.planes.length != 1) {
      return null;
    }
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  double? _eyeAspectRatio(Face face) {
    final values = <double>[];
    for (final type in [FaceContourType.leftEye, FaceContourType.rightEye]) {
      final points = face.contours[type]?.points;
      if (points == null || points.length < 4) continue;
      final bounds = _pointBounds(points);
      if (bounds.width > 0) values.add(bounds.height / bounds.width);
    }
    if (values.isNotEmpty) {
      return (values.reduce((a, b) => a + b) / values.length)
          .clamp(0.0, 0.6)
          .toDouble();
    }
    final probabilities = [
      face.leftEyeOpenProbability,
      face.rightEyeOpenProbability,
    ].whereType<double>().toList();
    if (probabilities.isEmpty) return null;
    final probability =
        probabilities.reduce((a, b) => a + b) / probabilities.length;
    return 0.08 + probability * 0.20;
  }

  _MeshFeatures? _meshFeatures(mesh.FaceMesh face) {
    final points = <int, mesh.FaceMeshPoint>{
      for (final point in face.points) point.index: point,
    };
    const leftEye = [362, 385, 387, 263, 373, 380];
    const rightEye = [33, 160, 158, 133, 153, 144];
    const lips = [78, 308, 13, 14];
    if (![...leftEye, ...rightEye, ...lips].every(points.containsKey)) {
      return null;
    }

    double distance(int first, int second) {
      final a = points[first]!;
      final b = points[second]!;
      return math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
    }

    double eyeRatio(List<int> indices) {
      final vertical1 = distance(indices[1], indices[5]);
      final vertical2 = distance(indices[2], indices[4]);
      final horizontal = distance(indices[0], indices[3]);
      return horizontal <= 0 ? 0 : (vertical1 + vertical2) / (2 * horizontal);
    }

    final ear = (eyeRatio(leftEye) + eyeRatio(rightEye)) / 2;
    final mouthWidth = distance(lips[0], lips[1]);
    final mar = mouthWidth <= 0 ? 0.0 : distance(lips[2], lips[3]) / mouthWidth;
    // ML Kit returns the canonical MediaPipe 0..467 mesh. The refined iris
    // points 468..477 are unavailable, so keep Iris neutral after calibration
    // rather than inject a noisy eye-probability substitute.
    return _MeshFeatures(
      ear: ear.clamp(0.0, 0.6).toDouble(),
      mar: mar.clamp(0.0, 1.5).toDouble(),
      iris: 0,
    );
  }

  double _mouthAspectRatio(Face face) {
    final upper = face.contours[FaceContourType.upperLipBottom]?.points;
    final lower = face.contours[FaceContourType.lowerLipTop]?.points;
    if (upper != null &&
        lower != null &&
        upper.isNotEmpty &&
        lower.isNotEmpty) {
      final all = [...upper, ...lower];
      final bounds = _pointBounds(all);
      if (bounds.width > 0) {
        final upperY = upper.map((point) => point.y).reduce(math.max);
        final lowerY = lower.map((point) => point.y).reduce(math.min);
        return ((lowerY - upperY).abs() / bounds.width)
            .clamp(0.0, 1.5)
            .toDouble();
      }
    }
    final left = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final right = face.landmarks[FaceLandmarkType.rightMouth]?.position;
    final bottom = face.landmarks[FaceLandmarkType.bottomMouth]?.position;
    if (left == null || right == null || bottom == null) return 0;
    final sideY = (left.y + right.y) / 2;
    final width = math.sqrt(
      math.pow(right.x - left.x, 2) + math.pow(right.y - left.y, 2),
    );
    return ((bottom.y - sideY).abs() * 2 / math.max(1, width))
        .clamp(0.0, 1.5)
        .toDouble();
  }

  Rect _pointBounds(List<math.Point<int>> points) {
    var minX = points.first.x.toDouble();
    var maxX = minX;
    var minY = points.first.y.toDouble();
    var maxY = minY;
    for (final point in points.skip(1)) {
      minX = math.min(minX, point.x.toDouble());
      maxX = math.max(maxX, point.x.toDouble());
      minY = math.min(minY, point.y.toDouble());
      maxY = math.max(maxY, point.y.toDouble());
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _emitMetrics(
    DateTime now,
    bool faceDetected,
    double? ear,
    double mar,
    double iris,
    double pitch,
    double yaw,
    double roll,
  ) {
    _fpsStartedAt ??= now;
    _processedFrames++;
    if (_lastMetricsAt != null &&
        now.difference(_lastMetricsAt!) < const Duration(milliseconds: 250)) {
      return;
    }
    _lastMetricsAt = now;
    final elapsed = now.difference(_fpsStartedAt!).inMilliseconds / 1000;
    final fps = elapsed <= 0 ? 0.0 : _processedFrames / elapsed;
    onMetrics(
      CabinMetrics(
        capturedAt: now,
        faceDetected: faceDetected,
        calibrated: _useStgt && _stgtEngine.calibrated,
        calibrationProgress: _useStgt ? _stgtEngine.calibrationProgress : 0,
        calibrationFrames: _stgtEngine.calibrationFrames,
        ear: ear,
        mar: faceDetected ? mar : null,
        iris: iris,
        pitch: pitch,
        yaw: yaw,
        roll: roll,
        rawScore: _stgtEngine.rawScore,
        score: _stgtEngine.score,
        predictedScore: _stgtEngine.predictedScore,
        trend: _stgtEngine.trend,
        severity: _stgtEngine.severity,
        statusText: faceDetected
            ? _stgtEngine.statusText
            : 'Không thấy khuôn mặt · điều chỉnh camera',
        fps: fps,
        scoreHistory: _stgtEngine.scoreHistory,
      ),
    );
  }

  bool _isPhoneLabel(String label) {
    final normalized = label.toLowerCase();
    return normalized.contains('phone') ||
        normalized.contains('telephone') ||
        normalized.contains('mobile device');
  }

  String _cameraMessage(CameraException error) {
    return switch (error.code) {
      'CameraAccessDenied' ||
      'CameraAccessDeniedWithoutPrompt' => 'Chưa được cấp quyền camera cabin',
      'CameraAccessRestricted' => 'Camera bị giới hạn trên thiết bị',
      _ => 'Không khởi động được camera cabin',
    };
  }
}

class _MeshFeatures {
  const _MeshFeatures({
    required this.ear,
    required this.mar,
    required this.iris,
  });

  final double ear;
  final double mar;
  final double iris;
}
