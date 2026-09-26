import 'game.dart';
import 'levels.dart';
import 'profile.dart';
import 'rewards.dart';

class NextGoal {
  const NextGoal(this.title, this.detail, this.mode, this.level, {this.date});
  final String title, detail;
  final GameMode mode;
  final int level;
  final DateTime? date;
  static NextGoal forProfile(PlayerProfile p) {
    // Recommend only reachable boards; improve stars to unlock more of them.
    for (final bit in [1, 2, 4]) {
      for (var offset = 0; offset < ClassicLevels.count; offset++) {
        final level = (p.classicLevel - 1 + offset) % ClassicLevels.count + 1;
        if (!p.isClassicLevelUnlocked(level)) continue;
        if (p.levelRecord(level).starMask & bit != 0) continue;
        final title = bit == 1
            ? 'Clear level $level'
            : bit == 2
            ? 'Clear level $level without a miss'
            : 'Earn level $level’s time star';
        final probe = BalanceGame()
          ..setControlMode(p.controlMode)
          ..start(levelNumber: level);
        return NextGoal(
          title,
          bit == 1
              ? 'Reach all ten glowing holes with ${p.controlMode.label} controls.'
              : bit == 2
              ? 'Finish all ten holes without losing a ball.'
              : 'Finish within ${formatRunTime(probe.targetTime)}. Pause time does not count.',
          GameMode.classic,
          level,
        );
      }
    }
    return NextGoal(
      'Beat today’s Daily record',
      'All ${ClassicLevels.count * 3} stars earned with these controls. Try today’s shared board.',
      GameMode.daily,
      15,
      date: DailyChallenge.day(DateTime.now()),
    );
  }
}
