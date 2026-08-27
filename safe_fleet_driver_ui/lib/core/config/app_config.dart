import 'dart:io';

abstract final class AppConfig {
  static const _definedApiUrl = String.fromEnvironment('API_BASE_URL');

  static bool get hasDefinedApiUrl => _definedApiUrl.isNotEmpty;

  static String get defaultApiUrl {
    if (_definedApiUrl.isNotEmpty) return _normalize(_definedApiUrl);
    if (Platform.isAndroid) return 'http://10.0.2.2:8080/api/v1';
    return 'http://127.0.0.1:8080/api/v1';
  }

  static const mapStyleUrl = String.fromEnvironment(
    'MAP_STYLE_URL',
    defaultValue: 'https://tiles.openfreemap.org/styles/bright',
  );

  // Firebase client identifiers are public build configuration, not server
  // credentials. Never pass the Admin service-account key to the mobile app.
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');

  static bool get hasFirebaseConfig =>
      firebaseApiKey.isNotEmpty &&
      firebaseProjectId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      (Platform.isAndroid
          ? firebaseAndroidAppId.isNotEmpty
          : firebaseIosAppId.isNotEmpty);

  /// Style bản đồ dùng cho Chế độ lái ban đêm.
  ///
  /// Mặc định trùng [mapStyleUrl] để không thay đổi hành vi hiện tại. Đặt
  /// `--dart-define=MAP_STYLE_URL_DARK=<url style tối>` để bản đồ chuyển hẳn
  /// sang nền tối; khi chưa đặt, màn lái vẫn phủ một lớp lọc tối lên bản đồ
  /// sáng để không chói mắt trong cabin.
  static const mapStyleUrlDark = String.fromEnvironment(
    'MAP_STYLE_URL_DARK',
    defaultValue: mapStyleUrl,
  );

  /// True khi chưa có style tối riêng — màn lái sẽ tự phủ lớp lọc tối.
  static bool get needsDarkMapOverlay => mapStyleUrlDark == mapStyleUrl;

  static String _normalize(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
