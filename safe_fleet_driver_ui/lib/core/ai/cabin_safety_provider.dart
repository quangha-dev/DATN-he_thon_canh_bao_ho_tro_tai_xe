import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app.dart';
import 'cabin_ai_controller.dart';
import 'cabin_foreground_service.dart';
import 'temporal_safety_engine.dart';

class CabinSafetyState {
  const CabinSafetyState({
    this.enabled = false,
    this.status = CabinAiStatus.stopped,
    this.message = 'Giám sát cabin đang tắt',
    this.modelMode = DrowsinessModelMode.stgtTflite,
    this.lastDetection,
    this.metrics,
  });

  final bool enabled;
  final CabinAiStatus status;
  final String message;
  final DrowsinessModelMode modelMode;
  final SafetyDetection? lastDetection;
  final CabinMetrics? metrics;

  bool get active => enabled && status == CabinAiStatus.active;

  CabinSafetyState copyWith({
    bool? enabled,
    CabinAiStatus? status,
    String? message,
    DrowsinessModelMode? modelMode,
    SafetyDetection? lastDetection,
    CabinMetrics? metrics,
    bool clearDetection = false,
    bool clearMetrics = false,
  }) => CabinSafetyState(
    enabled: enabled ?? this.enabled,
    status: status ?? this.status,
    message: message ?? this.message,
    modelMode: modelMode ?? this.modelMode,
    lastDetection: clearDetection
        ? null
        : (lastDetection ?? this.lastDetection),
    metrics: clearMetrics ? null : (metrics ?? this.metrics),
  );
}

final cabinSafetyProvider =
    NotifierProvider<CabinSafetyController, CabinSafetyState>(
      CabinSafetyController.new,
    );

class CabinSafetyController extends Notifier<CabinSafetyState> {
  CabinAiController? _controller;
  final _foregroundService = CabinForegroundService.instance;
  bool _inBackground = false;

  CameraController? get cameraController => _controller?.cameraController;

  @override
  CabinSafetyState build() {
    _foregroundService.setHandlers(
      onStopped: _stopFromNotification,
      onDetection: _recordBackgroundDetection,
    );
    ref.onDispose(() => unawaited(_disposeController()));
    return const CabinSafetyState();
  }

  Future<void> toggle() => state.enabled ? stop() : start();

  Future<void> start() async {
    if (state.enabled && _controller != null) return;
    final cameraPermission = await Permission.camera.request();
    if (!cameraPermission.isGranted) {
      state = state.copyWith(
        enabled: false,
        status: CabinAiStatus.unavailable,
        message: 'Cần cấp quyền camera để giám sát nền',
      );
      return;
    }
    await Permission.notification.request();
    state = state.copyWith(
      enabled: true,
      status: CabinAiStatus.starting,
      message: 'Đang khởi động camera cabin',
      clearDetection: true,
      clearMetrics: true,
    );
    try {
      await _foregroundService.start(
        model: _modelLabel(state.modelMode),
        status: 'Đang khởi động camera trước',
      );
      await _replaceController(state.modelMode);
    } catch (_) {
      await _foregroundService.stop();
      state = state.copyWith(
        enabled: false,
        status: CabinAiStatus.unavailable,
        message: state.modelMode == DrowsinessModelMode.stgtTflite
            ? 'Không thể tải STGT · kiểm tra model trên thiết bị'
            : 'Không thể khởi động giám sát nền',
      );
    }
  }

  Future<void> stop() async {
    _inBackground = false;
    await _disposeController();
    await _foregroundService.stop();
    state = state.copyWith(
      enabled: false,
      status: CabinAiStatus.stopped,
      message: 'Giám sát cabin đang tắt',
      clearDetection: true,
      clearMetrics: true,
    );
  }

  Future<void> setModel(DrowsinessModelMode mode) async {
    if (mode == state.modelMode) return;
    state = state.copyWith(modelMode: mode);
    if (state.enabled) await _replaceController(mode);
  }

