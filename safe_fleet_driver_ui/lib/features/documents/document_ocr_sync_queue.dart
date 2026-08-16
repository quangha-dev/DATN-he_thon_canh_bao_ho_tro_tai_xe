import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/network/api_client.dart';
import 'document_ocr_queue_repository.dart';
import 'driving_log_entry.dart';
import 'driving_log_repository.dart';
import 'server_document_ocr_service.dart';

typedef DocumentOcrCompletedNotifier = Future<void> Function(String message);
typedef DocumentOcrFailedNotifier = Future<void> Function(String message);
typedef DocumentOcrConnectivityCheck =
    Future<List<ConnectivityResult>> Function();

class DocumentOcrSyncQueue {
  DocumentOcrSyncQueue({
    required this.queueRepository,
    required this.drivingLogRepository,
    required this.gateway,
    DocumentOcrCompletedNotifier? notifyCompleted,
    DocumentOcrFailedNotifier? notifyFailed,
    Stream<List<ConnectivityResult>>? connectivityChanges,
    DocumentOcrConnectivityCheck? connectivityCheck,
  }) : _notifyCompleted =
           notifyCompleted ?? DocumentOcrNotificationService.completed,
       _notifyFailed = notifyFailed ?? DocumentOcrNotificationService.failed,
       _connectivityChanges =
           connectivityChanges ?? Connectivity().onConnectivityChanged,
       _connectivityCheck =
           connectivityCheck ?? Connectivity().checkConnectivity;

  final DocumentOcrQueueRepository queueRepository;
  final DrivingLogRepository drivingLogRepository;
  final DocumentOcrGateway gateway;
  final DocumentOcrCompletedNotifier _notifyCompleted;
  final DocumentOcrFailedNotifier _notifyFailed;
  final Stream<List<ConnectivityResult>> _connectivityChanges;
  final DocumentOcrConnectivityCheck _connectivityCheck;
  final _changes = StreamController<List<DocumentOcrQueueItem>>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _timer;
  bool _started = false;
  bool _syncing = false;
  bool _rerunRequested = false;
  final Set<String> _cancelledEntryIds = <String>{};

  Stream<List<DocumentOcrQueueItem>> get changes => _changes.stream;

  Future<List<DocumentOcrQueueItem>> list() => queueRepository.list();

  Future<void> start({bool syncImmediately = true}) async {
    if (_started) {
      if (syncImmediately) unawaited(syncNow());
      return;
    }
    _started = true;
    await queueRepository.recoverInterruptedUploads();
    await recoverMissingEntries();
    _connectivitySubscription = _connectivityChanges.listen((results) {
      if (!results.contains(ConnectivityResult.none)) unawaited(syncNow());
    });
    await _emit();
    if (syncImmediately) unawaited(syncNow());
  }

