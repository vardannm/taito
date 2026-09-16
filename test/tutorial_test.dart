import 'package:balance_arcade/one_finger_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/tutorial.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/board_painter.dart';

Future<void> frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> moveControls(
  WidgetTester tester,
  double dy, {
  bool tilt = false,
}) async {
  final finder = find.byType(PivotBoard);
  await tester.ensureVisible(finder);
  await tester.pump();
  final game = tester.widget<PivotBoard>(finder).game;
  final viewport = BoardViewport(tester.getSize(finder));
  final origin = tester.getTopLeft(finder);
  if (game.analog) {
    await tester.ensureVisible(find.byKey(const ValueKey('analog-left')));
    await tester.pump();
    final left = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('analog-left'))),
      pointer: 1,
    );
    final right = tilt
        ? null
        : await tester.startGesture(
            tester.getCenter(find.byKey(const ValueKey('analog-right'))),
            pointer: 2,
          );
    // Analog maps short joystick movement into platform travel.
    await left.moveBy(Offset(0, dy / 8));
    await right?.moveBy(Offset(0, dy / 8));
    await frames(tester, 2);
    await left.up();
    await right?.up();
  } else if (game.oneFinger) {
    final pad = find.byType(OneFingerControls);
    await tester.ensureVisible(pad);
    await tester.pump();
    final scale = tester.widget<OneFingerControls>(pad).boardScale;
    final pointer = await tester.startGesture(tester.getCenter(pad));
    await pointer.moveBy(tilt ? Offset(75 * scale, 0) : Offset(0, dy * scale));
    await frames(tester, 2);
    await pointer.up();
  } else {
    final left = await tester.startGesture(
      origin + viewport.project(Offset(20, game.left)),
      pointer: 1,
    );
    final right = tilt
        ? null
        : await tester.startGesture(
            origin + viewport.project(Offset(340, game.right)),
            pointer: 2,
          );
    await left.moveBy(Offset(0, dy * viewport.scale));
    await right?.moveBy(Offset(0, dy * viewport.scale));
    await frames(tester, 2);
    await left.up();
    await right?.up();
  }
  await frames(tester, 60);
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test('tutorial dismissal persists without recording a run', () async {
    final first = PlayerProfile();
    await first.completeTutorial();
    final second = PlayerProfile();
    await second.load();
    expect(second.tutorialSeen, true);
    expect(second.runs, 0);
  });
  for (final mode in ControlMode.values) {
    testWidgets('all three interactive lessons work with $mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          home: FirstPlayTutorial(control: mode, onDone: () => done = true),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'NEXT'))
            .onPressed,
        isNull,
      );
      await moveControls(tester, -45);
      expect(find.text('You did it. Ready for the next step!'), findsOneWidget);
      await tester.ensureVisible(find.text('NEXT'));
      await tester.pump();
      await tester.tap(find.text('NEXT'));
      await tester.pump();
      await moveControls(tester, -70, tilt: true);
      expect(find.text('You did it. Ready for the next step!'), findsOneWidget);
      await tester.ensureVisible(find.text('NEXT'));
      await tester.pump();
      await tester.tap(find.text('NEXT'));
      await tester.pump();
      await moveControls(tester, -60);
      expect(find.text('You did it. Ready for the next step!'), findsOneWidget);
      await tester.ensureVisible(find.text("LET'S PLAY"));
      await tester.pump();
      await tester.tap(find.text("LET'S PLAY"));
      await tester.pump();
      expect(done, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('small phone tutorial can be skipped and replayed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final profile = PlayerProfile()
      ..sound = false
      ..haptics = false;
    await tester.pumpWidget(ArcadeApp(profile: profile));
    expect(find.byType(FirstPlayTutorial), findsNothing);
    expect(profile.runs, 0);
    await tester.tap(find.byTooltip('Modes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('HOW TO PLAY'));
    await tester.pump();
    await tester.tap(find.text('HOW TO PLAY'));
    await frames(tester, 25);
    await tester.ensureVisible(find.text('REPLAY QUICK TUTORIAL'));
    await tester.pump();
    await tester.tap(find.text('REPLAY QUICK TUTORIAL'));
    await frames(tester, 25);
    expect(find.byType(FirstPlayTutorial), findsOneWidget);
    await tester.tap(find.text('SKIP'));
    await tester.pump();
    expect(profile.tutorialSeen, true);
    expect(
      tester.widget<PivotBoard>(find.byType(PivotBoard)).game.waitingForInput,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
