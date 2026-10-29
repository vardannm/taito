import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'ball_cosmetics.dart';
import 'ball_world.dart';
import 'coin_store.dart';
import 'infinite_coin_chip.dart';
import 'menu_design.dart';
import 'platform_painter.dart';
import 'platforms.dart';
import 'premium_menu.dart' show formatMenuScore;
import 'profile.dart';
import 'shop_design.dart';
import 'survival_upgrades.dart';

String formatShopPrice(int cost) => formatMenuScore(cost);

class ShopHeader extends StatelessWidget {
  const ShopHeader({
    super.key,
    required this.profile,
    required this.onWalletChanged,
  });
  final PlayerProfile profile;
  final VoidCallback onWalletChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 20, 14),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Done shopping',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 21),
          style: IconButton.styleFrom(
            foregroundColor: menuText,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 6),
        const Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Gear Shop',
              style: TextStyle(
                color: menuText,
                fontSize: 29,
                height: 1,
                letterSpacing: -.8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              height: 48,
              child: WalletButton(
                key: const ValueKey('wallet'),
                profile: profile,
                onClosed: onWalletChanged,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class ShopShowcase extends StatelessWidget {
  const ShopShowcase({
    super.key,
    required this.title,
    required this.index,
    required this.count,
    required this.name,
    required this.subtitle,
    required this.bonus,
    required this.cost,
    required this.owned,
    required this.controller,
    required this.onBrowse,
    required this.onChanged,
    required this.itemBuilder,
    required this.action,
    this.footer,
    this.magnet,
    this.compact = false,
    this.premium = false,
    this.locked = false,
  });
  final String title, name, subtitle;
  final int index, count, cost;
  final double bonus;
  final bool owned, compact, premium, locked;
  final PageController controller;
  final ValueChanged<int> onBrowse, onChanged;
  final IndexedWidgetBuilder itemBuilder;
  final Widget action;
  final Widget? footer;
  final String? magnet;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: menuGold,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Divider(color: Color(0xFF385054), height: 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${(index + 1).toString().padLeft(2, '0')} / $count',
            key: ValueKey(compact ? 'platform-position' : 'ball-position'),
            style: const TextStyle(
              color: menuMuted,
              fontSize: 10,
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      SizedBox(height: compact ? 6 : 8),
      LayoutBuilder(
        builder: (context, bounds) => SizedBox(
          height: compact ? 50 : (bounds.maxWidth > 420 ? 260 : 150),
          child: Row(
            children: [
              _BrowseArrow(
                previous: true,
                label: compact ? 'platform' : 'ball',
                onPressed: locked || index == 0
                    ? null
                    : () => onBrowse(index - 1),
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      key: ValueKey(compact ? 'platform-pages' : 'ball-pages'),
                      controller: controller,
                      itemCount: count,
                      physics: locked
                          ? const NeverScrollableScrollPhysics()
                          : const PageScrollPhysics(),
                      onPageChanged: onChanged,
                      itemBuilder: itemBuilder,
                    ),
                    if (!compact)
                      Positioned(
                        right: 0,
                        top: 8,
                        child: IgnorePointer(
                          child: _PriceTag(
                            owned: owned,
                            premium: premium,
                            cost: cost,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _BrowseArrow(
                previous: false,
                label: compact ? 'platform' : 'ball',
                onPressed: locked || index == count - 1
                    ? null
                    : () => onBrowse(index + 1),
              ),
            ],
          ),
        ),
      ),
      if (compact) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 9, 9),
          decoration: BoxDecoration(
            color: menuPanel.withAlpha(180),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF3C5151)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      key: const ValueKey('platform-name'),
                      style: const TextStyle(
                        color: menuText,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+${formatBoost(bonus)}× Infinite points',
                      style: const TextStyle(color: menuGold, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: action,
              ),
            ],
          ),
        ),
      ] else ...[
        Text(
          name,
          textAlign: TextAlign.center,
          key: ValueKey(compact ? 'platform-name' : 'ball-name'),
          style: TextStyle(
            color: menuText,
            fontSize: compact ? 20 : 28,
            height: 1.15,
            fontWeight: FontWeight.w500,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: menuMuted, fontSize: 10, height: 1.4),
        ),
        if (magnet != null)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox.square(
                  dimension: 14,
                  child: CustomPaint(painter: _MagnetPainter(menuGold)),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    magnet!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: menuGold, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(
            color: menuPanel.withAlpha(180),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF3C5151)),
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: menuGold, size: 24),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '+${formatBoost(bonus)}×',
                        maxLines: 1,
                        style: const TextStyle(
                          color: menuGold,
                          fontSize: 22,
                          height: 1.05,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Infinite points',
                      style: TextStyle(
                        color: menuMuted,
                        fontSize: 9,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: action,
              ),
            ],
          ),
        ),
      ],
      if (footer != null) footer!,
    ],
  );
}

