import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/onboarding.dart';
import 'package:balance_arcade/level_picker.dart';
import 'package:balance_arcade/levels.dart';
import 'package:balance_arcade/progress_backup.dart';
import 'package:balance_arcade/tutorial_spotlight.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_boss.dart';
import 'package:balance_arcade/late_enemies.dart';
import 'package:balance_arcade/menu_design.dart';
import 'package:balance_arcade/premium_menu.dart';
import 'package:balance_arcade/two_finger_feedback.dart';

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
Offset twoFingerContact(WidgetTester tester, int side) {
  final board = find.byType(PivotBoard);
  final size = tester.getSize(board);
  final pivotBoard = tester.widget<PivotBoard>(board);
  return tester.getTopLeft(board) +
      TwoFingerFeedbackPainter.halfCenter(
        pivotBoard.viewportFor(size, tester.view.physicalSize),
        pivotBoard.game,
        side,
      );
}

Future<void> launch(
  WidgetTester tester,
  PlayerProfile profile, {
  Size size = const Size(320, 568),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ArcadeApp(profile: profile));
  await frames(tester, 3);
}

Finder menuButton(String tooltip) =>
    find.byWidgetPredicate((w) => w is MenuQuietButton && w.tooltip == tooltip);
Finder shopBack() => find.byWidgetPredicate(
  (w) => w is MenuBackButton && w.tooltip == 'Done shopping',
);

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
      expect(p.controlMode, ControlMode.twoFinger);
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
      expect(restored.controlMode, ControlMode.oneFinger);
      expect(restored.tutorial.step, TutorialStep.completed);
      await restored.replayTutorial();
      restored.tutorial.step = TutorialStep.freePlay;
      restored.tutorial.freePlaySeconds = 23;
      await restored.saveTutorial();
      final resumed = PlayerProfile();
      await resumed.load();
      expect(resumed.tutorial.step, TutorialStep.freePlay);
      expect(resumed.tutorial.freePlaySeconds, 23);
      expect(resumed.tutorial.twoFingerReplay, isTrue);
      expect(resumed.preferredControlMode, ControlMode.oneFinger);
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
      simulate(g, lesson, 2.6);
      expect(progress.step, TutorialStep.magnet);
      g.ballX = lesson.pickup!.x;
      g.left = g.right = lesson.pickup!.y + BalanceGame.ballRadius;
      simulate(g, lesson, .02);
      expect(g.survival.magnet, greaterThan(0));
      expect(progress.step, TutorialStep.magnetFeedback);
      simulate(g, lesson, 5.1);
      expect(progress.step, TutorialStep.combo);
      g.ballX = lesson.pickup!.x;
      g.left = g.right = lesson.pickup!.y + BalanceGame.ballRadius;
      simulate(g, lesson, .02);
      expect(g.survival.combo, 2);
      expect(progress.step, TutorialStep.comboFeedback);
      simulate(g, lesson, 2.6);
      expect(progress.step, TutorialStep.boss);
      expect(g.boss?.training, isTrue);
      expect(g.lives, g.heartCapacity);
      // This walk-through checks the lesson order, not dodging.
      g.survival.shield = 30;
      simulate(g, lesson, InfiniteBoss.trainingDuration + .1);
      expect(g.boss, isNull);
      expect(g.bossesCleared, 0);
      expect(progress.step, TutorialStep.bossFeedback);
      simulate(g, lesson, 3.1);
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
  test('the practice boss is shorter and fires far less than a real one', () {
    int fired(InfiniteBoss boss) {
      final seen = <LateEnemyShot>{};
      for (var i = 0; i < 60 * 40 && !boss.expired; i++) {
        boss.step(1 / 60, target: (x: 180, y: 470));
        seen.addAll(boss.shots);
      }
      return seen.length;
    }

    final practice = InfiniteBoss.training();
    final real = InfiniteBoss();
    final practiceShots = fired(practice);
    expect(practice.expired, isTrue);
    expect(practice.age, closeTo(InfiniteBoss.trainingDuration, .02));
    expect(practice.lifetime, lessThan(real.lifetime));
    // Three three-bullet volleys and two lasers.
    expect(practiceShots, 11);
    expect(fired(real), greaterThan(practiceShots * 2));
    expect(practice.displayName, 'PRACTICE WARDEN');
  });
  test('practice-boss hits cost hearts but never end the lesson run', () {
    final g = BalanceGame(seed: 3)
      ..setControlMode(ControlMode.oneFinger)
      ..start(gameMode: GameMode.infinite);
    g.lives = 1;
    final progress = TutorialProgress(step: TutorialStep.boss);
    final lesson = TutorialRun(g, progress, () {})..configure();
    expect(g.tutorialCourse, isTrue);
    expect(g.lives, g.heartCapacity);
    // Standing still under the first, slow aimed volley.
    simulate(g, lesson, 6.5);
    expect(g.lives, lessThan(g.heartCapacity));
    expect(g.finished, isFalse);
    expect(progress.step, TutorialStep.boss);
    expect(g.boss, isNotNull);
    // Never moving through the whole fight still leaves the last heart.
    simulate(g, lesson, InfiniteBoss.trainingDuration - 6.5 + .2);
    expect(g.lives, 1);
    expect(g.finished, isFalse);
    expect(progress.step, TutorialStep.bossFeedback);
  });
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
    'first launch practices tilt, lift and re-grab, then replays from Settings',
    (tester) async {
      final p = profileAt(TutorialStep.controls);
      await launch(tester, p);
      final g = currentGame(tester);
      expect(g.controlMode, ControlMode.twoFinger);
      expect(find.text('Tilt with one thumb'), findsOneWidget);
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.controls);
      final spotlight = find.byType(TutorialSpotlight);
      final layer = tester.renderObject<RenderBox>(spotlight);
      final targets = tester
          .widget<TutorialSpotlight>(spotlight)
          .targets(layer);
      expect(targets, hasLength(2));
      for (final side in [0, 1]) {
        final center = layer.localToGlobal(targets[side].center);
        expect(
          (center - twoFingerContact(tester, side)).distance,
          lessThan(.01),
        );
      }
      final left = await tester.startGesture(twoFingerContact(tester, 0));
      await left.moveBy(const Offset(0, 30));
      await frames(tester, 2);
      expect(p.tutorial.step, TutorialStep.controlsLift);
      await left.moveBy(const Offset(0, -30));
      await frames(tester, 2);
      expect(p.tutorial.step, TutorialStep.controlsLift);
      final right = await tester.startGesture(twoFingerContact(tester, 1));
      await left.moveBy(const Offset(0, -30));
      await right.moveBy(const Offset(0, -30));
      await frames(tester, 2);
      expect(p.tutorial.step, TutorialStep.controlsRegrab);
      await left.up();
      await right.moveBy(const Offset(0, -20));
      await frames(tester, 2);
      expect(p.tutorial.step, TutorialStep.controlsRegrab);
      await right.up();
      await frames(tester, 2);
      expect(p.tutorial.step, TutorialStep.controlsRegrab);
      final leftAgain = await tester.startGesture(twoFingerContact(tester, 0));
      final rightAgain = await tester.startGesture(twoFingerContact(tester, 1));
      await leftAgain.moveBy(const Offset(0, -20));
      await frames(tester, 2);
      expect(p.tutorial.step, TutorialStep.controlsRegrab);
      await rightAgain.moveBy(const Offset(0, -20));
      await frames(tester, 2);
      expect(p.tutorial.step, TutorialStep.heartsHoles);
      expect(g.pivotHeld(0), isTrue);
      expect(g.pivotHeld(1), isTrue);
      await leftAgain.up();
      await rightAgain.up();
      await tester.tap(find.byKey(const ValueKey('skip-tutorial')));
      await tester.pump();
      expect(p.tutorial.step, TutorialStep.completed);
      expect(g.tutorialCourse, isFalse);
      await tester.tap(find.byKey(const ValueKey('board-pause')));
      await tester.pump();
      await tester.ensureVisible(find.text('BACK TO MENU'));
      await tester.tap(find.text('BACK TO MENU'));
      await frames(tester, 35);
      await tester.tap(menuButton('Settings'));
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('replay-tutorial')));
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.controls);
      expect(currentGame(tester).controlMode, ControlMode.twoFinger);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'keyboard players can tilt, lift, release and lift again',
    variant: const TargetPlatformVariant({TargetPlatform.macOS}),
    (tester) async {
      final p = profileAt(TutorialStep.controls);
      await launch(tester, p);
      expect(find.text('Tilt one end'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.controlsLift);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.controlsRegrab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      await frames(tester, 2);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await frames(tester, 15);
      expect(p.tutorial.step, TutorialStep.heartsHoles);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('resumed replay uses Two-Finger and returns to the saved Halo', (
    tester,
  ) async {
    final original = profileAt(TutorialStep.completed)
      ..controlMode = ControlMode.oneFinger
      ..haloJoystick = true;
    await original.save();
    await original.replayTutorial();
    original.tutorial.step = TutorialStep.controlsRegrab;
    await original.saveTutorial();
    final resumed = PlayerProfile();
    await resumed.load();
    await launch(tester, resumed);
    expect(resumed.preferredControlMode, ControlMode.oneFinger);
    expect(currentGame(tester).controlMode, ControlMode.twoFinger);
    expect(find.text('Release and grab again'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('skip-tutorial')));
    await frames(tester, 40);
    expect(currentGame(tester).controlMode, ControlMode.oneFinger);
    expect(currentGame(tester).haloJoystick, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final step in [TutorialStep.controls, TutorialStep.classicPlay]) {
    testWidgets('skipping $step before moving returns to the menu', (
      tester,
    ) async {
      final p = profileAt(step);
      await launch(tester, p);
      expect(
        find.byKey(const ValueKey('menu-play')).hitTestable(),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('skip-tutorial')));
      await frames(tester, 40);
      expect(p.tutorial.step, TutorialStep.completed);
      expect(currentGame(tester).tutorialCourse, isFalse);
      final play = find.byKey(const ValueKey('menu-play')).hitTestable();
      expect(play, findsOneWidget);
      await tester.tap(play);
      await frames(tester, 40);
      expect(
        find.byKey(const ValueKey('start-control-prompt')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final size in [const Size(820, 1180), const Size(1180, 820)]) {
    testWidgets('spotlight covers scaled menu controls at $size', (
      tester,
    ) async {
      for (final (step, button) in [
        (TutorialStep.shop, find.byKey(const ValueKey('board-shop'))),
        (TutorialStep.levels, find.byKey(const ValueKey('choose-level'))),
        (TutorialStep.dailyChallenge, menuButton('Modes')),
      ]) {
        await launch(tester, profileAt(step), size: size);
        await frames(tester);
        final spotlight = find.byType(TutorialSpotlight);
        final layer = tester.renderObject<RenderBox>(spotlight);
        final target = tester
            .widget<TutorialSpotlight>(spotlight)
            .targets(layer);
        final buttonRect = tester
            .getRect(button)
            .shift(-tester.getTopLeft(spotlight));
        expect(target.single, rectMoreOrLessEquals(buttonRect));
        expect(button.hitTestable(at: const Alignment(.96, 0)), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });
  }

  testWidgets(
    'shop actions lead to Level 1, then a win shows the Daily lesson immediately',
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
      await tester.tap(shopBack());
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.levels);
      expect(find.text('Classic levels'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('choose-level')));
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.level1);
      await tester.tap(find.byKey(const ValueKey('level-1')));
      await frames(tester, 35);
      expect(p.tutorial.step, TutorialStep.classicPlay);
      final g = currentGame(tester);
      expect(g.mode, GameMode.classic);
      expect(g.level, 1);
      expect(find.textContaining('Daily Challenge:'), findsNothing);
      await tester.tapAt(twoFingerContact(tester, 0));
      await frames(tester, 2);
      expect(find.byType(TutorialSpotlight), findsNothing);
      g.won = true;
      g.completed = 10;
      g.phase = GamePhase.over;
      await frames(tester, 2);
      expect(p.tutorial.step, TutorialStep.dailyChallenge);
      expect(p.tutorial.gameplayComplete, isTrue);
      expect(find.text('TUTORIAL · 11 OF 11'), findsOneWidget);
      expect(find.text('Daily Challenge'), findsOneWidget);
      final levels = find.text('LEVELS');
      await tester.ensureVisible(levels);
      await tester.tap(levels);
      await frames(tester);
      final picker = find.byType(LevelPicker);
      expect(picker, findsOneWidget);
      expect(tester.widget<LevelPicker>(picker).tutorial, isFalse);
      expect(tester.widget<LevelPicker>(picker).selected, 2);
      Navigator.of(tester.element(picker)).pop();
      await frames(tester);
      await tester.ensureVisible(find.text('BACK TO MENU'));
      await tester.tap(find.text('BACK TO MENU'));
      await frames(tester, 35);
      // The win moved Classic on, without tapping Next Level.
      expect(p.classicLevel, 2);
      expect(find.textContaining('Daily Challenge:'), findsOneWidget);
      await tester.tap(menuButton('Modes'));
      await frames(tester);
      expect(p.tutorial.step, TutorialStep.completed);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('a Level 1 loss lets the player finish the tutorial', (
    tester,
  ) async {
    final p = profileAt(TutorialStep.classicPlay);
    await launch(tester, p);
    await tester.tapAt(twoFingerContact(tester, 0));
    await frames(tester, 2);
    final game = currentGame(tester);
    game.lives = 0;
    game.phase = GamePhase.over;
    await frames(tester, 2);
    expect(game.won, isFalse);
    expect(p.tutorial.step, TutorialStep.dailyChallenge);
    expect(find.text('LEVELS'), findsNothing);

    await tester.ensureVisible(find.text('BACK TO MENU'));
    await tester.tap(find.text('BACK TO MENU'));
    await frames(tester, 35);
    expect(find.text('Classic levels'), findsNothing);
    expect(find.text('Daily Challenge'), findsOneWidget);
    await tester.tap(menuButton('Modes'));
    await frames(tester);
    expect(p.tutorialSeen, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('free play has no overlays and resumes its saved timer', (
    tester,
  ) async {
    final p = profileAt(TutorialStep.freePlay)..tutorial.freePlaySeconds = 20;
    await launch(tester, p);
    expect(find.byType(TutorialSpotlight), findsNothing);
    expect(p.tutorial.freePlaySeconds, 20);
    await tester.tapAt(twoFingerContact(tester, 0));
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
      await tester.tap(shopBack());
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('choose-level')));
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
      await tester.tapAt(twoFingerContact(tester, 0));
      await frames(tester, 2);
      expect(find.byType(TutorialSpotlight), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
