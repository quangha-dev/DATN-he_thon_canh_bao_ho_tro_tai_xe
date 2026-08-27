import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../../app.dart';

const _periodicTaskUniqueName = 'safefleet-background-sync-v1';
const _periodicTaskName = 'sync-offline-queues';

/// Entry point chạy trong isolate riêng của Android WorkManager/iOS Background
/// Fetch. Mỗi lần chạy đều tự khởi tạo storage, API client và SQLite; không giữ
/// tham chiếu đến UI isolate.
@pragma('vm:entry-point')
void safeFleetBackgroundDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final container = ProviderContainer();
    try {
      final api = container.read(apiClientProvider);
      await api.initialize();
      if (!await api.hasSession()) return true;

      await container.read(syncQueueProvider).syncNow();
      final ocrQueue = container.read(documentOcrSyncQueueProvider);
      await ocrQueue.start(syncImmediately: false);
      await ocrQueue.syncNow();
      await ocrQueue.stop();
      return true;
    } catch (_) {
      // false yêu cầu nền tảng retry với backoff; payload trong SQLite vẫn còn
      // nguyên và các API đột biến đều có clientEventId/idempotency key.
      return false;
    } finally {
      container.dispose();
    }
  });
}

Future<void> initializeBackgroundSync() async {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

  await Workmanager().initialize(safeFleetBackgroundDispatcher);
  if (Platform.isAndroid) {
    await Workmanager().registerPeriodicTask(
      _periodicTaskUniqueName,
      _periodicTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
  // iOS dùng Background Fetch do hệ điều hành lập lịch; Info.plist đã bật
  // UIBackgroundModes=fetch và callback nhận Workmanager.iOSBackgroundTask.
}
