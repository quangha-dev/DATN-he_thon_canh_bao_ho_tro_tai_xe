import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'document_field_extractor.dart';
import 'driving_log_entry.dart';
import 'on_device_vietocr_service.dart';

void _traceOcrStage(String stage, Stopwatch stopwatch) {
  if (kDebugMode) {
    debugPrint('SAFEFLEET_OCR_STAGE|$stage|${stopwatch.elapsedMilliseconds}ms');
  }
}

class DocumentScanService {
  DocumentScanService({
    TextRecognizer? recognizer,
    this._vietOcr = const OnDeviceVietOcrService(),
  }) : _recognizer =
           recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;
  final OnDeviceVietOcrService _vietOcr;
  final _fieldExtractor = const DocumentFieldExtractor();
  final _uuid = const Uuid();

  Future<DrivingLogEntry> createPendingServerDraft({
    required String sourcePath,
    String driverName = '',
    String vehiclePlate = '',
  }) async {
    final id = _uuid.v4();
    final root = await getApplicationDocumentsDirectory();
    final scanDirectory = Directory(p.join(root.path, 'driving_log_scans'));
    await scanDirectory.create(recursive: true);
    final extension = p.extension(sourcePath).toLowerCase();
    final supportedExtension = const {
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
    }.contains(extension);
    if (!supportedExtension) {
      throw const FormatException('Ảnh phải có định dạng JPEG, PNG hoặc WebP');
    }
    final originalPath = p.join(scanDirectory.path, '${id}_original$extension');
    await File(sourcePath).copy(originalPath);
    final now = DateTime.now();
    return DrivingLogEntry(
      id: id,
      imagePath: originalPath,
      originalImagePath: originalPath,
      qualityLevel: ScanQualityLevel.yellow,
      qualityScore: 0,
      qualityIssues: const [pendingComputerOcrIssue],
      ocrText: '',
      fieldConfidences: {
        'driverName': driverName.trim().isEmpty ? 0 : 1,
        'vehiclePlate': vehiclePlate.trim().isEmpty ? 0 : 0.55,
        'projectAddress': 0,
      },
      voucherDate: null,
      driverName: driverName.trim(),
      assistantName: '',
      vehiclePlate: DocumentFieldExtractor.normalizePlate(vehiclePlate),
      projectAddress: '',
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
  }

  Future<DrivingLogEntry> process({
    required String sourcePath,
    String driverName = '',
    String vehiclePlate = '',
    bool useFocusedProjectOcr = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    final id = _uuid.v4();
    final root = await getApplicationDocumentsDirectory();
    final scanDirectory = Directory(p.join(root.path, 'driving_log_scans'));
    await scanDirectory.create(recursive: true);

    final sourceBytes = await File(sourcePath).readAsBytes();
    _traceOcrStage('source-read', stopwatch);
    final processed = await compute(_preprocessDocument, sourceBytes);
    _traceOcrStage('preprocessed', stopwatch);
    final sourceExtension = p.extension(sourcePath).toLowerCase();
    final preservesOriginalBytes = const {
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
    }.contains(sourceExtension);
    final originalPath = p.join(
      scanDirectory.path,
      '${id}_original${preservesOriginalBytes ? sourceExtension : '.jpg'}',
    );
    // File gửi lên server phải giữ nguyên byte từ camera/thư viện. Việc giải
    // mã rồi encode JPEG lại làm mất nét chữ nhỏ và từng gây Bắc -> Bic,
    // Yên -> Yêu. Chỉ đổi sang JPEG khi định dạng đầu vào không được API hỗ trợ.
    await File(originalPath).writeAsBytes(
      preservesOriginalBytes ? sourceBytes : processed.originalBytes,
      flush: true,
    );

    final orientation = await _recognizeBestOrientation(
      scanDirectory: scanDirectory,
      id: id,
      bytes: processed.scanBytes,
    );
    _traceOcrStage('orientation-recognized', stopwatch);
    final imagePath = p.join(scanDirectory.path, '$id.jpg');
    await File(imagePath).writeAsBytes(orientation.bytes, flush: true);

    final snapshots = <DocumentOcrSnapshot>[orientation.snapshot];
    // Luôn OCR các vùng quan trọng. Kết quả toàn trang có thể trông "đủ" nhưng
    // vẫn lẫn dòng bảng/chữ ký, vì vậy không dùng confidence toàn trang để bỏ
    // qua lượt OCR chuyên biệt.
    final dateRegion = _adaptiveFocusedRegion(
      orientation.snapshot,
      kind: DocumentOcrSnapshotKind.date,
      fallback: const _NormalizedRegion(
        left: 0,
        top: 0,
        width: 1,
        height: 0.45,
      ),
    );
    final projectRegion = _adaptiveFocusedRegion(
      orientation.snapshot,
      kind: DocumentOcrSnapshotKind.project,
      fallback: const _NormalizedRegion(left: 0, top: 0, width: 1, height: 0.5),
    );
    for (final request in [
      (region: dateRegion, kind: DocumentOcrSnapshotKind.date, suffix: 'date'),
      if (useFocusedProjectOcr)
        (
          region: projectRegion,
          kind: DocumentOcrSnapshotKind.project,
          suffix: 'project',
        ),
    ]) {
      final focused = await _recognizeFocusedRegion(
        scanDirectory: scanDirectory,
        id: id,
        sourceBytes: orientation.bytes,
        region: request.region,
        kind: request.kind,
        suffix: request.suffix,
      );
      if (focused != null) snapshots.add(focused);
    }
    _traceOcrStage('focused-regions-recognized', stopwatch);
    String? vietOcrTrace;
    if (useFocusedProjectOcr) {
      try {
        final vietOcr = await _recognizeProjectWithVietOcr(
          orientation.bytes,
          orientation.snapshot,
        );
        if (vietOcr != null) {
          snapshots.add(vietOcr.snapshot);
          vietOcrTrace =
              '${vietOcr.engine}, ${vietOcr.elapsedMs} ms: ${vietOcr.snapshot.text}';
        }
        _traceOcrStage('vietocr-recognized', stopwatch);
      } catch (_) {
        // Model native là lượt tăng cường; ML Kit vẫn là fallback hoàn toàn offline.
      }
    }
    var extracted = _fieldExtractor.extract(snapshots);
    _traceOcrStage('fields-extracted', stopwatch);
    if ((extracted.confidences['voucherDate'] ?? 0) < 0.8 ||
        (useFocusedProjectOcr &&
            (extracted.confidences['projectAddress'] ?? 0) < 0.8)) {
      final header = await _recognizeFocusedRegion(
        scanDirectory: scanDirectory,
        id: id,
        sourceBytes: orientation.bytes,
        region: const _NormalizedRegion(
          left: 0,
          top: 0,
          width: 1,
          height: 0.42,
        ),
        kind: DocumentOcrSnapshotKind.header,
        suffix: 'header',
      );
      if (header != null) snapshots.add(header);
      extracted = _fieldExtractor.extract(snapshots);
    }

    // Điểm này chỉ phản ánh chất lượng quang học/crop. Thiếu trường OCR được
    // hiển thị bằng độ tin cậy của từng ô, không còn làm ảnh rõ bị hạ màu.
    final score = processed.score;
    final qualityLevel = processed.hardFailure || score < 50
        ? ScanQualityLevel.red
        : score < 80
        ? ScanQualityLevel.yellow
        : ScanQualityLevel.green;
    final now = DateTime.now();
    final plate = extracted.vehiclePlate.isNotEmpty
        ? extracted.vehiclePlate
        : DocumentFieldExtractor.normalizePlate(vehiclePlate);

    final debugOcrText = snapshots
        .map((item) => item.text.trim())
        .where((text) => text.isNotEmpty)
        .toSet()
        .join('\n\n--- OCR vùng tăng cường ---\n');
    stopwatch.stop();
    final localTrace =
        '--- OCR on-device (ML Kit + SafeFleet pipeline, ${stopwatch.elapsedMilliseconds} ms) ---';

    return DrivingLogEntry(
      id: id,
      imagePath: imagePath,
      originalImagePath: originalPath,
      qualityLevel: qualityLevel,
      qualityScore: score,
      qualityIssues: processed.issues.toSet().toList(),
      ocrText:
          '$localTrace\n$debugOcrText'
          '${vietOcrTrace == null ? '' : '\n\n--- VietOCR on-device ---\n$vietOcrTrace'}',
      fieldConfidences: {
        ...extracted.confidences,
        if (extracted.vehiclePlate.isEmpty)
          'vehiclePlate': vehiclePlate.trim().isEmpty ? 0 : 0.55,
        'driverName': driverName.trim().isEmpty ? 0 : 1,
        'tripCount': 0.7,
      },
      voucherDate: extracted.voucherDate,
      driverName: driverName.trim(),
      assistantName: '',
      vehiclePlate: plate,
      projectAddress: extracted.projectAddress,
      tripCount: 1,
      mealCost: null,
      ruleCost: null,
      tyreCost: null,
      otherCost: null,
      managerConfirmation: '',
      voucherNumber: extracted.voucherNumber,
      status: DrivingLogStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<_VietOcrProjectResult?> _recognizeProjectWithVietOcr(
    Uint8List imageBytes,
    DocumentOcrSnapshot snapshot,
  ) async {
    if (snapshot.lines.isEmpty || snapshot.width <= 1 || snapshot.height <= 1) {
      return null;
    }
    DocumentOcrLine? anchor;
    var anchorScore = 0.0;
    for (final line in snapshot.lines) {
      final score = math.max(
        DocumentFieldExtractor.labelSimilarity(line.text, 'tên công trình'),
        DocumentFieldExtractor.labelSimilarity(line.text, 'xuất hàng cho'),
      );
      if (score > anchorScore) {
        anchorScore = score;
        anchor = line;
      }
    }
    if (anchor == null || anchorScore < 0.58) return null;

    DocumentOcrLine? address;
    var addressScore = 0.0;
    final foldedAnchor = DocumentFieldExtractor.normalizeForMatch(anchor.text);
    for (final line in snapshot.lines) {
      if (identical(line, anchor)) continue;
      final normalized = DocumentFieldExtractor.normalizeForMatch(line.text);
      if (_isVietOcrBoundary(normalized)) continue;
      final padded = ' $normalized ';
      final markers = const [
        ' pho ',
        ' phuong ',
        ' duong ',
        ' xa ',
        ' huyen ',
        ' tinh ',
      ].where(padded.contains).length;
      final hasPhone = RegExp(r'\b0\d{8,10}\b').hasMatch(normalized);
      final hasAbbreviatedPlace = RegExp(
        r'\b[pxth]\s+[a-z]',
      ).hasMatch(normalized);
      final verticalGap = (line.centerY - anchor.centerY).abs();
      final nearAnchor =
          verticalGap <= math.max(anchor.height, line.height) * 3.4;
      if (!nearAnchor && markers == 0 && !hasPhone) continue;
      var score = markers * 100.0;
      if (hasPhone) score += 90;
      if (hasAbbreviatedPlace) score += 25;
      score += math.max(0, 45 - verticalGap / math.max(1, anchor.height) * 12);
      if (line.text.length >= 12) score += 12;
      if (score > addressScore) {
        addressScore = score;
        address = line;
      }
    }

    final projectResult = await _recognizeLineWithVietOcr(imageBytes, anchor);
    if (projectResult == null) return null;
    var projectText = _transferOcrCase(projectResult.text, anchor.text);
    if (projectText.trim().isEmpty) return null;
    var elapsed = projectResult.elapsedMs;
    var engine = projectResult.engine;
    String addressText = '';
    if (address != null &&
        !foldedAnchor.contains(
          DocumentFieldExtractor.normalizeForMatch(address.text),
        )) {
      final addressResult = await _recognizeLineWithVietOcr(
        imageBytes,
        address,
      );
      if (addressResult != null) {
        addressText = _transferOcrCase(addressResult.text, address.text);
        elapsed += addressResult.elapsedMs;
        engine = addressResult.engine;
      }
    }
    final recognizedProject =
        DocumentFieldExtractor.labelSimilarity(projectText, 'tên công trình') >=
                0.72 ||
            DocumentFieldExtractor.labelSimilarity(
                  projectText,
                  'xuất hàng cho',
                ) >=
                0.72
        ? projectText
        : 'Tên công trình: $projectText';
    final combined = [recognizedProject, addressText]
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join('\n');
    return _VietOcrProjectResult(
      snapshot: DocumentOcrSnapshot.fromText(
        combined,
        kind: DocumentOcrSnapshotKind.project,
      ),
      elapsedMs: elapsed,
      engine: engine,
    );
  }

  Future<OnDeviceVietOcrResult?> _recognizeLineWithVietOcr(
    Uint8List imageBytes,
    DocumentOcrLine line,
  ) async {
    final segments = _splitLineForVietOcr(line);
    final recognized = <String>[];
    var elapsedMs = 0;
    var engine = 'vietocr-onnx-android';
    for (final segment in segments) {
      final crop = _cropTextLine(imageBytes, segment);
      if (crop == null) continue;
      final expectedCharacters = segment.text.runes.length;
      final result = await _vietOcr.recognizeLine(
        crop,
        maxTokens: (expectedCharacters + 16).clamp(24, 72),
      );
      final text = _transferOcrCase(result.text, segment.text);
      if (text.isNotEmpty) recognized.add(text);
      elapsedMs += result.elapsedMs;
      engine = result.engine;
    }
    if (recognized.isEmpty) return null;
    return OnDeviceVietOcrResult(
      text: recognized.join(' '),
      elapsedMs: elapsedMs,
      engine: '$engine-segmented',
    );
  }

  Future<_OrientationResult> _recognizeBestOrientation({
    required Directory scanDirectory,
    required String id,
    required Uint8List bytes,
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Không đọc được ảnh phiếu');
    }

    _OrientationResult? best;
    for (final angle in const [0, 90, 180, 270]) {
      final candidate = angle == 0
          ? decoded
          : img.copyRotate(decoded, angle: angle);
      final candidateBytes = Uint8List.fromList(
        img.encodeJpg(candidate, quality: 92),
      );
      final temporaryPath = p.join(scanDirectory.path, '${id}_ocr_$angle.jpg');
      final temporary = File(temporaryPath);
      await temporary.writeAsBytes(candidateBytes, flush: true);
      try {
        final recognized = await _recognizer.processImage(
          InputImage.fromFilePath(temporaryPath),
        );
        final score = _orientationScore(recognized.text);
        if (best == null || score > best.score) {
          best = _OrientationResult(
            bytes: candidateBytes,
            snapshot: _snapshotFromRecognized(
              recognized,
              width: candidate.width.toDouble(),
              height: candidate.height.toDouble(),
            ),
            score: score,
          );
        }
      } finally {
        await temporary.delete().catchError((_) => temporary);
      }
    }
    return best ??
        _OrientationResult(
          bytes: bytes,
          snapshot: const DocumentOcrSnapshot(
            text: '',
            lines: [],
            width: 1,
            height: 1,
          ),
          score: 0,
        );
  }

  Future<DocumentOcrSnapshot?> _recognizeFocusedRegion({
    required Directory scanDirectory,
    required String id,
    required Uint8List sourceBytes,
    required _NormalizedRegion region,
    required DocumentOcrSnapshotKind kind,
    required String suffix,
  }) async {
    final variants = await compute(
      _prepareOcrRegionVariants,
      _OcrRegionRequest(sourceBytes, region),
    );
    final color = variants.color;
    final enhanced = variants.enhanced;
    if (color == null && enhanced == null) return null;
    Future<DocumentOcrSnapshot> recognize(
      _PreparedOcrRegion candidate,
      String candidateSuffix,
    ) async {
      final temporaryPath = p.join(
        scanDirectory.path,
        '${id}_ocr_${suffix}_$candidateSuffix.jpg',
      );
      final temporary = File(temporaryPath);
      await temporary.writeAsBytes(candidate.bytes, flush: true);
      try {
        final recognized = await _recognizer.processImage(
          InputImage.fromFilePath(temporaryPath),
        );
        return _snapshotFromRecognized(
          recognized,
          width: candidate.width.toDouble(),
          height: candidate.height.toDouble(),
          kind: kind,
        );
      } finally {
        await temporary.delete().catchError((_) => temporary);
      }
    }

    final candidates =
        <({_PreparedOcrRegion image, DocumentOcrSnapshot snapshot})>[];
    for (final input in [
      if (color != null) (image: color, suffix: 'color'),
      if (enhanced != null) (image: enhanced, suffix: 'enhanced'),
    ]) {
      try {
        candidates.add((
          image: input.image,
          snapshot: await recognize(input.image, input.suffix),
        ));
      } catch (_) {
        // Một biến thể thất bại không làm mất kết quả từ biến thể còn lại.
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort(
      (first, second) => _focusedSnapshotScore(
        second.snapshot,
        kind,
      ).compareTo(_focusedSnapshotScore(first.snapshot, kind)),
    );
    final best = candidates.first;
    final angle = _medianTextAngle(best.snapshot.lines);
    if (angle.abs() < 1 || angle.abs() > 10) return best.snapshot;
    final deskewed = await compute(
      _rotateOcrRegionRequest,
      _RotateOcrRegionRequest(best.image, -angle),
    );
    if (deskewed == null) return best.snapshot;
    try {
      final corrected = await recognize(deskewed, 'deskew');
      return _focusedSnapshotScore(corrected, kind) >=
              _focusedSnapshotScore(best.snapshot, kind)
          ? corrected
          : best.snapshot;
    } catch (_) {
      return best.snapshot;
    }
  }

  _NormalizedRegion _adaptiveFocusedRegion(
    DocumentOcrSnapshot snapshot, {
    required DocumentOcrSnapshotKind kind,
    required _NormalizedRegion fallback,
  }) {
    if (snapshot.width <= 1 || snapshot.height <= 1) return fallback;
    final anchors = kind == DocumentOcrSnapshotKind.date
        ? const ['ngày', 'ngay', 'date']
        : const [
            'tên công trình',
            'ten cong trinh',
            'xuất hàng cho',
            'xuat hang cho',
            'công trình',
            'project',
          ];
    DocumentOcrLine? best;
    var bestScore = 0.0;
    for (final line in snapshot.lines) {
      for (final anchor in anchors) {
        final score = DocumentFieldExtractor.labelSimilarity(line.text, anchor);
        if (score > bestScore) {
          bestScore = score;
          best = line;
        }
      }
    }
    if (best == null || bestScore < 0.68) return fallback;

    final line = best;
    final leftPadding = kind == DocumentOcrSnapshotKind.project ? 0.06 : 0.1;
    final topPadding = kind == DocumentOcrSnapshotKind.project ? 0.04 : 0.06;
    final left = (line.left / snapshot.width - leftPadding).clamp(0.0, 0.95);
    final top = (line.top / snapshot.height - topPadding).clamp(0.0, 0.95);
    final desiredRight = kind == DocumentOcrSnapshotKind.project
        ? 1.0
        : math.max(line.right / snapshot.width + 0.18, left + 0.42);
    final desiredBottom = kind == DocumentOcrSnapshotKind.project
        ? math.max(line.bottom / snapshot.height + 0.2, top + 0.24)
        : math.max(line.bottom / snapshot.height + 0.1, top + 0.16);
    final right = desiredRight.clamp(left + 0.05, 1.0);
    final bottom = desiredBottom.clamp(top + 0.05, 1.0);
    return _NormalizedRegion(
      left: left,
      top: top,
      width: right - left,
      height: bottom - top,
    );
  }

  double _focusedSnapshotScore(
    DocumentOcrSnapshot snapshot,
    DocumentOcrSnapshotKind kind,
  ) {
    final normalized = DocumentFieldExtractor.normalizeForMatch(snapshot.text);
    final confidences = snapshot.lines
        .map((line) => line.confidence)
        .whereType<double>()
        .toList();
    var score = math.min(snapshot.text.length, 400) * 0.15;
    if (confidences.isNotEmpty) {
      score += confidences.reduce((a, b) => a + b) / confidences.length * 100;
    }
    if (kind == DocumentOcrSnapshotKind.project) {
      if (normalized.contains('ten cong trinh')) score += 180;
      if (normalized.contains('xuat hang cho')) score += 100;
      if (normalized.contains('ho ten nguoi nhan hang')) score -= 30;
      if (normalized.contains('phieu xuat kho')) score -= 50;
    } else if (kind == DocumentOcrSnapshotKind.date) {
      if (normalized.contains('ngay') && normalized.contains('thang')) {
        score += 180;
      }
    } else if (kind == DocumentOcrSnapshotKind.header) {
      if (normalized.contains('phieu xuat kho')) score += 120;
    }
    return score;
  }

  DocumentOcrSnapshot _snapshotFromRecognized(
    RecognizedText recognized, {
    required double width,
    required double height,
    DocumentOcrSnapshotKind kind = DocumentOcrSnapshotKind.fullPage,
  }) {
    final lines = <DocumentOcrLine>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final box = line.boundingBox;
        lines.add(
          DocumentOcrLine(
            text: line.text,
            left: box.left,
            top: box.top,
            right: box.right,
            bottom: box.bottom,
            angle: line.angle,
            confidence: line.confidence,
            elements: [
              for (final element in line.elements)
                DocumentOcrElement(
                  text: element.text,
                  left: element.boundingBox.left,
                  top: element.boundingBox.top,
                  right: element.boundingBox.right,
                  bottom: element.boundingBox.bottom,
                  angle: element.angle,
                  confidence: element.confidence,
                ),
            ],
          ),
        );
      }
    }
    return DocumentOcrSnapshot(
      text: recognized.text,
      lines: lines,
      width: width,
      height: height,
      kind: kind,
    );
  }

  int _orientationScore(String text) {
    final normalized = DocumentFieldExtractor.foldVietnamese(
      text,
    ).toUpperCase();
    var score = math.min(text.length, 600);
    for (final anchor in const [
      'PHIEU XUAT KHO',
      'NGAY',
      'HANG MUC',
      'XE VAN CHUYEN',
      'SO LUONG',
      'CONG TRINH',
    ]) {
      if (normalized.contains(anchor)) score += 500;
    }
    return score;
  }

  void dispose() => _recognizer.close();
}

class _OrientationResult {
  const _OrientationResult({
    required this.bytes,
    required this.snapshot,
    required this.score,
  });

  final Uint8List bytes;
  final DocumentOcrSnapshot snapshot;
  final int score;
}

class _VietOcrProjectResult {
  const _VietOcrProjectResult({
    required this.snapshot,
    required this.elapsedMs,
    required this.engine,
  });

  final DocumentOcrSnapshot snapshot;
  final int elapsedMs;
  final String engine;
}

bool _isVietOcrBoundary(String normalized) {
  for (final label in const [
    'phieu xuat kho',
    'hang muc',
    'xuat tai kho',
    'ho ten nguoi nhan hang',
    'ten nhan hieu quy cach',
    'pham chat vat tu',
    'so luong xuat',
    'nguoi giao hang',
    'nguoi nhan hang',
  ]) {
    if (DocumentFieldExtractor.labelSimilarity(normalized, label) >= 0.78) {
      return true;
    }
  }
  return false;
}

List<DocumentOcrLine> _splitLineForVietOcr(
  DocumentOcrLine line, {
  int maxCharacters = 46,
}) {
  if (line.elements.length < 2 || line.text.runes.length <= maxCharacters) {
    return [line];
  }
  final ordered = [...line.elements]..sort((a, b) => a.left.compareTo(b.left));
  final groups = <List<DocumentOcrElement>>[];
  var current = <DocumentOcrElement>[];
  var currentLength = 0;
  for (final element in ordered) {
    final addition = element.text.runes.length + (current.isEmpty ? 0 : 1);
    if (current.isNotEmpty && currentLength + addition > maxCharacters) {
      groups.add(current);
      current = <DocumentOcrElement>[];
      currentLength = 0;
    }
    current.add(element);
    currentLength += element.text.runes.length + (current.length == 1 ? 0 : 1);
  }
  if (current.isNotEmpty) groups.add(current);
  return [
    for (final group in groups)
      DocumentOcrLine(
        text: group.map((element) => element.text).join(' '),
        left: group.map((element) => element.left).reduce(math.min),
        top: group.map((element) => element.top).reduce(math.min),
        right: group.map((element) => element.right).reduce(math.max),
        bottom: group.map((element) => element.bottom).reduce(math.max),
        angle: line.angle,
        confidence: line.confidence,
        elements: group,
      ),
  ];
}

Uint8List? _cropTextLine(Uint8List imageBytes, DocumentOcrLine line) {
  final source = img.decodeImage(imageBytes);
  if (source == null) return null;
  final horizontalPadding = math.max(6, line.height * 0.22).round();
  final verticalPadding = math.max(3, line.height * 0.16).round();
  final left = (line.left.floor() - horizontalPadding)
      .clamp(0, source.width - 2)
      .toInt();
  final top = (line.top.floor() - verticalPadding)
      .clamp(0, source.height - 2)
      .toInt();
  final right = (line.right.ceil() + horizontalPadding)
      .clamp(left + 2, source.width)
      .toInt();
  final bottom = (line.bottom.ceil() + verticalPadding)
      .clamp(top + 2, source.height)
      .toInt();
  final crop = img.copyCrop(
    source,
    x: left,
    y: top,
    width: right - left,
    height: bottom - top,
  );
  return Uint8List.fromList(img.encodePng(crop));
}

String _transferOcrCase(String value, String reference) {
  if (value.trim().isEmpty) return '';
  final words = value.trim().split(RegExp(r'\s+'));
  final referenceWords = reference.trim().split(RegExp(r'\s+'));
  if (words.length != referenceWords.length) return value.trim();
  return [
    for (var index = 0; index < words.length; index++)
      referenceWords[index].isNotEmpty &&
              referenceWords[index][0] == referenceWords[index][0].toUpperCase()
          ? '${words[index][0].toUpperCase()}${words[index].substring(1)}'
          : '${words[index][0].toLowerCase()}${words[index].substring(1)}',
  ].join(' ');
}

class _PreprocessedDocument {
  const _PreprocessedDocument({
    required this.originalBytes,
    required this.scanBytes,
    required this.score,
    required this.issues,
    required this.hardFailure,
  });

  final Uint8List originalBytes;
  final Uint8List scanBytes;
  final int score;
  final List<String> issues;
  final bool hardFailure;
}

class _NormalizedRegion {
  const _NormalizedRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

class _PreparedOcrRegion {
  const _PreparedOcrRegion(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;
}

class _OcrRegionRequest {
  const _OcrRegionRequest(this.sourceBytes, this.region);

  final Uint8List sourceBytes;
  final _NormalizedRegion region;
}

class _PreparedOcrVariants {
  const _PreparedOcrVariants(this.color, this.enhanced);

  final _PreparedOcrRegion? color;
  final _PreparedOcrRegion? enhanced;
}

_PreparedOcrVariants _prepareOcrRegionVariants(_OcrRegionRequest request) {
  return _PreparedOcrVariants(
    _prepareOcrRegion(request.sourceBytes, request.region, enhance: false),
    _prepareOcrRegion(request.sourceBytes, request.region, enhance: true),
  );
}

class _RotateOcrRegionRequest {
  const _RotateOcrRegionRequest(this.source, this.angle);

  final _PreparedOcrRegion source;
  final double angle;
}

_PreparedOcrRegion? _rotateOcrRegionRequest(_RotateOcrRegionRequest request) =>
    _rotateOcrRegion(request.source, request.angle);

double _medianTextAngle(List<DocumentOcrLine> lines) {
  final angles =
      lines
          .map((line) => line.angle)
          .whereType<double>()
          .where((angle) => angle.isFinite && angle.abs() <= 15)
          .toList()
        ..sort();
  if (angles.isEmpty) return 0;
  final middle = angles.length ~/ 2;
  return angles.length.isOdd
      ? angles[middle]
      : (angles[middle - 1] + angles[middle]) / 2;
}

_PreparedOcrRegion? _rotateOcrRegion(_PreparedOcrRegion source, double angle) {
  final decoded = img.decodeImage(source.bytes);
  if (decoded == null) return null;
  decoded.backgroundColor = img.ColorRgb8(255, 255, 255);
  final rotated = img.copyRotate(
    decoded,
    angle: angle,
    interpolation: img.Interpolation.cubic,
  );
  return _PreparedOcrRegion(
    Uint8List.fromList(img.encodeJpg(rotated, quality: 96)),
    rotated.width,
    rotated.height,
  );
}

_PreparedOcrRegion? _prepareOcrRegion(
  Uint8List sourceBytes,
  _NormalizedRegion region, {
  required bool enhance,
}) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null || decoded.width < 32 || decoded.height < 32) return null;
  final left = (decoded.width * region.left).round().clamp(
    0,
    decoded.width - 2,
  );
  final top = (decoded.height * region.top).round().clamp(
    0,
    decoded.height - 2,
  );
  final width = (decoded.width * region.width).round().clamp(
    2,
    decoded.width - left,
  );
  final height = (decoded.height * region.height).round().clamp(
    2,
    decoded.height - top,
  );
  var crop = img.copyCrop(
    decoded,
    x: left,
    y: top,
    width: width,
    height: height,
  );

  // Chữ ở phần đầu phiếu thường nhỏ. Phóng vùng cần đọc nhưng giới hạn kích
  // thước để thời gian và RAM vẫn phù hợp với điện thoại phổ thông.
  final desiredWidth = math.max(crop.width, 1800).clamp(1800, 2600);
  if (desiredWidth != crop.width) {
    crop = img.copyResize(
      crop,
      width: desiredWidth,
      interpolation: img.Interpolation.cubic,
    );
  }

  if (!enhance) {
    return _PreparedOcrRegion(
      Uint8List.fromList(img.encodeJpg(crop, quality: 96)),
      crop.width,
      crop.height,
    );
  }

  final histogram = List<int>.filled(256, 0);
  final luminance = Uint8List(crop.width * crop.height);
  for (var y = 0; y < crop.height; y++) {
    for (var x = 0; x < crop.width; x++) {
      final pixel = crop.getPixel(x, y);
      final gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
          .round()
          .clamp(0, 255);
      luminance[y * crop.width + x] = gray;
      histogram[gray]++;
    }
  }
  final total = crop.width * crop.height;
  final low = _histogramPercentile(histogram, total, 0.02);
  final high = _histogramPercentile(histogram, total, 0.98);
  final range = math.max(24, high - low);
  final enhanced = img.Image(width: crop.width, height: crop.height);
  for (var y = 0; y < crop.height; y++) {
    for (var x = 0; x < crop.width; x++) {
      final value = ((luminance[y * crop.width + x] - low) * 255 / range)
          .round()
          .clamp(0, 255);
      enhanced.setPixelRgba(x, y, value, value, value, 255);
    }
  }
  return _PreparedOcrRegion(
    Uint8List.fromList(img.encodeJpg(enhanced, quality: 96)),
    enhanced.width,
    enhanced.height,
  );
}

int _histogramPercentile(List<int> histogram, int total, double percentile) {
  final target = (total * percentile).round();
  var count = 0;
  for (var value = 0; value < histogram.length; value++) {
    count += histogram[value];
    if (count >= target) return value;
  }
  return histogram.length - 1;
}

_PreprocessedDocument _preprocessDocument(Uint8List sourceBytes) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    throw const FormatException('Tệp ảnh không hợp lệ');
  }
  final original = img.bakeOrientation(decoded);
  final originalBytes = Uint8List.fromList(
    img.encodeJpg(original, quality: 94),
  );
  final longest = math.max(original.width, original.height);
  final scale = longest > 640 ? 640 / longest : 1.0;
  final preview = scale < 1
      ? img.copyResize(
          original,
          width: (original.width * scale).round(),
          height: (original.height * scale).round(),
          interpolation: img.Interpolation.average,
        )
      : original.clone();

  final detection = _detectDocument(preview);
  var hardFailure = detection == null;
  var issues = <String>[];
  img.Image scan;
  double coverage = 1;
  if (detection == null) {
    scan = original.clone();
    issues.add('Không xác định chắc chắn được đủ bốn cạnh phiếu');
  } else {
    final inverseScaleX = original.width / preview.width;
    final inverseScaleY = original.height / preview.height;
    final points = detection.points
        .map(
          (point) => _Point(point.x * inverseScaleX, point.y * inverseScaleY),
        )
        .toList();
    coverage = detection.coverage;
    scan = _warpDocument(original, points);
  }

  final metricsImage = math.max(scan.width, scan.height) > 1000
      ? img.copyResize(
          scan,
          width: scan.width >= scan.height ? 1000 : null,
          height: scan.height > scan.width ? 1000 : null,
          interpolation: img.Interpolation.average,
        )
      : scan;
  final metrics = _qualityMetrics(metricsImage);
  var score = 100;
  if (detection == null) score -= 45;
  if (coverage < 0.35) {
    score -= 20;
    issues.add('Phiếu chiếm diện tích quá nhỏ trong ảnh');
  } else if (coverage < 0.52) {
    score -= 8;
    issues.add('Nên đưa camera gần phiếu hơn');
  }
  if (math.min(scan.width, scan.height) < 600) {
    score -= 24;
    hardFailure = true;
    issues.add('Độ phân giải vùng phiếu quá thấp');
  } else if (math.min(scan.width, scan.height) < 900) {
    score -= 10;
    issues.add('Chữ nhỏ, cần kiểm tra kỹ kết quả nhận dạng');
  }
  if (metrics.sharpness < 7) {
    score -= 35;
    hardFailure = true;
    issues.add('Ảnh quá nhòe, cần chụp lại');
  } else if (metrics.sharpness < 14) {
    score -= 14;
    issues.add('Ảnh hơi nhòe');
  }
  if (metrics.contrast < 28) {
    score -= 25;
    issues.add('Độ tương phản thấp, chữ khó đọc');
  } else if (metrics.contrast < 42) {
    score -= 10;
    issues.add('Ánh sáng trên phiếu chưa đều');
  }
  if (metrics.darkRatio > 0.28) {
    score -= 18;
    issues.add('Có vùng tối lớn trên phiếu');
  } else if (metrics.darkRatio > 0.14) {
    score -= 8;
    issues.add('Phiếu có bóng đổ');
  }
  if (metrics.brightRatio > 0.22) {
    score -= 18;
    issues.add('Ảnh bị lóa hoặc cháy sáng');
  } else if (metrics.brightRatio > 0.1) {
    score -= 8;
    issues.add('Một phần phiếu hơi sáng');
  }

  return _PreprocessedDocument(
    originalBytes: originalBytes,
    scanBytes: Uint8List.fromList(img.encodeJpg(scan, quality: 92)),
    score: score.clamp(0, 100),
    issues: issues,
    hardFailure: hardFailure,
  );
}

class _DocumentDetection {
  const _DocumentDetection(this.points, this.coverage);

  final List<_Point> points;
  final double coverage;
}

class _Point {
  const _Point(this.x, this.y);

  final double x;
  final double y;
}

_DocumentDetection? _detectDocument(img.Image image) {
  final width = image.width;
  final height = image.height;
  final total = width * height;
  final luminance = Uint8List(total);
  final histogram = List<int>.filled(256, 0);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final pixel = image.getPixel(x, y);
      final value = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
          .round();
      luminance[y * width + x] = value;
      histogram[value]++;
    }
  }
  final threshold = math.max(95, _otsu(histogram, total) - 12);
  final mask = Uint8List(total);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final pixel = image.getPixel(x, y);
      final maxChannel = math.max(pixel.r, math.max(pixel.g, pixel.b));
      final minChannel = math.min(pixel.r, math.min(pixel.g, pixel.b));
      final lowSaturation = maxChannel - minChannel < 95;
      if (luminance[y * width + x] >= threshold && lowSaturation) {
        mask[y * width + x] = 1;
      }
    }
  }

  final visited = Uint8List(total);
  final queue = Int32List(total);
  var bestCount = 0;
  var bestCorners = <_Point>[];
  for (var start = 0; start < total; start++) {
    if (mask[start] == 0 || visited[start] != 0) continue;
    var head = 0;
    var tail = 0;
    queue[tail++] = start;
    visited[start] = 1;
    var count = 0;
    var minSum = double.infinity;
    var maxSum = double.negativeInfinity;
    var minDiff = double.infinity;
    var maxDiff = double.negativeInfinity;
    var topLeft = const _Point(0, 0);
    var topRight = const _Point(0, 0);
    var bottomRight = const _Point(0, 0);
    var bottomLeft = const _Point(0, 0);
    while (head < tail) {
      final index = queue[head++];
      final x = index % width;
      final y = index ~/ width;
      count++;
      final sum = (x + y).toDouble();
      final diff = (x - y).toDouble();
      if (sum < minSum) {
        minSum = sum;
        topLeft = _Point(x.toDouble(), y.toDouble());
      }
      if (sum > maxSum) {
        maxSum = sum;
        bottomRight = _Point(x.toDouble(), y.toDouble());
      }
      if (diff > maxDiff) {
        maxDiff = diff;
        topRight = _Point(x.toDouble(), y.toDouble());
      }
      if (diff < minDiff) {
        minDiff = diff;
        bottomLeft = _Point(x.toDouble(), y.toDouble());
      }
      if (x > 0) {
        _enqueue(index - 1, mask, visited, queue, tail, (v) => tail = v);
      }
      if (x + 1 < width) {
        _enqueue(index + 1, mask, visited, queue, tail, (v) => tail = v);
      }
      if (y > 0) {
        _enqueue(index - width, mask, visited, queue, tail, (v) => tail = v);
      }
      if (y + 1 < height) {
        _enqueue(index + width, mask, visited, queue, tail, (v) => tail = v);
      }
    }
    if (count > bestCount) {
      bestCount = count;
      bestCorners = [topLeft, topRight, bottomRight, bottomLeft];
    }
  }
  if (bestCount < total * 0.08 || bestCorners.length != 4) return null;
  final expanded = _expandQuad(bestCorners, width, height);
  final area = _polygonArea(expanded);
  if (area < total * 0.18) return null;
  return _DocumentDetection(expanded, (area / total).clamp(0, 1));
}

