import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/analog_controls.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/one_finger_controls.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/tutorial.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Finder controller(ControlMode mode) => switch (mode) {
  ControlMode.oneFinger => find.byType(OneFingerControls),
  ControlMode.analog => find.byKey(const ValueKey('analog-left')),
  ControlMode.twoFinger => find.byType(PivotBoard),
};

Offset contact(WidgetTester tester, BalanceGame game) {
  if (!game.oneFinger && !game.analog) {
    final board = find.byType(PivotBoard);
    return tester.getTopLeft(board) +
        BoardViewport.forGame(
          tester.getSize(board),
          game,
          fillWidth: tester.widget<PivotBoard>(board).fillWidth,
        ).project(Offset(20, game.screenY(game.left)));
  }
  return tester.getCenter(controller(game.controlMode));
}

Future<BalanceGame> launch(
  WidgetTester tester,
  ControlMode mode, {
  Size size = const Size(320, 568),
  bool tutorialSeen = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ArcadeApp(
      profile: PlayerProfile()
        ..tutorialSeen = tutorialSeen
        ..sound = false
        ..haptics = false
        ..controlMode = mode,
    ),
  );
  await tester.pump();
  return tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
}

void expectOwned(BalanceGame game) {
  if (game.oneFinger) {
    expect(game.controlHeld, isTrue);
  } else {
    expect(game.pivotTargets[0], isNotNull);
  }
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  for (final mode in ControlMode.values) {
    testWidgets('$mode opens frozen and uses the starting gesture for movement', (
      tester,
    ) async {
      final game = await launch(tester, mode, tutorialSeen: false);
      expect(find.byType(FirstPlayTutorial), findsNothing);
      expect(game.infinite, isTrue);
      expect(game.waitingForInput, isTrue);
      final left = game.left, camera = game.cameraOffset;
      final holes = game.board.toList(), run = game.runSerial;
      final epoch = game.inputEpoch;
      await tester.pump(const Duration(seconds: 5));
      expect(game.elapsed, 0);
      expect(game.score, 0);
      expect(game.left, left);
      expect(game.cameraOffset, camera);
      expect(game.board, holes);
      // Non-control touches cannot start the run.
      await tester.tapAt(tester.getCenter(find.byType(PivotBoard)));
      expect(game.waitingForInput, isTrue);

      final boardState = tester.state(find.byType(PivotBoard));
      final controlState = tester.state(controller(mode));
      final rect = tester.getRect(controller(mode));
      final finger = await tester.startGesture(
        contact(tester, game),
        pointer: 7,
      );
      expect(game.waitingForInput, isFalse);
      expectOwned(game);
      // Exercise movement before the first frame and after the start UI rebuild.
      await finger.moveBy(const Offset(6, -4));
      if (game.oneFinger)
        expect(game.controlPosition, greaterThan(0));
      else
        expect(game.pivotTargets[0], lessThan(left));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.left, lessThan(left));
      expect(game.runSerial, run);
      expect(game.inputEpoch, epoch);
      expect(tester.state(find.byType(PivotBoard)), same(boardState));
      expect(tester.state(controller(mode)), same(controlState));
      expect(
        tester.getRect(controller(mode)).width,
        greaterThanOrEqualTo(rect.width - .001),
      );
      final moved = game.left;
      await finger.moveBy(const Offset(0, -4));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.left, lessThan(moved));
      expectOwned(game);
      await finger.up();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      testWidgets('$mode keeps held input through shield changes at $size', (
        tester,
      ) async {
        final game = await launch(tester, mode, size: size);
        final finger = await tester.startGesture(
          contact(tester, game),
          pointer: 23,
        );
        await finger.moveBy(const Offset(4, -2));
        await tester.pump(const Duration(milliseconds: 16));
        final state = tester.state(controller(mode));
        final rect = tester.getRect(controller(mode));
        final epoch = game.inputEpoch;
        final run = game.runSerial;
        final tilt = game.controlPosition;

        Future<void> pickup() async {
          game.survival.items.add(
            InfiniteItem(InfiniteItemKind.shield, game.ballX, game.ballY),
          );
          game.step(1 / 120);
          await tester.pump(const Duration(milliseconds: 16));
          expect(game.survival.shield, greaterThan(9));
          expect(find.textContaining('SHIELD '), findsWidgets);
        }

        await pickup();
        game.survival.shield = 2;
        await pickup(); // Refresh an active shield without re-grabbing.
        expect(game.controlPosition, tilt);
        expectOwned(game);
        final before = game.left;
        // Pending movement must survive the exact tick when the shield expires.
        await finger.moveBy(const Offset(0, -3));
        game.survival.shield = .01;
        await tester.pump(const Duration(milliseconds: 32));
        expect(game.survival.protected, isFalse);
        expect(game.lives, 3);
        expect(game.left, lessThan(before));
        expect(game.inputEpoch, epoch);
        expect(game.runSerial, run);
        expect(tester.state(controller(mode)), same(state));
        expect(
          tester.getRect(controller(mode)).width,
          greaterThanOrEqualTo(rect.width - .001),
        );
        expectOwned(game);

        final after = game.left;
        await finger.moveBy(const Offset(0, -3));
        await tester.pump(const Duration(milliseconds: 16));
        expect(game.left, lessThan(after));
        if (game.analog) expect(game.analogInputs[0], lessThan(0));
        await finger.up();
        expect(game.controlHeld, isFalse);
        if (!game.oneFinger) expect(game.pivotTargets[0], isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('keyboard starts on key down and applies that same held key', (
    tester,
  ) async {
    final game = await launch(tester, ControlMode.oneFinger);
    final left = game.left, run = game.runSerial, epoch = game.inputEpoch;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    expect(game.waitingForInput, isFalse);
    expect(game.leftInput, -1);
    await tester.pump(const Duration(milliseconds: 32));
    expect(game.left, lessThan(left));
    expect(game.runSerial, run);
    expect(game.inputEpoch, epoch);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    expect(game.leftInput, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'settings apply to the ready board and modal keys do not start it',
    (tester) async {
      final game = await launch(tester, ControlMode.twoFinger);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      expect(game.waitingForInput, isTrue);
      await tester.ensureVisible(find.byKey(const ValueKey('control-analog')));
      await tester.tap(find.byKey(const ValueKey('control-analog')));
      await tester.pump();
      Navigator.of(tester.element(find.text('Make yourself at home.'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(game.analog, isTrue);
      expect(find.byType(AnalogControls), findsOneWidget);
      expect(game.waitingForInput, isTrue);
      expect(game.elapsed, 0);
      final finger = await tester.startGesture(contact(tester, game));
      await finger.moveBy(const Offset(0, -3));
      expect(game.waitingForInput, isFalse);
      expect(game.analogInputs[0], lessThan(0));
      await finger.up();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'home returns to a frozen Infinite board and lifecycle stays ready',
    (tester) async {
      final game = await launch(tester, ControlMode.oneFinger);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(game.waitingForInput, isTrue);
      expect(game.paused, isFalse);
      final finger = await tester.startGesture(contact(tester, game));
      await tester.pump();
      await finger.up();
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(game.paused, isTrue);
      await tester.tap(find.text('BACK TO CLUB'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(game.infinite, isTrue);
      expect(game.waitingForInput, isTrue);
      expect(game.paused, isFalse);
      expect(game.elapsed, 0);
      expect(game.controlHeld, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final mode in [ControlMode.analog, ControlMode.twoFinger]) {
    testWidgets(
      '$mode preserves both fingers through expiry and cancels on pause',
      (tester) async {
        final game = await launch(tester, mode);
        final left = await tester.startGesture(
          contact(tester, game),
          pointer: 31,
        );
        await tester.pump();
        final board = find.byType(PivotBoard);
        final rightPoint = game.analog
            ? tester.getCenter(find.byKey(const ValueKey('analog-right')))
            : tester.getTopLeft(board) +
                  BoardViewport(
                    tester.getSize(board),
                  ).project(Offset(340, game.screenY(game.right)));
        final right = await tester.startGesture(rightPoint, pointer: 32);
        await left.moveBy(const Offset(0, -2));
        await right.moveBy(const Offset(0, -3));
        game.survival.items.add(
          InfiniteItem(InfiniteItemKind.shield, game.ballX, game.ballY),
        );
        await tester.pump(const Duration(milliseconds: 16));
        expect(game.survival.protected, isTrue);
        game.survival.shield = .01;
        await tester.pump(const Duration(milliseconds: 32));
        final l = game.left, r = game.right;
        await left.moveBy(const Offset(0, -4));
        await right.moveBy(const Offset(0, -5));
        await tester.pump(const Duration(milliseconds: 16));
        expect(game.left, lessThan(l));
        expect(game.right, lessThan(r));
        expect(game.pivotTargets.every((target) => target != null), isTrue);
        await tester.tap(find.byTooltip('Pause'));
        await tester.pump();
        expect(game.pivotTargets, [null, null]);
        await tester.tap(find.text('RESUME RUN'));
        await tester.pump();
        final next = await tester.startGesture(
          contact(tester, game),
          pointer: 33,
        );
        await left.up();
        await right.cancel();
        // Stale releases from the old epoch must not release a new controller.
        expect(game.pivotTargets[0], isNotNull);
        await next.moveBy(const Offset(0, -3));
        expect(game.pivotTargets[0], lessThan(game.left));
        await next.up();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('ready screen fits large text with controls still reachable', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final game = await launch(tester, ControlMode.oneFinger);
    expect(tester.takeException(), isNull);
    final pad = find.byType(OneFingerControls);
    expect(tester.getRect(pad).bottom, lessThanOrEqualTo(568));
    final finger = await tester.startGesture(contact(tester, game));
    await finger.moveBy(const Offset(3, -3));
    await tester.pump();
    expect(game.waitingForInput, isFalse);
    expect(game.controlHeld, isTrue);
    expect(tester.takeException(), isNull);
    await finger.up();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Infinite retry prepares a fresh run that waits for control input',
    (tester) async {
      final game = await launch(tester, ControlMode.oneFinger);
      var finger = await tester.startGesture(contact(tester, game));
      await finger.up();
      game.phase = GamePhase.over;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(find.text('ONE MORE RUN'));
      await tester.pump();
      final run = game.runSerial;
      expect(game.waitingForInput, isTrue);
      expect(game.finished, isFalse);
      expect(game.elapsed, 0);
      expect(game.lives, 3);
      expect(game.controlHeld, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(game.elapsed, 0);
      finger = await tester.startGesture(contact(tester, game));
      await finger.moveBy(const Offset(3, -3));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.waitingForInput, isFalse);
      expect(game.controlHeld, isTrue);
      expect(game.controlPosition, greaterThan(0));
      expect(game.runSerial, run);
      await finger.up();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
