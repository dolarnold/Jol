import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/booking/screens/attendee_booking_screens.dart';
import 'features/discover/screens/attendee_discovery_screens.dart';
import 'features/profile/screens/attendee_profile_screens.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/signup_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/screens/widget_gallery_screen.dart';
import 'ui/theme/jol_theme.dart';
import 'ui/theme/jol_theme_mode.dart';
import 'ui/widgets/jol_tab_bar.dart';

GoRouter _createRouter() {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/splash'),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/interests',
        builder: (context, state) => const InterestsScreen(),
      ),
      GoRoute(
        path: '/category/:category',
        builder: (context, state) =>
            CategoryScreen(category: state.pathParameters['category']!),
      ),
      GoRoute(
        path: '/event/:eventId',
        builder: (context, state) =>
            EventScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/invite',
        builder: (context, state) => const InviteCodeScreen(),
      ),
      GoRoute(
        path: '/tickets/choose/:eventId',
        builder: (context, state) =>
            TicketSelectionScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/checkout/:eventId',
        builder: (context, state) =>
            CheckoutScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/payment-result/:eventId',
        builder: (context, state) =>
            PaymentResultScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/ticket/:eventId',
        builder: (context, state) =>
            TicketQrScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/fund/:eventId',
        builder: (context, state) =>
            FundScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/share/:eventId',
        builder: (context, state) =>
            ShareEventScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/student-verify',
        builder: (context, state) => const StudentVerificationScreen(),
      ),
      GoRoute(
        path: '/staff-request',
        builder: (context, state) => const StaffRequestScreen(),
      ),
      GoRoute(
        path: '/staff',
        builder: (context, state) => const StaffDashboardScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => Scaffold(
          body: navigationShell,
          extendBody: true,
          bottomNavigationBar: JolTabBar(
            currentIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
          ),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (context, state) => const DiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/host',
                builder: (context, state) => const HostDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tickets',
                builder: (context, state) => const TicketsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/me',
                builder: (context, state) => const AttendeeMeScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/gallery',
        builder: (context, state) => const WidgetGalleryScreen(),
      ),
    ],
  );
}

class JolApp extends ConsumerStatefulWidget {
  const JolApp({super.key});

  @override
  ConsumerState<JolApp> createState() => _JolAppState();
}

class _JolAppState extends ConsumerState<JolApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _createRouter();
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'JOL',
      debugShowCheckedModeBanner: false,
      theme: JolTheme.light,
      darkTheme: JolTheme.dark,
      themeMode: ref.watch(jolThemeModeProvider),
      routerConfig: _router,
    );
  }
}
