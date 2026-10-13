import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:balance_arcade/progress_backup.dart';
import 'package:balance_arcade/tilt_lift_controls.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'game_test.dart' show advance;
import 'start_flow_test.dart' show launch;

BalanceGame splitGame() => BalanceGame(seed: 9)
  ..setControlMode(ControlMode.tiltLift)
  ..start(gameMode: GameMode.practice)
  ..board.clear()
  ..left = 340
  ..right = 340;

void main() {
  testWidgets('legacy tilt-only controls are absent from settings', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final game = await launch(tester, ControlMode.oneFinger);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('control-tiltLift')), findsNothing);
    expect(game.controlMode, ControlMode.oneFinger);
    expect(find.byKey(const ValueKey('tilt-lift-tilt')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'tilt preserves height and lift preserves angle; release stops lift',
    () {
      final game = splitGame();
      game.grabTiltLiftAxis(tilt: true);
      game.setTiltLiftInput(tilt: true, value: .4);
      game.step(1 / 120);
      expect((game.left + game.right) / 2, closeTo(340, .001));
      expect(game.right - game.left, closeTo(56, .001));
      game.grabTiltLiftAxis(tilt: false);
      game.setTiltLiftInput(tilt: false, value: -.5);
      game.releaseTiltLiftAxis(tilt: true);
      advance(game, .2);
      expect(game.controlHeld, isTrue);
      expect((game.left + game.right) / 2, closeTo(326, .001));
      expect(game.right - game.left, closeTo(56, .001));
      game.releaseTiltLiftAxis(tilt: false);
      final left = game.left, right = game.right;
      advance(game, .2);
      expect(game.left, left);
      expect(game.right, right);
      expect(game.controlHeld, isFalse);
      game.grabTiltLiftAxis(tilt: true);
      game.grabTiltLiftAxis(tilt: false);
      game.setTiltLiftInput(tilt: false, value: 1);
      game.releaseTiltLiftAxis(tilt: false);
      expect(game.tiltHeld, isTrue);
      expect(game.controlHeld, isTrue);
      game.setPaused(true);
      game.setPaused(false);
      advance(game, .1);
      expect(game.left, left);
      expect(game.right, right);
      expect(game.controlHeld, isFalse);
    },
  );

  test('rail limits preserve the angle while stopping lift', () {
    final game = splitGame();
    game.grabTiltLiftAxis(tilt: true);
    game.setTiltLiftInput(tilt: true, value: 1);
    game.grabTiltLiftAxis(tilt: false);
    game.setTiltLiftInput(tilt: false, value: -1);
    game.step(1 / 120);
    game.left = game.minPivot;
    game.right = game.minPivot + 140;
    game.step(1 / 120);
    expect(game.left, game.minPivot);
    expect(game.right - game.left, closeTo(140, .001));
    game.setTiltLiftInput(tilt: false, value: 1);
    game.step(1 / 120);
    expect(game.left, greaterThan(game.minPivot));
    expect(game.right - game.left, closeTo(140, .001));
  });

  test('selection and records persist for the new control mode', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final profile = PlayerProfile()..controlMode = ControlMode.tiltLift;
    profile.levelRecords['tiltLift:1'] = const LevelRecord(starMask: 3);
    final backup = ProgressBackup.decode(
      ProgressBackup.encode(profile),
      testEconomy: profile.unlimitedCoins,
    );
    expect(backup.controlMode, ControlMode.tiltLift);
    expect(backup.levelRecord(1).starMask, 3);
    await profile.save();
    final restored = PlayerProfile();
    await restored.load();
    expect(restored.controlMode, ControlMode.oneFinger);
    expect(restored.levelRecord(1, ControlMode.tiltLift).starMask, 3);
  });

  testWidgets(
    'tilt-only ignores vertical motion and extra fingers; pause cancels input',
    (tester) async {
      final game = splitGame(), frame = ValueNotifier(0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 130,
                child: TiltLiftControls(game: game, frame: frame),
              ),
            ),
          ),
        ),
      );
      final tiltPoint = tester.getCenter(
        find.byKey(const ValueKey('tilt-lift-tilt')),
      );
      expect(find.byKey(const ValueKey('tilt-lift-lift')), findsNothing);
      final tilt = await tester.startGesture(tiltPoint, pointer: 1);
      await tilt.moveBy(const Offset(0, -25));
      game.step(1 / 120);
      expect(game.left, 340);
      expect(game.right, 340);
      await tilt.moveBy(const Offset(12, 0));
      game.step(1 / 120);
      expect(game.right - game.left, greaterThan(0));
      expect((game.left + game.right) / 2, closeTo(340, .001));
      final angle = game.controlPosition;
      final extra = await tester.startGesture(tiltPoint, pointer: 3);
      await extra.moveBy(const Offset(-30, 0));
      await extra.up();
      expect(game.controlPosition, closeTo(angle, 1e-10));
      await tilt.up();
      expect(game.controlHeld, isFalse);
      final stale = await tester.startGesture(tiltPoint, pointer: 4);
      game.setPaused(true);
      game.setPaused(false);
      await stale.moveBy(const Offset(20, -10));
      expect(game.controlPosition, closeTo(angle, 1e-10));
      expect(game.liftInput, 0);
      await stale.up();
      await tester.pumpWidget(const SizedBox());
      frame.dispose();
    },
  );
}
