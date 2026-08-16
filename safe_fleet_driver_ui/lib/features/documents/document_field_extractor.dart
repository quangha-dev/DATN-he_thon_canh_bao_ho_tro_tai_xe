import 'dart:math' as math;

/// Vùng OCR đã được chuẩn hóa từ ML Kit. Tọa độ được giữ lại để ghép các dòng
/// theo bố cục của phiếu thay vì phụ thuộc hoàn toàn vào thứ tự chuỗi OCR.
class DocumentOcrSnapshot {
  const DocumentOcrSnapshot({
    required this.text,
    required this.lines,
    required this.width,
    required this.height,
    this.kind = DocumentOcrSnapshotKind.fullPage,
  });

  factory DocumentOcrSnapshot.fromText(
    String text, {
    DocumentOcrSnapshotKind kind = DocumentOcrSnapshotKind.fullPage,
  }) {
    final rawLines = text
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
    return DocumentOcrSnapshot(
      text: text,
      lines: [
        for (var index = 0; index < rawLines.length; index++)
          DocumentOcrLine(
            text: rawLines[index].trim(),
            left: 0,
            top: index.toDouble(),
            right: 1,
            bottom: index + 0.8,
          ),
      ],
      width: 1,
      height: math.max(1, rawLines.length).toDouble(),
      kind: kind,
    );
  }

  final String text;
  final List<DocumentOcrLine> lines;
  final double width;
  final double height;
  final DocumentOcrSnapshotKind kind;
}

enum DocumentOcrSnapshotKind { fullPage, header, project, date }

class DocumentOcrLine {
  const DocumentOcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.angle,
    this.confidence,
    this.elements = const [],
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double? angle;
  final double? confidence;
  final List<DocumentOcrElement> elements;

  double get height => math.max(1, bottom - top);
  double get centerY => (top + bottom) / 2;
}

