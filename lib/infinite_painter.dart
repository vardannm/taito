import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game.dart';
import 'infinite_progress.dart';
import 'maze_gates.dart';
import 'pickup_painter.dart';

const _comboColors = [
  Color(0xFFF2ECDD),
  Color(0xFFA9DAC2),
  Color(0xFF95D2E8),
  Color(0xFFC5B0E6),
  Color(0xFFFFBD98),
  // x6 turns the board dark violet, x7 goes darker still.
  Color(0xFF412A77),
  Color(0xFF16121E),
];

/// How far the board has gone dark: nothing through x5, full from x6 on.
double comboDarkness(double power) =>
    ((power.clamp(0.0, 1.0) - 4 / 6) * 6).clamp(0.0, 1.0);

Color comboColor(double power, {bool background = false}) {
  final steps = _comboColors.length - 1;
  final position = power.clamp(0.0, 1.0) * steps;
  final index = position.floor().clamp(0, steps - 1);
  final color = Color.lerp(
    _comboColors[index],
    _comboColors[index + 1],
    position - index,
  )!;
  // The pale wash keeps early tiers soft; it must not lift the dark tiers.
  return background
      ? Color.lerp(
          color,
          const Color(0xFFF7F3E8),
          .3 * (1 - comboDarkness(power)),
        )!
      : color;
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
  final darkness = comboDarkness(power);
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
      Paint()
        ..color = Colors.white.withValues(
          alpha: (.08 + .05 * power) * (1 - .55 * darkness),
        ),
    );
  }
  // The pale streaks hand their frame budget over to the embers as the board
  // darkens, so the dark tiers cost no more to draw than the bright ones.
  final streakPaint = Paint()
    ..color = Colors.white.withValues(alpha: .18 + .18 * power)
    ..strokeWidth = 1 + power;
  for (var i = 0; i < (12 * power * (1 - darkness)).ceil(); i++) {
    final x = 28.0 + (i * 83 % 304),
        y = 16 + (i * 137 + game.clock * (25 + 75 * power)) % 520;
    c.drawLine(Offset(x, y), Offset(x, y - 3 - 18 * power), streakPaint);
  }
  if (darkness > 0) paintComboEmbers(c, game.clock, darkness);
}

/// Embers that rise through the dark tiers. Positions come from the clock and
/// the index alone: no particle state to own, reset or leak between runs, and
/// every ember lands in one of four batched paths to keep the draw count flat.
void paintComboEmbers(Canvas c, double clock, double darkness) {
  const violet = Color(0xFFCBA8FF), spark = Color(0xFFFFE6B8);
  final count = (InfiniteTuning.maxParticles * darkness).round();
  final glow = Path(), cores = Path(), sparks = Path(), trails = Path();
  for (var i = 0; i < count; i++) {
    final speed = 34 + (i % 5) * 13.0;
    final life = (clock * speed + i * 137) % 600;
    final y = 570 - life;
    if (y < -10) continue;
    // Fade in off the bottom edge and out again near the top of the field.
    final fade =
        (life / 90).clamp(0.0, 1.0) * ((600 - life) / 200).clamp(0.0, 1.0);
    if (fade <= .02) continue;
    final sway = math.sin(clock * 1.7 + i * .8) * (5 + i % 4);
    final p = Offset((i * 97) % 320 + 22.0 + sway, y);
    final twinkle = .75 + .25 * math.sin(clock * 4 + i * 1.3);
    final radius = (1.3 + (i % 3) * .55) * twinkle * fade;
    glow.addOval(Rect.fromCircle(center: p, radius: radius * 3.4));
    (i % 4 == 0 ? sparks : cores).addOval(
      Rect.fromCircle(center: p, radius: radius),
    );
    trails.addRect(
      Rect.fromLTWH(p.dx - radius * .45, p.dy, radius * .9, radius * 4.5),
    );
  }
  final alpha = .55 * darkness;
  c.drawPath(glow, Paint()..color = violet.withValues(alpha: alpha * .28));
  c.drawPath(trails, Paint()..color = violet.withValues(alpha: alpha * .22));
  c.drawPath(cores, Paint()..color = violet.withValues(alpha: alpha));
  c.drawPath(sparks, Paint()..color = spark.withValues(alpha: alpha));
}

void paintInfiniteItems(Canvas c, BalanceGame game, bool reducedMotion) {
  if (!game.infinite) return;
  for (final item in game.survival.items) {
    final p = Offset(item.x, game.screenY(item.y));
    if (p.dy < -14 || p.dy > 574) continue;
    // Each pickup bobs on its own phase, so a row of them never pulses as one.
    final phase = item.x * .07;
    final bob = reducedMotion ? 0.0 : math.sin(game.clock * 2.2 + phase) * 1.4;
    paintPickup(
      c,
      Offset(p.dx, p.dy + bob),
      switch (item.kind) {
        InfiniteItemKind.combo => PickupFace.combo,
        InfiniteItemKind.shield => PickupFace.shield,
        InfiniteItemKind.heart => PickupFace.heart,
      },
      reducedMotion ? 0 : (game.clock * .55 + phase) % 1,
    );
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

/// Laser gates during an Infinite maze section: one batched path for every
/// beam, so a screenful of them costs the same handful of draws as one.
void paintMazeGates(Canvas c, BalanceGame game, bool reducedMotion) {
  if (game.mazeGates.isEmpty) return;
  final beams = Path(), posts = Path();
  var brightest = 0.0;
  for (final gate in game.mazeGates) {
    if (gate.y < -20 || gate.y > 580) continue;
    final lit = gate.intensity;
    brightest = math.max(brightest, lit);
    beams
      ..moveTo(MazeGate.edge, gate.y)
      ..lineTo(gate.gapLeft, gate.y)
      ..moveTo(gate.gapRight, gate.y)
      ..lineTo(MazeGate.edge + MazeGate.span, gate.y);
    // Bright posts mark the opening, so the safe lane reads at a glance.
    for (final x in [gate.gapLeft, gate.gapRight]) {
      posts.addRect(Rect.fromCenter(center: Offset(x, gate.y), width: 3, height: 15));
    }
  }
  if (brightest <= 0) return;
  final pulse = reducedMotion ? 1.0 : .86 + .14 * math.sin(game.clock * 3);
  c.drawPath(
    beams,
    Paint()
      ..color = const Color(0xFFFF343E).withValues(alpha: .26 * pulse * brightest)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round,
  );
  c.drawPath(
    beams,
    Paint()
      ..color = const Color(0xFFFF3D49).withValues(alpha: brightest)
      ..style = PaintingStyle.stroke
      ..strokeWidth = MazeGate.beamHalf * 2
      ..strokeCap = StrokeCap.round,
  );
  c.drawPath(
    beams,
    Paint()
      ..color = const Color(0xFFFFD5CE).withValues(alpha: brightest)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9,
  );
  c.drawPath(
    posts,
    Paint()..color = const Color(0xFFFFE9A8).withValues(alpha: .9 * brightest),
  );
}
