import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game.dart';
import 'infinite_painter.dart';

void paintSpiderBackdrop(Canvas c, BalanceGame game) {
  if (game.spiders.isEmpty) return;
  final thread = Paint()
    ..color = const Color(0xFF193C38).withAlpha(32)
    ..style = PaintingStyle.stroke
    ..strokeWidth = .7;
  for (final (corner, rotation)
      in game.spiderLevel
          ? [
              (const Offset(18, 18), 0.0),
              (const Offset(342, 542), math.pi),
              (const Offset(342, 18), math.pi / 2),
            ]
          : <(Offset, double)>[]) {
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
    final radius = s.zoneRadius;
    final center = Offset(s.zoneX, game.screenY(s.zoneY));
    final webInk = game.infinite ? infiniteBoardInk(game, center) : null;
    thread.color =
        webInk?.withAlpha(180) ?? const Color(0xFF193C38).withAlpha(32);
    final color = s.chasing
        ? (webInk == null
              ? const Color(0xFFEF6654)
              : webInk == Colors.white
              ? const Color(0xFFFFB5A3)
              : const Color(0xFFB72820))
        : webInk ?? const Color(0xFF725138);
    c.drawCircle(
      center,
      radius,
      Paint()..color = color.withAlpha(s.chasing ? 24 : 12),
    );
    final boundary = Paint()
      ..color = color.withAlpha(game.infinite ? 230 : 165)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var i = 0; i < 28; i++) {
      c.drawArc(
        Rect.fromCircle(center: center, radius: radius),
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
        center + Offset(math.cos(a), math.sin(a)) * radius,
        thread,
      );
    }
    c.drawCircle(center, radius * .45, thread);
    c.drawCircle(center, radius * .75, thread);
  }
}

void paintSpiders(Canvas c, BalanceGame game, bool reducedMotion) {
  for (final spider in game.spiders) {
    c.save();
    c.translate(spider.x, game.screenY(spider.y));
    c.rotate(spider.heading);
    c.scale(spider.bodyRadius / 6);
    final webInk = game.infinite
        ? infiniteBoardInk(game, Offset(spider.x, game.screenY(spider.y)))
        : null;
    final color = webInk == Colors.white
        ? (spider.chasing ? const Color(0xFFFFB5A3) : const Color(0xFFF5EFDC))
        : spider.chasing
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
      c.drawCircle(
        Offset(6, y),
        .85,
        Paint()
          ..color = webInk == Colors.white
              ? const Color(0xFF253C34)
              : const Color(0xFFEAD8A6),
      );
    }
    c.restore();
  }
}

/// A fixed aiming line precedes each slow, non-homing web projectile.
void paintSpiderWebShots(Canvas c, BalanceGame game, bool reducedMotion) {
  if (!game.infinite) return;
  for (final web in game.webShots) {
    if (web.expired) continue;
    final center = Offset(web.x, web.y);
    final tint = infiniteBoardInk(game, center);
    final paint = Paint()
      ..color = tint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    if (web.warning) {
      final target = Offset(web.targetX, web.targetY);
      final delta = target - center;
      for (var i = 0; i < 12; i++) {
        c.drawLine(
          center + delta * (i / 12),
          center + delta * ((i + .5) / 12),
          Paint()
            ..color = tint.withAlpha(120)
            ..strokeWidth = 1,
        );
      }
      c.drawCircle(
        target,
        10,
        Paint()
          ..color = tint.withAlpha(130)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      c.drawArc(
        Rect.fromCircle(center: center, radius: 14),
        -math.pi / 2,
        math.pi * 2 * web.age / web.warningSeconds,
        false,
        paint,
      );
    }
    final radius = web.warning ? 7.0 : 9.0;
    c.drawCircle(
      center,
      radius + 2,
      Paint()
        ..color = (tint == Colors.white ? Colors.black : Colors.white)
            .withAlpha(160),
    );
    c.drawCircle(center, radius, paint);
    c.drawCircle(center, radius * .45, paint);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + (reducedMotion ? 0 : web.age * .7);
      c.drawLine(
        center,
        center + Offset(math.cos(a), math.sin(a)) * radius,
        paint,
      );
    }
  }
}