class _BrowseArrow extends StatelessWidget {
  const _BrowseArrow({
    required this.previous,
    required this.label,
    required this.onPressed,
  });
  final bool previous;
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    key: ValueKey('${previous ? 'previous' : 'next'}-$label'),
    tooltip: '${previous ? 'Previous' : 'Next'} $label',
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      maximumSize: const Size(48, 48),
      foregroundColor: menuText,
      disabledForegroundColor: menuLine,
      backgroundColor: const Color(0xFF1B3034),
      disabledBackgroundColor: const Color(0xFF192A2E),
      side: const BorderSide(color: Color(0xFF385054)),
      shape: const CircleBorder(),
    ),
    icon: Icon(
      previous ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
      size: 28,
    ),
  );
}

class _PriceTag extends StatelessWidget {
  const _PriceTag({
    required this.owned,
    required this.premium,
    required this.cost,
  });
  final bool owned, premium;
  final int cost;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFF14272C),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: (owned ? menuMint : menuGold).withAlpha(100)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!owned)
          const CoinIcon(size: 14)
        else
          const Icon(Icons.check_rounded, size: 13, color: menuMint),
        const SizedBox(width: 5),
        Text(
          owned ? 'OWNED' : formatShopPrice(cost),
          style: TextStyle(
            color: owned ? menuMint : menuGold,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: owned ? 1 : 0,
          ),
        ),
        if (premium)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.auto_awesome_rounded, size: 12, color: menuGold),
          ),
      ],
    ),
  );
}

