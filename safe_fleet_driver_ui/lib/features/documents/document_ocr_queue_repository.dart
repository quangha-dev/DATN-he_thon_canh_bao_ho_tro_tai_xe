import 'package:sqflite/sqflite.dart';

import '../../core/storage/local_database.dart';

enum DocumentOcrQueueStatus {
  pendingUpload,
  uploading,
  waitingResult,
  waitingReview,
  failed,
}

extension DocumentOcrQueueStatusValue on DocumentOcrQueueStatus {
  String get databaseValue => switch (this) {
    DocumentOcrQueueStatus.pendingUpload => 'PENDING_UPLOAD',
    DocumentOcrQueueStatus.uploading => 'UPLOADING',
    DocumentOcrQueueStatus.waitingResult => 'WAITING_RESULT',
    DocumentOcrQueueStatus.waitingReview => 'WAITING_REVIEW',
    DocumentOcrQueueStatus.failed => 'FAILED',
  };

  static DocumentOcrQueueStatus parse(Object? value) =>
      switch (value?.toString().toUpperCase()) {
        'UPLOADING' => DocumentOcrQueueStatus.uploading,
        'WAITING_RESULT' => DocumentOcrQueueStatus.waitingResult,
        'WAITING_REVIEW' => DocumentOcrQueueStatus.waitingReview,
        'FAILED' => DocumentOcrQueueStatus.failed,
        _ => DocumentOcrQueueStatus.pendingUpload,
      };
}

class DocumentOcrQueueItem {
  const DocumentOcrQueueItem({
    required this.entryId,
    required this.imagePath,
    required this.serverJobId,
    required this.status,
    required this.attempts,
    required this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  final String entryId;
  final String imagePath;
  final int? serverJobId;
  final DocumentOcrQueueStatus status;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory DocumentOcrQueueItem.fromDatabase(Map<String, Object?> row) =>
      DocumentOcrQueueItem(
        entryId: row['entry_id']!.toString(),
        imagePath: row['image_path']!.toString(),
        serverJobId: (row['server_job_id'] as num?)?.round(),
        status: DocumentOcrQueueStatusValue.parse(row['status']),
        attempts: (row['attempts'] as num?)?.round() ?? 0,
        lastError: row['last_error']?.toString(),
        createdAt:
            DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt:
            DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class DocumentOcrQueueRepository {
  const DocumentOcrQueueRepository(this._database);

  final LocalDatabase _database;

  Future<void> enqueue({
    required String entryId,
    required String imagePath,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('document_ocr_queue', {
      'entry_id': entryId,
      'image_path': imagePath,
      'server_job_id': null,
      'status': DocumentOcrQueueStatus.pendingUpload.databaseValue,
      'attempts': 0,
      'last_error': null,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<DocumentOcrQueueItem>> list() async {
    final db = await _database.database;
    final rows = await db.query(
      'document_ocr_queue',
      orderBy: 'created_at ASC',
    );
    return rows.map(DocumentOcrQueueItem.fromDatabase).toList();
  }

  Future<List<DocumentOcrQueueItem>> pendingUploads() async {
    final db = await _database.database;
    final rows = await db.query(
      'document_ocr_queue',
      where: 'status = ?',
      whereArgs: [DocumentOcrQueueStatus.pendingUpload.databaseValue],
      orderBy: 'created_at ASC',
    );
    return rows.map(DocumentOcrQueueItem.fromDatabase).toList();
  }

  Future<List<DocumentOcrQueueItem>> waitingResults() async {
    final db = await _database.database;
    final rows = await db.query(
      'document_ocr_queue',
      where: 'status IN (?, ?)',
      whereArgs: [
        DocumentOcrQueueStatus.waitingResult.databaseValue,
        DocumentOcrQueueStatus.waitingReview.databaseValue,
      ],
      orderBy: 'created_at ASC',
    );
    return rows.map(DocumentOcrQueueItem.fromDatabase).toList();
  }

  Future<void> recoverInterruptedUploads() async {
    final db = await _database.database;
    await db.update(
      'document_ocr_queue',
      {
        'status': DocumentOcrQueueStatus.pendingUpload.databaseValue,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'status = ?',
      whereArgs: [DocumentOcrQueueStatus.uploading.databaseValue],
    );
  }

  Future<void> markUploading(String entryId) => _update(
    entryId,
    status: DocumentOcrQueueStatus.uploading,
    clearError: true,
  );

  Future<void> markWaitingResult(String entryId, int serverJobId) => _update(
    entryId,
    status: DocumentOcrQueueStatus.waitingResult,
    serverJobId: serverJobId,
    clearError: true,
  );

  Future<void> markWaitingReview(
    String entryId,
    int serverJobId,
    String? reason,
  ) => _update(
    entryId,
    status: DocumentOcrQueueStatus.waitingReview,
    serverJobId: serverJobId,
    error: reason ?? 'Biển số cần được quản lý xác nhận',
  );

  Future<void> markUploadForRetry(String entryId, Object error) => _update(
    entryId,
    status: DocumentOcrQueueStatus.pendingUpload,
    error: error.toString(),
    incrementAttempts: true,
  );

  Future<void> markResultCheckFailed(
    String entryId,
    Object error, {
    bool waitingForReview = false,
  }) => _update(
    entryId,
    status: waitingForReview
        ? DocumentOcrQueueStatus.waitingReview
        : DocumentOcrQueueStatus.waitingResult,
    error: error.toString(),
    incrementAttempts: true,
  );

  Future<void> markFailed(String entryId, Object error) => _update(
    entryId,
    status: DocumentOcrQueueStatus.failed,
    error: error.toString(),
    incrementAttempts: true,
  );

  Future<void> retry(String entryId) => _update(
    entryId,
    status: DocumentOcrQueueStatus.pendingUpload,
    clearJobId: true,
    clearError: true,
  );

  Future<void> remove(String entryId) async {
    final db = await _database.database;
    await db.delete(
      'document_ocr_queue',
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
  }

  Future<void> _update(
    String entryId, {
    required DocumentOcrQueueStatus status,
    int? serverJobId,
    bool clearJobId = false,
    String? error,
    bool clearError = false,
    bool incrementAttempts = false,
  }) async {
    final db = await _database.database;
    final values = <String, Object?>{
      'status': status.databaseValue,
      'updated_at': DateTime.now().toIso8601String(),
      if (serverJobId != null || clearJobId) 'server_job_id': serverJobId,
      if (error != null || clearError) 'last_error': error,
    };
    if (incrementAttempts) {
      await db.rawUpdate(
        '''
        UPDATE document_ocr_queue
        SET status = ?, server_job_id = COALESCE(?, server_job_id),
            attempts = attempts + 1, last_error = ?, updated_at = ?
        WHERE entry_id = ?
        ''',
        [
          status.databaseValue,
          serverJobId,
          error,
          values['updated_at'],
          entryId,
        ],
      );
      return;
    }
    await db.update(
      'document_ocr_queue',
      values,
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
  }
}