  Future<void> stop() async {
    _started = false;
    _timer?.cancel();
    _timer = null;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  Future<void> enqueue(DrivingLogEntry entry) async {
    await queueRepository.enqueue(
      entryId: entry.id,
      imagePath: entry.originalImagePath.isNotEmpty
          ? entry.originalImagePath
          : entry.imagePath,
    );
    await _emit();
    unawaited(syncNow());
  }

  Future<void> retry(String entryId) async {
    await queueRepository.retry(entryId);
    await _emit();
    unawaited(syncNow());
  }

  Future<void> cancel(String entryId) async {
    _cancelledEntryIds.add(entryId);
    final items = await queueRepository.list();
    DocumentOcrQueueItem? cancelledItem;
    for (final item in items) {
      if (item.entryId == entryId) {
        cancelledItem = item;
        break;
      }
    }
    await queueRepository.remove(entryId);
    await _emit();
    final jobId = cancelledItem?.serverJobId;
    if (jobId != null) {
      unawaited(gateway.deleteJob(jobId).catchError((_) {}));
    }
  }

  /// Khôi phục các phiếu vẫn mang dấu chờ OCR nhưng bị thiếu dòng hàng đợi.
  /// Dấu trên bản ghi là lớp bảo vệ thứ hai để một lần lưu form hoặc ứng dụng
  /// bị dừng đột ngột không thể làm phiếu nhảy nhầm sang mục hoàn thành.
  Future<void> recoverMissingEntries() async {
    final queuedIds = (await queueRepository.list())
        .map((item) => item.entryId)
        .toSet();
    final entries = await drivingLogRepository.list();
    var recovered = false;
    for (final entry in entries) {
      if (!entry.isComputerOcrPending || queuedIds.contains(entry.id)) {
        continue;
      }
      await queueRepository.enqueue(
        entryId: entry.id,
        imagePath: entry.originalImagePath.isNotEmpty
            ? entry.originalImagePath
            : entry.imagePath,
      );
      queuedIds.add(entry.id);
      recovered = true;
    }
    if (recovered) await _emit();
  }

  Future<void> syncNow() async {
    if (!_started) return;
    if (_syncing) {
      _rerunRequested = true;
      return;
    }
    _timer?.cancel();
    _timer = null;
    _syncing = true;
    var hadTransportFailure = false;
    var interfaceOffline = false;
    try {
      try {
        final connectivity = await _connectivityCheck();
        interfaceOffline = connectivity.contains(ConnectivityResult.none);
        if (interfaceOffline) return;
      } catch (_) {
        // Nếu plugin chưa trả trạng thái, thử API thật; lỗi vận chuyển vẫn được
        // giữ trong hàng đợi và retry khi có sự kiện kết nối tiếp theo.
      }
      final uploads = await queueRepository.pendingUploads();
      for (final item in uploads) {
        if (_cancelledEntryIds.contains(item.entryId)) {
          await queueRepository.remove(item.entryId);
          continue;
        }
        await queueRepository.markUploading(item.entryId);
        await _emit();
        try {
          final job = await gateway.submit(item.imagePath);
          if (_cancelledEntryIds.contains(item.entryId)) {
            await queueRepository.remove(item.entryId);
            unawaited(gateway.deleteJob(job.id).catchError((_) {}));
            continue;
          }
          if (job.status == ServerDocumentOcrJobStatus.completed) {
            await _complete(item, job.result!);
          } else if (job.status == ServerDocumentOcrJobStatus.failed) {
            await _failTerminal(
              item,
              job.errorMessage ?? 'OCR máy tính không nhận dạng được phiếu',
            );
          } else if (job.status == ServerDocumentOcrJobStatus.awaitingReview) {
            await queueRepository.markWaitingReview(
              item.entryId,
              job.id,
              job.reviewMessage,
            );
          } else {
            await queueRepository.markWaitingResult(item.entryId, job.id);
          }
        } catch (error) {
          hadTransportFailure = true;
          await queueRepository.markUploadForRetry(item.entryId, error);
        }
        await _emit();
      }

      final waiting = await queueRepository.waitingResults();
      for (final item in waiting) {
        if (_cancelledEntryIds.contains(item.entryId)) {
          await queueRepository.remove(item.entryId);
          if (item.serverJobId != null) {
            unawaited(gateway.deleteJob(item.serverJobId!).catchError((_) {}));
          }
          continue;
        }
        final jobId = item.serverJobId;
        if (jobId == null) {
          await queueRepository.markUploadForRetry(
            item.entryId,
            'Thiếu mã tác vụ OCR máy chủ',
          );
          continue;
        }
        try {
          final job = await gateway.getJob(jobId);
          if (_cancelledEntryIds.contains(item.entryId)) {
            await queueRepository.remove(item.entryId);
            unawaited(gateway.deleteJob(job.id).catchError((_) {}));
            continue;
          }
          if (job.status == ServerDocumentOcrJobStatus.completed) {
            await _complete(item, job.result!);
          } else if (job.status == ServerDocumentOcrJobStatus.failed) {
            await _failTerminal(
              item,
              job.errorMessage ?? 'OCR máy tính không nhận dạng được phiếu',
            );
          } else if (job.status == ServerDocumentOcrJobStatus.awaitingReview) {
            await queueRepository.markWaitingReview(
              item.entryId,
              job.id,
              job.reviewMessage,
            );
          }
        } catch (error) {
          if (error is ApiFailure && error.statusCode == 404) {
            await _failTerminal(
              item,
              'Tác vụ OCR không còn tồn tại trên máy chủ',
            );
          } else {
            hadTransportFailure = true;
            await queueRepository.markResultCheckFailed(
              item.entryId,
              error,
              waitingForReview:
                  item.status == DocumentOcrQueueStatus.waitingReview,
            );
          }
        }
        await _emit();
      }
    } finally {
      _syncing = false;
      final items = await queueRepository.list();
      final hasWaiting = items.any(
        (item) =>
            item.status == DocumentOcrQueueStatus.waitingResult ||
            item.status == DocumentOcrQueueStatus.waitingReview,
      );
      final waitingOnlyForReview =
          hasWaiting &&
          items.every(
            (item) => item.status != DocumentOcrQueueStatus.waitingResult,
          );
      final hasPending = items.any(
        (item) => item.status == DocumentOcrQueueStatus.pendingUpload,
      );
      if (_started && hasWaiting && !interfaceOffline) {
        _schedule(Duration(seconds: waitingOnlyForReview ? 30 : 3));
      } else if (_started && hasPending && hadTransportFailure) {
        _schedule(const Duration(seconds: 30));
      }
      if (_rerunRequested) {
        _rerunRequested = false;
        unawaited(syncNow());
      }
    }
  }

  Future<void> _complete(
    DocumentOcrQueueItem item,
    ServerDocumentOcrResult result,
  ) async {
    if (_cancelledEntryIds.contains(item.entryId)) {
      await queueRepository.remove(item.entryId);
      await drivingLogRepository.delete(item.entryId);
      return;
    }
    final entry = await drivingLogRepository.find(item.entryId);
    if (entry != null) {
      await drivingLogRepository.save(
        applyServerDocumentOcrResult(entry, result),
      );
    }
    if (_cancelledEntryIds.contains(item.entryId)) {
      await drivingLogRepository.delete(item.entryId);
      await queueRepository.remove(item.entryId);
      return;
    }
    await queueRepository.remove(item.entryId);
    await _notifyCompleted(result.projectAddress).catchError((_) {});
  }

  Future<void> _failTerminal(DocumentOcrQueueItem item, String message) async {
    await queueRepository.markFailed(item.entryId, message);
    await _notifyFailed(message).catchError((_) {});
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(syncNow()));
  }

  Future<void> _emit() async {
    if (_changes.isClosed) return;
    _changes.add(await queueRepository.list());
  }

  Future<void> dispose() async {
    await stop();
    await _changes.close();
  }
}
