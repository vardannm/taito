import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/one_finger_controls.dart';
import 'package:balance_arcade/pivot_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Rect> padRect(WidgetTester tester, double bottomPadding) async {
    final game = BalanceGame()
      ..preferredControlMode = ControlMode.oneFinger
      ..start(levelNumber: 1);
    await tester.pumpWidget(
      MaterialApp(
        home: PivotBoard(
          game: game,
          frame: ValueNotifier(0),
          bottomPadding: bottomPadding,
        ),
      ),
    );
    return tester.getRect(find.byKey(const ValueKey('one-finger-pad')));
  }

  testWidgets('one-finger pad grows into the bottom inset with a margin', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final notched = await padRect(tester, 34);
    expect(notched.bottom, 844 - 8);
    expect(notched.height, OneFingerControls.height + 34 - 8);
    // Its top stays where it was: the board above does not move.
    expect(notched.top, 844 - 34 - OneFingerControls.height);

    final flat = await padRect(tester, 0);
    expect(flat.bottom, 844);
    expect(flat.height, OneFingerControls.height);
  });
}
