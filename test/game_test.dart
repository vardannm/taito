import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';

void advance(BalanceGame game, double seconds) {
  for (int i = 0; i < (seconds * 120).ceil(); i++) {
    game.step(1 / 120);
  }
}

void placeAt(BalanceGame game, Hole hole) {
  game.left = game.right = hole.y + BalanceGame.ballRadius;
  game.ballX = hole.x;
  game.velocity = 0;
  game.leftSpeed = game.rightSpeed = 0;
  game.step(1 / 120);
}

void main() {
  test('a level bar keeps the ball centered', () {
    final game = BalanceGame()..start();
    advance(game, 2);
    expect(game.ballX, 180);
    expect(game.velocity, 0);
  });
  test('independent motors and inertia behave symmetrically', () {
    final left = BalanceGame()..start();
    left.leftInput = -1;
    final right = BalanceGame()..start();
    right.rightInput = -1;
    advance(left, .4);
    advance(right, .4);
    expect(left.ballX, greaterThan(180));
    expect(right.ballX, lessThan(180));
    expect(left.ballX + right.ballX, closeTo(360, .0001));
    expect(left.left, lessThan(left.right));
    left.clearInput();
    final previous = left.ballX;
    advance(left, .1);
    expect(left.ballX, greaterThan(previous));
  });
  test('target sinks, scores once, returns and rearms controls', () {
    final game = BalanceGame()..start();
    placeAt(game, game.activeHole);
    final score = game.score;
    expect(game.phase, GamePhase.sinking);
    expect(game.target, 2);
    expect(game.completed, 1);
    expect(score, greaterThanOrEqualTo(100));
    advance(game, .5);
    expect(game.score, score);
    advance(game, 1);
    expect(game.canControl, isTrue);
    expect(game.left, 526);
    expect(game.ballX, 180);
    expect(game.leftInput, 0);
  });
  test('three misses end classic, practice has unlimited attempts', () {
    for (final practice in [false, true]) {
      final game = BalanceGame()
        ..start(gameMode: practice ? GameMode.practice : GameMode.classic);
      for (int i = 0; i < 3; i++) {
        placeAt(game, game.board.firstWhere((h) => h.target == 0));
        advance(game, 1.5);
      }
      expect(game.finished, !practice);
      expect(game.lives, practice ? 3 : 0);
      expect(game.misses, 3);
    }
  });
  test('clearing ten targets wins; replay resets the whole run', () {
    final game = BalanceGame()..start();
    for (int i = 1; i <= 10; i++) {
      placeAt(game, game.activeHole);
      advance(game, 1.5);
    }
    expect(game.won, isTrue);
    expect(game.finished, isTrue);
    expect(game.completed, 10);
    expect(game.bestStreak, 10);
    expect(game.multiplier, 4);
    game.start();
    expect(game.score, 0);
    expect(game.target, 1);
    expect(game.won, isFalse);
    expect(game.finished, isFalse);
  });
  test('pause freezes transitions and invalidates held input', () {
    final game = BalanceGame()..start();
    game.leftInput = -1;
    game.setPaused(true);
    advance(game, 2);
    expect(game.left, 526);
    expect(game.leftInput, 0);
    game.setPaused(false);
    placeAt(game, game.activeHole);
    game.setPaused(true);
    advance(game, 2);
    expect(game.phase, GamePhase.sinking);
    game.setPaused(false);
    advance(game, 1.5);
    expect(game.phase, GamePhase.playing);
  });
  test('frame subdivision gives consistent trajectories', () {
    final a = BalanceGame()..start();
    final b = BalanceGame()..start();
    a.leftInput = b.leftInput = -1;
    for (int i = 0; i < 12; i++) {
      a.step(1 / 30);
    }
    for (int i = 0; i < 48; i++) {
      b.step(1 / 120);
    }
    expect(a.ballX, closeTo(b.ballX, .001));
    expect(a.left, closeTo(b.left, .001));
  });
  test('every target has a collision-free geometric route from the launch', () {
    // Reachability, not an assertion that the route is easy for a human.
    for (final target in BalanceGame.holes.where((h) => h.target > 0)) {
      const grid = 4;
      final queue = <(int, int)>[(45, 129)];
      final seen = <(int, int)>{queue.first};
      bool reached = false;
      for (var head = 0; head < queue.length && !reached; head++) {
        final (x, y) = queue[head];
        if (math.pow(x * grid - target.x, 2) +
                math.pow(y * grid - target.y, 2) <
            100) {
          reached = true;
          break;
        }
        for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final next = (x + dx, y + dy);
          if (next.$1 < 8 ||
              next.$1 > 82 ||
              next.$2 < 8 ||
              next.$2 > 129 ||
              seen.contains(next))
            continue;
          final blocked = BalanceGame.holes.any(
            (hole) =>
                hole != target &&
                math.pow(next.$1 * grid - hole.x, 2) +
                        math.pow(next.$2 * grid - hole.y, 2) <
                    15 * 15,
          );
          if (!blocked) {
            seen.add(next);
            queue.add(next);
          }
        }
      }
      expect(
        reached,
        isTrue,
        reason: 'Target ${target.target} must have a route',
      );
    }
  });
}
