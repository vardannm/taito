import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/infinite_boss.dart';
import 'package:balance_arcade/late_enemies.dart';
import 'infinite_boss_test.dart' show advance, run;

InfiniteBoss keeper({double top = 0}) =>
    InfiniteBoss(kind: BossKind.chronoKeeper, top: top);

void main() {
  test(
    'three clock phases warn, finish before exit and leave no projectiles',
    () {
      final boss = keeper();
      final seen = <LateEnemyShot>{};
      final counts = <BossPhase, int>{};
      for (var i = 0; i < 28 * 120; i++) {
        boss.step(1 / 120, target: (x: 180, y: 430));
        for (final shot in boss.shots) {
          if (!seen.add(shot)) continue;
          expect(shot.age, closeTo(-InfiniteBoss.chronoWarning, 1 / 120));
          expect(
            shot.contact(
              shot.origin.x,
              shot.origin.y,
              shot.origin.x,
              shot.origin.y,
            ),
            isNull,
          );
          counts.update(boss.phase, (n) => n + 1, ifAbsent: () => 1);
        }
        expect(boss.shots.length, lessThanOrEqualTo(9));
        if (boss.phase == BossPhase.leaving) {
          expect(boss.shots.where((s) => s.visible || s.age < 0), isEmpty);
        }
      }
      expect(counts, {
        BossPhase.tickRain: 9,
        BossPhase.pendulum: 6,
        BossPhase.rewind: 9,
      });
      expect(boss.displayName, 'CHRONO KEEPER');
      expect(boss.shots, isEmpty);
    },
  );

  test('tick bolts pause continuously and then resume on the same trail', () {
    final boss = keeper()..step(2.41, target: (x: 180, y: 430));
    final shot = boss.shots.first;
    final start = shot.positionAt(.85);
    expect(shot.positionAt(1.1), start);
    expect(shot.positionAt(1.35), start);
    expect(shot.positionAt(.849).y, closeTo(start.y, .2));
    expect(shot.positionAt(1.351).y, closeTo(start.y, .2));
    expect(shot.positionAt(1.6).y, greaterThan(start.y));
  });

  test(
    'rewind bolts hit on both passes and lock the turn point during warning',
    () {
      final boss = keeper()..step(18.21, target: (x: 180, y: 430));
      final shot = boss.shots.firstWhere((s) => s.reason.startsWith('Rewind'));
      final turn = shot.positionAt(1.6);
      expect(turn.y, 502);
      final hits = <bool>{};
      for (var i = 0; i < 4 * 120; i++) {
        boss.step(1 / 120, target: (x: 300, y: 314));
        expect(shot.positionAt(1.6), turn);
        if (shot.contact(shot.origin.x, 430, shot.origin.x, 430) != null) {
          hits.add(shot.age > 1.6);
        }
      }
      expect(hits, {false, true}, reason: 'outbound and returning contact');
      expect(shot.positionAt(0).y, closeTo(shot.positionAt(3.2).y, 1e-8));
    },
  );

  test(
    'a reachable dodge route works on normal and expanded portrait boards',
    () {
      for (final top in [0.0, -250.0]) {
        for (final targetY in [314.0, 430.0]) {
          for (final pace in [1.0, 1.36]) {
            final boss = keeper(top: top);
            var x = 130.0;
            var hit = false;
            for (var i = 0; i < (28 / pace * 120).ceil(); i++) {
              final desired = boss.age >= 10 && boss.age < 18 ? 180.0 : 130.0;
              final nextX = x + (desired - x).clamp(-100 / 120, 100 / 120);
              boss.step(pace / 120, target: (x: nextX, y: targetY));
              for (final shot in boss.shots) {
                hit |= shot.contact(x, targetY, nextX, targetY) != null;
                if (shot.visible) {
                  expect(shot.position.x, inInclusiveRange(24.0, 336.0));
                  expect(shot.position.y, inInclusiveRange(top + 190, 560.001));
                }
              }
              x = nextX;
            }
            expect(hit, isFalse, reason: 'top=$top, y=$targetY, pace=$pace');
          }
        }
      }
    },
  );

  test('the scheduled Keeper arrives, pauses and clears through gameplay', () {
    final game = run()
      ..lateEnemiesEnabled = false
      ..snakeEncountersEnabled = false
      ..survival.shield = 1e6;
    final slot = game.bossOrder.indexOf(BossKind.chronoKeeper);
    expect(slot, greaterThan(0));
    game.bossesEncountered = slot;
    game.survival.points = game.bossScoreThresholds[slot].toDouble();
    advance(game, 3.1);
    expect(game.boss!.kind, BossKind.chronoKeeper);
    advance(game, 4);
    final boss = game.boss!;
    final age = boss.age;
    final positions = boss.shots.map((s) => s.position).toList();
    game.setPaused(true);
    advance(game, 5);
    expect(boss.age, age);
    expect(boss.shots.map((s) => s.position), positions);
    game.setPaused(false);
    advance(game, 28);
    expect(game.boss, isNull);
    expect(game.bossesCleared, 1);
  });
}
