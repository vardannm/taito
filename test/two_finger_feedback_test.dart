import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/pivot_board.dart';
import 'package:balance_arcade/two_finger_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('two-finger play shows halves, then each finger and its end', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = BalanceGame()
      ..preferredControlMode = ControlMode.twoFinger
      ..start(levelNumber: 1, waitForInput: true);
    await tester.pumpWidget(
      MaterialApp(
        home: PivotBoard(game: game, frame: ValueNotifier(0)),
      ),
    );
    TwoFingerFeedbackPainter painter() => tester
        .widget<CustomPaint>(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is TwoFingerFeedbackPainter,
          ),
        )
        .painter as TwoFingerFeedbackPainter;
    expect(painter().hintOpacity, 1);
    expect(painter().fingers, isEmpty);

    final left = await tester.startGesture(const Offset(80, 600));
    await tester.pump();
    expect(painter().fingers.keys, [0]);
    await left.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(painter().fingers[0], const Offset(80, 560));
    final right = await tester.startGesture(const Offset(310, 500));
    await tester.pump();
    expect(painter().fingers.keys, containsAll([0, 1]));

    for (var i = 0; i < 48; i++) {
      game.step(1 / 60);
    }
    expect(painter().hintOpacity, 0, reason: 'the hint fades once play starts');

    await left.up();
    await right.up();
    await tester.pump();
    expect(painter().fingers, isEmpty);
  });

  testWidgets('one-finger play has no two-finger feedback', (tester) async {
    final game = BalanceGame()
      ..preferredControlMode = ControlMode.oneFinger
      ..start(levelNumber: 1);
    await tester.pumpWidget(
      MaterialApp(
        home: PivotBoard(game: game, frame: ValueNotifier(0)),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is TwoFingerFeedbackPainter,
      ),
      findsNothing,
    );
  });
}
