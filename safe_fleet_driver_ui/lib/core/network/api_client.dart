import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.statusCode, this.data});

  final String message;
  final int? statusCode;
  final Object? data;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.defaultApiUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _accessTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          if (error.response?.statusCode == 401 &&
              request.extra['retried'] != true &&
              !request.path.contains('/auth/refresh') &&
              !request.path.contains('/auth/login')) {
            try {
              await _refreshAccessToken();
              request.extra['retried'] = true;
              final token = await _storage.read(key: _accessTokenKey);
              request.headers['Authorization'] = 'Bearer $token';
              handler.resolve(await dio.fetch(request));
              return;
            } catch (_) {
              await clearSession();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _apiUrlKey = 'api_base_url';

  final Dio dio;
  final FlutterSecureStorage _storage;
  Future<void>? _refreshing;

  Future<void> initialize() async {
    final override = await _storage.read(key: _apiUrlKey);
    if (override != null && override.trim().isNotEmpty) {
      dio.options.baseUrl = _normalize(override);
    }
  }

  Future<Map<String, dynamic>> login(String account, String password) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'usernameOrEmail': account.trim(), 'password': password},
        options: Options(extra: {'retried': true}),
      );
      final data = unwrapMap(response.data);
      await _saveTokens(data);
      return data;
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  Future<void> logout() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    try {
      if (refreshToken != null) {
        await dio.post<void>(
          '/auth/logout',
          data: {'refreshToken': refreshToken},
          options: Options(extra: {'retried': true}),
        );
      }
    } finally {
      await clearSession();
    }
  }

  Future<bool> hasSession() async =>
      (await _storage.read(key: _accessTokenKey))?.isNotEmpty == true;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      );
      return _unwrap<T>(response.data);
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  Future<T> post<T>(String path, {Object? data}) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(path, data: data);
      return _unwrap<T>(response.data);
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  Future<T> patch<T>(String path, {Object? data}) async {
    try {
      final response = await dio.patch<Map<String, dynamic>>(path, data: data);
      return _unwrap<T>(response.data);
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  Future<void> setBaseUrl(String value) async {
    final normalized = _normalize(value.trim());
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const ApiFailure('Địa chỉ API không hợp lệ');
    }
    dio.options.baseUrl = normalized;
    await _storage.write(key: _apiUrlKey, value: normalized);
  }

  Future<void> clearBaseUrlOverride() async {
    dio.options.baseUrl = AppConfig.defaultApiUrl;
    await _storage.delete(key: _apiUrlKey);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<void> _refreshAccessToken() async {
    if (_refreshing != null) {
      return _refreshing;
    }
    final completer = Completer<void>();
    _refreshing = completer.future;
    try {
      final refreshToken = await _storage.read(key: _refreshTokenKey);
      if (refreshToken == null) {
        throw const ApiFailure('Phiên đăng nhập đã hết hạn');
      }
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(
          extra: {'retried': true},
          headers: {'Authorization': null},
        ),
      );
      await _saveTokens(unwrapMap(response.data));
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    await _storage.write(
      key: _accessTokenKey,
      value: data['accessToken']?.toString(),
    );
    await _storage.write(
      key: _refreshTokenKey,
      value: data['refreshToken']?.toString(),
    );
  }

  T _unwrap<T>(Map<String, dynamic>? body) {
    if (body == null || body['success'] != true) {
      throw ApiFailure(body?['message']?.toString() ?? 'API không phản hồi');
    }
    return body['data'] as T;
  }

  Map<String, dynamic> unwrapMap(Map<String, dynamic>? body) {
    final value = _unwrap<Object?>(body);
    return Map<String, dynamic>.from(value! as Map);
  }

  ApiFailure _failure(DioException error) {
    final body = error.response?.data;
    final message = body is Map
        ? body['message']?.toString()
        : error.type == DioExceptionType.connectionError
        ? 'Không thể kết nối máy chủ'
        : null;
    return ApiFailure(
      message ?? error.message ?? 'Yêu cầu thất bại',
      statusCode: error.response?.statusCode,
      data: body,
    );
  }

  String _normalize(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
