import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/one_finger_controls.dart';
import 'package:balance_arcade/pivot_board.dart';

void main() {
  testWidgets(
    'thumb pad is below the board; re-grabbing anywhere preserves the platform',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final game = BalanceGame()
        ..setControlMode(ControlMode.oneFinger)
        ..start(gameMode: GameMode.practice);
      game.board.clear();
      final frame = ValueNotifier(0);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              height: 656,
              child: PivotBoard(game: game, frame: frame),
            ),
          ),
        ),
      );
      final pad = find.byType(OneFingerControls);
      final board = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BoardPainter,
      );
      expect(
        tester.getRect(board).bottom,
        lessThanOrEqualTo(tester.getRect(pad).top),
      );
      expect(tester.getSize(pad).height, 96);
      // Touching the playfield cannot take ownership of the one-finger control.
      await tester.drag(board, const Offset(50, -30));
      game.step(1 / 120);
      expect(game.left, 500);
      expect(game.right, 500);
      var finger = await tester.startGesture(tester.getCenter(pad));
      await finger.moveBy(const Offset(33, -24));
      game.step(1 / 120);
      expect(game.controlPosition, closeTo(.3, .001));
      expect((game.left + game.right) / 2, closeTo(476, .001));
      await finger.up();
      final left = game.left, right = game.right;
      game.step(.1);
      expect(game.left, left);
      expect(game.right, right);
      finger = await tester.startGesture(
        tester.getBottomLeft(pad) + const Offset(45, -20),
      );
      game.step(1 / 120);
      expect(game.left, left);
      expect(game.right, right);
      await finger.moveBy(const Offset(-11, 10));
      game.step(1 / 120);
      expect(game.controlPosition, closeTo(.2, .001));
      expect((game.left + game.right) / 2, closeTo(486, .001));
      await finger.up();
      await tester.pumpWidget(const SizedBox());
      frame.dispose();
    },
  );

  testWidgets(
    'leaving the thumb area stops vertical movement; cancel discards pending movement',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final game = BalanceGame()
        ..setControlMode(ControlMode.oneFinger)
        ..start(gameMode: GameMode.practice);
      game.board.clear();
      final frame = ValueNotifier(0);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              height: 656,
              child: PivotBoard(game: game, frame: frame),
            ),
          ),
        ),
      );
      final pad = find.byType(OneFingerControls);
      final finger = await tester.startGesture(tester.getCenter(pad));
      await finger.moveBy(const Offset(0, -300));
      game.step(1 / 120);
      expect(game.left, 452);
      await finger.moveBy(const Offset(0, -50));
      game.step(1 / 120);
      expect(game.left, 452);
      await finger.up();
      final next = await tester.startGesture(tester.getCenter(pad));
      await next.moveBy(const Offset(0, 15));
      await next.cancel();
      game.step(1 / 120);
      expect(game.left, 452);
      expect(game.controlHeld, false);
      await tester.pumpWidget(const SizedBox());
      frame.dispose();
    },
  );
}
