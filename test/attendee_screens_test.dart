import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jol/features/attendee/state/attendee_controller.dart';
import 'package:jol/features/discover/models/jol_event.dart';
import 'package:jol/features/discover/screens/attendee_discovery_screens.dart';
import 'package:jol/features/discover/widgets/jol_poster.dart';
import 'package:jol/ui/theme/jol_theme.dart';

void main() {
  testWidgets('Discover screen renders controls, categories and events', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: JolTheme.dark,
          home: Scaffold(body: DiscoverScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('discover more'), findsOneWidget);
    expect(find.text('pick your kind of night'), findsOneWidget);
    expect(find.text('nightlife'), findsWidgets);
    expect(find.text('Amapiano Sundowner'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Got an invite code?'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Got an invite code?'), findsOneWidget);
  });

  testWidgets('Search screen has privacy-aware people and event results', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: JolTheme.dark,
          home: Scaffold(body: SearchScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('organisers'), findsOneWidget);
    expect(find.text('Verified organiser'), findsWidgets);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Private profile'), findsOneWidget);
    expect(find.text('Aisha Khan'), findsOneWidget);
  });

  testWidgets('private event hides the exact address before RSVP', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: JolTheme.dark,
          home: Scaffold(body: EventScreen(eventId: 'thandi')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Address shared after RSVP'), findsOneWidget);
    expect(find.text('18 Example Street'), findsNothing);
  });

  testWidgets('all six poster styles paint at a small size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: JolTheme.dark,
        home: Scaffold(
          body: Wrap(
            children: [
              for (final style in JolPosterStyle.values)
                JolPoster(
                  style: style,
                  primary: const Color(0xFFE8792E),
                  secondary: const Color(0xFF4A0E1C),
                  title: 'JOL test',
                  dateStamp: "'26 11 07",
                  size: const Size(120, 150),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(JolPoster), findsNWidgets(6));
  });

  test('student verification state stays false until explicitly verified', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(attendeeControllerProvider).isStudentVerified,
      isFalse,
    );
    container
        .read(attendeeControllerProvider.notifier)
        .verifyStudent('student@myuct.ac.za');
    expect(
      container.read(attendeeControllerProvider).isStudentVerified,
      isTrue,
    );
    expect(
      container.read(attendeeControllerProvider).studentEmail,
      'student@myuct.ac.za',
    );
  });
}
