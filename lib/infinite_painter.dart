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

void paintInfiniteEnergy(
  Canvas c,
  BalanceGame game,
  bool reducedMotion,
) {
  if (!game.infinite || game.survival.combo < 5) return;

  final a = Offset(20, game.screenY(game.left));
  final b = Offset(340, game.screenY(game.right));

  final combo = game.survival.combo;

  // 0 at x5, reaches maximum intensity around x20.
  final intensity = ((combo - 5) / 15.0).clamp(0.0, 1.0);

  final direction = b - a;
  final span = direction.distance;

  if (span <= 0) return;

  final angle = math.atan2(direction.dy, direction.dx);

  final time = game.clock;

  // The whole effect becomes faster / more unstable as combo rises.
  final pulse =
      reducedMotion
          ? 1.0
          : 0.82 +
              math.sin(time * (5.0 + intensity * 5.0)) *
                  (0.10 + intensity * 0.08);

  // Changes from warm gold -> orange/red -> almost white-hot.
  final energyColor = Color.lerp(
    const Color(0xFFFFC247),
    const Color(0xFFFF365D),
    intensity,
  )!;

  final secondaryColor = Color.lerp(
    const Color(0xFFFF8A32),
    const Color(0xFFD43CFF),
    intensity,
  )!;

  c.save();

  c.translate(a.dx, a.dy);
  c.rotate(angle);

  // ============================================================
  // 1. HUGE ENERGY AURA
  // ============================================================

  c.drawLine(
    const Offset(0, 0),
    Offset(span, 0),
    Paint()
      ..color = energyColor.withValues(
        alpha: (0.10 + intensity * 0.10) * pulse,
      )
      ..strokeWidth = 30 + intensity * 12
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        16 + intensity * 10,
      ),
  );

  // ============================================================
  // 2. LOWER HOT GLOW
  // Gives the platform a heated / charged feeling.
  // ============================================================

  c.drawRect(
    Rect.fromLTWH(
      0,
      -4,
      span,
      12 + intensity * 5,
    ),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          energyColor.withValues(alpha: 0.65),
          secondaryColor.withValues(alpha: 0.25),
          secondaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromLTWH(
          0,
          -4,
          span,
          20,
        ),
      )
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        7,
      ),
  );

  // ============================================================
  // 3. ELECTRIC ENERGY ARCS
  // ============================================================

  if (!reducedMotion) {
    final arcCount = 3 + (intensity * 5).round();

    for (var arc = 0; arc < arcCount; arc++) {
      final path = Path();

      final segments = 12;

      for (var i = 0; i <= segments; i++) {
        final progress = i / segments;
        final x = progress * span;

        // Arcs become larger and more unstable with combo.
        final wave =
            math.sin(
              progress * math.pi * (3 + arc % 3) +
                  time * (5.5 + intensity * 4) +
                  arc * 2.1,
            );

        final noise =
            math.sin(
              i * 8.73 +
                  time * (9 + arc * 0.8) +
                  arc * 13.7,
            );

        final envelope = math.sin(progress * math.pi);

        final height =
            envelope *
            (
              wave * (4 + intensity * 8) +
              noise * (2 + intensity * 5)
            );

        final y = -6 - arc * 1.5 - height;

        if (i == 0) {
          path.moveTo(x, 0);
        } else {
          path.lineTo(x, y);
        }
      }

      path.lineTo(span, 0);

      // Arc glow.
      c.drawPath(
        path,
        Paint()
          ..color = secondaryColor.withValues(
            alpha: 0.17 + intensity * 0.15,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            7,
          ),
      );

      // Sharp electrical center.
      c.drawPath(
        path,
        Paint()
          ..color = Color.lerp(
            energyColor,
            Colors.white,
            0.55,
          )!.withValues(
            alpha: 0.45 + intensity * 0.4,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 + intensity
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  // ============================================================
  // 4. TRAVELLING ENERGY SURGES
  // Bright pulses race along the platform.
  // ============================================================

  if (!reducedMotion) {
    final surgeCount = 2 + (intensity * 2).round();

    for (var i = 0; i < surgeCount; i++) {
      final progress =
          (
            time * (0.65 + intensity * 0.9) +
            i / surgeCount
          ) %
          1.0;

      final x = progress * span;

      final radius = 7 + intensity * 7;

      c.drawCircle(
        Offset(x, 0),
        radius * 2.2,
        Paint()
          ..color = energyColor.withValues(
            alpha: 0.18,
          )
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            14,
          ),
      );

      c.drawCircle(
        Offset(x, 0),
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.95),
              energyColor.withValues(alpha: 0.7),
              energyColor.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(x, 0),
              radius: radius,
            ),
          ),
      );
    }
  }

  // ============================================================
  // 5. RISING SPARKS / ENERGY DEBRIS
  // ============================================================

  if (!reducedMotion) {
    final particleCount = 10 + (intensity * 16).round();

    for (var i = 0; i < particleCount; i++) {
      final life =
          (
            time * (0.65 + intensity * 0.8) +
            i * 0.117
          ) %
          1.0;

      final baseX =
          ((i * 71.0) % math.max(span - 10, 1)) + 5;

      final sideways =
          math.sin(
            i * 2.71 +
                time * (4 + intensity * 4),
          ) *
          (3 + intensity * 6);

      final y =
          -5 -
          life * (20 + intensity * 34);

      final x = baseX + sideways * life;

      final alpha =
          (1 - life) *
          (0.35 + intensity * 0.55);

      final radius =
          (1.1 + intensity * 1.3) *
          (1 - life * 0.55);

      c.drawCircle(
        Offset(x, y),
        radius * 3,
        Paint()
          ..color = secondaryColor.withValues(
            alpha: alpha * 0.25,
          )
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            5,
          ),
      );

      c.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = Color.lerp(
            energyColor,
            Colors.white,
            0.65,
          )!.withValues(
            alpha: alpha,
          ),
      );
    }
  }

  // ============================================================
  // 6. WHITE-HOT PLATFORM CORE
  // ============================================================

  c.drawLine(
    const Offset(0, 0),
    Offset(span, 0),
    Paint()
      ..color = energyColor.withValues(
        alpha: 0.8 * pulse,
      )
      ..strokeWidth = 7 + intensity * 2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        5,
      ),
  );

  c.drawLine(
    const Offset(0, 0),
    Offset(span, 0),
    Paint()
      ..color = Color.lerp(
        const Color(0xFFFFF0B5),
        Colors.white,
        intensity,
      )!
      ..strokeWidth = 2.2 + intensity
      ..strokeCap = StrokeCap.round,
  );

  // ============================================================
  // 7. ENDPOINT ENERGY BURSTS
  // ============================================================

  if (!reducedMotion) {
    for (final x in [0.0, span]) {
      final endpointPulse =
          0.7 +
          math.sin(
                time * (7 + intensity * 5) +
                x,
              ) *
              0.3;

      c.drawCircle(
        Offset(x, 0),
        (10 + intensity * 7) * endpointPulse,
        Paint()
          ..color = secondaryColor.withValues(
            alpha: 0.22 + intensity * 0.15,
          )
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            10,
          ),
      );

      c.drawCircle(
        Offset(x, 0),
        2.2 + intensity * 1.5,
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.9,
          ),
      );
    }
  }

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
