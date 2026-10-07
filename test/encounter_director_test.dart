import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/encounter_director.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/late_enemies.dart';

void main() {
  test('all six kinds can actually be the first encounter around 1000m', () {
    final seen = <EncounterEnemy>{};
    for (var seed = 0; seed < 100; seed++) {
      final game = BalanceGame(seed: seed)
        ..start(gameMode: GameMode.infinite)
        ..mazeSectionsEnabled = false
        ..maxHeight = 10800
        ..board.clear();
      game.step(1 / 120);
      if (game.snakes.isNotEmpty) seen.add(EncounterEnemy.snake);
      if (game.lateEnemy != null) seen.add(game.lateEnemy!.kind.encounterKind);
    }
    expect(seen, containsAll(EncounterEnemy.values));
  });

  test('blocked beetle escape routes allow another unlocked enemy', () {
    final game = BalanceGame(seed: 7)
      ..start(gameMode: GameMode.infinite)
      ..mazeSectionsEnabled = false
      ..snakeEncountersEnabled = false
      ..maxHeight = 50000
      ..board.clear();
    final turnY = game.ballY - game.ascentSpeed * .65;
    game.board.addAll([Hole(110, turnY), Hole(250, turnY)]);
    game.step(1 / 120);
    expect(game.lateEnemy, isNotNull);
    expect(game.lateEnemy!.kind, isNot(LateEnemyKind.beetle));
  });
  test(
    'seeded plans vary every enemy position and keep distance gaps bounded',
    () {
      final firstKinds = <EncounterEnemy>{};
      final ranks = <EncounterEnemy, Set<int>>{};
      for (var seed = 0; seed < 200; seed++) {
        final director = EncounterDirector(seed);
        expect(director.unlocks, EncounterDirector(seed).unlocks);
        final order = director.unlocks.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));
        expect(order.first.value, inInclusiveRange(800, 999));
        firstKinds.add(order.first.key);
        for (var i = 0; i < order.length; i++) {
          (ranks[order[i].key] ??= {}).add(i);
          if (i > 0)
            expect(
              order[i].value - order[i - 1].value,
              inInclusiveRange(400, 650),
            );
        }
        expect(order.last.value, lessThanOrEqualTo(4250));
      }
      expect(firstKinds, containsAll(EncounterEnemy.values));
      for (final positions in ranks.values) expect(positions.length, 6);
    },
  );

  test('no early unlocks; safe overdue introductions win before repeats', () {
    final d = EncounterDirector(8);
    expect(
      d.choose(metres: 799, elapsed: 100, candidates: EncounterEnemy.values),
      isNull,
    );
    final seen = <EncounterEnemy>{};
    for (var i = 0; i < 6; i++) {
      final selected = d.choose(
        metres: 5000,
        elapsed: i * 60,
        candidates: EncounterEnemy.values,
      )!;
      expect(seen.add(selected), isTrue);
      expect(d.spawned(selected, i * 60), isTrue);
    }
    // Excluding an unsafe candidate leaves other encounters eligible.
    final safe = EncounterEnemy.values.where((e) => e != EncounterEnemy.beetle);
    expect(
      d.choose(metres: 5000, elapsed: 1000, candidates: safe),
      isNot(EncounterEnemy.beetle),
    );
  });

  test('repeat cooldown, quiet interval and recent history prevent spam', () {
    final d = EncounterDirector(2);
    final first = d.choose(
      metres: 5000,
      elapsed: 0,
      candidates: EncounterEnemy.values,
    )!;
    d.spawned(first, 0);
    expect(d.choose(metres: 5000, elapsed: 27, candidates: [first]), isNull);
    expect(d.choose(metres: 5000, elapsed: 28, candidates: [first]), first);
    d.rest(0, 800);
    final rest = d.nextEncounterAt;
    expect(rest, greaterThanOrEqualTo(18));
    expect(
      d.choose(
        metres: 5000,
        elapsed: rest - .01,
        candidates: EncounterEnemy.values,
      ),
      isNull,
    );
    EncounterEnemy? previous;
    final seen = <EncounterEnemy>{};
    for (var i = 0; i < 100; i++) {
      final chosen = d.choose(
        metres: 5000,
        elapsed: 100 + i * 60,
        candidates: EncounterEnemy.values,
      )!;
      expect(chosen, isNot(previous));
      seen.add(chosen);
      d.spawned(chosen, 100 + i * 60);
      previous = chosen;
    }
    expect(seen, containsAll(EncounterEnemy.values));
  });

  test(
    'new runs reroll; pause, score and equipment preserve the existing plan',
    () {
      final game = BalanceGame(seed: 7)..start(gameMode: GameMode.infinite);
      final plan = game.enemyDirector.unlocks;
      game.score = 10000000;
      game.survival.points = 10000000;
      game.setPaused(true);
      game.step(.1);
      expect(game.enemyDirector.unlocks, plan);
      game.start(gameMode: GameMode.infinite);
      expect(game.enemyDirector.unlocks, isNot(plan));
      final replay = BalanceGame(seed: 7)..start(gameMode: GameMode.infinite);
      expect(replay.enemyDirector.unlocks, plan);
    },
  );
}
