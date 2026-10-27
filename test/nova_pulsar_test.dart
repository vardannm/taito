import 'dart:math' as math;

import 'package:balance_arcade/infinite_boss.dart';
import 'package:balance_arcade/late_enemies.dart';
import 'package:flutter_test/flutter_test.dart';

/// Steps [shot] until it is live, then checks a ball moving [from] → [to].
bool hits(LateEnemyShot shot, EnemyPoint from, EnemyPoint to) {
  while (shot.age < .05) {
    shot.step(1 / 120);
  }
  return shot.contact(from.x, from.y, to.x, to.y) != null;
}

void main() {
  test('dash segments slide and only lit dashes touch', () {
    const dashes = LaserDashes(length: 60, gap: 40, speed: 50);
    expect(dashes.segments(300, 0).first, (0.0, 60.0));
    expect(dashes.segments(300, 0)[1], (100.0, 160.0));
    // One second later every dash has slid 50 units along the beam.
    expect(dashes.segments(300, 1)[1], (50.0, 110.0));
    expect(dashes.covers(80, 300, 0, 0), isFalse);
    expect(dashes.covers(80, 300, 0, 25), isTrue);
  });

  test('a dashed boss laser lets the ball through its gaps only', () {
    LateEnemyShot beam() => LateEnemyShot(
      kind: LateShotKind.laser,
      origin: (x: 180, y: 100),
      velocity: (x: 0, y: 0),
      delay: 0,
      life: 2,
      beamEnd: (x: 180, y: 500),
      radiusOverride: 4,
      dashes: const LaserDashes(length: 60, gap: 54),
    );
    // Lit 100–160, 214–274, …; the gap 160–214 is clear by 11 + 11 units.
    expect(hits(beam(), (x: 170, y: 187), (x: 190, y: 187)), isFalse);
    expect(hits(beam(), (x: 170, y: 130), (x: 190, y: 130)), isTrue);
    expect(hits(beam(), (x: 170, y: 244), (x: 190, y: 244)), isTrue);
  });

  test('a growing ring hits on its lit band and not in an opening', () {
    LateEnemyShot ring() => LateEnemyShot(
      kind: LateShotKind.laser,
      origin: (x: 180, y: 100),
      velocity: (x: 0, y: 0),
      delay: 0,
      life: 5,
      radiusOverride: 4,
      // One opening straight down (π/2), 0.4 radians wide.
      ring: const LaserRing(
        startRadius: 30,
        speed: 100,
        gaps: [(math.pi / 2 - .2, .4)],
      ),
    );
    // A resting ball straight below, as the ring grows through 200 units.
    var shot = ring();
    for (var i = 0; i < 240; i++) {
      shot.step(1 / 120);
      expect(shot.contact(180, 300, 180, 300), isNull);
    }
    // The same ball off to the side, on the lit part of the ring.
    shot = ring();
    final side = (x: 180 + 200 * math.cos(1.0), y: 100 + 200 * math.sin(1.0));
    var hit = false;
    for (var i = 0; i < 240 && !hit; i++) {
      shot.step(1 / 120);
      hit = shot.contact(side.x, side.y, side.x, side.y) != null;
    }
    expect(hit, isTrue);
  });

  test('Nova Pulsar runs rings, dashed rails, then the lance', () {
    final boss = InfiniteBoss(kind: BossKind.novaPulsar, seed: 3);
    final seen = <BossPhase>{};
    final rings = <LateEnemyShot>[], beams = <LateEnemyShot>[];
    for (var i = 0; i < 28 * 120; i++) {
      boss.step(1 / 120, target: (x: 90, y: 430));
      seen.add(boss.phase);
      for (final shot in boss.shots) {
        if (shot.ring != null && !rings.contains(shot)) rings.add(shot);
        if (shot.dashes != null && !beams.contains(shot)) beams.add(shot);
      }
    }
    expect(seen, containsAll([
      BossPhase.novaRings,
      BossPhase.dashedRails,
      BossPhase.novaLance,
    ]));
    expect(rings, hasLength(6));
    expect(beams, hasLength(5), reason: 'two pairs of rails and one lance');
    expect(boss.displayName, 'NOVA PULSAR');
  });

  test('every opening is wider than the ball and beam, and faces down', () {
    for (var seed = 0; seed < 40; seed++) {
      final boss = InfiniteBoss(kind: BossKind.novaPulsar, seed: seed);
      final rings = <LateEnemyShot>{}, beams = <LateEnemyShot>{};
      for (var i = 0; i < 28 * 60; i++) {
        boss.step(1 / 60, target: (x: seed.isEven ? 60 : 300, y: 430));
        for (final shot in boss.shots) {
          if (shot.ring != null) rings.add(shot);
          if (shot.dashes != null) beams.add(shot);
        }
      }
      // Ball (7) plus beam (4) on both sides of an opening.
      const body = 2 * (7 + 4.0);
      for (final shot in rings) {
        final ring = shot.ring!;
        final (start, width) = ring.gaps.first;
        final down = start + width / 2;
        expect(down, inInclusiveRange(math.pi * .35, math.pi * .65));
        // At least four openings, so one is always within reach.
        expect(ring.gaps.length, greaterThanOrEqualTo(4));
        // Even 120 units from the core the opening fits the ball easily.
        for (final (_, w) in ring.gaps) {
          expect(w * 120, greaterThan(body * 1.5));
        }
      }
      for (final shot in beams) {
        expect(shot.dashes!.gap, greaterThan(body * 2));
      }
      // The lance starts on the side away from the player.
      final lance = beams.firstWhere((b) => b.life > 5);
      final startX = lance.beamAt(0).start.x;
      expect((startX - 180).sign, seed.isEven ? 1 : -1);
    }
  });
}
