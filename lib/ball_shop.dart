import 'package:flutter/material.dart';

import 'ball_cosmetics.dart';
import 'ball_world.dart';
import 'coin_store.dart';
import 'menu_design.dart';
import 'onboarding.dart';
import 'platforms.dart';
import 'profile.dart';
import 'shop_design.dart';
import 'shop_showcase.dart';
import 'tutorial_spotlight.dart';

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
  late int ballIndex, platformIndex;
  late final PageController balls, platforms;
  final exampleKey = GlobalKey();
  bool get guiding =>
      !widget.profile.tutorialSeen &&
      [
        TutorialStep.shopBall,
        TutorialStep.shopPlatform,
      ].contains(widget.profile.tutorial.step);
  bool get ballLesson =>
      guiding && widget.profile.tutorial.step == TutorialStep.shopBall;
  bool get platformLesson =>
      guiding && widget.profile.tutorial.step == TutorialStep.shopPlatform;
  late final AnimationController preview = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ballIndex = guiding
        ? 0
        : ballShopOrder.indexOf(widget.profile.selectedBall);
    platformIndex = guiding
        ? 0
        : platformShopOrder.indexOf(widget.profile.selectedPlatform);
    balls = PageController(initialPage: ballIndex);
    platforms = PageController(initialPage: platformIndex);
    revealExample();
  }

  void revealExample() {
    if (!guiding) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = exampleKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(target, alignment: .55).then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  void equippedExample() {
    if (!guiding) return;
    setState(() {
      widget.profile.tutorial.step = ballLesson
          ? TutorialStep.shopPlatform
          : TutorialStep.shopBrowse;
    });
    widget.onTutorialChanged?.call();
    revealExample();
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
    balls.dispose();
    platforms.dispose();
    super.dispose();
  }

  void browse(PageController controller, int index) {
    if (guiding || !controller.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpToPage(index);
    } else {
      controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget action({
    required String id,
    required bool owned,
    required bool equipped,
    required int cost,
    required VoidCallback buy,
    required bool lesson,
  }) {
    final button = ShopPurchaseButton(
      buttonKey: ValueKey(id),
      equipped: equipped && !lesson,
      price: owned ? null : cost,
      label: lesson
          ? 'Equip'
          : equipped
          ? 'Equipped'
          : owned
          ? 'Equip'
          : formatShopPrice(cost),
      onPressed: lesson
          ? () {
              buy();
              equippedExample();
            }
          : equipped || (!owned && !widget.profile.canAfford(cost))
          ? null
          : buy,
    );
    return lesson ? KeyedSubtree(key: exampleKey, child: button) : button;
  }

  Widget? shortfall(String id, int cost, bool owned) =>
      owned || widget.profile.canAfford(cost)
      ? null
      : GetCoinsLink(
          key: ValueKey('get-coins-$id'),
          profile: widget.profile,
          needed: cost - widget.profile.wallet,
          onClosed: refresh,
        );
  void refresh() {
    if (mounted) setState(() {});
  }

  Widget ballShowcase() {
    final p = widget.profile, ball = ballShopOrder[ballIndex];
    final owned = p.ownedBalls.contains(ball);
    return ShopShowcase(
      key: const ValueKey('ball-showcase'),
      title: 'BALLS',
      index: ballIndex,
      count: ballShopOrder.length,
      name: ball.label,
      subtitle: '${BallWorld.of(ball).name} · World included',
      bonus: ball.scoreBonus,
      owned: owned,
      cost: ball.cost,
      premium: ball.purchaseOnly,
      controller: balls,
      locked: guiding,
      onBrowse: (index) => browse(balls, index),
      onChanged: (index) => setState(() => ballIndex = index),
      itemBuilder: (context, index) => ShopBallArtwork(
        ball: ballShopOrder[index],
        animation: MediaQuery.disableAnimationsOf(context) ? null : preview,
      ),
      magnet: ball.magnetRadius > 0
          ? '${ball.magnetLabel} · ${ball.magnetRadius.round()} radius'
          : null,
      action: action(
        id: 'buy-${ball.name}',
        owned: owned,
        equipped: p.selectedBall == ball,
        cost: ball.cost,
        lesson: ballLesson,
        buy: () => setState(() => p.selectBall(ball)),
      ),
      footer: shortfall('buy-${ball.name}', ball.cost, owned),
    );
  }

  Widget platformShowcase() {
    final p = widget.profile, rail = platformShopOrder[platformIndex];
    final owned = p.ownedPlatforms.contains(rail);
    return ShopShowcase(
      key: const ValueKey('platform-showcase'),
      title: 'PLATFORMS',
      index: platformIndex,
      count: platformShopOrder.length,
      name: rail.label,
      subtitle: rail.description,
      bonus: rail.scoreBonus,
      owned: owned,
      cost: rail.cost,
      premium: rail.purchaseOnly,
      compact: true,
      controller: platforms,
      locked: guiding,
      onBrowse: (index) => browse(platforms, index),
      onChanged: (index) => setState(() => platformIndex = index),
      itemBuilder: (context, index) => ShopRailArtwork(
        style: platformShopOrder[index],
        animation: MediaQuery.disableAnimationsOf(context) ? null : preview,
      ),
      action: action(
        id: 'buy-platform-${rail.name}',
        owned: owned,
        equipped: p.selectedPlatform == rail,
        cost: rail.cost,
        lesson: platformLesson,
        buy: () => setState(() => p.selectPlatform(rail)),
      ),
      footer: shortfall('buy-platform-${rail.name}', rail.cost, owned),
    );
  }

  Widget upgrades() => ShopUpgradePanel(
    profile: widget.profile,
    onBuy: (upgrade) =>
        setState(() => widget.profile.buySurvivalUpgrade(upgrade)),
    onWalletChanged: refresh,
  );

  Widget collection() => MenuSurface(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.7),
          radius: 1.2,
          colors: [Color(0xFF20383C), menuBackground],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            ShopHeader(profile: widget.profile, onWalletChanged: refresh),
            Expanded(
              child: LayoutBuilder(
                builder: (context, bounds) => SingleChildScrollView(
                  key: const ValueKey('shop-scroll'),
                  padding: EdgeInsets.fromLTRB(
                    bounds.maxWidth < 360 ? 16 : 24,
                    4,
                    bounds.maxWidth < 360 ? 16 : 24,
                    24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!widget.profile.available)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Device storage is unavailable; progress may not save.',
                                style: TextStyle(color: menuGold, fontSize: 11),
                              ),
                            ),
                          if (bounds.maxWidth >= 760)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: ballShowcase()),
                                const SizedBox(width: 32),
                                Expanded(
                                  child: Column(
                                    children: [
                                      platformShowcase(),
                                      const SizedBox(height: 20),
                                      upgrades(),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            ballShowcase(),
                            const SizedBox(height: 20),
                            platformShowcase(),
                            const SizedBox(height: 20),
                            upgrades(),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            'YOUR LOADOUT  /  ×${formatBoost(widget.profile.equipmentMultiplier)} INFINITE POINTS',
                            key: const ValueKey('gear-total'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: menuMuted,
                              fontSize: 10,
                              letterSpacing: 1,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Stack(
    key: const ValueKey('shop-swipe-area'),
    children: [
      collection(),
      if (guiding)
        TutorialSpotlight(
          title: ballLesson
              ? 'Balls bring their world'
              : 'Platforms add points',
          icon: ballLesson
              ? Icons.sports_baseball_rounded
              : Icons.horizontal_rule_rounded,
          lesson: widget.profile.tutorial.step.lesson,
          lessons: TutorialStep.lessons,
          message: ballLesson
              ? 'Each ball comes with its own background, and stronger balls boost Infinite points. Tap Equip on your Steel starter.'
              : 'Platforms boost Infinite points too. Equip your starter rail, then use the arrows or swipe to browse your gear.',
          blockOutside: true,
          onSkip: () {
            widget.onSkipTutorial?.call();
            refresh();
          },
          targets: (layer) {
            final rect = tutorialTarget(exampleKey, layer);
            return [if (rect != null) rect];
          },
        ),
    ],
  );
}
