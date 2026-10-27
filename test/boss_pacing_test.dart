import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_boss.dart';
import 'package:balance_arcade/late_enemies.dart';
import 'infinite_boss_test.dart' show advance, run;

void main() {
  test('the six slots use the set windows and any boss can fill any slot', () {
    expect(bossScoreWindows, [
      (70000, 110000),
      (220000, 250000),
      (450000, 520000),
      (700000, 780000),
      (1000000, 1100000),
      (1300000, 1400000),
    ]);
    final bySlot = List.generate(6, (_) => <BossKind>{});
    for (var seed = 0; seed < 300; seed++) {
      final game = BalanceGame(seed: seed)..start(gameMode: GameMode.infinite);
      expect(game.bossOrder.toSet(), BossKind.values.toSet());
      for (final (slot, kind) in game.bossOrder.indexed) {
        bySlot[slot].add(kind);
      }
    }
    // Venom Crown can open a run, Sky Warden can close it, and so on.
    for (final kinds in bySlot) {
      expect(kinds, BossKind.values.toSet());
    }
  });

  test(
    'seeded windows vary between runs and stay fixed on pause and revive',
    () {
      final a = BalanceGame(seed: 19), b = BalanceGame(seed: 19);
      final seen = <String>{};
      final orders = <String>{};
      for (var i = 0; i < 20; i++) {
        a.start(gameMode: GameMode.infinite);
        b.start(gameMode: GameMode.infinite);
        expect(a.bossScoreThresholds, b.bossScoreThresholds);
        expect(a.bossOrder, b.bossOrder);
        expect(a.bossOrder.toSet(), BossKind.values.toSet());
        orders.add(a.bossOrder.join(','));
        for (final (slot, (low, high)) in bossScoreWindows.indexed) {
          expect(a.bossScoreThresholds[slot], inInclusiveRange(low, high));
        }
        seen.add(a.bossScoreThresholds.join(','));
      }
      expect(seen.length, greaterThan(1));
      expect(orders.length, greaterThan(1));
      final thresholds = a.bossScoreThresholds;
      final order = a.bossOrder;
      a.setPaused(true);
      advance(a, 10);
      a.setPaused(false);
      expect(a.bossScoreThresholds, same(thresholds));
      expect(a.bossOrder, same(order));
      a.lives = 0;
      a.phase = GamePhase.over;
      expect(a.reviveInfinite(), isTrue);
      expect(a.bossScoreThresholds, same(thresholds));
      expect(a.bossOrder, same(order));
    },
  );

  test('after all six, Overdrive bosses return on time and run faster', () {
    final game = run()
      ..lateEnemiesEnabled = false
      ..snakeEncountersEnabled = false
      ..bossesEncountered = BossKind.values.length
      ..survival.points = 2000000;
    // Untouchable, so the test follows the schedule rather than dodging.
    game.survival.shield = 1e6;
    double waitForBoss(double limit) {
      var waited = 0.0;
      while (game.boss == null && waited < limit) {
        advance(game, .5);
        waited += .5;
      }
      return waited;
    }

    waitForBoss(60);
    final first = game.boss!;
    expect(first.lap, 1);
    expect(first.kind, game.bossOrder.first);
    expect(first.displayName, '${first.kind.name} II');
    expect(first.pace, closeTo(1.12, 1e-9));
    // The whole fight plays 12% faster: 28 seconds of attacks in 25.
    advance(game, InfiniteBoss.duration / first.pace + .1);
    expect(game.boss, isNull);
    expect(game.bossesCleared, 1);
    // No score can rush the next one: it waits for play time.
    game.survival.points = 50000000;
    advance(game, InfiniteBoss.overdriveGapSeconds - 5);
    expect(game.boss, isNull);
    expect(waitForBoss(60), lessThan(60));
    expect(game.boss!.kind, game.bossOrder[1]);
    expect(game.boss!.lap, 1);
  });
  test('Overdrive speed stops growing after the fourth lap', () {
    expect(InfiniteBoss(lap: 0).pace, 1);
    expect(InfiniteBoss(lap: 3).pace, closeTo(1.36, 1e-9));
    expect(InfiniteBoss(lap: 9).pace, closeTo(1.36, 1e-9));
    expect(
      InfiniteBoss(kind: BossKind.novaPulsar, lap: 2).displayName,
      'NOVA PULSAR III',
    );
    expect(InfiniteBoss.training().pace, 1);
  });
  test('arrival warning lasts three active seconds and freezes on pause', () {
    final game = run()..survival.points = 120000;
    advance(game, .1);
    expect(game.bossWarningSeconds, 3);
    expect(game.message, contains('${game.bossOrder.first.name} IN 3'));
    advance(game, 1);
    expect(game.bossWarningSeconds, 2);
    game.setPaused(true);
    advance(game, 20);
    expect(game.bossWarningSeconds, 2);
    game.setPaused(false);
    advance(game, 1);
    expect(game.bossWarningSeconds, 1);
    expect(game.boss, isNull);
    advance(game, 1);
    expect(game.boss, isNotNull);
    expect(game.bossWarningSeconds, isNull);
  });

  test(
    'large score jump still gives 60 seconds of normal play between bosses',
    () {
      final game = run()
        ..survival.points = 1000000
        ..survival.shield = 1000
        ..lateEnemiesEnabled = false
        ..snakeEncountersEnabled = false;
      advance(game, 3.1);
      expect(game.boss!.kind, game.bossOrder[0]);
      while (game.boss != null) advance(game, 1 / 120);
      final end = game.elapsed;
      advance(game, 59);
      expect(game.elapsed - end, closeTo(59, .01));
      expect(game.bossPending, isFalse);
      expect(game.bossWarningSeconds, isNull);
      expect(game.board, isNotEmpty);
      advance(game, 1.1);
      expect(game.bossPending, isTrue);
      expect(game.boss, isNull);
      advance(game, 3.1);
      expect(game.boss!.kind, game.bossOrder[1]);
    },
  );

  test('a lost heart delays and restarts the arrival warning', () {
    final game = run()..survival.points = 120000;
    advance(game, 1);
    game.lateEnemy =
        LateEnemyEncounter(
            kind: LateEnemyKind.cricket,
            origin: (x: 180, y: 160),
            target: (x: 180, y: 430),
          )
          ..shots.add(
            LateEnemyShot(
              kind: LateShotKind.shard,
              origin: (x: game.ballX, y: game.screenY(game.ballY)),
              velocity: (x: 0, y: 0),
              delay: 0,
              life: 1,
            ),
          );
    game.step(1 / 120);
    expect(game.lives, 2);
    expect(game.bossWarningSeconds, isNull);
    game.lateEnemy = null;
    advance(game, 4.9);
    expect(game.bossWarningSeconds, isNull);
    advance(game, .2);
    expect(game.bossWarningSeconds, 3);
    advance(game, 3);
    expect(game.boss, isNotNull);
  });
}
