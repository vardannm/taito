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
  if (ball.index >= BallCosmetic.aurora.index &&
      ball.index <= BallCosmetic.eclipse.index) {
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
  if (ball.index >= BallCosmetic.pearl.index) {
    final phase = reducedMotion ? 0.0 : time * .7;
    canvas.save();
    canvas.clipPath(shape);
    if (ball == BallCosmetic.singularity) {
      canvas.drawCircle(
        center,
        radius * .8,
        Paint()..color = const Color(0xFF161627),
      );
    } else if (ball == BallCosmetic.opal) {
      const flecks = [
        Color(0xFFAAF4D9),
        Color(0xFFFFD399),
        Color(0xFFCDA8FF),
        Color(0xFF8BD7FF),
      ];
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4 + phase * .2;
        final p = center + Offset(math.cos(a), math.sin(a)) * radius * .55;
        canvas.drawPath(
          Path()
            ..moveTo(center.dx, center.dy)
            ..lineTo(p.dx + radius * .4, p.dy - radius * .25)
            ..lineTo(p.dx, p.dy + radius * .3)
            ..close(),
          Paint()..color = flecks[i % 4].withAlpha(150),
        );
      }
    } else {
      for (var i = 0; i < 4; i++) {
        final paint = Paint()
          ..color = Color.lerp(
            tint,
            i.isEven ? Colors.white : const Color(0xFF19324D),
            .6,
          )!.withAlpha(170)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * (ball == BallCosmetic.malachite ? .16 : .09);
        canvas.drawArc(
          Rect.fromCenter(
            center: center + Offset(radius * .3 * math.sin(phase), 0),
            width: radius * (1 + i * .35),
            height: radius * (.4 + i * .35),
          ),
          phase + i * .7,
          math.pi * 1.5,
          false,
          paint,
        );
      }
    }
    canvas.restore();
    if (ball.premium) {
      final orbit = Rect.fromCenter(
        center: center,
        width: radius * 2.7,
        height: radius * 1.3,
      );
      canvas.drawArc(
        orbit,
        phase,
        math.pi * 1.45,
        false,
        Paint()
          ..color = tint.withAlpha(160)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * .09,
      );
      if (!reducedMotion)
        for (var i = 0; i < 3; i++) {
          final a = phase * 2 + i * math.pi * 2 / 3;
          canvas.drawCircle(
            center + Offset(math.cos(a), math.sin(a)) * radius * 1.45,
            radius * .09,
            Paint()..color = tint.withAlpha(190),
          );
        }
    }
  }
}

void paintCosmeticTrail(
  Canvas canvas,
  Offset center,
  Offset motion,
  double radius,
  BallCosmetic ball,
) {
  if (!ball.premium || motion.distance < .1) return;
  final direction = motion / motion.distance;
  for (var i = 4; i > 0; i--) {
    canvas.drawCircle(
      center - direction * (i * radius * .85),
      radius * (.7 - i * .1),
      Paint()..color = Color(ball.color).withAlpha(65 - i * 11),
    );
  }
}

class CosmeticPreview extends CustomPainter {
  CosmeticPreview(this.ball, {this.animation}) : super(repaint: animation);
  final BallCosmetic ball;
  final AnimationController? animation;
  @override
  void paint(Canvas canvas, Size size) => paintCosmetic(
    canvas,
    size.center(Offset.zero),
    math.min(size.width, size.height) * .28,
    ball,
    time: (animation?.value ?? 0) * math.pi * 20,
    reducedMotion: animation == null || !animation!.isAnimating,
  );
  @override
  bool shouldRepaint(CosmeticPreview oldDelegate) =>
      ball != oldDelegate.ball || animation != oldDelegate.animation;
}
