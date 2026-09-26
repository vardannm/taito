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
  final streakPaint = Paint()
    ..color = Colors.white.withValues(alpha: .18 + .18 * power)
    ..strokeWidth = 1 + power;
  for (var i = 0; i < (12 * power).ceil(); i++) {
    final x = 28.0 + (i * 83 % 304),
        y = 16 + (i * 137 + game.clock * (25 + 75 * power)) % 520;
    c.drawLine(Offset(x, y), Offset(x, y - 3 - 18 * power), streakPaint);
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

/// Bounded, blur-free energy: gradients and shared paths avoid a separate
/// blur render pass for every spark/arc. Cost does not grow with pace/combo.
void paintInfiniteEnergy(Canvas c, BalanceGame game, bool reducedMotion) {
  if (!game.infinite || game.survival.combo < 5) return;
  final a = Offset(20, game.screenY(game.left));
  final b = Offset(340, game.screenY(game.right));
  if (math.max(a.dy, b.dy) < -40 || math.min(a.dy, b.dy) > 610) return;
  final direction = b - a, span = direction.distance;
  if (span <= 0) return;
  final time = game.clock;
  const gold = Color(0xFFFFC247), amber = Color(0xFFFF8A32);
  final pulse = reducedMotion ? 1.0 : .85 + math.sin(time * 5) * .1;
  c.save();
  c.translate(a.dx, a.dy);
  c.rotate(math.atan2(direction.dy, direction.dx));

  // A single soft gradient supplies the aura without a Gaussian blur.
  final aura = Rect.fromLTWH(-8, -26, span + 16, 46);
  c.drawRect(
    aura,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          gold.withAlpha(0),
          gold.withValues(alpha: .23 * pulse),
          amber.withValues(alpha: .12 * pulse),
          amber.withAlpha(0),
        ],
        stops: const [0, .55, .72, 1],
      ).createShader(aura),
  );
  if (!reducedMotion) {
    final arcs = Path();
    for (var arc = 0; arc < 3; arc++) {
      arcs.moveTo(0, 0);
      for (var i = 1; i < 12; i++) {
        final t = i / 12;
        final wave = math.sin(
          t * math.pi * (3 + arc % 3) + time * 5.5 + arc * 2.1,
        );
        arcs.lineTo(
          t * span,
          -5 - arc * 1.5 - math.sin(t * math.pi) * wave * 6,
        );
      }
      arcs.lineTo(span, 0);
    }
    c.drawPath(
      arcs,
      Paint()
        ..color = amber.withAlpha(40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawPath(
      arcs,
      Paint()
        ..color = const Color(0xBBFFF0B5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    final sparkPaint = Paint();
    for (var i = 0; i < 8; i++) {
      final life = (time * .65 + i * .117) % 1;
      final x =
          (i * 71 % (span - 10)) + 5 + math.sin(i * 2.71 + time * 4) * 3 * life;
      sparkPaint.color = const Color(
        0xFFFFF0B5,
      ).withValues(alpha: (1 - life) * .65);
      c.drawCircle(
        Offset(x, -5 - life * 26),
        1.8 * (1 - life * .5),
        sparkPaint,
      );
    }
    final surgePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xEEFFF9DD), Color(0x77FFC247), Color(0x00FFC247)],
      ).createShader(const Rect.fromLTWH(-9, -9, 18, 18));
    for (var i = 0; i < 2; i++) {
      c.save();
      c.translate(((time * .65 + i / 2) % 1) * span, 0);
      c.drawCircle(Offset.zero, 9, surgePaint);
      c.restore();
    }
  }
  c.drawLine(
    Offset.zero,
    Offset(span, 0),
    Paint()
      ..color = gold.withValues(alpha: .45 * pulse)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round,
  );
  c.drawLine(
    Offset.zero,
    Offset(span, 0),
    Paint()
      ..color = const Color(0xFFFFF0B5)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round,
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
