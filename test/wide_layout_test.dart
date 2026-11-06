import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/menu_design.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/mode_navigation.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  for (final size in [
    const Size(600, 900),
    const Size(1114, 720),
    const Size(932, 678),
    const Size(820, 1180),
    const Size(1440, 900),
    const Size(1920, 1080),
    const Size(1024, 500),
  ]) {
    test(
      'wide route stays visible and round without platform camera pan $size',
      () {
        final game = BalanceGame()..start(gameMode: GameMode.classic);
        for (final fill in [0.0, .5, 1.0]) {
          Offset? offset;
          for (final y in [30.0, 280.0, 440.0, 526.0]) {
            game.left = game.right = y;
            final view = BoardViewport.forGame(size, game, fillWidth: fill);
            expect(view.project(Offset.zero).dy, greaterThanOrEqualTo(-.001));
            expect(
              view.project(const Offset(360, 560)).dy,
              lessThanOrEqualTo(size.height - handleStrip(game) + .001),
            );
            expect(view.rect.left, greaterThanOrEqualTo(0));
            expect(view.rect.right, lessThanOrEqualTo(size.width));
            if (fill == 1) {
              expect(view.project(Offset.zero).dy, greaterThanOrEqualTo(96));
            }
            expect(view.horizontalScale, greaterThanOrEqualTo(view.scale));
            if (fill == 1) {
              final span =
                  view.project(const Offset(340, 0)).dx -
                  view.project(const Offset(20, 0)).dx;
              expect(span, closeTo(size.width * .74, .001));
            }
            offset ??= view.offset;
            expect(view.offset, offset);
            for (final side in [0, 1]) {
              expect(
                view.controlsSide(view.gripCenter(game, side), side),
                isTrue,
              );
            }
          }
        }
      },
    );

    testWidgets('wide menu, three worlds and Settings fit $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final profile = PlayerProfile()
        ..tutorialSeen = true
        ..music = false
        ..sound = false
        ..haptics = false;
      await tester.pumpWidget(ArcadeApp(profile: profile));
      await tester.pump();
      final play = tester.getRect(find.byKey(const ValueKey('menu-play')));
      expect(play.height, greaterThan(64));
      expect(play.bottom, lessThanOrEqualTo(size.height));
      expect(play.left, greaterThanOrEqualTo(0));
      expect(play.right, lessThanOrEqualTo(size.width));
      expect(tester.takeException(), isNull);
      for (var mode = 0; mode < 3; mode++) {
        await selectWorld(tester, mode);
        if (mode == 1 && size.height >= 720) {
          final summary = find.byKey(
            const ValueKey('menu-classic-level-summary'),
          );
          final label = find.descendant(
            of: summary,
            matching: find.text('Level 1'),
          );
          expect(tester.getRect(label).height, greaterThan(28));
          final summaryRect = tester.getRect(summary);
          expect(summaryRect.bottom, lessThanOrEqualTo(size.height));
        }
        await armWorld(tester);
        final board = tester.widget<PivotBoard>(find.byType(PivotBoard));
        final game = board.game;
        final view = BoardViewport.forGame(
          tester.getSize(find.byType(PivotBoard)),
          game,
          fillWidth: board.fillWidth,
          bottomInset: board.bottomInset,
        );
        expect(view.project(Offset.zero).dy, greaterThanOrEqualTo(-.001));
        expect(
          view.project(const Offset(360, 560)).dy,
          lessThanOrEqualTo(view.bounds.bottom + .001),
        );
        expect(game.waitingForInput, isTrue);
        final dynamic state = tester.state(find.byType(GameScreen));
        state.home();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      await startWorld(tester);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      final resume = tester.getRect(find.text('RESUME RUN'));
      expect(resume.left, greaterThanOrEqualTo(0));
      expect(resume.right, lessThanOrEqualTo(size.width));
      expect(resume.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
      final dynamic state = tester.state(find.byType(GameScreen));
      state.home();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final options = tester.element(find.text('Options'));
      expect(MediaQuery.textScalerOf(options).scale(14), greaterThan(14));
      expect(MediaQuery.sizeOf(options), size);
      expect(find.byTooltip('Close settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final rightCutout in [false, true]) {
    testWidgets(
      'side cutout keeps chrome safe without shrinking gameplay: $rightCutout',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(466, 678);
        final insets = FakeViewPadding(
          left: rightCutout ? 0 : 84,
          right: rightCutout ? 84 : 0,
        );
        tester.view.padding = insets;
        tester.view.viewPadding = insets;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ArcadeApp(
            profile: PlayerProfile()
              ..tutorialSeen = true
              ..sound = false
              ..music = false
              ..controlMode = ControlMode.oneFinger,
          ),
        );
        await tester.pump(const Duration(milliseconds: 700));
        final play = tester.getRect(find.byKey(const ValueKey('menu-play')));
        expect(play.center.dx, closeTo(233, .01));
        final endless = tester.getRect(
          find.byKey(const ValueKey('menu-infinite-mark')),
        );
        final title = tester.getRect(
          find.byKey(const ValueKey('selected-mode-title')),
        );
        expect(endless.bottom, lessThan(title.top));
        final settings = tester.getRect(find.byTooltip('Settings'));
        expect(settings.right, lessThanOrEqualTo(rightCutout ? 382 : 466));
        await startWorld(tester);
        final board = tester.getRect(find.byType(PivotBoard));
        expect(board.left, closeTo(0, .01));
        expect(board.width, closeTo(466, .01));
        final pause = tester.getRect(find.byKey(const ValueKey('board-pause')));
        expect(pause.right, lessThanOrEqualTo(rightCutout ? 382 : 466));
        expect(pause.left, greaterThanOrEqualTo(rightCutout ? 0 : 84));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  test('phone projection and menu scale retain existing dimensions', () {
    for (final size in [const Size(390, 844), const Size(540, 720)]) {
      final view = BoardViewport(size, fillWidth: 1);
      expect(view.scale, size.width / 360);
      expect(view.rect.left, 0);
      expect(view.rect.right, size.width);
      expect(wideMenuScale(size), 1);
    }
  });

  testWidgets('resizing a live run keeps its board and run state', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(540, 720);
    addTearDown(tester.view.reset);
    final profile = PlayerProfile()
      ..tutorialSeen = true
      ..controlMode = ControlMode.twoFinger
      ..music = false
      ..sound = false
      ..haptics = false;
    await tester.pumpWidget(ArcadeApp(profile: profile));
    await startWorld(tester);
    await tester.pump(const Duration(milliseconds: 600));
    final boardState = tester.state(find.byType(PivotBoard));
    final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    final serial = game.runSerial, lives = game.lives;
    tester.view.physicalSize = const Size(1114, 720);
    await tester.pump();
    expect(tester.state(find.byType(PivotBoard)), same(boardState));
    expect(game.runSerial, serial);
    expect(game.lives, lives);
    expect(game.started, isTrue);
    expect(game.paused, isFalse);
    tester.view.physicalSize = const Size(540, 720);
    await tester.pump();
    expect(tester.state(find.byType(PivotBoard)), same(boardState));
    expect(game.runSerial, serial);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('two-finger edge touches control a fitted wide board', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1114, 720);
    addTearDown(tester.view.reset);
    final game = BalanceGame()
      ..setControlMode(ControlMode.twoFinger)
      ..start(gameMode: GameMode.practice, waitForInput: true);
    final frame = ValueNotifier(0);
    await tester.pumpWidget(
      MaterialApp(
        home: PivotBoard(game: game, frame: frame, fillWidth: 1),
      ),
    );
    final beforeLeft = game.left, beforeRight = game.right;
    final left = await tester.startGesture(const Offset(24, 360), pointer: 21);
    final right = await tester.startGesture(
      const Offset(1090, 360),
      pointer: 22,
    );
    await left.moveBy(const Offset(0, -40));
    await right.moveBy(const Offset(0, 20));
    game.step(1 / 120);
    expect(game.left, lessThan(beforeLeft));
    expect(game.right, greaterThan(beforeRight));
    await left.up();
    await right.up();
    expect(game.pivotTargets, [null, null]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    frame.dispose();
  });

  for (final size in [const Size(1114, 720), const Size(820, 1180)]) {
    testWidgets('large accessibility text fits wide menu and pause $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final profile = PlayerProfile()
        ..tutorialSeen = true
        ..sound = false
        ..music = false
        ..haptics = false;
      await tester.pumpWidget(ArcadeApp(profile: profile));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('CHOOSE YOUR CONTROLS'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await startWorld(tester);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Your run is right where you left it.'), findsNothing);
      expect(
        tester.getRect(find.byKey(const ValueKey('pause-panel'))).width,
        closeTo(size.width, .01),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('pause-panel'))).height,
        closeTo(size.height, .01),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('menu sizing preserves accessibility scaling without doubling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1114, 720);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: const MenuSurface(child: MenuSurface(child: Text('Readable'))),
      ),
    );
    final media = MediaQuery.of(tester.element(find.text('Readable')));
    expect(media.textScaler.scale(14), closeTo(14 * 1.8 * 1.2, .00001));
    expect(media.size, const Size(1114, 720));
    expect(tester.takeException(), isNull);
  });
}
