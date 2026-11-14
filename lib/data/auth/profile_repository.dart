import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

/// The signed-in user, as returned by Laravel's UserResource.
@immutable
class JolUser {
  const JolUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.bio,
    this.role,
  });

  factory JolUser.fromApi(Map<String, dynamic> json) {
    String? text(String key) {
      final value = json[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    return JolUser(
      id: '${json['id']}',
      name: text('name') ?? '',
      email: text('email'),
      phone: text('phone'),
      avatarUrl: text('avatar_url'),
      bio: text('bio'),
      role: text('role'),
    );
  }

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final String? role;

  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);

/// Loads GET /auth/profile. Call `ref.invalidate(currentUserProvider)` after
/// logging in, logging out or saving the profile so it reloads.
final currentUserProvider = FutureProvider<JolUser>(
  (ref) => ref.watch(profileRepositoryProvider).fetchProfile(),
);

class ProfileRepository {
  const ProfileRepository(this._dio);

  final Dio _dio;

  Future<JolUser> fetchProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/profile');
      return _parseUser(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<JolUser> updateProfile({String? name, String? bio}) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/auth/profile',
        data: {'name': ?name, 'bio': bio},
      );
      return _parseUser(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  JolUser _parseUser(Map<String, dynamic>? body) {
    final data = body?['data'];
    final user = data is Map ? data['user'] : null;
    if (user is! Map) {
      throw const ApiException(
        'The profile response was not in the expected format.',
      );
    }
    return JolUser.fromApi(Map<String, dynamic>.from(user));
  }
}
