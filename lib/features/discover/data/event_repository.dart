import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/api_client.dart';
import '../models/jol_event.dart';

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => EventRepository(ref.watch(apiClientProvider)),
);

final attendeeEventsProvider = FutureProvider<List<JolEvent>>(
  (ref) => ref.watch(eventRepositoryProvider).fetchEvents(),
);

final attendeeEventProvider = FutureProvider.family<JolEvent, String>(
  (ref, eventId) => ref.watch(eventRepositoryProvider).fetchEvent(eventId),
);

/// "Jol Team Top List This Week", in rank order.
final topListProvider = FutureProvider<List<({JolEvent event, int rank, int attendees})>>(
  (ref) => ref.watch(eventRepositoryProvider).fetchTopList(),
);

/// Categories, cities and poster styles hosts can pick, as the JOL team set
/// them up: kind ('category', 'city', 'poster_style') → slug → label.
final catalogProvider = FutureProvider<Map<String, Map<String, String>>>(
  (ref) => ref.watch(eventRepositoryProvider).fetchCatalog(),
);

class EventRepository {
  const EventRepository(this._dio);

  final Dio _dio;

  Future<Map<String, Map<String, String>>> fetchCatalog() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/catalog');
      final data = response.data?['data'];
      if (data is! Map) return const {};
      return {
        for (final entry in data.entries)
          if (entry.value is List)
            '${entry.key}': {
              for (final item in entry.value as List)
                if (item is Map) '${item['slug']}': '${item['label']}',
            },
      };
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<JolEvent>> fetchEvents() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/events');
      final data = response.data?['data'];
      if (data is! List) {
        throw const ApiException(
          'The event response was not in the expected format.',
        );
      }
      return data
          .map((item) {
            if (item is! Map) {
              throw const ApiException(
                'The event response was not in the expected format.',
              );
            }
            return JolEvent.fromApi(Map<String, dynamic>.from(item));
          })
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<({JolEvent event, int rank, int attendees})>> fetchTopList() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/top-list');
      final data = response.data?['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .where((item) => item['event'] is Map)
          .map(
            (item) => (
              event: JolEvent.fromApi(
                Map<String, dynamic>.from(item['event'] as Map),
                attending: (item['attendees'] as num?)?.toInt() ?? 0,
              ),
              rank: (item['rank'] as num?)?.toInt() ?? 0,
              attendees: (item['attendees'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<JolEvent> fetchEvent(String eventId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/events/${Uri.encodeComponent(eventId)}',
      );
      final data = response.data?['data'];
      final event = data is Map ? data['event'] : null;
      if (event is! Map) {
        throw const ApiException(
          'The event response was not in the expected format.',
        );
      }
      final stats = data is Map ? data['stats'] : null;
      final going = stats is Map ? stats['going_count'] : null;
      return JolEvent.fromApi(
        Map<String, dynamic>.from(event),
        attending: going is num ? going.toInt() : 0,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
