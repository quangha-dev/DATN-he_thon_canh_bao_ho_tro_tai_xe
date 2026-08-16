import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/network/api_client.dart';
import 'document_field_extractor.dart';
import 'driving_log_entry.dart';

class ServerDocumentOcrResult {
  const ServerDocumentOcrResult({
    required this.projectAddress,
    required this.engine,
    required this.elapsedMs,
    this.voucherDate,
    this.voucherNumber = '',
    this.vehiclePlate = '',
    this.driverName = '',
    this.tripCount,
    this.rawText = '',
    this.fieldConfidences = const {},
  });

  final String projectAddress;
  final String engine;
  final int elapsedMs;
  final DateTime? voucherDate;
  final String voucherNumber;
  final String vehiclePlate;
  final String driverName;
  final int? tripCount;
  final String rawText;
  final Map<String, double> fieldConfidences;
}

enum ServerDocumentOcrJobStatus {
  queued,
  processing,
  awaitingReview,
  completed,
  failed,
}

class ServerDocumentOcrJob {
  const ServerDocumentOcrJob({
    required this.id,
    required this.status,
    this.result,
    this.errorMessage,
    this.reviewMessage,
  });

  final int id;
  final ServerDocumentOcrJobStatus status;
  final ServerDocumentOcrResult? result;
  final String? errorMessage;
  final String? reviewMessage;

  bool get isTerminal =>
      status == ServerDocumentOcrJobStatus.completed ||
      status == ServerDocumentOcrJobStatus.failed;
}

abstract interface class DocumentOcrGateway {
  Future<ServerDocumentOcrJob> submit(String imagePath);
  Future<ServerDocumentOcrJob> getJob(int id);
  Future<void> deleteJob(int id);
}

class ServerDocumentOcrService implements DocumentOcrGateway {
  const ServerDocumentOcrService(this._api);

  static const jobsEndpointPath = '/mobile/documents/ocr/jobs';

  final ApiClient _api;

  @override
  Future<ServerDocumentOcrJob> submit(String imagePath) async {
    final image = File(imagePath);
    if (!await image.exists()) {
      throw const ApiFailure('Không tìm thấy ảnh phiếu gốc');
    }
    if (await image.length() == 0) {
      throw const ApiFailure('Ảnh phiếu gốc bị rỗng');
    }
    final extension = p.extension(imagePath).toLowerCase();
    final mediaType = switch (extension) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imagePath,
        filename:
            'driving-log-original${extension.isEmpty ? '.jpg' : extension}',
        contentType: DioMediaType.parse(mediaType),
      ),
    });
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
        jobsEndpointPath,
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      return _parseJob(_api.unwrapMap(response.data));
    } on DioException catch (error) {
      throw _failure(error, uploading: true);
    }
  }

  @override
  Future<ServerDocumentOcrJob> getJob(int id) async {
    try {
      final response = await _api.dio.get<Map<String, dynamic>>(
        '$jobsEndpointPath/$id',
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      return _parseJob(_api.unwrapMap(response.data));
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<void> deleteJob(int id) async {
    try {
      await _api.dio.delete<void>('$jobsEndpointPath/$id');
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) throw _failure(error);
    }
  }

  ServerDocumentOcrJob _parseJob(Map<String, dynamic> data) {
    final id = (data['id'] as num?)?.round();
    if (id == null) throw const ApiFailure('OCR server không trả mã tác vụ');
    final status = switch (data['status']?.toString().toUpperCase()) {
      'QUEUED' => ServerDocumentOcrJobStatus.queued,
      'PROCESSING' => ServerDocumentOcrJobStatus.processing,
      'AWAITING_REVIEW' => ServerDocumentOcrJobStatus.awaitingReview,
      'COMPLETED' => ServerDocumentOcrJobStatus.completed,
      'FAILED' => ServerDocumentOcrJobStatus.failed,
      _ => throw const ApiFailure('Trạng thái OCR server không hợp lệ'),
    };
    ServerDocumentOcrResult? result;
    final projectAddress = data['projectAddress']?.toString().trim() ?? '';
    if (status == ServerDocumentOcrJobStatus.completed) {
      result = ServerDocumentOcrResult(
        projectAddress: projectAddress,
        voucherDate: DateTime.tryParse(data['voucherDate']?.toString() ?? ''),
        voucherNumber: data['voucherNumber']?.toString().trim() ?? '',
        vehiclePlate: data['vehiclePlate']?.toString().trim() ?? '',
        driverName: data['driverName']?.toString().trim() ?? '',
        tripCount: (data['tripCount'] as num?)?.round(),
        rawText: data['rawText']?.toString() ?? '',
        fieldConfidences: (data['fieldConfidences'] as Map? ?? const {}).map(
          (key, value) =>
              MapEntry(key.toString(), value is num ? value.toDouble() : 0),
        ),
        engine: data['engine']?.toString() ?? 'server-ocr',
        elapsedMs: (data['elapsedMs'] as num?)?.round() ?? 0,
      );
    }
    return ServerDocumentOcrJob(
      id: id,
      status: status,
      result: result,
      errorMessage: data['errorMessage']?.toString(),
      reviewMessage: data['plateReviewReason']?.toString(),
    );
  }

  ApiFailure _failure(DioException error, {bool uploading = false}) {
    final responseBody = error.response?.data;
    return ApiFailure(
      responseBody is Map
          ? responseBody['message']?.toString() ?? 'OCR server không khả dụng'
          : switch (error.type) {
              DioExceptionType.connectionTimeout =>
                'Hết thời gian kết nối OCR server',
              DioExceptionType.sendTimeout when uploading =>
                'Hết thời gian gửi ảnh gốc lên máy tính',
              DioExceptionType.receiveTimeout =>
                'Hết thời gian chờ trạng thái OCR server',
              DioExceptionType.connectionError =>
                'Không thể kết nối backend trên máy tính',
              _ => 'OCR server không khả dụng',
            },
      statusCode: error.response?.statusCode,
    );
  }
}

abstract final class DocumentOcrNotificationService {
  static const _channel = MethodChannel(
    'vn.safefleet.safe_fleet_driver_ui/document_ocr',
  );

  static Future<void> completed(String projectAddress) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('showCompleted', {
      'projectAddress': projectAddress,
    });
  }

  static Future<void> failed(String message) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('showFailed', {'message': message});
  }
}

