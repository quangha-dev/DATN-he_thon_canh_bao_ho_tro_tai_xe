import 'package:sqflite/sqflite.dart';

import '../../core/storage/local_database.dart';
import 'driving_log_entry.dart';

class DrivingLogRepository {
  const DrivingLogRepository(this._localDatabase);

  final LocalDatabase _localDatabase;

  Future<void> save(DrivingLogEntry entry) async {
    final db = await _localDatabase.database;
    final updated = await db.update(
      'driving_log_entries',
      entry.toDatabase(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    if (updated == 0) {
      await db.insert(
        'driving_log_entries',
        entry.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  Future<DrivingLogEntry?> find(String id) async {
    final db = await _localDatabase.database;
    final rows = await db.query(
      'driving_log_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : DrivingLogEntry.fromDatabase(rows.first);
  }

  Future<List<DrivingLogEntry>> list({DateTime? month}) async {
    final db = await _localDatabase.database;
    late final List<Map<String, Object?>> rows;
    if (month == null) {
      rows = await db.query(
        'driving_log_entries',
        orderBy: 'COALESCE(voucher_date, created_at) DESC, created_at DESC',
      );
    } else {
      final start = DateTime(month.year, month.month);
      final end = DateTime(month.year, month.month + 1);
      rows = await db.query(
        'driving_log_entries',
        where:
            'COALESCE(voucher_date, created_at) >= ? AND '
            'COALESCE(voucher_date, created_at) < ?',
        whereArgs: [start.toIso8601String(), end.toIso8601String()],
        orderBy: 'COALESCE(voucher_date, created_at) DESC, created_at DESC',
      );
    }
    return rows.map(DrivingLogEntry.fromDatabase).toList();
  }

  Future<void> markExported(Iterable<String> ids) async {
    final values = ids.toList();
    if (values.isEmpty) return;
    final db = await _localDatabase.database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final id in values) {
      batch.update(
        'driving_log_entries',
        {'status': 'EXPORTED', 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> delete(String id) async {
    final db = await _localDatabase.database;
    await db.delete('driving_log_entries', where: 'id = ?', whereArgs: [id]);
  }
}
