import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/api_client.dart';
import '../../data/push/push_service.dart';
import '../../features/attendee/state/attendee_controller.dart';

const _background = Color(0xFF0B0B0B);
const _pinColor = Color(0xFFF1F0EC);

/// The live splash: the JOL pin drops in, bobs, looks around and blinks while
/// the app checks the saved sign-in. With "reduce motion" on it stays still.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _intro.value = 1;
    } else {
      _intro.forward().whenComplete(() {
        if (mounted) _loop.repeat();
      });
    }
    unawaited(_goToStart(minimum: still ? Duration.zero : const Duration(milliseconds: 2200)));
  }

  Future<void> _goToStart({required Duration minimum}) async {
    final container = ProviderScope.containerOf(context, listen: false);
    // Check the sign-in while the animation plays; leave once both are done.
    final results = await Future.wait<Object?>([
      Future<void>.delayed(minimum),
      container.read(tokenStoreProvider).read().catchError((_) => null),
      // Back in the mode the person last used (guest or host).
      container.read(attendeeControllerProvider.notifier).restoreAccessMode(),
    ]);
    final token = results[1] as String?;
    final signedIn = token != null && token.isNotEmpty;
    if (signedIn) {
      unawaited(PushService.register(container.read(apiClientProvider)));
    }
    if (!mounted) return;
    final mode = container.read(attendeeControllerProvider).accessMode;
    context.go(
      !signedIn
          ? '/welcome'
          : mode == AppAccessMode.host
          ? '/host'
          : '/discover',
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: _background,
        systemNavigationBarColor: _background,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              key: const ValueKey('startup-splash'),
              animation: Listenable.merge([_intro, _loop]),
              builder: (context, _) {
                final drop = Curves.elasticOut.transform(
                  (_intro.value / 0.85).clamp(0.0, 1.0),
                );
                final fade = Curves.easeOut.transform(
                  ((_intro.value - 0.45) / 0.55).clamp(0.0, 1.0),
                );
                final t = _loop.value;
                // Gentle bob; the shadow shrinks as the pin rises.
                final lift = _loop.isAnimating ? math.sin(t * 2 * math.pi) : 0.0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 210,
                      child: CustomPaint(
                        painter: _PinPainter(
                          drop: drop,
                          lift: lift,
                          look: _lookAt(t),
                          blink: _blinkAt(t),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Opacity(
                      opacity: fade,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - fade)),
                        child: Column(
                          children: [
                            Text(
                              'jol',
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(color: _pinColor, height: 1),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'what’s on tonight',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: _pinColor.withValues(alpha: 0.55),
                                    letterSpacing: 0.4,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Eyes glance left, then right, then back (−1 … 1).
  static double _lookAt(double t) {
    if (t < 0.15) return 0;
    if (t < 0.3) return -Curves.easeInOut.transform((t - 0.15) / 0.15);
    if (t < 0.55) return -1 + 2 * Curves.easeInOut.transform((t - 0.3) / 0.25);
    if (t < 0.7) return 1 - Curves.easeInOut.transform((t - 0.55) / 0.15);
    return 0;
  }

  /// 1 = open, 0 = shut: a quick blink near the end of each loop.
  static double _blinkAt(double t) {
    const start = 0.8;
    const length = 0.08;
    if (t < start || t > start + length) return 1;
    final p = (t - start) / length;
    return (p < 0.5 ? 1 - p * 2 : (p - 0.5) * 2).clamp(0.08, 1.0);
  }
}

class _PinPainter extends CustomPainter {
  const _PinPainter({
    required this.drop,
    required this.lift,
    required this.look,
    required this.blink,
  });

  /// 0 → 1 as the pin drops in.
  final double drop;

  /// −1 … 1 bob.
  final double lift;

  /// −1 (left) … 1 (right).
  final double look;

  /// 1 open … 0 shut.
  final double blink;

  @override
  void paint(Canvas canvas, Size size) {
    // The pin from JolLogo: x −1…1, y −1…1.59, scaled to fit.
    final scale = size.width * 0.34;
    final groundY = size.height * 0.9;
    final restY = groundY - 1.62 * scale;
    final y = restY - (1 - drop) * size.height * 0.7 - lift * 8;
    final centre = Offset(size.width / 2, y);

    // Shadow on the ground.
    final shadowWidth = scale * 1.7 * (1 - 0.18 * lift) * drop.clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, groundY),
        width: shadowWidth,
        height: shadowWidth * 0.12,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.07 + 0.03 * (1 - lift)),
    );

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(scale);
    final pin = Path()
      ..moveTo(0, -1)
      ..arcToPoint(const Offset(-1, 0), radius: const Radius.circular(1), clockwise: false)
      ..cubicTo(-1, .72, -.4, 1.22, 0, 1.59)
      ..cubicTo(.4, 1.22, 1, .72, 1, 0)
      ..arcToPoint(const Offset(0, -1), radius: const Radius.circular(1), clockwise: false)
      ..close();
    canvas.drawPath(pin, Paint()..color = _pinColor);

    final eye = Paint()..color = _background;
    for (final x in const [-.353, .353]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + look * .1, 0),
          width: .44,
          height: .44 * blink,
        ),
        eye,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PinPainter old) =>
      old.drop != drop || old.lift != lift || old.look != look || old.blink != blink;
}
