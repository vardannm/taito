import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game.dart';
import 'infinite_progress.dart';

const _comboColors = [
  Color(0xFFF2ECDD),
  Color(0xFFA9DAC2),
  Color(0xFF95D2E8),
  Color(0xFFC5B0E6),
  Color(0xFFFFBD98),
];
Color comboColor(double power, {bool background = false}) {
  final position = power.clamp(0.0, 1.0) * 4;
  final index = position.floor().clamp(0, 3);
  final color = Color.lerp(
    _comboColors[index],
    _comboColors[index + 1],
    position - index,
  )!;
  return background ? Color.lerp(color, const Color(0xFFF7F3E8), .3)! : color;
}

/// Paints behind the entire game, including HUD, controls and screen margins.
class InfiniteBackdropPainter extends CustomPainter {
  InfiniteBackdropPainter(
    this.game, {
    required this.reducedMotion,
    Listenable? repaint,
  }) : super(repaint: repaint);
  final BalanceGame game;
  final bool reducedMotion;
  @override
  void paint(Canvas c, Size size) {
    final power = game.survival.visualCombo;
    final color = comboColor(power, background: true);
    c.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, comboColor(power), .65)!],
        ).createShader(Offset.zero & size),
    );
    if (power > .01 && !reducedMotion) {
      final drift = math.sin(game.clock * .4) * size.width * .15;
      c.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .7 + drift, size.height * .18),
          width: size.width * 1.8,
          height: size.height * .7,
        ),
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white.withAlpha(45), Colors.white.withAlpha(0)],
          ).createShader(Offset.zero & size),
      );
    }
  }

  @override
  bool shouldRepaint(InfiniteBackdropPainter old) =>
      old.game != game || old.reducedMotion != reducedMotion;
}

void paintInfiniteAtmosphere(Canvas c, BalanceGame game, bool reducedMotion) {
  if (!game.infinite) return;
  final power = (game.survival.visualCombo * InfiniteTuning.visualIntensity)
      .clamp(0.0, 1.0);
  if (power < .005) return;
  final tint = comboColor(power);
  const area = Rect.fromLTWH(10, 10, 340, 540);
  // Opaque color transforms the whole playfield; the start fades in smoothly.
  c.drawRect(
    area,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors:
            [
                  Color.lerp(tint, Colors.white, .3)!,
                  tint,
                  Color.lerp(tint, const Color(0xFF77BBB5), .2)!,
                ]
                .map(
                  (color) =>
                      color.withValues(alpha: (power * 4).clamp(0.0, 1.0)),
                )
                .toList(),
      ).createShader(area),
  );
  if (reducedMotion) return;
  for (var band = 0; band < 3; band++) {
    final drift = math.sin(game.clock * .45 + band * 2) * 45;
    final y = 80.0 + band * 160;
    final path = Path()
      ..moveTo(10, y + drift)
      ..cubicTo(115, y - 95, 210, y + 80, 350, y - 35 + drift)
      ..lineTo(350, y + 30 + drift)
      ..cubicTo(210, y + 120, 115, y - 50, 10, y + 65 + drift)
      ..close();
    c.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: .08 + .05 * power),
    );
  }
  for (var i = 0; i < (InfiniteTuning.maxParticles * power).ceil(); i++) {
    final x = 28.0 + (i * 83 % 304),
        y = 16 + (i * 137 + game.clock * (25 + 75 * power)) % 520;
    c.drawLine(
      Offset(x, y),
      Offset(x, y - 3 - 18 * power),
      Paint()
        ..color = Colors.white.withValues(alpha: .18 + .18 * power)
        ..strokeWidth = 1 + power,
    );
  }
}

