import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:safe_fleet_driver_ui/core/network/api_client.dart';
import 'package:safe_fleet_driver_ui/core/storage/local_database.dart';
import 'package:safe_fleet_driver_ui/core/storage/sync_queue.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _ApiCall {
  const _ApiCall(this.path, this.data);

  final String path;
  final Object? data;
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.acceptedTelemetryIds, this.failingPaths = const {}});

  final Set<String>? acceptedTelemetryIds;
  final Set<String> failingPaths;
  final calls = <_ApiCall>[];

  @override
  Future<T> post<T>(String path, {Object? data}) async {
    calls.add(_ApiCall(path, data));
    if (failingPaths.contains(path)) {
      throw const ApiFailure('offline');
    }
    if (path == '/mobile/telemetry/batch') {
      final body = Map<String, dynamic>.from(data! as Map);
      final items = List<Map<String, dynamic>>.from(
        (body['items']! as List).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      return <String, dynamic>{
            'items': items
                .where(
                  (item) =>
                      acceptedTelemetryIds == null ||
                      acceptedTelemetryIds!.contains(item['clientEventId']),
                )
                .map(
                  (item) => {
                    'clientEventId': item['clientEventId'],
                    'status': 'ACCEPTED',
                  },
                )
                .toList(),
          }
          as T;
    }
    return <String, dynamic>{'id': calls.length} as T;
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late LocalDatabase database;
  late String databaseName;

  setUp(() {
    databaseName = 'safefleet-sync-${DateTime.now().microsecondsSinceEpoch}.db';
    database = LocalDatabase(databaseName: databaseName);
  });

  tearDown(() async {
    await database.close();
    await databaseFactory.deleteDatabase(
      join(await getDatabasesPath(), databaseName),
    );
  });

  test(
    'sync respects priority and ACKs every supported offline type',
    () async {
      final api = _FakeApiClient();
      final queue = SyncQueue(database, api);
      await queue.enqueueTelemetry({
        'clientEventId': 'telemetry-1',
        'lat': 21.0,
        'lng': 105.8,
      });
      await queue.enqueueFlood({
        'clientEventId': 'flood-1',
        'lat': 21.01,
        'lng': 105.81,
        'severity': 'HIGH',
      });
      await queue.enqueueWorkflow(
        tripId: 7,
        action: 'pause',
        clientEventId: 'workflow-1',
      );
      await queue.enqueueSafety({
        'clientEventId': 'safety-1',
        'eventType': 'PHONE_USAGE',
        'severity': 'HIGH',
      }, critical: false);
      await queue.enqueueSos({
        'clientEventId': 'sos-1',
        'lat': 21.02,
        'lng': 105.82,
      });

      expect(await queue.syncNow(), 5);
      expect(api.calls.map((call) => call.path), [
        '/mobile/incidents/sos',
        '/mobile/safety-events',
        '/mobile/trips/7/pause-workflow',
        '/mobile/flood-reports/quick',
        '/mobile/telemetry/batch',
      ]);
      final workflowBody = Map<String, dynamic>.from(api.calls[2].data! as Map);
      expect(workflowBody['clientEventId'], 'workflow-1');
      expect(await database.pendingCount(), 0);
    },
  );

  test('telemetry remains queued until its own server ACK arrives', () async {
    final api = _FakeApiClient(acceptedTelemetryIds: {'telemetry-accepted'});
    final queue = SyncQueue(database, api);
    await queue.enqueueTelemetry({
      'clientEventId': 'telemetry-accepted',
      'lat': 21.0,
      'lng': 105.8,
    });
    await queue.enqueueTelemetry({
      'clientEventId': 'telemetry-waiting',
      'lat': 21.1,
      'lng': 105.9,
    });

    expect(await queue.syncNow(), 1);
    final pending = await database.pending();
    expect(pending, hasLength(1));
    expect(pending.single['event_id'], 'telemetry-waiting');
  });

  test('failed urgent command is retained and marked for retry', () async {
    final api = _FakeApiClient(failingPaths: const {'/mobile/incidents/sos'});
    final queue = SyncQueue(database, api);
    await queue.enqueueSos({
      'clientEventId': 'sos-retry',
      'lat': 21.02,
      'lng': 105.82,
    });

    expect(await queue.syncNow(), 0);
    final pending = await database.pending();
    expect(pending, hasLength(1));
    expect(pending.single['status'], 'FAILED');
    expect(pending.single['attempts'], 1);
  });
}
