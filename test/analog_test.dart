import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/analog_controls.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'game_test.dart' show advance;

BalanceGame analogGame() => BalanceGame()
  ..setControlMode(ControlMode.analog)
  ..start(gameMode: GameMode.practice);
void main() {
  for (final mode in [GameMode.laserMaze]) {
    test(
      'selected analog lifts, reverses and holds in $mode without delay',
      () {
        final game = BalanceGame()
          ..setControlMode(ControlMode.analog)
          ..start(gameMode: mode);
        final start = game.left;
        game.grabPivot(0);
        game.grabPivot(1);
        game.dragPivot(0, -6);
        game.dragPivot(1, -6);
        game.step(1 / 120);
        expect(game.controlMode, ControlMode.analog);
        expect(game.left, closeTo(start - 6, .00001));
        game.dragPivot(0, 3);
        game.dragPivot(1, 3);
        game.step(1 / 120);
        expect(game.left, closeTo(start - 3, .00001));
        game.releasePivot(0);
        game.releasePivot(1);
        game.step(.1);
        expect(game.left, closeTo(start - 3, .00001));
        expect(game.finished, false);
      },
    );
  }

  for (final mode in [ControlMode.twoFinger, ControlMode.analog]) {
    test(
      '$mode follows both fingers in one tick without smoothing or release drift',
      () {
        final game = BalanceGame()
          ..setControlMode(mode)
          ..start(gameMode: GameMode.practice);
        final initial = game.left;
        game.grabPivot(0);
        game.grabPivot(1);
        game.dragPivot(0, -5);
        game.dragPivot(1, -3);
        game.step(1 / 120);
        expect(game.left, closeTo(initial - 5, .00001));
        expect(game.right, closeTo(initial - 3, .00001));
        game.dragPivot(0, 2);
        game.releasePivot(0);
        game.releasePivot(1);
        game.step(1 / 120);
        expect(game.left, closeTo(initial - 3, .00001));
        final held = game.left;
        advance(game, .2);
        expect(game.left, held);
        expect(game.pivotTargets[0], isNull);
        game.grabPivot(0);
        game.dragPivot(0, -100);
        game.setPaused(true);
        game.setPaused(false);
        advance(game, .1);
        expect(game.left, held);
      },
    );
  }
  test(
    'analog setting persists and migrates legacy control preferences',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await SharedPreferencesAsync().setBool('gilt.oneFinger', true);
      final profile = PlayerProfile();
      await profile.load();
      expect(profile.controlMode, ControlMode.oneFinger);
      profile.controlMode = ControlMode.analog;
      await profile.save();
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.controlMode, ControlMode.analog);
    },
  );
  testWidgets(
    'two vertical joysticks ignore horizontal motion and own separate fingers',
    (tester) async {
      final game = analogGame(), frame = ValueNotifier(0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 130,
                child: AnalogControls(game: game, frame: frame),
              ),
            ),
          ),
        ),
      );
      final left = tester.getCenter(find.byKey(const ValueKey('analog-left')));
      final right = tester.getCenter(
        find.byKey(const ValueKey('analog-right')),
      );
      final a = await tester.startGesture(left, pointer: 1);
      await a.moveBy(const Offset(50, 0));
      expect(game.analogInputs, [0, 0]);
      final initial = game.left;
      await a.moveBy(const Offset(0, -1));
      game.step(1 / 120);
      expect(game.left, closeTo(initial - 145 / 34, .00001));
      await a.moveBy(const Offset(0, -40));
      final b = await tester.startGesture(right, pointer: 2);
      await b.moveBy(const Offset(-70, 40));
      expect(game.analogInputs, [-1, 1]);
      final extra = await tester.startGesture(left, pointer: 3);
      await extra.moveBy(const Offset(0, 40));
      await extra.up();
      expect(game.analogInputs, [-1, 1]);
      await a.up();
      expect(game.analogInputs, [0, 1]);
      await b.cancel();
      expect(game.analogInputs, [0, 0]);
      final stale = await tester.startGesture(left, pointer: 4);
      await stale.moveBy(const Offset(0, -40));
      game.clearInput();
      await stale.moveBy(const Offset(0, 20));
      expect(game.analogInputs, [0, 0]);
      await stale.up();
      await tester.pumpWidget(const SizedBox());
      frame.dispose();
    },
  );
}
