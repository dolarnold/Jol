import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/api_client.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer ??= Timer(
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 1400),
      _goToStart,
    );
  }

  Future<void> _goToStart() async {
    if (!mounted) return;
    String? token;
    try {
      token = await ProviderScope.containerOf(
        context,
        listen: false,
      ).read(tokenStoreProvider).read();
    } catch (_) {
      token = null;
    }
    if (!mounted) return;
    context.go(token != null && token.isNotEmpty ? '/discover' : '/welcome');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: const Color(0xFF0B0B0B),
        systemNavigationBarColor: const Color(0xFF0B0B0B),
      ),
      child: Scaffold(
        backgroundColor: Color(0xFF0B0B0B),
        body: SafeArea(
          child: Center(
            child: Image.asset(
              'assets/images/jolnow_idle_loop.png',
              key: const ValueKey('startup-splash-image'),
              width: 300,
              height: 300,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
