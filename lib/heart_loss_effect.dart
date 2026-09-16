import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Visual state only. No timers, gesture ownership, or life-system mutations.
class HeartLossEffect {
  HeartLossEffect(this.origin);
  final Offset origin;
  double age = 0;
  static const duration = .85;
  bool get finished => age >= duration;
}

class HeartLossPainter extends CustomPainter {
  HeartLossPainter(
    this.effects, {
    required this.reducedMotion,
    Listenable? repaint,
  }) : super(repaint: repaint);
  final List<HeartLossEffect> effects;
  final bool reducedMotion;
  static final heart = Path()
    ..moveTo(0, 9)
    ..cubicTo(-3, 6, -12, 0, -12, -6)
    ..cubicTo(-12, -14, -3, -16, 0, -9)
    ..cubicTo(3, -16, 12, -14, 12, -6)
    ..cubicTo(12, 0, 3, 6, 0, 9)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    for (final effect in effects) {
      final t = (effect.age / HeartLossEffect.duration).clamp(0.0, 1.0);
      if (t >= 1) continue;
      final opacity = (1 - t) * (1 - t);
      canvas.save();
      canvas.translate(
        effect.origin.dx + (reducedMotion ? 0 : math.sin(t * math.pi * 2) * 3),
        effect.origin.dy -
            (reducedMotion ? 0 : 48 * Curves.easeOut.transform(t)),
      );
      canvas.scale(reducedMotion ? 1 : 1 - .22 * t);
      canvas.drawPath(
        heart,
        Paint()
          ..color = const Color(0xFFF8F1E4).withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawPath(
        heart,
        Paint()..color = const Color(0xFFE55A62).withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant HeartLossPainter oldDelegate) => true;
}
