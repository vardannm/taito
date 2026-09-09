import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game.dart';
import 'hazards.dart';

const _red = Color(0xFFE34336), _white = Color(0xFFFFF1D6);

void paintSpecialHazards(Canvas c, BalanceGame game, bool reducedMotion) {
  for (final h in game.specialHazards) {
    final alpha = reducedMotion
        ? 230
        : (160 + 80 * math.sin(h.age * math.pi * 4)).round();
    final warning = Paint()
      ..color = _red.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final p = Offset(h.x, h.y);
    if (h.kind == HazardKind.platformGap) continue;
    if (h.zigzag && h.warning) {
      final path = Path()..moveTo(h.x, h.y);
      for (var i = 1; i <= 4; i++) {
        path.lineTo(180 + (i.isOdd ? 125 : -125), h.y + i * 70);
      }
      c.drawPath(
        path,
        Paint()
          ..color = _red.withAlpha(65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (h.kind == HazardKind.laser) {
      if (h.sweeping) {
        c.drawLine(
          Offset(h.originX - 65, 48),
          Offset(h.originX + 65, 48),
          warning,
        );
        for (final direction in [-1.0, 1.0]) {
          final tip = Offset(h.originX + direction * 65, 48);
          c.drawLine(tip, tip + Offset(-direction * 6, -5), warning);
          c.drawLine(tip, tip + Offset(-direction * 6, 5), warning);
        }
      }
      if (h.warning) {
        c.drawRect(
          Rect.fromLTRB(h.x - 10, 35, h.x + 10, 535),
          Paint()..color = _red.withAlpha(30),
        );
        for (double y = 40; y < 530; y += 16) {
          c.drawLine(Offset(h.x, y), Offset(h.x, y + 8), warning);
        }
        _caption(
          c,
          '${h.countdown.toStringAsFixed(1)}s',
          Offset(h.x, 62),
          _red,
        );
      } else if (h.active) {
        c.drawLine(
          Offset(h.x, 40),
          Offset(h.x, 530),
          Paint()
            ..color = _red.withAlpha(160)
            ..strokeWidth = 14
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        c.drawLine(
          Offset(h.x, 40),
          Offset(h.x, 530),
          Paint()
            ..color = _red
            ..strokeWidth = 6,
        );
        c.drawLine(
          Offset(h.x, 40),
          Offset(h.x, 530),
          Paint()
            ..color = _white
            ..strokeWidth = 2,
        );
      }
      for (final y in [34.0, 536.0]) {
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(h.x, y), width: 22, height: 12),
            const Radius.circular(3),
          ),
          Paint()..color = const Color(0xFF163D3B),
        );
        c.drawCircle(Offset(h.x, y), 3, Paint()..color = _red);
      }
      continue;
    }
    if (h.warning) {
      c.drawCircle(p, 18, warning);
      c.drawCircle(p, 12, warning..strokeWidth = 1);
      for (final d in [-1.0, 1.0])
        c.drawLine(p + Offset(d * 21, 0), p + Offset(d * 27, 0), warning);
      _caption(c, h.countdown.toStringAsFixed(1), p, _red);
    } else if (h.active) {
      c.drawCircle(p + const Offset(0, 1), 14, Paint()..color = _white);
      c.drawCircle(p, 12, Paint()..color = const Color(0xFF081F22));
      c.drawCircle(
        p,
        13,
        Paint()
          ..color = h.kind == HazardKind.movingHole
              ? const Color(0xFF2ACAC6)
              : _red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (h.kind == HazardKind.movingHole) {
      for (final d in [-1.0, 1.0]) {
        final tip = p + Offset(d * 29, 0);
        c.drawLine(tip, tip + Offset(-d * 5, -5), warning);
        c.drawLine(tip, tip + Offset(-d * 5, 5), warning);
      }
    }
  }
}

void paintGapWarning(Canvas c, BalanceGame game, bool reducedMotion) {
  for (final h in game.specialHazards.where(
    (h) => h.kind == HazardKind.platformGap,
  )) {
    Offset point(double x) => Offset(
      x,
      game.screenY(game.left + (game.right - game.left) * (x - 20) / 320),
    );
    final a = point(h.gapLeft), b = point(h.gapRight);
    final opacity = reducedMotion
        ? 230
        : (160 + 80 * math.sin(h.age * math.pi * 4)).round();
    if (h.warning) {
      c.drawLine(
        a,
        b,
        Paint()
          ..color = _red.withAlpha(opacity)
          ..strokeWidth = 13,
      );
      for (var i = 0; i < 6; i++) {
        final p = Offset.lerp(a, b, i / 5)!;
        c.drawLine(
          p + const Offset(-3, 5),
          p + const Offset(3, -5),
          Paint()
            ..color = _white
            ..strokeWidth = 2,
        );
      }
      _caption(
        c,
        'BREAK ${h.countdown.toStringAsFixed(1)}s',
        point(h.x) - const Offset(0, 24),
        _red,
      );
    } else if (h.active) {
      for (final p in [a, b]) c.drawCircle(p, 4, Paint()..color = _red);
      _caption(c, 'GAP', point(h.x) + const Offset(0, 23), _red);
    }
  }
}

void _caption(Canvas c, String value, Offset center, Color color) {
  final text = TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        fontFamily: 'monospace',
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  text.paint(c, center - Offset(text.width / 2, text.height / 2));
}
