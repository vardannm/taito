import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game.dart';
import 'infinite_painter.dart';
import 'infinite_progress.dart';

/// Pointed, striped quills distinguish the radial attack from round spider webs.
void paintPorcupines(Canvas canvas, BalanceGame game, bool reducedMotion) {
  if (!game.infinite) return;
  for (final p in game.porcupines) {
    final center = Offset(p.x, game.screenY(p.y));
    final ink = infiniteBoardInk(game, center);
    final charging = p.charge != null;
    final progress = ((p.charge ?? 0) / InfiniteTuning.quillWarningSeconds)
        .clamp(0.0, 1.0);
    final amber = ink == Colors.white
        ? const Color(0xFFFFD58A)
        : const Color(0xFF98400E);
    if (charging) {
      canvas.drawCircle(center, 30, Paint()..color = amber.withAlpha(25));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 29),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..color = amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      for (var i = 0; i < InfiniteTuning.quillCount; i++) {
        final a = p.burstAngle + i * math.pi * 2 / InfiniteTuning.quillCount;
        final direction = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
          center + direction * 34,
          center + direction * (42 + progress * 12),
          Paint()
            ..color = amber.withAlpha(180)
            ..strokeWidth = 1.2,
        );
      }
    }
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(p.heading);
    canvas.drawOval(
      const Rect.fromLTWH(-20, -16, 41, 34),
      Paint()
        ..color = (ink == Colors.white ? Colors.black : Colors.white).withAlpha(
          130,
        ),
    );
    final dark = Paint()..color = const Color(0xFF38291F);
    final fur = Paint()..color = const Color(0xFF886343);
    for (final side in [-1.0, 1.0]) {
      for (final x in [-7.0, 7.0]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, side * 10), width: 7, height: 5),
          dark,
        );
      }
    }
    canvas.drawOval(const Rect.fromLTWH(-14, -11, 27, 22), dark);
    // Two layers of long tapered back quills, leaving the face exposed.
    for (var layer = 0; layer < 2; layer++) {
      for (var i = 0; i < 13; i++) {
        final a = .65 + i * (math.pi * 2 - 1.3) / 12;
        final direction = Offset(math.cos(a), math.sin(a));
        final normal = Offset(-direction.dy, direction.dx);
        final base = direction * (layer == 0 ? 8.0 : 4.0);
        final tip =
            direction *
            ((layer == 0 ? 20.0 : 14.0) + (charging ? progress * 3 : 0));
        final shape = Path()
          ..moveTo((base + normal * 1.8).dx, (base + normal * 1.8).dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo((base - normal * 1.8).dx, (base - normal * 1.8).dy)
          ..close();
        canvas.drawPath(shape, dark);
        canvas.drawLine(
          base + (tip - base) * .45,
          tip,
          Paint()
            ..color = const Color(0xFFF5DBAB)
            ..strokeWidth = 1.2,
        );
      }
    }
    canvas.drawOval(const Rect.fromLTWH(4, -7, 15, 14), fur);
    canvas.drawOval(const Rect.fromLTWH(14, -4, 8, 8), fur);
    canvas.drawCircle(const Offset(21, 0), 2.3, dark);
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(Offset(8, side * 6), 2.7, dark);
      canvas.drawCircle(
        Offset(15, side * 3.4),
        1.4,
        Paint()..color = const Color(0xFFFFF3D8),
      );
      canvas.drawCircle(Offset(15.5, side * 3.4), .8, dark);
    }
    canvas.restore();
  }
  for (final q in game.quills) {
    if (q.expired) continue;
    final ink = infiniteBoardInk(game, Offset(q.x, game.screenY(q.y)));
    canvas.save();
    canvas.translate(q.x, game.screenY(q.y));
    canvas.rotate(q.angle);
    final shape = Path()
      ..moveTo(9, 0)
      ..lineTo(-6, -2)
      ..lineTo(-4, 0)
      ..lineTo(-6, 2)
      ..close();
    canvas.drawPath(
      shape,
      Paint()
        ..color = ink == Colors.white
            ? const Color(0xFF38291F)
            : const Color(0xFFFFF3D8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(shape, Paint()..color = ink);
    canvas.drawLine(
      const Offset(-3, 0),
      const Offset(2, 0),
      Paint()
        ..color = const Color(0xFFD99B4F)
        ..strokeWidth = 1.4,
    );
    canvas.restore();
  }
}
