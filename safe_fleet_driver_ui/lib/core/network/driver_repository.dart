import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../features/navigation/engine/nav_route.dart';
import '../../models/driver_models.dart';
import '../storage/local_database.dart';
import '../storage/sync_queue.dart';
import 'api_client.dart';

class DriverRepository {
  DriverRepository(this.api, this.database, this.syncQueue);

  final ApiClient api;
  final LocalDatabase database;
  final SyncQueue syncQueue;
  final _uuid = const Uuid();

  Future<DriverBootstrap> bootstrap({bool allowCache = true}) async {
    try {
      final data = await api.get<Map<String, dynamic>>('/mobile/bootstrap');
      await database.cache('bootstrap', data);
      return DriverBootstrap.fromJson(data);
    } catch (_) {
      if (!allowCache) rethrow;
      final cached = await database.cached<Map<String, dynamic>>('bootstrap');
      if (cached == null) rethrow;
      return DriverBootstrap.fromJson(cached);
    }
  }

  Future<List<Map<String, dynamic>>> tripsToday() async {
    final data = await api.get<List<dynamic>>('/mobile/trips/today');
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<Map<String, dynamic>> profile() =>
      api.get<Map<String, dynamic>>('/mobile/me');

  Future<Map<String, dynamic>> monthlyActivity({
    DateTime? month,
  }) => api.get<Map<String, dynamic>>(
    '/mobile/activity/monthly',
    query: month == null
        ? null
        : {'month': '${month.year}-${month.month.toString().padLeft(2, '0')}'},
  );

  Future<Map<String, dynamic>> trip(int id) async {
    final trip = await api.get<Map<String, dynamic>>('/mobile/trips/$id');
    try {
      trip['warehouseIssue'] = await api.get<Map<String, dynamic>>(
        '/mobile/trips/$id/warehouse-issue',
      );
    } catch (_) {
      // Legacy trips created before normalized documents still use plannedRoute.
    }
    return trip;
  }

  Future<Map<String, dynamic>> submitChecklist(
    int tripId,
    Map<String, dynamic> data,
  ) => api.post<Map<String, dynamic>>(
    '/mobile/trips/$tripId/pre-trip-checklist',
    data: data,
  );

  Future<Map<String, dynamic>> workflow(
    int tripId,
    String action, {
    String? note,
  }) async {
    final clientEventId = _uuid.v4();
    try {
      return await api.post<Map<String, dynamic>>(
        '/mobile/trips/$tripId/$action-workflow',
        data: {'note': note, 'clientEventId': clientEventId},
      );
    } on ApiFailure catch (error) {
      if (error.statusCode != null) rethrow;
      await syncQueue.enqueueWorkflow(
        tripId: tripId,
        action: action,
        note: note,
        clientEventId: clientEventId,
      );
      return {
        'action': action.toUpperCase(),
        'status': 'QUEUED_OFFLINE',
        'queued': true,
        'clientEventId': clientEventId,
      };
    }
  }

  Future<Map<String, dynamic>> executeConfirmedTripAction({
    required int tripId,
    required String action,
    String? note,
  }) {
    final normalized = action.toLowerCase();
    if (normalized == 'accept' || normalized == 'reject') {
      return api.post<Map<String, dynamic>>(
        '/mobile/trips/$tripId/$normalized',
        data: {'note': note, 'clientEventId': _uuid.v4()},
      );
    }
    if (!const {'start', 'pause', 'resume', 'complete'}.contains(normalized)) {
      throw ArgumentError.value(action, 'action', 'Unsupported trip action');
    }
    return workflow(tripId, normalized, note: note);
  }

  Future<NavSession> navigationRoute({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    required String destinationName,
    int? tripId,
  }) async {
    final data = await api.post<Map<String, dynamic>>(
      '/mobile/navigation/routes',
      data: {
        'originLat': originLat,
        'originLng': originLng,
        'destinationLat': destinationLat,
        'destinationLng': destinationLng,
        'destinationName': destinationName,
        'tripId': tripId,
      },
    );
    await database.cache('navigation_current', data);
    return NavSession.fromJson(data);
  }

  Future<List<LocationPoint>> autocompleteLocation(String query) async {
    final data = await api.get<List<dynamic>>(
      '/mobile/locations/autocomplete',
      query: {'query': query, 'limit': 6},
    );
    return data
        .map(
          (item) =>
              LocationPoint.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  /// Names a point the driver dropped on the map.
  ///
  /// Falls back to the raw coordinates when the geocoder cannot be reached, so
  /// a pin dropped out of coverage is still a usable destination.
  Future<LocationPoint> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    try {
      final data = await api.get<Map<String, dynamic>>(
        '/mobile/locations/reverse',
        query: {'lat': lat, 'lng': lng},
      );
      return LocationPoint.fromJson(data);
    } catch (_) {
      return LocationPoint(
        name: 'Vị trí đã chọn trên bản đồ',
        address:
            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
        lat: lat,
        lng: lng,
        source: 'MAP_PIN',
      );
    }
  }

  Future<List<Map<String, dynamic>>> nearbyFloodPoints({
    required double lat,
    required double lng,
    double radiusKm = 20,
  }) async {
    final data = await api.get<List<dynamic>>(
      '/mobile/flood-points/nearby',
      query: {'lat': lat, 'lng': lng, 'radiusKm': radiusKm},
    );
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  /// Restores the session the driver was following, falling back to the copy
  /// cached on disk so guidance survives an app restart with no connectivity.
  Future<NavSession?> currentNavigation() async {
    try {
      final data = await api.get<Map<String, dynamic>>(
        '/mobile/navigation/current',
      );
      await database.cache('navigation_current', data);
      return NavSession.fromJson(data);
    } catch (_) {
      final cached = await database.cached<Map<String, dynamic>>(
        'navigation_current',
      );
      return cached == null ? null : NavSession.fromJson(cached);
    }
  }

  Future<NavSession> reroute({
    required String sessionId,
    required Position position,
    String reason = 'OFF_ROUTE_CONFIRMED',
  }) => rerouteAt(
    sessionId: sessionId,
    latitude: position.latitude,
    longitude: position.longitude,
    gpsAccuracyMeters: position.accuracy,
    reason: reason,
  );

  Future<NavSession> rerouteAt({
    required String sessionId,
    required double latitude,
    required double longitude,
    double? gpsAccuracyMeters,
    String reason = 'OFF_ROUTE_CONFIRMED',
  }) async {
    final data = await api.post<Map<String, dynamic>>(
      '/mobile/navigation/reroute',
      data: {
        'sessionId': sessionId,
        'currentLat': latitude,
        'currentLng': longitude,
        'gpsAccuracyMeters': gpsAccuracyMeters,
        'reason': reason,
      },
    );
    await database.cache('navigation_current', data);
    return NavSession.fromJson(data);
  }

  /// Closes a session so it stops being restored on the next launch and stops
  /// accumulating as an open row in the fleet database.
  Future<void> completeNavigation({
    required String sessionId,
    String reason = 'ARRIVED',
  }) async {
    await api.post<Map<String, dynamic>>(
      '/mobile/navigation/complete',
      data: {'sessionId': sessionId, 'reason': reason},
    );
    await database.remove('navigation_current');
  }

  Future<Map<String, dynamic>> navigationEvent({
    required String sessionId,
    required Position position,
    required double distanceToRouteMeters,
  }) => navigationEventAt(
    sessionId: sessionId,
    latitude: position.latitude,
    longitude: position.longitude,
    distanceToRouteMeters: distanceToRouteMeters,
    gpsAccuracyMeters: position.accuracy,
    occurredAt: position.timestamp,
  );

  Future<Map<String, dynamic>> navigationEventAt({
    required String sessionId,
    required double latitude,
    required double longitude,
    double? distanceToRouteMeters,
    double? gpsAccuracyMeters,
    DateTime? occurredAt,
  }) => api.post<Map<String, dynamic>>(
    '/mobile/navigation/events',
    data: {
      'sessionId': sessionId,
      'eventType': 'LOCATION_UPDATE',
      'lat': latitude,
      'lng': longitude,
      'distanceToRouteMeters': distanceToRouteMeters,
      'gpsAccuracyMeters': gpsAccuracyMeters,
      // Always offset-qualified: a device clock reads UTC, and sending a naive
      // local string is what used to store these seven hours adrift.
      'occurredAt': (occurredAt ?? DateTime.now()).toUtc().toIso8601String(),
    },
  );

  Future<String> queueTelemetry({
    required int vehicleId,
    required int driverId,
    int? tripId,
    required Position position,
    int? batteryLevel,
  }) => syncQueue.enqueueTelemetry({
    'clientEventId': _uuid.v4(),
    'vehicleId': vehicleId,
    'driverId': driverId,
    'tripId': tripId,
    'lat': position.latitude,
    'lng': position.longitude,
    'speed': position.speed < 0 ? 0 : position.speed * 3.6,
    'heading': position.heading,
    'batteryLevel': batteryLevel,
    'gpsAccuracyMeters': position.accuracy,
    'gpsStatus': position.accuracy <= 25 ? 'GOOD' : 'WEAK',
    'createdAt': position.timestamp.toIso8601String(),
  });

  Future<Map<String, dynamic>> reportFlood({
    required Position position,
    String hazardType = 'FLOOD',
    required String severity,
    String? address,
  }) async {
    final payload = <String, dynamic>{
      'lat': position.latitude,
      'lng': position.longitude,
      'hazardType': hazardType,
      'severity': severity,
      'address': address,
      'clientEventId': _uuid.v4(),
    };
    try {
      return await api.post<Map<String, dynamic>>(
        '/mobile/flood-reports/quick',
        data: payload,
      );
    } on ApiFailure catch (error) {
      if (error.statusCode != null) rethrow;
      await syncQueue.enqueueFlood(payload);
      return {
        'status': 'QUEUED_OFFLINE',
        'queued': true,
        'clientEventId': payload['clientEventId'],
      };
    }
  }

  Future<Map<String, dynamic>> reportFloodSegment({
    required Position position,
    required List<Map<String, double>> geometry,
    String severity = 'BLOCKED',
  }) => reportFloodSegmentAt(
    latitude: position.latitude,
    longitude: position.longitude,
    geometry: geometry,
    severity: severity,
  );

  /// Reports a flooded stretch of road rather than a single pin.
  ///
  /// A segment is what the router can actually exclude as a corridor, so this
  /// is the report shape that removes the street from everybody's route.
  Future<Map<String, dynamic>> reportFloodSegmentAt({
    required double latitude,
    required double longitude,
    required List<Map<String, double>> geometry,
    String severity = 'BLOCKED',
  }) async {
    if (geometry.length < 2) {
      throw ArgumentError.value(geometry, 'geometry', 'Cần ít nhất 2 điểm');
    }
    final payload = <String, dynamic>{
      'lat': latitude,
      'lng': longitude,
      'address': 'Đoạn đường ngập do tài xế báo trong lúc dẫn đường',
      'severity': severity,
      'source': 'DRIVER_REPORT',
      'clientEventId': _uuid.v4(),
      'geometryType': 'SEGMENT',
      'geometry': geometry,
      'radiusMeters': 80,
    };
    try {
      return await api.post<Map<String, dynamic>>(
        '/flood-reports/hazards',
        data: payload,
      );
    } on ApiFailure catch (error) {
      if (error.statusCode != null) rethrow;
      await syncQueue.enqueueFloodHazard(payload);
      return {
        'status': 'QUEUED_OFFLINE',
        'queued': true,
        'clientEventId': payload['clientEventId'],
      };
    }
  }

  Future<Map<String, dynamic>> sendSos({
    required Position position,
    String? description,
  }) async {
    final payload = <String, dynamic>{
      'lat': position.latitude,
      'lng': position.longitude,
      'severity': 'CRITICAL',
      'description': description ?? 'SOS từ ứng dụng tài xế',
      'clientEventId': _uuid.v4(),
    };
    try {
      return await api.post<Map<String, dynamic>>(
        '/mobile/incidents/sos',
        data: payload,
      );
    } catch (_) {
      await syncQueue.enqueueSos(payload);
      return {
        'incidentCode': 'ĐANG-CHỜ-ĐỒNG-BỘ',
        'status': 'QUEUED_OFFLINE',
        'queued': true,
      };
    }
  }

  Future<void> queueSafetyEvent({
    required String eventType,
    required String severity,
    required double confidence,
    required String note,
    Position? position,
  }) async {
    final payload = <String, dynamic>{
      'eventType': eventType,
      'severity': severity,
      'lat': position?.latitude,
      'lng': position?.longitude,
      'speed': position == null ? null : position.speed * 3.6,
      'confidence': confidence,
      'createdAt': DateTime.now().toIso8601String(),
      'note': note,
      'clientEventId': _uuid.v4(),
    };
    await syncQueue.enqueueSafety(payload, critical: severity == 'CRITICAL');
    await syncQueue.syncNow();
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final page = await api.get<Map<String, dynamic>>(
      '/mobile/notifications',
      query: {'page': 0, 'size': 100},
    );
    return DriverBootstrap.maps(page['items']);
  }

  Future<void> markNotificationRead(int id) =>
      api.patch<Object?>('/mobile/notifications/$id/read');

  Future<Map<String, dynamic>> agentCommand(String transcript, {int? tripId}) =>
      api.post<Map<String, dynamic>>(
        '/mobile/agent/command',
        data: {
          'commandType': 'VOICE',
          'transcript': transcript,
          'tripId': tripId,
        },
      );

  Future<Map<String, dynamic>> agentChat(List<Map<String, String>> messages) {
    final start = messages.length > 20 ? messages.length - 20 : 0;
    return api.post<Map<String, dynamic>>(
      '/mobile/agent/chat',
      data: {'messages': messages.sublist(start)},
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 30),
    );
  }

  Future<Map<String, dynamic>> confirmAgentCommand(
    int commandId, {
    double? latitude,
    double? longitude,
    String? floodSeverity,
    String? addressText,
    String? description,
  }) => api.post<Map<String, dynamic>>(
    '/mobile/agent/commands/$commandId/confirm',
    data: {
      'lat': latitude,
      'lng': longitude,
      'floodSeverity': floodSeverity,
      'address': addressText,
      'description': description,
    },
  );

  Future<Map<String, dynamic>> cancelAgentCommand(int commandId) => api
      .post<Map<String, dynamic>>('/mobile/agent/commands/$commandId/cancel');
}
