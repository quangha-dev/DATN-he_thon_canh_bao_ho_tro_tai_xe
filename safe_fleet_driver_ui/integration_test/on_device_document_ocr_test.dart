import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:safe_fleet_driver_ui/features/documents/document_scan_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const fixtures = {
    'phieutest.jpg':
        'CT xây dựng nhà máy Công ty cổ phần bao bì Phương Bắc Hưng Yên, '
        'Tổ dân phố Thợ, Phường Đường Hào, Tỉnh Hưng Yên',
    'phieutest2.jpg':
        'CT Thi công xây thô và hoàn thiện mặt ngoài nhà ở thấp tầng giai đoạn I, '
        'P. Đồng Văn - T. Ninh Bình.(Mr: 0359694246',
  };
  for (final fixture in fixtures.entries) {
    testWidgets(
      'OCR ${fixture.key} hoàn toàn trên điện thoại',
      (tester) async {
        final bytes = await rootBundle.load(
          'assets/test_documents/${fixture.key}',
        );
        final temporaryDirectory = await getTemporaryDirectory();
        final image = File(p.join(temporaryDirectory.path, fixture.key));
        await image.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

        final service = DocumentScanService();
        try {
          final result = await service.process(sourcePath: image.path);
          // Prefix này được tạo trong process local và không thể đến từ API.
          expect(result.ocrText, startsWith('--- OCR on-device'));
          expect(result.ocrText, isNot(contains('OCR server')));
          expect(result.ocrText.trim(), isNotEmpty);
          expect(result.projectAddress, fixture.value);
          // Dòng máy đọc được được in vào log ADB để so sánh với ground truth.
          // ignore: avoid_print
          print(
            'ON_DEVICE_OCR_RESULT|${fixture.key}|${result.qualityLevel.name}|'
            '${result.qualityScore}|${result.projectAddress}',
          );
          // Base64 giữ nguyên dấu và xuống dòng khi log đi qua Flutter driver.
          // ignore: avoid_print
          print(
            'ON_DEVICE_OCR_RAW_BASE64|${fixture.key}|'
            '${base64Encode(utf8.encode(result.ocrText))}',
          );
        } finally {
          service.dispose();
        }
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  }
}
