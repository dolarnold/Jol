import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/jol_event.dart';

class JolPoster extends StatelessWidget {
  const JolPoster({
    super.key,
    required this.style,
    required this.primary,
    required this.secondary,
    required this.title,
    required this.dateStamp,
    required this.size,
    this.area,
    this.imageFile,
    this.imageUrl,
  });

  final JolPosterStyle style;
  final Color primary;
  final Color secondary;
  final String title;
  final String dateStamp;
  final Size size;
  final String? area;
  final File? imageFile;

  /// Cover photo from the API, shown under the poster text when set.
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final art = CustomPaint(
      painter: _PosterPainter(
        style: style,
        primary: primary,
        secondary: secondary,
        title: title,
        dateStamp: dateStamp,
        area: area,
        paintArt: true,
      ),
    );
    final text = CustomPaint(
      painter: _PosterPainter(
        style: style,
        primary: primary,
        secondary: secondary,
        title: title,
        dateStamp: dateStamp,
        area: area,
        paintArt: false,
      ),
    );
    final url = imageUrl;
    return SizedBox.fromSize(
      size: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageFile != null) ...[
              Image.file(imageFile!, fit: BoxFit.cover),
              text,
            ] else if (url != null)
              Image.network(
                url,
                fit: BoxFit.cover,
                // Draw the photo with the poster text over it; fall back to
                // the generated poster while loading or if the image fails.
                frameBuilder: (context, child, frame, _) => frame == null
                    ? art
                    : Stack(fit: StackFit.expand, children: [child, text]),
                errorBuilder: (_, _, _) => art,
              )
            else
              art,
          ],
        ),
      ),
    );
  }
}

class _PosterPainter extends CustomPainter {
  const _PosterPainter({
    required this.style,
    required this.primary,
    required this.secondary,
    required this.title,
    required this.dateStamp,
    required this.area,
    required this.paintArt,
  });

  final JolPosterStyle style;
  final Color primary;
  final Color secondary;
  final String title;
  final String dateStamp;
  final String? area;
  final bool paintArt;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    if (paintArt) {
      canvas.drawRect(bounds, Paint()..color = secondary);
      switch (style) {
        case JolPosterStyle.sunset:
          _drawSunset(canvas, size);
          break;
        case JolPosterStyle.boldType:
          _drawBoldType(canvas, size);
          break;
        case JolPosterStyle.halftone:
          _drawHalftone(canvas, size);
          break;
        case JolPosterStyle.stripes:
          _drawStripes(canvas, size);
          break;
        case JolPosterStyle.glow:
          _drawGlow(canvas, size);
          break;
        case JolPosterStyle.split:
          _drawSplit(canvas, size);
          break;
      }
    }

