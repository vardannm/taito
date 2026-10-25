import 'package:flutter/material.dart';

import 'infinite_coin_chip.dart';
import 'menu_design.dart';
import 'premium_menu.dart' show formatMenuScore;
import 'profile.dart';

/// The coin store is a placeholder until App Store and Google Play billing
/// are connected. App Review rejects purchases that do nothing, so switch
/// this off for a store submission until then.
const coinStoreVisible = true;

/// A real-money coin pack. [id] is the intended store product id; [price] is
/// a USD placeholder until the stores supply localized prices.
class CoinPack {
  const CoinPack(this.id, this.coins, this.price, {this.bonus = 0, this.tag});
  final String id;
  final int coins;
  final String price;

  /// Extra coins, in percent, over the smallest pack's rate.
  final int bonus;
  final String? tag;
}

const coinPacks = [
  CoinPack('coins_5000', 5000, r'$0.99'),
  CoinPack('coins_30000', 30000, r'$4.99', bonus: 20, tag: 'POPULAR'),
  CoinPack('coins_70000', 70000, r'$9.99', bonus: 40),
  CoinPack('coins_160000', 160000, r'$19.99', bonus: 60, tag: 'BEST VALUE'),
  CoinPack('coins_450000', 450000, r'$49.99', bonus: 80),
];

/// Opens the coin store. [needed] is how many more coins the item the player
/// was looking at costs; the smallest pack that covers it is highlighted.
Future<void> showCoinStore(
  BuildContext context,
  PlayerProfile profile, {
  int? needed,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: menuBackground,
  showDragHandle: true,
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * .92,
  ),
  builder: (_) => MenuSurface(
    child: CoinStoreSheet(profile: profile, needed: needed),
  ),
);

class CoinStoreSheet extends StatefulWidget {
  const CoinStoreSheet({super.key, required this.profile, this.needed});
  final PlayerProfile profile;
  final int? needed;
  @override
  State<CoinStoreSheet> createState() => _CoinStoreSheetState();
}

class _CoinStoreSheetState extends State<CoinStoreSheet> {
  String? notice;

