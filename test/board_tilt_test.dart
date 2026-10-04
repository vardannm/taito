import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_tilt_controls.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/pivot_board.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:balance_arcade/progress_backup.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'start_flow_test.dart' show launch;

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  testWidgets(
    'board tilt is hidden until touch, ignores lift, and can be re-grabbed anywhere',
    (tester) async {
      final game = BalanceGame()
        ..setControlMode(ControlMode.boardTilt)
        ..start(gameMode: GameMode.practice)
        ..left = 350
        ..right = 350
        ..board.clear();
      final frame = ValueNotifier(0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 480,
                child: PivotBoard(game: game, frame: frame),
              ),
            ),
          ),
        ),
      );
      final board = find.byType(BoardTiltControls);
      expect(find.byKey(const ValueKey('board-tilt-cue')), findsNothing);
      expect(find.byKey(const ValueKey('tilt-lift-tilt')), findsNothing);
      final origin = tester.getCenter(board);
      final finger = await tester.startGesture(origin, pointer: 1);
      await tester.pump();
      expect(find.byKey(const ValueKey('board-tilt-cue')), findsOneWidget);
      await finger.moveBy(const Offset(0, -80));
      game.step(1 / 120);
      expect(game.left, 350);
      expect(game.right, 350);
      game.grabTiltLiftAxis(tilt: false);
      game.setTiltLiftInput(tilt: false, value: -1);
      expect(game.liftHeld, isFalse);
      expect(game.liftInput, 0);
      await finger.moveBy(const Offset(20, 0));
      game.step(1 / 120);
      expect(game.right - game.left, greaterThan(0));
      expect((game.left + game.right) / 2, closeTo(350, 1e-8));
      final angle = game.right - game.left;
      final extra = await tester.startGesture(
        origin + const Offset(70, 50),
        pointer: 2,
      );
      await extra.moveBy(const Offset(-40, -40));
      await extra.up();
      game.step(1 / 120);
      expect(game.right - game.left, closeTo(angle, 1e-8));
      await finger.up();
      await tester.pump();
      expect(find.byKey(const ValueKey('board-tilt-cue')), findsNothing);
      final next = await tester.startGesture(
        origin + const Offset(-90, 65),
        pointer: 3,
      );
      game.step(1 / 120);
      expect(game.right - game.left, closeTo(angle, 1e-8));
      await next.moveBy(const Offset(-10, 0));
      game.step(1 / 120);
      expect(game.right - game.left, lessThan(angle));
      game.setPaused(true);
      game.setPaused(false);
      final pausedAngle = game.right - game.left;
      await next.moveBy(const Offset(60, 60));
      game.step(1 / 120);
      await tester.pump();
      expect(game.right - game.left, closeTo(pausedAngle, 1e-8));
      expect(find.byKey(const ValueKey('board-tilt-cue')), findsNothing);
      await next.cancel();
      final held = await tester.startGesture(origin, pointer: 4);
      await tester.pumpWidget(const SizedBox());
      expect(game.controlHeld, isFalse);
      await held.up();
      frame.dispose();
    },
  );

  testWidgets(
    'fifth option starts on the board and persists its selection and records',
    (tester) async {
      final game = await launch(tester, ControlMode.oneFinger);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final option = find.byKey(const ValueKey('control-boardTilt'));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pump();
      expect(game.controlMode, ControlMode.boardTilt);
      expect(find.byType(BoardTiltControls), findsOneWidget);
      expect(find.byKey(const ValueKey('tilt-lift-tilt')), findsNothing);
      expect(find.byKey(const ValueKey('board-tilt-cue')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      final profile = PlayerProfile()..controlMode = ControlMode.boardTilt;
      profile.levelRecords['boardTilt:1'] = const LevelRecord(starMask: 3);
      await profile.save();
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.controlMode, ControlMode.boardTilt);
      expect(restored.levelRecord(1).starMask, 3);
      final backup = ProgressBackup.decode(
        ProgressBackup.encode(restored),
        testEconomy: false,
      );
      expect(backup.controlMode, ControlMode.boardTilt);
      expect(backup.levelRecord(1).starMask, 3);
    },
  );
}
