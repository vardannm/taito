import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('floating setting persists without changing the control mode', () async {
    final p = PlayerProfile()..floatingOneFinger = true;
    await p.save();
    final loaded = PlayerProfile();
    await loaded.load();
    expect(loaded.floatingOneFinger, isTrue);
    expect(loaded.controlMode, ControlMode.oneFinger);
  });

  testWidgets(
    'floating control regrabs without a jump, ignores second fingers, and cancels',
    (tester) async {
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
              height: 560,
              child: PivotBoard(
                game: game,
                frame: frame,
                floatingOneFinger: true,
              ),
            ),
          ),
        ),
      );
      final pad = find.byKey(const ValueKey('floating-one-finger'));
      expect(find.byKey(const ValueKey('one-finger-pad')), findsNothing);
      final left = game.left, right = game.right;
      final finger = await tester.startGesture(
        tester.getCenter(pad),
        pointer: 1,
      );
      game.step(1 / 120);
      expect(game.controlHeld, isTrue);
      expect(game.left, left);
      expect(game.right, right);
      await finger.moveBy(const Offset(33, -24));
      game.step(1 / 120);
      expect(game.controlPosition, greaterThan(0));
      expect((game.left + game.right) / 2, lessThan((left + right) / 2));
      final tilt = game.controlPosition;
      final other = await tester.startGesture(
        tester.getTopLeft(pad) + const Offset(45, 70),
        pointer: 2,
      );
      await other.moveBy(const Offset(-30, 25));
      await other.up();
      expect(game.controlPosition, tilt);
      expect(game.controlHeld, isTrue);
      await finger.up();
      expect(game.controlHeld, isFalse);
      final heldLeft = game.left, heldRight = game.right;
      final regrab = await tester.startGesture(
        tester.getBottomRight(pad) - const Offset(5, 5),
      );
      game.step(1 / 120);
      expect(game.controlPosition, tilt);
      expect(game.left, closeTo(heldLeft, .000001));
      expect(game.right, closeTo(heldRight, .000001));
      await regrab.moveBy(const Offset(-20, 0));
      expect(game.controlPosition, lessThan(tilt));
      await regrab.cancel();
      expect(game.controlHeld, isFalse);
      final pausedFinger = await tester.startGesture(tester.getCenter(pad));
      game.setPaused(true);
      frame.value++;
      await tester.pump();
      final pausedTilt = game.controlPosition;
      await pausedFinger.moveBy(const Offset(40, 40));
      expect(game.controlPosition, pausedTilt);
      expect(game.controlHeld, isFalse);
      await pausedFinger.up();
      await tester.pumpWidget(const SizedBox());
      frame.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'board touch starts play instead of swiping modes and pause remains accessible',
    (tester) async {
      final p = PlayerProfile()
        ..tutorialSeen = true
        ..floatingOneFinger = true;
      await tester.pumpWidget(ArcadeApp(profile: p));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final pad = find.byKey(const ValueKey('floating-one-finger'));
      final g = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      final mode = g.mode;
      final finger = await tester.startGesture(tester.getCenter(pad));
      await finger.moveBy(const Offset(45, -20));
      await tester.pump(const Duration(milliseconds: 100));
      expect(g.waitingForInput, isFalse);
      expect(g.mode, mode);
      expect(g.controlHeld, isTrue);
      await finger.up();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('board-pause')));
      await tester.pump();
      expect(g.paused, isTrue);
      expect(g.controlHeld, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
