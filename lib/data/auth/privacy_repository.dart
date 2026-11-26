import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

/// Privacy & data (POPIA): marketing choice, data export, account deletion.
@immutable
class PrivacySettings {
  const PrivacySettings({
    required this.marketingOptIn,
    required this.deleteBlockers,
    required this.upcomingTickets,
    required this.twoFactorEnabled,
    required this.privacyUrl,
    required this.cookiesUrl,
  });

  factory PrivacySettings.fromApi(Map<String, dynamic> json) => PrivacySettings(
    marketingOptIn: json['marketing_opt_in'] == true,
    deleteBlockers: [
      for (final item in (json['delete_blockers'] as List? ?? const []))
        '$item',
    ],
    upcomingTickets: (json['upcoming_tickets'] as num?)?.toInt() ?? 0,
    twoFactorEnabled: json['two_factor_enabled'] == true,
    privacyUrl: '${json['privacy_url'] ?? ''}',
    cookiesUrl: '${json['cookies_url'] ?? ''}',
  );

  final bool marketingOptIn;
  final List<String> deleteBlockers;
  final int upcomingTickets;
  final bool twoFactorEnabled;
  final String privacyUrl;
  final String cookiesUrl;
}

final privacyRepositoryProvider = Provider<PrivacyRepository>(
  (ref) => PrivacyRepository(ref.watch(apiClientProvider)),
);

final privacySettingsProvider = FutureProvider<PrivacySettings>(
  (ref) => ref.watch(privacyRepositoryProvider).fetch(),
);

/// The website address (API base URL without /api/v1), for legal pages.
String get siteUrl =>
    configuredApiBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');

class PrivacyRepository {
  const PrivacyRepository(this._dio);

  final Dio _dio;

  Future<PrivacySettings> fetch() => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/privacy');
    final data = response.data?['data'];
    return PrivacySettings.fromApi(
      data is Map ? Map<String, dynamic>.from(data) : const {},
    );
  });

  Future<void> setMarketing(bool optIn) => _call(
    () => _dio.put<void>('/me/marketing', data: {'opt_in': optIn}),
  );

  /// Emails a 24-hour download link. Returns the server's message.
  Future<String> requestExport() => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>('/me/export');
    return '${response.data?['message'] ?? 'Check your email.'}';
  });

  Future<void> deleteAccount({
    required String password,
    String? twoFactorCode,
  }) => _call(
    () => _dio.delete<void>(
      '/me',
      data: {
        'password': password,
        'confirm': 'DELETE',
        'two_factor_code': ?twoFactorCode,
      },
    ),
  );

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
