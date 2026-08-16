import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'driving_log_entry.dart';

class DrivingLogExportService {
  Future<File> export({
    required DateTime month,
    required List<DrivingLogEntry> entries,
  }) async {
    if (entries.isEmpty) {
      throw StateError('Không có dữ liệu để xuất');
    }
    final bytes = buildWorkbookBytes(month: month, entries: entries);
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'driving_log_exports'));
    await directory.create(recursive: true);
    final plate = entries
        .map((entry) => entry.vehiclePlate.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => 'XE');
    final safePlate = plate.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final file = File(
      p.join(
        directory.path,
        'NHAT_TRINH_${safePlate}_${month.year}_${month.month.toString().padLeft(2, '0')}.xlsx',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Uint8List buildWorkbookBytes({
    required DateTime month,
    required List<DrivingLogEntry> entries,
  }) {
    if (entries.isEmpty) {
      throw StateError('Không có dữ liệu để xuất');
    }
    final archive = Archive();
    _add(archive, '[Content_Types].xml', _contentTypes);
    _add(archive, '_rels/.rels', _rootRelationships);
    _add(archive, 'xl/workbook.xml', _workbook);
    _add(archive, 'xl/_rels/workbook.xml.rels', _workbookRelationships);
    _add(archive, 'xl/styles.xml', _styles);
    _add(archive, 'xl/worksheets/sheet1.xml', _sheet(month, entries));

    return ZipEncoder().encodeBytes(archive);
  }

  void _add(Archive archive, String name, String content) {
    archive.addFile(ArchiveFile.string(name, content));
  }

  String _sheet(DateTime month, List<DrivingLogEntry> entries) {
    final driver = entries
        .map((entry) => entry.driverName.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final plate = entries
        .map((entry) => entry.vehiclePlate.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final rows = <String>[
      _row(1, [
        _textCell(
          'A1',
          'NHẬT TRÌNH LÁI XE THÁNG ${month.month} NĂM ${month.year}',
          style: 1,
        ),
      ], height: 28),
      _row(2, [
        _textCell('A2', 'Tên lái xe: $driver', style: 2),
        _textCell('F2', 'Biển số: $plate', style: 2),
      ]),
      _row(4, [
        _textCell('A4', 'Ngày', style: 3),
        _textCell('B4', 'TÊN LÁI XE (Phụ xe)', style: 3),
        _textCell('C4', 'TÊN-ĐỊA CHỈ CÔNG TRÌNH', style: 3),
        _textCell('D4', 'SỐ CHUYẾN', style: 3),
        _textCell('E4', 'Ăn ca', style: 3),
        _textCell('F4', 'Luật', style: 3),
        _textCell('G4', 'Làm lốp', style: 3),
        _textCell('H4', 'Chi phí khác', style: 3),
        _textCell('I4', 'Tổng chi phí', style: 3),
        _textCell('J4', 'XÁC NHẬN NGƯỜI QUẢN LÝ', style: 3),
      ], height: 44),
    ];
    for (var index = 0; index < entries.length; index++) {
      final row = index + 5;
      final entry = entries[index];
      rows.add(
        _row(row, [
          _textCell('A$row', _date(entry.voucherDate), style: 4),
          _textCell(
            'B$row',
            entry.assistantName.trim().isEmpty
                ? entry.driverName
                : '${entry.driverName} (${entry.assistantName})',
            style: 5,
          ),
          _textCell('C$row', entry.projectAddress, style: 5),
          _numberCell('D$row', entry.tripCount, style: 6),
          _numberCell('E$row', entry.mealCost, style: 7),
          _numberCell('F$row', entry.ruleCost, style: 7),
          _numberCell('G$row', entry.tyreCost, style: 7),
          _numberCell('H$row', entry.otherCost, style: 7),
          _numberCell('I$row', entry.totalCost, style: 7),
          _textCell('J$row', entry.managerConfirmation, style: 5),
        ], height: 30),
      );
    }
    final lastRow = mathMax(entries.length + 4, 5);
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <dimension ref="A1:J$lastRow"/>
  <sheetViews><sheetView workbookViewId="0"><pane ySplit="4" topLeftCell="A5" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
  <cols>
    <col min="1" max="1" width="11" customWidth="1"/>
    <col min="2" max="2" width="24" customWidth="1"/>
    <col min="3" max="3" width="48" customWidth="1"/>
    <col min="4" max="4" width="12" customWidth="1"/>
    <col min="5" max="9" width="15" customWidth="1"/>
    <col min="10" max="10" width="24" customWidth="1"/>
  </cols>
  <sheetData>${rows.join()}</sheetData>
  <mergeCells count="3"><mergeCell ref="A1:J1"/><mergeCell ref="A2:E2"/><mergeCell ref="F2:J2"/></mergeCells>
  <autoFilter ref="A4:J$lastRow"/>
  <pageMargins left="0.25" right="0.25" top="0.5" bottom="0.5" header="0.2" footer="0.2"/>
</worksheet>''';
  }

  String _row(int row, List<String> cells, {double? height}) =>
      '<row r="$row"${height == null ? '' : ' ht="$height" customHeight="1"'}>${cells.join()}</row>';

  String _textCell(String ref, String value, {int style = 0}) =>
      '<c r="$ref" s="$style" t="inlineStr"><is><t xml:space="preserve">${_escape(value)}</t></is></c>';

  String _numberCell(String ref, int? value, {int style = 0}) => value == null
      ? '<c r="$ref" s="$style"/>'
      : '<c r="$ref" s="$style"><v>$value</v></c>';

  String _date(DateTime? value) =>
      value == null ? '' : '${value.day}/${value.month}/${value.year}';

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

int mathMax(int first, int second) => first > second ? first : second;

const _contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>''';

const _rootRelationships =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

const _workbook = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets><sheet name="Nhật trình" sheetId="1" r:id="rId1"/></sheets>
</workbook>''';

const _workbookRelationships =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

const _styles = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="3">
    <font><sz val="11"/><name val="Times New Roman"/></font>
    <font><b/><sz val="18"/><name val="Times New Roman"/></font>
    <font><b/><sz val="11"/><name val="Times New Roman"/></font>
  </fonts>
  <fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFEAF2FA"/><bgColor indexed="64"/></patternFill></fill></fills>
  <borders count="2"><border/><border><left style="thin"/><right style="thin"/><top style="thin"/><bottom style="thin"/><diagonal/></border></borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="8">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="center"/></xf>
    <xf numFmtId="0" fontId="2" fillId="2" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
    <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf>
    <xf numFmtId="1" fontId="0" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="3" fontId="0" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="right" vertical="center"/></xf>
  </cellXfs>
  <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>''';
