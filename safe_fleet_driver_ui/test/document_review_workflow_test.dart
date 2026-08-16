import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_fleet_driver_ui/core/design/theme.dart';
import 'package:safe_fleet_driver_ui/features/documents/document_review_screen.dart';
import 'package:safe_fleet_driver_ui/features/documents/driving_log_entry.dart';

void main() {
  testWidgets('pending form only shows the global queue state', (tester) async {
    await _pumpReview(
      tester,
      entry: _entry(pending: true),
      serverOcrManagedByQueue: true,
    );

    expect(find.text('Bổ sung dữ liệu phiếu'), findsOneWidget);
    expect(find.text('Máy tính đang xử lý OCR'), findsOneWidget);
    expect(find.textContaining('OCR máy chủ · Sẵn sàng'), findsNothing);
    expect(find.text('OCR máy tính đã hoàn tất'), findsNothing);
    for (final key in const [
      'voucher-field',
      'vehicle-plate-field',
      'project-address-field',
      'driver-name-field',
      'trip-count-field',
    ]) {
      expect(
        _isReadOnly(tester, ValueKey(key)),
        isTrue,
        reason: '$key phải bị khóa trong lúc OCR',
      );
    }
    expect(
      tester
          .widget<InkWell>(find.byKey(const ValueKey('voucher-date-field')))
          .onTap,
      isNull,
    );
    expect(
      _isReadOnly(tester, const ValueKey('assistant-name-field')),
      isFalse,
    );
    expect(
      _isReadOnly(tester, const ValueKey('manager-confirmation-field')),
      isFalse,
    );
  });

  testWidgets('completed form never offers to start OCR again', (tester) async {
    await _pumpReview(
      tester,
      entry: _entry(pending: false),
      serverOcrCompleted: true,
    );

    expect(find.text('Bổ sung dữ liệu phiếu'), findsOneWidget);
    expect(find.text('OCR máy tính đã hoàn tất'), findsOneWidget);
    expect(
      find.textContaining('không khởi chạy thêm một tác vụ OCR'),
      findsOneWidget,
    );
    expect(find.textContaining('OCR máy chủ · Sẵn sàng'), findsNothing);
    expect(find.text('Máy tính đang xử lý OCR'), findsNothing);
    expect(find.textContaining('Chất lượng ảnh · Vàng'), findsNothing);
    expect(
      _isReadOnly(tester, const ValueKey('project-address-field')),
      isFalse,
    );
    expect(
      tester
          .widget<InkWell>(find.byKey(const ValueKey('voucher-date-field')))
          .onTap,
      isNotNull,
    );
  });
}

bool _isReadOnly(WidgetTester tester, Key fieldKey) {
  final editable = find.descendant(
    of: find.byKey(fieldKey),
    matching: find.byType(EditableText),
  );
  return tester.widget<EditableText>(editable).readOnly;
}

Future<void> _pumpReview(
  WidgetTester tester, {
  required DrivingLogEntry entry,
  bool serverOcrManagedByQueue = false,
  bool serverOcrCompleted = false,
}) async {
  // Dùng viewport cao để toàn bộ trường của ListView được dựng, nhờ đó có thể
  // kiểm tra trạng thái khóa của cả nhóm OCR và nhóm bổ sung trong một frame.
  tester.view.physicalSize = const Size(1080, 12000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: SfTheme.light,
        home: DocumentReviewScreen(
          initialEntry: entry,
          serverOcrManagedByQueue: serverOcrManagedByQueue,
          serverOcrCompleted: serverOcrCompleted,
        ),
      ),
    ),
  );
  await tester.pump();
}

DrivingLogEntry _entry({required bool pending}) {
  final now = DateTime(2026, 8, 11, 12);
  return DrivingLogEntry(
    id: pending ? 'pending-review' : 'completed-review',
    imagePath: 'Z:/missing-voucher.jpg',
    originalImagePath: 'Z:/missing-original.jpg',
    qualityLevel: ScanQualityLevel.yellow,
    qualityScore: 72,
    qualityIssues: pending
        ? const [pendingComputerOcrIssue]
        : const ['Ảnh hơi nghiêng'],
    ocrText: pending ? 'OCR local' : 'OCR local\n--- OCR server (test)',
    fieldConfidences: const {'projectAddress': 0.91},
    voucherDate: DateTime(2026, 8, 11),
    driverName: 'Nguyễn Văn An',
    assistantName: '',
    vehiclePlate: '29C64684',
    projectAddress: pending ? '' : 'Công trình đã nhận dạng',
    tripCount: 1,
    mealCost: null,
    ruleCost: null,
    tyreCost: null,
    otherCost: null,
    managerConfirmation: '',
    voucherNumber: '77029',
    status: DrivingLogStatus.draft,
    createdAt: now,
    updatedAt: now,
  );
}