void paintInfiniteItems(Canvas c, BalanceGame game, bool reducedMotion) {
  if (!game.infinite) return;
  for (final item in game.survival.items) {
    final p = Offset(item.x, game.screenY(item.y));
    if (p.dy < 0 || p.dy > 560) continue;
    final tint = switch (item.kind) {
      InfiniteItemKind.combo => const Color(0xFFBD7920),
      InfiniteItemKind.shield => const Color(0xFF21778C),
      InfiniteItemKind.heart => const Color(0xFFC6454E),
    };
    c.drawCircle(p, 12, Paint()..color = const Color(0xFFF9F4E4));
    c.drawCircle(
      p,
      12,
      Paint()
        ..color = tint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    final shape = Path();
    if (item.kind == InfiniteItemKind.combo) {
      shape.moveTo(p.dx, p.dy - 8);
      shape.lineTo(p.dx + 6, p.dy);
      shape.lineTo(p.dx, p.dy + 8);
      shape.lineTo(p.dx - 6, p.dy);
      shape.close();
    } else if (item.kind == InfiniteItemKind.shield) {
      shape.moveTo(p.dx - 6, p.dy - 7);
      shape.lineTo(p.dx + 6, p.dy - 7);
      shape.lineTo(p.dx + 5, p.dy + 3);
      shape.lineTo(p.dx, p.dy + 8);
      shape.lineTo(p.dx - 5, p.dy + 3);
      shape.close();
    } else {
      shape.moveTo(p.dx, p.dy + 7);
      shape.cubicTo(p.dx - 15, p.dy - 2, p.dx - 7, p.dy - 13, p.dx, p.dy - 5);
      shape.cubicTo(p.dx + 7, p.dy - 13, p.dx + 15, p.dy - 2, p.dx, p.dy + 7);
    }
    c.drawPath(shape, Paint()..color = tint);
  }
}

void paintInfiniteEnergy(Canvas c, BalanceGame game, bool reducedMotion) {
  if (!game.infinite || game.survival.combo < 5) return;
  final a = Offset(20, game.screenY(game.left)),
      b = Offset(340, game.screenY(game.right));
  final span = (b - a).distance;
  c.save();
  c.translate(a.dx, a.dy);
  c.rotate(math.atan2(b.dy - a.dy, b.dx - a.dx));
  c.drawRect(
    Rect.fromLTWH(0, -13, span, 15),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00FF773F), Color(0xBBFFB550)],
      ).createShader(Rect.fromLTWH(0, -13, span, 15)),
  );
  if (!reducedMotion) {
    // Broad, curling outer flames with independent warm cores and rising embers.
    // All particles are derived from time; nothing accumulates between frames.
    for (var i = 0; i < 20; i++) {
      final phase = game.clock * 5.2 + i * 2.37;
      final x = 8 + i * (span - 16) / 19;
      final h = 13 + 8 * math.sin(phase) + 6 * math.sin(phase * .71 + i);
      final curl = 5 * math.sin(phase * .8);
      for (var layer = 0; layer < 2; layer++) {
        final height = layer == 0 ? h : h * .6, width = layer == 0 ? 9.0 : 4.5;
        final flame = Path()
          ..moveTo(x - width, 1)
          ..cubicTo(
            x - width - 3,
            -height * .38,
            x + curl - width,
            -height * .8,
            x + curl,
            -height - 5,
          )
          ..cubicTo(
            x + curl + 2,
            -height * .55,
            x + width + 3,
            -height * .35,
            x + width,
            1,
          )
          ..close();
        c.drawPath(
          flame,
          Paint()
            ..shader =
                LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: layer == 0
                      ? [const Color(0xAAED593A), const Color(0xEEFFA538)]
                      : [const Color(0xCCFFE8A8), const Color(0xFFFFF5CC)],
                ).createShader(
                  Rect.fromLTWH(x - width, -height - 5, width * 2, height + 6),
                ),
        );
      }
      if (i.isEven) {
        final life = (game.clock * .8 + i * .173) % 1;
        c.drawCircle(
          Offset(x + math.sin(i + life * 3) * 7, -7 - life * 37),
          1.3 * (1 - life),
          Paint()
            ..color = const Color(
              0xFFFFE5A2,
            ).withValues(alpha: (1 - life) * .9),
        );
      }
    }
  }
  c.drawLine(
    const Offset(0, -2),
    Offset(span, -2),
    Paint()
      ..color = const Color(0xFFFFE8A2)
      ..strokeWidth = 2.5,
  );
  c.restore();
}

void paintInfiniteShield(Canvas c, BalanceGame game, bool reducedMotion) {
  if (!game.infinite || !game.survival.protected || game.ballScale <= 0) return;
  final p = Offset(game.visualX, game.screenY(game.visualY));
  final shield = game.survival.shield > 0;
  final tint = shield ? const Color(0xFF16899D) : const Color(0xFF618A4C);
  final pulse = reducedMotion
      ? 0.0
      : math.sin(game.clock * (game.survival.shield < 3 ? 10 : 5));
  c.drawCircle(p, 13 + pulse, Paint()..color = tint.withAlpha(35));
  c.drawCircle(
    p,
    13 + pulse,
    Paint()
      ..color = tint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8,
  );
  if (shield)
    c.drawArc(
      Rect.fromCircle(center: p, radius: 16),
      -math.pi / 2,
      math.pi * 2 * game.survival.shield / InfiniteTuning.shieldSeconds,
      false,
      Paint()
        ..color = tint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
}