void _enqueue(
  int index,
  Uint8List mask,
  Uint8List visited,
  Int32List queue,
  int tail,
  void Function(int) updateTail,
) {
  if (mask[index] == 0 || visited[index] != 0) return;
  visited[index] = 1;
  queue[tail] = index;
  updateTail(tail + 1);
}

int _otsu(List<int> histogram, int total) {
  var sum = 0.0;
  for (var index = 0; index < histogram.length; index++) {
    sum += index * histogram[index];
  }
  var backgroundWeight = 0;
  var backgroundSum = 0.0;
  var maximum = 0.0;
  var threshold = 128;
  for (var index = 0; index < histogram.length; index++) {
    backgroundWeight += histogram[index];
    if (backgroundWeight == 0) continue;
    final foregroundWeight = total - backgroundWeight;
    if (foregroundWeight == 0) break;
    backgroundSum += index * histogram[index];
    final backgroundMean = backgroundSum / backgroundWeight;
    final foregroundMean = (sum - backgroundSum) / foregroundWeight;
    final between =
        backgroundWeight *
        foregroundWeight *
        math.pow(backgroundMean - foregroundMean, 2);
    if (between > maximum) {
      maximum = between.toDouble();
      threshold = index;
    }
  }
  return threshold;
}

List<_Point> _expandQuad(List<_Point> points, int width, int height) {
  final centerX = points.map((p) => p.x).reduce((a, b) => a + b) / 4;
  final centerY = points.map((p) => p.y).reduce((a, b) => a + b) / 4;
  return points
      .map(
        (point) => _Point(
          (centerX + (point.x - centerX) * 1.025).clamp(0, width - 1),
          (centerY + (point.y - centerY) * 1.025).clamp(0, height - 1),
        ),
      )
      .toList();
}

