import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';

@immutable
class AppNotice {
  const AppNotice({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.read,
    this.title,
    this.eventId,
  });

  final String id;
  final String? title;
  final String message;
  final String? eventId;
  final bool read;
  final DateTime createdAt;
}

@immutable
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.fromJol,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final bool fromJol;
  final String body;
  final DateTime createdAt;
}

final inboxRepositoryProvider = Provider<InboxRepository>(
  (ref) => InboxRepository(ref.watch(apiClientProvider)),
);

final notificationsProvider = FutureProvider<List<AppNotice>>(
  (ref) => ref.watch(inboxRepositoryProvider).notifications(),
);

final supportMessagesProvider = FutureProvider<List<SupportMessage>>(
  (ref) => ref.watch(inboxRepositoryProvider).messages(),
);

class InboxRepository {
  const InboxRepository(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  List<Map<String, dynamic>> _list(Object? value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : const [];

  DateTime _date(Object? value) =>
      DateTime.tryParse('$value')?.toLocal() ?? DateTime.now();

  Future<List<AppNotice>> notifications() => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>('/notifications');
    return _list(response.data?['data'])
        .map(
          (item) => AppNotice(
            id: '${item['id']}',
            title: item['title'] as String?,
            message: item['message'] as String? ?? '',
            eventId: item['event_id']?.toString(),
            read: item['read'] == true,
            createdAt: _date(item['created_at']),
          ),
        )
        .toList(growable: false);
  });

  Future<void> markAllRead() => _call(() async {
    await _dio.post<void>('/notifications/read');
  });

  Future<List<SupportMessage>> messages() => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>('/support/messages');
    return _list(response.data?['data'])
        .map(
          (item) => SupportMessage(
            id: '${item['id']}',
            fromJol: item['from_jol'] == true,
            body: item['body'] as String? ?? '',
            createdAt: _date(item['created_at']),
          ),
        )
        .toList(growable: false);
  });

  Future<void> send(String body) => _call(() async {
    await _dio.post<void>('/support/messages', data: {'body': body.trim()});
  });
}
