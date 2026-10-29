import 'package:flutter/material.dart';

import 'ball_world.dart';
import 'menu_design.dart';
import 'pickup_painter.dart';
import 'platform_painter.dart';
import 'shop_catalog.dart';
import 'shop_design.dart';
import 'survival_upgrades.dart';

IconData shopUpgradeIcon(SurvivalUpgrade upgrade) => switch (upgrade) {
  SurvivalUpgrade.magnet => Icons.attractions_rounded,
  SurvivalUpgrade.shield => Icons.shield_outlined,
  SurvivalUpgrade.hearts => Icons.favorite_outline_rounded,
};

/// Shares the actual game art between the catalog and the purchase preview.
class ShopArtwork extends StatelessWidget {
  const ShopArtwork({super.key, required this.product, this.animation});
  final ShopProduct product;
  final AnimationController? animation;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: product.upgrade == null
        ? CustomPaint(
            key: product.ball == null
                ? null
                : ValueKey('world-preview-${product.ball!.name}'),
            painter: product.ball != null
                ? BallWorldPreview(product.ball!, animation: animation)
                : ShopPlatformStage(
                    PlatformPreview(product.platform!, animation: animation),
                    animation: animation,
                  ),
          )
        : CustomPaint(
            painter: _UpgradeStage(product, animation),
            child: product.upgrade == SurvivalUpgrade.hearts
                ? const Center(
                    child: Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFED9E9A),
                      size: 70,
                    ),
                  )
                : null,
          ),
  );
}

class _UpgradeStage extends CustomPainter {
  _UpgradeStage(this.product, this.animation) : super(repaint: animation);
  final ShopProduct product;
  final AnimationController? animation;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size, tint = Color(product.color);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.lerp(menuPanel, tint, .25)!, menuBackground],
          radius: .9,
        ).createShader(rect),
    );
    final center = rect.center;
    for (final radius in [.29, .40, .51]) {
      canvas.drawCircle(
        center,
        size.shortestSide * radius,
        Paint()
          ..color = tint.withAlpha(25)
          ..style = PaintingStyle.stroke,
      );
    }
    if (product.upgrade != SurvivalUpgrade.hearts) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(2.7);
      paintPickup(
        canvas,
        Offset.zero,
        product.upgrade == SurvivalUpgrade.magnet
            ? PickupFace.magnet
            : PickupFace.shield,
        (animation?.value ?? 0) * 12,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_UpgradeStage old) =>
      old.product.id != product.id || old.animation != animation;
}
