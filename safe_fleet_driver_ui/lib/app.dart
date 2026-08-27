import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/theme.dart';
import 'core/design/tokens.dart';
import 'core/network/api_client.dart';
import 'core/network/driver_repository.dart';
import 'core/ai/cabin_safety_provider.dart';
import 'core/notifications/push_registration_service.dart';
import 'core/notifications/trip_assignment_notification_monitor.dart';
import 'core/storage/local_database.dart';
import 'core/storage/sync_queue.dart';
import 'features/auth/login_screen.dart';
import 'features/camera/cabin_camera_screen.dart';
import 'features/documents/document_ocr_queue_repository.dart';
import 'features/documents/document_ocr_sync_queue.dart';
import 'features/documents/document_scan_service.dart';
import 'features/documents/driving_log_export_service.dart';
import 'features/documents/driving_log_repository.dart';
import 'features/documents/server_document_ocr_service.dart';
import 'features/shell/driver_shell.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final databaseProvider = Provider<LocalDatabase>((ref) {
  final database = LocalDatabase();
  ref.onDispose(database.close);
  return database;
});
final syncQueueProvider = Provider<SyncQueue>((ref) {
  final queue = SyncQueue(
    ref.read(databaseProvider),
    ref.read(apiClientProvider),
  );
  ref.onDispose(queue.dispose);
  return queue;
});
final drivingLogRepositoryProvider = Provider<DrivingLogRepository>(
  (ref) => DrivingLogRepository(ref.read(databaseProvider)),
);
final documentScanServiceProvider = Provider<DocumentScanService>((ref) {
  final service = DocumentScanService();
  ref.onDispose(service.dispose);
  return service;
});
final serverDocumentOcrServiceProvider = Provider<DocumentOcrGateway>(
  (ref) => ServerDocumentOcrService(ref.read(apiClientProvider)),
);
final documentOcrQueueRepositoryProvider = Provider<DocumentOcrQueueRepository>(
  (ref) => DocumentOcrQueueRepository(ref.read(databaseProvider)),
);
final documentOcrSyncQueueProvider = Provider<DocumentOcrSyncQueue>((ref) {
  final queue = DocumentOcrSyncQueue(
    queueRepository: ref.read(documentOcrQueueRepositoryProvider),
    drivingLogRepository: ref.read(drivingLogRepositoryProvider),
    gateway: ref.read(serverDocumentOcrServiceProvider),
  );
  ref.onDispose(queue.dispose);
  return queue;
});
final drivingLogExportServiceProvider = Provider<DrivingLogExportService>(
  (_) => DrivingLogExportService(),
);
final driverRepositoryProvider = Provider<DriverRepository>(
  (ref) => DriverRepository(
    ref.read(apiClientProvider),
    ref.read(databaseProvider),
    ref.read(syncQueueProvider),
  ),
);
final tripAssignmentNotificationMonitorProvider =
    Provider<TripAssignmentNotificationMonitor>((ref) {
      final monitor = TripAssignmentNotificationMonitor(
        ref.read(driverRepositoryProvider),
        ref.read(databaseProvider),
      );
      ref.onDispose(monitor.dispose);
      return monitor;
    });
final pushRegistrationServiceProvider = Provider<PushRegistrationService>((
  ref,
) {
  final service = PushRegistrationService(ref.read(apiClientProvider));
  ref.onDispose(service.dispose);
  return service;
});

enum SessionStatus { checking, signedOut, signedIn }

final sessionProvider = NotifierProvider<SessionController, SessionStatus>(
  SessionController.new,
);

class SessionController extends Notifier<SessionStatus> {
  @override
  SessionStatus build() => SessionStatus.checking;

  Future<void> restore() async {
    final api = ref.read(apiClientProvider);
    await api.initialize();
    ref.read(syncQueueProvider).start();
    var signedIn = await api.hasSession();
    if (signedIn) {
      try {
        await api.get<Map<String, dynamic>>('/auth/me');
      } on ApiFailure catch (error) {
        // Mạng tạm thời gián đoạn vẫn cho phép tài xế dùng dữ liệu offline.
        // Chỉ xóa phiên khi server xác nhận token thực sự không còn hợp lệ.
        if (error.statusCode == 401) {
          await api.clearSession();
          signedIn = false;
        }
      }
    }
    state = signedIn ? SessionStatus.signedIn : SessionStatus.signedOut;
    if (signedIn) {
      await ref.read(documentOcrSyncQueueProvider).start();
      await ref.read(tripAssignmentNotificationMonitorProvider).start();
      await ref.read(pushRegistrationServiceProvider).start();
    }
  }

