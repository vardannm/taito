import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game.dart';

void paintSpiderBackdrop(Canvas c, BalanceGame game) {
  if (!game.spiderLevel) return;
  final thread = Paint()
    ..color = const Color(0xFF193C38).withAlpha(32)
    ..style = PaintingStyle.stroke
    ..strokeWidth = .7;
  for (final (corner, rotation) in [
    (const Offset(18, 18), 0.0),
    (const Offset(342, 542), math.pi),
    (const Offset(342, 18), math.pi / 2),
  ]) {
    c.save();
    c.translate(corner.dx, corner.dy);
    c.rotate(rotation);
    for (var spoke = 0; spoke <= 7; spoke++) {
      final a = spoke * math.pi / 14;
      c.drawLine(
        Offset.zero,
        Offset(math.cos(a) * 150, math.sin(a) * 150),
        thread,
      );
    }
    for (var radius = 26.0; radius <= 150; radius += 24) {
      final web = Path()..moveTo(radius, 0);
      for (var spoke = 1; spoke <= 7; spoke++) {
        final a = spoke * math.pi / 14, mid = a - math.pi / 28;
        web.quadraticBezierTo(
          math.cos(mid) * radius * .9,
          math.sin(mid) * radius * .9,
          math.cos(a) * radius,
          math.sin(a) * radius,
        );
      }
      c.drawPath(web, thread);
    }
    c.restore();
  }
  for (final s in game.spiders) {
    final center = Offset(s.homeX, s.homeY),
        color = s.chasing ? const Color(0xFFBA392E) : const Color(0xFF725138);
    c.drawCircle(
      center,
      s.zoneRadius,
      Paint()..color = color.withAlpha(s.chasing ? 24 : 12),
    );
    final boundary = Paint()
      ..color = color.withAlpha(165)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var i = 0; i < 28; i++) {
      c.drawArc(
        Rect.fromCircle(center: center, radius: s.zoneRadius),
        i * math.pi * 2 / 28,
        .13,
        false,
        boundary,
      );
    }
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawLine(
        center,
        center + Offset(math.cos(a), math.sin(a)) * s.zoneRadius,
        thread,
      );
    }
    c.drawCircle(center, s.zoneRadius * .45, thread);
    c.drawCircle(center, s.zoneRadius * .75, thread);
  }
}

void paintSpiders(Canvas c, BalanceGame game, bool reducedMotion) {
  for (final spider in game.spiders) {
    c.save();
    c.translate(spider.x, spider.y);
    c.rotate(spider.heading);
    c.scale(spider.bodyRadius / 6);
    final color = spider.chasing
        ? const Color(0xFF80251F)
        : const Color(0xFF253C34);
    final legs = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final sign in [-1.0, 1.0]) {
      for (var i = 0; i < 4; i++) {
        final x = -6.0 + i * 3.8;
        final walk = reducedMotion
            ? 0.0
            : math.sin(spider.time * 7 + i * 1.7 + sign) * 1.4;
        c.drawPath(
          Path()
            ..moveTo(x, sign * 3)
            ..lineTo(x - 3 + walk, sign * (8 + i % 2))
            ..lineTo(x + 1 + walk, sign * (12 + i % 2)),
          legs,
        );
      }
    }
    c.drawOval(const Rect.fromLTWH(-9, -5, 12, 10), Paint()..color = color);
    c.drawCircle(const Offset(4, 0), 4, Paint()..color = color);
    for (final y in [-1.5, 1.5]) {
      c.drawCircle(Offset(6, y), .85, Paint()..color = const Color(0xFFEAD8A6));
    }
    c.restore();
  }
}
