import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:balance_arcade/porcupines.dart';
import 'package:balance_arcade/snakes.dart';
import 'package:balance_arcade/spiders.dart';
import 'package:balance_arcade/spider_web.dart';

BalanceGame run({double metres = 0}) {
  final g = BalanceGame(seed: 12)..start(gameMode: GameMode.infinite);
  g.mazeSectionsEnabled = false;
  g.maxHeight = metres * 10;
  g.board.clear();
  g.survival.items.clear();
  return g;
}

void main() {
  test('snakes slither diagonally in both directions with a tapered body', () {
    for (final fromLeft in [true, false]) {
      final s = BoardSnake(x: 180, y: 100, fromLeft: fromLeft);
      final before = s.points.toList();
      s.step(.2);
      expect(s.x, closeTo(180 + (fromLeft ? 13 : -13), 1e-8));
      expect(s.y, closeTo(114.4, 1e-8));
      expect(s.radiusAt(0), greaterThan(s.radiusAt(BoardSnake.samples - 1)));
      final headShift = s.points.first.x - before.first.x;
      final middleShift = s.points[14].x - before[14].x;
      expect((headShift - middleShift).abs(), greaterThan(.1));
      expect(s.points.last.y, lessThan(s.points.first.y));
    }
  });

  test(
    'head, body and tail detect contact and fast crossings; gaps remain safe',
    () {
      final s = BoardSnake(x: 180, y: 300);
      for (final i in [0, 14, 28]) {
        final p = s.points[i];
        expect(s.contact(p.x, p.y, p.x, p.y), isNotNull);
        expect(s.contact(p.x - 160, p.y, p.x + 160, p.y), isNotNull);
      }
      expect(s.contact(330, 100, 330, 150), isNull);
    },
  );

  test('only hard encounters spawn a snake above the visible board', () {
    for (final metres in [0.0, 1000.0, 1200.0, 1300.0]) {
      final g = run(metres: metres);
      g.step(1 / 120);
      expect(g.snakes, isEmpty);
    }
    for (var seed = 0; seed < 12; seed++) {
      final g = BalanceGame(seed: seed)..start(gameMode: GameMode.infinite);
      g.mazeSectionsEnabled = false;
      g.maxHeight = 14000;
      g.visibleTop = -160;
      g.step(1 / 120);
      expect(g.snakes.length, 1);
      expect(
        g.snakes.single.points.every((p) => g.screenY(p.y) < g.visibleTop),
        isTrue,
      );
      expect(g.specialHazards, isEmpty);
      g.snakes.clear();
      g.step(1 / 120);
      expect(g.snakes, isEmpty); // No backlog or immediate second arrival.
    }
  });

  test('snake scheduling waits for ranged attacks and special hazards', () {
    for (var blocker = 0; blocker < 4; blocker++) {
      final g = run(metres: 1400);
      switch (blocker) {
        case 0:
          g.specialHazards.add(SpecialHazard(HazardKind.laser, x: 280, y: 200));
        case 1:
          g.webShots.add(
            SpiderWebShot(x: 80, y: 200, targetX: 180, targetY: 400),
          );
        case 2:
          g.quills.add(PorcupineQuill(x: 80, y: 200, angle: 0));
        case 3:
          g.porcupines.add(BoardPorcupine(80, 250)..charge = .2);
      }
      g.step(1 / 120);
      expect(g.snakes, isEmpty);
    }
    final g = run(metres: 1400);
    g.snakes.add(BoardSnake(x: 140, y: 180));
    g.spiders.add(BoardSpider(80, 250, 38));
    g.porcupines.add(BoardPorcupine(280, 250));
    g.step(1 / 120);
    expect(g.snakes.length, 1);
    expect(g.webShots, isEmpty);
    expect(g.quills, isEmpty);
    expect(g.porcupines.single.charge, isNull);
    expect(g.specialHazards, isEmpty);
  });

  test(
    'snake contact costs one heart, honors protection and ends the last life',
    () {
      for (final shielded in [false, true]) {
        final g = run();
        final s = BoardSnake(x: g.ballX, y: g.ballY);
        g.snakes.add(s);
        if (shielded) g.survival.shield = 10;
        g.step(1 / 120);
        expect(g.lives, shielded ? 3 : 2);
        g.step(1 / 120);
        expect(g.lives, shielded ? 3 : 2);
        g.survival.shield = g.survival.recovery = 0;
        g.lives = 1;
        g.step(1 / 120);
        expect(g.lives, 0);
        expect(g.phase, isNot(GamePhase.playing));
        expect(g.message, contains('snake'));
      }
    },
  );

  test('snake and shield contacts resolve in travel order', () {
    for (final shieldFirst in [true, false]) {
      final g = run();
      g.snakes.add(BoardSnake(x: 180, y: 350));
      g.survival.items.add(
        InfiniteItem(InfiniteItemKind.shield, 180, shieldFirst ? 400 : 280),
      );
      g.grabPivot(0);
      g.grabPivot(1);
      g.dragPivot(0, -200);
      g.dragPivot(1, -200);
      g.step(1 / 120);
      expect(g.lives, shieldFirst ? 3 : 2);
      expect(g.survival.shield, greaterThan(0));
    }
  });

  test(
    'world movement, scrolled collisions, pause and cleanup stay consistent',
    () {
      final g = run();
      g.cameraOffset = 1000;
      g.left -= 1000;
      g.right -= 1000;
      g.dangerY -= 1000;
      final s = BoardSnake(x: g.ballX, y: g.ballY);
      final oldY = s.y;
      g.snakes.add(s);
      g.setPaused(true);
      g.step(.1);
      expect(s.age, 0);
      g.setPaused(false);
      g.step(1 / 120);
      expect(s.y, closeTo(oldY + InfiniteTuning.snakeDownSpeed / 120, 1e-8));
      expect(g.lives, 2);
      s.step(10);
      g.step(1 / 120);
      expect(g.snakes, isEmpty);
    },
  );

  test('breathing sections, mazes and restart clear snakes', () {
    for (final maze in [false, true]) {
      final g = run();
      g.snakes.add(BoardSnake(x: 100, y: 200));
      g.maxHeight = maze ? 8000 : 1800;
      g.mazeSectionsEnabled = maze;
      g.step(1 / 120);
      expect(g.snakes, isEmpty);
    }
    final g = run();
    g.snakes.add(BoardSnake(x: 100, y: 200));
    g.start(gameMode: GameMode.classic, levelNumber: 31);
    expect(g.snakes, isEmpty);
  });
}
