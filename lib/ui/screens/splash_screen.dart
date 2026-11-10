import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../widgets/jol_logo.dart';

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
      () {
        if (mounted) context.go('/welcome');
      },
    );
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
      child: const Scaffold(
        backgroundColor: Color(0xFF0B0B0B),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                JolLogo(size: 144, color: Color(0xFFF1F0EC)),
                SizedBox(height: 20),
                Text(
                  'J O L',
                  style: TextStyle(
                    color: Color(0xFFF1F0EC),
                    fontFamily: 'ArchivoExpanded',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
