import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

String get defaultApiBaseUrl {
  if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb) {
    return 'http://10.0.2.2:8000/api/v1';
  }
  return 'http://127.0.0.1:8000/api/v1';
}

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
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
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
        handler.next(options);
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
  const ApiException(this.message);

  final String message;

  factory ApiException.fromDio(DioException exception) {
    final response = exception.response?.data;
    if (response is Map) {
      final error = response['error'];
      if (error is Map) {
        final details = error['details'];
        if (details is Map) {
          for (final value in details.values) {
            if (value is List && value.isNotEmpty) {
              return ApiException(value.first.toString());
            }
          }
        }
        final message = error['message'];
        if (message is String && message.isNotEmpty) {
          return ApiException(message);
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
