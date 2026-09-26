import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/onboarding.dart';
import 'package:balance_arcade/levels.dart';
import 'package:balance_arcade/progress_backup.dart';
import 'package:balance_arcade/tutorial_spotlight.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/one_finger_controls.dart';

Future<void> frames(WidgetTester tester, [int count = 25]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

PlayerProfile profileAt(TutorialStep step) => PlayerProfile()
  ..sound = false
  ..music = false
  ..haptics = false
  ..tutorial = TutorialProgress(step: step);
BalanceGame currentGame(WidgetTester tester) =>
    tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
Future<void> launch(WidgetTester tester, PlayerProfile profile) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ArcadeApp(profile: profile));
  await frames(tester, 3);
}

void simulate(BalanceGame game, TutorialRun tutorial, double seconds) {
  for (var i = 0; i < (seconds * 120).ceil(); i++) {
    game.step(1 / 120);
    tutorial.tick(1 / 120);
  }
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test(
    'fresh default, explicit preferences, legacy migration, and ordered checkpoints',
    () async {
      final p = PlayerProfile();
      await p.load();
      expect(p.controlMode, ControlMode.oneFinger);
      expect(p.tutorial.step, TutorialStep.controls);
      p.controlMode = ControlMode.analog;
      await p.save();
      for (final step in TutorialStep.values) {
        p.tutorial.step = step;
        p.saveTutorial();
      }
      await p.saveTutorial();
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.controlMode, ControlMode.analog);
      expect(restored.tutorial.step, TutorialStep.completed);
      await restored.replayTutorial();
      restored.tutorial.step = TutorialStep.freePlay;
      restored.tutorial.freePlaySeconds = 23;
      await restored.saveTutorial();
      final resumed = PlayerProfile();
      await resumed.load();
      expect(resumed.tutorial.step, TutorialStep.freePlay);
      expect(resumed.tutorial.freePlaySeconds, 23);
      expect(resumed.runs, 0);
      expect(resumed.wallet, 0);
      await resumed.completeTutorial();
      final skipped = PlayerProfile();
      await skipped.load();
      expect(skipped.tutorialSeen, isTrue);
      expect(skipped.tutorial.step, TutorialStep.completed);
    },
  );
  test('every checkpoint survives a restart and a backup', () async {
    final p = PlayerProfile();
    for (final step in TutorialStep.values) {
      p.tutorial.step = step;
      p.tutorial.freePlaySeconds = 17.5;
      await p.saveTutorial();
      final q = PlayerProfile();
      await q.load();
      expect(q.tutorial.step, step);
      expect(q.tutorial.freePlaySeconds, 17.5);
      final backup = ProgressBackup.decode(
        ProgressBackup.encode(q),
        testEconomy: false,
      );
      expect(backup.tutorial.step, step);
    }
  });
  test(
    'Level 1 has a gradual route, simple hazards, and connected safe paths',
    () {
      final board = ClassicLevels.build(1);
      final targets = board.where((h) => h.target > 0).toList();
      expect(targets.map((h) => h.target), List.generate(10, (i) => i + 1));
      expect(board.where((h) => h.target == 0).length, 3);
      for (var i = 1; i < targets.length; i++) {
        expect(targets[i].y, lessThan(targets[i - 1].y));
        expect((targets[i].x - targets[i - 1].x).abs(), lessThanOrEqualTo(100));
      }
      expect(ClassicLevels.hasSafeRoutes(board, []), isTrue);
    },
  );
  test(
    'a natural free-play ending advances without requiring the full timer',
    () {
      final g = BalanceGame()..start(gameMode: GameMode.infinite);
      final p = TutorialProgress(step: TutorialStep.freePlay);
      final run = TutorialRun(g, p, () {})..configure();
      g.lives = 0;
      run.tick(.01);
      expect(p.step, TutorialStep.shop);
    },
  );
  test(
    'returning players retain controls and are not forced into the new tutorial',
    () async {
      final storage = SharedPreferencesAsync();
      await storage.setBool('gilt.oneFinger', false);
      await storage.setInt('gilt.runs', 3);
      final p = PlayerProfile();
      await p.load();
      expect(p.controlMode, ControlMode.twoFinger);
      expect(p.tutorial.step, TutorialStep.completed);
      await p.replayTutorial();
      final q = PlayerProfile();
      await q.load();
      expect(q.tutorial.step, TutorialStep.controls);
      expect(q.tutorialSeen, isFalse);
      expect(q.runs, 3);
    },
  );
  test(
    'real contacts advance course, missed pickups retry, free play uses active time',
    () {
      final g = BalanceGame(seed: 4)
        ..setControlMode(ControlMode.oneFinger)
        ..start(gameMode: GameMode.infinite);
      final progress = TutorialProgress();
      final lesson = TutorialRun(g, progress, () {})..configure();
      simulate(g, lesson, 4);
      expect(progress.step, TutorialStep.controls);
      expect(g.board, isEmpty);
      expect(g.lives, 3);
      g.grabControl();
      g.dragControlVertical(-25);
      simulate(g, lesson, .02);
      expect(progress.step, TutorialStep.heartsHoles);
      g.releaseControl();
      simulate(g, lesson, 8.8);
      expect(g.lives, 3);
      expect(progress.step, TutorialStep.coins);
      // Move away from a coin and let it pass: it must be offered again.
      final first = lesson.coin;
      g.ballX = 300;
      simulate(g, lesson, 4.5);
      expect(lesson.coin, isNot(same(first)));
      expect(progress.step, TutorialStep.coins);
      g.ballX = lesson.coin!.x;
      g.left = g.right = lesson.coin!.y + BalanceGame.ballRadius;
      simulate(g, lesson, .02);
      expect(g.coinsCollected, 1);
      expect(progress.step, TutorialStep.coinsFeedback);
      simulate(g, lesson, 2.1);
      expect(progress.step, TutorialStep.shield);
      g.ballX = lesson.pickup!.x;
      g.left = g.right = lesson.pickup!.y + BalanceGame.ballRadius;
      simulate(g, lesson, .02);
      expect(g.survival.shield, greaterThan(0));
      expect(progress.step, TutorialStep.shieldFeedback);
      simulate(g, lesson, 5.1);
      expect(progress.step, TutorialStep.combo);
      g.ballX = lesson.pickup!.x;
      g.left = g.right = lesson.pickup!.y + BalanceGame.ballRadius;
      simulate(g, lesson, .02);
      expect(g.survival.combo, 2);
      expect(progress.step, TutorialStep.comboFeedback);
      simulate(g, lesson, 2.6);
      expect(progress.step, TutorialStep.freePlay);
      expect(g.tutorialCourse, isFalse);
      final seconds = progress.freePlaySeconds;
      g.setPaused(true);
      simulate(g, lesson, 50);
      expect(progress.freePlaySeconds, seconds);
      g.setPaused(false);
      progress.freePlaySeconds = 44.99;
      simulate(g, lesson, .02);
      expect(progress.step, TutorialStep.shop);
    },
  );
  test(
    'an accidental tutorial hit costs one heart and continues without resetting input',
    () {
      final g = BalanceGame(seed: 2)
        ..setControlMode(ControlMode.oneFinger)
        ..start(gameMode: GameMode.infinite);
      final progress = TutorialProgress(step: TutorialStep.heartsHoles);
      final lesson = TutorialRun(g, progress, () {})..configure();
      g.grabControl();
      g.ballX = lesson.hole!.x;
      g.left = g.right = lesson.hole!.y + BalanceGame.ballRadius;
      final serial = g.runSerial, epoch = g.inputEpoch;
      simulate(g, lesson, .02);
      expect(g.lives, 2);
      expect(progress.step, TutorialStep.heartsFeedback);
      expect(g.controlHeld, isTrue);
      expect(g.inputEpoch, epoch);
      expect(g.runSerial, serial);
      simulate(g, lesson, 2.1);
      expect(progress.step, TutorialStep.coins);
    },
  );
  testWidgets(
    'first launch learns movement, skips, and replays from Settings',
    (tester) async {
      final p = profileAt(TutorialStep.controls);
      await launch(tester, p);
      final g = currentGame(tester);
      expect(g.oneFinger, isTrue);
      expect(find.text('Drag to control the platform.'), findsOneWidget);
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.controls);
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(OneFingerControls)),
      );
      await finger.moveBy(const Offset(0, -30));
      await frames(tester, 2);
      expect(p.tutorial.step, TutorialStep.heartsHoles);
      expect(g.controlHeld, isTrue);
      await finger.up();
      await tester.tap(find.byKey(const ValueKey('skip-tutorial')));
      await tester.pump();
      expect(p.tutorial.step, TutorialStep.completed);
      expect(g.tutorialCourse, isFalse);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      await tester.ensureVisible(find.text('BACK TO CLUB'));
      await tester.tap(find.text('BACK TO CLUB'));
      await frames(tester, 35);
      await tester.tap(find.byTooltip('Settings'));
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('replay-tutorial')));
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.controls);
      expect(currentGame(tester).oneFinger, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'shop actions, Level 1 completion, and delayed Daily introduction',
    (tester) async {
      final p = profileAt(TutorialStep.shop)..wallet = 1;
      await launch(tester, p);
      await tester.tap(find.byKey(const ValueKey('board-shop')));
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.shopBall);
      await tester.tap(find.byKey(const ValueKey('buy-steel')));
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.shopPlatform);
      await tester.tap(find.byKey(const ValueKey('buy-platform-classic')));
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.shopBrowse);
      expect(p.wallet, 1);
      expect(find.byType(TutorialSpotlight), findsNothing);
      await tester.tap(find.byTooltip('Done shopping'));
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.levels);
      await tester.tap(find.byTooltip('Classic levels'));
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.level1);
      await tester.tap(find.byKey(const ValueKey('level-1')));
      await frames(tester, 35);
      expect(p.tutorial.step, TutorialStep.classicPlay);
      final g = currentGame(tester);
      expect(g.mode, GameMode.classic);
      expect(g.level, 1);
      expect(find.textContaining('Daily Challenge:'), findsNothing);
      await tester.tap(find.byType(OneFingerControls));
      await frames(tester, 2);
      expect(find.byType(TutorialSpotlight), findsNothing);
      g.won = true;
      g.completed = 10;
      g.phase = GamePhase.over;
      await frames(tester, 2);
      expect(p.tutorial.step, TutorialStep.dailyChallenge);
      expect(p.tutorial.gameplayComplete, isTrue);
      expect(find.textContaining('Daily Challenge:'), findsNothing);
      await tester.ensureVisible(find.text('BACK TO CLUB'));
      await tester.tap(find.text('BACK TO CLUB'));
      await frames(tester, 35);
      expect(find.textContaining('Daily Challenge:'), findsOneWidget);
      await tester.tap(find.byTooltip('Daily Challenge'));
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.completed);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('free play has no overlays and resumes its saved timer', (
    tester,
  ) async {
    final p = profileAt(TutorialStep.freePlay)..tutorial.freePlaySeconds = 20;
    await launch(tester, p);
    expect(find.byType(TutorialSpotlight), findsNothing);
    expect(p.tutorial.freePlaySeconds, 20);
    await tester.tap(find.byType(OneFingerControls));
    await frames(tester);
    expect(p.tutorial.freePlaySeconds, greaterThan(20));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'resumed shop and level guidance remain usable with large text and reduced motion',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final p = profileAt(TutorialStep.shopPlatform);
      await launch(tester, p);
      await frames(tester);
      expect(
        find.byKey(const ValueKey('buy-platform-classic')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('buy-platform-classic')));
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.shopBrowse);
      await tester.tap(find.byTooltip('Done shopping'));
      await frames(tester);
      await tester.tap(find.byTooltip('Classic levels'));
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.level1);
      expect(find.text('Choose your challenge.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('level-1')));
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.classicPlay);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ArcadeApp(profile: profileAt(TutorialStep.classicPlay)),
      );
      await frames(tester);
      final g = currentGame(tester);
      expect(g.level, 1);
      expect(g.mode, GameMode.classic);
      expect(g.waitingForInput, isTrue);
      await tester.tap(find.byType(OneFingerControls));
      await frames(tester, 2);
      expect(find.byType(TutorialSpotlight), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
