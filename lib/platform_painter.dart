import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'platforms.dart';

void paintPlatformDetail(
  Canvas canvas,
  Offset a,
  Offset b,
  PlatformStyle style, {
  double time = 0,
  bool reducedMotion = false,
}) {
  if (style == PlatformStyle.classic) return;
  final tint = Color(style.color), span = (b - a).distance;
  canvas.save();
  canvas.translate(a.dx, a.dy);
  canvas.rotate(math.atan2(b.dy - a.dy, b.dx - a.dx));
  if (style == PlatformStyle.ion || style == PlatformStyle.solar) {
    canvas.drawLine(
      const Offset(0, -1),
      Offset(span, -1),
      Paint()
        ..color = tint.withAlpha(65)
        ..strokeWidth = 11,
    );
  }
  canvas.drawLine(
    Offset.zero,
    Offset(span, 0),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors:
            style == PlatformStyle.sovereign || style == PlatformStyle.carbon
            ? [
                const Color(0xFF28333F),
                const Color(0xFF53636D),
                const Color(0xFF101F29),
              ]
            : [
                Color.lerp(tint, Colors.white, .6)!,
                tint,
                Color.lerp(tint, const Color(0xFF254A53), .35)!,
              ],
      ).createShader(Rect.fromLTWH(0, -3, span, 6))
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round,
  );
  if (style.energized) {
    canvas.drawLine(
      Offset.zero,
      Offset(span, 0),
      Paint()
        ..color = tint.withAlpha(45)
        ..strokeWidth = 13,
    );
    final sparks = Path();
    for (var i = 0; i < 6; i++) {
      final phase = reducedMotion ? i / 6 : (time * .18 + i / 6) % 1;
      final x = phase * span;
      sparks.addOval(
        Rect.fromCircle(
          center: Offset(x, -4 - 4 * math.sin(phase * math.pi)),
          radius: 1.2,
        ),
      );
    }
    canvas.drawPath(
      sparks,
      Paint()..color = tint.withAlpha(reducedMotion ? 70 : 155),
    );
  }
  canvas.drawLine(
    const Offset(0, -1.6),
    Offset(span, -1.6),
    Paint()
      ..color = Colors.white.withAlpha(180)
      ..strokeWidth = .8,
  );
  for (var x = 12.0; x < span - 8; x += 22) {
    if (style == PlatformStyle.celestial || style == PlatformStyle.prism) {
      canvas.drawPath(
        Path()
          ..moveTo(x - 5, 0)
          ..lineTo(x, -2.5)
          ..lineTo(x + 5, 0)
          ..lineTo(x, 2.5)
          ..close(),
        Paint()..color = Colors.white.withAlpha(140),
      );
    }
    if (style == PlatformStyle.carbon) {
      canvas.drawLine(
        Offset(x - 3, -2),
        Offset(x + 3, 2),
        Paint()
          ..color = Colors.white.withAlpha(95)
          ..strokeWidth = 1,
      );
    }
    if (style == PlatformStyle.copper || style == PlatformStyle.sovereign) {
      canvas.drawCircle(
        Offset(x, .3),
        1.2,
        Paint()..color = const Color(0xFF785442),
      );
    } else {
      canvas.drawLine(
        Offset(x - 2, 2),
        Offset(x + 2, -2),
        Paint()
          ..color = style == PlatformStyle.prism
              ? const Color(0xFF8FFFE0)
              : const Color(0xFF2E6862)
          ..strokeWidth = 1.2,
      );
    }
  }
  canvas.restore();
}

class PlatformPreview extends CustomPainter {
  PlatformPreview(this.style, {this.animation}) : super(repaint: animation);
  final PlatformStyle style;
  final AnimationController? animation;
  @override
  void paint(Canvas canvas, Size size) {
    final a = Offset(3, size.height * .6),
        b = Offset(size.width - 3, size.height * .4);
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0xFF244A46)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = Color(style.color)
        ..strokeWidth = 5,
    );
    paintPlatformDetail(
      canvas,
      a,
      b,
      style,
      time: (animation?.value ?? 0) * 16.6666667,
      reducedMotion: animation == null || !animation!.isAnimating,
    );
  }

  @override
  bool shouldRepaint(PlatformPreview old) => old.style != style;
}
