import 'dart:math' as math;
import 'infinite_difficulty.dart';

enum EncounterEnemy { snake, beetle, cricket, moth, scorpion, seedSpitter }

extension EncounterEnemyStyle on EncounterEnemy {
  int get attackStyle => switch (this) {
    EncounterEnemy.snake || EncounterEnemy.cricket => 0,
    EncounterEnemy.beetle => 1,
    EncounterEnemy.moth || EncounterEnemy.seedSpitter => 2,
    EncounterEnemy.scorpion => 3,
  };
}

/// A seeded plan belongs to one run. Score, equipment and frame rate never
/// change unlocks. Selection commits only after gameplay actually spawns it.
class EncounterDirector {
  EncounterDirector(int seed) : _random = math.Random(seed) {
    final order = EncounterEnemy.values.toList()..shuffle(_random);
    var distance =
        InfiniteDifficulty.enemyFirstUnlockMetres +
        _random.nextDouble() * InfiniteDifficulty.enemyFirstUnlockJitter;
    for (final enemy in order) {
      _unlocks[enemy] = distance.floorToDouble();
      _affinity[enemy] = .8 + _random.nextDouble() * .4;
      distance +=
          InfiniteDifficulty.enemyUnlockGapMetres +
          _random.nextDouble() * InfiniteDifficulty.enemyUnlockGapJitter;
    }
  }
  final math.Random _random;
  final _unlocks = <EncounterEnemy, double>{};
  final _affinity = <EncounterEnemy, double>{};
  final _counts = <EncounterEnemy, int>{};
  final _lastTime = <EncounterEnemy, double>{};
  final _recent = <EncounterEnemy>[];
  double nextEncounterAt = 0;
  Map<EncounterEnemy, double> get unlocks => Map.unmodifiable(_unlocks);
  double unlockMetres(EncounterEnemy enemy) => _unlocks[enemy]!;
  bool introduced(EncounterEnemy enemy) => _counts.containsKey(enemy);
  void deferUntil(double time) =>
      nextEncounterAt = math.max(nextEncounterAt, time);

  EncounterEnemy? choose({
    required double metres,
    required double elapsed,
    required Iterable<EncounterEnemy> candidates,
  }) {
    if (elapsed < nextEncounterAt) return null;
    final ready = candidates
        .where(
          (enemy) =>
              metres >= unlockMetres(enemy) &&
              (!_lastTime.containsKey(enemy) ||
                  elapsed - _lastTime[enemy]! >=
                      InfiniteDifficulty.enemyRepeatCooldownSeconds),
        )
        .toList();
    if (ready.isEmpty) return null;
    // Introduce overdue enemies before repeats. Blocked terrain is excluded by
    // the caller, so an unsafe beetle cannot starve the rest of the roster.
    final fresh = ready.where((enemy) => !introduced(enemy)).toList()
      ..sort((a, b) => unlockMetres(a).compareTo(unlockMetres(b)));
    if (fresh.isNotEmpty) return fresh.first;
    if (ready.length > 1 && _recent.isNotEmpty) ready.remove(_recent.last);
    double weight(EncounterEnemy enemy) {
      final age = ((elapsed - _lastTime[enemy]!) / 60).clamp(.5, 2.5);
      final sameStyle =
          _recent.isNotEmpty && _recent.last.attackStyle == enemy.attackStyle;
      final recent = _recent.contains(enemy);
      return _affinity[enemy]! *
          age /
          (1 + _counts[enemy]! * .15) *
          (sameStyle ? .55 : 1) *
          (recent ? .35 : 1);
    }

    var roll =
        _random.nextDouble() *
        ready.fold(0.0, (sum, enemy) => sum + weight(enemy));
    for (final enemy in ready) {
      roll -= weight(enemy);
      if (roll <= 0) return enemy;
    }
    return ready.last;
  }

  /// Returns true on the first successful introduction, never on selection.
  bool spawned(EncounterEnemy enemy, double elapsed) {
    final first = !introduced(enemy);
    _counts[enemy] = (_counts[enemy] ?? 0) + 1;
    _lastTime[enemy] = elapsed;
    _recent.add(enemy);
    if (_recent.length > 3) _recent.removeAt(0);
    return first;
  }

  void rest(double elapsed, double metres) {
    final progress = (metres / 2400).clamp(0.0, 1.0);
    final extra = InfiniteDifficulty.enemyOpeningRestBonus * (1 - progress);
    nextEncounterAt = math.max(
      nextEncounterAt,
      elapsed +
          InfiniteDifficulty.lateEnemyRestSeconds +
          extra +
          _random.nextDouble() * 5,
    );
  }
}
