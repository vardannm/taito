import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/capture_main.dart';
import 'package:balance_arcade/capture_run.dart';
import 'package:balance_arcade/pivot_board.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'capture_run_test.dart' show makeTake;
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'support/shop_navigation.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('capture menu opens shop and applies chosen look to replay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final profile = PlayerProfile()
      ..sound = false
      ..haptics = false
      ..tutorialSeen = true;
    final take = makeTake(limit: 300);
    await SharedPreferencesAsync().setString(captureSaveKey, take.encode());
    await tester.pumpWidget(CaptureApp(profile: profile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SHOP · CHANGE BALL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(BallShop), findsOneWidget);
    expect(profile.wallet, 300000);
    await revealShopBall(tester, BallCosmetic.coral);
    await tester.tap(find.byKey(const ValueKey('buy-coral')));
    await tester.pump();
    expect(profile.selectedBall, BallCosmetic.coral);
    Navigator.of(tester.element(find.byType(BallShop))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('REPLAY SAVED TAKE'));
    await tester.tap(find.text('REPLAY SAVED TAKE'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    expect(game.renderCosmetic, BallCosmetic.coral);
    expect(game.cosmetic, take.setup.ball);
    for (var i = 0; i < 180; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('Replay complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [
    const Size(320, 568),
    const Size(402, 874),
    const Size(1032, 1376),
    const Size(1114, 720),
  ]) {
    testWidgets('six-heart replay fits $size and ignores gameplay touches', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await SharedPreferencesAsync().setString(
        captureSaveKey,
        makeTake(limit: 300).encode(),
      );
      await tester.pumpWidget(
        CaptureApp(
          profile: PlayerProfile()
            ..sound = false
            ..haptics = false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('REPLAY SAVED TAKE'));
      await tester.tap(find.text('REPLAY SAVED TAKE'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 16));
      final board = find.byType(PivotBoard);
      final game = tester.widget<PivotBoard>(board).game;
      expect(find.byTooltip('Pause'), findsNothing);
      if (size.width >= 600) {
        expect(
          tester.getCenter(find.byKey(const ValueKey('infinite-score'))).dx,
          closeTo(size.width / 2, .01),
        );
      }
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('infinite-score')))
            .style!
            .fontFamily,
        'monospace',
      );
      final inputs = game.pivotTargets.toList();
      final viewport = BoardViewport.forGame(
        tester.getSize(board),
        game,
        fillWidth: 1,
      );
      await tester.tapAt(
        tester.getTopLeft(board) + viewport.gripCenter(game, 0),
      );
      expect(game.pivotTargets, inputs);
      for (var i = 0; i < 180; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('Replay complete'), findsOneWidget);
      expect(find.text('Replay stopped'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'wide recording hides pause and supports the invisible pause gesture',
    (tester) async {
      tester.view.physicalSize = const Size(1114, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        CaptureApp(
          profile: PlayerProfile()
            ..sound = false
            ..haptics = false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('RECORD FIXED INFINITE RUN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.byTooltip('Pause'), findsNothing);
      expect(
        tester.getCenter(find.byKey(const ValueKey('infinite-score'))).dx,
        closeTo(557, .01),
      );
      final gesture = find.byKey(const ValueKey('capture-pause-gesture'));
      await tester.tap(gesture);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(gesture);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Paused'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('phone records two actual fingers, saves, exports and replays', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final profile = PlayerProfile()
      ..sound = false
      ..haptics = false;
    final exported = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('rollrise/capture-export'),
      (call) async {
        expect(call.method, 'share');
        exported.add(call.arguments as String);
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('rollrise/capture-export'),
        null,
      ),
    );
    await tester.pumpWidget(CaptureApp(profile: profile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RECORD FIXED INFINITE RUN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final board = find.byType(PivotBoard);
    final game = tester.widget<PivotBoard>(board).game;
    final view = BoardViewport.forGame(
      tester.getSize(board),
      game,
      fillWidth: 1,
    );
    final origin = tester.getTopLeft(board);
    final left = await tester.startGesture(
      origin + view.gripCenter(game, 0),
      pointer: 41,
    );
    final right = await tester.startGesture(
      origin + view.gripCenter(game, 1),
      pointer: 42,
    );
    for (var i = 0; i < 150; i++) {
      if (i % 6 == 0) {
        await left.moveBy(const Offset(0, -1));
        await right.moveBy(const Offset(0, -1));
      }
      await tester.pump(const Duration(milliseconds: 16));
    }
    await left.up();
    await right.up();
    // Autosave already exists before opening the pause menu.
    final storage = SharedPreferencesAsync();
    final autosaved = await storage.getString(captureSaveKey);
    expect(autosaved, isNotNull);
    CapturePlayer(CaptureFile.decode(autosaved!)).verify();
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    await tester.tap(find.text('FINISH & SAVE'));
    await tester.pumpAndSettle();
    final saved = await storage.getString(captureSaveKey);
    final take = CaptureFile.decode(saved!);
    expect(
      take.commands.where((c) => c.name == 'grab').map((c) => c.side),
      containsAll([0, 1]),
    );
    expect(take.ticks, greaterThan(240));
    CapturePlayer(take).verify();
    expect(profile.wallet, 0); // Capture never banks coins or results.
    expect(profile.infiniteRuns, 0);
    await tester.tap(find.text('EXPORT JSON FILE'));
    await tester.pumpAndSettle();
    expect(exported, [saved]);
    await tester.tap(find.text('BACK TO CAPTURE MENU'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('REPLAY SAVED TAKE'));
    await tester.tap(find.text('REPLAY SAVED TAKE'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    for (var i = 0; i < 170; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('Replay complete'), findsOneWidget);
    expect(find.text('Replay stopped'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