  void comingSoon(String message) => setState(() => notice = message);

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final needed = widget.needed;
    final suggested = needed == null
        ? null
        : coinPacks.where((pack) => pack.coins >= needed).firstOrNull;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MenuHeading(
              'Get coins',
              eyebrow: 'COIN STORE',
              subtitle:
                  'Top up for premium balls, worlds, platforms and upgrades.',
              trailing: MenuIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Close coin store',
                onPressed: () => Navigator.pop(context),
              ),
            ),
            MenuPanel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const CoinIcon(size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MenuSection('Your wallet'),
                        const SizedBox(height: 3),
                        Text(
                          p.unlimitedCoins ? '∞' : formatMenuScore(p.wallet),
                          key: const ValueKey('coin-store-wallet'),
                          style: const TextStyle(
                            color: menuText,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (needed != null && needed > 0)
                    Flexible(
                      child: MenuPill(
                        'Need ${formatMenuScore(needed)}',
                        accent: menuMint,
                      ),
                    ),
                ],
              ),
            ),
            AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: notice == null
                  ? const SizedBox(width: double.infinity, height: 14)
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Container(
                          key: const ValueKey('coin-store-notice'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: menuMint.withAlpha(20),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: menuMint.withAlpha(90)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                color: menuMint,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  notice!,
                                  style: const TextStyle(
                                    color: menuText,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            for (final (index, pack) in coinPacks.indexed)
              _PackTile(
                pack: pack,
                tier: index,
                suggested: pack == suggested,
                onBuy: () => comingSoon(
                  'Coin packs open in an upcoming update. '
                  '${formatMenuScore(pack.coins)} coins for ${pack.price} '
                  'will be ready then. Nothing was charged.',
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Coins never expire. Prices are in USD; the store shows '
                    'your local price at checkout.',
                    style: TextStyle(color: menuMuted, fontSize: 11),
                  ),
                ),
                TextButton(
                  key: const ValueKey('restore-purchases'),
                  onPressed: () => comingSoon(
                    'Restoring purchases arrives with coin packs. '
                    'Nothing has been bought yet.',
                  ),
                  child: const Text('Restore'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({
    required this.pack,
    required this.tier,
    required this.suggested,
    required this.onBuy,
  });
  final CoinPack pack;
  final int tier;
  final bool suggested;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final tag = suggested ? 'COVERS THIS ITEM' : pack.tag;
    final lit = tag != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onBuy,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: lit
                    ? [const Color(0xFF34442F), menuPanel]
                    : [menuRaised, menuPanel],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: lit ? menuGold.withAlpha(190) : menuLine,
                width: lit ? 1.4 : 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, lit ? 10 : 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lit) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: suggested ? menuMint : menuGold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: menuBackground,
                          fontSize: 9,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 50,
                        child: _CoinPile(coins: tier + 1),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formatMenuScore(pack.coins),
                                style: const TextStyle(
                                  color: menuText,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.4,
                                ),
                              ),
                            ),
                            Text(
                              pack.bonus > 0
                                  ? 'coins · +${pack.bonus}% bonus'
                                  : 'coins',
                              style: TextStyle(
                                color: pack.bonus > 0 ? menuMint : menuMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        key: ValueKey('coin-pack-${pack.id}'),
                        onPressed: onBuy,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(84, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: Text(
                          pack.price,
                          semanticsLabel:
                              'Buy ${pack.coins} coins for ${pack.price}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pile of painted coins that grows with the pack.
class _CoinPile extends StatelessWidget {
  const _CoinPile({required this.coins});
  final int coins;
  static const spots = [
    Offset(18, 14),
    Offset(30, 20),
    Offset(6, 22),
    Offset(26, 4),
    Offset(10, 4),
  ];
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      // Back coins first, so the first coin sits in front.
      for (var i = coins.clamp(1, spots.length) - 1; i >= 0; i--)
        Positioned(
          left: spots[i].dx,
          top: spots[i].dy,
          child: CoinIcon(size: i == 0 ? 30 : 26),
        ),
    ],
  );
}

/// The Gear Shop wallet: the balance with a "+" that opens the coin store.
class WalletButton extends StatelessWidget {
  const WalletButton({super.key, required this.profile, this.onClosed});
  final PlayerProfile profile;
  final VoidCallback? onClosed;
  @override
  Widget build(BuildContext context) {
    final amount = profile.unlimitedCoins
        ? '∞'
        : formatMenuScore(profile.wallet);
    final content = Container(
      padding: EdgeInsets.fromLTRB(8, 6, coinStoreVisible ? 6 : 12, 6),
      decoration: BoxDecoration(
        color: menuGold.withAlpha(16),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: menuGold.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinIcon(size: 20),
          const SizedBox(width: 7),
          Text(
            amount,
            style: const TextStyle(
              color: menuGold,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (coinStoreVisible) ...[
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: menuGold,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 17,
                color: menuBackground,
              ),
            ),
          ],
        ],
      ),
    );
    if (!coinStoreVisible) {
      return Semantics(label: 'Wallet $amount coins', child: content);
    }
    return Tooltip(
      message: 'Get coins',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () async {
            await showCoinStore(context, profile);
            onClosed?.call();
          },
          child: content,
        ),
      ),
    );
  }
}

/// "Need 1,200 more · Get coins" under gear the player cannot afford yet.
class GetCoinsLink extends StatelessWidget {
  const GetCoinsLink({
    super.key,
    required this.profile,
    required this.needed,
    this.onClosed,
  });
  final PlayerProfile profile;
  final int needed;
  final VoidCallback? onClosed;
  @override
  Widget build(BuildContext context) {
    final label = 'Need ${formatMenuScore(needed)} more';
    if (!coinStoreVisible) {
      return Text(
        '$label coins',
        style: const TextStyle(color: menuMuted, fontSize: 11),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () async {
          await showCoinStore(context, profile, needed: needed);
          onClosed?.call();
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 36),
          visualDensity: VisualDensity.compact,
        ),
        icon: const CoinIcon(size: 16),
        label: Text(
          '$label · Get coins',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
