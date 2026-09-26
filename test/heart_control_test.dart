import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/pivot_board.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'start_flow_test.dart' show launch, contact, controller, expectOwned;

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  for (final mode in ControlMode.values) {
    testWidgets(
      '$mode keeps the same held fingers through two lost hearts and protection expiry',
      (tester) async {
        final game = await launch(tester, mode);
        final first = await tester.startGesture(
          contact(tester, game),
          pointer: 61,
        );
        TestGesture? second;
        if (!game.oneFinger) {
          final board = find.byType(PivotBoard);
          final right = game.analog
              ? tester.getCenter(find.byKey(const ValueKey('analog-right')))
              : tester.getTopLeft(board) +
                    BoardViewport(
                      tester.getSize(board),
                    ).project(Offset(340, game.screenY(game.right)));
          second = await tester.startGesture(right, pointer: 62);
        }
        await first.moveBy(const Offset(0, -3));
        await second?.moveBy(const Offset(0, -1));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 600));
        final epoch = game.inputEpoch, run = game.runSerial;
        final state = tester.state(controller(mode));
        final rect = tester.getRect(controller(mode));
        for (final hearts in [2, 1]) {
          final left = game.screenY(game.left),
              right = game.screenY(game.right);
          final x = game.ballX, tilt = game.controlPosition;
          game.board
            ..clear()
            ..add(Hole(game.ballX, game.ballY));
          await tester.pump(const Duration(milliseconds: 16));
          expect(game.lives, hearts);
          expect(game.survival.recovery, greaterThan(2.4));
          expect(game.phase, GamePhase.playing);
          expect(game.inputEpoch, epoch);
          expect(game.runSerial, run);
          expect(game.screenY(game.left), closeTo(left, .001));
          expect(game.screenY(game.right), closeTo(right, .001));
          expect(game.ballX, closeTo(x, .1));
          expect(game.controlPosition, tilt);
          expectOwned(game);
          if (second != null) expect(game.pivotTargets[1], isNotNull);
          expect(tester.state(controller(mode)), same(state));
          expect(tester.getRect(controller(mode)), rect);
          expect(find.textContaining('RECOVERY '), findsOneWidget);

          // No fresh touch: pending movement, expiry, and subsequent dragging all
          // belong to the original pointer(s).
          game.board.clear();
          game.survival.recovery = .01;
          final before = game.left;
          await first.moveBy(const Offset(0, -5));
          await second?.moveBy(const Offset(0, -4));
          await tester.pump(const Duration(milliseconds: 32));
          expect(game.survival.recovery, 0);
          expect(game.left, lessThan(before));
          expect(game.lives, hearts);
          expect(game.inputEpoch, epoch);
          expectOwned(game);
          await first.moveBy(const Offset(0, 2));
          await second?.moveBy(const Offset(0, 2));
          await tester.pump(const Duration(milliseconds: 16));
          expectOwned(game);
        }
        // The last heart still ends the run and releases controls.
        game.board.add(Hole(game.ballX, game.ballY));
        await tester.pump(const Duration(milliseconds: 16));
        expect(game.lives, 0);
        expect(game.phase, GamePhase.sinking);
        expect(game.controlHeld, isFalse);
        expect(game.pivotTargets, [null, null]);
        await first.up();
        await second?.up();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('held keyboard steering survives damage feedback', (
    tester,
  ) async {
    final game = await launch(tester, ControlMode.twoFinger);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await tester.pump(const Duration(milliseconds: 16));
    game.board
      ..clear()
      ..add(Hole(game.ballX, game.ballY));
    final epoch = game.inputEpoch;
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.lives, 2);
    expect(game.inputEpoch, epoch);
    expect(game.leftInput, -1);
    final height = game.screenY(game.left);
    await tester.pump(const Duration(milliseconds: 32));
    expect(game.screenY(game.left), lessThan(height));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    expect(game.leftInput, -1);
    expect(game.rightInput, -1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    expect(game.leftInput, 0);
    expect(game.rightInput, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
