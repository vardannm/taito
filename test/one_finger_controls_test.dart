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
      // Vertical is a stick: held up, it keeps climbing without more movement.
      final lifted = (game.left + game.right) / 2;
      expect(lifted, lessThan(500));
      for (var i = 0; i < 60; i++) {
        game.step(1 / 120);
      }
      expect((game.left + game.right) / 2, lessThan(lifted - 25));
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
      final held = (game.left + game.right) / 2;
      await finger.moveBy(const Offset(-11, 10));
      game.step(1 / 120);
      expect(game.controlPosition, closeTo(.2, .001));
      // Ten pixels below the new grab point is a gentle, controllable descent.
      final eased = (game.left + game.right) / 2;
      expect(eased, greaterThan(held));
      expect(eased, lessThan(held + 1));
      await finger.up();
      await tester.pumpWidget(const SizedBox());
      frame.dispose();
    },
  );

  testWidgets(
    'a held stick climbs outside the thumb area and reverses immediately; cancel stops input',
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
      // Held far above the pad: a full-speed climb that needs no more motion.
      await finger.moveBy(const Offset(0, -300));
      for (var i = 0; i < 120; i++) {
        game.step(1 / 120);
      }
      expect(game.left, closeTo(500 - BalanceGame.liftMotor, .001));
      await finger.moveBy(const Offset(0, -50));
      for (var i = 0; i < 60; i++) {
        game.step(1 / 120);
      }
      expect(game.left, closeTo(500 - BalanceGame.liftMotor * 1.5, .001));
      // Reverse while the finger is still far above the pad.
      final top = game.left;
      await finger.moveBy(const Offset(0, 400));
      for (var i = 0; i < 60; i++) {
        game.step(1 / 120);
      }
      expect(game.left, closeTo(top + BalanceGame.liftMotor / 2, .001));
      await finger.up();
      final released = game.left;
      game.step(.5);
      expect(game.left, released); // Releasing the stick stops the platform.
      final next = await tester.startGesture(tester.getCenter(pad));
      await next.moveBy(const Offset(0, 150));
      for (var i = 0; i < 60; i++) {
        game.step(1 / 120);
      }
      expect(game.left, closeTo(released + BalanceGame.liftMotor / 2, .001));
      final lowered = game.left;
      await next.moveBy(const Offset(0, -15));
      await next.cancel();
      game.step(.25);
      expect(game.left, lowered);
      expect(game.controlHeld, false);
      await tester.pumpWidget(const SizedBox());
      frame.dispose();
    },
  );
  testWidgets(
    'resizing a held thumb pad preserves ownership and a held stick',
    (tester) async {
      final game = BalanceGame()
        ..setControlMode(ControlMode.oneFinger)
        ..start(gameMode: GameMode.practice);
      game.board.clear();
      final frame = ValueNotifier(0);
      Future<void> show(double height) => tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              height: height,
              child: PivotBoard(game: game, frame: frame),
            ),
          ),
        ),
      );
      await show(600);
      final pad = find.byType(OneFingerControls);
      final state = tester.state(pad);
      final finger = await tester.startGesture(
        tester.getCenter(pad),
        pointer: 51,
      );
      await finger.moveBy(const Offset(12, -8));
      game.step(1 / 120);
      final tilt = game.controlPosition;
      final height = (game.left + game.right) / 2;
      final epoch = game.inputEpoch;
      await show(560);
      expect(tester.state(pad), same(state));
      expect(game.controlHeld, isTrue);
      expect(game.inputEpoch, epoch);
      expect(game.controlPosition, tilt);
      final scale = tester.widget<OneFingerControls>(pad).boardScale;
      await finger.moveBy(const Offset(-3, -4));
      game.step(1 / 120);
      expect(game.controlPosition, closeTo(tilt - 3 / (110 * scale), .00001));
      // A resize rebases tilt but never re-centres a stick still held up, so
      // the climb carries on from the height it had reached.
      expect((game.left + game.right) / 2, lessThan(height));
      await finger.up();
      expect(game.controlHeld, isFalse);
      await tester.pumpWidget(const SizedBox());
      frame.dispose();
    },
  );
}
