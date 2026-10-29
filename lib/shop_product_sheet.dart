import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ball_cosmetics.dart';
import 'ball_world.dart';
import 'coin_store.dart';
import 'infinite_coin_chip.dart';
import 'menu_design.dart';
import 'premium_menu.dart' show formatMenuScore;
import 'profile.dart';
import 'shop_artwork.dart';
import 'shop_catalog.dart';
import 'shop_product_state.dart';
import 'survival_upgrades.dart';

Future<void> showShopProduct(
  BuildContext context,
  PlayerProfile profile,
  ShopProduct product,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: false,
  enableDrag: false,
  backgroundColor: menuBackground,
  constraints: BoxConstraints(
    maxWidth: 640,
    maxHeight: MediaQuery.sizeOf(context).height * .94,
  ),
  builder: (_) => MenuSurface(
    child: ShopProductSheet(profile: profile, product: product),
  ),
);

/// Preview and confirmation share one sheet. The quoted price and level are
/// checked by the profile again at commit time; the UI never grants rewards.
class ShopProductSheet extends StatefulWidget {
  const ShopProductSheet({
    super.key,
    required this.profile,
    required this.product,
  });
  final PlayerProfile profile;
  final ShopProduct product;
  @override
  State<ShopProductSheet> createState() => _ShopProductSheetState();
}

