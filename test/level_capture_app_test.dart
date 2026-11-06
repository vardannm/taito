import 'package:balance_arcade/capture_main.dart';
import 'package:balance_arcade/capture_run.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/level_picker.dart';
import 'package:balance_arcade/pivot_board.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/record_completed_level.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  for (final size in [
    const Size(402, 874),
    const Size(1032, 1376),
    const Size(951, 669),
  ]) {
    testWidgets('recorded level replays without divergence on $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final recorder = CaptureRecorder(const CaptureSetup(level: 24));
      recorder.game.arenaStretch = 1.05;
      recorder.game.visibleTop = -160;
      recorder.game.visibleBottom = 650;
      recorder.game.grabPivot(0);
      recorder.game.grabPivot(1);
      recorder.game.dragPivot(0, -8);
      for (var i = 0; i < 180; i++) recorder.step();
      final file = recorder.snapshot();
      await tester.pumpWidget(
        MaterialApp(
          home: CaptureScreen(
            profile: PlayerProfile()
              ..sound = false
              ..haptics = false,
            setup: const CaptureSetup(),
            replay: file,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      for (var i = 0; i < 140; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      expect(game.mode, GameMode.classic);
      expect(game.level, 24);
      expect(captureFingerprint(game), file.checkpoints[file.ticks]);
      expect(find.text('Replay complete'), findsOneWidget);
      expect(find.text('Replay stopped'), findsNothing);
      expect(find.byTooltip('Pause'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('choose any level, complete it, export verified JSON and retry', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);
    final profile = PlayerProfile()
      ..sound = false
      ..haptics = false;
    final storage = SharedPreferencesAsync();
    await storage.setString(captureSaveKey, 'preserve the Infinite take');
    String? exported;
    const channel = MethodChannel('rollrise/capture-export');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      exported = call.arguments as String;
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await tester.pumpWidget(CaptureApp(profile: profile, levelCapture: true));
    await tester.pumpAndSettle();
    expect(
      find.text('PLAY BUNDLED REPLAY'),
      findsNothing,
    ); // Current bundle is Infinite.
    await tester.tap(find.text('CHOOSE LEVEL TO RECORD'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LevelPicker>(find.byType(LevelPicker)).allLevelsUnlocked,
      isTrue,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('level-1')));
    await tester.tap(find.byKey(const ValueKey('level-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    expect(game.mode, GameMode.classic);
    expect(game.level, 1);
    expect(
      find.byKey(const ValueKey('classic-capture-progress')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('infinite-score')), findsNothing);
    final driver = LevelRecordingDriver();
    for (var frame = 0; frame < 9000 && !game.finished; frame++) {
      driver.move(game);
      await tester.pump(const Duration(microseconds: 33334));
    }
    await tester.pumpAndSettle();
    expect(game.won, isTrue);
    expect(find.text('Level complete'), findsOneWidget);
    final saved = await storage.getString(levelCaptureSaveKey);
    final take = CaptureFile.decode(saved!);
    expect(take.setup.level, 1);
    expect(take.summary['won'], isTrue);
    CapturePlayer(take).verify();
    expect(
      await storage.getString(captureSaveKey),
      'preserve the Infinite take',
    );
    expect(profile.wallet, 0);
    expect(profile.totalStars, 0);
    await tester.tap(find.text('EXPORT JSON FILE'));
    await tester.pumpAndSettle();
    expect(exported, saved);
    await tester.tap(find.text('RECORD LEVEL AGAIN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final retry = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    expect(retry.level, 1);
    expect(retry.waitingForInput, isTrue);
    expect(retry.completed, 0);
    expect(retry, isNot(same(game)));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
