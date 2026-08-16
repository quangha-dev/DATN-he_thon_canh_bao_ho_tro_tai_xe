import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../network/driver_repository.dart';
import '../storage/local_database.dart';

class TripAssignmentNotificationMonitor {
  TripAssignmentNotificationMonitor(this._repository, this._database);

  static const _channel = MethodChannel(
    'vn.safefleet.safe_fleet_driver_ui/trip_notifications',
  );
  static const _lastShownCacheKey = 'last_trip_assignment_notification_id';

  final DriverRepository _repository;
  final LocalDatabase _database;
  Timer? _timer;
  bool _syncing = false;

  Future<void> start() async {
    if (_timer != null) return;
    if (Platform.isAndroid) await Permission.notification.request();
    await syncNow();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(syncNow()),
    );
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> syncNow() async {
    if (_syncing || !Platform.isAndroid) return;
    _syncing = true;
    try {
      final permission = await Permission.notification.status;
      if (!permission.isGranted) return;

      final lastShown = await _database.cached<num>(_lastShownCacheKey) ?? 0;
      final notifications = await _repository.notifications();
      final assignments =
          notifications
              .where(
                (item) =>
                    item['type']?.toString() == 'TRIP_ASSIGNED' &&
                    item['read'] != true &&
                    (item['id'] as num?) != null &&
                    (item['id'] as num).toInt() > lastShown.toInt(),
              )
              .toList()
            ..sort(
              (left, right) =>
                  (left['id'] as num).compareTo(right['id'] as num),
            );

      var newestShown = lastShown.toInt();
      for (final item in assignments.take(5)) {
        final id = (item['id'] as num).toInt();
        final shown = await _channel.invokeMethod<bool>('showAssignment', {
          'id': id,
          'title': item['title']?.toString() ?? 'Bạn có chuyến mới',
          'content':
              item['content']?.toString() ??
              'Mở SafeFleet để xem chi tiết chuyến được giao.',
          'tripId': (item['referenceId'] as num?)?.toInt(),
        });
        if (shown == true) newestShown = id;
      }
      if (newestShown > lastShown.toInt()) {
        await _database.cache(_lastShownCacheKey, newestShown);
      }
    } catch (_) {
      // Mất mạng tạm thời không được làm gián đoạn màn hình tài xế.
    } finally {
      _syncing = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