class DocumentOcrElement {
  const DocumentOcrElement({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.angle,
    this.confidence,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double? angle;
  final double? confidence;
}

class DocumentFieldExtraction {
  const DocumentFieldExtraction({
    required this.voucherDate,
    required this.voucherNumber,
    required this.vehiclePlate,
    required this.projectAddress,
    required this.confidences,
  });

  final DateTime? voucherDate;
  final String voucherNumber;
  final String vehiclePlate;
  final String projectAddress;
  final Map<String, double> confidences;
}

/// Bộ tách trường dành cho phiếu xuất kho.
///
/// OCR ký tự vẫn do ML Kit xử lý. Lớp này giải quyết phần hiểu biểu mẫu:
/// đối sánh nhãn gần đúng, ghép dòng theo vị trí và chọn kết quả tốt nhất từ
/// OCR toàn trang cùng các lượt OCR vùng chuyên biệt.
class DocumentFieldExtractor {
  const DocumentFieldExtractor();

  DocumentFieldExtraction extract(Iterable<DocumentOcrSnapshot> snapshots) {
    final available = snapshots.where((item) => item.text.trim().isNotEmpty);
    _DateCandidate? bestDate;
    _TextCandidate? bestProject;
    _TextCandidate? bestVoucher;
    _TextCandidate? bestPlate;

    for (final snapshot in available) {
      final date = _extractDate(snapshot);
      if (date != null && (bestDate == null || date.score > bestDate.score)) {
        bestDate = date;
      }
      final project = _extractProject(snapshot);
      if (project != null &&
          (bestProject == null || project.score > bestProject.score)) {
        bestProject = project;
      }
      final textOrderProject = _extractProjectFromTextOrder(snapshot);
      if (textOrderProject != null &&
          (bestProject == null || textOrderProject.score > bestProject.score)) {
        bestProject = textOrderProject;
      }
      final voucher = _extractVoucher(snapshot);
      if (voucher != null &&
          (bestVoucher == null || voucher.score > bestVoucher.score)) {
        bestVoucher = voucher;
      }
      final plate = _extractPlate(snapshot);
      if (plate != null &&
          (bestPlate == null || plate.score > bestPlate.score)) {
        bestPlate = plate;
      }
    }

    return DocumentFieldExtraction(
      voucherDate: bestDate?.value,
      voucherNumber: bestVoucher?.value ?? '',
      vehiclePlate: bestPlate == null ? '' : normalizePlate(bestPlate.value),
      projectAddress: bestProject?.value ?? '',
      confidences: {
        'voucherDate': bestDate?.score.clamp(0, 1) ?? 0,
        'voucherNumber': bestVoucher?.score.clamp(0, 1) ?? 0,
        'vehiclePlate': bestPlate?.score.clamp(0, 1) ?? 0,
        'projectAddress': bestProject?.score.clamp(0, 1) ?? 0,
      },
    );
  }

  _DateCandidate? _extractDate(DocumentOcrSnapshot snapshot) {
    final folded = foldVietnamese(snapshot.text);
    final candidates = <_DateCandidate>[];
    final wordPattern = RegExp(
      r'ng[a4]y\s*([0-9oilsb]{1,2})\s*th[a4]ng\s*([0-9oilsb]{1,2})(?:\s*n[a4]m)?\s*([0-9oilsb]{4})',
      caseSensitive: false,
    );
    for (final match in wordPattern.allMatches(folded)) {
      final value = _validatedDate(
        _ocrNumber(match.group(1)!),
        _ocrNumber(match.group(2)!),
        _ocrNumber(match.group(3)!),
      );
      if (value != null) {
        candidates.add(
          _DateCandidate(value, 0.93 + _regionBoost(snapshot.kind, date: true)),
        );
      }
    }

    final numericPattern = RegExp(
      r'(?<!\d)([0-9oilsb]{1,2})\s*[./-]\s*([0-9oilsb]{1,2})\s*[./-]\s*([0-9oilsb]{2,4})(?!\d)',
      caseSensitive: false,
    );
    for (final match in numericPattern.allMatches(folded)) {
      var year = _ocrNumber(match.group(3)!);
      if (year != null && year < 100) year += 2000;
      final value = _validatedDate(
        _ocrNumber(match.group(1)!),
        _ocrNumber(match.group(2)!),
        year,
      );
      if (value != null) {
        candidates.add(
          _DateCandidate(value, 0.84 + _regionBoost(snapshot.kind, date: true)),
        );
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.first;
  }

  _TextCandidate? _extractProject(DocumentOcrSnapshot snapshot) {
    final lines = [...snapshot.lines]
      ..sort((first, second) {
        final rowTolerance = math.max(
          snapshot.height <= 10 ? 0.1 : 3.0,
          math.max(first.height, second.height) * 0.55,
        );
        if ((first.centerY - second.centerY).abs() <= rowTolerance) {
          return first.left.compareTo(second.left);
        }
        return first.centerY.compareTo(second.centerY);
      });
    _TextCandidate? best;
    for (var index = 0; index < lines.length; index++) {
      final anchorLine = lines[index];
      final normalized = normalizeForMatch(anchorLine.text);
      final labelScore = math.max(
        _anchorSimilarity(normalized, 'ten cong trinh'),
        _anchorSimilarity(normalized, 'xuat hang cho'),
      );
      if (labelScore < 0.72) continue;

      final parts = <String>[];
      final firstPart = _truncateAtProjectBoundary(
        _stripProjectLabels(anchorLine.text),
      );
      if (_isUsefulProjectText(firstPart)) parts.add(firstPart);
      var previous = anchorLine;
      var continuationRows = 0;
      final valueStartX = _projectValueStartX(anchorLine);
      for (
        var nextIndex = index + 1;
        nextIndex < lines.length && nextIndex <= index + 6;
        nextIndex++
      ) {
        final next = lines[nextIndex];
        final nextNormalized = normalizeForMatch(next.text);
        if (_isVoucherTitle(nextNormalized)) continue;
        if (_isProjectStopLine(nextNormalized)) break;

        final sameBaseline =
            (next.centerY - previous.centerY).abs() <=
            math.max(next.height, previous.height) * 0.65;
        if (sameBaseline && next.left + 2 < previous.left) continue;

        if (!sameBaseline) {
          final gap = next.top - previous.bottom;
          final maximumGap = math.max(
            previous.height * 1.35,
            snapshot.height * 0.022,
          );
          if (gap < -math.max(next.height, previous.height) * 0.4) continue;
          if (gap > maximumGap || continuationRows >= 2) break;
          if (snapshot.width > 4 &&
              (next.right < valueStartX ||
                  next.left > valueStartX + snapshot.width * 0.22)) {
            break;
          }
          final previousAngle = previous.angle ?? 0;
          final nextAngle = next.angle ?? previousAngle;
          if ((nextAngle - previousAngle).abs() > 6) break;
          continuationRows++;
        }

        final nextPart = _truncateAtProjectBoundary(
          _stripProjectLabels(next.text, allowLooseColon: false),
        );
        if (!_isUsefulProjectText(nextPart)) {
          if (_containsProjectBoundary(next.text)) break;
          continue;
        }
        parts.add(nextPart);
        previous = next;
        if (_containsProjectBoundary(next.text)) {
          break;
        }
      }

      final value = _cleanProject(parts.join(' '));
      if (value.length < 4) continue;
      var score = 0.58 + labelScore * 0.2;
      score += _regionBoost(snapshot.kind, project: true);
      // Vùng crop chuyên biệt thường đọc nét hơn nhưng đôi khi cắt mất phần
      // địa chỉ xuống dòng. Thưởng theo lượng thông tin hữu ích để bản toàn
      // trang đầy đủ có thể thắng một crop ngắn, thay vì chỉ kiểm tra >=18 ký tự.
      score += math.min(value.length, 180) / 1000;
      final projectStructure = normalizeForMatch(value);
      final addressMarkers = const [
        ' pho ',
        ' phuong ',
        ' duong ',
        ' xa ',
        ' huyen ',
        ' tinh ',
      ].where((marker) => ' $projectStructure '.contains(marker)).length;
      score += math.min(addressMarkers, 4) * 0.018;
      if (RegExp(r'\b0\d{8,10}\b').hasMatch(projectStructure)) score += 0.035;
      if (RegExp(
        r'\b(?:cong ty|nha may|xay dung|duong|phuong|xa|huyen|tinh|ct)\b',
      ).hasMatch(normalizeForMatch(value))) {
        score += 0.05;
      }
      if (anchorLine.confidence case final confidence?) {
        score += (confidence.clamp(0.4, 1) - 0.4) * 0.08;
      }
      final candidate = _TextCandidate(value, score.clamp(0, 0.98));
      if (best == null || candidate.score > best.score) best = candidate;
    }
    return best;
  }

  _TextCandidate? _extractProjectFromTextOrder(DocumentOcrSnapshot snapshot) {
    final rawLines = snapshot.text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    _TextCandidate? best;
    for (var index = 0; index < rawLines.length; index++) {
      final normalized = normalizeForMatch(rawLines[index]);
      final labelScore = math.max(
        _anchorSimilarity(normalized, 'ten cong trinh'),
        _anchorSimilarity(normalized, 'xuat hang cho'),
      );
      if (labelScore < 0.72) continue;

      final parts = <String>[];
      final first = _truncateAtProjectBoundary(
        _stripProjectLabels(rawLines[index]),
      );
      if (_isUsefulProjectText(first)) parts.add(first);
      for (
        var nextIndex = index + 1;
        nextIndex < rawLines.length && nextIndex <= index + 3;
        nextIndex++
      ) {
        final line = rawLines[nextIndex];
        final lineNormalized = normalizeForMatch(line);
        if (_isProjectStopLine(lineNormalized)) break;
        final part = _truncateAtProjectBoundary(
          _stripProjectLabels(line, allowLooseColon: false),
        );
        if (_isUsefulProjectText(part)) parts.add(part);
        if (_containsProjectBoundary(line)) break;
      }

      final value = _cleanProject(parts.join(' '));
      if (value.length < 4) continue;
      var score = 0.58 + labelScore * 0.2;
      score += _regionBoost(snapshot.kind, project: true);
      score += math.min(value.length, 180) / 1000;
      final structure = ' ${normalizeForMatch(value)} ';
      final addressMarkers = const [
        ' pho ',
        ' phuong ',
        ' duong ',
        ' xa ',
        ' huyen ',
        ' tinh ',
      ].where(structure.contains).length;
      score += math.min(addressMarkers, 4) * 0.018;
      if (RegExp(r'\b0\d{8,10}\b').hasMatch(structure)) score += 0.035;
      if (RegExp(
        r'\b(?:cong ty|nha may|xay dung|thi cong)\b',
      ).hasMatch(structure)) {
        score += 0.05;
      }
      final candidate = _TextCandidate(value, score.clamp(0, 0.98));
      if (best == null || candidate.score > best.score) best = candidate;
    }
    return best;
  }

  _TextCandidate? _extractVoucher(DocumentOcrSnapshot snapshot) {
    final folded = foldVietnamese(snapshot.text);
    final match = RegExp(
      r'(?:^|\n)\s*so\s*[:.]?\s*([0-9oilsb]{4,})\b',
      caseSensitive: false,
    ).firstMatch(folded);
    if (match == null) return null;
    final number = _ocrNumberString(match.group(1)!);
    if (number.length < 4) return null;
    return _TextCandidate(number, 0.9);
  }

  _TextCandidate? _extractPlate(DocumentOcrSnapshot snapshot) {
    final compact = snapshot.text.replaceAll(RegExp(r'[ \t]+'), ' ');
    final match = RegExp(
      r'\b\d{2}\s*[A-Za-z]\s*[-.]?\s*\d{3}\s*[.-]?\s*\d{2}\b',
    ).firstMatch(compact);
    if (match == null) return null;
    return _TextCandidate(match.group(0)!, 0.92);
  }

  static double _regionBoost(
    DocumentOcrSnapshotKind kind, {
    bool date = false,
    bool project = false,
  }) => switch (kind) {
    DocumentOcrSnapshotKind.date when date => 0.05,
    DocumentOcrSnapshotKind.project when project => 0,
    DocumentOcrSnapshotKind.header when date || project => 0.03,
    _ => 0,
  };

  static DateTime? _validatedDate(int? day, int? month, int? year) {
    if (day == null || month == null || year == null) return null;
    if (year < 2000 || year > 2100) return null;
    final candidate = DateTime(year, month, day);
    return candidate.day == day && candidate.month == month ? candidate : null;
  }

  static int? _ocrNumber(String value) => int.tryParse(_ocrNumberString(value));

  static String _ocrNumberString(String value) => value
      .toLowerCase()
      .replaceAll('o', '0')
      .replaceAll('i', '1')
      .replaceAll('l', '1')
      .replaceAll('s', '5')
      .replaceAll('b', '8')
      .replaceAll(RegExp(r'\D'), '');

  static bool _isProjectStopLine(String normalized) {
    if (normalized.isEmpty) return false;
    for (final anchor in const [
      'phieu xuat kho',
      'mau so',
      'ho ten nguoi nhan hang',
      'xe van chuyen',
      'xuat tai kho',
      'hang muc',
      'so thu tu',
      'ten nhan hieu quy cach',
      'pham chat vat tu',
      'don vi tinh',
      'so luong xuat',
      'xac nhan',
      'nguoi lap phieu',
      'nguoi giao hang',
      'nguoi nhan hang',
      'dai dien nha may',
      'ky ho ten',
    ]) {
      if (_anchorSimilarity(normalized, anchor) >= 0.78) return true;
    }
    if (RegExp(
      r'^(?:[a-z]{2,5}\s*)?\d{2,4}(?:\s+\d{1,4}){1,3}\s*[a-z]?$',
    ).hasMatch(normalized)) {
      return true;
    }
    return false;
  }

  static bool _isVoucherTitle(String normalized) =>
      _anchorSimilarity(normalized, 'phieu xuat kho') >= 0.78 ||
      _anchorSimilarity(normalized, 'mau so') >= 0.82;

  static double _projectValueStartX(DocumentOcrLine line) {
    if (line.elements.isEmpty) {
      return line.left + (line.right - line.left) * 0.22;
    }
    var labelEnded = false;
    for (final element in line.elements) {
      final normalized = normalizeForMatch(element.text);
      if (labelEnded) return element.left;
      if (normalized == 'trinh' || normalized == 'cho') labelEnded = true;
    }
    return line.left + (line.right - line.left) * 0.22;
  }

  static final RegExp _projectBoundaryPattern = RegExp(
    r'(?:^|\s)[\-–—•]?\s*(?:phieu\s*xuat\s*kho|mau\s*so|ho\s*ten\s*nguoi\s*nhan\s*hang|xe\s*van\s*chuyen|xuat\s*tai\s*kho|hang\s*muc|so\s*thu\s*tu|ten\s*nhan\s*hieu|don\s*vi\s*tinh|so\s*luong\s*xuat|nguoi\s*lap\s*phieu|nguoi\s*giao\s*hang|dai\s*dien\s*nha\s*may|ky\s*,?\s*ho\s*ten)\s*[:.]?',
    caseSensitive: false,
  );

  static bool _containsProjectBoundary(String value) =>
      _projectBoundaryPattern.hasMatch(foldVietnamese(value));

  static String _truncateAtProjectBoundary(String value) {
    final match = _projectBoundaryPattern.firstMatch(foldVietnamese(value));
    return match == null
        ? value.trim()
        : value.substring(0, match.start).trim();
  }

  static bool _isUsefulProjectText(String value) {
    final normalized = normalizeForMatch(value);
    if (normalized.length < 3 || _isProjectStopLine(normalized)) return false;
    if (normalized == 'ten cong trinh' || normalized == 'xuat hang cho') {
      return false;
    }
    return true;
  }

  static String _stripProjectLabels(
    String value, {
    bool allowLooseColon = true,
  }) {
    var result = value.trim().replaceFirst(RegExp(r'^[-•–—\s]+'), '');
    for (var pass = 0; pass < 2; pass++) {
      final folded = foldVietnamese(result);
      final exact = RegExp(
        r'^(?:ten\s*cong\s*trinh|xuat\s*(?:t?hang)\s*cho)\s*[:.\-]?\s*',
        caseSensitive: false,
      ).firstMatch(folded);
      if (exact != null) {
        result = result.substring(exact.end).trim();
        continue;
      }
      final colon = result.indexOf(':');
      if (allowLooseColon && colon >= 0 && colon < 40) {
        result = result.substring(colon + 1).trim();
        continue;
      }
      final normalized = normalizeForMatch(result);
      if (_anchorSimilarity(normalized, 'ten cong trinh') >= 0.72 ||
          _anchorSimilarity(normalized, 'xuat hang cho') >= 0.72) {
        final words = result.split(RegExp(r'\s+'));
        result = words.length <= 3 ? '' : words.skip(3).join(' ');
      }
    }
    return result;
  }

  static String _cleanProject(String value) {
    var result = _truncateAtProjectBoundary(value)
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceFirst(RegExp(r'^[:;,.\-\s]+'), '')
        .trim();
    if (result.length > 220) result = result.substring(0, 220).trimRight();
    return result;
  }

  static double _anchorSimilarity(String normalizedText, String anchor) {
    if (normalizedText.contains(anchor)) return 1;
    final words = normalizedText
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();
    final target = anchor.split(' ');
    if (words.isEmpty) return 0;
    var best = 0.0;
    for (final size in {
      math.max(1, target.length - 1),
      target.length,
      target.length + 1,
    }) {
      if (size > words.length) continue;
      for (var start = 0; start + size <= words.length; start++) {
        final candidate = words.sublist(start, start + size).join(' ');
        final longest = math.max(candidate.length, anchor.length);
        if (longest == 0) continue;
        final similarity = 1 - _levenshtein(candidate, anchor) / longest;
        if (similarity > best) best = similarity;
      }
    }
    return best;
  }

  static int _levenshtein(String first, String second) {
    var previous = List<int>.generate(second.length + 1, (index) => index);
    for (var row = 1; row <= first.length; row++) {
      final current = List<int>.filled(second.length + 1, 0)..[0] = row;
      for (var column = 1; column <= second.length; column++) {
        final cost = first.codeUnitAt(row - 1) == second.codeUnitAt(column - 1)
            ? 0
            : 1;
        current[column] = math.min(
          math.min(current[column - 1] + 1, previous[column] + 1),
          previous[column - 1] + cost,
        );
      }
      previous = current;
    }
    return previous.last;
  }

  static String normalizePlate(String value) => value
      .toUpperCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('.', '')
      .replaceAll('-', '');

  static String normalizeForMatch(String value) => foldVietnamese(value)
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static double labelSimilarity(String value, String label) =>
      _anchorSimilarity(normalizeForMatch(value), normalizeForMatch(label));

  static String foldVietnamese(String value) {
    const source =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
        'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const target =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    var result = value;
    for (var index = 0; index < source.length; index++) {
      result = result.replaceAll(source[index], target[index]);
    }
    return result;
  }
}

class _DateCandidate {
  const _DateCandidate(this.value, this.score);

  final DateTime value;
  final double score;
}

class _TextCandidate {
  const _TextCandidate(this.value, this.score);

  final String value;
  final double score;
}