class _ShopProductSheetState extends State<ShopProductSheet>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool busy = false, success = false;
  String? error;
  late int quote = widget.product.priceFor(widget.profile);
  late int quotedLevel = widget.product.levelFor(widget.profile);
  late final bool wasOwned;
  final scroll = ScrollController();
  late final preview = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void initState() {
    super.initState();
    wasOwned = widget.product.ownedBy(widget.profile);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncPreview();
  }

  void syncPreview() {
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled ||
        ModalRoute.isCurrentOf(context) == false ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      preview.stop();
    } else if (!preview.isAnimating) {
      preview.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => syncPreview();
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    preview.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> confirm() async {
    if (busy || success) return;
    setState(() {
      busy = true;
      error = null;
    });
    final result = await widget.profile.purchaseShopProduct(
      widget.product,
      quotedPrice: quote,
      quotedLevel: quotedLevel,
    );
    if (!mounted) return;
    setState(() {
      busy = false;
      success = result == ShopTransactionResult.success;
      error = switch (result) {
        ShopTransactionResult.success => null,
        ShopTransactionResult.insufficientCoins =>
          'Your balance changed. Earn a few more coins to unlock this item.',
        ShopTransactionResult.changed =>
          'This item changed. Review the updated price and try again.',
        ShopTransactionResult.busy =>
          'Another purchase is saving. Please try again.',
        ShopTransactionResult.storageUnavailable =>
          'Couldn’t save your purchase. No coins were spent. Check device storage and try again.',
      };
      if (!success) {
        quote = widget.product.priceFor(widget.profile);
        quotedLevel = widget.product.levelFor(widget.profile);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) scroll.jumpTo(0);
    });
    if (success && widget.profile.haptics) HapticFeedback.lightImpact();
  }

  Future<void> earnCoins() async {
    await showCoinStore(
      context,
      widget.profile,
      needed: (quote - widget.profile.wallet).clamp(0, quote),
    );
    if (mounted)
      setState(() {
        error = null;
        quote = widget.product.priceFor(widget.profile);
        quotedLevel = widget.product.levelFor(widget.profile);
      });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile, item = widget.product, upgrade = item.upgrade;
    final affordable = p.canAfford(quote), maxed = item.maxedFor(p);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final level = item.levelFor(p);
    final short = MediaQuery.sizeOf(context).height < 500;
    return PopScope(
      canPop: !busy,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      success
                          ? 'YOURS TO KEEP'
                          : short
                          ? item.name
                          : item.premium
                          ? 'PREMIUM COLLECTION'
                          : 'TAKE A CLOSER LOOK',
                      style: TextStyle(
                        color: menuGold,
                        fontSize: short ? 18 : 10,
                        letterSpacing: short ? 0 : 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close item details',
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: menuText),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: _DetailPanel(
                            key: const ValueKey('shop-purchase-error'),
                            icon: Icons.error_outline_rounded,
                            title: 'Purchase not completed',
                            detail: error!,
                            accent: const Color(0xFFEDAD97),
                          ),
                        ),
                      ),
                    if (success)
                      Semantics(
                        liveRegion: true,
                        child: TweenAnimationBuilder<double>(
                          key: const ValueKey('shop-purchase-success'),
                          tween: Tween(begin: reduced ? 1 : .92, end: 1),
                          duration: reduced
                              ? Duration.zero
                              : const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) =>
                              Transform.scale(scale: value, child: child),
                          child: _DetailPanel(
                            icon: Icons.check_circle_rounded,
                            title: upgrade == null
                                ? '${item.name} equipped'
                                : '${upgrade.label} upgraded',
                            detail: upgrade == null
                                ? (wasOwned
                                      ? 'Ready for your next run.'
                                      : 'Added to your collection. Ready for your next run.')
                                : 'Now ${upgrade.valueLabel(level)}. Ready for your next Infinite run.',
                            accent: menuMint,
                          ),
                        ),
                      ),
                    if (success) const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: MediaQuery.sizeOf(context).height < 600
                            ? (short ? 110 : 150)
                            : 230,
                        child: ShopArtwork(
                          product: item,
                          animation: reduced ? null : preview,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: menuText,
                        fontSize: 30,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: const TextStyle(
                        color: menuMuted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (!success) ...[
                      if (item.ball != null)
                        _DetailPanel(
                          icon: Icons.landscape_outlined,
                          title: '${BallWorld.of(item.ball!).name} included',
                          detail: BallWorld.of(item.ball!).description,
                        ),
                      if (upgrade == null) ...[
                        const SizedBox(height: 10),
                        _DetailPanel(
                          icon: Icons.all_inclusive_rounded,
                          title: '+${formatBoost(item.bonus)}× Infinite points',
                          detail:
                              'Total with this item: x${formatBoost(item.multiplierFor(p))} (currently x${formatBoost(p.equipmentMultiplier)}).',
                          accent: menuMint,
                        ),
                        if ((item.ball?.magnetRadius ?? 0) > 0) ...[
                          const SizedBox(height: 10),
                          _DetailPanel(
                            icon: Icons.attractions_rounded,
                            title: item.ball!.magnetLabel,
                            detail:
                                'Always active in Infinite. Collection radius: ${item.ball!.magnetRadius.round()} world units.',
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Text(
                          'Identical handling and hitboxes. Points bonuses and built-in magnets apply in Infinite.',
                          style: TextStyle(
                            color: menuMuted,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ] else
                        _DetailPanel(
                          icon: shopUpgradeIcon(upgrade),
                          title: 'Level $level / ${upgrade.maxLevel}',
                          detail: maxed
                              ? '${upgrade.valueLabel(level)} · Maximum reached'
                              : 'Current: ${upgrade.valueLabel(level)}\nNext: ${upgrade.valueLabel(level + 1)}\nPermanent upgrade for Infinite.',
                          accent: Color(item.color),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
              decoration: const BoxDecoration(
                color: menuPanel,
                border: Border(top: BorderSide(color: menuLine)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!success && !maxed) ...[
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 16,
                      runSpacing: 5,
                      children: [
                        Text(
                          'Balance  ${p.unlimitedCoins ? '∞' : formatMenuScore(p.wallet)}',
                          style: const TextStyle(
                            color: menuMuted,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          affordable
                              ? 'After purchase  ${p.unlimitedCoins ? '∞' : formatMenuScore(p.wallet - quote)}'
                              : 'Need ${formatMenuScore(quote - p.wallet)} more coins',
                          key: const ValueKey('shop-balance-after'),
                          style: TextStyle(
                            color: affordable ? menuMint : menuGold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    key: const ValueKey('confirm-shop-purchase'),
                    onPressed: busy
                        ? null
                        : success || maxed || item.equippedBy(p)
                        ? () => Navigator.pop(context)
                        : affordable
                        ? confirm
                        : earnCoins,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 52),
                    ),
                    child: busy
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: menuGold,
                                ),
                              ),
                              SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Saving purchase…',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          )
                        : Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                success
                                    ? 'Continue browsing'
                                    : maxed
                                    ? 'Fully upgraded'
                                    : item.equippedBy(p)
                                    ? 'Equipped'
                                    : !affordable
                                    ? 'Earn coins'
                                    : quote == 0
                                    ? 'Equip'
                                    : upgrade != null
                                    ? 'Upgrade'
                                    : 'Buy & equip',
                              ),
                              if (!success &&
                                  !maxed &&
                                  affordable &&
                                  quote > 0) ...[
                                const CoinIcon(size: 18),
                                Text(formatMenuScore(quote)),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.accent = menuGold,
  });
  final IconData icon;
  final String title, detail;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: accent.withAlpha(12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accent.withAlpha(45)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accent, size: 23),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                detail,
                style: const TextStyle(
                  color: menuMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
