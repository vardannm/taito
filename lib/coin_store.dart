import 'package:flutter/material.dart';

import 'achievement_sheet.dart';
import 'daily_prize_sheet.dart';
import 'infinite_coin_chip.dart';
import 'menu_design.dart';
import 'premium_menu.dart' show formatMenuScore;
import 'profile.dart';

/// Only actual gameplay rewards are offered here. Paid packs require billing,
/// verified delivery and localized store prices before they can be shown.
Future<void> showCoinStore(
  BuildContext context,
  PlayerProfile profile, {
  int? needed,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: menuBackground,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxWidth: 640,
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
  late final int? target = widget.needed == null
      ? null
      : widget.profile.wallet + widget.needed!;
  Future<void> rewards(Widget child) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: menuBackground,
      constraints: BoxConstraints(
        maxWidth: 640,
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      builder: (_) => child,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final needed = target == null ? 0 : (target! - p.wallet).clamp(0, target!);
    final dailyReady = p.dailyPrizes.canClaim(DateTime.now());
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 10, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Earn coins',
                    style: TextStyle(
                      color: menuText,
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                MenuIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close coin store',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MenuPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'YOUR WALLET',
                          style: TextStyle(
                            color: menuMuted,
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const CoinIcon(size: 30),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                p.unlimitedCoins
                                    ? '∞'
                                    : formatMenuScore(p.wallet),
                                key: const ValueKey('coin-store-wallet'),
                                style: const TextStyle(
                                  color: menuGold,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (target != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            needed > 0
                                ? '${formatMenuScore(needed)} more coins for your item'
                                : 'You have enough for your item!',
                            style: const TextStyle(
                              color: menuMint,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  MenuAction(
                    title: 'Daily prize',
                    icon: Icons.card_giftcard_rounded,
                    subtitle: dailyReady
                        ? 'Your next reward is ready to claim.'
                        : 'Claimed today. Come back after the daily reset.',
                    trailing: dailyReady
                        ? const MenuPill('READY', accent: menuMint)
                        : null,
                    onTap: () => rewards(DailyPrizeSheet(profile: p)),
                  ),
                  MenuAction(
                    title: 'Achievement rewards',
                    icon: Icons.emoji_events_outlined,
                    subtitle: p.achievementsReady > 0
                        ? '${p.achievementsReady} rewards ready to collect.'
                        : 'Turn your milestones into coins.',
                    onTap: () => rewards(AchievementSheet(profile: p)),
                  ),
                  const SizedBox(height: 8),
                  const MenuSection('Earn while you play'),
                  const SizedBox(height: 12),
                  const _EarnRow(
                    Icons.all_inclusive_rounded,
                    'Infinite',
                    'Collect brass coins as you climb. Keep them when the run ends.',
                  ),
                  const _EarnRow(
                    Icons.star_outline_rounded,
                    'Classic',
                    'Win a level to earn its coin prize.',
                  ),
                  const _EarnRow(
                    Icons.merge_rounded,
                    'Number Merge',
                    'Reach 2,048 and finish the run for a coin reward.',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    key: const ValueKey('billing-unavailable'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: menuRaised,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Coin purchases are unavailable in this version. You can earn and spend coins through gameplay.',
                      style: TextStyle(
                        color: menuMuted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to browsing'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarnRow extends StatelessWidget {
  const _EarnRow(this.icon, this.title, this.detail);
  final IconData icon;
  final String title, detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: menuGold, size: 22),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: menuText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
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

class WalletButton extends StatelessWidget {
  const WalletButton({super.key, required this.profile, this.onClosed});
  final PlayerProfile profile;
  final VoidCallback? onClosed;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Get coins',
    child: Semantics(
      button: true,
      label:
          'Wallet, ${profile.unlimitedCoins ? 'unlimited' : profile.wallet} coins. Ways to earn coins.',
      excludeSemantics: true,
      child: Material(
        color: menuGold.withAlpha(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: menuGold.withAlpha(65)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            await showCoinStore(context, profile);
            onClosed?.call();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinIcon(size: 20),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    profile.unlimitedCoins
                        ? '∞'
                        : formatMenuScore(profile.wallet),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: menuGold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.add_circle_rounded, color: menuGold, size: 20),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

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
  Widget build(BuildContext context) => TextButton(
    onPressed: () async {
      await showCoinStore(context, profile, needed: needed);
      onClosed?.call();
    },
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      minimumSize: const Size(48, 48),
    ),
    child: Text(
      'Need ${formatMenuScore(needed)} more · Earn coins',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 11, height: 1.5),
    ),
  );
}
