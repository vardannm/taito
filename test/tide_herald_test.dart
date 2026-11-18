import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_boss.dart';
import 'package:balance_arcade/late_enemies.dart';
import 'infinite_boss_test.dart' show advance, run;

InfiniteBoss herald({double top = 0, int lap = 0}) =>
    InfiniteBoss(kind: BossKind.tideHerald, top: top, lap: lap);

void main() {
  test('Colossus opens at 25,000 to 32,000; Herald is second or third', () {
    expect(bossScoreWindows.first, (25000, 32000));
    final thresholds = <int>{};
    for (var seed = 0; seed < 200; seed++) {
      final game = BalanceGame(seed: seed)..start(gameMode: GameMode.infinite);
      expect(game.bossOrder.first, BossKind.stormColossus);
      expect(game.nextBossKind, BossKind.stormColossus);
      expect(
        game.bossOrder.indexOf(BossKind.tideHerald),
        inInclusiveRange(1, 2),
      );
      expect(game.bossScoreThresholds.first, inInclusiveRange(25000, 32000));
      thresholds.add(game.bossScoreThresholds.first);
    }
    // The exact score still varies from run to run.
    expect(thresholds.length, greaterThan(20));
  });

  test('it waits for its score, arrives once and the next boss is later', () {
    final game = run()
      ..survival.shield = 1e6
      ..lateEnemiesEnabled = false
      ..snakeEncountersEnabled = false;
    final slot = game.bossOrder.indexOf(BossKind.tideHerald);
    game.bossesEncountered = slot;
    final threshold = game.bossScoreThresholds[slot];
    game.survival.points = threshold - 2000.0;
    advance(game, 4);
    expect(game.boss, isNull);
    expect(game.bossWarningSeconds, isNull);
    game.survival.points = threshold.toDouble();
    advance(game, .1);
    expect(game.message, contains('TIDE HERALD IN 3'));
    advance(game, 3.1);
    expect(game.boss!.kind, BossKind.tideHerald);
    expect(game.boss!.displayName, 'TIDE HERALD');
    while (game.boss != null) {
      advance(game, 1 / 120);
    }
    expect(game.bossesCleared, 1);
    // Still far below the next window: play simply carries on.
    game.survival.points = 60000;
    advance(game, 70);
    expect(game.boss, isNull);
    expect(game.bossPending, isFalse);
    expect(game.nextBossKind, isNot(BossKind.tideHerald));
  });

  test('three phases in order, every attack finished before it leaves', () {
    final boss = herald(top: -100);
    final seen = <LateEnemyShot>{};
    var bubbles = 0, waves = 0, geysers = 0;
    final phases = <BossPhase>[];
    for (var i = 0; i < 28 * 120; i++) {
      boss.step(1 / 120, target: (x: 180, y: 420), scrollDistance: 1.5);
      if (phases.isEmpty || phases.last != boss.phase) phases.add(boss.phase);
      for (final shot in boss.shots) {
        if (!seen.add(shot)) continue;
        if (shot.kind == LateShotKind.shard) {
          expect(boss.phase, BossPhase.driftBubbles);
          bubbles++;
        } else if (shot.dashes != null) {
          expect(boss.phase, BossPhase.tideWaves);
          waves++;
        } else {
          expect(shot.kind, LateShotKind.laser);
          expect(boss.phase, BossPhase.geysers);
          geysers++;
        }
      }
      expect(boss.shots.length, lessThanOrEqualTo(12));
      if (boss.phase == BossPhase.leaving) {
        expect(boss.shots.where((shot) => shot.visible), isEmpty);
      }
      if (boss.age >= 2 && boss.age <= 26) {
        expect(boss.position.x, inInclusiveRange(142.0, 218.0));
        expect(boss.position.y, inInclusiveRange(0.0, 10.0));
      }
    }
    expect(phases, [
      BossPhase.arriving,
      BossPhase.driftBubbles,
      BossPhase.tideWaves,
      BossPhase.geysers,
      BossPhase.leaving,
    ]);
    expect(bubbles, 12);
    expect(waves, 3);
    expect(geysers, 10);
    boss.step(.01, target: (x: 180, y: 420));
    expect(boss.expired, isTrue);
  });

  test('bubbles keep to their columns and leave open lanes between them', () {
    for (final aim in [30.0, 60.0, 180.0, 255.0, 330.0]) {
      final boss = herald()..step(2.61, target: (x: aim, y: 430));
      final volley = boss.shots.toList();
      expect(volley, hasLength(3));
      for (var t = .9; t < volley.first.life; t += .05) {
        final xs = volley.map((shot) => shot.positionAt(t).x).toList()..sort();
        // The whole volley sways together, so each lane keeps its width.
        expect(xs[1] - xs[0], closeTo(InfiniteBoss.tideBubbleSpacing, 1e-6));
        expect(xs[2] - xs[1], closeTo(InfiniteBoss.tideBubbleSpacing, 1e-6));
        expect(xs.first, greaterThanOrEqualTo(24));
        expect(xs.last, lessThanOrEqualTo(336));
      }
      // Slow enough to read: about three seconds from the Herald to the ball.
      final first = volley.first;
      expect(
        (first.positionAt(1).y - first.positionAt(0).y),
        lessThanOrEqualTo(110),
      );
    }
  });

  test('a wave marks two openings, then only its lit parts can hurt', () {
    for (var wave = 0; wave < 3; wave++) {
      final boss = herald();
      boss.step(10.2 + wave * 2.3 + .01, target: (x: 180, y: 430));
      final shot = boss.shots.lastWhere((s) => s.dashes != null);
      final lit = shot.dashes!.segments(312, 0);
      final litLength = lit.fold(0.0, (sum, s) => sum + s.$2 - s.$1);
      expect(litLength, closeTo(312 - 2 * InfiniteBoss.tideWaveGap, 1e-6));
      // Harmless while it is only a warning.
      expect(shot.visible, isFalse);
      expect(shot.contact(180, 430, 180, 430), isNull);
      boss.step(InfiniteBoss.laserWarning, target: (x: 180, y: 430));
      expect(shot.visible, isTrue);
      // Stand still at every column while the wave rolls down past y = 430.
      final hit = <int>{};
      while (shot.visible) {
        boss.step(1 / 120, target: (x: 180, y: 430));
        for (var x = 28; x <= 332; x++) {
          if (shot.contact(x + .0, 430, x + .0, 430) != null) hit.add(x);
        }
      }
      final safe = [
        for (var x = 28; x <= 332; x++)
          if (!hit.contains(x)) x,
      ];
      expect(hit, isNotEmpty);
      // Both openings stay wide for the ball's centre despite the slow drift.
      expect(safe.length, greaterThanOrEqualTo(100));
      var runs = 0, longest = 0, current = 0;
      for (var x = 28; x <= 333; x++) {
        if (safe.contains(x)) {
          if (current++ == 0) runs++;
          if (current > longest) longest = current;
        } else {
          current = 0;
        }
      }
      expect(runs, inInclusiveRange(2, 3));
      expect(longest, greaterThanOrEqualTo(45));
    }
  });

  test('geysers alternate, warn first and leave time to change lanes', () {
    final boss = herald();
    final seen = <LateEnemyShot>{};
    final sets = <double, List<double>>{};
    while (boss.age < 26) {
      boss.step(1 / 120, target: (x: 180, y: 430));
      for (final shot in boss.shots) {
        if (shot.dashes != null ||
            shot.kind != LateShotKind.laser ||
            !seen.add(shot)) {
          continue;
        }
        // Marking time: every geyser of one set shares it.
        final at = boss.age - shot.age - InfiniteBoss.laserWarning;
        sets.putIfAbsent((at * 10).round() / 10, () => []).add(shot.origin.x);
      }
    }
    expect(sets.keys.toList()..sort(), [18.0, 19.8, 21.6, 23.4]);
    expect(sets[18.0]!..sort(), [55, 180, 305]);
    expect(sets[19.8]!..sort(), [117.5, 242.5]);
    expect(sets[21.6]!..sort(), [55, 180, 305]);
    expect(sets[23.4]!..sort(), [117.5, 242.5]);
    // One set is spent well before the next goes live.
    expect(1.8 - InfiniteBoss.tideGeyserLife, greaterThanOrEqualTo(.75));
    // The ball's centre is safe anywhere in the lanes between live columns,
    // and each lane of one set sits inside a column of the other.
    const reach = 7 + InfiniteBoss.tideGeyserRadius;
    for (final (live, lanes) in [
      ([55.0, 180.0, 305.0], [117.5, 242.5]),
      ([117.5, 242.5], [55.0, 180.0, 305.0]),
    ]) {
      for (final lane in lanes) {
        for (final x in live) {
          expect((lane - x).abs() - reach, greaterThanOrEqualTo(25));
        }
      }
    }
  });

  test('a geyser only hurts inside its marked column while it is live', () {
    final boss = herald()..step(18.01, target: (x: 180, y: 430));
    final middle = boss.shots.singleWhere((s) => s.origin.x == 180);
    expect(middle.contact(180, 430, 180, 430), isNull);
    boss.step(InfiniteBoss.laserWarning - .1, target: (x: 180, y: 430));
    expect(middle.visible, isFalse);
    boss.step(.2, target: (x: 180, y: 430));
    expect(middle.visible, isTrue);
    expect(middle.contact(180, 430, 180, 430), isNotNull);
    expect(middle.contact(205, 430, 205, 430), isNotNull);
    expect(middle.contact(117.5, 430, 117.5, 430), isNull);
    expect(middle.contact(242.5, 430, 242.5, 430), isNull);
    boss.step(InfiniteBoss.tideGeyserLife, target: (x: 180, y: 430));
    expect(middle.visible, isFalse);
  });

  test('a simple, slow dodge clears the whole fight without a hit', () {
    // A plain player: when the spot it stands on will be hit within the next
    // .8 seconds, it rolls at half of the ball's top speed to the nearest
    // spot that stays safe longest. No frame-perfect movement is needed.
    for (final top in [0.0, -130.0, -250.0]) {
      for (final startX in [40.0, 180.0, 320.0]) {
        final boss = herald(top: top);
        var x = startX;
        const y = 430.0, speed = 130.0, dt = 1 / 120, horizon = .8;
        // Seconds until standing at [at] is dangerous, up to the horizon.
        double safeFor(double at) {
          var soonest = horizon;
          for (final shot in boss.shots) {
            if (shot.cancelled) continue;
            for (var ahead = 0.0; ahead < soonest; ahead += .04) {
              final t = shot.age + ahead;
              if (t < 0) continue;
              if (t > shot.life) break;
              final bool danger;
              if (shot.kind == LateShotKind.shard) {
                final p = shot.positionAt(t);
                danger = (p.x - at).abs() < 24 && (p.y - y).abs() < 30;
              } else if (shot.dashes != null) {
                danger =
                    (shot.beamAt(t).start.y - y).abs() < 30 &&
                    shot.dashes!.covers(at - 24, 312, t, 22);
              } else {
                danger = (shot.origin.x - at).abs() < 34;
              }
              if (danger) {
                soonest = ahead;
                break;
              }
            }
          }
          return soonest;
        }

        final hits = <String>[];
        while (!boss.expired) {
          var goal = x;
          if (safeFor(x) < horizon) {
            var best = -1.0;
            for (var candidate = 30.0; candidate <= 330; candidate += 4) {
              final travel = (candidate - x).abs() / speed;
              final safe = safeFor(candidate);
              // Only spots it can reach before they turn dangerous.
              if (safe <= travel) continue;
              final value = safe - travel * .25;
              if (value > best) {
                best = value;
                goal = candidate;
              }
            }
          }
          final before = x;
          x += (goal - x).clamp(-speed * dt, speed * dt);
          boss.step(dt, target: (x: x, y: y), scrollDistance: 1);
          for (final shot in boss.shots) {
            if (shot.contact(before, y, x, y) != null) {
              hits.add('${shot.reason} at ${boss.age.toStringAsFixed(2)}');
            }
          }
        }
        expect(hits, isEmpty, reason: 'top $top, start $startX');
      }
    }
  });

  test('a Herald hit costs one heart and respects the shield', () {
    for (final shielded in [false, true]) {
      final game = run()..bossesEncountered = 1;
      final boss = herald();
      game.boss = boss;
      boss.shots.add(
        LateEnemyShot(
          kind: LateShotKind.laser,
          origin: (x: game.ballX, y: 170),
          velocity: (x: 0, y: 0),
          delay: 0,
          life: InfiniteBoss.tideGeyserLife,
          beamEnd: (x: game.ballX, y: 537),
          radiusOverride: InfiniteBoss.tideGeyserRadius,
          reasonOverride: 'Herald geyser. Step out of the marked column.',
        ),
      );
      if (shielded) game.survival.shield = 10;
      game.step(1 / 120);
      expect(game.lives, shielded ? 3 : 2);
      expect(game.boss, isNotNull);
    }
  });

  test('Overdrive brings the Herald back, faster and renamed', () {
    final boss = herald(lap: 1);
    expect(boss.displayName, 'TIDE HERALD II');
    expect(boss.pace, closeTo(1.12, 1e-9));
  });
}
