import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jol/app.dart';

Future<void> _launchToWelcome(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: JolApp()));
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('splash leads to welcome with a working theme switch', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: JolApp()));

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
    expect(find.text('Student email'), findsOneWidget);
    expect(find.text('Send code & continue'), findsOneWidget);
  });

  testWidgets('sign-up validates fields without pretending to send a code', (
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
    expect(
      find.text(
        "That isn't a student email. Use your university "
        'address ending in .ac.za, like name@myuct.ac.za.',
      ),
      findsOneWidget,
    );

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
    await tester.enterText(
      find.byKey(const ValueKey('student-email')),
      'lesego@college.co.za',
    );
    await tester.tap(find.byKey(const ValueKey('signup-continue')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "That isn't a student email. Use your university "
        'address ending in .ac.za, like name@myuct.ac.za.',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('student-email')),
      'lesego@myuct.ac.za',
    );
    await tester.tap(find.byKey(const ValueKey('signup-continue')));
    await tester.pumpAndSettle();
    expect(
      find.text('Sign-up isn’t connected yet, so no code was sent.'),
      findsOneWidget,
    );
  });

  testWidgets('login and guest browsing lead to the tab shell', (tester) async {
    await _launchToWelcome(tester);
    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();
    expect(find.text('good to see you again'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('mobile-number')),
      '825550147',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.text('Sign-in isn’t connected yet, so no code was sent.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

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
