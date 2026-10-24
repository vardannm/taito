import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_boss.dart';
import 'package:balance_arcade/late_enemies.dart';
import 'infinite_boss_test.dart' show run, advance;

void main() {
  test(
    'a big score jump visits every boss in shuffled order with rest gaps',
    () {
      final game = run()
        ..survival.points = 2000000
        ..survival.shield = 1000
        ..lateEnemiesEnabled = false
        ..snakeEncountersEnabled = false;
      double? previousEnd;
      for (final kind in game.bossOrder) {
        while (game.boss == null) advance(game, 1 / 120);
        expect(game.boss!.kind, kind);
        if (previousEnd != null)
          expect(game.elapsed - previousEnd, greaterThanOrEqualTo(63));
        while (game.boss != null) advance(game, 1 / 120);
        previousEnd = game.elapsed;
      }
      expect(game.bossesEncountered, BossKind.values.length);
      advance(game, 65);
      expect(game.boss, isNull);
      expect(game.bossPending, isFalse);
    },
  );
  test(
    'Seraph has three distinct phases and finishes all attacks before exit',
    () {
      final boss = InfiniteBoss(kind: BossKind.eclipseSeraph);
      final seen = <LateEnemyShot>{};
      final counts = <LateShotKind, int>{};
      for (var frame = 0; frame < 28 * 120 + 1; frame++) {
        boss.step(1 / 120, target: (x: 180, y: 430), scrollDistance: 2);
        for (final shot in boss.shots) {
          if (!seen.add(shot)) continue;
          counts.update(shot.kind, (n) => n + 1, ifAbsent: () => 1);
          expect(boss.phase, switch (shot.kind) {
            LateShotKind.moth => BossPhase.petals,
            LateShotKind.laser => BossPhase.curtains,
            LateShotKind.shard => BossPhase.comets,
            _ => throw StateError('Unexpected Seraph weapon'),
          });
        }
        expect(boss.shots.length, lessThanOrEqualTo(12));
        if (boss.age > 26) expect(boss.shots.any((s) => s.visible), isFalse);
      }
      expect(counts, {
        LateShotKind.moth: 16,
        LateShotKind.laser: 6,
        LateShotKind.shard: 9,
      });
      expect(boss.expired, isTrue);
      expect(boss.shots, isEmpty);
    },
  );

  test(
    'curtain warning is harmless and always leaves a broad fixed escape lane',
    () {
      final boss = InfiniteBoss(kind: BossKind.eclipseSeraph, top: -250);
      boss.step(10.21, target: (x: 180, y: 430));
      final beams = boss.shots
          .where((s) => s.kind == LateShotKind.laser)
          .toList();
      expect(beams.length, 2);
      for (final beam in beams) {
        expect(beam.visible, isFalse);
        expect(beam.contact(beam.origin.x, 430, beam.origin.x, 430), isNull);
        expect(beam.origin.x, beam.beamEnd!.x);
      }
      boss.step(1.21, target: (x: 280, y: 430));
      for (final beam in beams) {
        expect(beam.visible, isTrue);
        expect(beam.contact(beam.origin.x, 430, beam.origin.x, 430), isNotNull);
        expect(beam.contact(180, 430, 180, 430), isNull);
      }
    },
  );

  test(
    'comets mark their locked trails then reach tall and standard boards',
    () {
      for (final top in [0.0, -250.0]) {
        final boss = InfiniteBoss(kind: BossKind.eclipseSeraph, top: top);
        boss.step(18.01, target: (x: 180, y: 430));
        final comet = boss.shots.firstWhere(
          (s) => s.kind == LateShotKind.shard,
        );
        final landing = comet.positionAt(2.1);
        expect(landing.y, closeTo(430, 1e-8));
        expect(comet.visible, isFalse);
        expect(
          comet.contact(landing.x, landing.y, landing.x, landing.y),
          isNull,
        );
        boss.step(.8, target: (x: 300, y: 430));
        expect(comet.visible, isFalse);
        boss.step(2.21, target: (x: 300, y: 430));
        expect(
          comet.contact(landing.x, landing.y, landing.x, landing.y),
          isNotNull,
        );
        expect(comet.positionAt(2.1), landing);
      }
    },
  );

  test(
    'third boss respects threshold, owns a clear arena and never repeats',
    () {
      final game = run()
        ..bossesEncountered = 2
        ..survival.points = 500000
        ..survival.shield = 1000;
      advance(game, .1);
      expect(game.boss, isNull);
      expect(game.bossPending, isFalse);
      game.survival.points = game.bossScoreThresholds[2].toDouble();
      advance(game, 3.1);
      expect(game.boss!.kind, game.bossOrder[2]);
      expect(game.bossesEncountered, 3);
      while (game.boss != null) {
        expect(game.board, isEmpty);
        expect(game.specialHazards, isEmpty);
        expect(game.mazeGates, isEmpty);
        expect(game.lateEnemy, isNull);
        expect(game.spiders, isEmpty);
        expect(game.porcupines, isEmpty);
        expect(game.snakes, isEmpty);
        expect(game.dangerActive, isFalse);
        advance(game, 1 / 120);
      }
      game.survival.points = 1000000;
      advance(game, 5);
      expect(game.boss, isNull);
      expect(game.board, isNotEmpty);
      final thresholds = game.bossScoreThresholds;
      game.lives = 0;
      game.phase = GamePhase.over;
      expect(game.reviveInfinite(), isTrue);
      expect(game.bossScoreThresholds, same(thresholds));
      expect(game.bossesEncountered, 3);
      game.start(gameMode: GameMode.infinite);
      expect(game.bossesEncountered, 0);
    },
  );

  test(
    'Seraph hits respect shields/recovery and pause freezes weapon poses',
    () {
      for (final protection in ['none', 'shield', 'recovery']) {
        final game = run()..bossesEncountered = 3;
        final boss = InfiniteBoss(kind: BossKind.eclipseSeraph)
          ..shots.add(
            LateEnemyShot(
              kind: LateShotKind.shard,
              origin: (x: game.ballX, y: game.screenY(game.ballY)),
              velocity: (x: 0, y: 0),
              delay: 0,
              life: 2,
            ),
          );
        game.boss = boss;
        if (protection == 'shield') game.survival.shield = 10;
        if (protection == 'recovery') game.survival.recovery = 10;
        game.setPaused(true);
        final age = boss.age;
        advance(game, 5);
        expect(boss.age, age);
        game.setPaused(false);
        game.step(1 / 120);
        expect(game.lives, protection == 'none' ? 2 : 3);
      }
    },
  );

  test('recoil follows volleys and charging builds during a warning', () {
    for (final kind in BossKind.values) {
      final boss = InfiniteBoss(kind: kind);
      boss.step(
        kind == BossKind.prismReaver || kind == BossKind.novaPulsar
            ? 3.7
            : kind == BossKind.venomCrown
            ? 3.5
            : 2.6,
        target: (x: 180, y: 430),
      );
      expect(boss.recoil, closeTo(1, 1e-8));
      boss.step(.4, target: (x: 180, y: 430));
      expect(boss.recoil, 0);
      final time = kind == BossKind.skyWarden
          ? 10.0
          : kind == BossKind.stormColossus
          ? 18.0
          : 10.2;
      boss.step(time - boss.age + .01, target: (x: 180, y: 430));
      final before = boss.charge;
      boss.step(.5, target: (x: 180, y: 430));
      expect(boss.charge, greaterThan(before));
    }
  });
}