  Future<void> login(String account, String password) async {
    await ref.read(apiClientProvider).login(account, password);
    await ref.read(documentOcrSyncQueueProvider).start();
    await ref.read(tripAssignmentNotificationMonitorProvider).start();
    await ref.read(pushRegistrationServiceProvider).start();
    state = SessionStatus.signedIn;
  }

  Future<void> logout() async {
    await ref.read(cabinSafetyProvider.notifier).stop();
    await ref.read(documentOcrSyncQueueProvider).stop();
    await ref.read(tripAssignmentNotificationMonitorProvider).stop();
    await ref.read(pushRegistrationServiceProvider).stop(unregister: true);
    await ref.read(apiClientProvider).logout();
    state = SessionStatus.signedOut;
  }
}

class SafeFleetDriverApp extends ConsumerStatefulWidget {
  const SafeFleetDriverApp({super.key});

  @override
  ConsumerState<SafeFleetDriverApp> createState() => _SafeFleetDriverAppState();
}

class _SafeFleetDriverAppState extends ConsumerState<SafeFleetDriverApp>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => ref.read(sessionProvider.notifier).restore());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(cabinSafetyProvider.notifier);
    switch (state) {
      case AppLifecycleState.resumed:
        controller.enterForeground();
        ref.read(documentOcrSyncQueueProvider).syncNow();
        ref.read(tripAssignmentNotificationMonitorProvider).syncNow();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        controller.enterBackground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(sessionProvider);
    final cabin = ref.watch(cabinSafetyProvider);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'SafeFleet Driver',
      theme: SfTheme.light,
      builder: (context, child) => Stack(
        children: [
          child ?? const SizedBox.shrink(),
          if (status == SessionStatus.signedIn && cabin.enabled)
            Positioned(
              right: 18,
              bottom: MediaQuery.paddingOf(context).bottom + 98,
              child: _GlobalCabinIndicator(
                active: cabin.active,
                onTap: () => _navigatorKey.currentState?.push<void>(
                  MaterialPageRoute(builder: (_) => const CabinCameraScreen()),
                ),
              ),
            ),
        ],
      ),
      home: switch (status) {
        SessionStatus.checking => const _SplashScreen(),
        SessionStatus.signedOut => const LoginScreen(),
        SessionStatus.signedIn => const DriverShell(),
      },
    );
  }
}

class _GlobalCabinIndicator extends StatelessWidget {
  const _GlobalCabinIndicator({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = active ? SfColors.onAccent : SfColors.amberInk;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: SfRadius.pillR,
        boxShadow: SfShadow.floating,
      ),
      child: Material(
        color: active ? SfColors.green700 : SfColors.amber,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SfSpace.x12,
              vertical: SfSpace.x8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility, color: ink, size: 16),
                const SizedBox(width: SfSpace.x4),
                Text(
                  active ? 'AI BẬT' : 'AI…',
                  style: SfType.label.copyWith(color: ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.sf.surface,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BrandMark(size: 76),
          const SizedBox(height: SfSpace.x20),
          Text(
            'SAFEFLEET',
            style: SfType.titleSub.copyWith(
              color: context.sf.textPrimary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: SfSpace.x24),
          const SizedBox(width: 120, child: LinearProgressIndicator()),
        ],
      ),
    ),
  );
}

class BrandMark extends _BrandMark {
  const BrandMark({super.key, super.size, super.onHero});
}

/// Logo khiên bo 18px. Trên nền xanh dùng nền trắng 16%, icon trắng; trên nền
/// sáng thì ngược lại.
class _BrandMark extends StatelessWidget {
  const _BrandMark({super.key, this.size = 56, this.onHero = false});

  final double size;
  final bool onHero;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: onHero
          ? SfColors.onAccent.withValues(alpha: 0.16)
          : SfColors.green700,
      borderRadius: BorderRadius.circular(size * .32),
    ),
    child: Icon(
      Icons.shield_rounded,
      size: size * .54,
      color: onHero ? SfColors.onAccent : SfColors.green300,
    ),
  );
}
