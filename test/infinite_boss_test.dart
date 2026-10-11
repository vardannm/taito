import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_boss.dart';
import 'package:balance_arcade/late_enemies.dart';
import 'package:balance_arcade/porcupines.dart';
import 'package:balance_arcade/spiders.dart';

BalanceGame run() => BalanceGame(seed: 7)
  ..start(gameMode: GameMode.infinite)
  ..mazeSectionsEnabled = false
  ..board.clear()
  ..survival.items.clear();

void advance(BalanceGame game, double seconds) {
  for (var i = 0; i < (seconds * 120).ceil(); i++) {
    game.stallTime = 0;
    game.step(1 / 120);
  }
}

void main() {
  test(
    'boss triggers at its chosen score once, only in active Infinite play',
    () {
      final game = run()..survival.points = 0;
      game.step(1 / 120);
      expect(game.boss, isNull);
      game.survival.points = game.bossScoreThresholds.first.toDouble();
      game.setPaused(true);
      advance(game, 1);
      expect(game.boss, isNull);
      game.setPaused(false);
      advance(game, 3.1);
      expect(game.boss, isNotNull);
      expect(game.bossesEncountered, 1);
      game.boss = null;
      advance(game, .2);
      expect(game.boss, isNull);
      for (final mode in GameMode.values.where((m) => m != GameMode.infinite)) {
        game.start(gameMode: mode);
        game.survival.points = 200000;
        advance(game, .1);
        expect(game.boss, isNull);
        expect(game.bossesEncountered, 0);
      }
      game.start(gameMode: GameMode.infinite, waitForInput: true);
      game.survival.points = 120000;
      advance(game, 1);
      expect(game.boss, isNull);
      game.beginInput();
      advance(game, 3.1);
      expect(game.boss, isNotNull);
    },
  );

  test('boss waits for a committed attack, then owns a clear arena', () {
    final game = run()
      ..survival.points = 120000
      ..survival.shield = 100;
    final visitor = LateEnemyEncounter(
      kind: LateEnemyKind.cricket,
      origin: (x: 43, y: 160),
      target: (x: 180, y: 420),
    );
    game.lateEnemy = visitor;
    game.step(1 / 120);
    expect(game.boss, isNull);
    expect(game.lateEnemy, same(visitor));
    while (!visitor.expired) {
      game.survival.items.clear();
      game.survival.shield = 100;
      game.step(1 / 120);
      expect(game.boss, isNull);
    }
    game.board.add(Hole(game.ballX, game.ballY - 100));
    game.spiders.add(BoardSpider(80, game.ballY - 300, 45));
    game.porcupines.add(BoardPorcupine(280, game.ballY - 300));
    advance(game, 3.1);
    expect(game.boss, isNotNull);
    final score = game.score, camera = game.cameraOffset;
    final serial = game.runSerial;
    while (game.boss != null) {
      expect(game.board, isEmpty);
      expect(game.spiders, isEmpty);
      expect(game.porcupines, isEmpty);
      expect(game.snakes, isEmpty);
      expect(game.lateEnemy, isNull);
      expect(game.specialHazards, isEmpty);
      expect(game.mazeGates, isEmpty);
      expect(game.mazeSection, isFalse);
      expect(game.webShots, isEmpty);
      expect(game.quills, isEmpty);
      expect(game.dangerActive, isFalse);
      game.survival.items.clear();
      game.survival.shield = 100;
      game.step(1 / 120);
    }
    expect(game.finished, isFalse);
    expect(game.lives, 3);
    expect(game.score, greaterThan(score));
    expect(game.cameraOffset, greaterThan(camera));
    expect(game.runSerial, serial);
    expect(game.message, contains('BOSS CLEARED'));
    advance(game, .1);
    expect(game.board, isNotEmpty);
    expect(
      game.board.every((hole) => game.screenY(hole.y) < game.visibleTop),
      isTrue,
    );
    advance(game, .5);
    expect(game.boss, isNull);
  });

  test('pause freezes boss movement, warnings, bullets and pools', () {
    final game = run()
      ..survival.points = 120000
      ..survival.shield = 100;
    advance(game, 3.1);
    final boss = game.boss!;
    final age = boss.age, camera = game.cameraOffset;
    final position = boss.position;
    final shotAges = boss.shots.map((shot) => shot.age).toList();
    game.setPaused(true);
    advance(game, 5);
    expect(boss.age, age);
    expect(boss.position, position);
    expect(boss.shots.map((shot) => shot.age), shotAges);
    expect(game.cameraOffset, camera);
    game.setPaused(false);
    advance(game, .1);
    expect(boss.age, greaterThan(age));
    expect(game.cameraOffset, greaterThan(camera));
  });

  test('a pending boss waits for the maze and its final gates to leave', () {
    final game = run()
      ..mazeSectionsEnabled = true
      ..maxHeight = 8000
      ..survival.shield = 100;
    game.step(1 / 120);
    expect(game.mazeSection, isTrue);
    game.survival.points = 120000;
    game.step(1 / 120);
    expect(game.boss, isNull);
    for (var i = 0; i < 120 * 50 && game.boss == null; i++) {
      game.survival.items.clear();
      game.survival.shield = 100;
      game.stallTime = 0;
      if (game.mazeSection || game.mazeGates.isNotEmpty) {
        expect(game.boss, isNull);
      }
      game.step(1 / 120);
    }
    expect(game.boss, isNotNull);
    expect(game.mazeSection, isFalse);
    expect(game.mazeGates, isEmpty);
    expect(game.board, isEmpty);
    expect(game.specialHazards, isEmpty);
    // A maze cannot start during any of the boss's attack phases.
    game.maxHeight += 20000;
    while (game.boss != null) {
      game.survival.items.clear();
      game.survival.shield = 100;
      game.step(1 / 120);
      expect(game.mazeSection, isFalse);
      expect(game.mazeGates, isEmpty);
    }
  });

  test(
    'boss follows the climb, attacks in order and leaves after 28 seconds',
    () {
      final boss = InfiniteBoss(top: -100);
      final phases = <BossPhase>{};
      var bullets = 0, lasers = 0, bombs = 0, pools = 0;
      final seen = <LateEnemyShot>{};
      for (var i = 0; i < 28 * 120; i++) {
        boss.step(1 / 120, target: (x: 180, y: 400), scrollDistance: 1.5);
        phases.add(boss.phase);
        for (final shot in boss.shots) {
          if (!seen.add(shot)) continue;
          switch (shot.kind) {
            case LateShotKind.shard:
              expect(boss.phase, BossPhase.bullets);
              bullets++;
            case LateShotKind.laser:
              expect(boss.phase, BossPhase.lasers);
              lasers++;
            case LateShotKind.bomb:
              expect(boss.phase, BossPhase.pools);
              bombs++;
            case LateShotKind.acid:
              expect(boss.phase, BossPhase.pools);
              pools++;
            default:
              fail('Unexpected boss shot ${shot.kind}');
          }
        }
        expect(boss.shots.length, lessThanOrEqualTo(15));
        if (boss.age >= 2 && boss.age <= 26) {
          expect(boss.position.y, 5);
          expect(boss.position.x, inInclusiveRange(125.0, 235.0));
        }
      }
      boss.step(.01, target: (x: 180, y: 400));
      expect(boss.expired, isTrue);
      expect(
        phases,
        containsAll([
          BossPhase.arriving,
          BossPhase.bullets,
          BossPhase.lasers,
          BossPhase.pools,
          BossPhase.leaving,
        ]),
      );
      expect(bullets, 25);
      expect(lasers, 3);
      expect(bombs, 6);
      expect(pools, 6);
      expect(boss.shots, isEmpty);
    },
  );

  test('boss laser warns harmlessly and locks its aim before firing', () {
    final boss = InfiniteBoss();
    boss.step(10.01, target: (x: 180, y: 430));
    final beam = boss.shots.singleWhere((s) => s.kind == LateShotKind.laser);
    final endpoint = beam.beamEnd;
    expect(beam.visible, isFalse);
    expect(beam.contact(180, 430, 180, 430), isNull);
    boss.step(1, target: (x: 300, y: 400));
    expect(beam.visible, isFalse);
    boss.step(.2, target: (x: 300, y: 400));
    expect(beam.visible, isTrue);
    expect(beam.beamEnd, endpoint);
    expect(beam.contact(180, 430, 180, 430), isNotNull);
    expect(beam.contact(300, 430, 300, 430), isNull);
  });

  test('boss bullets reach the platform on expanded portrait boards', () {
    final boss = InfiniteBoss(top: -250);
    boss.step(2.6, target: (x: 180, y: 430));
    final center = boss.shots[2];
    boss.step(2.4, target: (x: 180, y: 430));
    expect(center.visible, isTrue);
    expect(center.position.x, closeTo(180, 1e-8));
    expect(center.position.y, closeTo(430, 1e-8));
    expect(center.contact(180, 430, 180, 430), isNotNull);
  });

  test('thrown pools warn, land, scroll with the floor and expire', () {
    final boss = InfiniteBoss();
    boss.step(18.01, target: (x: 180, y: 400));
    final pool = boss.shots.firstWhere((s) => s.kind == LateShotKind.acid);
    expect(pool.visible, isFalse);
    expect(pool.contact(180, 400, 180, 400), isNull);
    expect(pool.position.y, 400);
    boss.step(.8, target: (x: 180, y: 400), scrollDistance: 80);
    expect(pool.position.y, 400);
    boss.step(.2, target: (x: 180, y: 400), scrollDistance: 20);
    expect(pool.visible, isTrue);
    expect(pool.position.y, greaterThan(400));
    final at = pool.position;
    boss.step(.1, target: (x: 180, y: 400));
    expect(pool.contact(at.x, at.y, at.x, at.y), isNotNull);
    expect(pool.contact(at.x + 50, at.y, at.x + 50, at.y), isNull);
    boss.step(3, target: (x: 180, y: 400));
    expect(pool.visible, isFalse);
  });

  for (final kind in [
    LateShotKind.shard,
    LateShotKind.laser,
    LateShotKind.acid,
  ]) {
    test('boss $kind costs one heart and respects shields and recovery', () {
      for (final protection in ['none', 'shield', 'recovery']) {
        final game = run()..bossesEncountered = 1;
        final shot = LateEnemyShot(
          kind: kind,
          origin: (x: game.ballX, y: game.screenY(game.ballY)),
          velocity: (x: 0, y: 0),
          delay: 0,
          life: 2,
          radiusOverride: kind == LateShotKind.acid ? 30 : 4,
          beamEnd: (x: game.ballX, y: 537),
          reasonOverride: 'Boss hit',
        );
        game.boss = InfiniteBoss()..shots.add(shot);
        if (protection == 'shield') game.survival.shield = 10;
        if (protection == 'recovery') game.survival.recovery = 10;
        game.step(1 / 120);
        expect(game.lives, protection == 'none' ? 2 : 3);
        expect(game.boss, isNotNull);
        advance(game, .1);
        expect(game.lives, protection == 'none' ? 2 : 3);
      }
    });
  }

  test('lethal hit, revive and restart clean up boss state', () {
    final game = run()
      ..lives = 1
      ..bossesEncountered = 1;
    game.boss = InfiniteBoss()
      ..shots.add(
        LateEnemyShot(
          kind: LateShotKind.acid,
          origin: (x: game.ballX, y: game.screenY(game.ballY)),
          velocity: (x: 0, y: 0),
          delay: 0,
          life: 3,
        ),
      );
    game.step(1 / 120);
    expect(game.lives, 0);
    expect(game.boss, isNull);
    advance(game, 1);
    expect(game.reviveInfinite(), isTrue);
    game.survival.points = 120000;
    advance(game, .1);
    expect(game.boss, isNull);
    game.start(gameMode: GameMode.infinite);
    expect(game.bossesEncountered, 0);
    game.survival.points = 120000;
    advance(game, 3.1);
    expect(game.boss, isNotNull);
  });
}
