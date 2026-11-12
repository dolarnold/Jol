import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jol/app.dart';
import 'package:jol/data/api/api_client.dart';
import 'package:jol/data/auth/auth_repository.dart';
import 'package:jol/data/mocks/mock_attendee_events.dart';
import 'package:jol/features/discover/data/event_repository.dart';

Widget _testApp() {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(_TestAuthRepository()),
      attendeeEventsProvider.overrideWith((ref) async => mockAttendeeEvents),
    ],
    child: const JolApp(),
  );
}

Future<void> _launchToWelcome(WidgetTester tester) async {
  await tester.pumpWidget(_testApp());
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pumpAndSettle();
}

class _MemoryTokenStore implements TokenStore {
  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}

class _TestAuthRepository extends AuthRepository {
  _TestAuthRepository() : super(Dio(), _MemoryTokenStore());

  @override
  Future<void> registerAttendee({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {}

  @override
  Future<void> login({required String login, required String password}) async {
    throw const ApiException('Invalid credentials.');
  }
}

void main() {
  testWidgets('splash leads to welcome with a working theme switch', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    expect(find.text('J O L'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('J O L'))).brightness,
      Brightness.dark,
    );

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('find the jol. host the jol.'), findsOneWidget);

    await tester.tap(find.byTooltip('Switch to light theme'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('find the jol. host the jol.')))
          .brightness,
      Brightness.light,
    );

    await tester.tap(find.byKey(const ValueKey('create-account')));
    await tester.pumpAndSettle();
    expect(find.text('Let’s get you in'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('Let’s get you in'))).brightness,
      Brightness.light,
    );
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('sign-up validates fields and submits an account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _launchToWelcome(tester);
    await tester.tap(find.byKey(const ValueKey('create-account')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('signup-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Enter your full name.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('signup-name')),
      'Lesego Mokoena',
    );
    await tester.enterText(
      find.byKey(const ValueKey('mobile-number')),
      '825550147',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-email')),
      'lesego@example.com',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('signup-password')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-password')),
      'password123',
    );
    await tester.tap(find.byKey(const ValueKey('signup-continue')));
    await tester.pumpAndSettle();
    expect(find.text('discover more'), findsOneWidget);
  });

  testWidgets('login errors are shown and guests can browse the tab shell', (
    tester,
  ) async {
    await _launchToWelcome(tester);
    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();
    expect(find.text('good to see you again'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('login-identifier')),
      '825550147',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'password123',
    );
    await tester.tap(find.text('Log in').last);
    await tester.pumpAndSettle();
    expect(find.text('Invalid credentials.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Look around first'));
    await tester.pumpAndSettle();
    expect(find.text('discover more'), findsOneWidget);

    for (final (label, screenTitle) in [
      ('Search', 'search'),
      ('Host', 'hosting'),
      ('Tickets', 'tickets'),
      ('Me', 'you'),
    ]) {
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();
      expect(find.text(screenTitle), findsOneWidget);
    }

    await tester.tap(find.text('Open widget gallery'));
    await tester.pumpAndSettle();
    expect(find.text('Foundation components'), findsOneWidget);
    expect(find.text('Buttons'), findsOneWidget);
  });

  testWidgets(
    'welcome supports login, sign-up, guest browsing and light mode',
    (tester) async {
      await _launchToWelcome(tester);
      await tester.tap(find.byTooltip('Switch to light theme'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('create-account')));
      await tester.pumpAndSettle();
      expect(find.text('Let’s get you in'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();
      expect(find.text('good to see you again'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Look around first'));
      await tester.pumpAndSettle();
      expect(find.text('discover more'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('discover more'))).brightness,
        Brightness.light,
      );
    },
  );
}
