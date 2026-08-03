import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../design/tokens.dart';
import '../network/driver_repository.dart';
import '../storage/sync_queue.dart';

/// Publishes the signed-in driver's real phone GPS as the assigned vehicle's
/// realtime position. Android keeps the stream in a foreground service so it
/// can continue while the driver uses another application.
class VehicleLocationTracker {
  VehicleLocationTracker(this._repository, this._syncQueue);

  final DriverRepository _repository;
  final SyncQueue _syncQueue;

  StreamSubscription<Position>? _subscription;
  int? _driverId;
  int? _vehicleId;
  int? _tripId;
  String _vehiclePlate = '001';
  DateTime? _lastPublishedAt;
  bool _publishing = false;

  Future<bool> start() async {
    if (_subscription != null) return true;

    final bootstrap = await _repository.bootstrap(allowCache: false);
    final driver = bootstrap.driver;
    _driverId = (driver?['id'] as num?)?.toInt();
    _vehicleId = (driver?['currentVehicleId'] as num?)?.toInt();
    _vehiclePlate =
        driver?['currentVehiclePlateNumber']?.toString().trim().isNotEmpty ==
            true
        ? driver!['currentVehiclePlateNumber'].toString()
        : '001';
    _tripId = (bootstrap.currentTrip?['id'] as num?)?.toInt();

    if (_driverId == null || _vehicleId == null) return false;
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    try {
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      await _publish(initial, force: true);
    } catch (_) {
      // The position stream below can still recover when GPS gets a fix.
    }

    _subscription = Geolocator.getPositionStream(
      locationSettings: _locationSettings(),
    ).listen((position) => unawaited(_publish(position)), onError: (_) {});
    return true;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  LocationSettings _locationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'SafeFleet đang chia sẻ vị trí',
          notificationText: 'Xe $_vehiclePlate • GPS thật từ điện thoại tài xế',
          notificationChannelName: 'Theo dõi vị trí xe',
          enableWakeLock: true,
          setOngoing: true,
          color: SfColors.teal,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
  }

  Future<void> _publish(Position position, {bool force = false}) async {
    if (_publishing || _driverId == null || _vehicleId == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastPublishedAt != null &&
        now.difference(_lastPublishedAt!) < const Duration(seconds: 8)) {
      return;
    }

    _publishing = true;
    try {
      await _repository.queueTelemetry(
        vehicleId: _vehicleId!,
        driverId: _driverId!,
        tripId: _tripId,
        position: position,
      );
      await _syncQueue.syncNow();
      _lastPublishedAt = now;
    } finally {
      _publishing = false;
    }
  }
}
