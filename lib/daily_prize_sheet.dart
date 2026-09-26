import 'dart:async';
import 'package:flutter/material.dart';
import 'daily_prizes.dart';
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Daily prizes',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'A gift each day. Reach Day 5 to choose a ball or platform. Missed days keep your progress.',
            ),
            const SizedBox(height: 16),
            for (var i = 1; i <= 5; i++)
              Card(
                color: i == day
                    ? const Color(0xFFF2D99B)
                    : const Color(0xFFFFFAEE),
                child: ListTile(
                  leading: Icon(
                    i < day || (i == day && !ready)
                        ? Icons.check_circle_rounded
                        : i == 5
                        ? Icons.redeem_rounded
                        : Icons.toll_rounded,
                  ),
                  title: Text(
                    'Day $i',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    i == 5
                        ? 'Choose a ball or platform'
                        : '${DailyPrizes.coins[i - 1]} coins',
                  ),
                  trailing: i == day ? Text(ready ? 'TODAY' : 'CLAIMED') : null,
                ),
              ),
            const SizedBox(height: 12),
            if (message != null) Text(message!, semanticsLabel: message),
            if (!p.available)
              const Text(
                'Device storage could not save your prize. It is available for this session.',
              ),
            if (ready &&
                day == 5 &&
                (p.prizeBall != null || p.prizePlatform != null)) ...[
              if (p.prizeBall != null)
                FilledButton(
                  onPressed: busy ? null : () => claim(),
                  child: Text('CLAIM ${p.prizeBall!.label.toUpperCase()} BALL'),
                ),
              if (p.prizePlatform != null)
                FilledButton(
                  onPressed: busy ? null : () => claim(platform: true),
                  child: Text(
                    'CLAIM ${p.prizePlatform!.label.toUpperCase()} PLATFORM',
                  ),
                ),
            ] else
              FilledButton(
                onPressed: ready && !busy ? () => claim() : null,
                child: Text(
                  ready
                      ? 'CLAIM ${day == 5 ? 100 : DailyPrizes.coins[day - 1]} COINS'
                      : 'CLAIMED TODAY',
                ),
              ),
            if (ready &&
                day == 5 &&
                p.prizeBall == null &&
                p.prizePlatform == null)
              const Text('You own all gear! Enjoy 100 coins instead.'),
            const SizedBox(height: 8),
            Text(
              '${p.wallet} coins in your wallet',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Resets at midnight UTC. A new five-day track starts after Day 5. Equip prizes in the Gear Shop.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
