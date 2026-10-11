import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_boss.dart';
import 'package:balance_arcade/late_enemies.dart';
import 'infinite_boss_test.dart' show run, advance;

InfiniteBoss colossus({double top = 0}) =>
    InfiniteBoss(kind: BossKind.stormColossus, top: top);

void main() {
  test(
    'second boss uses its chosen score, follows the first, and never repeats',
    () {
      final game = run()
        ..bossesEncountered = 1
        ..survival.points = 200000;
      game.step(1 / 120);
      expect(game.boss, isNull);
      game.survival.points = game.bossScoreThresholds[1] - 10.0;
      game.step(1 / 120);
      expect(game.boss, isNull);
      game.survival.points = 330000;
      advance(game, 3.1);
      expect(game.boss!.kind, BossKind.stormColossus);
      expect(game.bossesEncountered, 2);
      final serial = game.runSerial;
      while (game.boss != null) {
        expect(game.boss!.kind, BossKind.stormColossus);
        expect(game.board, isEmpty);
        expect(game.lateEnemy, isNull);
        expect(game.spiders, isEmpty);
        expect(game.porcupines, isEmpty);
        expect(game.snakes, isEmpty);
        expect(game.mazeGates, isEmpty);
        expect(game.specialHazards, isEmpty);
        expect(game.webShots, isEmpty);
        expect(game.quills, isEmpty);
        expect(game.dangerActive, isFalse);
        game.survival.shield = 100;
        game.survival.items.clear();
        game.step(1 / 120);
      }
      expect(game.phase, GamePhase.playing);
      expect(game.runSerial, serial);
      expect(game.message, contains('BOSS CLEARED'));
      advance(game, 1);
      expect(game.board, isNotEmpty);
      game.survival.points = 750000;
      advance(game, .5);
      expect(game.boss, isNull);
      game.start(gameMode: GameMode.infinite);
      game.survival.points = 330000;
      advance(game, 3.1);
      expect(game.boss!.kind, BossKind.skyWarden);
      expect(game.bossesEncountered, 1);
      while (game.boss != null) {
        expect(game.boss!.kind, BossKind.skyWarden);
        game.survival.shield = 100;
        game.survival.items.clear();
        game.step(1 / 120);
      }
      game.bossesEnabled = false;
      advance(game, 60);
      game.bossesEnabled = true;
      advance(game, 3.1);
      expect(game.boss!.kind, BossKind.stormColossus);
      expect(game.bossesEncountered, 2);
    },
  );

  test('Colossus uses three distinct weapon phases and fully cleans up', () {
    final boss = colossus();
    final seen = <LateEnemyShot>{};
    final counts = <LateShotKind, int>{};
    for (var frame = 0; frame < 28 * 120 + 1; frame++) {
      boss.step(1 / 120, target: (x: 180, y: 430), scrollDistance: 2);
      for (final shot in boss.shots) {
        if (!seen.add(shot)) continue;
        counts.update(shot.kind, (value) => value + 1, ifAbsent: () => 1);
        expect(boss.phase, switch (shot.kind) {
          LateShotKind.ricochet => BossPhase.ricochets,
          LateShotKind.moth => BossPhase.blades,
          LateShotKind.mine => BossPhase.mines,
          _ => throw StateError('Unexpected Colossus weapon'),
        });
      }
      expect(boss.shots.length, lessThanOrEqualTo(8));
    }
    expect(counts, {
      LateShotKind.ricochet: 8,
      LateShotKind.moth: 8,
      LateShotKind.mine: 6,
    });
    expect(boss.expired, isTrue);
    expect(boss.shots, isEmpty);
  });

  test(
    'orbs reflect once at each rail and hit their locked aim on tall boards',
    () {
      for (final top in [0.0, -250.0]) {
        final boss = colossus(top: top);
        boss.step(2.6, target: (x: 180, y: 430));
        for (var index = 0; index < 2; index++) {
          final shot = boss.shots[index];
          final bounce = shot.positionAt(shot.bounceTime);
          expect(bounce.x, closeTo(index == 0 ? 28 : 332, 1e-8));
          final flight = (430 - shot.origin.y) / shot.velocity.y;
          final at = shot.positionAt(flight);
          expect(at.x, closeTo(180, 1e-8));
          expect(at.y, closeTo(430, 1e-8));
          expect(flight, lessThan(shot.life));
          final before = shot.positionAt(shot.bounceTime - .05);
          final after = shot.positionAt(shot.bounceTime + .05);
          expect(before.x, closeTo(after.x, 1e-8));
        }
      }
    },
  );

  test(
    'blade pairs curve in opposite directions and alternate their spread',
    () {
      final boss = colossus();
      boss.step(10.71, target: (x: 180, y: 430));
      final first = boss.shots
          .where((s) => s.kind == LateShotKind.moth)
          .toList();
      expect(first.length, 2);
      expect(first[0].curve, -first[1].curve);
      expect(
        (first[0].positionAt(1.5).x - first[1].positionAt(1.5).x).abs(),
        144,
      );
      boss.step(1.1, target: (x: 180, y: 430));
      final blades = boss.shots
          .where((s) => s.kind == LateShotKind.moth)
          .toList();
      expect(blades.last.curve.abs(), 48);
      final at = first.first.positionAt(1.5);
      boss.step(.5, target: (x: 300, y: 430));
      expect(first.first.contact(at.x, at.y, at.x, at.y), isNotNull);
    },
  );

  test(
    'mines warn before a full-disk blast and stay fixed during scrolling',
    () {
      final boss = colossus();
      boss.step(18.01, target: (x: 180, y: 430));
      final mine = boss.shots.firstWhere((s) => s.kind == LateShotKind.mine);
      final position = mine.position;
      expect(mine.visible, isFalse);
      expect(mine.contact(180, 430, 180, 430), isNull);
      boss.step(1.2, target: (x: 300, y: 430), scrollDistance: 240);
      expect(mine.position, position);
      expect(mine.visible, isFalse);
      boss.step(.2, target: (x: 300, y: 430), scrollDistance: 40);
      expect(mine.visible, isTrue);
      expect(mine.position, position);
      expect(mine.contact(180, 430, 180, 430), isNotNull);
      expect(mine.contact(215, 430, 215, 430), isNotNull);
      expect(mine.contact(240, 430, 240, 430), isNull);
      boss.step(1, target: (x: 300, y: 430));
      expect(mine.visible, isFalse);
      mine.step(.1);
      expect(mine.contact(180, 430, 180, 430), isNull);
    },
  );

  test(
    'Colossus mine warning freezes on pause and costs one heart on contact',
    () {
      final game = run()..bossesEncountered = 2;
      final boss = colossus()
        ..step(18.01, target: (x: game.ballX, y: game.screenY(game.ballY)));
      game.boss = boss;
      game.setPaused(true);
      final age = boss.age, camera = game.cameraOffset;
      advance(game, 5);
      expect(boss.age, age);
      expect(game.cameraOffset, camera);
      expect(game.lives, 3);
      game.setPaused(false);
      advance(game, 1.5);
      expect(game.lives, 2);
      expect(game.survival.recovery, greaterThan(0));
      expect(game.boss, same(boss));
      advance(game, .5);
      expect(game.lives, 2);
    },
  );

  test('revive preserves both boss milestones and restart resets them', () {
    final game = run()
      ..bossesEncountered = 2
      ..lives = 1;
    game.boss = colossus()
      ..shots.add(
        LateEnemyShot(
          kind: LateShotKind.mine,
          origin: (x: game.ballX, y: game.screenY(game.ballY)),
          velocity: (x: 0, y: 0),
          delay: 0,
          life: 1,
        ),
      );
    game.step(1 / 120);
    expect(game.lives, 0);
    expect(game.boss, isNull);
    advance(game, 1);
    expect(game.reviveInfinite(), isTrue);
    game.survival.points = 550000;
    advance(game, .1);
    expect(game.boss, isNull);
    expect(game.bossesEncountered, 2);
    game.start(gameMode: GameMode.classic);
    expect(game.bossesEncountered, 0);
    expect(game.boss, isNull);
  });
}
