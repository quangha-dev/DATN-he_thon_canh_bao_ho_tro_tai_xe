import 'package:flutter/services.dart';

class OnDeviceVietOcrResult {
  const OnDeviceVietOcrResult({
    required this.text,
    required this.elapsedMs,
    required this.engine,
  });

  final String text;
  final int elapsedMs;
  final String engine;
}

class OnDeviceVietOcrService {
  const OnDeviceVietOcrService();

  static const _channel = MethodChannel('safefleet/vietocr');

  Future<OnDeviceVietOcrResult> recognizeLine(
    Uint8List bytes, {
    int? maxTokens,
  }) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'recognizeLine',
      {'bytes': bytes, 'maxTokens': ?maxTokens},
    );
    if (response == null) throw StateError('VietOCR không trả kết quả');
    return OnDeviceVietOcrResult(
      text: response['text']?.toString().trim() ?? '',
      elapsedMs: (response['elapsedMs'] as num?)?.round() ?? 0,
      engine: response['engine']?.toString() ?? 'vietocr-onnx-android',
    );
  }
}