class ShopBallArtwork extends StatelessWidget {
  const ShopBallArtwork({super.key, required this.ball, this.animation});
  final BallCosmetic ball;
  final Animation<double>? animation;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final diameter = math.min(bounds.maxWidth, bounds.maxHeight) - 14;
      return Center(
        child: SizedBox.square(
          dimension: diameter,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _OrbitPainter(Color(ball.color)),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ClipOval(
                  child: CustomPaint(
                    key: ValueKey('world-preview-${ball.name}'),
                    painter: BallWorldPreview(
                      ball,
                      ballHeight: .5,
                      ballScale: .32,
                      animation: animation,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter(this.tint);
  final Color tint;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero), radius = size.shortestSide / 2 - 1;
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, pen..color = tint.withAlpha(35));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * .77,
      math.pi * .5,
      false,
      pen..color = menuGold.withAlpha(170),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * .23,
      math.pi * .15,
      false,
      pen..color = tint.withAlpha(130),
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.tint != tint;
}

class ShopRailArtwork extends StatelessWidget {
  const ShopRailArtwork({super.key, required this.style, this.animation});
  final PlatformStyle style;
  final Animation<double>? animation;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _RailPainter(style, animation)),
  );
}

class _RailPainter extends CustomPainter {
  _RailPainter(this.style, this.animation) : super(repaint: animation);
  final PlatformStyle style;
  final Animation<double>? animation;
  @override
  void paint(Canvas canvas, Size size) {
    final span = size.width * .82, center = size.center(Offset.zero);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(0, 13),
        width: span,
        height: 12,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color(style.color).withAlpha(40),
            Color(style.color).withAlpha(0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, 2.2);
    final a = Offset(-span / 2, 0), b = Offset(span / 2, 0);
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = Color(style.color)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    paintPlatformDetail(
      canvas,
      a,
      b,
      style,
      time: (animation?.value ?? 0) * 12,
      reducedMotion: animation == null,
    );
    canvas.drawLine(
      a + const Offset(3, -2),
      b - const Offset(3, 2),
      Paint()
        ..color = Colors.white.withAlpha(120)
        ..strokeWidth = .6,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.style != style || old.animation != animation;
}

class ShopUpgradePanel extends StatelessWidget {
  const ShopUpgradePanel({
    super.key,
    required this.profile,
    required this.onBuy,
    required this.onWalletChanged,
  });
  final PlayerProfile profile;
  final ValueChanged<SurvivalUpgrade> onBuy;
  final VoidCallback onWalletChanged;

  int? get missingCoins {
    int? needed;
    for (final upgrade in SurvivalUpgrade.values) {
      final level = profile.upgradeLevel(upgrade);
      if (level >= upgrade.maxLevel) continue;
      final cost = upgrade.costAt(level);
      if (!profile.canAfford(cost)) {
        final shortfall = cost - profile.wallet;
        needed = needed == null ? shortfall : math.min(needed, shortfall);
      }
    }
    return needed;
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('shop-upgrades'),
    padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
    decoration: BoxDecoration(
      color: const Color(0xFF182A2E),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFF354B4E)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'Upgrades',
                style: TextStyle(
                  color: menuText,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -.4,
                ),
              ),
            ),
            Text(
              'PERMANENT',
              style: TextStyle(
                color: menuGold,
                fontSize: 8,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 4),
          ],
        ),
        const SizedBox(height: 8),
        for (final upgrade in SurvivalUpgrade.values) _upgrade(upgrade),
        if (missingCoins case final int needed)
          GetCoinsLink(
            key: const ValueKey('get-coins-upgrades'),
            profile: profile,
            needed: needed,
            onClosed: onWalletChanged,
          ),
        const SizedBox(height: 6),
        const Text(
          'For Infinite. Extra hearts apply to your next run.',
          textAlign: TextAlign.center,
          style: TextStyle(color: menuMuted, fontSize: 9, height: 1.4),
        ),
      ],
    ),
  );

  Widget _upgrade(SurvivalUpgrade upgrade) {
    final level = profile.upgradeLevel(upgrade), cost = upgrade.costAt(level);
    final maxed = level >= upgrade.maxLevel;
    final (name, icon, tint) = switch (upgrade) {
      SurvivalUpgrade.magnet => ('Magnet', Icons.attractions_rounded, menuGold),
      SurvivalUpgrade.shield => (
        'Shield',
        Icons.shield_outlined,
        const Color(0xFF90C9E3),
      ),
      SurvivalUpgrade.hearts => (
        'Hearts',
        Icons.favorite_rounded,
        const Color(0xFFECA89F),
      ),
    };
    String value(int tier) =>
        '${upgrade.valueAt(tier).toInt()}${upgrade == SurvivalUpgrade.hearts ? '' : 's'}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 42,
                decoration: BoxDecoration(
                  color: tint.withAlpha(13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: upgrade == SurvivalUpgrade.magnet
                    ? Center(
                        child: SizedBox.square(
                          dimension: 25,
                          child: CustomPaint(painter: _MagnetPainter(tint)),
                        ),
                      )
                    : Icon(icon, color: tint, size: 25),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  label:
                      '${upgrade.label}, level $level of ${upgrade.maxLevel}. Current: ${upgrade.valueLabel(level)}. ${maxed ? 'Fully upgraded' : 'Next: ${upgrade.valueLabel(level + 1)}'}',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: menuText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '$level/${upgrade.maxLevel}',
                            style: const TextStyle(
                              color: menuMuted,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        key: ValueKey('upgrade-value-${upgrade.name}'),
                        children: [
                          Text(
                            value(level),
                            style: const TextStyle(
                              color: menuMuted,
                              fontSize: 9,
                              height: 1.3,
                            ),
                          ),
                          if (!maxed)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 3),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 10,
                                color: menuMuted,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              maxed
                                  ? ' · Max level'
                                  : '${value(level + 1)}${upgrade == SurvivalUpgrade.hearts ? ' hearts' : ' duration'}',
                              style: const TextStyle(
                                color: menuMuted,
                                fontSize: 9,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          for (var i = 0; i < upgrade.maxLevel; i++)
                            Expanded(
                              child: Container(
                                height: 4,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: i < level
                                      ? tint
                                      : const Color(0xFF34494D),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 79,
                child: ShopPurchaseButton(
                  buttonKey: ValueKey('upgrade-${upgrade.name}'),
                  label: maxed ? 'Max' : formatShopPrice(cost),
                  price: maxed ? null : cost,
                  equipped: maxed,
                  onPressed: maxed || !profile.canAfford(cost)
                      ? null
                      : () => onBuy(upgrade),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MagnetPainter extends CustomPainter {
  const _MagnetPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final path = Path()
      ..moveTo(5, 4)
      ..lineTo(5, 13)
      ..arcToPoint(
        const Offset(19, 13),
        radius: const Radius.circular(7),
        clockwise: false,
      )
      ..lineTo(19, 4);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round,
    );
    for (final x in [2.5, 16.5]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 2, 5, 5),
          const Radius.circular(1),
        ),
        Paint()..color = menuText,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MagnetPainter old) => color != old.color;
}
