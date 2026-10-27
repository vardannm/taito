import 'menu_design.dart';
import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'game.dart';
import 'levels.dart';
import 'profile.dart';
import 'rewards.dart';

class StarRow extends StatelessWidget {
  const StarRow(
    this.mask, {
    super.key,
    this.size = 18,
    this.dark = false,
    this.count = 3,
  });
  final int mask, count;
  final double size;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    // Earned stars fill from the left whichever goals earned them; the goal
    // list beside a result says which ones they were.
    final earned = LevelRecord.starCount(mask & ((1 << count) - 1));
    return Semantics(
      label: '$earned of $count stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            Icon(
              i < earned ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i < earned
                  ? (dark ? brass : const Color(0xFFA76D20))
                  : (dark ? cream.withAlpha(80) : ink.withAlpha(80)),
            ),
        ],
      ),
    );
  }
}

class MasteryResult extends StatelessWidget {
  const MasteryResult({
    super.key,
    required this.game,
    required this.record,
    required this.unlocks,
  });
  final BalanceGame game;
  final LevelRecord record;
  final List<CabinetStyle> unlocks;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 14),
      StarRow(
        game.earnedStarMask | (record.starMask & 8),
        size: 34,
        dark: true,
        count: game.mode == GameMode.classic ? 4 : 3,
      ),
      const SizedBox(height: 8),
      for (final (bit, label) in [
        (1, 'Finish the board'),
        (2, 'Finish without a miss'),
        (4, 'Finish in ${formatRunTime(game.targetTime)} active time'),
        if (game.mode == GameMode.classic)
          (
            8,
            game.levelStarAlreadyOwned
                ? 'Bonus star already collected'
                : 'Collect the bonus star',
          ),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ((game.earnedStarMask | (record.starMask & 8)) & bit) != 0
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 15,
                color:
                    ((game.earnedStarMask | (record.starMask & 8)) & bit) != 0
                    ? brass
                    : const Color(0xFFB5C5BB),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        ((game.earnedStarMask | (record.starMask & 8)) & bit) !=
                            0
                        ? brass
                        : const Color(0xFFB5C5BB),
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 10),
      Text(
        '${formatRunTime(game.elapsed)} active time' +
            (game.mode == GameMode.classic
                ? ''
                : '  ·  ${game.coinsCollected}/${game.coins.length} coins'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: cream),
      ),
      const SizedBox(height: 5),
      Text(
        'Saved: ${record.stars}/${game.mode == GameMode.classic ? 4 : 3} stars' +
            (game.mode == GameMode.classic
                ? ''
                : '  ·  Best ${record.bestScore}') +
            (record.bestTime == null
                ? ''
                : '  ·  ${formatRunTime(record.bestTime!)}'),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: cream.withAlpha(170)),
      ),
      for (final style in unlocks)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            '${style.title} unlocked in Cabinet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: brass,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
    ],
  );
}

class DailyCard extends StatelessWidget {
  const DailyCard({
    super.key,
    required this.date,
    required this.profile,
    required this.onPlay,
  });
  final DateTime date;
  final PlayerProfile profile;
  final VoidCallback onPlay;
  @override
  Widget build(BuildContext context) {
    final record = profile.dailyRecord(DailyChallenge.key(date));
    final preview = BalanceGame()
      ..setControlMode(profile.controlMode)
      ..start(gameMode: GameMode.daily, challengeDate: date)
      ..cabinet = profile.cabinet;
    return MenuSurface(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MenuHeading(
                'A fresh board. One day.',
                eyebrow: 'DAILY CHALLENGE',
              ),
              const SizedBox(height: 6),
              Text(
                '${DailyChallenge.key(date)} · UTC',
                style: const TextStyle(
                  color: menuText,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: CustomPaint(
                  painter: BoardPainter(preview, reducedMotion: true),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ten targets. Three balls. Same layout on every retry. A new board arrives at midnight UTC.',
                style: TextStyle(color: menuMuted, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Time star: ${formatRunTime(preview.targetTime)} active time',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              StarRow(record.starMask, dark: true),
              Text(
                'Your best: ${record.bestScore} · ${record.attempts} attempts',
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                '${profile.controlMode.label} records on this device',
                style: TextStyle(fontSize: 11, color: menuMuted),
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: onPlay, child: const Text('PLAY DAILY')),
            ],
          ),
        ),
      ),
    );
  }
}

class CabinetPicker extends StatelessWidget {
  const CabinetPicker({
    super.key,
    required this.profile,
    required this.onSelected,
    this.embedded = false,
  });
  final PlayerProfile profile;
  final ValueChanged<CabinetStyle> onSelected;
  final bool embedded;
  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: embedded,
    physics: embedded ? const NeverScrollableScrollPhysics() : null,
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
    children: [
      const MenuHeading('Make it yours.', eyebrow: 'CABINET STYLES'),
      const SizedBox(height: 6),
      Text(
        '${profile.totalStars} / ${ClassicLevels.count * 4} Classic stars · identical handling in every style',
        style: TextStyle(fontSize: 12, color: menuMuted),
      ),
      const SizedBox(height: 16),
      for (final style in CabinetStyle.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: menuPanel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: profile.cabinet == style ? menuGold : menuLine,
                width: profile.cabinet == style ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('cabinet-${style.name}'),
              onTap: profile.isUnlocked(style) ? () => onSelected(style) : null,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      height: 100,
                      child: CustomPaint(
                        painter: BoardPainter(
                          BalanceGame()..cabinet = style,
                          reducedMotion: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            style.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            profile.isUnlocked(style)
                                ? (profile.cabinet == style
                                      ? 'Equipped'
                                      : 'Tap to equip')
                                : 'Earn ${style.requiredStars} Classic stars',
                            style: TextStyle(fontSize: 12, color: menuMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      profile.cabinet == style
                          ? Icons.check_circle_rounded
                          : profile.isUnlocked(style)
                          ? Icons.arrow_forward_rounded
                          : Icons.lock_outline_rounded,
                      size: 21,
                      color: menuText,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class FinaleBriefing extends StatelessWidget {
  const FinaleBriefing({
    super.key,
    required this.game,
    required this.onPlay,
    required this.onBack,
  });
  final BalanceGame game;
  final VoidCallback onPlay, onBack;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: menuBackground.withAlpha(245),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                size: 44,
                color: brass,
              ),
              const SizedBox(height: 16),
              Text(
                ClassicLevels.definition(game.level).finaleTitle.isEmpty
                    ? 'NEW HAZARD'
                    : 'FINALE',
                style: const TextStyle(
                  color: brass,
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Level ${game.level}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: cream,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                ClassicLevels.finaleRule(game.level),
                textAlign: TextAlign.center,
                style: const TextStyle(color: cream, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Time star: ${formatRunTime(game.targetTime)} active time',
                style: const TextStyle(color: brass, fontSize: 12),
              ),
              const SizedBox(height: 22),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: menuGold,
                  foregroundColor: menuBackground,
                ),
                onPressed: onPlay,
                child: const Text('START LEVEL'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: cream),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('BACK TO LEVELS'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
