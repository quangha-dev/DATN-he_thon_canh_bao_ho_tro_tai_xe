import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../network/api_client.dart';
import 'local_database.dart';

class SyncQueue {
  SyncQueue(this.database, this.api);

  final LocalDatabase database;
  final ApiClient api;
  final _uuid = const Uuid();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _syncing = false;

  Future<String> enqueueTelemetry(Map<String, dynamic> telemetry) async {
    final eventId = telemetry['clientEventId']?.toString() ?? _uuid.v4();
    await database.enqueue(
      eventId: eventId,
      type: 'TELEMETRY',
      payload: {...telemetry, 'clientEventId': eventId},
    );
    return eventId;
  }

  Future<String> enqueueSafety(
    Map<String, dynamic> payload, {
    required bool critical,
  }) async {
    final eventId = payload['clientEventId']?.toString() ?? _uuid.v4();
    await database.enqueue(
      eventId: eventId,
      type: critical ? 'SAFETY_CRITICAL' : 'SAFETY_HIGH',
      payload: {...payload, 'clientEventId': eventId},
    );
    return eventId;
  }

  Future<String> enqueueSos(Map<String, dynamic> payload) async {
    final eventId = payload['clientEventId']?.toString() ?? _uuid.v4();
    await database.enqueue(
      eventId: eventId,
      type: 'SOS',
      payload: {...payload, 'clientEventId': eventId},
    );
    return eventId;
  }

  Future<String> enqueueWorkflow({
    required int tripId,
    required String action,
    String? note,
    String? clientEventId,
  }) async {
    final eventId = clientEventId ?? _uuid.v4();
    await database.enqueue(
      eventId: eventId,
      type: 'TRIP_WORKFLOW',
      payload: {
        'path': '/mobile/trips/$tripId/$action-workflow',
        'body': {'note': note, 'clientEventId': eventId},
      },
    );
    return eventId;
  }

  Future<String> enqueueFlood(Map<String, dynamic> payload) async {
    final eventId = payload['clientEventId']?.toString() ?? _uuid.v4();
    await database.enqueue(
      eventId: eventId,
      type: 'FLOOD_REPORT',
      payload: {...payload, 'clientEventId': eventId},
    );
    return eventId;
  }

  void start() {
    _subscription ??= Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        syncNow();
      }
    });
  }

  Future<int> syncNow() async {
    if (_syncing) return 0;
    _syncing = true;
    var syncedCount = 0;
    try {
      final queued = await database.pending();
      final commands = queued
          .where((item) => item['type'] != 'TELEMETRY')
          .toList();
      for (final item in commands) {
        final payload = Map<String, dynamic>.from(
          jsonDecode(item['payload']! as String) as Map,
        );
        try {
          final type = item['type']!.toString();
          final path = switch (type) {
            'SOS' => '/mobile/incidents/sos',
            'SAFETY_CRITICAL' || 'SAFETY_HIGH' => '/mobile/safety-events',
            'FLOOD_REPORT' => '/mobile/flood-reports/quick',
            'TRIP_WORKFLOW' => payload['path']!.toString(),
            _ => throw StateError('Loại đồng bộ không được hỗ trợ: $type'),
          };
          final body = type == 'TRIP_WORKFLOW'
              ? Map<String, dynamic>.from(payload['body']! as Map)
              : payload;
          await api.post<Map<String, dynamic>>(path, data: body);
          await database.markSynced([item['id']! as int]);
          syncedCount += 1;
        } catch (error) {
          await database.markFailed([item['id']! as int], error);
        }
      }

      final telemetry = queued
          .where((item) => item['type'] == 'TELEMETRY')
          .toList();
      if (telemetry.isEmpty) return syncedCount;
      final batchId = 'mobile-${_uuid.v4()}';
      final items = telemetry
          .map(
            (item) => Map<String, dynamic>.from(
              jsonDecode(item['payload']! as String) as Map,
            ),
          )
          .toList();
      try {
        final result = await api.post<Map<String, dynamic>>(
          '/mobile/telemetry/batch',
          data: {'batchId': batchId, 'items': items},
        );
        final acknowledgements = List<Map<String, dynamic>>.from(
          (result['items'] as List).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        final syncedEventIds = acknowledgements
            .where(
              (item) =>
                  item['status'] == 'ACCEPTED' || item['status'] == 'DUPLICATE',
            )
            .map((item) => item['clientEventId'])
            .toSet();
        final syncedIds = telemetry
            .where((item) => syncedEventIds.contains(item['event_id']))
            .map((item) => item['id']! as int)
            .toList();
        await database.markSynced(syncedIds);
        return syncedCount + syncedIds.length;
      } catch (error) {
        await database.markFailed(
          telemetry.map((item) => item['id']! as int),
          error,
        );
        return syncedCount;
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
