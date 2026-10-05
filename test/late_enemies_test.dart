import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:balance_arcade/late_enemies.dart';
import 'package:balance_arcade/porcupines.dart';
import 'package:balance_arcade/spider_web.dart';

LateEnemyEncounter encounter(LateEnemyKind kind) => LateEnemyEncounter(
  kind: kind,
  origin: (x: 43, y: 160),
  target: (x: 180, y: 420),
);

BalanceGame run() => BalanceGame(seed: 7)
  ..start(gameMode: GameMode.infinite)
  ..mazeSectionsEnabled = false
  ..snakeEncountersEnabled = false
  ..board.clear()
  ..survival.items.clear();

void advance(BalanceGame game, double seconds) {
  for (var i = 0; i < (seconds * 120).ceil(); i++) {
    game.stallTime = 0;
    game.step(1 / 120);
  }
}

LateEnemyShot stationary(LateShotKind kind, double x, double y) =>
    LateEnemyShot(
      kind: kind,
      origin: (x: x, y: y),
      velocity: (x: 0, y: 0),
      delay: 0,
      life: 2,
    );

void main() {
  test('milestones introduce all five after the existing late hazards', () {
    expect(LateEnemyKind.values.map((k) => k.unlockMetres), [
      2600,
      3100,
      3600,
      4100,
      4600,
    ]);
    final game = run()..maxHeight = 24000;
    game.survival.points = 10000000;
    advance(game, .3);
    expect(game.lateEnemy, isNull);
  });

  test('beetle waits when terrain blocks both marked-circle escape routes', () {
    final blocked = run()..maxHeight = 27800;
    final turnY = blocked.ballY - blocked.ascentSpeed * .65;
    blocked.board.addAll([Hole(110, turnY), Hole(250, turnY)]);
    blocked.step(1 / 120);
    expect(blocked.lateEnemy, isNull);
    final clear = run()..maxHeight = 27800;
    clear.step(1 / 120);
    expect(clear.lateEnemy?.kind, LateEnemyKind.beetle);
  });

  test(
    'every encounter has a full harmless wind-up and bounded projectiles',
    () {
      for (final kind in LateEnemyKind.values) {
        final e = encounter(kind);
        e.step(InfiniteTuning.lateEnemyWarning - .01);
        expect(e.warning, isTrue);
        expect(e.shots.length, lessThanOrEqualTo(6));
        expect(e.bodyContact(43, 160, 43, 160), isNull);
        for (final shot in e.shots) {
          expect(shot.contact(0, 0, 360, 560), isNull);
          expect(shot.visible, isFalse);
        }
        e.step(10);
        expect(e.expired, isTrue);
        e.step(.1);
        for (final shot in e.shots) {
          expect(shot.contact(0, 0, 360, 560), isNull);
        }
      }
    },
  );

  test(
    'beetle bomb is harmless; acid begins at landing and scrolls for 2s',
    () {
      final e = encounter(LateEnemyKind.beetle);
      final bomb = e.shots.first, acid = e.shots.last;
      e.step(InfiniteTuning.lateEnemyWarning + .94, scrollDistance: 240);
      expect(bomb.visible, isTrue);
      expect(
        bomb.contact(
          bomb.position.x,
          bomb.position.y,
          bomb.position.x,
          bomb.position.y,
        ),
        isNull,
      );
      expect(acid.visible, isFalse);
      expect(acid.position.y, 420);
      e.step(.02, scrollDistance: 4);
      expect(acid.visible, isTrue);
      expect(acid.position.y, closeTo(422, 1e-8));
      expect(acid.contact(180, 420, 180, 420), closeTo(.5, 1e-8));
      e.step(.3, scrollDistance: 60);
      expect(acid.position.y, closeTo(482, 1e-8));
      expect(acid.persistent, isTrue);
      e.step(2);
      expect(acid.visible, isFalse);
    },
  );

  test(
    'cricket reflects once at either wall and sweeps both sides of bounce',
    () {
      for (final left in [true, false]) {
        final e = LateEnemyEncounter(
          kind: LateEnemyKind.cricket,
          origin: (x: left ? 43.0 : 317.0, y: 160),
          target: (x: 180, y: 420),
        );
        final shot = e.shots.single;
        final bounce = shot.positionAt(shot.bounceTime);
        expect(bounce.x, closeTo(left ? 332 : 28, 1e-8));
        final before = shot.positionAt(shot.bounceTime - .1);
        final after = shot.positionAt(shot.bounceTime + .1);
        expect(before.x, closeTo(after.x, 1e-8));
        shot.step(shot.delay + shot.bounceTime - .1);
        shot.step(.2);
        expect(shot.contact(bounce.x, bounce.y, bounce.x, bounce.y), isNotNull);
        expect(
          shot.positionAt(shot.life).x,
          inInclusiveRange(28.0 - 1e-8, 332.0 + 1e-8),
        );
      }
    },
  );

  test('moth streams separate symmetrically and close again', () {
    final e = LateEnemyEncounter(
      kind: LateEnemyKind.moth,
      origin: (x: 180, y: 120),
      target: (x: 180, y: 420),
    );
    final a = e.shots[0], b = e.shots[1];
    expect(e.shots.length, 6);
    expect(a.positionAt(0), b.positionAt(0));
    expect(
      (a.positionAt(1.4).x - b.positionAt(1.4).x).abs(),
      closeTo(116, 1e-8),
    );
    expect(a.positionAt(2.8).x, closeTo(b.positionAt(2.8).x, 1e-8));
    final p = a.positionAt(1.4);
    a.step(a.delay);
    a.step(2.8);
    expect(a.contact(p.x, p.y, p.x, p.y), isNotNull);
    expect(a.contact(180, p.y, 180, p.y), isNull);
  });

  test(
    'scorpion needles fire 0.2s apart along exactly the same locked line',
    () {
      final e = encounter(LateEnemyKind.scorpion);
      expect(e.shots.length, 3);
      expect(e.shots[1].delay - e.shots[0].delay, closeTo(.2, 1e-8));
      expect(e.shots[2].delay - e.shots[1].delay, closeTo(.2, 1e-8));
      e.step(InfiniteTuning.lateEnemyWarning + .1);
      expect(e.shots.where((s) => s.visible).length, 1);
      e.step(.2);
      expect(e.shots.where((s) => s.visible).length, 2);
      e.step(.2);
      expect(e.shots.where((s) => s.visible).length, 3);
      expect(e.shots.map((s) => s.velocity).toSet().length, 1);
    },
  );

  test(
    'seed splits at its marked endpoint; an absorbed seed cancels children',
    () {
      final e = encounter(LateEnemyKind.seedSpitter);
      final seed = e.shots.first;
      final split = seed.positionAt(seed.life);
      for (final shard in e.shots.skip(1)) {
        expect(shard.origin, split);
        expect(shard.delay, seed.delay + seed.life);
      }
      e.step(seed.delay + seed.life + .01);
      expect(seed.visible, isFalse);
      expect(e.shots.where((s) => s.visible).length, 3);
      seed.consumed = true;
      for (final shard in e.shots.skip(1)) {
        expect(shard.visible, isFalse);
        expect(shard.contact(split.x, split.y, split.x, split.y), isNull);
      }
    },
  );

  test('activation and expiry fractions cannot cause retroactive damage', () {
    final shot = LateEnemyShot(
      kind: LateShotKind.needle,
      origin: (x: 100, y: 100),
      velocity: (x: 100, y: 0),
      delay: 1,
      life: 1,
    );
    shot.step(.95);
    shot.step(.1);
    expect(shot.contact(103, 100, 103, 200), isNull);
    expect(shot.contact(103, 100, 103, 100), closeTo(.5, 1e-8));
    shot.step(.9);
    shot.step(.1);
    expect(shot.contact(198, 200, 198, 100), isNull);
    expect(shot.contact(198, 100, 198, 100), isNotNull);
    shot.step(.1);
    expect(shot.contact(200, 100, 200, 100), isNull);
  });

  test(
    'pause freezes warnings and projectiles; reset, breath, maze clear visitors',
    () {
      for (final cleanup in ['reset', 'breath', 'maze', 'disabled']) {
        final g = run();
        final e = encounter(LateEnemyKind.cricket);
        g.lateEnemy = e;
        advance(g, .2);
        g.setPaused(true);
        final age = e.age;
        final shotAge = e.shots.single.age;
        advance(g, .5);
        expect(e.age, age);
        expect(e.shots.single.age, shotAge);
        g.setPaused(false);
        switch (cleanup) {
          case 'reset':
            g.start(gameMode: GameMode.classic);
          case 'breath':
            g.maxHeight = 1800;
          case 'maze':
            g.mazeSectionsEnabled = true;
            g.maxHeight = 8000;
          case 'disabled':
            g.lateEnemiesEnabled = false;
        }
        g.step(1 / 120);
        expect(g.lateEnemy, isNull, reason: cleanup);
      }
    },
  );

  for (final kind in LateShotKind.values.where((k) => k != LateShotKind.bomb)) {
    test('$kind respects hearts, shields, recovery and lethal damage', () {
      for (final shield in [false, true]) {
        final g = run();
        final e = encounter(LateEnemyKind.scorpion);
        e.shots.clear();
        final shot = stationary(kind, g.ballX, g.screenY(g.ballY));
        e.shots.add(shot);
        g.lateEnemy = e;
        if (shield) g.survival.shield = 10;
        g.step(1 / 120);
        expect(g.lives, shield ? 3 : 2);
        expect(shot.consumed, !shot.persistent);
        advance(g, .1);
        expect(g.lives, shield ? 3 : 2);
        g.survival.shield = g.survival.recovery = 0;
        g.lives = 1;
        e.shots.add(stationary(kind, g.ballX, g.screenY(g.ballY)));
        g.step(1 / 120);
        expect(g.lives, 0);
        expect(g.phase, GamePhase.sinking);
      }
    });
  }

  for (final shieldFirst in [true, false]) {
    test(
      'screen-space shots and world-space shields resolve in order ($shieldFirst)',
      () {
        final g = run();
        final e = encounter(LateEnemyKind.scorpion);
        e.shots
          ..clear()
          ..add(stationary(LateShotKind.needle, 180, 350));
        g.lateEnemy = e;
        g.survival.items.add(
          InfiniteItem(InfiniteItemKind.shield, 180, shieldFirst ? 400 : 300),
        );
        g.grabPivot(0);
        g.grabPivot(1);
        g.dragPivot(0, -200);
        g.dragPivot(1, -200);
        g.step(1 / 120);
        expect(g.lives, shieldFirst ? 3 : 2);
        expect(g.survival.shield, greaterThan(0));
      },
    );
  }

  test(
    'late encounters wait for existing warnings, shots, and special hazards',
    () {
      for (var blocker = 0; blocker < 4; blocker++) {
        final g = run()..maxHeight = 27800;
        g.survival.shield = 100;
        switch (blocker) {
          case 0:
            g.specialHazards.add(
              SpecialHazard(HazardKind.laser, x: 50, y: 100),
            );
          case 1:
            g.webShots.add(
              SpiderWebShot(x: 50, y: 50, targetX: 150, targetY: 300),
            );
          case 2:
            g.quills.add(PorcupineQuill(x: 50, y: 50, angle: math.pi / 2));
          case 3:
            g.porcupines.add(BoardPorcupine(80, 160)..charge = 0);
        }
        g.step(1 / 120);
        expect(g.lateEnemy, isNull, reason: 'blocker $blocker');
      }
    },
  );

  test(
    'long seeded runs introduce every kind without overlapping attack systems',
    () {
      for (var seed = 0; seed < 3; seed++) {
        final g = BalanceGame(seed: seed)..start(gameMode: GameMode.infinite);
        g.survival.shield = 2000;
        g.cameraOffset = 25000;
        g.left = g.right = BalanceGame.infiniteStart - g.cameraOffset;
        g.maxHeight = 25000;
        final seen = <LateEnemyKind>{};
        LateEnemyEncounter? previous;
        double endedAt = -100;
        for (var i = 0; i < 120 * 260; i++) {
          g.stallTime = 0;
          g.step(1 / 120);
          final e = g.lateEnemy;
          if (previous != null && e == null) endedAt = g.elapsed;
          if (e != null) {
            if (e != previous) {
              expect(g.metres, greaterThanOrEqualTo(e.kind.unlockMetres));
              expect(g.elapsed - endedAt, greaterThanOrEqualTo(1.9));
              seen.add(e.kind);
            }
            expect(g.specialHazards, isEmpty);
            expect(g.snakes, isEmpty);
            expect(g.webShots, isEmpty);
            expect(g.quills, isEmpty);
            expect(g.porcupines.every((p) => p.charge == null), isTrue);
            expect(e.shots.length, lessThanOrEqualTo(6));
          }
          previous = e;
        }
        expect(seen, containsAll(LateEnemyKind.values), reason: 'seed $seed');
        expect(g.finished, isFalse);
      }
    },
  );

  test(
    'revive discards a dangerous visitor and provides a fresh quiet interval',
    () {
      final g = run();
      g.lateEnemy = encounter(LateEnemyKind.beetle);
      g.phase = GamePhase.over;
      g.lives = 0;
      expect(g.reviveInfinite(), isTrue);
      expect(g.lateEnemy, isNull);
      expect(g.survival.recovery, 3);
    },
  );
}
