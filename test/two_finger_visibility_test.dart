import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/pivot_board.dart';

void main() {
  test('thumb targets stay clear of the ball and reachable at phone scales', () {
    final game = BalanceGame()..start(gameMode: GameMode.practice);
    for (final size in [
      const Size(320, 410),
      const Size(390, 760),
      const Size(800, 1040),
    ]) {
      for (final fill in [0.0, .5, 1.0]) {
        for (final height in [30.0, 280.0, 440.0, 526.0]) {
          game.left = game.right = height;
          final viewport = BoardViewport.forGame(size, game, fillWidth: fill);
          for (final side in [0, 1]) {
            final pivot = viewport.project(
              Offset(side == 0 ? 20 : 340, height),
            );
            final grip = viewport.gripCenter(game, side);
            expect(viewport.hitsGrip(grip, game, side), isTrue);
            expect(viewport.hitsGrip(pivot, game, side), isFalse);
            // Even the nearest edge of the touch target leaves room for a thumb.
            expect((grip.dy - pivot.dy).abs() - 24, closeTo(40, .00001));
            expect(grip.dy - 16, greaterThanOrEqualTo(0));
            expect(grip.dy + 16, lessThanOrEqualTo(size.height));
          }
        }
      }
    }
  });

  testWidgets(
    'offset handles own both fingers without grabbing under the ball',
    (tester) async {
      final game = BalanceGame()
        ..start(gameMode: GameMode.infinite, waitForInput: true)
        ..board.clear();
      final frame = ValueNotifier(0);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 390,
              height: 760,
              child: PivotBoard(game: game, frame: frame, fillWidth: 1),
            ),
          ),
        ),
      );
      final board = find.byType(PivotBoard);
      final origin = tester.getTopLeft(board);
      final viewport = BoardViewport.forGame(
        tester.getSize(board),
        game,
        fillWidth: 1,
      );
      await tester.tapAt(
        origin + viewport.project(Offset(20, game.screenY(game.left))),
      );
      expect(game.waitingForInput, isTrue);
      final beforeLeft = game.left, beforeRight = game.right;
      final left = await tester.startGesture(
        origin + viewport.gripCenter(game, 0),
        pointer: 11,
      );
      final right = await tester.startGesture(
        origin + viewport.gripCenter(game, 1),
        pointer: 12,
      );
      expect(game.waitingForInput, isFalse);
      expect(game.left, beforeLeft);
      expect(game.right, beforeRight);
      await left.moveBy(const Offset(0, -20));
      await right.moveBy(const Offset(0, -10));
      game.step(1 / 120);
      expect(game.left, lessThan(beforeLeft));
      expect(game.right, lessThan(beforeRight));
      expect(beforeLeft - game.left, greaterThan(beforeRight - game.right));
      await left.up();
      expect(game.pivotTargets[0], isNull);
      expect(game.pivotTargets[1], isNotNull);
      await right.cancel();
      expect(game.pivotTargets, [null, null]);
      await tester.pumpWidget(const SizedBox());
      frame.dispose();
    },
  );
}
