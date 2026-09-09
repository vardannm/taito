import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'game.dart';
import 'levels.dart';
import 'profile.dart';
import 'rewards.dart';

class StarRow extends StatelessWidget {
  const StarRow(this.mask, {super.key, this.size = 18, this.dark = false});
  final int mask;
  final double size;
  final bool dark;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${LevelRecord.starCount(mask)} of 3 stars',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            (mask & (1 << i)) != 0
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            size: size,
            color: (mask & (1 << i)) != 0
                ? (dark ? brass : const Color(0xFFA76D20))
                : (dark ? cream.withAlpha(80) : ink.withAlpha(80)),
          ),
      ],
    ),
  );
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
      StarRow(game.earnedStarMask, size: 34, dark: true),
      const SizedBox(height: 8),
      for (final (bit, label) in [
        (1, 'Finish the board'),
        (2, 'Finish without a miss'),
        (4, 'Finish in ${formatRunTime(game.targetTime)} active time'),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                (game.earnedStarMask & bit) != 0
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 15,
                color: (game.earnedStarMask & bit) != 0
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
                    color: (game.earnedStarMask & bit) != 0
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
        '${formatRunTime(game.elapsed)} active time  ·  ${game.coinsCollected}/${game.coins.length} coins',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: cream),
      ),
      const SizedBox(height: 5),
      Text(
        'Saved: ${record.stars}/3 stars  ·  Best ${record.bestScore}' +
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'A fresh board. One day.',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${DailyChallenge.key(date)} · UTC',
              style: const TextStyle(color: ink, fontFamily: 'monospace'),
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
              style: TextStyle(color: ink.withAlpha(190), height: 1.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Time star: ${formatRunTime(preview.targetTime)} active time',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            StarRow(record.starMask),
            Text(
              'Your best: ${record.bestScore} · ${record.attempts} attempts',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              '${profile.controlMode.label} records on this device',
              style: TextStyle(fontSize: 11, color: ink.withAlpha(170)),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onPlay, child: const Text('PLAY DAILY')),
          ],
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
  });
  final PlayerProfile profile;
  final ValueChanged<CabinetStyle> onSelected;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
    children: [
      const Text(
        'Make it yours.',
        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: ink),
      ),
      const SizedBox(height: 6),
      Text(
        '${profile.totalStars} / ${ClassicLevels.count * 3} Classic stars · identical handling in every style',
        style: TextStyle(fontSize: 12, color: ink.withAlpha(180)),
      ),
      const SizedBox(height: 16),
      for (final style in CabinetStyle.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: const Color(0xFFFFFAEE),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: profile.cabinet == style ? ink : ink.withAlpha(40),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: ink.withAlpha(180),
                            ),
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
                      color: ink,
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
  const FinaleBriefing({super.key, required this.game, required this.onPlay});
  final BalanceGame game;
  final VoidCallback onPlay;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: ink.withAlpha(242),
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
                'LEVEL ${game.level} · FINALE',
                style: const TextStyle(
                  color: brass,
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                game.finaleTitle,
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
                  backgroundColor: brass,
                  foregroundColor: ink,
                ),
                onPressed: onPlay,
                child: const Text('START FINALE'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
