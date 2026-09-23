import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game.dart';
import 'hazards.dart';
import 'infinite_painter.dart';

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
    if (h.warning &&
        h.motion != HazardMotion.legacy &&
        h.motion != HazardMotion.stationary) {
      final path = Paint()
        ..color = _red.withAlpha(80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      if (h.motion == HazardMotion.circle || h.motion == HazardMotion.oval) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(h.originX, h.originY),
            width: h.radiusX * 2,
            height:
                (h.motion == HazardMotion.circle ? h.radiusX : h.radiusY) * 2,
          ),
          path,
        );
      } else {
        final delta = h.motion == HazardMotion.horizontal
            ? Offset(h.radiusX, 0)
            : Offset(0, h.radiusY);
        c.drawLine(
          Offset(h.originX, h.originY) - delta,
          Offset(h.originX, h.originY) + delta,
          path,
        );
      }
    }
    if (h.kind == HazardKind.laser) {
      final horizontal = h.orientation == LaserOrientation.horizontal;
      Offset point(double along) =>
          horizontal ? Offset(along, h.y) : Offset(h.x, along);
      final low = horizontal ? 24.0 : SpecialHazard.laserTop(game.visibleTop),
          high = horizontal ? 336.0 : 537.0;
      if (h.sweeping && h.warning) {
        c.drawLine(
          Offset(h.originX - 65, low + 15),
          Offset(h.originX + 65, low + 15),
          warning,
        );
      }
      if (h.warning) {
        c.drawRect(
          horizontal
              ? Rect.fromLTRB(24, h.y - 10, 336, h.y + 10)
              : Rect.fromLTRB(h.x - 10, low, h.x + 10, high),
          Paint()..color = _red.withAlpha(30),
        );
        for (var along = low + 6; along < high - 8; along += 16) {
          c.drawLine(point(along), point(along + 8), warning);
        }
        _caption(
          c,
          game,
          '${h.countdown.toStringAsFixed(1)}s',
          point(low + 29),
          _red,
        );
      } else if (h.active) {
        c.drawLine(
          point(low),
          point(high),
          Paint()
            ..color = _red.withAlpha(160)
            ..strokeWidth = 14
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        c.drawLine(
          point(low),
          point(high),
          Paint()
            ..color = _red
            ..strokeWidth = 6,
        );
        c.drawLine(
          point(low),
          point(high),
          Paint()
            ..color = _white
            ..strokeWidth = 2,
        );
      }
      for (final end in [low, high]) {
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: point(end),
              width: horizontal ? 12 : 22,
              height: horizontal ? 22 : 12,
            ),
            const Radius.circular(3),
          ),
          Paint()..color = const Color(0xFF163D3B),
        );
        c.drawCircle(point(end), 3, Paint()..color = _red);
      }
      continue;
    }
    if (h.warning) {
      c.drawCircle(p, 18, warning);
      c.drawCircle(p, 12, warning..strokeWidth = 1);
      for (final d in [-1.0, 1.0])
        c.drawLine(p + Offset(d * 21, 0), p + Offset(d * 27, 0), warning);
      _caption(c, game, h.countdown.toStringAsFixed(1), p, _red);
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
        game,
        'BREAK ${h.countdown.toStringAsFixed(1)}s',
        point(h.x) - const Offset(0, 24),
        _red,
      );
    } else if (h.active) {
      for (final p in [a, b]) c.drawCircle(p, 4, Paint()..color = _red);
      _caption(c, game, 'GAP', point(h.x) + const Offset(0, 23), _red);
    }
  }
}

void _caption(
  Canvas c,
  BalanceGame game,
  String value,
  Offset center,
  Color color,
) {
  final text = TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        color: game.infinite ? infiniteBoardInk(game, center) : color,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        fontFamily: 'monospace',
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  text.paint(c, center - Offset(text.width / 2, text.height / 2));
}
