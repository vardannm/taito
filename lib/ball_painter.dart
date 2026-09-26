import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ball_cosmetics.dart';

void paintCosmetic(
  Canvas canvas,
  Offset center,
  double radius,
  BallCosmetic ball, {
  double time = 0,
  bool reducedMotion = false,
  List<Color>? steelPalette,
}) {
  final tint = Color(ball.color);
  if (ball.glowing) {
    canvas.drawCircle(
      center,
      radius * 1.9,
      Paint()
        ..shader = RadialGradient(
          colors: [tint.withAlpha(100), tint.withAlpha(0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.9)),
    );
  }
  final shape = Path();
  if (ball.sides == 0) {
    shape.addOval(Rect.fromCircle(center: center, radius: radius));
  } else {
    for (var i = 0; i < ball.sides; i++) {
      final a = i * math.pi * 2 / ball.sides - math.pi / 2;
      final p = center + Offset(math.cos(a), math.sin(a)) * radius;
      if (i == 0) {
        shape.moveTo(p.dx, p.dy);
      } else {
        shape.lineTo(p.dx, p.dy);
      }
    }
    shape.close();
  }
  canvas.drawPath(
    shape,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.4, -.5),
        radius: .95,
        colors: ball == BallCosmetic.steel && steelPalette != null
            ? steelPalette
            : [
                Colors.white,
                tint,
                Color.lerp(tint, const Color(0xFF182B37), .8)!,
              ],
      ).createShader(Rect.fromCircle(center: center, radius: radius)),
  );
  canvas.drawPath(
    shape,
    Paint()
      ..color = const Color(0xFF233F43)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius / 10,
  );
  if (ball == BallCosmetic.circuit) {
    canvas.save();
    canvas.clipPath(shape);
    for (final x in [-.6, -.1, .4]) {
      canvas.drawLine(
        center + Offset(x * radius, -radius),
        center + Offset((x + .45) * radius, radius),
        Paint()
          ..color = const Color(0xFF225D59)
          ..strokeWidth = radius / 5,
      );
    }
    canvas.restore();
  }
  if (ball.index >= BallCosmetic.aurora.index) {
    canvas.save();
    canvas.clipPath(shape);
    final phase = reducedMotion ? .5 : time * .65;
    if (ball == BallCosmetic.eclipse) {
      canvas.drawCircle(
        center + Offset(radius * .22, 0),
        radius * .76,
        Paint()..color = const Color(0xFF242B45),
      );
    } else if (ball == BallCosmetic.nebula) {
      for (var i = 0; i < 7; i++) {
        final angle = i * 2.4 + phase;
        canvas.drawCircle(
          center +
              Offset(math.cos(angle), math.sin(angle)) *
                  radius *
                  (.25 + .08 * i),
          radius * .075,
          Paint()..color = Colors.white,
        );
      }
    } else {
      for (var i = 0; i < 3; i++) {
        canvas.drawArc(
          Rect.fromCircle(
            center: center + Offset(math.sin(phase + i) * radius * .25, 0),
            radius: radius * (.35 + i * .22),
          ),
          phase + i,
          math.pi * 1.3,
          false,
          Paint()
            ..color =
                (ball == BallCosmetic.nova
                        ? const Color(0xFFFFF2B3)
                        : const Color(0xFFE0FFF8))
                    .withAlpha(180)
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * .11,
        );
      }
    }
    canvas.restore();
  }
  if (ball == BallCosmetic.reactor || ball == BallCosmetic.obsidian) {
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + (reducedMotion ? 0 : time * .8);
      final p = center + Offset(math.cos(a), math.sin(a)) * radius * .6;
      canvas.drawLine(
        center,
        p,
        Paint()
          ..color = tint.withAlpha(160)
          ..strokeWidth = radius / 9,
      );
    }
    canvas.drawCircle(
      center,
      radius * .27,
      Paint()..color = const Color(0xFFF0FFFF),
    );
  }
}

class CosmeticPreview extends CustomPainter {
  const CosmeticPreview(this.ball);
  final BallCosmetic ball;
  @override
  void paint(Canvas canvas, Size size) => paintCosmetic(
    canvas,
    size.center(Offset.zero),
    math.min(size.width, size.height) * .28,
    ball,
    reducedMotion: true,
  );
  @override
  bool shouldRepaint(CosmeticPreview oldDelegate) => ball != oldDelegate.ball;
}
