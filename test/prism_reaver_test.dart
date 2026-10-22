import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/infinite_boss.dart';
import 'package:balance_arcade/late_enemies.dart';
import 'infinite_boss_test.dart' show run, advance;

const target = (x: 180.0, y: 430.0);

void main() {
  test(
    'fourth boss has single/twin sweeps then rotors, all clear before exit',
    () {
      final boss = InfiniteBoss(kind: BossKind.prismReaver, seed: 7);
      final seen = <LateEnemyShot>{};
      final counts = <BossPhase, int>{};
      for (var frame = 0; frame <= 28 * 120; frame++) {
        boss.step(1 / 120, target: target);
        for (final shot in boss.shots) {
          if (!seen.add(shot)) continue;
          counts.update(boss.phase, (n) => n + 1, ifAbsent: () => 1);
          expect(
            shot.kind,
            boss.phase == BossPhase.rotors
                ? LateShotKind.spinner
                : LateShotKind.laser,
          );
        }
        expect(boss.shots.length, lessThanOrEqualTo(12));
        if (boss.age >= 26) expect(boss.shots.any((s) => s.visible), isFalse);
      }
      expect(counts, {
        BossPhase.sweepingLaser: 2,
        BossPhase.twinLasers: 4,
        BossPhase.rotors: 12,
      });
      expect(boss.expired, isTrue);
      expect(boss.shots, isEmpty);
    },
  );

  test(
    'moving emitters, sweep endpoints and twin escape lane on tall boards',
    () {
      for (final top in [0.0, -250.0]) {
        final boss = InfiniteBoss(kind: BossKind.prismReaver, top: top);
        boss.step(10.21, target: target);
        final beams = boss.shots
            .where((s) => s.kind == LateShotKind.laser && s.age < s.life)
            .toList();
        expect(beams.length, 2);
        final initial = beams.first.beam;
        expect(beams.first.contact(180, 430, 180, 430), isNull);
        boss.step(1.3, target: (x: 300, y: 430));
        expect(beams.first.visible, isTrue);
        expect(beams.first.beam.start, isNot(initial.start));
        expect(beams.first.beam.end, isNot(initial.end));
        for (var t = 0.0; t <= 1.65; t += .01) {
          final segments = beams.map((s) => s.beamAt(t)).toList();
          for (final segment in segments) {
            expect(segment.end.x, inInclusiveRange(24 - 1e-8, 336 + 1e-8));
            expect(segment.end.y, lessThanOrEqualTo(537 + 1e-8));
          }
          // At the platform the two rays retain a substantial gap; a ray that
          // exits a rail early cannot block that central lane either.
          double laneX(EnemyBeam b) =>
              b.start.x +
              (430 - b.start.y) * (b.end.x - b.start.x) / (b.end.y - b.start.y);
          expect(
            (laneX(segments[0]) - laneX(segments[1])).abs(),
            greaterThan(150),
          );
        }
      }
    },
  );

  test(
    'moving beam catches a stationary ball and fast crossing on a long tick',
    () {
      final beam = LateEnemyShot(
        kind: LateShotKind.laser,
        origin: (x: 100, y: 100),
        velocity: (x: 0, y: 0),
        delay: 1,
        life: 1,
        beamPath: (t) => (
          start: (x: 100 + t * 160, y: 100),
          end: (x: 100 + t * 160, y: 500),
        ),
      );
      beam.step(.9);
      expect(beam.contact(180, 300, 180, 300), isNull);
      beam.step(1.2);
      expect(beam.contact(180, 300, 180, 300), inInclusiveRange(.08, .92));
      expect(beam.contact(300, 300, 60, 300), isNotNull);
      expect(beam.contact(320, 300, 320, 300), isNull);
      beam.step(.1);
      expect(beam.contact(180, 300, 180, 300), isNull);
    },
  );

  test(
    'rotating laser sweeps its full length without damaging warning/expired time',
    () {
      final beam = LateEnemyShot(
        kind: LateShotKind.laser,
        origin: (x: 180, y: 100),
        velocity: (x: 0, y: 0),
        delay: 1,
        life: 1,
        beamPath: (t) {
          final angle = math.pi / 2 + (t - .5) * .8;
          return (
            start: (x: 180, y: 100),
            end: (
              x: 180 + math.cos(angle) * 400,
              y: 100 + math.sin(angle) * 400,
            ),
          );
        },
      );
      beam.step(.8);
      expect(beam.contact(180, 300, 180, 300), isNull);
      beam.step(1.4);
      expect(beam.contact(180, 300, 180, 300), isNotNull);
      expect(beam.contact(335, 300, 335, 300), isNull);
      beam.step(.1);
      expect(beam.contact(180, 300, 180, 300), isNull);
    },
  );

  test(
    'rotors vary seeded paths and spin, and sweep collisions along curves',
    () {
      List<LateEnemyShot> rotors(int seed, double dt) {
        final boss = InfiniteBoss(kind: BossKind.prismReaver, seed: seed);
        while (boss.age < 19) boss.step(dt, target: target);
        return boss.shots.where((s) => s.kind == LateShotKind.spinner).toList();
      }

      final a = rotors(7, 1 / 120),
          b = rotors(7, 1 / 60),
          c = rotors(8, 1 / 120);
      expect(a.length, 4);
      expect(a.map((s) => s.positionAt(1)), b.map((s) => s.positionAt(1)));
      expect(
        a.map((s) => s.positionAt(1)),
        isNot(c.map((s) => s.positionAt(1))),
      );
      expect(a.map((s) => s.pathFrequency).toSet().length, 3);
      for (final shot in a) {
        expect(shot.positionAt(0), shot.origin);
        final point = shot.positionAt(1.5);
        final rotation = shot.rotation;
        shot.step(2);
        expect(shot.contact(point.x, point.y, point.x, point.y), isNotNull);
        expect(shot.rotation, isNot(rotation));
        expect(shot.contact(1000, 1000, 1000, 1000), isNull);
      }
    },
  );

  test(
    'Reaver unlock preserves arena, pause, hearts, shields, and recovery',
    () {
      final game = run();
      final slot = game.bossOrder.indexOf(BossKind.prismReaver);
      game.bossesEncountered = slot;
      game.survival.points = game.bossScoreThresholds[slot] - 1000.0;
      advance(game, .1);
      expect(game.bossPending, isFalse);
      game.survival.points = game.bossScoreThresholds[slot].toDouble();
      advance(game, 3.1);
      expect(game.boss!.kind, BossKind.prismReaver);
      expect(game.bossesEncountered, slot + 1);
      expect(game.board, isEmpty);
      final boss = game.boss!;
      game.setPaused(true);
      final position = boss.position;
      advance(game, 5);
      expect(boss.position, position);
      game.setPaused(false);
      for (final kind in [LateShotKind.spinner, LateShotKind.laser]) {
        for (final protection in ['none', 'shield', 'recovery']) {
          final g = run()..bossesEncountered = 4;
          g.boss = InfiniteBoss(kind: BossKind.prismReaver)
            ..shots.add(
              LateEnemyShot(
                kind: kind,
                origin: (x: g.ballX, y: g.screenY(g.ballY)),
                beamEnd: (x: g.ballX, y: 537),
                velocity: (x: 0, y: 0),
                delay: 0,
                life: 2,
              ),
            );
          if (protection == 'shield') g.survival.shield = 10;
          if (protection == 'recovery') g.survival.recovery = 10;
          g.step(1 / 120);
          expect(g.lives, protection == 'none' ? 2 : 3);
        }
      }
    },
  );
}
