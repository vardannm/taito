import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game.dart';
import 'infinite_painter.dart';

void paintSnakes(Canvas canvas, BalanceGame game, bool reducedMotion) {
  if (!game.infinite) return;
  const palettes = [
    (Color(0xFF164D3B), Color(0xFF66B77A), Color(0xFFF0D38C)),
    (Color(0xFF285269), Color(0xFF68B9B7), Color(0xFFFFDEA0)),
    (Color(0xFF743E25), Color(0xFFD39654), Color(0xFFFFE7AB)),
  ];
  for (final snake in game.snakes) {
    final (dark, scales, gold) = palettes[snake.variant % palettes.length];
    final points = snake.points
        .map((p) => Offset(p.x, game.screenY(p.y)))
        .toList();
    final head = points.first;
    final contrast = infiniteBoardInk(game, head);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // Continuous, tapered layers give the body volume without a sprite seam.
    for (var layer = 0; layer < 3; layer++) {
      for (var i = points.length - 2; i >= 0; i--) {
        final r = snake.radiusAt(i);
        final offset = layer == 0 ? const Offset(1.2, 2) : Offset.zero;
        stroke
          ..color = layer == 0
              ? Colors.black.withAlpha(75)
              : layer == 1
              ? dark
              : scales
          ..strokeWidth =
              2 * r +
              (layer == 0
                  ? 4
                  : layer == 1
                  ? 1.5
                  : -2);
        canvas.drawLine(points[i] + offset, points[i + 1] + offset, stroke);
      }
    }
    // Alternating gold-edged dorsal diamonds follow each bend in the spine.
    for (var i = points.length - 4; i >= 3; i -= 3) {
      final p = points[i];
      final tangent = points[i - 1] - points[i + 1];
      final direction = tangent / tangent.distance;
      final normal = Offset(-direction.dy, direction.dx);
      final r = snake.radiusAt(i);
      final diamond = Path()
        ..moveTo((p + direction * 5).dx, (p + direction * 5).dy)
        ..lineTo((p + normal * r * .72).dx, (p + normal * r * .72).dy)
        ..lineTo((p - direction * 5).dx, (p - direction * 5).dy)
        ..lineTo((p - normal * r * .72).dx, (p - normal * r * .72).dy)
        ..close();
      canvas.drawPath(diamond, Paint()..color = dark);
      canvas.drawPath(
        diamond,
        Paint()
          ..color = gold.withAlpha(195)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .75,
      );
      canvas.drawCircle(p - normal * r * .8, .8, Paint()..color = gold);
    }
    final heading = math.atan2(head.dy - points[1].dy, head.dx - points[1].dx);
    canvas.save();
    canvas.translate(head.dx, head.dy);
    canvas.rotate(heading);
    // A brief forked tongue flick is cosmetic; slithering remains physical.
    if (!reducedMotion && snake.age % 2.3 < .32) {
      final tongue = Paint()
        ..color = const Color(0xFFDE625A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
        Path()
          ..moveTo(8, 0)
          ..lineTo(16, 0)
          ..moveTo(16, 0)
          ..lineTo(20, -2.5)
          ..moveTo(16, 0)
          ..lineTo(20, 2.5),
        tongue,
      );
    }
    final headShape = Path()
      ..moveTo(11, 0)
      ..cubicTo(11, -5, 3, -9, -5, -8)
      ..quadraticBezierTo(-11, 0, -5, 8)
      ..cubicTo(3, 9, 11, 5, 11, 0)
      ..close();
    canvas.drawPath(
      headShape,
      Paint()
        ..color = contrast.withAlpha(180)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawPath(
      headShape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scales, dark],
        ).createShader(const Rect.fromLTWH(-10, -9, 22, 18)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-5, -2)
        ..quadraticBezierTo(2, -4, 7, -1),
      Paint()
        ..color = gold.withAlpha(155)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(3.5, side * 5.3),
          width: 4.5,
          height: 3.5,
        ),
        Paint()..color = gold,
      );
      canvas.drawLine(
        Offset(3.7, side * 5.3 - 1.2),
        Offset(3.7, side * 5.3 + 1.2),
        Paint()
          ..color = const Color(0xFF15251E)
          ..strokeWidth = 1.2,
      );
      canvas.drawCircle(
        Offset(7.5, side * 2),
        .6,
        Paint()..color = gold.withAlpha(150),
      );
    }
    canvas.restore();
  }
}
