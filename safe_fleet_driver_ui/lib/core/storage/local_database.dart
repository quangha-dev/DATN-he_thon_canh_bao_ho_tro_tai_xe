import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase({this.databaseName = 'safefleet_driver.db'});

  final String databaseName;
  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database async {
    final current = _database;
    if (current != null && current.isOpen) return current;
    _database = null;

    final pending = _opening;
    if (pending != null) return pending;
    final opening = _open();
    _opening = opening;
    try {
      final opened = await opening;
      _database = opened;
      return opened;
    } finally {
      _opening = null;
    }
  }

  Future<Database> _open() async => openDatabase(
    join(await getDatabasesPath(), databaseName),
    // WorkManager uses a second Flutter isolate. It must own a separate
    // connection; otherwise disposing its ProviderContainer can close the
    // UI isolate's cached sqflite handle for the same path.
    singleInstance: false,
    version: 4,
    onCreate: (db, _) async {
      await _createBaseTables(db);
      await _createDrivingLogTables(db);
      await _createDocumentOcrQueueTables(db);
      await _ensureDrivingLogConfirmationColumns(db);
    },
    onUpgrade: (db, oldVersion, _) async {
      if (oldVersion < 2) await _createDrivingLogTables(db);
      if (oldVersion < 3) await _createDocumentOcrQueueTables(db);
      if (oldVersion < 4) await _ensureDrivingLogConfirmationColumns(db);
    },
  );

  Future<void> _createBaseTables(Database db) async {
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
  }

  Future<void> _createDrivingLogTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS driving_log_entries (
        id TEXT PRIMARY KEY,
        image_path TEXT NOT NULL,
        original_image_path TEXT NOT NULL,
        quality_level TEXT NOT NULL,
        quality_score INTEGER NOT NULL,
        quality_issues TEXT NOT NULL,
        ocr_text TEXT NOT NULL,
        field_confidences TEXT NOT NULL,
        voucher_date TEXT,
        driver_name TEXT NOT NULL DEFAULT '',
        assistant_name TEXT NOT NULL DEFAULT '',
        vehicle_plate TEXT NOT NULL DEFAULT '',
        project_address TEXT NOT NULL DEFAULT '',
        trip_count INTEGER,
        meal_cost INTEGER,
        rule_cost INTEGER,
        tyre_cost INTEGER,
        other_cost INTEGER,
        manager_confirmation TEXT NOT NULL DEFAULT '',
        voucher_number TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'DRAFT',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        confirmation_id TEXT,
        confirmed_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_driving_log_voucher_date
      ON driving_log_entries(voucher_date DESC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_driving_log_status
      ON driving_log_entries(status)
    ''');
  }

  Future<void> _ensureDrivingLogConfirmationColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(driving_log_entries)');
    final names = columns.map((row) => row['name']?.toString()).toSet();
    if (!names.contains('confirmation_id')) {
      await db.execute(
        'ALTER TABLE driving_log_entries ADD COLUMN confirmation_id TEXT',
      );
    }
    if (!names.contains('confirmed_at')) {
      await db.execute(
        'ALTER TABLE driving_log_entries ADD COLUMN confirmed_at TEXT',
      );
    }
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_driving_log_confirmation_id
      ON driving_log_entries(confirmation_id)
      WHERE confirmation_id IS NOT NULL
    ''');
  }

  Future<void> _createDocumentOcrQueueTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_ocr_queue (
        entry_id TEXT PRIMARY KEY,
        image_path TEXT NOT NULL,
        server_job_id INTEGER,
        status TEXT NOT NULL DEFAULT 'PENDING_UPLOAD',
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_document_ocr_queue_status
      ON document_ocr_queue(status, created_at)
    ''');
  }

  Future<void> enqueue({
    required String eventId,
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    await db.insert('offline_queue', {
      'event_id': eventId,
      'type': type,
      'payload': jsonEncode(payload),
      'status': 'PENDING',
      'attempts': 0,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, dynamic>>> pending({int limit = 200}) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT *
      FROM offline_queue
      WHERE status IN ('PENDING','FAILED')
      ORDER BY CASE type
        WHEN 'SOS' THEN 0
        WHEN 'SAFETY_CRITICAL' THEN 1
        WHEN 'SAFETY_HIGH' THEN 2
        WHEN 'TRIP_WORKFLOW' THEN 3
        WHEN 'FLOOD_REPORT' THEN 4
        WHEN 'FLOOD_HAZARD' THEN 4
        WHEN 'TELEMETRY' THEN 5
        ELSE 6
      END, id
      LIMIT ?
      ''',
      [limit],
    );
  }

  Future<int> pendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM offline_queue WHERE status IN ('PENDING','FAILED')",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markSynced(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        'offline_queue',
        {'status': 'SYNCED', 'last_error': null},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> markFailed(Iterable<int> ids, Object error) async {
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.rawUpdate(
        'UPDATE offline_queue SET status = ?, attempts = attempts + 1, last_error = ? WHERE id = ?',
        ['FAILED', error.toString(), id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> cache(String key, Object value) async {
    final db = await database;
    await db.insert('cached_documents', {
      'cache_key': key,
      'payload': jsonEncode(value),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> remove(String key) async {
    final db = await database;
    await db.delete(
      'cached_documents',
      where: 'cache_key = ?',
      whereArgs: [key],
    );
  }

  Future<T?> cached<T>(String key) async {
    final db = await database;
    final rows = await db.query(
      'cached_documents',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['payload']! as String) as T;
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) {
      try {
        await opening;
      } catch (_) {
        // Opening already failed; there is no connection left to close.
      }
    }
    final current = _database;
    _database = null;
    if (current != null && current.isOpen) await current.close();
  }
}