double _polygonArea(List<_Point> points) {
  var area = 0.0;
  for (var index = 0; index < points.length; index++) {
    final current = points[index];
    final next = points[(index + 1) % points.length];
    area += current.x * next.y - next.x * current.y;
  }
  return area.abs() / 2;
}

img.Image _warpDocument(img.Image source, List<_Point> points) {
  final top = _distance(points[0], points[1]);
  final bottom = _distance(points[3], points[2]);
  final left = _distance(points[0], points[3]);
  final right = _distance(points[1], points[2]);
  var width = math.max(top, bottom).round().clamp(320, 2600);
  var height = math.max(left, right).round().clamp(320, 2600);
  final longest = math.max(width, height);
  if (longest > 2200) {
    final ratio = 2200 / longest;
    width = (width * ratio).round();
    height = (height * ratio).round();
  }
  final output = img.Image(width: width, height: height);
  final p0 = points[0];
  final p1 = points[1];
  final p2 = points[2];
  final p3 = points[3];
  final dx1 = p1.x - p2.x;
  final dx2 = p3.x - p2.x;
  final dx3 = p0.x - p1.x + p2.x - p3.x;
  final dy1 = p1.y - p2.y;
  final dy2 = p3.y - p2.y;
  final dy3 = p0.y - p1.y + p2.y - p3.y;
  final denominator = dx1 * dy2 - dx2 * dy1;
  final g = denominator.abs() < 0.000001
      ? 0.0
      : (dx3 * dy2 - dx2 * dy3) / denominator;
  final h = denominator.abs() < 0.000001
      ? 0.0
      : (dx1 * dy3 - dx3 * dy1) / denominator;
  final a = p1.x - p0.x + g * p1.x;
  final b = p3.x - p0.x + h * p3.x;
  final c = p0.x;
  final d = p1.y - p0.y + g * p1.y;
  final e = p3.y - p0.y + h * p3.y;
  final f = p0.y;

  for (var y = 0; y < height; y++) {
    final v = height <= 1 ? 0.0 : y / (height - 1);
    for (var x = 0; x < width; x++) {
      final u = width <= 1 ? 0.0 : x / (width - 1);
      final z = g * u + h * v + 1;
      final sourceX = ((a * u + b * v + c) / z).clamp(0, source.width - 1);
      final sourceY = ((d * u + e * v + f) / z).clamp(0, source.height - 1);
      final pixel = source.getPixel(sourceX.round(), sourceY.round());
      output.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, pixel.a);
    }
  }
  return output;
}