DrivingLogEntry applyServerDocumentOcrResult(
  DrivingLogEntry local,
  ServerDocumentOcrResult server,
) {
  final projectAddress = server.projectAddress.trim();
  final voucherNumber = server.voucherNumber.trim();
  final vehiclePlate = DocumentFieldExtractor.normalizePlate(
    server.vehiclePlate,
  );
  final driverName = server.driverName.trim();
  if (projectAddress.isEmpty &&
      server.voucherDate == null &&
      voucherNumber.isEmpty &&
      vehiclePlate.isEmpty &&
      driverName.isEmpty &&
      server.tripCount == null &&
      server.rawText.trim().isEmpty) {
    return local;
  }
  final trace =
      '--- OCR server (${server.engine}, ${server.elapsedMs} ms) ---\n'
      '${server.rawText.trim().isEmpty ? projectAddress : server.rawText.trim()}';
  final projectWasEnteredByUser =
      local.projectAddress.trim().isNotEmpty &&
      (local.fieldConfidences['projectAddress'] ?? 0) >= 1;
  final plateWasEnteredByUser =
      local.vehiclePlate.trim().isNotEmpty &&
      (local.fieldConfidences['vehiclePlate'] ?? 0) >= 1;
  final recognizedCoreFields = <bool>[
    projectAddress.isNotEmpty,
    server.voucherDate != null,
    voucherNumber.isNotEmpty,
    vehiclePlate.isNotEmpty,
  ].where((recognized) => recognized).length;
  final hasCompleteCoreResult = recognizedCoreFields == 4;
  final merged = local.copyWith(
    voucherDate: local.voucherDate ?? server.voucherDate,
    projectAddress: projectWasEnteredByUser || projectAddress.isEmpty
        ? local.projectAddress
        : projectAddress,
    voucherNumber:
        local.voucherNumber.trim().isNotEmpty || voucherNumber.isEmpty
        ? local.voucherNumber
        : voucherNumber,
    vehiclePlate: plateWasEnteredByUser || vehiclePlate.isEmpty
        ? local.vehiclePlate
        : vehiclePlate,
    driverName: local.driverName.trim().isNotEmpty || driverName.isEmpty
        ? local.driverName
        : driverName,
    tripCount: local.tripCount ?? server.tripCount,
    // Ảnh trong hàng đợi bắt đầu ở mức vàng/0. Khi OCR máy tính nhận đủ
    // bốn trường in chính, phản ánh đúng kết quả bằng trạng thái xanh.
    qualityLevel: hasCompleteCoreResult
        ? ScanQualityLevel.green
        : ScanQualityLevel.yellow,
    qualityScore: hasCompleteCoreResult ? 94 : 60 + recognizedCoreFields * 6,
    qualityIssues: local.qualityIssues
        .where((issue) => issue != pendingComputerOcrIssue)
        .toList(),
    ocrText: '${local.ocrText.trim()}\n\n$trace',
    fieldConfidences: {
      ...local.fieldConfidences,
      ...server.fieldConfidences,
      if (projectAddress.isNotEmpty)
        'projectAddress': projectWasEnteredByUser
            ? 1
            : server.fieldConfidences['projectAddress'] ?? 0.99,
      if (local.voucherDate != null)
        'voucherDate': local.fieldConfidences['voucherDate'] ?? 1,
      if (local.voucherNumber.trim().isNotEmpty)
        'voucherNumber': local.fieldConfidences['voucherNumber'] ?? 1,
      if (plateWasEnteredByUser) 'vehiclePlate': 1,
      if (local.driverName.trim().isNotEmpty)
        'driverName': local.fieldConfidences['driverName'] ?? 1,
    },
  );
  return merged.copyWith(
    status: local.status == DrivingLogStatus.exported
        ? DrivingLogStatus.exported
        : merged.hasRequiredOperationalFields
        ? DrivingLogStatus.verified
        : DrivingLogStatus.draft,
  );
}