  void updateSpeed(double speedKph) => _controller?.updateSpeed(speedKph);

  void acknowledgeDetection() {
    state = state.copyWith(clearDetection: true);
  }

  Future<void> enterBackground() async {
    if (!state.enabled || _inBackground) return;
    _inBackground = true;
    await _disposeController();
    await _foregroundService.enterBackground();
    await _foregroundService.update(
      model: 'ML Kit temporal nền',
      status: 'Đang theo dõi nền · camera trước hoạt động',
    );
    state = state.copyWith(
      status: CabinAiStatus.active,
      message: 'Đang theo dõi nền · camera trước hoạt động',
    );
  }

  Future<void> enterForeground() async {
    if (!state.enabled || !_inBackground) return;
    _inBackground = false;
    await _foregroundService.enterForeground();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await _replaceController(state.modelMode);
  }

  Future<void> _replaceController(DrowsinessModelMode mode) async {
    await _disposeController();
    late final CabinAiController controller;
    controller = CabinAiController(
      modelMode: mode,
      onStatus: (status, message) {
        if (_controller != controller) return;
        state = state.copyWith(status: status, message: message);
        unawaited(
          _foregroundService.update(model: _modelLabel(mode), status: message),
        );
      },
      onDetection: (detection) async {
        if (_controller != controller) return;
        await _recordDetection(detection, updateNotification: true);
      },
      onMetrics: (metrics) {
        if (_controller != controller) return;
        state = state.copyWith(metrics: metrics);
      },
    );
    _controller = controller;
    await controller.start();
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  Future<void> _stopFromNotification() async {
    _inBackground = false;
    await _disposeController();
    state = state.copyWith(
      enabled: false,
      status: CabinAiStatus.stopped,
      message: 'Đã dừng từ thanh thông báo',
      clearDetection: true,
    );
  }

  Future<void> _recordBackgroundDetection(double confidence, String reason) =>
      _recordDetection(
        SafetyDetection(
          type: SafetyDetectionType.drowsiness,
          confidence: confidence,
          severity: 'HIGH',
          reason: reason,
          detectedAt: DateTime.now(),
          source: 'mlkit-native-background',
        ),
        updateNotification: false,
      );

  Future<void> _recordDetection(
    SafetyDetection detection, {
    required bool updateNotification,
  }) async {
    final metrics = state.metrics;
    final metricNote = metrics == null
        ? ''
        : ' · EAR ${metrics.ear?.toStringAsFixed(3) ?? '--'}'
              ' · MAR ${metrics.mar?.toStringAsFixed(3) ?? '--'}'
              ' · pitch ${metrics.pitch.toStringAsFixed(1)}'
              ' · yaw ${metrics.yaw.toStringAsFixed(1)}'
              ' · iris ${metrics.iris.toStringAsFixed(3)}'
              ' · score ${metrics.score.toStringAsFixed(1)}'
              ' · predicted ${metrics.predictedScore.toStringAsFixed(1)}';
    state = state.copyWith(lastDetection: detection);
    if (updateNotification) {
      unawaited(
        _foregroundService.update(
          model: _modelLabel(state.modelMode),
          status: detection.type == SafetyDetectionType.drowsiness
              ? 'Phát hiện dấu hiệu buồn ngủ'
              : 'Phát hiện dấu hiệu mất tập trung',
          warning: true,
        ),
      );
    }
    await ref
        .read(driverRepositoryProvider)
        .queueSafetyEvent(
          eventType: detection.apiEventType,
          severity: detection.severity,
          confidence: detection.confidence,
          note:
              '${detection.reason}$metricNote · ${detection.source} · on-device',
        );
  }

  String _modelLabel(DrowsinessModelMode mode) =>
      mode == DrowsinessModelMode.stgtTflite ? 'STGT' : 'Temporal dự phòng';
}
