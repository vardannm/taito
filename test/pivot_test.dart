import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';

void main() {
  test('fast pivot swipes remain swept through traps', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    final trap = game.board.first;
    game.left = game.right = trap.y + 30;
    game.ballX = trap.x;
    game.grabPivot(0);
    game.grabPivot(1);
    game.dragPivot(0, -160);
    game.dragPivot(1, -160);
    for (var i = 0; i < 120; i++) {
      game.step(1 / 120);
    }
    expect(game.finished, isTrue);
    expect(game.pivotTargets, [null, null]);
  });
  test('scrolling does not move held targets and regrabbing has no jump', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    game.left = game.right = -200;
    game.cameraOffset = 500;
    game.grabPivot(0);
    game.dragPivot(0, -20);
    expect(game.pivotTargets[0], -220);
    game.releasePivot(0);
    game.grabPivot(0);
    expect(game.pivotTargets[0], -200);
    game.setPaused(true);
    game.dragPivot(0, -100);
    expect(game.pivotTargets[0], isNull);
  });
}
