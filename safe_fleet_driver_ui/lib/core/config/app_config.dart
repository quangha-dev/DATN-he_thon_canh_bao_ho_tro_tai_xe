import 'dart:io';

abstract final class AppConfig {
  static const _definedApiUrl = String.fromEnvironment('API_BASE_URL');

  static String get defaultApiUrl {
    if (_definedApiUrl.isNotEmpty) return _normalize(_definedApiUrl);
    if (Platform.isAndroid) return 'http://10.0.2.2:8080/api/v1';
    return 'http://127.0.0.1:8080/api/v1';
  }

  static const mapStyleUrl = String.fromEnvironment(
    'MAP_STYLE_URL',
    defaultValue: 'https://tiles.openfreemap.org/styles/bright',
  );

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
