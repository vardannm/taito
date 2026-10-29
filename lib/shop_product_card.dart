import 'package:flutter/material.dart';

import 'ball_cosmetics.dart';
import 'ball_world.dart';
import 'coin_store.dart';
import 'menu_design.dart';
import 'premium_menu.dart' show formatMenuScore;
import 'profile.dart';
import 'shop_artwork.dart';
import 'shop_catalog.dart';
import 'shop_design.dart';
import 'shop_product_state.dart';
import 'survival_upgrades.dart';

class ShopProductCard extends StatelessWidget {
  const ShopProductCard({
    super.key,
    required this.product,
    required this.profile,
    required this.onInspect,
    required this.onAction,
    required this.onCoinsChanged,
    this.animation,
    this.tutorialKey,
    this.tutorial = false,
  });
  final ShopProduct product;
  final PlayerProfile profile;
  final VoidCallback onInspect, onAction, onCoinsChanged;
  final AnimationController? animation;
  final Key? tutorialKey;
  final bool tutorial;

  @override
  Widget build(BuildContext context) {
    final owned = product.ownedBy(profile),
        selected = product.equippedBy(profile),
        maxed = product.maxedFor(profile);
    final cost = product.priceFor(profile), level = product.levelFor(profile);
    final upgrade = product.upgrade;
    final status = selected
        ? 'EQUIPPED'
        : owned
        ? 'OWNED'
        : maxed
        ? 'MAX LEVEL'
        : product.premium
        ? 'PREMIUM'
        : upgrade != null
        ? 'PERMANENT'
        : product.ball == null
        ? 'PLATFORM'
        : 'BALL + WORLD';
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      decoration: BoxDecoration(
        color: menuPanel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected || maxed
              ? menuMint.withAlpha(120)
              : product.premium
              ? menuGold.withAlpha(90)
              : menuLine.withAlpha(100),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(22),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('preview-${product.id}'),
              onTap: onInspect,
              child: Semantics(
                button: true,
                label: 'Preview ${product.name}',
                excludeSemantics: true,
                child: SizedBox(
                  height: upgrade == null ? 164 : 140,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ShopArtwork(product: product, animation: animation),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: ShopGlassPill(
                          child: Text(
                            status,
                            style: TextStyle(
                              color: selected || maxed ? menuMint : menuText,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .8,
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        right: 10,
                        bottom: 10,
                        child: ShopGlassPill(
                          child: Icon(
                            Icons.open_in_full_rounded,
                            color: menuText,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: menuText,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  product.ball != null
                      ? BallWorld.of(product.ball!).name
                      : product.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: menuMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                if (upgrade != null) ...[
                  Semantics(
                    label: 'Level $level of ${upgrade.maxLevel}',
                    child: Row(
                      children: [
                        for (var i = 0; i < upgrade.maxLevel; i++)
                          Expanded(
                            child: Container(
                              height: 4,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: i < level ? menuMint : menuLine,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Current: ${upgrade.valueLabel(level)}',
                    style: const TextStyle(color: menuMint, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    maxed
                        ? 'Maximum reached'
                        : 'Next: ${upgrade.valueLabel(level + 1)}',
                    style: const TextStyle(color: menuMuted, fontSize: 11),
                  ),
                ] else ...[
                  Text(
                    product.bonus > 0
                        ? '+${formatBoost(product.bonus)}× Infinite points'
                        : 'Original equipment',
                    style: const TextStyle(
                      color: menuMint,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if ((product.ball?.magnetRadius ?? 0) > 0) ...[
                    const SizedBox(height: 5),
                    Text(
                      '${product.ball!.magnetLabel} · ${product.ball!.magnetRadius.round()}',
                      style: const TextStyle(color: menuGold, fontSize: 10),
                    ),
                  ],
                ],
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: tutorialKey,
                  child: ShopPurchaseButton(
                    buttonKey: ValueKey(product.id),
                    equipped: !tutorial && (selected || maxed),
                    price: tutorial || owned || maxed ? null : cost,
                    label: tutorial
                        ? 'Equip'
                        : selected
                        ? 'Equipped'
                        : maxed
                        ? 'Fully upgraded'
                        : owned
                        ? 'Equip'
                        : formatMenuScore(cost),
                    onPressed: tutorial
                        ? onAction
                        : selected || maxed || !profile.canAfford(cost)
                        ? null
                        : onAction,
                  ),
                ),
                if (!owned && !maxed && !profile.canAfford(cost))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: GetCoinsLink(
                      key: ValueKey('get-coins-${product.id}'),
                      profile: profile,
                      needed: cost - profile.wallet,
                      onClosed: onCoinsChanged,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShopFeaturedWorld extends StatelessWidget {
  const ShopFeaturedWorld({
    super.key,
    required this.product,
    required this.onPressed,
    this.animation,
  });
  final ShopProduct product;
  final VoidCallback onPressed;
  final AnimationController? animation;
  @override
  Widget build(BuildContext context) => Material(
    color: menuPanel,
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed,
      child: LayoutBuilder(
        builder: (context, bounds) {
          if (bounds.maxWidth < 440 &&
              MediaQuery.textScalerOf(context).scale(12) > 17) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 150,
                  child: ShopArtwork(product: product, animation: animation),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEXT DISCOVERY',
                        style: TextStyle(
                          color: menuGold,
                          fontSize: 9,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        BallWorld.of(product.ball!).name,
                        style: const TextStyle(
                          color: menuText,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Explore world',
                        style: TextStyle(
                          color: menuGold,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          final artWidth = (bounds.maxWidth * .42).clamp(100.0, 220.0);
          return IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'NEXT DISCOVERY',
                          style: TextStyle(
                            color: menuGold,
                            fontSize: 9,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          BallWorld.of(product.ball!).name,
                          style: const TextStyle(
                            color: menuText,
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -.6,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${product.name} ball + world · ${formatMenuScore(product.ball!.cost)} coins',
                          style: const TextStyle(
                            color: menuMuted,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Explore world',
                                style: TextStyle(
                                  color: menuGold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: menuGold,
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: artWidth,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 180),
                    child: ShopArtwork(product: product, animation: animation),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
