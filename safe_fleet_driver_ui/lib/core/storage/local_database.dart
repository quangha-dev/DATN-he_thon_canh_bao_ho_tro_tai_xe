import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase({this.databaseName = 'safefleet_driver.db'});

  final String databaseName;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await openDatabase(
      join(await getDatabasesPath(), databaseName),
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
      },
    );
    return _database!;
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
    await _database?.close();
    _database = null;
  }
}
