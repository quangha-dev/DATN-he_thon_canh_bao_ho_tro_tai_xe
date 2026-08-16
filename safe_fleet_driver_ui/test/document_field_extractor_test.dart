import 'package:flutter_test/flutter_test.dart';
import 'package:safe_fleet_driver_ui/features/documents/document_field_extractor.dart';

void main() {
  const extractor = DocumentFieldExtractor();

  test('extracts Vietnamese date and long project from the voucher header', () {
    final result = extractor.extract([
      DocumentOcrSnapshot.fromText('''
PHIẾU XUẤT KHO
Ngày 5 tháng 7 năm 2026
Tên công trình: Xuất thẳng cho CT Xây dựng nhà máy Công ty cổ phần tại Phường Bạch Hưng Yên
Xuất tại kho (ngăn lò)
Hạng mục: C
'''),
    ]);

    expect(result.voucherDate, DateTime(2026, 7, 5));
    expect(result.projectAddress, contains('CT Xây dựng nhà máy'));
    expect(result.projectAddress, isNot(contains('Xuất tại kho')));
    expect(result.confidences['voucherDate'], greaterThanOrEqualTo(0.9));
    expect(result.confidences['projectAddress'], greaterThanOrEqualTo(0.8));
  });

  test(
    'tolerates common OCR errors and a project split onto the next line',
    () {
      final result = extractor.extract([
        DocumentOcrSnapshot.fromText('''
PHIEU XUAT KHO
Ngay S thang 7 nam 2O26
Ten cong trlnh:
Xuat thang cho CT Xay dung nha may Cong ty Co phan Bac Hung Yen
Hang muc
''', kind: DocumentOcrSnapshotKind.header),
      ]);

      expect(result.voucherDate, DateTime(2026, 7, 5));
      expect(result.projectAddress, contains('CT Xay dung nha may'));
      expect(result.projectAddress, isNot(contains('Hang muc')));
    },
  );

  test('uses focused OCR result when full-page OCR misses a field', () {
    final result = extractor.extract([
      DocumentOcrSnapshot.fromText('PHIẾU XUẤT KHO\nSố: 77029'),
      DocumentOcrSnapshot.fromText(
        '05/07/2026',
        kind: DocumentOcrSnapshotKind.date,
      ),
      DocumentOcrSnapshot.fromText(
        'Tên công trình\nNhà máy sản xuất Bắc Hưng Yên\nSố thứ tự',
        kind: DocumentOcrSnapshotKind.project,
      ),
    ]);

    expect(result.voucherDate, DateTime(2026, 7, 5));
    expect(result.voucherNumber, '77029');
    expect(result.projectAddress, 'Nhà máy sản xuất Bắc Hưng Yên');
    expect(result.confidences['voucherDate'], greaterThan(0.85));
    expect(result.confidences['projectAddress'], greaterThan(0.85));
  });

  test('prefers a complete full-page project over a truncated focused crop', () {
    final result = extractor.extract([
      DocumentOcrSnapshot.fromText('''
Tên công trình: Xuất hàng cho CT Thi công xây thô và hoàn thiện mặt ngoài nhà ở thấp tầng giai đoạn I,
P. Đồng Văn - T. Ninh Bình.(Mr: 0359694246)
Xuất tại kho (ngăn lò)
'''),
      DocumentOcrSnapshot.fromText(
        'Tên công trình: CT Thi công xây thô và hoàn thiện mặt ngoài nhà ở thấp tâng giai đoạn ,P.',
        kind: DocumentOcrSnapshotKind.project,
      ),
    ]);

    expect(
      result.projectAddress,
      'CT Thi công xây thô và hoàn thiện mặt ngoài nhà ở thấp tầng giai đoạn I, P. Đồng Văn - T. Ninh Bình.(Mr: 0359694246)',
    );
  });

  test('rejects invalid calendar dates', () {
    final result = extractor.extract([
      DocumentOcrSnapshot.fromText(
        'Ngày 31 tháng 2 năm 2026\nTên công trình: Kho thử nghiệm',
      ),
    ]);

    expect(result.voucherDate, isNull);
    expect(result.confidences['voucherDate'], 0);
  });

  test('stops project before recipient, material code and signature text', () {
    final result = extractor.extract([
      DocumentOcrSnapshot.fromText('''
Tên công trình: Xuất thẳng cho CT Xây dựng nbà máy Công ty cổ phẩn bao bì Phuong Bic Hưng Yên, Tổ dân
- Họ tên người nhận hàng: 300-10-1
(Ký, họ tên)
''', kind: DocumentOcrSnapshotKind.project),
    ]);

    expect(result.projectAddress, contains('Phuong Bic Hưng Yên, Tổ dân'));
    expect(result.projectAddress, isNot(contains('Họ tên người nhận hàng')));
    expect(result.projectAddress, isNot(contains('300-10-1')));
    expect(result.projectAddress, isNot(contains('Ký, họ tên')));
  });

  test('removes voucher title without inventing text missing from OCR', () {
    final result = extractor.extract([
      DocumentOcrSnapshot.fromText(
        'Tên công trình: CT Xây dựng nbà máy Công ty cổ phẩn bao bì Phuong Bic Hung Yên, Tố dân PHIỂU XUẤT KHO',
        kind: DocumentOcrSnapshotKind.project,
      ),
    ]);

    expect(
      result.projectAddress,
      'CT Xây dựng nbà máy Công ty cổ phẩn bao bì Phuong Bic Hung Yên, Tố dân',
    );
  });

  test('skips a side title and keeps the following address line', () {
    final result = extractor.extract([
      const DocumentOcrSnapshot(
        text:
            'Tên công trình: Nhà máy Alpha, Tổ dân\nPHIẾU XUẤT KHO\nphố 2, Phường Minh Khai, Tỉnh Hưng Yên',
        width: 1200,
        height: 700,
        kind: DocumentOcrSnapshotKind.project,
        lines: [
          DocumentOcrLine(
            text: 'Tên công trình: Nhà máy Alpha, Tổ dân',
            left: 40,
            top: 120,
            right: 850,
            bottom: 148,
          ),
          DocumentOcrLine(
            text: 'PHIẾU XUẤT KHO',
            left: 880,
            top: 118,
            right: 1160,
            bottom: 150,
          ),
          DocumentOcrLine(
            text: 'phố 2, Phường Minh Khai, Tỉnh Hưng Yên',
            left: 230,
            top: 151,
            right: 900,
            bottom: 180,
          ),
        ],
      ),
    ]);

    expect(
      result.projectAddress,
      'Nhà máy Alpha, Tổ dân phố 2, Phường Minh Khai, Tỉnh Hưng Yên',
    );
  });

  test('truncates an inline recipient label from the project value', () {
    final result = extractor.extract([
      DocumentOcrSnapshot.fromText(
        'Tên công trình: Nhà máy Bắc Hưng Yên - Họ tên người nhận hàng: Nguyễn Văn A',
        kind: DocumentOcrSnapshotKind.project,
      ),
    ]);

    expect(result.projectAddress, 'Nhà máy Bắc Hưng Yên');
  });

  test('uses geometry to reject a distant table line', () {
    final result = extractor.extract([
      const DocumentOcrSnapshot(
        text: 'Tên công trình\nNhà máy Bắc Hưng Yên\nPHC.300-10-T',
        width: 1000,
        height: 800,
        kind: DocumentOcrSnapshotKind.project,
        lines: [
          DocumentOcrLine(
            text: 'Tên công trình:',
            left: 50,
            top: 80,
            right: 260,
            bottom: 105,
            angle: 1.2,
          ),
          DocumentOcrLine(
            text: 'Nhà máy Bắc Hưng Yên',
            left: 220,
            top: 108,
            right: 700,
            bottom: 135,
            angle: 1.4,
          ),
          DocumentOcrLine(
            text: 'PHC.300-10-T',
            left: 80,
            top: 260,
            right: 260,
            bottom: 285,
          ),
        ],
      ),
    ]);

    expect(result.projectAddress, 'Nhà máy Bắc Hưng Yên');
  });
}
