import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'start_flow_test.dart' show launch, contact, controller, expectOwned;
import 'support/mode_navigation.dart';

dynamic screen(WidgetTester tester) => tester.state(find.byType(GameScreen));

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  testWidgets(
    'inactive worlds are images and partial swipes allocate no game resources',
    (tester) async {
      final game = await launch(tester, ControlMode.twoFinger);
      final dynamic state = screen(tester);
      final serial = game.runSerial;
      final frame = state.frame.value;
      expect(state.ticker.isActive, isFalse);
      expect(game.hasMazeResources, isFalse);
      expect(game.hasMergeResources, isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(state.frame.value, frame);
      final drag = await tester.startGesture(
        tester.getCenter(find.byType(PivotBoard)),
      );
      await drag.moveBy(const Offset(-210, 0));
      await tester.pump();
      expect(game.runSerial, serial);
      expect(game.mode, GameMode.infinite);
      expect(game.elapsed, 0);
      expect(find.byKey(const ValueKey('mode-preview-1')), findsOneWidget);
      expect(
        tester.widget(find.byKey(const ValueKey('mode-preview-1'))),
        isA<Image>(),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is BoardPainter,
        ),
        findsOneWidget,
      );
      await drag.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(game.runSerial, serial);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(game.mode, GameMode.classic);
      expect(game.runSerial, serial + 1);
      expect(state.ticker.isActive, isFalse);
      await selectWorld(tester, 2);
      expect(game.hasMazeResources, isTrue);
      expect(game.hasMergeResources, isFalse);
      await selectWorld(tester, 3);
      expect(game.hasMazeResources, isFalse);
      expect(game.hasMergeResources, isTrue);
      await selectWorld(tester, 0);
      expect(game.hasMazeResources, isFalse);
      expect(game.hasMergeResources, isFalse);
      expect(state.ticker.isActive, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  for (final control in ControlMode.values) {
    testWidgets(
      '$control expands and reverses without replacing held controls',
      (tester) async {
        final game = await launch(tester, control, size: const Size(390, 844));
        final dynamic state = screen(tester);
        final board = find.byType(PivotBoard);
        final preview = tester.getRect(board);
        final boardState = tester.state(board);
        final controlState = tester.state(controller(control));
        final finger = await tester.startGesture(
          contact(tester, game),
          pointer: 72,
        );
        await finger.moveBy(const Offset(3, -3));
        await tester.pump();
        final epoch = game.inputEpoch, serial = game.runSerial;
        final tilt = game.controlPosition;
        await tester.pump(const Duration(milliseconds: 180));
        final middle = tester.getRect(board);
        expect(middle.width, greaterThan(preview.width));
        expect(middle.width, lessThan(390));
        expect(state.chromeOpacity, 1);
        expect(state.expansion, greaterThan(0));
        expect(state.expansion, lessThan(1));
        await tester.pump(const Duration(milliseconds: 260));
        expect(state.expansion, 1);
        expect(state.chromeOpacity, greaterThan(0));
        await tester.pump(const Duration(milliseconds: 160));
        final full = tester.getRect(board);
        expect(full.width, closeTo(390, .01));
        expect(full.height, greaterThan(preview.height));
        expect(full.center.dx, closeTo(195, .01));
        expect(state.chromeOpacity, 0);
        expect(tester.state(board), same(boardState));
        expect(tester.state(controller(control)), same(controlState));
        expect(game.inputEpoch, epoch);
        expect(game.runSerial, serial);
        expect(game.controlPosition, tilt);
        expectOwned(game);
        final left = game.left;
        await finger.moveBy(const Offset(0, -4));
        await tester.pump(const Duration(milliseconds: 16));
        expect(game.left, lessThan(left));
        await finger.up();
        final position = game.left;
        state.home();
        await tester.pump();
        expect(state.ticker.isActive, isFalse);
        await tester.pump(const Duration(milliseconds: 300));
        final shrinking = tester.getRect(board);
        expect(shrinking.width, lessThan(full.width));
        expect(shrinking.width, greaterThan(preview.width));
        expect(game.left, position);
        expect(game.runSerial, serial);
        expect(state.returning, isTrue);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(game.waitingForInput, isTrue);
        expect(game.runSerial, serial + 1);
        expect(tester.getRect(board), preview);
        expect(state.ticker.isActive, isFalse);
        expect(state.returning, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'heart feedback appears at the platform, fades, and never owns input',
    (tester) async {
      final game = await launch(
        tester,
        ControlMode.oneFinger,
        size: const Size(390, 844),
      );
      final dynamic state = screen(tester);
      final finger = await tester.startGesture(
        contact(tester, game),
        pointer: 91,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final epoch = game.inputEpoch;
      final heldState = tester.state(controller(ControlMode.oneFinger));
      game.board
        ..clear()
        ..add(Hole(game.ballX, game.ballY));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.lives, 2);
      expect(state.heartEffects, hasLength(1));
      final board = find.byType(PivotBoard);
      final box = tester.getRect(board);
      final platform =
          box.topLeft +
          BoardViewport.forGame(
            Size(box.width, box.height - 96),
            game,
            fillWidth: 1,
          ).project(
            Offset(game.ballX, game.screenY(game.platformY(game.ballX))),
          );
      expect(
        (state.heartEffects.single.origin as Offset).dx,
        closeTo(platform.dx, 1),
      );
      expect(
        (state.heartEffects.single.origin as Offset).dy,
        closeTo(platform.dy - 20, 1),
      );
      await finger.moveBy(const Offset(8, -5));
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.heartEffects.single.age, closeTo(.3, .02));
      expect(game.inputEpoch, epoch);
      expectOwned(game);
      expect(tester.state(controller(ControlMode.oneFinger)), same(heldState));
      await tester.pump(const Duration(milliseconds: 600));
      expect(state.heartEffects, isEmpty);
      expect(game.lives, 2);
      expectOwned(game);
      await finger.up();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('last-heart feedback cleans up and the finished loop stops', (
    tester,
  ) async {
    final game = await launch(tester, ControlMode.twoFinger);
    final dynamic state = screen(tester);
    await startWorld(tester);
    await tester.pump(const Duration(milliseconds: 600));
    game.lives = 1;
    state.observedLives = 1;
    game.board
      ..clear()
      ..add(Hole(game.ballX, game.ballY));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.lives, 0);
    expect(state.heartEffects, hasLength(1));
    game.phase = GamePhase.over;
    await tester.pump(const Duration(milliseconds: 16));
    expect(state.ticker.isActive, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(state.heartEffects, isEmpty);
    expect(state.ticker.isActive, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
  });
}
