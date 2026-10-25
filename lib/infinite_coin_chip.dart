import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'menu_design.dart';

/// Infinite's in-run coin counter: a soft glass pebble under the combo, with a
/// painted coin, this run's coins and the wallet total. It adapts to the board
/// ink, so it reads on light and dark sections alike, and swells while the
/// coin spins for a moment after each pickup.
class InfiniteCoinChip extends StatelessWidget {
  const InfiniteCoinChip({
    super.key,
    required this.wallet,
    required this.collected,
    required this.ink,
    this.unlimited = false,
    this.sinceCoin = 99,
    this.reducedMotion = false,
  });

  final int wallet, collected;

  /// Board text color at the HUD; light ink means a dark field behind it.
  final Color ink;
  final bool unlimited, reducedMotion;

  /// Seconds since the last coin was picked up.
  final double sinceCoin;

  /// How long a pickup keeps the chip lit and the coin spinning.
  static const popSeconds = .5;

  static String grouped(int value) {
    final digits = value.abs().toString();
    final out = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    final pop = reducedMotion
        ? 0.0
        : (1 - sinceCoin / popSeconds).clamp(0.0, 1.0);
    final ease = Curves.easeOutCubic.transform(pop);
    final darkField = ink.computeLuminance() > .5;
    return Semantics(
      label: unlimited
          ? 'Unlimited coins. $collected coins this run.'
          : '$collected coins this run. Wallet ${grouped(wallet)} coins.',
      excludeSemantics: true,
      child: Transform.scale(
        scale: 1 + .08 * ease,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 3, 13, 3),
          decoration: BoxDecoration(
            color: darkField
                ? const Color(0xFF071214).withValues(alpha: .34)
                : Colors.white.withValues(alpha: .46),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: menuGold.withValues(alpha: .45 + .4 * ease),
              width: .8,
            ),
            boxShadow: [
              BoxShadow(
                color: menuGold.withValues(alpha: .4 * ease),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 22,
                child: CustomPaint(painter: CoinPainter(spin: pop)),
              ),
              const SizedBox(width: 7),
              Text(
                '+$collected',
                key: const ValueKey('hud-coins-collected'),
                style: TextStyle(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Container(
                width: 1,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: ink.withValues(alpha: .22),
              ),
              Text(
                unlimited ? '∞' : grouped(wallet),
                key: const ValueKey('hud-coins-wallet'),
                style: TextStyle(
                  color: ink.withValues(alpha: .66),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Infinite's painted coin as an inline icon, so menus and price tags show
/// the same coin the player collects on the board.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 16});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: CoinPainter()),
    ),
  );
}

/// A minted gold coin with a rim, an inner ring and a shine. [spin] from 1
/// to 0 turns it once around its vertical axis.
class CoinPainter extends CustomPainter {
  const CoinPainter({this.spin = 0});
  final double spin;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final turn = math.cos(spin * math.pi * 2).abs();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(math.max(.18, turn), 1);
    final face = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(
      const Offset(0, 1),
      r,
      Paint()..color = const Color(0xFF6E4614).withValues(alpha: .45),
    );
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.4),
          radius: 1.05,
          colors: [Color(0xFFFFF0B8), Color(0xFFF0C25A), Color(0xFFB57A22)],
          stops: [0, .55, 1],
        ).createShader(face),
    );
    canvas.drawCircle(
      Offset.zero,
      r * .68,
      Paint()
        ..color = const Color(0xFF9A6418).withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .09,
    );
    canvas.drawCircle(
      Offset.zero,
      r * .5,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE2A83E), Color(0xFFFFE08A)],
        ).createShader(face),
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r * .8),
      math.pi * 1.1,
      math.pi * .45,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: .75)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * .12,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CoinPainter oldDelegate) =>
      oldDelegate.spin != spin;
}
