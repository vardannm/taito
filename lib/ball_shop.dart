import 'package:flutter/material.dart';
import 'ball_cosmetics.dart';
import 'ball_painter.dart';
import 'platforms.dart';
import 'platform_painter.dart';
import 'board_painter.dart';
import 'profile.dart';

class BallShop extends StatefulWidget {
  const BallShop({super.key, required this.profile});
  final PlayerProfile profile;
  @override
  State<BallShop> createState() => _BallShopState();
}

class _BallShopState extends State<BallShop> {
  bool platforms = false;
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
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
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
                      selected || (!owned && !widget.profile.canAfford(cost))
                      ? null
                      : buy,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(
                    selected
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
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Gear Shop',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
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
          if (p.unlimitedCoins)
            const Text(
              'TEST BUILD - Unlimited coins',
              style: TextStyle(fontWeight: FontWeight.w800, color: orange),
            ),
          const SizedBox(height: 10),
          Text(
            'Your gear: x${formatBoost(p.equipmentMultiplier)} points',
            key: const ValueKey('gear-total'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const Text(
            'Ball + platform bonuses add to the base x1. They multiply Infinite distance and combo rewards. Handling stays the same.',
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
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Balls'),
                icon: Icon(Icons.sports_baseball),
              ),
              ButtonSegment(
                value: true,
                label: Text('Platforms'),
                icon: Icon(Icons.horizontal_rule),
              ),
            ],
            selected: {platforms},
            onSelectionChanged: (values) =>
                setState(() => platforms = values.first),
          ),
          const SizedBox(height: 16),
          if (!platforms)
            for (final b in BallCosmetic.values)
              item(
                id: 'buy-${b.name}',
                name: b.label,
                description: b.description,
                cost: b.cost,
                bonus: b.scoreBonus,
                owned: p.ownedBalls.contains(b),
                selected: p.selectedBall == b,
                painter: CosmeticPreview(b),
                buy: () => setState(() => p.selectBall(b)),
              ),
          if (platforms)
            for (final rail in PlatformStyle.values)
              item(
                id: 'buy-platform-${rail.name}',
                name: rail.label,
                description: rail.description,
                cost: rail.cost,
                bonus: rail.scoreBonus,
                owned: p.ownedPlatforms.contains(rail),
                selected: p.selectedPlatform == rail,
                painter: PlatformPreview(rail),
                buy: () => setState(() => p.selectPlatform(rail)),
              ),
        ],
      ),
    );
  }
}
