import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'game_test.dart' show advance;

void main() {
  test(
    'holes approach continuously while platform stays at its screen height',
    () {
      final game = BalanceGame()..start(gameMode: GameMode.infinite);
      final hole = game.board.first;
      final before = game.screenY(hole.y);
      game.grabPivot(0);
      game.grabPivot(1);
      advance(game, 2);
      expect(game.screenY(hole.y) - before, greaterThan(68));
      expect(game.screenY(game.left), closeTo(440, .001));
      expect(game.screenY(game.right), closeTo(440, .001));
      expect(game.screenY(game.pivotTargets[0]!), closeTo(440, .001));
      expect(game.score, greaterThan(5));
      game.dragPivot(0, -20);
      advance(game, .1);
      expect(game.screenY(game.left), closeTo(420, .001));
      expect(game.screenY(game.right), closeTo(440, .001));
    },
  );

  test('an approaching hole catches a ball even without any steering', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    game.lives = 1; // Exercise final-life capture.
    final hole = game.board.first;
    game.left = game.right = hole.y + 30;
    game.ballX = hole.x;
    advance(game, 1.5);
    expect(game.finished, isTrue);
    expect(game.captureX, hole.x);
    expect(game.captureY, hole.y);
  });

  test('pause freezes automatic travel, score and red danger', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    advance(game, 1);
    game.setPaused(true);
    final camera = game.cameraOffset, left = game.left, red = game.dangerY;
    final score = game.score;
    advance(game, 10);
    expect(game.cameraOffset, camera);
    expect(game.left, left);
    expect(game.dangerY, red);
    expect(game.score, score);
  });

  test('ascent accelerates gradually and has a fixed speed cap', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    expect(game.ascentSpeed, 68);
    game.maxHeight = 4500;
    expect(
      game.ascentSpeed,
      closeTo(
        68 +
            10.3359375 * InfiniteDifficulty.speedGrowth +
            6.75 * InfiniteDifficulty.paceGrowth,
        .001,
      ),
    );
    game.maxHeight = 100000;
    expect(
      game.ascentSpeed,
      68 +
          112 * InfiniteDifficulty.speedGrowth +
          36 * InfiniteDifficulty.paceGrowth,
    );
  });
}
