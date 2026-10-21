import 'package:flutter/material.dart';

import 'menu_design.dart';

/// The wallet includes coins already banked during this run.
class RunCoinSummary extends StatelessWidget {
  const RunCoinSummary({
    super.key,
    required this.wallet,
    required this.collected,
    this.compact = false,
    this.unlimited = false,
  });

  final int wallet, collected;
  final bool compact, unlimited;

  @override
  Widget build(BuildContext context) => Semantics(
    label: unlimited
        ? 'Unlimited coins. Collected $collected coins this run.'
        : 'Total wallet: $wallet coins, including $collected collected this run.',
    excludeSemantics: true,
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 7 : 15,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF26362F), Color(0xFF162C30)],
        ),
        border: Border.all(color: menuGold.withAlpha(80)),
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Icon(
            Icons.monetization_on_rounded,
            color: menuGold,
            size: compact ? 19 : 30,
          ),
          SizedBox(width: compact ? 7 : 12),
          if (compact) ...[
            Text(
              unlimited ? '∞' : '$wallet',
              style: const TextStyle(
                color: menuGold,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '+$collected',
              style: const TextStyle(
                color: menuMint,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ] else ...[
            Expanded(
              child: _amount(
                'TOTAL COINS',
                unlimited ? '∞' : '$wallet',
                menuGold,
                'run-wallet-total',
              ),
            ),
            Container(
              height: 34,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: menuLine,
            ),
            Expanded(
              child: _amount(
                'THIS RUN',
                '+$collected',
                menuMint,
                'run-coins-collected',
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _amount(String title, String value, Color color, String id) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: menuMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: .6,
        ),
      ),
      const SizedBox(height: 5),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          key: ValueKey(id),
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ],
  );
}
