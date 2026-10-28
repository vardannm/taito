import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game.dart';
import 'hazards.dart';
import 'infinite_painter.dart';
import 'arena_canvas.dart';

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
    if ((h.warning || (h.active && h.motion == HazardMotion.circle)) &&
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
          high = horizontal ? 336.0 : h.laserBottom;
      if (h.sweeping && h.warning) {
        c.drawLine(
          Offset(h.originX - 65, low + 15),
          Offset(h.originX + 65, low + 15),
          warning,
        );
      }
      // A dashed beam's warning already shows where its dashes and gaps are.
      final segments = h.laserSegments(low, high);
      if (h.warning) {
        for (final (a, b) in segments) {
          final rect = horizontal
              ? Rect.fromLTRB(a, h.y - 10, b, h.y + 10)
              : Rect.fromLTRB(h.x - 10, a, h.x + 10, b);
          c.drawRect(rect, Paint()..color = _red.withAlpha(30));
          if (h.dashed) {
            c.drawRRect(
              RRect.fromRectAndRadius(
                rect.deflate(6),
                const Radius.circular(4),
              ),
              Paint()
                ..color = _red.withAlpha(alpha)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
          }
        }
        if (!h.dashed) {
          for (var along = low + 6; along < high - 8; along += 16) {
            c.drawLine(point(along), point(along + 8), warning);
          }
        }
        _caption(
          c,
          game,
          '${h.laserWarningDirection == null ? 'FIXED' : 'MOVING'} ${h.countdown.toStringAsFixed(1)}s',
          point(low + 29),
          _red,
        );
        _paintLaserMotionCue(c, h, low, high, reducedMotion);
      } else if (h.active) {
        final cap = h.dashed ? StrokeCap.round : StrokeCap.butt;
        for (final (a, b) in segments) {
          c.drawLine(
            point(a),
            point(b),
            Paint()
              ..color = _red.withAlpha(160)
              ..strokeWidth = 14
              ..strokeCap = cap
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
          c.drawLine(
            point(a),
            point(b),
            Paint()
              ..color = _red
              ..strokeWidth = 6
              ..strokeCap = cap,
          );
          c.drawLine(
            point(a),
            point(b),
            Paint()
              ..color = _white
              ..strokeWidth = 2
              ..strokeCap = cap,
          );
        }
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
          ..color = _red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (h.kind == HazardKind.movingHole && h.motion == HazardMotion.circle) {
      // Tangent arrow communicates the circular direction, not a sideways sweep.
      final angle = math.atan2(h.y - h.originY, h.x - h.originX);
      final direction = Offset(-math.sin(angle), math.cos(angle));
      final normal = Offset(-direction.dy, direction.dx);
      final tip = p + direction * 23;
      c.drawLine(tip, tip - direction * 6 + normal * 4, warning);
      c.drawLine(tip, tip - direction * 6 - normal * 4, warning);
    } else if (h.kind == HazardKind.movingHole) {
      for (final d in [-1.0, 1.0]) {
        final tip = p + Offset(d * 29, 0);
        c.drawLine(tip, tip + Offset(-d * 5, -5), warning);
        c.drawLine(tip, tip + Offset(-d * 5, 5), warning);
      }
    }
  }
}

void _paintLaserMotionCue(
  Canvas c,
  SpecialHazard hazard,
  double low,
  double high,
  bool reducedMotion,
) {
  final direction = hazard.laserWarningDirection;
  if (direction == null) return;
  final stretch = c is ArenaCanvas ? c.stretch : 1.0;
  final angle = math.atan2(direction.y, direction.x * stretch);
  final alpha = reducedMotion || (hazard.age * 4).floor().isEven ? 255 : 70;
  final arrow = Paint()
    ..color = const Color(0xFFFFDA82).withAlpha(alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  for (final fraction in [.25, .5, .75]) {
    final along = low + (high - low) * fraction;
    final anchor = hazard.orientation == LaserOrientation.horizontal
        ? Offset(along, hazard.y - 23)
        : Offset(hazard.x + 23 / stretch, along);
    c.save();
    c.translate(anchor.dx, anchor.dy);
    c.rotate(angle);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-14, -10, 28, 20),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF10242B).withAlpha(215),
    );
    for (final x in [-5.0, 3.0]) {
      c.drawPath(
        Path()
          ..moveTo(x - 3, -4)
          ..lineTo(x + 1, 0)
          ..lineTo(x - 3, 4),
        arrow,
      );
    }
    c.restore();
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
  // Countdown captions change every frame; release each paragraph promptly.
  text.dispose();
}
