import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../push/push_service.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  ),
);

class AuthRepository {
  const AuthRepository(this._dio, this._tokenStore);

  final Dio _dio;
  final TokenStore _tokenStore;

  /// [twoFactorCode] is needed for accounts with two-step login; without it the
  /// server answers with an [ApiException] whose code is `TWO_FACTOR_REQUIRED`.
  Future<void> login({
    required String login,
    required String password,
    String? twoFactorCode,
  }) async {
    await _authenticate('/auth/login', {
      'login': login,
      'password': password,
      'two_factor_code': ?twoFactorCode,
    });
  }

  Future<void> registerAttendee({
    required String name,
    required String email,
    required String phone,
    required String password,
    bool marketingOptIn = false,
  }) async {
    await _authenticate('/auth/register-attendee', {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'password_confirmation': password,
      // Tapping "Create account" next to the privacy notice line accepts it.
      'accept_privacy': true,
      'marketing_opt_in': marketingOptIn,
    });
  }

  /// Revokes the token on the server (if it is still valid) and removes it
  /// from the device.
  Future<void> logout() async {
    await PushService.unregister(_dio);
    try {
      await _dio.post<void>('/auth/logout');
    } on DioException {
      // The token may already be expired or revoked; clear it anyway.
    }
    await _tokenStore.clear();
  }

  Future<void> _authenticate(String path, Map<String, Object?> payload) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: payload,
      );
      final token = response.data?['data']?['access_token'];
      if (token is! String || token.isEmpty) {
        throw const ApiException(
          'The server response did not include an access token.',
        );
      }
      try {
        await _tokenStore.write(token);
        // The API client reads the saved token, so register afterwards.
        unawaited(PushService.register(_dio));
      } on PlatformException {
        throw const ApiException(
          'Your account was created, but the sign-in token could not be '
          'securely saved on this device.',
        );
      }
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
