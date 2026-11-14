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

class EventRepository {
  const EventRepository(this._dio);

  final Dio _dio;

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