double _distance(_Point first, _Point second) => math.sqrt(
  math.pow(first.x - second.x, 2) + math.pow(first.y - second.y, 2),
);

class _QualityMetrics {
  const _QualityMetrics({
    required this.sharpness,
    required this.contrast,
    required this.darkRatio,
    required this.brightRatio,
  });

  final double sharpness;
  final double contrast;
  final double darkRatio;
  final double brightRatio;
}

_QualityMetrics _qualityMetrics(img.Image image) {
  final width = image.width;
  final height = image.height;
  final gray = Float64List(width * height);
  var sum = 0.0;
  var dark = 0;
  var bright = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final pixel = image.getPixel(x, y);
      final value = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
      gray[y * width + x] = value;
      sum += value;
      if (value < 45) dark++;
      if (value > 248) bright++;
    }
  }
  final count = width * height;
  final mean = sum / count;
  var variance = 0.0;
  var laplacian = 0.0;
  var laplacianCount = 0;
  for (var y = 1; y < height - 1; y += 2) {
    for (var x = 1; x < width - 1; x += 2) {
      final center = gray[y * width + x];
      variance += math.pow(center - mean, 2);
      laplacian +=
          (-4 * center +
                  gray[(y - 1) * width + x] +
                  gray[(y + 1) * width + x] +
                  gray[y * width + x - 1] +
                  gray[y * width + x + 1])
              .abs();
      laplacianCount++;
    }
  }
  return _QualityMetrics(
    sharpness: laplacianCount == 0 ? 0 : laplacian / laplacianCount,
    contrast: laplacianCount == 0 ? 0 : math.sqrt(variance / laplacianCount),
    darkRatio: dark / count,
    brightRatio: bright / count,
  );
}
