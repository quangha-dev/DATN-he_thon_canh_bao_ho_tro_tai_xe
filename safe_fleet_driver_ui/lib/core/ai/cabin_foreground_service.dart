import 'dart:io';

import 'package:flutter/services.dart';

class CabinForegroundService {
  CabinForegroundService._();

  static final instance = CabinForegroundService._();
  static const _channel = MethodChannel('vn.safefleet/cabin_monitoring');

  Future<void> Function()? _onStopped;
  Future<void> Function(double confidence, String reason)? _onDetection;
  int _warningCount = 0;

  void setHandlers({
    required Future<void> Function() onStopped,
    required Future<void> Function(double confidence, String reason)
    onDetection,
  }) {
    _onStopped = onStopped;
    _onDetection = onDetection;
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stoppedFromNotification') {
        await _onStopped?.call();
      } else if (call.method == 'backgroundDetection') {
        final arguments = Map<Object?, Object?>.from(call.arguments as Map);
        await _onDetection?.call(
          (arguments['confidence'] as num?)?.toDouble() ?? 0.9,
          arguments['reason'] as String? ??
              'Phát hiện buồn ngủ khi ứng dụng chạy nền',
        );
      }
    });
  }

  Future<void> enterBackground() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('enterBackground');
  }

  Future<void> enterForeground() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('enterForeground');
  }

  Future<void> start({required String model, required String status}) async {
    if (!Platform.isAndroid) return;
    _warningCount = 0;
    await _channel.invokeMethod<void>('start', {
      'model': model,
      'status': status,
    });
  }

  Future<void> update({
    required String model,
    required String status,
    bool warning = false,
  }) async {
    if (!Platform.isAndroid) return;
    if (warning) _warningCount++;
    await _channel.invokeMethod<void>('update', {
      'model': model,
      'status': status,
      'warningCount': _warningCount,
    });
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    _warningCount = 0;
    await _channel.invokeMethod<void>('stop');
  }
}
