import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'ui/screens/login_screen.dart';
import 'ui/screens/signup_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/tab_placeholder_screen.dart';
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
                builder: (context, state) => const TabPlaceholderScreen(
                  title: 'discover more',
                  subtitle: 'Find your next reason to go out.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const TabPlaceholderScreen(
                  title: 'search',
                  subtitle: 'Events, organisers and people.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/host',
                builder: (context, state) => const TabPlaceholderScreen(
                  title: 'hosting',
                  subtitle: 'Your events, all in one place.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tickets',
                builder: (context, state) => const TabPlaceholderScreen(
                  title: 'tickets',
                  subtitle: 'Your next night out starts here.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/me',
                builder: (context, state) => const TabPlaceholderScreen(
                  title: 'you',
                  subtitle: 'Your profile and preferences.',
                  showGalleryLink: true,
                ),
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
