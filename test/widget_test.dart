import 'support/mode_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/board_painter.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(430, 932),
  ]) {
    testWidgets('home, guide and gameplay fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profile = PlayerProfile()
        ..tutorialSeen = true
        ..sound = false
        ..haptics = false;
      await tester.pumpWidget(ArcadeApp(profile: profile));
      expect(find.text('INFINITE / POINTS'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Modes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('HOW TO PLAY'));
      await tester.tap(find.text('HOW TO PLAY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('A game of balance.'), findsOneWidget);
      await tester.ensureVisible(find.text('TRY PRACTICE'));
      await tester.pump();
      await tester.tap(find.text('TRY PRACTICE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('PRACTICE'), findsOneWidget);
      expect(find.byType(PivotBoard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'pivot drags are independent, cancel safely and do not jump on grab',
    (tester) async {
      final game = BalanceGame()..start(gameMode: GameMode.practice);
      final frame = ValueNotifier(0);
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.expand(
            child: PivotBoard(game: game, frame: frame),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(PivotBoard));
      Offset point(double x, double y) =>
          rect.topLeft + BoardViewport(rect.size).project(Offset(x, y));
      final left = await tester.startGesture(point(20, 526), pointer: 1);
      final right = await tester.startGesture(point(340, 526), pointer: 2);
      expect(game.left, 526);
      await left.moveBy(Offset(0, -20 * BoardViewport(rect.size).scale));
      await right.moveBy(Offset(0, -10 * BoardViewport(rect.size).scale));
      for (int i = 0; i < 20; i++) {
        game.step(1 / 120);
      }
      expect(game.left, closeTo(506, .01));
      expect(game.right, closeTo(516, .01));
      await left.up();
      expect(game.pivotTargets[0], isNull);
      expect(game.pivotTargets[1], isNotNull);
      await right.cancel();
      expect(game.pivotTargets, [null, null]);
      game.setPaused(true);
      await tester.tapAt(point(20, 506));
      expect(game.pivotTargets, [null, null]);
      await tester.pumpWidget(const SizedBox());
      frame.dispose();
    },
  );

  testWidgets('gameplay viewport respects tablet safe area', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(
      top: 44,
      bottom: 34,
      left: 12,
      right: 12,
    );
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ArcadeApp(
        profile: PlayerProfile()
          ..tutorialSeen = true
          ..sound = false
          ..haptics = false,
      ),
    );
    await openClassicLevels(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('First steps'));
    await tester.pump();
    final rect = tester.getRect(find.byType(PivotBoard));
    expect(rect.left, greaterThanOrEqualTo(12));
    expect(rect.right, lessThanOrEqualTo(788));
    expect(rect.bottom, lessThanOrEqualTo(1166));
    expect(rect.top, greaterThanOrEqualTo(44));
    expect(rect.height, greaterThan(850));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
