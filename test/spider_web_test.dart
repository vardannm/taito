import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/spiders.dart';
import 'package:balance_arcade/spider_web.dart';
import 'package:balance_arcade/infinite_progress.dart';

BalanceGame run() {
  final g = BalanceGame(seed: 12)..start(gameMode: GameMode.infinite);
  g.mazeSectionsEnabled = false;
  g.board.clear();
  g.spiders.clear();
  g.survival.items.clear();
  return g;
}

void main() {
  test('web warns harmlessly, moves slowly on a fixed aim, and expires', () {
    final web = SpiderWebShot(x: 100, y: 200, targetX: 200, targetY: 200);
    web.step(.8);
    expect(web.warning, true);
    expect(web.x, 100);
    expect(web.contact(100, 200, 100, 200), isNull);
    web.step(.4); // Only 0.2 seconds of actual flight.
    expect(web.x, closeTo(118, .001));
    expect(web.y, 200);
    expect(web.contact(115, 200, 115, 200), isNotNull);
    expect(web.contact(115, 235, 115, 235), isNull);
    web.step(.5);
    expect(web.x, closeTo(163, .001));
    expect(math.sqrt(web.vx * web.vx + web.vy * web.vy), 90);
    web.step(5);
    expect(web.expired, true);
    web.step(.01);
    expect(web.contact(web.x, web.y, web.x, web.y), isNull);
  });

  test(
    'visible spiders fire bounded shots; pause, breath and restart clear/freeze them',
    () {
      final g = run();
      g.spiders.add(BoardSpider(g.ballX - 130, g.ballY - 120, 38));
      g.step(1 / 120);
      expect(g.webShots.length, 1);
      final shot = g.webShots.single;
      expect(shot.warning, true);
      final target = (shot.targetX, shot.targetY);
      g.setPaused(true);
      g.step(.1);
      expect(shot.age, 0);
      g.setPaused(false);
      for (var i = 0; i < 100; i++) {
        g.survival.recovery = 100;
        g.stallTime = 0;
        g.step(.05);
        expect(
          g.webShots.length,
          lessThanOrEqualTo(InfiniteTuning.maxWebShots),
        );
      }
      expect((shot.targetX, shot.targetY), target);
      g.webShots.add(SpiderWebShot(x: 100, y: 200, targetX: 180, targetY: 400));
      g.maxHeight = 1800;
      g.step(1 / 120);
      expect(g.webShots, isEmpty);
      g.webShots.add(SpiderWebShot(x: 100, y: 200, targetX: 180, targetY: 400));
      g.start(gameMode: GameMode.classic, levelNumber: 31);
      expect(g.webShots, isEmpty);
      g.step(.1);
      expect(g.webShots, isEmpty);
    },
  );

  test('webs cost one heart and are consumed, including when shielded', () {
    for (final shielded in [false, true]) {
      final g = run();
      if (shielded) g.survival.shield = 10;
      g.webShots.add(
        SpiderWebShot(
          x: g.ballX,
          y: g.screenY(g.ballY),
          targetX: g.ballX,
          targetY: g.screenY(g.ballY),
          speed: 0,
          warningSeconds: 0,
        ),
      );
      g.step(1 / 120);
      expect(g.lives, shielded ? 3 : 2);
      expect(g.webShots, isEmpty);
      g.step(1 / 120);
      expect(g.lives, shielded ? 3 : 2);
    }
  });

  for (final shieldFirst in [true, false]) {
    test('web and shield swept contacts stay in order ($shieldFirst)', () {
      final g = run();
      g.webShots.add(
        SpiderWebShot(
          x: 180,
          y: 350,
          targetX: 180,
          targetY: 350,
          speed: 0,
          warningSeconds: 0,
        ),
      );
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
      expect(g.webShots, isEmpty);
    });
  }

  test('final-heart web hit ends the run', () {
    final g = run()..lives = 1;
    g.webShots.add(
      SpiderWebShot(
        x: g.ballX,
        y: g.screenY(g.ballY),
        targetX: g.ballX,
        targetY: g.screenY(g.ballY),
        speed: 0,
        warningSeconds: 0,
      ),
    );
    g.step(1 / 120);
    expect(g.lives, 0);
    expect(g.phase, isNot(GamePhase.playing));
    expect(g.message, contains('web'));
  });

  test(
    'circle holes warn before a slow complete orbit with both axes moving',
    () {
      final h = SpecialHazard(
        HazardKind.movingHole,
        x: 180,
        y: 300,
        motion: HazardMotion.circle,
        radiusX: InfiniteTuning.orbitRadius,
        period: InfiniteTuning.orbitPeriod,
        liveSeconds: InfiniteTuning.orbitLifeSeconds,
      );
      final start = (h.x, h.y);
      h.step(2, 216);
      expect((h.x, h.y), start);
      expect(h.hits(h.x, h.y, h.x, h.y), false);
      var minX = h.x, maxX = h.x, minY = h.y, maxY = h.y;
      for (var i = 0; i < 660; i++) {
        h.step(1 / 120, 216);
        minX = math.min(minX, h.x);
        maxX = math.max(maxX, h.x);
        minY = math.min(minY, h.y);
        maxY = math.max(maxY, h.y);
        expect(
          math.sqrt(math.pow(h.x - 180, 2) + math.pow(h.y - 300, 2)),
          closeTo(62, .001),
        );
      }
      expect(maxX - minX, closeTo(124, .01));
      expect(maxY - minY, closeTo(124, .01));
      expect(h.label, 'ORBITING HOLE');
      h.step(1 / 120, 216);
      expect(h.hits(h.x, h.y, h.x, h.y), true);
    },
  );
}
