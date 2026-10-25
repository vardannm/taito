import 'onboarding.dart';
import 'tutorial_spotlight.dart';
import 'package:flutter/material.dart';
import 'ball_cosmetics.dart';
import 'ball_painter.dart';
import 'ball_world.dart';
import 'platforms.dart';
import 'platform_painter.dart';
import 'profile.dart';
import 'menu_design.dart';
import 'survival_upgrades.dart';
import 'shop_design.dart';
import 'premium_menu.dart';
import 'infinite_coin_chip.dart';

class BallShop extends StatefulWidget {
  const BallShop({
    super.key,
    required this.profile,
    this.onTutorialChanged,
    this.onSkipTutorial,
  });
  final VoidCallback? onTutorialChanged, onSkipTutorial;
  final PlayerProfile profile;
  @override
  State<BallShop> createState() => _BallShopState();
}

class _BallShopState extends State<BallShop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int category = 0;
  double swipeDistance = 0;

  void finishSwipe(DragEndDetails details) {
    if (guiding) return;
    final velocity = details.primaryVelocity ?? 0;
    if (swipeDistance.abs() < 56 && velocity.abs() < 500) return;
    final direction = swipeDistance.abs() >= 56 ? swipeDistance : velocity;
    if (direction < 0 && category == 0) {
      Navigator.of(context).maybePop();
    } else {
      setState(
        () => category = (category + (direction > 0 ? 1 : -1)).clamp(0, 2),
      );
    }
  }

  final exampleKey = GlobalKey();
  bool get guiding =>
      !widget.profile.tutorialSeen &&
      [
        TutorialStep.shopBall,
        TutorialStep.shopPlatform,
      ].contains(widget.profile.tutorial.step);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.profile.tutorial.step == TutorialStep.shopPlatform) category = 1;
    revealExample();
  }

  /// Scrolls the starter card's button into view under the spotlight.
  void revealExample() {
    if (!guiding) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = exampleKey.currentContext;
      if (!mounted || target == null) return;
      // Rebuild once it lands, so the spotlight measures the moved button
      // even when reduced motion has stopped its pulse.
      Scrollable.ensureVisible(target, alignment: .8).then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  void equippedExample() {
    if (!guiding) return;
    setState(() {
      if (widget.profile.tutorial.step == TutorialStep.shopBall) {
        widget.profile.tutorial.step = TutorialStep.shopPlatform;
        category = 1;
      } else {
        widget.profile.tutorial.step = TutorialStep.shopBrowse;
      }
    });
    widget.onTutorialChanged?.call();
    revealExample();
  }

  late final AnimationController preview = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncPreview();
  }

  void syncPreview() {
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled ||
        (ModalRoute.isCurrentOf(context) == false) ||
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
    super.dispose();
  }

  Widget galleryItem({
    required String id,
    required String name,
    required String description,
    required int cost,
    required double bonus,
    required bool owned,
    required bool selected,
    required CustomPainter painter,
    required VoidCallback buy,
    bool purchaseOnly = false,
    bool example = false,
    BallCosmetic? worldBall,
  }) => ShopGalleryCard(
    name: name,
    description: description,
    selected: selected,
    status: selected
        ? 'EQUIPPED'
        : owned
        ? 'IN YOUR COLLECTION'
        : purchaseOnly
        ? 'PREMIUM'
        : 'DISCOVER',
    worldName: worldBall == null ? null : BallWorld.of(worldBall).name,
    artHeight: worldBall == null ? 136 : 188,
    artwork: CustomPaint(
      key: worldBall == null
          ? null
          : ValueKey('world-preview-${worldBall.name}'),
      painter: worldBall == null
          ? ShopPlatformStage(painter, animation: preview)
          : BallWorldPreview(
              worldBall,
              animation: MediaQuery.disableAnimationsOf(context)
                  ? null
                  : preview,
            ),
    ),
    detail: purchaseOnly
        ? 'Premium · +${formatBoost(bonus)}× Infinite points'
        : bonus == 0
        ? 'Base equipment'
        : '+${formatBoost(bonus)}× Infinite points',
    action: example && guiding
        // The lesson's one live button: equipping the starter moves it on.
        ? KeyedSubtree(
            key: exampleKey,
            child: ShopPurchaseButton(
              buttonKey: ValueKey(id),
              label: 'Equip',
              onPressed: () {
                buy();
                equippedExample();
              },
            ),
          )
        : ShopPurchaseButton(
            buttonKey: ValueKey(id),
            equipped: selected,
            price: selected || owned ? null : cost,
            label: selected
                ? 'Equipped'
                : owned
                ? 'Equip'
                : formatMenuScore(cost),
            onPressed: selected || (!owned && !widget.profile.canAfford(cost))
                ? null
                : buy,
          ),
  );

  Widget collection() {
    final p = widget.profile;
    final compact = MediaQuery.sizeOf(context).height < 650;
    return MenuSurface(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF20383D), menuBackground],
            stops: [0, .45],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 18, 4),
                child: Row(
                  children: [
                    MenuQuietButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Done shopping',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: SizedBox(
                        height: 56,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ROLLRISE / COLLECTION',
                                style: TextStyle(
                                  color: menuGold,
                                  fontSize: 8,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Gear Shop',
                                style: TextStyle(
                                  color: menuText,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: MenuPill(
                          p.unlimitedCoins ? '∞' : formatMenuScore(p.wallet),
                          key: const ValueKey('wallet'),
                          leading: const CoinIcon(size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Your gear: x${formatBoost(p.equipmentMultiplier)} points',
                    key: const ValueKey('gear-total'),
                    style: const TextStyle(
                      color: menuMint,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: MenuTabs(
                  labels: const ['Balls', 'Platforms', 'Upgrades'],
                  selected: category,
                  minimal: true,
                  icons: const [
                    Icons.sports_baseball_outlined,
                    Icons.horizontal_rule_rounded,
                    Icons.upgrade_rounded,
                  ],
                  onChanged: (value) => setState(() => category = value),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListView(
                      key: ValueKey('collection-$category'),
                      padding: EdgeInsets.fromLTRB(
                        18,
                        compact ? 18 : 24,
                        18,
                        24,
                      ),
                      children: [
                        Text(
                          [
                            'A new ball. A new world.',
                            'Precision, restyled.',
                            'Built for a longer run.',
                          ][category],
                          style: const TextStyle(
                            color: menuText,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            '${p.ownedBalls.length} of ${BallCosmetic.values.length} collected · Each ball includes its world.',
                            '${p.ownedPlatforms.length} of ${PlatformStyle.values.length} collected · Same handling. Fresh style.',
                            'Permanent Infinite upgrades. Extra hearts apply to your next run; duration upgrades apply to pickups you collect.',
                          ][category],
                          style: const TextStyle(
                            color: menuMuted,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (!p.available)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Device storage is unavailable; progress may not save.',
                              style: TextStyle(color: menuGold, fontSize: 11),
                            ),
                          ),
                        if (category == 0)
                          for (final b in ballShopOrder)
                            galleryItem(
                              id: 'buy-${b.name}',
                              worldBall: b,
                              name: b.label,
                              description:
                                  '${b.description}\n${b.magnetLabel} · Infinite',
                              cost: b.cost,
                              bonus: b.scoreBonus,
                              purchaseOnly: b.purchaseOnly,
                              example: b == BallCosmetic.steel,
                              owned: p.ownedBalls.contains(b),
                              selected: p.selectedBall == b,
                              painter: CosmeticPreview(b, animation: preview),
                              buy: () => setState(() => p.selectBall(b)),
                            ),
                        if (category == 1)
                          for (final rail in platformShopOrder)
                            galleryItem(
                              id: 'buy-platform-${rail.name}',
                              name: rail.label,
                              description: rail.description,
                              cost: rail.cost,
                              bonus: rail.scoreBonus,
                              purchaseOnly: rail.purchaseOnly,
                              example: rail == PlatformStyle.classic,
                              owned: p.ownedPlatforms.contains(rail),
                              selected: p.selectedPlatform == rail,
                              painter: PlatformPreview(
                                rail,
                                animation: preview,
                              ),
                              buy: () => setState(() => p.selectPlatform(rail)),
                            ),
                        if (category == 2)
                          for (final upgrade in SurvivalUpgrade.values)
                            collectionUpgrade(upgrade),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget collectionUpgrade(SurvivalUpgrade upgrade) {
    final p = widget.profile;
    final level = p.upgradeLevel(upgrade),
        cost = upgrade.costAt(p.upgradeLevel(upgrade));
    final maxed = level >= upgrade.maxLevel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: menuPanel,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: menuGold.withAlpha(15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      switch (upgrade) {
                        SurvivalUpgrade.magnet => Icons.attractions,
                        SurvivalUpgrade.shield => Icons.shield_outlined,
                        SurvivalUpgrade.hearts =>
                          Icons.favorite_outline_rounded,
                      },
                      color: menuGold,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      upgrade.label,
                      style: const TextStyle(
                        color: menuText,
                        fontSize: 23,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  for (var i = 0; i < upgrade.maxLevel; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: i < level ? menuMint : menuLine,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Current: ${upgrade.valueLabel(level)}',
                style: const TextStyle(color: menuText, fontSize: 14),
              ),
              const SizedBox(height: 5),
              Text(
                'Maximum: ${upgrade.valueLabel(upgrade.maxLevel)}',
                style: const TextStyle(color: menuMuted, fontSize: 11),
              ),
              const SizedBox(height: 18),
              ShopPurchaseButton(
                buttonKey: ValueKey('upgrade-${upgrade.name}'),
                equipped: maxed,
                label: maxed
                    ? 'Fully upgraded'
                    : 'Upgrade to ${upgrade.valueLabel(level + 1)} · $cost coins',
                onPressed: maxed || !p.canAfford(cost)
                    ? null
                    : () => setState(() => p.buySurvivalUpgrade(upgrade)),
              ),
              if (!maxed && !p.canAfford(cost))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Need ${cost - p.wallet} more coins',
                    style: const TextStyle(color: menuMuted, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return GestureDetector(
      key: const ValueKey('shop-swipe-area'),
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => swipeDistance = 0,
      onHorizontalDragUpdate: (details) => swipeDistance += details.delta.dx,
      onHorizontalDragEnd: finishSwipe,
      child: Stack(
        children: [
          collection(),
          if (guiding)
            TutorialSpotlight(
              title: p.tutorial.step == TutorialStep.shopBall
                  ? 'Balls bring their world'
                  : 'Platforms add points',
              icon: p.tutorial.step == TutorialStep.shopBall
                  ? Icons.sports_baseball_rounded
                  : Icons.horizontal_rule_rounded,
              lesson: p.tutorial.step.lesson,
              lessons: TutorialStep.lessons,
              message: p.tutorial.step == TutorialStep.shopBall
                  ? 'Each ball comes with its own background, and stronger balls boost Infinite points. Tap Equip on your Steel starter.'
                  : 'Platforms boost Infinite points too. Equip your starter rail, then browse the gear and upgrades.',
              blockOutside: true,
              onSkip: () {
                widget.onSkipTutorial?.call();
                setState(() {});
              },
              targets: (layer) {
                final rect = tutorialTarget(exampleKey, layer);
                return [if (rect != null) rect];
              },
            ),
        ],
      ),
    );
  }
}
