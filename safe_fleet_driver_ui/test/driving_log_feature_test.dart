import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:safe_fleet_driver_ui/core/storage/local_database.dart';
import 'package:safe_fleet_driver_ui/features/documents/driving_log_entry.dart';
import 'package:safe_fleet_driver_ui/features/documents/driving_log_export_service.dart';
import 'package:safe_fleet_driver_ui/features/documents/driving_log_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late LocalDatabase database;
  late DrivingLogRepository repository;
  late String databaseName;

  setUp(() {
    databaseName =
        'safefleet-driving-log-${DateTime.now().microsecondsSinceEpoch}.db';
    database = LocalDatabase(databaseName: databaseName);
    repository = DrivingLogRepository(database);
  });

  tearDown(() async {
    await database.close();
    await databaseFactory.deleteDatabase(
      join(await getDatabasesPath(), databaseName),
    );
  });

  test('saves and reloads an offline driving-log entry', () async {
    final entry = _entry();
    await repository.save(entry);

    final loaded = await repository.find(entry.id);
    expect(loaded, isNotNull);
    expect(loaded!.voucherNumber, '77029');
    expect(loaded.vehiclePlate, '29C64684');
    expect(loaded.projectAddress, contains('Hưng Yên'));
    expect(loaded.totalCost, 350000);
    expect(loaded.qualityIssues, ['Ảnh hơi nhòe']);
    expect(loaded.fieldConfidences['vehiclePlate'], 0.92);
  });

  test('upgrades the existing version-1 database without data loss', () async {
    final path = join(await getDatabasesPath(), databaseName);
    final oldDatabase = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE offline_queue (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              event_id TEXT NOT NULL UNIQUE,
              type TEXT NOT NULL,
              payload TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'PENDING',
              attempts INTEGER NOT NULL DEFAULT 0,
              last_error TEXT,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE cached_documents (
              cache_key TEXT PRIMARY KEY,
              payload TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.insert('cached_documents', {
            'cache_key': 'bootstrap',
            'payload': '{"offline":true}',
            'updated_at': DateTime(2026, 7, 1).toIso8601String(),
          });
        },
      ),
    );
    await oldDatabase.close();

    expect(await repository.list(), isEmpty);
    expect(await database.cached<Map<String, dynamic>>('bootstrap'), {
      'offline': true,
    });
    final upgraded = await database.database;
    final version = await upgraded.rawQuery('PRAGMA user_version');
    expect(version.single.values.single, 4);
  });

  test('month filter and exported status are persisted', () async {
    final entry = _entry();
    await repository.save(entry);
    await repository.save(
      _entry(id: 'scan-2', date: DateTime(2026, 8, 1), voucherNumber: '88001'),
    );
    await repository.save(
      _entry(
        id: 'scan-draft',
        voucherNumber: '',
      ).copyWith(clearVoucherDate: true),
    );

    final july = await repository.list(month: DateTime(2026, 7));
    expect(july, hasLength(2));
    expect(july.map((entry) => entry.id), contains('scan-draft'));
    expect(july.map((entry) => entry.voucherNumber), contains('77029'));

    await repository.confirmOnce(entry, confirmationId: 'confirmation-export');
    await repository.markExported([entry.id]);
    expect(
      (await repository.find(entry.id))!.status,
      DrivingLogStatus.exported,
    );
  });

  test(
    'final confirmation is persisted exactly once and locks first values',
    () async {
      final entry = _entry();
      await repository.save(entry);

      final first = await repository.confirmOnce(
        entry,
        confirmationId: 'confirmation-first',
      );
      final replay = await repository.confirmOnce(
        entry.copyWith(projectAddress: 'Giá trị không được ghi đè'),
        confirmationId: 'confirmation-second',
      );

      expect(first.isConfirmed, isTrue);
      expect(replay.confirmationId, 'confirmation-first');
      expect(replay.projectAddress, entry.projectAddress);
      expect(
        (await repository.find(entry.id))!.confirmationId,
        'confirmation-first',
      );
    },
  );

  test('generated xlsx contains the expected journal headers and values', () {
    final bytes = DrivingLogExportService().buildWorkbookBytes(
      month: DateTime(2026, 7),
      entries: [_entry()],
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((file) => file.name).toSet();
    expect(names, contains('xl/worksheets/sheet1.xml'));
    expect(names, contains('xl/styles.xml'));

    final sheet = archive.files.firstWhere(
      (file) => file.name == 'xl/worksheets/sheet1.xml',
    );
    final xml = utf8.decode(sheet.readBytes()!);
    expect(xml, contains('NHẬT TRÌNH LÁI XE THÁNG 7 NĂM 2026'));
    expect(xml, contains('Công trình Bắc Hưng Yên'));
    expect(xml, contains('<v>350000</v>'));
  });
}

DrivingLogEntry _entry({
  String id = 'scan-1',
  DateTime? date,
  String voucherNumber = '77029',
}) {
  final now = DateTime(2026, 7, 5, 10);
  return DrivingLogEntry(
    id: id,
    imagePath: '/private/scan.jpg',
    originalImagePath: '/private/original.jpg',
    qualityLevel: ScanQualityLevel.yellow,
    qualityScore: 74,
    qualityIssues: const ['Ảnh hơi nhòe'],
    ocrText: 'PHIẾU XUẤT KHO',
    fieldConfidences: const {'vehiclePlate': 0.92},
    voucherDate: date ?? DateTime(2026, 7, 5),
    driverName: 'Nguyễn Văn Tú',
    assistantName: '',
    vehiclePlate: '29C64684',
    projectAddress: 'Công trình Bắc Hưng Yên',
    tripCount: 1,
    mealCost: 50000,
    ruleCost: 300000,
    tyreCost: null,
    otherCost: null,
    managerConfirmation: '',
    voucherNumber: voucherNumber,
    status: DrivingLogStatus.verified,
    createdAt: now,
    updatedAt: now,
  );
}
