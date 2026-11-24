import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Single place to rename the product.
class AppBrand {
  static const name = 'Swadharma';
  static const tagline = 'Clarity from the stars,\none conversation away';
}

/// A stylised third eye: almond outline, glowing iris and a few rays.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64, this.color = AppColors.gold});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _EyePainter(color));
}

class _EyePainter extends CustomPainter {
  _EyePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2, cy = s * .58;

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .05
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final eye = Path()
      ..moveTo(s * .06, cy)
      ..cubicTo(s * .26, cy - s * .32, s * .74, cy - s * .32, s * .94, cy)
      ..cubicTo(s * .74, cy + s * .32, s * .26, cy + s * .32, s * .06, cy);
    canvas.drawPath(eye, outline);

    // Iris
    final irisRect = Rect.fromCircle(center: Offset(cx, cy), radius: s * .16);
    canvas.drawCircle(
      Offset(cx, cy),
      s * .16,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFD98A), AppColors.saffron],
        ).createShader(irisRect),
    );
    canvas.drawCircle(Offset(cx, cy), s * .065, Paint()..color = AppColors.indigoDeep);
    canvas.drawCircle(Offset(cx - s * .04, cy - s * .04), s * .022,
        Paint()..color = Colors.white.withValues(alpha: .9));

    // Rays above the eye (the "third eye" opening).
    final ray = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * .04
      ..color = color.withValues(alpha: .85);
    for (final deg in [-90.0, -58.0, -122.0]) {
      final a = deg * math.pi / 180;
      final r0 = s * (deg == -90 ? .33 : .36), r1 = s * (deg == -90 ? .43 : .44);
      canvas.drawLine(Offset(cx + r0 * math.cos(a), cy + r0 * math.sin(a)),
          Offset(cx + r1 * math.cos(a), cy + r1 * math.sin(a)), ray);
    }
  }

  @override
  bool shouldRepaint(_EyePainter old) => old.color != color;
}

/// Mark + wordmark.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 40, this.light = true, this.axis = Axis.horizontal});

  final double markSize;
  final bool light;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final name = Text(
      AppBrand.name,
      style: TextStyle(
        fontFamily: AppTheme.serif,
        fontSize: markSize * .62,
        fontWeight: FontWeight.w700,
        letterSpacing: .4,
        color: light ? Colors.white : AppColors.ink,
        fontFeatures: const [FontFeature.liningFigures()],
      ),
    );
    final mark = BrandMark(size: markSize, color: light ? AppColors.gold : AppColors.saffron);
    return axis == Axis.horizontal
        ? Row(mainAxisSize: MainAxisSize.min, children: [mark, const SizedBox(width: 10), name])
        : Column(mainAxisSize: MainAxisSize.min, children: [mark, SizedBox(height: markSize * .18), name]);
  }
}

/// Deep-indigo night sky with a faint starfield and a warm glow.
class HeroBackdrop extends StatelessWidget {
  const HeroBackdrop({super.key, this.child, this.glow = true});

  final Widget? child;
  final bool glow;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: CustomPaint(painter: _SkyPainter(glow: glow), child: child),
      );
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.glow});
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (glow) {
      final center = Offset(size.width * .85, size.height * .08);
      final r = size.shortestSide * .9;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            AppColors.saffron.withValues(alpha: .22),
            AppColors.saffron.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
    final rand = math.Random(7);
    final dot = Paint();
    for (var i = 0; i < 70; i++) {
      final gold = rand.nextDouble() < .18;
      dot.color = (gold ? AppColors.gold : Colors.white)
          .withValues(alpha: .12 + rand.nextDouble() * .45);
      canvas.drawCircle(
        Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height),
        .5 + rand.nextDouble() * 1.4,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.glow != glow;
}
