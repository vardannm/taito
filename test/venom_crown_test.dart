import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_boss.dart';
import 'package:balance_arcade/infinite_boss_painter.dart';
import 'package:balance_arcade/late_enemies.dart';
import 'combo_render_budget_test.dart' show DrawingBudget;
import 'infinite_boss_test.dart' show run, advance;

class ToxicPaletteCanvas extends DrawingBudget {
  final colors = <int>{};
  @override
  dynamic noSuchMethod(Invocation invocation) {
    for (final arg in invocation.positionalArguments) {
      if (arg is Paint) colors.add(arg.color.toARGB32());
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  test(
    'fifth boss fires 17 toxic formations in three phases and clears before exit',
    () {
      final boss = InfiniteBoss(kind: BossKind.venomCrown);
      final seen = <LateEnemyShot>{};
      final phases = <BossPhase, int>{};
      for (var i = 0; i <= 28 * 120; i++) {
        boss.step(1 / 120, target: (x: 180, y: 430));
        for (final shot in boss.shots) {
          if (!seen.add(shot)) continue;
          expect(shot.kind, LateShotKind.shard);
          expect(shot.positionPath, isNotNull);
          phases.update(boss.phase, (n) => n + 1, ifAbsent: () => 1);
        }
        expect(boss.shots.length, lessThanOrEqualTo(144));
        expect(boss.toxicWalls.length, lessThanOrEqualTo(6));
        if (boss.age >= 26) expect(boss.shots.any((s) => s.visible), isFalse);
      }
      expect(phases, {
        BossPhase.toxicSlalom: 120,
        BossPhase.toxicPulse: 120,
        BossPhase.toxicGauntlet: 168,
      });
      expect(boss.expired, isTrue);
      expect(boss.shots, isEmpty);
      expect(boss.toxicWalls, isEmpty);
    },
  );

  test(
    'every overlapping wall leaves a collision-safe shared corridor at all heights',
    () {
      for (final top in [0.0, -250.0]) {
        for (final start in [28.0, 180.0, 332.0]) {
          final boss = InfiniteBoss(
            kind: BossKind.venomCrown,
            top: top,
            seed: start.toInt(),
          );
          for (var i = 0; i < 26 * 120; i++) {
            final previousLane = boss.toxicLaneAt(boss.age);
            boss.step(1 / 120, target: (x: start, y: 430));
            final lane = boss.toxicLaneAt(boss.age);
            for (final shot in boss.shots.where((s) => s.visible)) {
              expect(
                (shot.position.x - lane).abs(),
                greaterThanOrEqualTo(32 - 1e-6),
              );
              expect(shot.position.x, inInclusiveRange(24 - 1e-6, 336 + 1e-6));
              expect(shot.contact(previousLane, 430, lane, 430), isNull);
            }
            for (final wall in boss.toxicWalls) {
              expect(wall.gapAt(boss.age), greaterThanOrEqualTo(64));
            }
            // Once the first aim is locked, the lane never teleports or outruns
            // ordinary steering (the ball's actual maximum is 265 units/s).
            if (boss.age > 2.61)
              expect((lane - previousLane).abs() * 120, lessThan(100));
          }
        }
      }
    },
  );

  test(
    'real rolling physics can survive the hardest phase without shields or hits',
    () {
      final directions = <bool>{};
      for (final start in [45.0, 180.0, 315.0]) {
        for (final seed in [2, 7]) {
          final g = run()
            ..setControlMode(ControlMode.oneFinger)
            ..bossesEncountered = 5
            ..ballX = start;
          final boss = InfiniteBoss(kind: BossKind.venomCrown, seed: seed);
          g.boss = boss;
          g.grabControl();
          for (var frame = 0; frame < 28 * 120; frame++) {
            const dt = 1 / 120, sample = .02;
            final time = boss.age;
            final desired = boss.toxicLaneAt(time);
            final desiredVelocity =
                (boss.toxicLaneAt(time + sample) -
                    boss.toxicLaneAt(time - sample)) /
                (sample * 2);
            final acceleration =
                30 * (desired - g.ballX) +
                12 * (desiredVelocity - g.velocity) +
                .48 * g.velocity;
            final force = (acceleration / ((6 / 7) * 1700)).clamp(-.36, .36);
            final slope = force.abs() < 1e-8
                ? 0.0
                : (1 - math.sqrt(1 - 4 * force * force)) / (2 * force);
            g.setControlPosition(slope / .4375);
            g.survival.items.clear();
            g.stallTime = 0;
            g.step(dt);
            expect(
              g.lives,
              3,
              reason:
                  'start=$start seed=$seed boss age=${boss.age} x=${g.ballX} lane=$desired',
            );
            expect(g.survival.shield, 0);
            expect(g.survival.recovery, 0);
            expect(g.finished, isFalse);
          }
          advance(g, .02);
          expect(g.boss, isNull);
          directions.add(boss.toxicLaneAt(8) > 180);
        }
      }
      expect(
        directions.length,
        2,
        reason: 'Exercise both seeded corridor directions.',
      );
    },
  );

  test(
    'remaining stationary is unsafe despite the guaranteed moving route',
    () {
      final g = run()
        ..setControlMode(ControlMode.oneFinger)
        ..bossesEncountered = 5;
      g.boss = InfiniteBoss(kind: BossKind.venomCrown, seed: 7);
      advance(g, 26);
      expect(g.lives, lessThan(3));
    },
  );

  test('pulse and gauntlet change travel speed and narrow the opening', () {
    ToxicWall wall(BossPhase mode) =>
        ToxicWall(at: 2.6, top: 0, mode: mode, laneAt: (_) => 180);
    final normal = wall(BossPhase.toxicSlalom),
        pulse = wall(BossPhase.toxicPulse),
        finalWall = wall(BossPhase.toxicGauntlet);
    expect(pulse.yAt(.5), lessThan(normal.yAt(.5)));
    expect(pulse.yAt(2), greaterThan(normal.yAt(2)));
    expect(finalWall.yAt(.5), lessThan(normal.yAt(.5)));
    expect(finalWall.gapAt(20), lessThan(pulse.gapAt(20)));
    expect(pulse.gapAt(20), lessThan(normal.gapAt(20)));
  });

  test(
    'warning is harmless, nonlinear sweeps catch hits, and expired fractions are safe',
    () {
      final boss = InfiniteBoss(kind: BossKind.venomCrown);
      boss.step(2.61, target: (x: 180, y: 430));
      final shot = boss.shots.first;
      expect(shot.contact(24, 430, 24, 430), isNull);
      boss.step(4, target: (x: 300, y: 430));
      expect(shot.contact(24, 430, 24, 430), isNotNull);
      expect(shot.contact(1000, 430, 1000, 430), isNull);
      shot.step(.1);
      expect(shot.contact(24, 430, 24, 430), isNull);
    },
  );

  test(
    'Crown threshold, pause, damage protection, and toxic palette are integrated',
    () {
      final g = run();
      final slot = g.bossOrder.indexOf(BossKind.venomCrown);
      g.bossesEncountered = slot;
      g.survival.points = g.bossScoreThresholds[slot] - 1000.0;
      advance(g, .1);
      expect(g.bossPending, isFalse);
      g.survival.points = g.bossScoreThresholds[slot].toDouble();
      advance(g, 3.1);
      expect(g.boss!.kind, BossKind.venomCrown);
      expect(g.board, isEmpty);
      final boss = g.boss!;
      boss.step(5, target: (x: 180, y: 430));
      final positions = boss.shots.map((s) => s.position).toList();
      g.setPaused(true);
      advance(g, 3);
      expect(boss.shots.map((s) => s.position), positions);
      final canvas = ToxicPaletteCanvas();
      paintInfiniteBoss(canvas, g, false);
      expect(
        canvas.colors,
        containsAll([
          toxicLime.toARGB32(),
          toxicYellow.toARGB32(),
          toxicMagenta.toARGB32(),
        ]),
      );
      expect(canvas.draws, lessThanOrEqualTo(65));
      for (final protection in ['none', 'shield', 'recovery']) {
        final game = run()..bossesEncountered = 5;
        game.boss = InfiniteBoss(kind: BossKind.venomCrown)
          ..shots.add(
            LateEnemyShot(
              kind: LateShotKind.shard,
              origin: (x: game.ballX, y: game.screenY(game.ballY)),
              velocity: (x: 0, y: 0),
              delay: 0,
              life: 1,
              radiusOverride: 6,
            ),
          );
        if (protection == 'shield') game.survival.shield = 10;
        if (protection == 'recovery') game.survival.recovery = 10;
        game.step(1 / 120);
        expect(game.lives, protection == 'none' ? 2 : 3);
      }
    },
  );
}
