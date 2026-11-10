import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../theme/jol_theme.dart';
import '../widgets/jol_button.dart';
import '../widgets/jol_logo.dart';
import '../widgets/jol_theme_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: tokens.background,
            systemNavigationBarColor: tokens.background,
          ),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: const JolThemeButton(),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(26, 4, 26, 12),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(0, constraints.maxHeight - 80),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _PosterCollage(),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                JolLogo(size: 72, color: tokens.text),
                                const SizedBox(width: 10),
                                Text(
                                  'jol',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayLarge
                                      ?.copyWith(fontSize: 76, height: 0.96),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'find the jol. host the jol.',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontSize: 25,
                                    letterSpacing: -0.85,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'nightlife, fitness and networking in Cape Town',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: tokens.muted),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(26, 10, 26, 14),
                    child: Column(
                      children: [
                        JolButton(
                          key: const ValueKey('create-account'),
                          label: 'Create account',
                          expanded: true,
                          onPressed: () => context.push('/signup'),
                        ),
                        const SizedBox(height: 10),
                        JolButton(
                          label: 'I already have an account',
                          variant: JolButtonVariant.secondary,
                          expanded: true,
                          onPressed: () => context.push('/login'),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 44,
                          child: TextButton(
                            onPressed: () => context.go('/discover'),
                            child: Text(
                              'Look around first',
                              style: TextStyle(
                                color: tokens.text,
                                decoration: TextDecoration.underline,
                                decorationColor: tokens.text,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PosterCollage extends StatelessWidget {
  const _PosterCollage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: const [
            Positioned(
              left: 0,
              top: 20,
              width: 158,
              height: 183,
              child: _PosterCard(kind: _PosterKind.sunset),
            ),
            Positioned(
              left: 112,
              top: 0,
              width: 155,
              height: 207,
              child: _PosterCard(kind: _PosterKind.stripes),
            ),
            Positioned(
              right: -2,
              top: 38,
              width: 146,
              height: 194,
              child: _PosterCard(kind: _PosterKind.title),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PosterKind { sunset, stripes, title }

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.kind});

  final _PosterKind kind;

  @override
  Widget build(BuildContext context) {
    final palette = switch (kind) {
      _PosterKind.sunset => const [Color(0xFF711D22), Color(0xFF260F19)],
      _PosterKind.stripes => const [
        Color(0xFF9D67FF),
        Color(0xFF78916D),
        Color(0xFFB8AF89),
      ],
      _PosterKind.title => const [Color(0xFF332A23), Color(0xFF111110)],
    };

    return Transform.rotate(
      angle: switch (kind) {
        _PosterKind.sunset => -0.095,
        _PosterKind.stripes => 0.045,
        _PosterKind.title => -0.02,
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: palette,
                ),
              ),
            ),
            CustomPaint(painter: _PosterArtPainter(kind)),
            if (kind == _PosterKind.title) ...[
              const Positioned(
                left: 12,
                top: 12,
                right: 8,
                child: Text(
                  'FOUNDERS\n&\nFRIENDS\nMIXER',
                  style: TextStyle(
                    fontFamily: 'ArchivoExpanded',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.02,
                    color: Color(0xFFF1F0EC),
                  ),
                ),
              ),
              const Positioned(
                right: 10,
                bottom: 10,
                child: Text(
                  '\'26 11 07',
                  style: TextStyle(
                    fontFamily: 'ShareTechMono',
                    fontSize: 8,
                    color: Color(0xFFFF8A2A),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PosterArtPainter extends CustomPainter {
  const _PosterArtPainter(this.kind);

  final _PosterKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case _PosterKind.sunset:
        final sunCenter = Offset(size.width * 0.57, size.height * 0.64);
        canvas.drawCircle(
          sunCenter,
          size.width * 0.22,
          Paint()..color = const Color(0xFFFF9A35),
        );
        canvas.drawRect(
          Rect.fromLTWH(0, sunCenter.dy, size.width, 2),
          Paint()..color = const Color(0xFFA17952),
        );
      case _PosterKind.stripes:
        canvas.save();
        canvas.translate(size.width / 2, size.height / 2);
        canvas.rotate(-0.58);
        final stripePaint = Paint()..color = const Color(0xFFB4C28D);
        for (var y = -size.height; y < size.height * 1.6; y += 42) {
          canvas.drawRect(
            Rect.fromLTWH(-size.width, y, size.width * 2, 20),
            stripePaint,
          );
        }
        canvas.restore();
      case _PosterKind.title:
        final glow = Paint()
          ..shader =
              const RadialGradient(
                colors: [Color(0x35D6A973), Color(0x00161110)],
              ).createShader(
                Rect.fromCircle(
                  center: Offset(size.width * 0.55, size.height * 0.32),
                  radius: size.width * 0.85,
                ),
              );
        canvas.drawRect(Offset.zero & size, glow);
    }

    final grain = Paint()..color = const Color(0x12FFFFFF);
    for (var y = 8.0; y < size.height; y += 13) {
      for (var x = 7.0; x < size.width; x += 13) {
        final offset = (x + y).toInt() % 3;
        canvas.drawCircle(Offset(x + offset, y), 0.7, grain);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PosterArtPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
