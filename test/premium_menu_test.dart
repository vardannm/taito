import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/premium_menu.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'start_flow_test.dart' show launch, contact;
import 'support/mode_navigation.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  for (final control in ControlMode.values) {
    for (var mode = 0; mode < 3; mode++) {
      testWidgets('Play launches prepared world $mode with $control', (
        tester,
      ) async {
        final game = await launch(tester, control);
        await selectWorld(tester, mode);
        final serial = game.runSerial,
            epoch = game.inputEpoch,
            level = game.level;
        final board = tester.state(find.byType(PivotBoard));
        await armWorld(tester);
        expect(game.waitingForInput, isTrue);
        expect(
          find.byKey(const ValueKey('start-control-prompt')),
          findsOneWidget,
        );
        final first = await tester.startGesture(contact(tester, game));
        expect(game.waitingForInput, isFalse);
        await first.up();
        expect(game.paused, isFalse);
        expect(game.runSerial, serial);
        expect(game.inputEpoch, epoch);
        expect(game.level, level);
        expect(game.score, 0);
        // A Play tap is never steering input, including Board Tilt mode.
        expect(game.controlHeld, isFalse);
        expect(game.pivotTargets, [null, null]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(game.elapsed, greaterThan(0));
        expect(tester.state(find.byType(PivotBoard)), same(board));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byKey(const ValueKey('board-shop')), findsNothing);
        expect(find.byTooltip('Pause'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('menu shows saved scores and total earned Classic stars', (
    tester,
  ) async {
    final profile = PlayerProfile()
      ..tutorialSeen = true
      ..music = false
      ..sound = false
      ..haptics = false
      ..infiniteBestScore = 148620
      ..mergeBest = 28640
      ..classicLevel = 3;
    profile.levelRecords[profile.recordKey(3, ControlMode.oneFinger)] =
        const LevelRecord(bestScore: 9600, starMask: 3);
    profile.levelRecords[profile.recordKey(4, ControlMode.twoFinger)] =
        const LevelRecord(starMask: 7);
    await profile.save();
    final loaded = PlayerProfile();
    await loaded.load();
    await tester.pumpWidget(ArcadeApp(profile: loaded));
    String displayedScore() => tester
        .widget<Text>(find.byKey(const ValueKey('menu-best-score')))
        .data!;
    expect(displayedScore(), '148,620');
    await selectWorld(tester, 1);
    expect(find.byKey(const ValueKey('menu-best-score')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('menu-earned-stars'))).data,
      '5',
    );
    expect(find.byKey(const ValueKey('choose-level')), findsOneWidget);
    await selectWorld(tester, 2);
    expect(displayedScore(), '28,640');
    await startWorld(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    await tester.tap(find.text('BACK TO MENU'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(displayedScore(), '28,640');
    expect(find.byKey(const ValueKey('menu-play')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'ambient paint stops for sheets, background, gameplay and reduced motion',
    (tester) async {
      final game = await launch(tester, ControlMode.oneFinger);
      final scene = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is PremiumMenuBackdrop,
      );
      Animation<double> clock() =>
          (tester.widget<CustomPaint>(scene).painter as PremiumMenuBackdrop)
              .drift;
      await tester.pump(const Duration(seconds: 1));
      final moving = clock().value;
      await tester.pump(const Duration(seconds: 1));
      expect(clock().value, isNot(moving));
      expect(game.elapsed, 0);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      final behindSheet = clock().value;
      await tester.pump(const Duration(seconds: 2));
      expect(clock().value, behindSheet);
      Navigator.of(tester.element(find.byTooltip('Close settings'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final background = clock().value;
      await tester.pump(const Duration(seconds: 2));
      expect(clock().value, background);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(clock().value, isNot(background));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      final reduced = clock().value;
      await tester.pump(const Duration(seconds: 2));
      expect(clock().value, reduced);
      final drift = clock();
      await startWorld(tester);
      await tester.pump();
      final playing = drift.value;
      await tester.pump(const Duration(seconds: 1));
      expect(drift.value, playing);
      expect(game.elapsed, greaterThan(0));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
