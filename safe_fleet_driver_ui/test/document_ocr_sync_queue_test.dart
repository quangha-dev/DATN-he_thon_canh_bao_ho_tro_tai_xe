import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:safe_fleet_driver_ui/core/network/api_client.dart';
import 'package:safe_fleet_driver_ui/core/storage/local_database.dart';
import 'package:safe_fleet_driver_ui/features/documents/document_ocr_queue_repository.dart';
import 'package:safe_fleet_driver_ui/features/documents/document_ocr_sync_queue.dart';
import 'package:safe_fleet_driver_ui/features/documents/driving_log_entry.dart';
import 'package:safe_fleet_driver_ui/features/documents/driving_log_repository.dart';
import 'package:safe_fleet_driver_ui/features/documents/server_document_ocr_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeOcrGateway implements DocumentOcrGateway {
  bool offline = false;
  int submitCount = 0;
  final List<int> deletedJobIds = [];
  ServerDocumentOcrJob job = const ServerDocumentOcrJob(
    id: 41,
    status: ServerDocumentOcrJobStatus.queued,
  );

  @override
  Future<ServerDocumentOcrJob> submit(String imagePath) async {
    submitCount += 1;
    if (offline) throw const ApiFailure('offline');
    return job;
  }

  @override
  Future<ServerDocumentOcrJob> getJob(int id) async {
    if (offline) throw const ApiFailure('offline');
    expect(id, job.id);
    return job;
  }

  @override
  Future<void> deleteJob(int id) async {
    if (offline) throw const ApiFailure('offline');
    deletedJobIds.add(id);
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late LocalDatabase database;
  late DrivingLogRepository logRepository;
  late DocumentOcrQueueRepository queueRepository;
  late _FakeOcrGateway gateway;
  late String databaseName;
  late List<String> completedNotifications;

  setUp(() {
    databaseName =
        'safefleet-ocr-queue-${DateTime.now().microsecondsSinceEpoch}.db';
    database = LocalDatabase(databaseName: databaseName);
    logRepository = DrivingLogRepository(database);
    queueRepository = DocumentOcrQueueRepository(database);
    gateway = _FakeOcrGateway();
    completedNotifications = [];
  });

  tearDown(() async {
    await database.close();
    await databaseFactory.deleteDatabase(
      join(await getDatabasesPath(), databaseName),
    );
  });

  DocumentOcrSyncQueue createService({
    DocumentOcrConnectivityCheck? connectivityCheck,
  }) => DocumentOcrSyncQueue(
    queueRepository: queueRepository,
    drivingLogRepository: logRepository,
    gateway: gateway,
    connectivityChanges: const Stream<List<ConnectivityResult>>.empty(),
    connectivityCheck:
        connectivityCheck ?? () async => [ConnectivityResult.wifi],
    notifyCompleted: (message) async => completedNotifications.add(message),
    notifyFailed: (_) async {},
  );

  test('does not attempt upload while the device has no network', () async {
    final entry = _entry(id: 'no-network-entry');
    await logRepository.save(entry);
    final service = createService(
      connectivityCheck: () async => [ConnectivityResult.none],
    );
    await service.enqueue(entry);
    await service.start(syncImmediately: false);

    await service.syncNow();

    final queued = await service.list();
    expect(gateway.submitCount, 0);
    expect(queued.single.status, DocumentOcrQueueStatus.pendingUpload);
    expect(queued.single.attempts, 0);
    await service.dispose();
  });

  test(
    'keeps upload offline then applies the server result when online',
    () async {
      final entry = _entry();
      await logRepository.save(entry);
      final service = createService();
      await service.enqueue(entry);
      await service.start(syncImmediately: false);

      gateway.offline = true;
      await service.syncNow();
      var queued = await service.list();
      expect(queued, hasLength(1));
      expect(queued.single.status, DocumentOcrQueueStatus.pendingUpload);
      expect(queued.single.attempts, 1);

      gateway.offline = false;
      await service.syncNow();
      queued = await service.list();
      expect(gateway.submitCount, 2);
      expect(queued.single.status, DocumentOcrQueueStatus.waitingResult);
      expect(queued.single.serverJobId, 41);

      gateway.job = const ServerDocumentOcrJob(
        id: 41,
        status: ServerDocumentOcrJobStatus.completed,
        result: ServerDocumentOcrResult(
          projectAddress: 'CT xây dựng nhà máy chính xác',
          engine: 'server_hybrid_tesseract_best_vietocr',
          elapsedMs: 9123,
        ),
      );
      await service.syncNow();

      expect(await service.list(), isEmpty);
      final updated = await logRepository.find(entry.id);
      expect(updated!.projectAddress, 'CT xây dựng nhà máy chính xác');
      expect(updated.ocrText, contains('server_hybrid_tesseract_best_vietocr'));
      expect(completedNotifications, ['CT xây dựng nhà máy chính xác']);
      await service.dispose();
    },
  );

  test('resumes polling a persisted server job after app restart', () async {
    final entry = _entry(id: 'restart-entry');
    await logRepository.save(entry);
    await queueRepository.enqueue(
      entryId: entry.id,
      imagePath: entry.originalImagePath,
    );
    await queueRepository.markWaitingResult(entry.id, 77);
    gateway.job = const ServerDocumentOcrJob(
      id: 77,
      status: ServerDocumentOcrJobStatus.completed,
      result: ServerDocumentOcrResult(
        projectAddress: 'Kết quả trả về sau khi mở lại app',
        engine: 'server_hybrid_tesseract_best_vietocr',
        elapsedMs: 8000,
      ),
    );

    final service = createService();
    await service.start(syncImmediately: false);
    await service.syncNow();

    expect(await service.list(), isEmpty);
    expect(
      (await logRepository.find(entry.id))!.projectAddress,
      'Kết quả trả về sau khi mở lại app',
    );
    expect(gateway.submitCount, 0);
    await service.dispose();
  });

  test('keeps a mismatched plate queued until manager approval', () async {
    final entry = _entry(id: 'plate-review-entry').copyWith(
      qualityIssues: const [pendingComputerOcrIssue],
      projectAddress: '',
    );
    await logRepository.save(entry);
    final service = createService();
    await service.enqueue(entry);
    await service.start(syncImmediately: false);
    await service.syncNow();

    gateway.job = const ServerDocumentOcrJob(
      id: 41,
      status: ServerDocumentOcrJobStatus.awaitingReview,
      reviewMessage: 'Biển số OCR không khớp xe cố định của tài xế',
    );
    await service.syncNow();

    var queued = await service.list();
    expect(queued, hasLength(1));
    expect(queued.single.status, DocumentOcrQueueStatus.waitingReview);
    expect(queued.single.lastError, contains('không khớp'));
    expect((await logRepository.find(entry.id))!.isComputerOcrPending, isTrue);
    expect(completedNotifications, isEmpty);

    gateway.job = const ServerDocumentOcrJob(
      id: 41,
      status: ServerDocumentOcrJobStatus.completed,
      result: ServerDocumentOcrResult(
        projectAddress: 'Công trình đã được quản lý xác nhận',
        vehiclePlate: '30A12345',
        engine: 'server_hybrid_tesseract_best_vietocr',
        elapsedMs: 7000,
      ),
    );
    await service.syncNow();

    queued = await service.list();
    expect(queued, isEmpty);
    expect(
      (await logRepository.find(entry.id))!.projectAddress,
      'Công trình đã được quản lý xác nhận',
    );
    expect(completedNotifications, ['Công trình đã được quản lý xác nhận']);
    await service.dispose();
  });

  test('recovers an OCR marker that is missing its queue row', () async {
    final entry = _entry(id: 'orphan-pending-entry').copyWith(
      qualityIssues: const [pendingComputerOcrIssue],
      status: DrivingLogStatus.draft,
    );
    await logRepository.save(entry);
    final service = createService();

    await service.start(syncImmediately: false);

    final queued = await service.list();
    expect(queued, hasLength(1));
    expect(queued.single.entryId, entry.id);
    expect(queued.single.status, DocumentOcrQueueStatus.pendingUpload);
    expect(gateway.submitCount, 0);
    await service.dispose();
  });

  test(
    'saving supplemental fields keeps OCR queued and merges the result later',
    () async {
      final entry = _entry(
        id: 'supplemental-entry',
      ).copyWith(projectAddress: '', fieldConfidences: const {});
      await logRepository.save(entry);
      final service = createService();
      await service.enqueue(entry);
      await service.start(syncImmediately: false);

      await service.syncNow();
      var queued = await service.list();
      expect(queued.single.status, DocumentOcrQueueStatus.waitingResult);

      final userEdited = entry.copyWith(
        assistantName: 'Nguyễn Văn Bình',
        mealCost: 120000,
        managerConfirmation: 'Đã xác nhận',
        status: DrivingLogStatus.draft,
      );
      await logRepository.save(userEdited);

      queued = await service.list();
      expect(queued, hasLength(1));
      expect(queued.single.status, DocumentOcrQueueStatus.waitingResult);

      gateway.job = const ServerDocumentOcrJob(
        id: 41,
        status: ServerDocumentOcrJobStatus.completed,
        result: ServerDocumentOcrResult(
          projectAddress: 'Công trình do OCR máy tính nhận dạng',
          engine: 'server_hybrid_tesseract_best_vietocr',
          elapsedMs: 7100,
        ),
      );
      await service.syncNow();

      expect(await service.list(), isEmpty);
      final completed = await logRepository.find(entry.id);
      expect(completed!.projectAddress, 'Công trình do OCR máy tính nhận dạng');
      expect(completed.assistantName, 'Nguyễn Văn Bình');
      expect(completed.mealCost, 120000);
      expect(completed.managerConfirmation, 'Đã xác nhận');
      expect(completed.status, DrivingLogStatus.verified);
      await service.dispose();
    },
  );

  test('continues merging a completed OCR result while form is open', () async {
    final entry = _entry(id: 'editing-entry').copyWith(
      qualityIssues: const [pendingComputerOcrIssue],
      projectAddress: '',
      fieldConfidences: const {},
    );
    await logRepository.save(entry);
    final service = createService();
    await service.enqueue(entry);
    await service.start(syncImmediately: false);
    await service.syncNow();
    expect(
      (await service.list()).single.status,
      DocumentOcrQueueStatus.waitingResult,
    );

    gateway.job = const ServerDocumentOcrJob(
      id: 41,
      status: ServerDocumentOcrJobStatus.completed,
      result: ServerDocumentOcrResult(
        projectAddress: 'Kết quả chỉ ghép sau khi đóng form',
        engine: 'server_hybrid_tesseract_best_vietocr',
        elapsedMs: 7200,
      ),
    );
    await service.syncNow();

    expect(await service.list(), isEmpty);
    expect(
      (await logRepository.find(entry.id))!.projectAddress,
      'Kết quả chỉ ghép sau khi đóng form',
    );
    await service.dispose();
  });

  test('deleting a pending entry cancels its server job', () async {
    final entry = _entry(
      id: 'cancelled-entry',
    ).copyWith(qualityIssues: const [pendingComputerOcrIssue]);
    await logRepository.save(entry);
    final service = createService();
    await service.enqueue(entry);
    await service.start(syncImmediately: false);
    await service.syncNow();
    expect((await service.list()).single.serverJobId, 41);

    await service.cancel(entry.id);
    await Future<void>.delayed(Duration.zero);

    expect(await service.list(), isEmpty);
    expect(gateway.deletedJobIds, [41]);
    expect(completedNotifications, isEmpty);
    await service.dispose();
  });
}

DrivingLogEntry _entry({String id = 'offline-entry'}) {
  final now = DateTime(2026, 8, 11, 9);
  return DrivingLogEntry(
    id: id,
    imagePath: '/private/scan.jpg',
    originalImagePath: '/private/original.jpg',
    qualityLevel: ScanQualityLevel.green,
    qualityScore: 90,
    qualityIssues: const [],
    ocrText: 'OCR local',
    fieldConfidences: const {'projectAddress': 0.5},
    voucherDate: DateTime(2026, 7, 5),
    driverName: 'Nguyễn Văn An',
    assistantName: '',
    vehiclePlate: '29C64684',
    projectAddress: 'Kết quả local sai',
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
