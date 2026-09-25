import 'onboarding.dart';
import 'tutorial_spotlight.dart';
import 'package:flutter/material.dart';
import 'ball_cosmetics.dart';
import 'ball_painter.dart';
import 'platforms.dart';
import 'platform_painter.dart';
import 'board_painter.dart';
import 'profile.dart';
import 'mastery_widgets.dart';

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
    with SingleTickerProviderStateMixin {
  int category = 0;
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
    if (widget.profile.tutorial.step == TutorialStep.shopPlatform) category = 1;
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
  }

  late final AnimationController preview = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      preview.stop();
    } else {
      preview.repeat();
    }
  }

  @override
  void dispose() {
    preview.dispose();
    super.dispose();
  }

  Widget item({
    required String id,
    required String name,
    required String description,
    required int cost,
    required double bonus,
    required bool owned,
    required bool selected,
    required CustomPainter painter,
    required VoidCallback buy,
    bool example = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      key: example ? exampleKey : null,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFDFE8DC) : Colors.white.withAlpha(160),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? ink : brass.withAlpha(100)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(width: 58, height: 64, child: CustomPaint(painter: painter)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(description, style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 5),
                if (!example)
                  Text(
                    bonus == 0
                        ? 'Base equipment'
                        : '+${formatBoost(bonus)}x Infinite points',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                const SizedBox(height: 6),
                FilledButton(
                  key: ValueKey(id),
                  onPressed:
                      (selected && !example) ||
                          (!owned && !widget.profile.canAfford(cost))
                      ? null
                      : () {
                          buy();
                          if (example) equippedExample();
                        },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(
                    selected && !example
                        ? 'Equipped'
                        : owned
                        ? 'Equip'
                        : '$cost coins',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Stack(
      children: [
        SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Gear Shop',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Done shopping',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  const Icon(Icons.toll, color: orange),
                  const SizedBox(width: 6),
                  Text(
                    p.unlimitedCoins ? '∞' : '${p.wallet}',
                    key: const ValueKey('wallet'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (guiding && category == 0)
                item(
                  id: 'buy-steel',
                  name: BallCosmetic.steel.label,
                  description: 'Free starter ball',
                  cost: 0,
                  bonus: 0,
                  owned: true,
                  selected: p.selectedBall == BallCosmetic.steel,
                  painter: CosmeticPreview(
                    BallCosmetic.steel,
                    animation: preview,
                  ),
                  buy: () => setState(() => p.selectBall(BallCosmetic.steel)),
                  example: true,
                ),
              if (guiding && category == 1)
                item(
                  id: 'buy-platform-classic',
                  name: PlatformStyle.classic.label,
                  description: 'Free starter platform',
                  cost: 0,
                  bonus: 0,
                  owned: true,
                  selected: p.selectedPlatform == PlatformStyle.classic,
                  painter: PlatformPreview(
                    PlatformStyle.classic,
                    animation: preview,
                  ),
                  buy: () =>
                      setState(() => p.selectPlatform(PlatformStyle.classic)),
                  example: true,
                ),
              if (p.unlimitedCoins)
                const Text(
                  'TEST BUILD - Unlimited coins',
                  style: TextStyle(fontWeight: FontWeight.w800, color: orange),
                ),
              const SizedBox(height: 10),
              Text(
                'Your gear: x${formatBoost(p.equipmentMultiplier)} points',
                key: const ValueKey('gear-total'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              if (!guiding)
                const Text(
                  'Ball + platform bonuses add to the base x1. They multiply Infinite distance and combo rewards. Magnetic balls also collect nearby rewards in Infinite. Handling stays the same.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              const SizedBox(height: 6),
              Text(
                p.available
                    ? 'Coins and owned gear save on this device.'
                    : 'Device storage is unavailable; progress may not save.',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final entry in [
                    'Balls',
                    'Platforms',
                    'Cabinet Styles',
                  ].asMap().entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: category == entry.key,
                      onSelected: guiding
                          ? null
                          : (_) => setState(() => category = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (!guiding && category == 0)
                for (final b in BallCosmetic.values)
                  item(
                    id: 'buy-${b.name}',
                    example: guiding && b == BallCosmetic.steel,
                    name: b.label,
                    description:
                        '${b.description}\n${b.magnetLabel} · Infinite',
                    cost: b.cost,
                    bonus: b.scoreBonus,
                    owned: p.ownedBalls.contains(b),
                    selected: p.selectedBall == b,
                    painter: CosmeticPreview(b, animation: preview),
                    buy: () => setState(() => p.selectBall(b)),
                  ),
              if (!guiding && category == 1)
                for (final rail in PlatformStyle.values)
                  item(
                    id: 'buy-platform-${rail.name}',
                    example: guiding && rail == PlatformStyle.classic,
                    name: rail.label,
                    description: rail.description,
                    cost: rail.cost,
                    bonus: rail.scoreBonus,
                    owned: p.ownedPlatforms.contains(rail),
                    selected: p.selectedPlatform == rail,
                    painter: PlatformPreview(rail, animation: preview),
                    buy: () => setState(() => p.selectPlatform(rail)),
                  ),
              if (category == 2)
                CabinetPicker(
                  profile: p,
                  embedded: true,
                  onSelected: (style) {
                    setState(() => p.selectCabinet(style));
                    p.save();
                  },
                ),
            ],
          ),
        ),
        if (guiding)
          TutorialSpotlight(
            message: p.tutorial.step == TutorialStep.shopBall
                ? 'Unlock and equip different balls. Tap Equip to try.'
                : 'Customize your platform and game style. Tap Equip.',
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
    );
  }
}
