import 'infinite_progress.dart';

/// Permanent upgrades apply to Infinite runs; levels are saved in the wallet.
enum SurvivalUpgrade { magnet, shield, hearts }

extension SurvivalUpgradeDetails on SurvivalUpgrade {
  String get label => switch (this) {
    SurvivalUpgrade.magnet => 'Magnet duration',
    SurvivalUpgrade.shield => 'Shield duration',
    SurvivalUpgrade.hearts => 'Starting hearts',
  };
  int get maxLevel => switch (this) {
    SurvivalUpgrade.magnet => 5,
    SurvivalUpgrade.shield => 5,
    SurvivalUpgrade.hearts => 3,
  };
  int costAt(int level) =>
      (this == SurvivalUpgrade.hearts ? 500 : 150) * (level + 1);
  double valueAt(int level) => switch (this) {
    SurvivalUpgrade.magnet =>
      level == 0
          ? InfiniteTuning.magnetSeconds
          : [9.0, 11.0, 13.0, 15.0, 17.0, 20.0][level],
    SurvivalUpgrade.shield => InfiniteTuning.shieldSeconds + level * 2,
    SurvivalUpgrade.hearts => InfiniteTuning.maxLives + level.toDouble(),
  };
  String valueLabel(int level) {
    final value = valueAt(level);
    final text = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return '$text ${this == SurvivalUpgrade.hearts ? 'hearts' : 'seconds'}';
  }
}
