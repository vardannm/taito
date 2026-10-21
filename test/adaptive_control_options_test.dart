import 'dart:convert';

import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/progress_backup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/mode_navigation.dart';

Future<PlayerProfile> launchControls(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final profile = PlayerProfile()
    ..tutorialSeen = true
    ..sound = false
    ..music = false
    ..haptics = false;
  await tester.pumpWidget(ArcadeApp(profile: profile));
  return profile;
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  for (final (size, compact) in [
    (const Size(540, 720), true), // Duo closed / single screen.
    (const Size(1114, 720), false), // Duo expanded / spanned.
    (const Size(820, 1180), false),
    (const Size(600, 900), false),
    (const Size(599, 900), true),
    (const Size(844, 390), true), // A rotated phone remains compact.
  ]) {
    testWidgets('control choices match logical layout $size', (tester) async {
      final profile = await launchControls(tester, size);
      await openSettings(tester);
      expect(
        find.byKey(const ValueKey('control-oneFinger')),
        compact ? findsOneWidget : findsNothing,
      );
      expect(find.byKey(const ValueKey('control-twoFinger')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('control-haloJoystick')),
        findsOneWidget,
      );
      final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      expect(
        game.controlMode,
        compact ? ControlMode.oneFinger : ControlMode.twoFinger,
      );
      expect(profile.preferredControlMode, ControlMode.oneFinger);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'unfolding updates an open Settings sheet and folding restores the pad choice',
    (tester) async {
      final profile = await launchControls(tester, const Size(540, 720));
      await startWorld(tester);
      await tester.pump(const Duration(milliseconds: 600));
      final dynamic state = tester.state(find.byType(GameScreen));
      state.showSettings();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      game.grabPivot(0);
      game.dragPivot(0, -10);
      final epoch = game.inputEpoch;
      final run = game.runSerial;
      final lives = game.lives;
      tester.view.physicalSize = const Size(1114, 720) * 2;
      await tester.pump();
      expect(find.byKey(const ValueKey('control-oneFinger')), findsNothing);
      expect(game.controlMode, ControlMode.twoFinger);
      expect(game.inputEpoch, greaterThan(epoch));
      expect(game.pivotTargets.every((target) => target == null), isTrue);
      expect(game.runSerial, run);
      expect(game.lives, lives);
      expect(profile.preferredControlMode, ControlMode.oneFinger);
      tester.view.physicalSize = const Size(540, 720) * 2;
      await tester.pump();
      expect(find.byKey(const ValueKey('control-oneFinger')), findsOneWidget);
      expect(game.controlMode, ControlMode.oneFinger);
      expect(game.runSerial, run);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Halo remains selectable on an expanded Duo and survives folding',
    (tester) async {
      final profile = await launchControls(tester, const Size(1114, 720));
      await openSettings(tester);
      final halo = find.byKey(const ValueKey('control-haloJoystick'));
      await tester.ensureVisible(halo);
      await tester.tap(halo);
      await tester.pump();
      final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      expect(profile.controlMode, ControlMode.oneFinger);
      expect(game.haloJoystick, isTrue);
      expect(game.oneFinger, isTrue);
      expect(find.byKey(const ValueKey('control-oneFinger')), findsNothing);
      final epoch = game.inputEpoch;
      tester.view.physicalSize = const Size(540, 720) * 2;
      await tester.pump();
      expect(game.inputEpoch, epoch);
      expect(game.haloJoystick, isTrue);
      expect(game.oneFinger, isTrue);
      expect(find.byKey(const ValueKey('control-oneFinger')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('large level picker offers Halo instead of the original pad', (
    tester,
  ) async {
    final profile = await launchControls(tester, const Size(1114, 720));
    await openClassicLevels(tester);
    expect(find.text('One-finger'), findsNothing);
    expect(find.text('Halo Joystick'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('level-control-oneFinger')));
    await tester.pump();
    expect(profile.haloJoystick, isTrue);
    await tester.tap(find.byKey(const ValueKey('level-1')));
    await tester.pump();
    final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    expect(game.mode, GameMode.classic);
    expect(game.oneFinger, isTrue);
    expect(game.haloJoystick, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'large tutorial replay keeps the compact preference for folding',
    (tester) async {
      final profile = await launchControls(tester, const Size(1114, 720));
      final dynamic state = tester.state(find.byType(GameScreen));
      state.replayTutorial();
      await tester.pump();
      final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      expect(game.controlMode, ControlMode.twoFinger);
      state.skipTutorial();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      expect(profile.preferredControlMode, ControlMode.oneFinger);
      tester.view.physicalSize = const Size(540, 720) * 2;
      await tester.pump();
      expect(game.controlMode, ControlMode.oneFinger);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'wide fallback does not overwrite the saved or exported compact preference',
    () async {
      final profile = PlayerProfile()..controlMode = ControlMode.oneFinger;
      profile.applyControlLayout(shortestSide: 720);
      expect(profile.controlMode, ControlMode.twoFinger);
      await profile.save();
      final encoded = ProgressBackup.encode(profile);
      expect(jsonDecode(encoded)['control'], 'oneFinger');
      final restored = PlayerProfile();
      restored.applyControlLayout(shortestSide: 720);
      await ProgressBackup.restore(
        restored,
        ProgressBackup.decode(encoded, testEconomy: false),
      );
      expect(restored.controlMode, ControlMode.twoFinger);
      restored.applyControlLayout(shortestSide: 540);
      expect(restored.controlMode, ControlMode.oneFinger);
      final reloaded = PlayerProfile();
      await reloaded.load();
      expect(reloaded.preferredControlMode, ControlMode.oneFinger);
      reloaded.applyControlLayout(shortestSide: 720);
      expect(reloaded.controlMode, ControlMode.twoFinger);
      reloaded.haloJoystick = true;
      expect(reloaded.controlMode, ControlMode.oneFinger);
      reloaded.haloJoystick = false;
      reloaded.controlMode = ControlMode.twoFinger;
      reloaded.applyControlLayout(shortestSide: 540);
      expect(reloaded.controlMode, ControlMode.twoFinger);
    },
  );
}
