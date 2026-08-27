import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';

class PushRegistrationService {
  PushRegistrationService(this._api, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _deviceUuidKey = 'safefleet_device_uuid';
  static const _notificationChannel = MethodChannel(
    'vn.safefleet.safe_fleet_driver_ui/trip_notifications',
  );

  final ApiClient _api;
  final FlutterSecureStorage _storage;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  bool _started = false;

  bool get isConfigured =>
      (Platform.isAndroid || Platform.isIOS) && AppConfig.hasFirebaseConfig;

  Future<void> start() async {
    if (_started || !isConfigured) return;
    _started = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: _firebaseOptions());
      }
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) await _register(token);
      _tokenSubscription = messaging.onTokenRefresh.listen((token) {
        unawaited(_register(token));
      });
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        unawaited(_showForeground(message));
      });
    } catch (_) {
      // Firebase là kênh push tăng cường. REST polling vẫn chạy nếu cấu hình
      // client thiếu/sai hoặc dịch vụ tạm thời không khả dụng.
      await stop();
    }
  }

  Future<void> stop({bool unregister = false}) async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    _tokenSubscription = null;
    _foregroundSubscription = null;
    if (unregister && isConfigured) {
      final deviceUuid = await _storage.read(key: _deviceUuidKey);
      if (deviceUuid != null) {
        try {
          await _api.delete<void>('/mobile/push-tokens/$deviceUuid');
        } catch (_) {
          // Token hết hạn phía FCM cũng sẽ được server tự vô hiệu hóa.
        }
      }
    }
    _started = false;
  }

  Future<void> _register(String token) async {
    var deviceUuid = await _storage.read(key: _deviceUuidKey);
    if (deviceUuid == null || deviceUuid.isEmpty) {
      deviceUuid = const Uuid().v4();
      await _storage.write(key: _deviceUuidKey, value: deviceUuid);
    }
    final package = await PackageInfo.fromPlatform();
    await _api.post<Map<String, dynamic>>(
      '/mobile/push-tokens',
      data: {
        'deviceUuid': deviceUuid,
        'platform': Platform.isAndroid ? 'ANDROID' : 'IOS',
        'provider': 'FCM',
        'token': token,
        'appVersion': '${package.version}+${package.buildNumber}',
        'osVersion': Platform.operatingSystemVersion,
        'deviceModel': Platform.localHostname,
      },
    );
  }

  Future<void> _showForeground(RemoteMessage message) async {
    if (!Platform.isAndroid) return;
    final notification = message.notification;
    if (notification == null) return;
    final pushId =
        int.tryParse(message.data['pushId'] ?? '') ??
        DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _notificationChannel.invokeMethod<bool>('showAssignment', {
      'id': pushId,
      'title': notification.title ?? 'SafeFleet',
      'content': notification.body ?? 'Bạn có thông báo mới.',
      'tripId': int.tryParse(message.data['referenceId'] ?? ''),
    });
  }

  FirebaseOptions _firebaseOptions() => FirebaseOptions(
    apiKey: AppConfig.firebaseApiKey,
    appId: Platform.isAndroid
        ? AppConfig.firebaseAndroidAppId
        : AppConfig.firebaseIosAppId,
    messagingSenderId: AppConfig.firebaseMessagingSenderId,
    projectId: AppConfig.firebaseProjectId,
  );

  Future<void> dispose() => stop();
}
