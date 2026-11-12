import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jol/data/api/api_client.dart';
import 'package:jol/data/auth/auth_repository.dart';
import 'package:jol/features/discover/data/event_repository.dart';
import 'package:jol/features/discover/models/jol_event.dart';

class _MemoryTokenStore implements TokenStore {
  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}

void main() {
  test(
    'attendee registration sends the API payload and stores its token',
    () async {
      final tokenStore = _MemoryTokenStore();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'));
      RequestOptions? request;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': {'access_token': 'plain-text-token'},
                },
              ),
            );
          },
        ),
      );
      final repository = AuthRepository(dio, tokenStore);

      await repository.registerAttendee(
        name: 'Lesego Mokoena',
        email: 'lesego@example.com',
        phone: '+27825550147',
        password: 'password123',
      );

      expect(request?.uri.path, '/api/v1/auth/register-attendee');
      expect(request?.data, {
        'name': 'Lesego Mokoena',
        'email': 'lesego@example.com',
        'phone': '+27825550147',
        'password': 'password123',
        'password_confirmation': 'password123',
      });
      expect(tokenStore.token, 'plain-text-token');
      dio.close();
    },
  );

  test('login API client attaches the saved bearer token', () async {
    final tokenStore = _MemoryTokenStore()..token = 'saved-token';
    final container = ProviderContainer(
      overrides: [tokenStoreProvider.overrideWithValue(tokenStore)],
    );
    addTearDown(container.dispose);
    final dio = container.read(apiClientProvider);
    RequestOptions? request;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response(requestOptions: options, data: {'data': []}),
          );
        },
      ),
    );

    await dio.get<void>('/events');

    expect(request?.headers['Authorization'], 'Bearer saved-token');
  });

  test('event payload maps into the discovery model without leaking a private address', () {
    final event = JolEvent.fromApi({
      'id': 42,
      'title': 'Rooftop Session',
      'category': 'nightlife',
      'type': 'commercial',
      'start_time': '2026-11-14T16:00:00+02:00',
      'end_time': '2026-11-14T22:00:00+02:00',
      'is_private': true,
      'location_name': 'The Rooftop',
      'address': '18 Example Street, Cape Town',
      'host': {'name': 'JOL Collective'},
      'ticket_tiers': [
        {
          'id': 3,
          'name': 'General',
          'description': 'Entry ticket',
          'price': 180.5,
          'remaining': 4,
        },
      ],
      'contribution_pot': null,
    });

    expect(event.id, '42');
    expect(event.title, 'Rooftop Session');
    expect(event.isApiBacked, isTrue);
    expect(event.venue, 'The Rooftop');
    expect(event.address, 'Cape Town, Cape Town');
    expect(event.tiers.single.id, '3');
    expect(event.tiers.single.price, 181);
    expect(event.fromPrice, 181);
  });

  test('event repository reads the Laravel resource collection', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response(
            requestOptions: options,
            data: {
              'data': [
                {
                  'id': 1,
                  'title': 'Sample event',
                  'start_time': '2026-11-14T16:00:00+02:00',
                  'ticket_tiers': [],
                },
              ],
            },
          ),
        ),
      ),
    );

    final events = await EventRepository(dio).fetchEvents();

    expect(events, hasLength(1));
    expect(events.single.title, 'Sample event');
    dio.close();
  });

  test('event repository resolves an event by its API identifier', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'));
    RequestOptions? request;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'data': {
                  'event': {
                    'id': 42,
                    'title': 'Rooftop Session',
                    'start_time': '2026-11-14T16:00:00+02:00',
                    'ticket_tiers': [],
                  },
                },
              },
            ),
          );
        },
      ),
    );

    final event = await EventRepository(dio).fetchEvent('42');

    expect(request?.uri.path, '/api/v1/events/42');
    expect(event.id, '42');
    expect(event.title, 'Rooftop Session');
    dio.close();
  });
}