    _drawLightLeaks(canvas, size);
    _drawVignette(canvas, size);
    _drawGrain(canvas, size);
    _drawStamp(canvas, size);
    if (size.width >= 160 && area != null) {
      _drawArea(canvas, size);
    }
  }

  void _drawSunset(Canvas canvas, Size size) {
    final horizon = size.height * .62;
    canvas.drawCircle(
      Offset(size.width * .68, horizon * .72),
      size.width * .25,
      Paint()..color = primary,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
      Paint()
        ..shader = LinearGradient(
          colors: [primary.withValues(alpha: .82), secondary],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );
    canvas.drawLine(
      Offset(0, horizon),
      Offset(size.width, horizon),
      Paint()
        ..color = Colors.white.withValues(alpha: .46)
        ..strokeWidth = 1,
    );
    _drawTitle(canvas, size, maxLines: 3);
  }

  void _drawBoldType(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    _drawTitle(canvas, size, maxLines: 4, large: true);
  }

  void _drawHalftone(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: .28);
    for (var y = 0.0; y < size.height; y += 8) {
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawCircle(Offset(x, y), 1.25, dotPaint);
      }
    }
    _drawTitle(canvas, size, maxLines: 3);
  }

  void _drawStripes(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = secondary);
    final stripePaint = Paint()..color = primary;
    for (var x = -size.height; x < size.width + size.height; x += 24) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + 13, 0)
        ..lineTo(x + size.height + 13, size.height)
        ..lineTo(x + size.height, size.height)
        ..close();
      canvas.drawPath(path, stripePaint);
    }
    _drawTitle(canvas, size, maxLines: 3);
  }

  void _drawGlow(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = secondary);
    canvas.drawCircle(
      Offset(size.width * .52, size.height * .42),
      size.shortestSide * .62,
      Paint()
        ..shader = RadialGradient(
          colors: [primary.withValues(alpha: .96), primary.withValues(alpha: 0)],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * .52, size.height * .42),
            radius: size.shortestSide * .62,
          ),
        ),
    );
    _drawTitle(canvas, size, maxLines: 3);
  }

  void _drawSplit(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = primary);
    final split = Path()
      ..moveTo(size.width * .63, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(split, Paint()..color = secondary);
    canvas.drawCircle(
      Offset(size.width * .68, size.height * .34),
      size.shortestSide * .2,
      Paint()
        ..color = Colors.transparent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(size.width * .68, size.height * .34),
      size.shortestSide * .2,
      Paint()
        ..color = Colors.white.withValues(alpha: .75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawTitle(canvas, size, maxLines: 3);
  }

  void _drawTitle(
    Canvas canvas,
    Size size, {
    required int maxLines,
    bool large = false,
  }) {
    final fontSize = (size.width * (large ? .155 : .11)).clamp(18, 54);
    final painter = TextPainter(
      text: TextSpan(
        text: title.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'ArchivoExpanded',
          fontSize: fontSize.toDouble(),
          fontWeight: FontWeight.w800,
          height: .96,
          shadows: const [
            Shadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 3)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: size.width * .82);

    final top = size.height * .12;
    painter.paint(canvas, Offset(size.width * .08, top));
  }

  void _drawLightLeaks(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x9EFF7628),
            Color(0x00FF7628),
            Color(0x00FF3440),
            Color(0x66FF3440),
          ],
          stops: [0, .35, .72, 1],
        ).createShader(bounds),
    );
    canvas.drawCircle(
      Offset(size.width * .52, size.height * .48),
      size.shortestSide * .3,
      Paint()
        ..blendMode = BlendMode.screen
        ..color = const Color(0x1DFFD6A0),
    );
  }

  void _drawVignette(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: .62)],
          stops: const [.42, 1],
          radius: 1.1,
        ).createShader(bounds),
    );
  }

  void _drawGrain(Canvas canvas, Size size) {
    final random = math.Random(241107);
    final grain = Paint()..color = Colors.white.withValues(alpha: .13);
    final grainCount = (size.width * size.height / 26).round();
    for (var i = 0; i < grainCount; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
          .7,
          .7,
        ),
        grain,
      );
    }
  }

  void _drawStamp(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: dateStamp,
        style: const TextStyle(
          color: Color(0xFFFF8A2A),
          fontFamily: 'ShareTechMono',
          fontSize: 12,
          shadows: [
            Shadow(color: Color(0xFFFF6B22), blurRadius: 8),
            Shadow(color: Color(0xAA000000), blurRadius: 3, offset: Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(size.width - painter.width - 9, size.height - painter.height - 8),
    );
  }

  void _drawArea(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: area!.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'ArchivoExpanded',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * .58);
    painter.paint(canvas, Offset(10, size.height - painter.height - 25));
  }

  @override
  bool shouldRepaint(covariant _PosterPainter oldDelegate) =>
      style != oldDelegate.style ||
      primary != oldDelegate.primary ||
      secondary != oldDelegate.secondary ||
      title != oldDelegate.title ||
      dateStamp != oldDelegate.dateStamp ||
      area != oldDelegate.area ||
      paintArt != oldDelegate.paintArt;
}
