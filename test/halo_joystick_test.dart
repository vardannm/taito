import 'dart:convert';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/one_finger_controls.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/progress_backup.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'support/mode_navigation.dart' show armWorld;

HaloJoystickPainter haloPainter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byWidgetPredicate(
                (w) => w is CustomPaint && w.painter is HaloJoystickPainter,
              ),
            )
            .painter!
        as HaloJoystickPainter;

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test(
    'Halo preference saves and restores without splitting one-finger records',
    () async {
      final p = PlayerProfile()..haloJoystick = true;
      p.levelRecords[p.recordKey(1, ControlMode.oneFinger)] = const LevelRecord(
        starMask: 7,
      );
      await p.save();
      final loaded = PlayerProfile();
      await loaded.load();
      expect(loaded.haloJoystick, isTrue);
      expect(loaded.controlMode, ControlMode.oneFinger);
      expect(loaded.levelRecord(1).starMask, 7);
      final backup = ProgressBackup.decode(
        ProgressBackup.encode(p),
        testEconomy: false,
      );
      final restored = PlayerProfile();
      await ProgressBackup.restore(restored, backup);
      expect(restored.haloJoystick, isTrue);
      expect(restored.levelRecord(1).starMask, 7);
      final old = jsonDecode(ProgressBackup.encode(p)) as Map<String, dynamic>;
      old.remove('haloJoystick');
      expect(
        ProgressBackup.decode(jsonEncode(old), testEconomy: false).haloJoystick,
        isFalse,
      );
    },
  );

  for (final mode in GameMode.values) {
    testWidgets(
      'floating Halo anchors anywhere and uses relative tilt/lift in $mode',
      (tester) async {
        final game = BalanceGame(seed: 8)
          ..haloJoystick = true
          ..setControlMode(ControlMode.oneFinger)
          ..start(gameMode: mode);
        if (!game.merging) {
          game.board.clear();
          game.coins.clear();
          game.specialHazards.clear();
          game.spiders.clear();
        }
        if (game.infinite) {
          game.tutorialCourse = true;
          game.tutorialAscent = 0;
        }
        if (game.merging) {
          game.mergeRun.orbs.clear();
          game.mergeRun.gates.clear();
        }
        game.left = game.right = 430;
        final frame = ValueNotifier(0);
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 360,
                height: 560,
                child: PivotBoard(game: game, frame: frame),
              ),
            ),
          ),
        );
        final pad = find.byType(OneFingerControls);
        expect(tester.getSize(pad), const Size(360, 560));
        expect(controlStrip(game), 0);
        expect(haloPainter(tester).anchor, isNull);
        expect(HaloJoystickPainter.opacity, lessThan(.5));
        final rect = tester.getRect(pad);
        final start = rect.topLeft + const Offset(95, 250);
        final first = await tester.startGesture(start, pointer: 1);
        await tester.pump();
        expect(haloPainter(tester).anchor, const Offset(95, 250));
        final scale = tester.widget<OneFingerControls>(pad).boardScale;
        await first.moveBy(Offset(0, -24 * scale));
        game.step(1 / 120);
        expect((game.left + game.right) / 2, closeTo(406, .01));
        await first.moveBy(Offset(22 * scale, 0));
        game.step(1 / 120);
        expect(game.controlPosition, closeTo(.2, .001));
        final tilt = game.controlPosition;
        final second = await tester.startGesture(
          rect.topLeft + const Offset(280, 180),
          pointer: 2,
        );
        await second.moveBy(const Offset(-100, -80));
        await tester.pump();
        expect(game.controlPosition, tilt);
        expect(haloPainter(tester).anchor, const Offset(95, 250));
        await second.up();
        await first.up();
        await tester.pump();
        expect(haloPainter(tester).anchor, isNull);
        expect(game.controlHeld, isFalse);
        final next = await tester.startGesture(
          rect.topLeft + const Offset(280, 180),
        );
        await tester.pump();
        expect(haloPainter(tester).anchor, const Offset(280, 180));
        expect(game.controlPosition, tilt);
        await next.cancel();
        await tester.pump();
        expect(haloPainter(tester).anchor, isNull);
        expect(game.controlHeld, isFalse);
        final paused = await tester.startGesture(rect.center);
        await tester.pump();
        game.setPaused(true);
        frame.value++;
        await tester.pump();
        expect(haloPainter(tester).anchor, isNull);
        expect(game.controlHeld, isFalse);
        await paused.up();
        await tester.pumpWidget(const SizedBox());
        frame.dispose();
      },
    );
  }

  testWidgets(
    'third Options choice activates Halo and the original pad remains selectable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final p = PlayerProfile()
        ..tutorialSeen = true
        ..sound = false
        ..music = false
        ..haptics = false;
      await tester.pumpWidget(ArcadeApp(profile: p));
      await tester.pump();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final halo = find.byKey(const ValueKey('control-haloJoystick'));
      await tester.ensureVisible(halo);
      await tester.tap(halo);
      await tester.pump();
      expect(p.haloJoystick, isTrue);
      expect(p.controlMode, ControlMode.oneFinger);
      Navigator.of(tester.element(halo)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      expect(game.haloJoystick, isTrue);
      await armWorld(tester);
      expect(find.byKey(const ValueKey('halo-joystick')), findsOneWidget);
      expect(find.byKey(const ValueKey('one-finger-pad')), findsNothing);
      final control = find.byType(OneFingerControls);
      final start = tester.getCenter(control);
      final finger = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 40));
      expect(game.waitingForInput, isFalse);
      expect(game.mode, GameMode.infinite);
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        (tester.getTopLeft(control) + haloPainter(tester).anchor! - start)
            .distance,
        lessThan(1),
      );
      final tilt = game.controlPosition;
      await finger.moveBy(const Offset(18, -12));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.controlPosition, greaterThan(tilt));
      await finger.up();
      await tester.pump();
      expect(haloPainter(tester).anchor, isNull);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      // Use the same Options route and reset the style without changing records.
      final dynamic state = tester.state(find.byType(GameScreen));
      state.showSettings();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final original = find.byKey(const ValueKey('control-oneFinger'));
      await tester.ensureVisible(original);
      await tester.tap(original);
      await tester.pump();
      expect(p.haloJoystick, isFalse);
      expect(game.haloJoystick, isFalse);
      Navigator.of(tester.element(original)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('one-finger-pad')), findsOneWidget);
      expect(tester.getSize(find.byType(OneFingerControls)).height, 96);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
