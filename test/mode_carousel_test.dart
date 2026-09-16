import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/mode_carousel.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'start_flow_test.dart' show launch, contact, controller, expectOwned;
import 'support/mode_navigation.dart';

ModeCarouselState carousel(WidgetTester tester) =>
    tester.state(find.byType(ModeCarousel));

Future<void> swipe(
  WidgetTester tester, {
  bool forward = true,
  Offset? from,
}) async {
  final board = find.byType(PivotBoard);
  await tester.dragFrom(
    from ?? tester.getCenter(board),
    Offset(forward ? -230 : 230, 0),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  testWidgets('five worlds swipe in order, snap, and never simulate previews', (
    tester,
  ) async {
    final game = await launch(tester, ControlMode.twoFinger);
    expect(
      tester
          .widget<PageView>(find.byType(PageView))
          .childrenDelegate
          .estimatedChildCount,
      5,
    );
    for (var index = 0; index < 5; index++) {
      if (index > 0) await swipe(tester);
      expect(carousel(tester).page, closeTo(index.toDouble(), .001));
      expect(game.mode, arcadeModes[index]);
      expect(game.waitingForInput, isTrue);
      expect(game.elapsed, 0);
      expect(game.score, 0);
      expect(game.level, 1);
      expect(tester.getCenter(find.byType(PivotBoard)).dx, closeTo(160, .01));
      expect(tester.takeException(), isNull);
    }
    await swipe(tester); // End stays on 2048.
    expect(carousel(tester).page, 4);
    for (var index = 3; index >= 0; index--) {
      await swipe(tester, forward: false);
      expect(game.mode, arcadeModes[index]);
      expect(carousel(tester).page, index);
    }
    await swipe(tester, forward: false);
    expect(carousel(tester).page, 0);
    await tester.pumpWidget(const SizedBox());
  });

  for (final control in ControlMode.values) {
    for (var index = 0; index < 5; index++) {
      testWidgets(
        '$control starts world $index with the same pointer and locks swipes',
        (tester) async {
          final game = await launch(tester, control);
          await selectWorld(tester, index);
          expect(game.mode, arcadeModes[index]);
          final state = tester.state(controller(control));
          final rect = tester.getRect(controller(control));
          final epoch = game.inputEpoch, serial = game.runSerial;
          final left = game.left;
          final finger = await tester.startGesture(
            contact(tester, game),
            pointer: 20,
          );
          await finger.moveBy(const Offset(5, -5));
          expect(game.waitingForInput, isFalse);
          expectOwned(game);
          await tester.pump(const Duration(milliseconds: 16));
          expect(game.left, lessThan(left));
          expect(game.inputEpoch, epoch);
          expect(game.runSerial, serial);
          expect(tester.state(controller(control)), same(state));
          expect(
            tester.getRect(controller(control)).width,
            greaterThanOrEqualTo(rect.width - .001),
          );
          // The original controller and another pointer cannot page while playing.
          await finger.moveBy(const Offset(-160, 0));
          expect(carousel(tester).page, index);
          expectOwned(game);
          // Restore the tilt before advancing physics into a narrow maze wall.
          await finger.moveBy(const Offset(160, 0));
          await swipe(tester, from: const Offset(200, 130));
          expect(carousel(tester).page, index);
          expect(game.mode, arcadeModes[index]);
          expectOwned(game);
          await finger.up();
          await tester.tap(find.byTooltip('Pause'));
          await tester.pump();
          await tester.tap(find.text('BACK TO CLUB'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump();
          expect(game.mode, arcadeModes[index]);
          expect(game.waitingForInput, isTrue);
          await swipe(tester, forward: index < 4);
          expect(carousel(tester).page, index < 4 ? index + 1 : index - 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets('continue worlds show saved levels and start them directly', (
    tester,
  ) async {
    final profile = PlayerProfile()
      ..sound = false
      ..haptics = false
      ..classicLevel = 18
      ..mazeLevel = 12;
    for (var i = 1; i <= 17; i++) {
      profile.levelRecords[profile.recordKey(i, ControlMode.twoFinger)] =
          const LevelRecord(starMask: 7);
    }
    await profile.save();
    final loaded = PlayerProfile();
    await loaded.load();
    await tester.pumpWidget(ArcadeApp(profile: loaded));
    final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    expect(
      game.infinite,
      isTrue,
    ); // Normal application opening always starts here.
    await selectWorld(tester, 1);
    expect(find.text('Classic • Level 18'), findsOneWidget);
    await startWorld(tester);
    expect(game.level, 18);
    expect(game.waitingForInput, isFalse);
    final dynamic screen = tester.state(find.byType(GameScreen));
    screen.home();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await selectWorld(tester, 3);
    expect(find.text('Maze • Level 12'), findsOneWidget);
    await startWorld(tester);
    expect(game.level, 12);
    expect(game.waitingForInput, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'short drags cancel back, header swipes work, and keyboard waits for snap',
    (tester) async {
      final game = await launch(tester, ControlMode.oneFinger);
      final finger = await tester.startGesture(const Offset(210, 112));
      await finger.moveBy(const Offset(-30, 0));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      expect(game.waitingForInput, isTrue);
      await finger.cancel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(carousel(tester).page, 0);
      await swipe(tester, from: const Offset(220, 110));
      expect(game.mode, GameMode.classic);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      expect(game.waitingForInput, isFalse);
      expect(game.leftInput, -1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'stale locked continue selection uses the nearest unlocked level',
    (tester) async {
      await tester.pumpWidget(
        ArcadeApp(profile: PlayerProfile()..classicLevel = 50),
      );
      await selectWorld(tester, 1);
      final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      expect(game.level, 1);
      await startWorld(tester);
      expect(game.level, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final control in ControlMode.values) {
    testWidgets(
      '$control ignores a second contact during a swipe before rebuilding',
      (tester) async {
        final game = await launch(tester, control);
        final swipeFinger = await tester.startGesture(
          const Offset(220, 80),
          pointer: 61,
        );
        await swipeFinger.moveBy(const Offset(-110, 0));
        // Intentionally no pump: hit testing still sees the old control widgets.
        final second = await tester.startGesture(
          contact(tester, game),
          pointer: 62,
        );
        await second.moveBy(const Offset(4, -5));
        expect(game.waitingForInput, isTrue);
        expect(game.controlHeld, isFalse);
        expect(game.pivotTargets, [null, null]);
        await second.up();
        await swipeFinger.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(game.mode, GameMode.classic);
        expect(game.inputLocked, isFalse);
        await startWorld(tester);
        expect(game.waitingForInput, isFalse);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'large text and reduced motion retain accessible mode navigation',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final game = await launch(tester, ControlMode.analog);
      for (var index = 1; index < 5; index++) {
        await tester.tap(find.byTooltip('Next mode'));
        await tester.pump();
        expect(game.mode, arcadeModes[index]);
        expect(carousel(tester).page, index);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
