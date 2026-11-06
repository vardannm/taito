import 'ui_audio.dart';
import 'menu_design.dart';
import 'responsive_layout.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'daily_prizes.dart';
import 'infinite_coin_chip.dart';
import 'profile.dart';

class DailyPrizeSheet extends StatefulWidget {
  const DailyPrizeSheet({super.key, required this.profile});
  final PlayerProfile profile;

  @override
  State<DailyPrizeSheet> createState() => _DailyPrizeSheetState();
}

class _DailyPrizeSheetState extends State<DailyPrizeSheet> {
  bool busy = false;
  String? message;
  late final Timer timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  Future<void> claim({bool platform = false}) async {
    setState(() => busy = true);
    final reward = await widget.profile.claimDailyPrize(platform: platform);
    if (!mounted) return;
    setState(() {
      busy = false;
      message = reward == null
          ? 'Already claimed today.'
          : 'You received $reward!';
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final now = DateTime.now();
    final ready = p.dailyPrizes.canClaim(now);
    final day = p.dailyPrizes.displayedDay(now);
    final firstDay = p.dailyPrizes.firstDisplayedDay(now);
    final tablet = usesWideStage(MediaQuery.sizeOf(context));
    final heading = MenuHeading(
      'Daily prizes',
      eyebrow: 'COME BACK. COLLECT MORE.',
      trailing: tablet
          ? MenuBackButton(
              icon: Icons.close_rounded,
              tooltip: 'Close daily prizes',
              onPressed: () => Navigator.pop(context),
            )
          : MenuIconButton(
              icon: Icons.close,
              tooltip: 'Close daily prizes',
              onPressed: () => Navigator.pop(context),
            ),
    );
    final days = <Widget>[
      const Text(
        'A gift each day. Gear every 5 days. Missed days keep your progress.',
      ),
      const SizedBox(height: 16),
      for (var i = firstDay; i < firstDay + DailyPrizes.rewardInterval; i++)
        Card(
          color: i == day ? const Color(0xFF2C4140) : menuPanel,
          child: ListTile(
            minVerticalPadding: tablet ? 18 : null,
            minLeadingWidth: tablet ? 40 : null,
            leading: i < day || (i == day && !ready)
                ? Icon(Icons.check_circle_rounded, size: tablet ? 32 : null)
                : DailyPrizes.isGearDay(i)
                ? Icon(Icons.redeem_rounded, size: tablet ? 32 : null)
                : CoinIcon(size: tablet ? 32 : 22),
            title: Text(
              'Day $i',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              DailyPrizes.isGearDay(i)
                  ? 'Choose a ball or platform'
                  : '${DailyPrizes.coinReward(i)} coins',
            ),
            trailing: i == day ? Text(ready ? 'TODAY' : 'CLAIMED') : null,
          ),
        ),
    ];
    final actions = <Widget>[
      if (message != null) Text(message!, semanticsLabel: message),
      if (!p.available)
        const Text(
          'Device storage could not save your prize. It is available for this session.',
        ),
      if (ready &&
          DailyPrizes.isGearDay(day) &&
          (p.prizeBall != null || p.prizePlatform != null)) ...[
        if (p.prizeBall != null)
          FilledButton.icon(
            key: const ValueKey('daily-claim-ball'),
            style: FilledButton.styleFrom(
              minimumSize: Size(0, tablet ? 72 : 56),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            icon: const Icon(Icons.sports_baseball_outlined),
            onPressed: uiAction(context, busy ? null : () => claim()),
            label: Text(
              'CLAIM ${p.prizeBall!.label.toUpperCase()} BALL',
              textAlign: TextAlign.center,
            ),
          ),
        if (p.prizeBall != null && p.prizePlatform != null)
          const SizedBox(height: 16),
        if (p.prizePlatform != null)
          FilledButton.icon(
            key: const ValueKey('daily-claim-platform'),
            style: FilledButton.styleFrom(
              minimumSize: Size(0, tablet ? 72 : 56),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            icon: const Icon(Icons.horizontal_rule_rounded),
            onPressed: uiAction(
              context,
              busy ? null : () => claim(platform: true),
            ),
            label: Text(
              'CLAIM ${p.prizePlatform!.label.toUpperCase()} PLATFORM',
              textAlign: TextAlign.center,
            ),
          ),
      ] else
        FilledButton(
          style: tablet
              ? FilledButton.styleFrom(
                  minimumSize: const Size(0, 72),
                  textStyle: const TextStyle(
                    fontFamily: 'sans-serif',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : null,
          onPressed: uiAction(context, ready && !busy ? () => claim() : null),
          child: Text(
            ready
                ? 'CLAIM ${DailyPrizes.coinReward(day)} COINS'
                : 'CLAIMED TODAY',
          ),
        ),
      if (ready &&
          DailyPrizes.isGearDay(day) &&
          p.prizeBall == null &&
          p.prizePlatform == null)
        const Text('You own all gear! Enjoy 100 coins instead.'),
      const SizedBox(height: 8),
      Text('${p.wallet} coins in your wallet', textAlign: TextAlign.center),
    ];
    return MenuSurface(
      child: SafeArea(
        child: tablet
            ? Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: days,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...actions,
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    const SizedBox(height: 8),
                    ...days,
                    const SizedBox(height: 12),
                    ...actions,
                  ],
                ),
              ),
      ),
    );
  }
}
