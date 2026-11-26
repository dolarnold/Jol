import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_version.dart';

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// The live JOL server (jolnow.co.za, hosted on Laravel Cloud). Override for
/// local testing with `--dart-define=API_BASE_URL=http://<your-pc-ip>:8000/api/v1`
const defaultApiBaseUrl = 'https://jolnow.co.za/api/v1';

String get configuredApiBaseUrl =>
    _apiBaseUrl.isEmpty ? defaultApiBaseUrl : _apiBaseUrl;

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._storage);

  static const _tokenKey = 'jol_access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _tokenKey);

  @override
  Future<void> write(String token) =>
      _storage.write(key: _tokenKey, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _tokenKey);
}

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => SecureTokenStore(const FlutterSecureStorage()),
);

final apiClientProvider = Provider<Dio>((ref) {
  final tokenStore = ref.watch(tokenStoreProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: configuredApiBaseUrl.replaceFirst(RegExp(r'/+$'), ''),
      // Laravel Cloud can take a while to wake up after being idle.
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStore.read();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (AppBuild.version.isNotEmpty) {
          options.headers['X-App-Version'] = AppBuild.version;
          options.headers['X-App-Platform'] = AppBuild.platform;
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // This app version is too old: the server asks for an update.
        final data = error.response?.data;
        if (error.response?.statusCode == 426 && data is Map && data['error'] is Map) {
          final details = (data['error'] as Map)['details'];
          ref.read(appUpdateProvider.notifier).show(
            AppUpdate(
              required: true,
              message: (data['error'] as Map)['message'] as String?,
              latest: details is Map ? details['latest_version'] as String? : null,
              storeUrl: details is Map ? details['store_url'] as String? : null,
            ),
          );
        }
        handler.next(error);
      },
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(requestHeader: true, requestBody: true, responseBody: true),
    );
  }
  ref.onDispose(dio.close);
  return dio;
});

class ApiException implements Exception {
  const ApiException(this.message, {this.code});

  final String message;

  /// The server's error code, e.g. `TWO_FACTOR_REQUIRED`, when it sent one.
  final String? code;

  factory ApiException.fromDio(DioException exception) {
    final response = exception.response?.data;
    if (response is Map) {
      final error = response['error'];
      if (error is Map) {
        final code = error['code'] is String ? error['code'] as String : null;
        final details = error['details'];
        if (details is Map) {
          for (final value in details.values) {
            if (value is List && value.isNotEmpty) {
              return ApiException(value.first.toString(), code: code);
            }
          }
        }
        final message = error['message'];
        if (message is String && message.isNotEmpty) {
          return ApiException(message, code: code);
        }
      }
      final message = response['message'];
      if (message is String && message.isNotEmpty) {
        return ApiException(message);
      }
    }

    return switch (exception.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => ApiException(
        'Could not reach JOL. Check that the Laravel API is running and '
        'the API_BASE_URL is correct.',
      ),
      _ => const ApiException('The request could not be completed. Try again.'),
    };
  }

  @override
  String toString() => message;
}
