import 'package:flutter_test/flutter_test.dart';
import 'package:safe_fleet_driver_ui/features/documents/driving_log_entry.dart';
import 'package:safe_fleet_driver_ui/features/documents/server_document_ocr_service.dart';

void main() {
  test(
    'server OCR endpoint is relative to the configured /api/v1 base URL',
    () {
      const baseUrl = 'http://127.0.0.1:8080/api/v1';

      expect(
        Uri.parse('$baseUrl${ServerDocumentOcrService.jobsEndpointPath}').path,
        '/api/v1/mobile/documents/ocr/jobs',
      );
    },
  );

  test('server OCR replaces project field and preserves local fields', () {
    final createdAt = DateTime(2026, 8, 10, 9);
    final local = DrivingLogEntry(
      id: 'doc-1',
      imagePath: '/scan.jpg',
      originalImagePath: '/original.jpg',
      qualityLevel: ScanQualityLevel.green,
      qualityScore: 91,
      qualityIssues: const [],
      ocrText: '--- OCR on-device ---\nTên công trình đọc sai',
      fieldConfidences: const {'voucherDate': 0.93, 'projectAddress': 0.61},
      voucherDate: DateTime(2026, 7, 5),
      driverName: 'Nguyễn Văn A',
      assistantName: '',
      vehiclePlate: '29C64684',
      projectAddress: 'Tên công trình đọc sai',
      tripCount: 1,
      mealCost: null,
      ruleCost: null,
      tyreCost: null,
      otherCost: null,
      managerConfirmation: '',
      voucherNumber: '77029',
      status: DrivingLogStatus.draft,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    const server = ServerDocumentOcrResult(
      projectAddress: 'CT xây dựng nhà máy chính xác',
      engine: 'server_hybrid_tesseract_best_vietocr',
      elapsedMs: 11589,
    );

    final merged = applyServerDocumentOcrResult(local, server);

    expect(merged.projectAddress, server.projectAddress);
    expect(merged.voucherDate, local.voucherDate);
    expect(merged.vehiclePlate, local.vehiclePlate);
    expect(merged.fieldConfidences['voucherDate'], 0.93);
    expect(merged.fieldConfidences['projectAddress'], 0.99);
    expect(merged.ocrText, contains('OCR on-device'));
    expect(merged.ocrText, contains('OCR server'));
    expect(merged.ocrText, contains(server.engine));
  });

  test('server OCR fills every empty printed field returned by backend', () {
    final now = DateTime(2026, 8, 11);
    final local = DrivingLogEntry(
      id: 'doc-full-result',
      imagePath: '/scan.jpg',
      originalImagePath: '/original.jpg',
      qualityLevel: ScanQualityLevel.yellow,
      qualityScore: 0,
      qualityIssues: const [pendingComputerOcrIssue],
      ocrText: '',
      fieldConfidences: const {},
      voucherDate: null,
      driverName: '',
      assistantName: '',
      vehiclePlate: '',
      projectAddress: '',
      tripCount: null,
      mealCost: null,
      ruleCost: null,
      tyreCost: null,
      otherCost: null,
      managerConfirmation: '',
      voucherNumber: '',
      status: DrivingLogStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
    final server = ServerDocumentOcrResult(
      projectAddress: 'CT xây dựng nhà máy',
      voucherDate: DateTime(2026, 7, 5),
      voucherNumber: '77029',
      vehiclePlate: '29C-646.84',
      driverName: 'Nguyễn Văn An',
      tripCount: 1,
      rawText: 'PHIẾU XUẤT KHO\nNgày 5 tháng 7 năm 2026',
      fieldConfidences: const {
        'voucherDate': 0.93,
        'voucherNumber': 0.9,
        'vehiclePlate': 0.92,
      },
      engine: 'server_hybrid_tesseract_best_vietocr',
      elapsedMs: 8000,
    );

    final merged = applyServerDocumentOcrResult(local, server);

    expect(merged.voucherDate, DateTime(2026, 7, 5));
    expect(merged.voucherNumber, '77029');
    expect(merged.vehiclePlate, '29C64684');
    expect(merged.driverName, 'Nguyễn Văn An');
    expect(merged.projectAddress, 'CT xây dựng nhà máy');
    expect(merged.tripCount, 1);
    expect(merged.qualityLevel, ScanQualityLevel.green);
    expect(merged.qualityScore, 94);
    expect(merged.qualityIssues, isEmpty);
    expect(merged.ocrText, contains('Ngày 5 tháng 7 năm 2026'));
  });

  test('empty server result does not alter the local entry', () {
    final now = DateTime(2026, 8, 10);
    final local = DrivingLogEntry(
      id: 'doc-2',
      imagePath: '/scan.jpg',
      originalImagePath: '/original.jpg',
      qualityLevel: ScanQualityLevel.yellow,
      qualityScore: 72,
      qualityIssues: const [],
      ocrText: 'local',
      fieldConfidences: const {'projectAddress': 0.7},
      voucherDate: null,
      driverName: '',
      assistantName: '',
      vehiclePlate: '',
      projectAddress: 'Kết quả local',
      tripCount: 1,
      mealCost: null,
      ruleCost: null,
      tyreCost: null,
      otherCost: null,
      managerConfirmation: '',
      voucherNumber: '',
      status: DrivingLogStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
    const server = ServerDocumentOcrResult(
      projectAddress: '   ',
      engine: 'server-ocr',
      elapsedMs: 10,
    );

    expect(applyServerDocumentOcrResult(local, server), same(local));
  });

  test('server merge preserves fields and project entered by the user', () {
    final now = DateTime(2026, 8, 11);
    final local = DrivingLogEntry(
      id: 'doc-user-edited',
      imagePath: '/scan.jpg',
      originalImagePath: '/original.jpg',
      qualityLevel: ScanQualityLevel.yellow,
      qualityScore: 0,
      qualityIssues: const [pendingComputerOcrIssue],
      ocrText: '',
      fieldConfidences: const {'projectAddress': 1},
      voucherDate: DateTime(2026, 8, 11),
      driverName: 'Nguyễn Văn An',
      assistantName: 'Trần Văn B',
      vehiclePlate: '29C64684',
      projectAddress: 'Công trình người dùng đã sửa',
      tripCount: 3,
      mealCost: 120000,
      ruleCost: 300000,
      tyreCost: 50000,
      otherCost: 10000,
      managerConfirmation: 'Đã xác nhận',
      voucherNumber: '77029',
      status: DrivingLogStatus.verified,
      createdAt: now,
      updatedAt: now,
    );
    const server = ServerDocumentOcrResult(
      projectAddress: 'Kết quả OCR máy tính',
      engine: 'server_hybrid_tesseract_best_vietocr',
      elapsedMs: 9000,
    );

    final merged = applyServerDocumentOcrResult(local, server);

    expect(merged.projectAddress, local.projectAddress);
    expect(merged.assistantName, local.assistantName);
    expect(merged.tripCount, 3);
    expect(merged.totalCost, 480000);
    expect(merged.managerConfirmation, 'Đã xác nhận');
    expect(merged.qualityIssues, isEmpty);
    expect(merged.ocrText, contains('Kết quả OCR máy tính'));
  });
}
