import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_fleet_driver_ui/features/documents/on_device_vietocr_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'VietOCR ONNX nhận dạng dòng trên Android',
    (tester) async {
      final data = await rootBundle.load(
        'assets/test_documents/vietocr_address.png',
      );
      final result = await const OnDeviceVietOcrService().recognizeLine(
        data.buffer.asUint8List(),
      );
      // ignore: avoid_print
      print('ON_DEVICE_VIETOCR_RESULT|${result.elapsedMs}|${result.text}');
      expect(result.engine, 'vietocr-onnx-android');
      expect(result.text, isNotEmpty);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
