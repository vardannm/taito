import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:balance_arcade/porcupines.dart';
import 'package:balance_arcade/spiders.dart';

BalanceGame run() {
  final g = BalanceGame(seed: 12)..start(gameMode: GameMode.infinite);
  g.mazeSectionsEnabled = false;
  g.board.clear();
  g.survival.items.clear();
  return g;
}

void advance(BalanceGame g, double seconds) {
  for (var i = 0; i < (seconds * 120).ceil(); i++) {
    g.stallTime = 0;
    g.step(1 / 120);
  }
}

void main() {
  test('burst covers 360 degrees equally and alternates its gaps', () {
    final p = BoardPorcupine(180, 240);
    final shots = p.burst();
    expect(shots.length, InfiniteTuning.quillCount);
    for (var i = 0; i < shots.length; i++) {
      final q = shots[i];
      expect(q.angle, closeTo(i * math.pi / 6, 1e-9));
      q.step(1);
      expect(q.x, closeTo(180 + math.cos(q.angle) * 115, 1e-9));
      expect(q.y, closeTo(240 + math.sin(q.angle) * 115, 1e-9));
    }
    expect(p.burst().first.angle, closeTo(math.pi / 12, 1e-9));
  });

  test('quills sweep fast crossings and clip collisions at expiry', () {
    final q = PorcupineQuill(x: 100, y: 200, angle: 0);
    q.step(.1);
    expect(q.contact(105, 140, 105, 260), isNotNull);
    expect(q.contact(105, 240, 105, 300), isNull);
    q.step(4);
    expect(q.expired, isTrue);
    expect(q.contact(400, 200, 400, 200), isNotNull);
    q.step(.01);
    expect(q.contact(q.x, q.y, q.x, q.y), isNull);
  });

  test('visible porcupine warns, pauses, fires once and cools down', () {
    final g = run();
    final p = BoardPorcupine(85, 260);
    g.porcupines.add(p);
    g.step(1 / 120);
    expect(p.charge, 0);
    expect(g.quills, isEmpty);
    g.setPaused(true);
    advance(g, 1);
    expect(p.charge, 0);
    g.setPaused(false);
    advance(g, 1);
    expect(g.quills, isEmpty);
    advance(g, .12);
    expect(p.bursts, 1);
    expect(g.quills.length, InfiniteTuning.quillCount);
    advance(g, 1);
    expect(p.bursts, 1);
    expect(p.charge, isNull);
  });

  test('bursts do not overlap web shots or special hazards', () {
    final g = run();
    final p = BoardPorcupine(85, 260);
    g.porcupines.add(p);
    g.specialHazards.add(SpecialHazard(HazardKind.laser, x: 280, y: 200));
    advance(g, .2);
    expect(p.charge, isNull);
    g.specialHazards.clear();
    g.spiders.add(BoardSpider(290, 280, 38));
    advance(g, .2);
    expect(p.charge, isNotNull);
    expect(g.webShots, isEmpty);
    advance(g, 1.2);
    expect(g.quills, isNotEmpty);
    expect(g.webShots, isEmpty);
  });

  test('breathing, maze and restarting clear attacks', () {
    for (final maze in [false, true]) {
      final g = run();
      final p = BoardPorcupine(85, 260)..charge = .5;
      g.porcupines.add(p);
      g.quills.add(PorcupineQuill(x: 100, y: 200, angle: 0));
      if (maze) {
        g.mazeSectionsEnabled = true;
        g.maxHeight = 8000;
      } else {
        g.maxHeight = 1800;
      }
      g.step(1 / 120);
      expect(g.quills, isEmpty);
      expect(p.charge, isNull);
      g.start(gameMode: GameMode.classic, levelNumber: 31);
      expect(g.porcupines, isEmpty);
      expect(g.quills, isEmpty);
    }
  });

  test(
    'quills and bodies respect hearts, recovery, shields and final life',
    () {
      for (final body in [false, true]) {
        for (final shield in [false, true]) {
          final g = run();
          if (shield) g.survival.shield = 10;
          if (body) {
            g.porcupines.add(BoardPorcupine(g.ballX, g.ballY));
          } else {
            g.quills.add(PorcupineQuill(x: g.ballX, y: g.ballY, angle: 0));
          }
          g.step(1 / 120);
          expect(g.lives, shield ? 3 : 2);
          expect(g.quills, isEmpty);
          g.step(1 / 120);
          expect(g.lives, shield ? 3 : 2);
          g.survival.recovery = g.survival.shield = 0;
          g.lives = 1;
          g.quills.add(PorcupineQuill(x: g.ballX, y: g.ballY, angle: 0));
          g.step(1 / 120);
          expect(g.lives, 0);
          expect(g.phase, isNot(GamePhase.playing));
          expect(g.message, contains('porcupine'));
        }
      }
    },
  );

  for (final shieldFirst in [true, false]) {
    test('shield and quill swept contacts resolve in order ($shieldFirst)', () {
      final g = run();
      g.quills.add(PorcupineQuill(x: 180, y: 350, angle: 0));
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
      expect(g.quills, isEmpty);
    });
  }

  test(
    'porcupines enter above the board, avoid holes, stay bounded and prune',
    () {
      for (var seed = 0; seed < 20; seed++) {
        final g = BalanceGame(seed: seed)..start(gameMode: GameMode.infinite);
        expect(g.porcupines, isEmpty);
        final seen = <BoardPorcupine>{};
        for (var offset = 100.0; offset < 45000; offset += 100) {
          g.cameraOffset = g.maxHeight = offset;
          g.ensureInfiniteBoard();
          expect(
            g.porcupines.length,
            lessThanOrEqualTo(InfiniteTuning.maxPorcupines),
          );
          for (final p in g.porcupines) {
            if (seen.add(p)) expect(g.screenY(p.y) + 30, lessThan(0));
            expect(g.screenY(p.y), lessThanOrEqualTo(640));
            for (final h in g.board) {
              expect(
                math.sqrt(math.pow(p.x - h.x, 2) + math.pow(p.y - h.y, 2)),
                greaterThanOrEqualTo(44),
              );
            }
          }
        }
        expect(seen.length, greaterThan(3));
      }
    },
  );
}
