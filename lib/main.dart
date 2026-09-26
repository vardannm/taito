import 'playtest_recorder.dart';
import 'app_analytics.dart';
export 'pivot_board.dart';
import 'pivot_board.dart';
import 'club.dart';
import 'control_options.dart';
import 'infinite_painter.dart';
import 'ball_shop.dart';
import 'daily_prize_sheet.dart';
import 'infinite_progress.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'board_painter.dart';
import 'game.dart';
import 'levels.dart';
import 'level_picker.dart';
import 'profile.dart';
import 'onboarding.dart';
import 'tutorial_spotlight.dart';
import 'rewards.dart';
import 'mastery_widgets.dart';
import 'analog_controls.dart';
import 'merge_widgets.dart';
import 'merge.dart';
import 'laser_maze.dart';
import 'laser_maze_widgets.dart';
import 'mode_carousel.dart';
import 'mode_previews.dart';
import 'heart_loss_effect.dart';
import 'control_hint.dart';
import 'one_finger_controls.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: cream,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  final profile = PlayerProfile();
  await profile.load();
  if (kDebugMode) await profile.grantBallTestCoins();
  final analytics = await AppAnalytics.initialize();
  runApp(ArcadeApp(profile: profile, analytics: analytics));
}

class ArcadeApp extends StatelessWidget {
  const ArcadeApp({super.key, required this.profile, this.analytics});
  final PlayerProfile profile;
  final AppAnalytics? analytics;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'GILT • Precision Arcade',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(seedColor: ink, surface: cream),
      fontFamily: 'sans-serif',
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
    ),
    home: GameScreen(profile: profile, analytics: analytics),
  );
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.profile, this.analytics});
  final PlayerProfile profile;
  final AppAnalytics? analytics;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final game = BalanceGame();
  final frame = ValueNotifier<int>(0);
  final hud = ValueNotifier<Object?>(null);
  final backdrop = ValueNotifier<int>(0);
  final feedback = GameFeedback();
  final playtest = PlaytestRecorder();
  late final analytics = widget.analytics ?? AppAnalytics();
  final touch = [0.0, 0.0];
  final keyboard = [0.0, 0.0];
  late final Ticker ticker;
  Duration? previous;
  double accumulator = 0;
  bool recorded = false, newBest = false, briefing = false;
  List<CabinetStyle> newUnlocks = [];
  TutorialRun? tutorialRun;
  bool tutorialSheetOpen = false;
  final tutorialShopKey = GlobalKey();
  final tutorialLevelsKey = GlobalKey();
  final tutorialDailyKey = GlobalKey();
  final tutorialHeartsKey = GlobalKey();
  final tutorialScoreKey = GlobalKey();
  final tutorialCoinsKey = GlobalKey();
  bool get tutorialActive => !profile.tutorialSeen && profile.tutorial.active;
  TutorialStep get tutorialStep => profile.tutorial.step;

  void tutorialChanged() {
    unawaited(profile.saveTutorial());
    if (mounted) setState(() {});
  }

  void advanceTutorial(TutorialStep step) {
    profile.tutorial.step = step;
    tutorialChanged();
  }

  void skipTutorial() {
    unawaited(profile.completeTutorial());
    game.endTutorialCourse();
    tutorialRun = null;
    setState(() {});
  }

  void replayTutorial() {
    unawaited(profile.replayTutorial());
    profile.controlMode = ControlMode.oneFinger;
    unawaited(profile.save());
    setState(() {
      prepareInfinite();
      entrance.value = 1;
    });
  }

  bool readyRetry = false;
  final carouselKey = GlobalKey<ModeCarouselState>();
  final boardKey = GlobalKey();
  final analogKey = GlobalKey();
  late final AnimationController entrance;
  bool returning = false;
  final heartEffects = <HeartLossEffect>[];
  final effectsKey = GlobalKey();
  int observedLives = 3;
  double get expansion =>
      Curves.easeInOutCubic.transform((entrance.value / .78).clamp(0.0, 1.0));
  double get chromeOpacity => entrance.isCompleted
      ? 0
      : 1 - ((entrance.value - .78) / .22).clamp(0.0, 1.0);
  int selectedMode = 0;
  bool carouselMoving = false;
  PlayerProfile get profile => widget.profile;

  @override
  void initState() {
    super.initState();
    entrance =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 560),
        )..addListener(() {
          if (mounted) setState(() {});
        });
    ticker = createTicker(tick);
    if (profile.tutorialSeen) profile.tutorial.step = TutorialStep.completed;
    if (tutorialActive && tutorialStep == TutorialStep.shopBrowse) {
      profile.tutorial.step = TutorialStep.levels;
      unawaited(profile.saveTutorial());
    }
    if (tutorialActive && tutorialStep == TutorialStep.classicPlay) {
      prepareWorld(1);
    } else {
      prepareInfinite();
    }
    if (tutorialActive &&
        (tutorialStep.inInfinite || tutorialStep == TutorialStep.classicPlay))
      entrance.value = 1;
    game.onInputStarted = () {
      tutorialRun?.configure();
      analytics.startRun(game);
      if (game.mode == GameMode.classic) profile.classicLevel = game.level;
      if (game.mode == GameMode.laserMaze) profile.mazeLevel = game.level;
      unawaited(profile.save());
      playtest.record("run_started", {
        "mode": game.mode.name,
        "control": game.controlMode.name,
        "retry": readyRetry,
      });
      // Do not reset controls or replace the board on the starting touch.
      enterWorld();
      setState(() {});
    };
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(onKey);
    if (tutorialActive &&
        [
          TutorialStep.shopBall,
          TutorialStep.shopPlatform,
          TutorialStep.level1,
        ].contains(tutorialStep)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (tutorialStep == TutorialStep.level1) {
          unawaited(selectLevel());
        } else {
          unawaited(showBallShop());
        }
      });
    }
  }

  void runTicker() {
    previous = null;
    accumulator = 0;
    if (!ticker.isActive) ticker.start();
  }

  void enterWorld() {
    if (MediaQuery.disableAnimationsOf(context)) {
      entrance.value = 1;
    } else {
      entrance.forward();
    }
    if (!game.paused) runTicker();
  }

  void spawnHeartLoss() {
    final board = boardKey.currentContext?.findRenderObject() as RenderBox?;
    final layer = effectsKey.currentContext?.findRenderObject() as RenderBox?;
    if (board == null || layer == null || !board.hasSize || !layer.hasSize)
      return;
    final viewport = BoardViewport.forGame(
      Size(
        board.size.width,
        math.max(
          1,
          board.size.height - (game.oneFinger ? OneFingerControls.height : 0),
        ),
      ),
      game,
      fillWidth: expansion,
    );
    final point = viewport.project(
      Offset(game.ballX, game.screenY(game.platformY(game.ballX))),
    );
    final origin =
        layer.globalToLocal(board.localToGlobal(point)) - const Offset(0, 20);
    if (heartEffects.length == 3) heartEffects.removeAt(0);
    heartEffects.add(HeartLossEffect(origin));
  }

  void tick(Duration now) {
    final delta = previous == null
        ? 1 / 120
        : (now - previous!).inMicroseconds / 1000000;
    previous = now;
    for (final effect in heartEffects) {
      effect.age += delta;
    }
    heartEffects.removeWhere((effect) => effect.finished);
    accumulator += math.min(delta, .05);
    final inputEpoch = game.inputEpoch;
    final before =
        '${game.phase}/${game.target}/${game.lives}/${game.inputEpoch}/$recorded';
    while (accumulator >= 1 / 120) {
      game.step(1 / 120);
      tutorialRun?.tick(1 / 120);
      accumulator -= 1 / 120;
    }
    if (game.lives < observedLives) spawnHeartLoss();
    syncMusic();
    observedLives = game.lives;
    // Feedback (including a lost heart) must not invalidate held input.
    // Only simulation transitions that actually clear input release keys.
    if (game.inputEpoch != inputEpoch) {
      touch.fillRange(0, 2, 0);
      keyboard.fillRange(0, 2, 0);
    }
    profile.bankCoins(game);
    if (game.event != null) {
      playtest.record(game.event!.name, {
        "mode": game.mode.name,
        "target": game.completed,
        "misses": game.misses,
      });
      unawaited(feedback.play(game.event!, profile));

      game.event = null;
    }
    if (game.finished && !recorded) {
      recorded = true;
      analytics.finishRun(game);
      playtest.record("run_finished", {
        "mode": game.mode.name,
        "won": game.won,
        "score": game.score,
        "activeSeconds": game.elapsed,
      });
      if (tutorialActive &&
          tutorialStep == TutorialStep.classicPlay &&
          game.mode == GameMode.classic &&
          game.level == 1 &&
          game.won) {
        advanceTutorial(TutorialStep.dailyChallenge);
      }
      if (!game.practice) {
        final locked = CabinetStyle.values
            .where((c) => !profile.isUnlocked(c))
            .toList();
        newBest = profile.recordResult(game);
        newUnlocks = locked.where(profile.isUnlocked).toList();
        unawaited(profile.save());
      }
    }
    // Rebuild HUD text only when its displayed values change, not every frame.
    hud.value = (
      game.score,
      game.metres,
      game.lives,
      game.target,
      game.elapsed.ceil(),
      game.hazardLabel,
      game.dangerActive,
      game.section,
      game.survival.combo,
      game.paceLevel,
      game.survival.noticeTime > 0 ? game.survival.notice : '',
      game.survival.shield.ceil(),
      game.survival.recovery.ceil(),
      game.coinsCollected,
      game.coins.length,
      game.merging ? game.mergeRun.highest : 0,
    );
    backdrop.value = (game.survival.visualCombo * 64).round();
    frame.value++;
    if (game.finished && heartEffects.isEmpty) ticker.stop();
    if (before !=
        '${game.phase}/${game.target}/${game.lives}/${game.inputEpoch}/$recorded')
      setState(() {});
  }

  void clearControls() {
    touch.fillRange(0, 2, 0);
    keyboard.fillRange(0, 2, 0);
    game.clearInput();
  }

  void input(int side, double value) {
    touch[side] = value;
    applyInput();
  }

  void applyInput() {
    if (!game.canControl) return;
    game.leftInput = (touch[0] + keyboard[0]).clamp(-1.0, 1.0);
    game.rightInput = (touch[1] + keyboard[1]).clamp(-1.0, 1.0);
  }

  bool onKey(KeyEvent event) {
    if ((tutorialActive &&
            game.waitingForInput &&
            !tutorialStep.inInfinite &&
            tutorialStep != TutorialStep.classicPlay) ||
        returning ||
        carouselMoving ||
        ModalRoute.of(context)?.isCurrent != true)
      return false;
    final key = event.logicalKey;
    const controlKeys = [
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
    ];
    if (key == LogicalKeyboardKey.escape &&
        event is KeyDownEvent &&
        game.started &&
        !game.waitingForInput &&
        !game.finished) {
      pause();
      return true;
    }
    if (!controlKeys.contains(key)) return false;
    if (event is KeyDownEvent) game.beginInput();
    final held = HardwareKeyboard.instance.logicalKeysPressed;
    keyboard[0] =
        (held.contains(LogicalKeyboardKey.keyS) ? 1.0 : 0) -
        (held.contains(LogicalKeyboardKey.keyW) ? 1.0 : 0);
    keyboard[1] =
        (held.contains(LogicalKeyboardKey.arrowDown) ? 1.0 : 0) -
        (held.contains(LogicalKeyboardKey.arrowUp) ? 1.0 : 0);
    applyInput();
    return true;
  }

  void start(GameMode mode, {DateTime? challengeDate}) => setState(() {
    if (mode == GameMode.infinite) {
      prepareInfinite(retry: game.infinite && game.finished);
      entrance.reverse();
      return;
    }
    if (mode == GameMode.classic &&
        !profile.isClassicLevelUnlocked(profile.classicLevel)) {
      unawaited(selectLevel());
      return;
    }
    final index = arcadeModes.indexOf(mode);
    if (index >= 0) {
      carouselKey.currentState?.jumpTo(index);
      selectedMode = index;
      carouselMoving = false;
    }
    playtest.record("run_started", {
      "mode": mode.name,
      "control": profile.controlMode.name,
      "level": mode == GameMode.laserMaze
          ? profile.mazeLevel
          : profile.classicLevel,
      "retry":
          game.finished &&
          game.mode == mode &&
          (mode != GameMode.classic || profile.classicLevel == game.level) &&
          (mode != GameMode.laserMaze || profile.mazeLevel == game.level) &&
          (mode != GameMode.daily ||
              DailyChallenge.key(challengeDate ?? DateTime.now()) ==
                  game.dailyKey),
    });
    clearControls();
    recorded = newBest = false;
    game.setControlMode(profile.controlMode);
    game.cabinet = profile.cabinet;
    game.cosmetic = profile.selectedBall;
    game.platformStyle = profile.selectedPlatform;
    game.cabinet = profile.cabinet;
    game.analogSensitivity = profile.analogSensitivity;
    game.twoFingerSensitivity = profile.twoFingerSensitivity;
    game.infiniteStartingPace = InfiniteTuning.startingPace(
      profile.infiniteBest,
    );
    newUnlocks = [];
    game.start(
      gameMode: mode,
      levelNumber: mode == GameMode.laserMaze
          ? profile.mazeLevel
          : profile.classicLevel,
      challengeDate: challengeDate,
      waitForInput:
          tutorialActive &&
          tutorialStep == TutorialStep.classicPlay &&
          mode == GameMode.classic,
    );
    tutorialRun = null;
    briefing = game.finale;
    analytics.selectMode(game.mode);
    analytics.startRun(game);
    if (briefing) game.setPaused(true);
    observedLives = game.lives;
    heartEffects.clear();
    enterWorld();
    syncMusic();
  });
  Future<void> selectLevel() async {
    setState(() => tutorialSheetOpen = true);
    if (tutorialActive && tutorialStep == TutorialStep.levels)
      advanceTutorial(TutorialStep.level1);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cream,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .84,
        child: SafeArea(
          child: LevelPicker(
            tutorial:
                tutorialActive &&
                [
                  TutorialStep.level1,
                  TutorialStep.classicPlay,
                ].contains(tutorialStep),
            onSkipTutorial: skipTutorial,
            selected: profile.classicLevel,
            totalStars: profile.totalStars,
            records: {
              for (var i = 1; i <= ClassicLevels.count; i++)
                i: profile.levelRecord(i),
            },
            controlLabel: profile.controlMode.label,
            onSelected: (number) {
              if (!profile.selectClassicLevel(number)) return;
              if (tutorialActive &&
                  [
                    TutorialStep.level1,
                    TutorialStep.classicPlay,
                  ].contains(tutorialStep) &&
                  number == 1) {
                advanceTutorial(TutorialStep.classicPlay);
              }
              unawaited(profile.save());
              Navigator.pop(context);
              start(GameMode.classic);
            },
          ),
        ),
      ),
    );
    if (mounted) setState(() => tutorialSheetOpen = false);
  }

  Future<void> selectMaze() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: cream,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .84,
      child: SafeArea(
        child: LaserMazePicker(
          selected: profile.mazeLevel,
          control: profile.controlMode,
          bestTimes: {
            for (var i = 1; i <= LaserMazeRoute.count; i++)
              if (profile.mazeBestTime(i, profile.controlMode) case final time?)
                i: time,
          },
          onSelected: (number) {
            profile.mazeLevel = number;
            unawaited(profile.save());
            Navigator.pop(context);
            start(GameMode.laserMaze);
          },
        ),
      ),
    ),
  );
  Future<void> showMerge() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: cream,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '2048 / MERGE',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Steer the solid middle ball into numbers. The largest number stays in the middle, with smaller numbers connected on both sides. Matching values combine anywhere in the snake and can cascade into one bigger ball.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Collect equal or smaller numbers with the middle ball. Touching a larger number ends the run: dodge the red rings! Every 400 score sends a numbered gate down from the top. Your main ball must be strictly greater than its number to pass. Matching values merge anywhere in the snake. Play continues beyond 2048.',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'BEST ${profile.mergeBest}  ·  HIGHEST ${formatMergeNumber(profile.mergeHighest)}',
                        style: label(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    start(GameMode.merge2048);
                  },
                  child: const Text('PLAY 2048'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> showDaily() {
    final date = DailyChallenge.day(DateTime.now());
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: cream,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .84,
          child: DailyCard(
            date: date,
            profile: profile,
            onPlay: () {
              Navigator.pop(context);
              start(GameMode.daily, challengeDate: date);
            },
          ),
        ),
      ),
    );
  }

  Future<void> showDailyPrizes() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cream,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DailyPrizeSheet(profile: profile),
    );
    if (mounted) setState(() {});
  }

  Future<void> showBallShop() async {
    setState(() => tutorialSheetOpen = true);
    if (tutorialActive && tutorialStep == TutorialStep.shop)
      advanceTutorial(TutorialStep.shopBall);
    analytics.openShop(game.mode);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cream,
      builder: (_) => FractionallySizedBox(
        heightFactor: .85,
        child: BallShop(
          profile: profile,
          onTutorialChanged: tutorialChanged,
          onSkipTutorial: skipTutorial,
        ),
      ),
    );
    if (mounted)
      setState(() {
        tutorialSheetOpen = false;
        if (tutorialActive && tutorialStep == TutorialStep.shopBrowse)
          advanceTutorial(TutorialStep.levels);
        game.cosmetic = profile.selectedBall;
        game.platformStyle = profile.selectedPlatform;
        game.cabinet = profile.cabinet;
        if (game.waitingForInput) prepareWorld(selectedMode);
      });
  }

  /// Infinite and 2048 run to a loop; every other screen is quiet. Pausing
  /// holds the track rather than restarting it.
  static const themeTrack = 'audio/theme.m4a';
  void syncMusic() {
    final wants =
        (game.infinite || game.merging) &&
        profile.music &&
        game.started &&
        !game.finished;
    unawaited(
      feedback.updateMusic(
        track: wants ? themeTrack : null,
        playing: !game.paused && !game.waitingForInput && !returning,
      ),
    );
  }

  void pause() => setState(() {
    briefing = false;
    clearControls();
    game.setPaused(!game.paused);
    syncMusic();
    if (game.paused) {
      ticker.stop();
    } else {
      runTicker();
    }
  });
  void prepareInfinite({bool retry = false}) {
    prepareWorld(0, retry: retry);
  }

  int get classicContinueLevel {
    var level = profile.classicLevel.clamp(1, ClassicLevels.count);
    while (level > 1 && !profile.isClassicLevelUnlocked(level)) {
      level--;
    }
    return level;
  }

  int worldLevel(int index) => switch (arcadeModes[index]) {
    GameMode.classic =>
      tutorialActive && tutorialStep == TutorialStep.classicPlay
          ? 1
          : classicContinueLevel,
    GameMode.laserMaze => profile.mazeLevel.clamp(1, LaserMazeRoute.count),
    _ => 1,
  };

  void prepareWorld(int index, {bool retry = false}) {
    analytics.selectMode(arcadeModes[index]);
    ticker.stop();
    previous = null;
    accumulator = 0;
    heartEffects.clear();
    carouselKey.currentState?.jumpTo(index);
    carouselMoving = false;
    selectedMode = index;
    readyRetry = retry;
    clearControls();
    recorded = newBest = briefing = false;
    newUnlocks = [];
    game.setControlMode(profile.controlMode);
    game.cabinet = profile.cabinet;
    game.cosmetic = profile.selectedBall;
    game.platformStyle = profile.selectedPlatform;
    game.cabinet = profile.cabinet;
    game.analogSensitivity = profile.analogSensitivity;
    game.twoFingerSensitivity = profile.twoFingerSensitivity;
    game.infiniteStartingPace = InfiniteTuning.startingPace(
      profile.infiniteBest,
    );
    game.start(
      gameMode: arcadeModes[index],
      levelNumber: worldLevel(index),
      waitForInput: true,
    );
    tutorialRun = tutorialActive && tutorialStep.inInfinite && game.infinite
        ? TutorialRun(game, profile.tutorial, tutorialChanged)
        : null;
    tutorialRun?.configure();
    observedLives = game.lives;
    syncMusic();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final neighbor in [index - 1, index + 1]) {
        if (neighbor >= 0 && neighbor < arcadeModes.length) {
          unawaited(
            precacheImage(
              AssetImage(
                modePreviewAsset(arcadeModes[neighbor], worldLevel(neighbor)),
              ),
              context,
            ),
          );
        }
      }
    });
    frame.value++;
  }

  Future<void> home() async {
    if (returning) return;
    profile.bankCoins(game);
    final index = arcadeModes.indexOf(game.mode);
    setState(() {
      returning = true;
      clearControls();
      game.setPaused(true);
      ticker.stop();
      heartEffects.clear();
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      entrance.value = 0;
    } else {
      try {
        await entrance.reverse().orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      prepareWorld(index < 0 ? 0 : index);
      returning = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && game.started && !game.finished) {
      unawaited(profile.saveTutorial());
      if (game.waitingForInput) {
        clearControls();
        return;
      }
      setState(() {
        clearControls();
        game.setPaused(true);
        ticker.stop();
      });
    }
    syncMusic();
  }

  @override
  void dispose() {
    game.onInputStarted = null;
    profile.bankCoins(game);
    unawaited(profile.saveTutorial());
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(onKey);
    unawaited(feedback.updateMusic(track: null, playing: false));
    ticker.dispose();
    entrance.dispose();
    heartEffects.clear();
    frame.dispose();
    hud.dispose();
    backdrop.dispose();
    feedback.dispose();
    super.dispose();
  }

  /// Foreground follows the currently visible Infinite background.
  Color get chromeInk =>
      game.infinite ? infiniteBoardInk(game, const Offset(180, 500)) : ink;

  TextStyle label([Color color = ink]) => TextStyle(
    fontSize: 10,
    letterSpacing: 1.8,
    fontWeight: FontWeight.w700,
    color: color,
  );

  @override
  Widget build(BuildContext context) => playScreen(context);

  Widget? tutorialOverlay() {
    if (!tutorialActive ||
        tutorialSheetOpen ||
        returning ||
        game.paused ||
        game.finished)
      return null;
    final step = tutorialStep;
    final guidedPlay = step.scripted && game.infinite;
    final objective =
        step == TutorialStep.classicPlay &&
        game.mode == GameMode.classic &&
        game.waitingForInput;
    final menu =
        game.waitingForInput && entrance.isDismissed && !step.inInfinite;
    if (!guidedPlay && !objective && !menu) return null;
    if (step == TutorialStep.freePlay) return null;
    final message = switch (step) {
      TutorialStep.controls => 'Drag to control the platform.',
      TutorialStep.heartsHoles => 'Avoid holes. A fall costs 1 heart.',
      TutorialStep.heartsFeedback =>
        game.misses > 0
            ? 'One heart lost. Keep going.'
            : 'Keep going. Protect your hearts.',
      TutorialStep.coins => 'Collect coins.',
      TutorialStep.coinsFeedback => 'Coin saved. Spend it later.',
      TutorialStep.shield => 'Shield protects you from danger.',
      TutorialStep.shieldFeedback => 'Protected! Watch the blue ring.',
      TutorialStep.metrics => 'Climb higher. Grow your score.',
      TutorialStep.combo => 'Collect the gold crystal.',
      TutorialStep.comboFeedback => 'Collect crystals to grow your Combo.',
      TutorialStep.shop ||
      TutorialStep.shopBall ||
      TutorialStep.shopPlatform ||
      TutorialStep.shopBrowse => 'Spend your coins and customize your game.',
      TutorialStep.levels => 'There are more ways to play. Open Levels.',
      TutorialStep.level1 => 'Open Levels, then choose Level 1.',
      TutorialStep.classicPlay =>
        'Reach glowing holes in order, 1–10. Avoid dark holes. Drag to begin.',
      TutorialStep.dailyChallenge =>
        'Daily Challenge: a new board each day. Earn stars and beat your best.',
      _ => '',
    };
    return TutorialSpotlight(
      key: const ValueKey('onboarding-spotlight'),
      message: message,
      onSkip: skipTutorial,
      listenable: frame,
      blockOutside: menu && !objective,
      bottomInset: guidedPlay || objective ? OneFingerControls.height + 12 : 16,
      messageTop: guidedPlay || objective
          ? MediaQuery.paddingOf(context).top + 118
          : null,
      targets: (layer) {
        final result = <Rect>[];
        void ui(GlobalKey key) {
          final r = tutorialTarget(key, layer);
          if (r != null) result.add(r);
        }

        final board = boardKey.currentContext?.findRenderObject() as RenderBox?;
        void worldPoint(double x, double y, [double radius = 22]) {
          if (board == null || !board.hasSize) return;
          final viewport = BoardViewport.forGame(
            Size(
              board.size.width,
              math.max(
                1,
                board.size.height -
                    (game.oneFinger ? OneFingerControls.height : 0),
              ),
            ),
            game,
            fillWidth: expansion,
          );
          final point = layer.globalToLocal(
            board.localToGlobal(viewport.project(Offset(x, game.screenY(y)))),
          );
          result.add(
            Rect.fromCircle(center: point, radius: radius * viewport.scale),
          );
        }

        void controls() {
          if (game.analog) {
            ui(analogKey);
            return;
          }
          if (board == null || !board.hasSize) return;
          if (game.oneFinger) {
            final top = layer.globalToLocal(
              board.localToGlobal(
                Offset(12, board.size.height - OneFingerControls.height + 10),
              ),
            );
            result.add(
              top & Size(board.size.width - 24, OneFingerControls.height - 20),
            );
          } else {
            worldPoint(20, game.left, 28);
            worldPoint(340, game.right, 28);
          }
        }

        if (objective) {
          worldPoint(game.activeHole.x, game.activeHole.y);
          controls();
        } else if (menu) {
          ui(
            step.inShop
                ? tutorialShopKey
                : step == TutorialStep.dailyChallenge
                ? tutorialDailyKey
                : tutorialLevelsKey,
          );
        } else {
          switch (step) {
            case TutorialStep.controls:
              controls();
            case TutorialStep.heartsHoles:
              if (tutorialRun?.hole case final hole?)
                worldPoint(hole.x, hole.y);
              ui(tutorialHeartsKey);
            case TutorialStep.heartsFeedback:
              ui(tutorialHeartsKey);
            case TutorialStep.coins:
              if (tutorialRun?.coin case final coin?)
                worldPoint(coin.x, coin.y);
            case TutorialStep.coinsFeedback:
              ui(tutorialCoinsKey);
            case TutorialStep.shield || TutorialStep.combo:
              if (tutorialRun?.pickup case final item?)
                worldPoint(item.x, item.y);
            case TutorialStep.shieldFeedback:
              worldPoint(game.ballX, game.ballY, 28);
            case TutorialStep.metrics || TutorialStep.comboFeedback:
              ui(tutorialScoreKey);
            default:
              break;
          }
        }
        return result;
      },
    );
  }

  Future<void> showModes() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: cream,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      Widget choice(String title, IconData icon, VoidCallback action) =>
          ListTile(
            leading: Icon(icon),
            title: Text(title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(sheetContext);
              action();
            },
          );
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Your arcade')),
              choice('Classic levels', Icons.adjust, selectLevel),
              choice('Maze routes', Icons.route_rounded, selectMaze),
              choice('DAILY', Icons.today_outlined, showDaily),
              choice(
                'PRACTICE',
                Icons.touch_app,
                () => start(GameMode.practice),
              ),
              choice('GEAR SHOP', Icons.palette_outlined, showBallShop),
              choice(
                'Goals, friends & backup',
                Icons.emoji_events_outlined,
                showClub,
              ),
              choice('HOW TO PLAY', Icons.help_outline, showGuide),
            ],
          ),
        ),
      );
    },
  );

  Widget boardChrome() {
    if (tutorialActive &&
        tutorialStep == TutorialStep.classicPlay &&
        game.waitingForInput)
      return const SizedBox();
    if (game.waitingForInput && !(tutorialActive && tutorialStep.inInfinite)) {
      if (game.mode != GameMode.classic && !game.maze) return const SizedBox();
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 240,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('choose-level'),
                    onPressed: carouselMoving
                        ? null
                        : game.maze
                        ? selectMaze
                        : selectLevel,
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                    label: const Text('Choose Level'),
                  ),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: cream.withAlpha(220),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Level ${game.level} · ${game.maze ? game.mazeRun.name : ClassicLevels.definition(game.level).name}',
                        key: const ValueKey('board-level-name'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: AnimatedBuilder(
          animation: Listenable.merge([hud, backdrop]),
          builder: (context, _) {
            final color = game.infinite
                ? infiniteBoardInk(game, const Offset(110, 60))
                : chromeInk;
            if (game.infinite) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final sideWidth = math.min(72.0, constraints.maxWidth * .25);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        key: tutorialHeartsKey,
                        width: sideWidth,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Semantics(
                            key: const ValueKey('board-hearts'),
                            label: '${game.lives} of 3 hearts remaining',
                            excludeSemantics: true,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < 3; i++)
                                    Icon(
                                      i < game.lives
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      key: ValueKey('board-heart-$i'),
                                      size: 20,
                                      color: i < game.lives
                                          ? const Color(0xFFEF6958)
                                          : color.withAlpha(130),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: IgnorePointer(
                          key: tutorialScoreKey,
                          child: Column(
                            key: const ValueKey('board-hud'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${game.score}',
                                  key: const ValueKey('infinite-score'),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 30,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              Text(
                                '${game.survival.combo}×${game.survival.combo == InfiniteTuning.maxCombo ? ' MAX' : ''}',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (game.survival.noticeTime > 0)
                                Text(
                                  game.survival.notice,
                                  key: const ValueKey('infinite-pickup-notice'),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              if (game.survival.protected)
                                Text(
                                  game.survival.shield > 0
                                      ? 'SHIELD ${game.survival.shield.ceil()}s'
                                      : 'RECOVERY ${game.survival.recovery.ceil()}s',
                                  key: const ValueKey('protection-status'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: color, fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: sideWidth,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: IconButton.filledTonal(
                            key: const ValueKey('board-pause'),
                            tooltip: game.paused ? 'Resume' : 'Pause',
                            onPressed: pause,
                            style: IconButton.styleFrom(
                              backgroundColor: color.withAlpha(24),
                              foregroundColor: color,
                            ),
                            icon: Icon(
                              game.paused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              size: 22,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: IgnorePointer(
                    child: Container(
                      key: const ValueKey('board-hud'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (color == Colors.white
                                    ? Colors.black
                                    : Colors.white)
                                .withAlpha(45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  game.maze
                                      ? '${game.score}%'
                                      : '${game.score}',
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 21,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  game.scrolling
                                      ? '${game.metres}m'
                                      : game.merging
                                      ? 'TOP ${formatMergeNumber(game.mergeRun.highest)}'
                                      : formatRunTime(game.elapsed),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            game.infinite
                                ? 'PACE ${game.paceLevel} · ${game.survival.combo}×${game.survival.combo == InfiniteTuning.maxCombo ? ' MAX' : ''}'
                                : game.maze
                                ? 'ROUTE ${game.level}'
                                : game.merging
                                ? 'MERGE'
                                : game.practice
                                ? 'PRACTICE'
                                : 'L${game.level} · TARGET ${game.target.clamp(1, 10)}/10',
                            style: TextStyle(
                              color: color.withAlpha(210),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (game.merging)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: 240,
                                child: MergeStatus(run: game.mergeRun),
                              ),
                            ),
                          if (!game.practice)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Semantics(
                                key: const ValueKey('board-hearts'),
                                label:
                                    '${game.lives} of ${game.maze || game.merging ? 1 : 3} hearts remaining',
                                excludeSemantics: true,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (
                                        var i = 0;
                                        i < (game.maze || game.merging ? 1 : 3);
                                        i++
                                      )
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 4,
                                          ),
                                          child: Icon(
                                            i < game.lives
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            key: ValueKey('board-heart-$i'),
                                            size: 20,
                                            color: i < game.lives
                                                ? const Color(0xFFEF6958)
                                                : color.withAlpha(130),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (game.infinite && game.survival.protected)
                            Text(
                              game.survival.shield > 0
                                  ? 'SHIELD ${game.survival.shield.ceil()}s'
                                  : 'RECOVERY ${game.survival.recovery.ceil()}s',
                              key: const ValueKey('protection-status'),
                              style: TextStyle(color: color, fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const ValueKey('board-pause'),
                  tooltip: game.paused ? 'Resume' : 'Pause',
                  onPressed: pause,
                  style: IconButton.styleFrom(
                    backgroundColor: color.withAlpha(24),
                    foregroundColor: color,
                  ),
                  icon: Icon(
                    game.paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    size: 22,
                    color: color,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static const worldColors = [
    Color(0xFFE9E9DC),
    Color(0xFFF1E4C8),
    Color(0xFFD5E8E5),
    Color(0xFFE4E3F1),
    Color(0xFFF3DFD0),
  ];

  String worldTitle(int index) => switch (index) {
    0 => 'Infinite',
    1 => 'Classic',
    2 => 'Maze',
    _ => '2048 Merge',
  };

  String worldSubtitle(int index) => switch (index) {
    0 => 'NO FINISH LINE. FIND YOUR FLOW.',
    1 => 'Classic • Level ${worldLevel(index)}',
    2 => 'Maze • Level ${worldLevel(index)}',
    _ => 'SMALL NUMBERS. BIG POSSIBILITIES.',
  };

  String get startInstruction => switch (game.controlMode) {
    ControlMode.analog => 'Touch a joystick to play',
    ControlMode.oneFinger => 'Drag the thumb area to play',
    ControlMode.twoFinger => 'Move a platform end to play',
  };

  bool acceptsWorldSwipe(Offset global) {
    if (tutorialActive ||
        !game.waitingForInput ||
        returning ||
        !entrance.isDismissed ||
        carouselMoving ||
        ModalRoute.of(context)?.isCurrent != true)
      return false;
    final analog = analogKey.currentContext?.findRenderObject() as RenderBox?;
    if (game.analog && analog != null) {
      final point = analog.globalToLocal(global);
      if ((Offset.zero & analog.size).contains(point) &&
          (point.dx <= 106 || point.dx >= analog.size.width - 106))
        return false;
    }
    final board = boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (board == null) return true;
    final point = board.globalToLocal(global);
    if (!(Offset.zero & board.size).contains(point)) return true;
    if (game.oneFinger)
      return point.dy < board.size.height - OneFingerControls.height;
    if (game.analog) return true;
    final viewport = BoardViewport(board.size);
    for (final side in [0, 1]) {
      final pivot = viewport.project(
        Offset(
          side == 0 ? 20 : 340,
          game.screenY(side == 0 ? game.left : game.right),
        ),
      );
      if ((point.dx - pivot.dx).abs() <= 44 &&
          (point.dy - pivot.dy).abs() <= 48)
        return false;
    }
    return true;
  }

  Widget world(BuildContext context, int index) {
    final active = index == selectedMode;
    return AnimatedContainer(
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            worldColors[index].withAlpha(0),
            game.waitingForInput
                ? worldColors[index]
                : worldColors[index].withAlpha(0),
          ],
        ),
      ),
      child: active
          ? IgnorePointer(
              ignoring: carouselMoving,
              child: PivotBoard(
                key: boardKey,
                game: game,
                frame: frame,
                fillWidth: expansion,
                overlay: boardChrome(),
                showHint:
                    game.waitingForInput &&
                    !carouselMoving &&
                    !returning &&
                    entrance.isDismissed,
              ),
            )
          : Opacity(
              opacity: 1 - expansion,
              child: IgnorePointer(
                child: Column(
                  children: [
                    Expanded(
                      child: RepaintBoundary(
                        child: Image.asset(
                          modePreviewAsset(
                            arcadeModes[index],
                            worldLevel(index),
                          ),
                          key: ValueKey('mode-preview-$index'),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          cacheWidth: 180,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                    if (game.oneFinger)
                      const SizedBox(height: OneFingerControls.height),
                  ],
                ),
              ),
            ),
    );
  }

  /// Fixed header shortcut into the gear shop while selecting a mode.
  Widget shopButton() => Semantics(
    button: true,
    label: 'Gear shop',
    child: Tooltip(
      message: 'Gear shop',
      child: Material(
        key: tutorialShopKey,
        color: cream,
        shape: CircleBorder(side: BorderSide(color: ink.withAlpha(40))),
        elevation: 3,
        shadowColor: ink.withAlpha(90),
        child: InkWell(
          key: const ValueKey('board-shop'),
          customBorder: const CircleBorder(),
          onTap: carouselMoving ? null : showBallShop,
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.storefront_rounded, size: 22, color: ink),
          ),
        ),
      ),
    ),
  );

  Widget selectionHeader(double page) {
    final index = page.round().clamp(0, arcadeModes.length - 1);
    final distance = page - index;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'GILT',
                  style: label().copyWith(letterSpacing: 5, fontSize: 13),
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Daily prizes',
              onPressed: carouselMoving ? null : showDailyPrizes,
              icon: Badge(
                isLabelVisible: profile.dailyPrizes.canClaim(DateTime.now()),
                child: const Icon(Icons.redeem_rounded),
              ),
            ),
            if (tutorialActive &&
                game.waitingForInput &&
                !returning &&
                [
                  TutorialStep.levels,
                  TutorialStep.level1,
                  TutorialStep.classicPlay,
                ].contains(tutorialStep))
              IconButton.filledTonal(
                key: tutorialLevelsKey,
                tooltip: 'Classic levels',
                onPressed: selectLevel,
                icon: const Icon(Icons.grid_view_rounded),
              ),
            if (tutorialActive &&
                game.waitingForInput &&
                !returning &&
                tutorialStep == TutorialStep.dailyChallenge)
              IconButton.filledTonal(
                key: tutorialDailyKey,
                tooltip: 'Daily Challenge',
                onPressed: () {
                  skipTutorial();
                  showDaily();
                },
                icon: const Icon(Icons.today_outlined),
              ),
            if (game.waitingForInput && !returning) ...[
              shopButton(),
              const SizedBox(width: 8),
            ],
            IconButton(
              tooltip: 'Modes',
              onPressed: carouselMoving ? null : showModes,
              icon: const Icon(Icons.apps_rounded, size: 21),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: carouselMoving ? null : showSettings,
              icon: const Icon(Icons.tune_rounded, size: 21),
            ),
          ],
        ),
        Expanded(
          child: Transform.translate(
            offset: Offset(reduced ? 0 : distance * -28, 0),
            child: Opacity(
              opacity: reduced ? 1 : 1 - distance.abs() * .8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    worldTitle(index),
                    key: const ValueKey('selected-mode-title'),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: MediaQuery.sizeOf(context).height < 650
                          ? 28
                          : 34,
                      height: 1.05,
                      letterSpacing: -1.4,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    worldSubtitle(index),
                    key: const ValueKey('selected-mode-subtitle'),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget carouselFooter(double page) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: 'Previous mode',
        visualDensity: VisualDensity.compact,
        onPressed: selectedMode > 0 && !carouselMoving
            ? () => carouselKey.currentState?.select(selectedMode - 1)
            : null,
        icon: const Icon(Icons.chevron_left_rounded, size: 18),
      ),
      for (var index = 0; index < arcadeModes.length; index++)
        Semantics(
          label: '${worldTitle(index)}, ${index + 1} of ${arcadeModes.length}',
          selected: selectedMode == index,
          button: true,
          child: GestureDetector(
            key: ValueKey('mode-$index'),
            behavior: HitTestBehavior.opaque,
            onTap: carouselMoving
                ? null
                : () => carouselKey.currentState?.select(index),
            child: SizedBox(
              width: 24,
              height: 30,
              child: Center(
                child: Container(
                  width: 6 + 12 * (1 - (page - index).abs().clamp(0.0, 1.0)),
                  height: 6,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      ink.withAlpha(50),
                      ink,
                      1 - (page - index).abs().clamp(0.0, 1.0),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
      IconButton(
        tooltip: 'Next mode',
        visualDensity: VisualDensity.compact,
        onPressed: selectedMode < arcadeModes.length - 1 && !carouselMoving
            ? () => carouselKey.currentState?.select(selectedMode + 1)
            : null,
        icon: const Icon(Icons.chevron_right_rounded, size: 18),
      ),
    ],
  );

  Widget playScreen(BuildContext context) => Scaffold(
    body: ModeCarousel(
      key: carouselKey,
      selected: selectedMode,
      locked:
          tutorialActive ||
          !game.waitingForInput ||
          returning ||
          !entrance.isDismissed,
      expansion: expansion,
      controlInset: game.oneFinger ? OneFingerControls.height : 0,
      acceptSwipe: acceptsWorldSwipe,
      onMoving: (moving) => setState(() {
        carouselMoving = moving;
        game.inputLocked = moving;
      }),
      onSelected: (index) => setState(() {
        if (index != selectedMode) prepareWorld(index);
      }),
      worldBuilder: world,
      builder: (context, worlds, page) {
        final low = page.floor().clamp(0, 4), high = page.ceil().clamp(0, 4);
        final background = Color.lerp(
          worldColors[low],
          worldColors[high],
          page - page.floor(),
        )!;
        final ready =
            game.waitingForInput && !returning && entrance.isDismissed;
        final menuHeaderHeight =
            MediaQuery.sizeOf(context).height < 650 &&
                MediaQuery.textScalerOf(context).scale(10) <= 10
            ? 104.0
            : 144.0;
        final headerHeight = menuHeaderHeight * (1 - expansion);
        return ColoredBox(
          color: background,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (game.infinite)
                Opacity(
                  opacity: 1 - chromeOpacity,

                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: InfiniteBackdropPainter(
                        game,
                        reducedMotion: MediaQuery.disableAnimationsOf(context),
                        repaint: backdrop,
                      ),
                    ),
                  ),
                ),
              SafeArea(
                key: const ValueKey('arcade-stage'),
                child: Column(
                  children: [
                    if (headerHeight > .1)
                      SizedBox(
                        height: headerHeight,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minHeight: menuHeaderHeight,
                            maxHeight: menuHeaderHeight,
                            child: IgnorePointer(
                              ignoring: !ready,
                              child: ExcludeSemantics(
                                excluding: !ready,
                                child: Opacity(
                                  opacity: chromeOpacity,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 4,
                                    ),
                                    child: selectionHeader(page),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 12 * (1 - expansion),
                        ),
                        child: worlds,
                      ),
                    ),
                    SizedBox(
                      height: 34 * (1 - expansion),
                      child: OverflowBox(
                        minHeight: 34,
                        maxHeight: 34,
                        alignment: Alignment.bottomCenter,
                        child: IgnorePointer(
                          ignoring: !ready,
                          child: ExcludeSemantics(
                            excluding: !ready,
                            child: Opacity(
                              opacity: chromeOpacity,

                              child: carouselFooter(page),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (game.analog)
                      SizedBox(
                        key: analogKey,
                        height: (MediaQuery.sizeOf(context).height * .19).clamp(
                          104.0,
                          140.0,
                        ),
                        child: IgnorePointer(
                          ignoring: carouselMoving,
                          child: LayoutBuilder(
                            builder: (context, bounds) => Stack(
                              fit: StackFit.expand,
                              children: [
                                AnalogControls(game: game, frame: frame),
                                if (ready && !carouselMoving)
                                  ControlHint(
                                    anchors: [
                                      Offset(62, bounds.maxHeight / 2),
                                      Offset(
                                        bounds.maxWidth - 62,
                                        bounds.maxHeight / 2,
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!returning && (game.paused || game.finished))
                SafeArea(
                  key: const ValueKey('run-overlay'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: boardOverlay(),
                  ),
                ),
              if (game.infinite && !game.waitingForInput ||
                  tutorialActive && tutorialStep.inInfinite)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 70,
                  right: 24,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: hud,
                      builder: (context, _) => Container(
                        key: tutorialCoinsKey,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cream.withAlpha(220),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.toll, size: 15, color: orange),
                            const SizedBox(width: 4),
                            AnimatedSwitcher(
                              key: const ValueKey('run-coins'),
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 260),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: Text(
                                '${profile.wallet}',
                                key: ValueKey(profile.wallet),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              IgnorePointer(
                child: RepaintBoundary(
                  key: effectsKey,
                  child: CustomPaint(
                    painter: HeartLossPainter(
                      heartEffects,
                      reducedMotion: MediaQuery.disableAnimationsOf(context),
                      repaint: frame,
                    ),
                  ),
                ),
              ),
              if (tutorialOverlay() case final overlay?) overlay,
            ],
          ),
        );
      },
    ),
  );
  Widget status() => SizedBox(
    height: 20,
    child: Center(
      child: Text(
        game.message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: game.phase == GamePhase.sinking && !game.lastSuccess
              ? orange
              : chromeInk.withAlpha(190),
        ),
      ),
    ),
  );

  Widget primary(String text, VoidCallback action, {String? trailing}) =>
      SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: action,
          style: FilledButton.styleFrom(
            backgroundColor: ink,
            foregroundColor: cream,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(text, style: label(cream)),
                ),
              ),
              const SizedBox(width: 8),
              trailing != null
                  ? Text(trailing, style: label(brass))
                  : const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      );

  Widget boardOverlay() => game.maze && game.finished
      ? LaserMazeResult(
          game: game,
          newBest: newBest,
          onRetry: () => start(game.mode),
          onNext: game.level < LaserMazeRoute.count
              ? () {
                  profile.mazeLevel = game.level + 1;
                  unawaited(profile.save());
                  start(GameMode.laserMaze);
                }
              : null,
          onLevels: selectMaze,
          onHome: home,
        )
      : game.merging && game.finished
      ? MergeResult(
          run: game.mergeRun,
          newBest: newBest,
          onRetry: () => start(GameMode.merge2048),
          onHome: home,
        )
      : briefing
      ? FinaleBriefing(game: game, onPlay: pause)
      : Container(
          decoration: BoxDecoration(
            color: ink.withAlpha(235),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      game.paused
                          ? Icons.pause_circle_outline
                          : game.won
                          ? Icons.workspace_premium_outlined
                          : Icons.refresh_rounded,
                      size: 43,
                      color: brass,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      game.paused
                          ? 'Take a breath.'
                          : game.won
                          ? (game.merging
                                ? '2048. You made it.'
                                : 'Pure precision.')
                          : 'So close.\nGo again.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        color: cream,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (game.finished) ...[
                      Text(
                        newBest
                            ? 'NEW PERSONAL BEST'
                            : game.practice
                            ? 'PRACTICE COMPLETE'
                            : game.infinite
                            ? 'INFINITE RUN COMPLETE'
                            : 'RUN COMPLETE',
                        style: label(brass),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${game.score}',
                        style: const TextStyle(
                          fontSize: 42,
                          fontFamily: 'monospace',
                          color: cream,
                        ),
                      ),
                      Text(
                        !game.won || game.merging
                            ? (game.infinite
                                  ? '${game.metres}m · Best combo x${game.survival.bestCombo}\n${game.message}  ${game.coinsCollected} coins saved.'
                                  : game.message)
                            : '${game.completed}/10 holes  •  ${game.bestStreak} best streak',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB5C5BB),
                        ),
                      ),
                      if (!game.infinite &&
                          !game.practice &&
                          !game.merging &&
                          !game.maze)
                        MasteryResult(
                          game: game,
                          record: game.daily
                              ? profile.dailyRecord(
                                  game.dailyKey,
                                  game.controlMode,
                                )
                              : profile.levelRecord(
                                  game.level,
                                  game.controlMode,
                                ),
                          unlocks: newUnlocks,
                        ),
                    ] else
                      const Text(
                        'Your run is right where you left it.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFB5C5BB),
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: brass,
                          foregroundColor: ink,
                        ),
                        onPressed: game.paused
                            ? pause
                            : () {
                                if (game.won &&
                                    game.mode == GameMode.classic &&
                                    game.level < ClassicLevels.count) {
                                  if (!profile.selectClassicLevel(
                                    game.level + 1,
                                  )) {
                                    unawaited(selectLevel());
                                    return;
                                  }
                                  unawaited(profile.save());
                                }
                                start(game.mode, challengeDate: game.dailyDate);
                              },
                        child: Text(
                          game.paused
                              ? 'RESUME RUN'
                              : game.won &&
                                    game.mode == GameMode.classic &&
                                    game.level < ClassicLevels.count
                              ? profile.isClassicLevelUnlocked(game.level + 1)
                                    ? 'NEXT LEVEL'
                                    : 'EARN MORE STARS'
                              : 'ONE MORE RUN',
                          style: label(),
                        ),
                      ),
                    ),
                    if (game.won &&
                        game.mode == GameMode.classic &&
                        game.level < ClassicLevels.count &&
                        !profile.isClassicLevelUnlocked(game.level + 1))
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Level ${game.level + 1} needs ${ClassicLevels.requiredStars(game.level + 1)} stars · You have ${profile.totalStars}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: cream, fontSize: 12),
                        ),
                      ),
                    if (game.won && !game.practice)
                      TextButton(
                        onPressed: () =>
                            start(game.mode, challengeDate: game.dailyDate),
                        child: Text('RETRY THIS BOARD', style: label(brass)),
                      ),
                    // A paused run can be dropped for a fresh one in any mode.
                    if (game.paused)
                      TextButton(
                        onPressed: () =>
                            start(game.mode, challengeDate: game.dailyDate),
                        child: Text('RESTART RUN', style: label(brass)),
                      ),
                    if (tutorialActive)
                      TextButton(
                        onPressed: skipTutorial,
                        child: const Text('Skip Tutorial'),
                      ),
                    TextButton(
                      onPressed: home,
                      child: Text(
                        'BACK TO CLUB',
                        style: label(cream.withAlpha(180)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

  Future<void> showGuide() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: cream,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A game of balance.',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 20),
              guideRow(
                '01',
                'Two thumbs. One bar.',
                'Drag either end of the platform up or down. Use two fingers to move both ends. Release to hold its screen position.',
              ),
              guideRow(
                '02',
                'Follow the light.',
                'Tilt to roll. Lift both ends to climb. Sink the ball into the glowing numbered hole; every other hole is a trap.',
              ),
              guideRow(
                '03',
                'Make it a perfect ten.',
                'Each target returns the bar to the bottom. Clear all ten with three balls. Consecutive targets build a multiplier; faster climbs earn bonus points.',
              ),
              guideRow(
                '04',
                'Go beyond ten.',
                'Infinite begins with three hearts. Laser maze sections arrive from time to time: the traps stop and wide laser walls come down instead, so steer through their openings. A hit costs a heart and resets your combo; the ball and platform blink for 2.5 seconds of protection while you keep steering from the same position. Gold crystals build combos up to x10; violet and midnight tiers build toward electric cyan at x9 and a golden maximum at x10. Blue shields protect for 10 seconds. Red-and-blue magnets collect nearby coins, combo crystals, shields and hearts for 12 seconds. Rare hearts restore a life. Keep steering to escape the rising red floor.',
              ),
              const Text(
                'Desktop: W / S = left end. ↑ / ↓ = right end. Esc = pause.',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
              guideRow(
                '05',
                'Watch the warnings.',
                'Infinite starts with open spaces and builds difficulty with height. Warning holes unlock at 180m, moving holes at 350m, lasers at 600m and platform gaps at 900m. Move away from red warnings before they activate. In late Infinite encounters, orbiting holes follow a marked circle.',
              ),
              guideRow(
                '06',
                'Stay out of the web.',
                'Classic levels 31–50 have slow patrolling spiders. Enter a marked territory and its spider chases you. Contact ends the run immediately. Each successful target resets the spiders. In Infinite, spiders move slowly and fire aimed webs: move away from the marked line before the slow shot arrives. Web hits cost a heart; shields block them.',
              ),
              const SizedBox(height: 20),
              guideRow(
                '07',
                'Three ways to master it.',
                'Earn a star for finishing, one for a finish without misses, and one for beating the active-time target in the HUD. Pauses and ball resets do not count. Stars and records are saved separately for each control mode.',
              ),
              guideRow(
                '08',
                'Take the detour.',
                'Classic and Daily brass coins are worth 250 points. Infinite coins save to your local wallet immediately. Open the Gear Shop for balls and platforms that add Infinite point multipliers. Selected balls also have permanent magnets with different collection ranges in Infinite; handling stays the same. Each coin can be collected once. Classic stars unlock cabinet styles with identical handling.',
              ),
              guideRow(
                '09',
                'Return for the daily.',
                'The daily board changes at midnight UTC. Retry its fixed layout to improve your local record. Infinite pace rises smoothly from x1 to x5, increasing speed, distance points and obstacle frequency. Every run starts gently at x1; pace rises gradually over longer distances. Combo crystals award 50 × combo × pace points. Missing a crystal keeps your combo; losing a heart resets it.',
              ),
              guideRow(
                '10',
                'Follow the laser road.',
                'Laser Maze uses your selected controls, including responsive Vertical Analog. Follow arrows up, sideways and down. Gold shortcuts are narrow; wide detours reconnect. In Endless, bugs patrol outside the road. Amber circles warn for two seconds; red areas overlapping the road catch the ball. The center of every route stays clear.',
              ),
              primary('TRY PRACTICE', () {
                Navigator.pop(context);
                start(GameMode.practice);
              }),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  replayTutorial();
                },
                child: const Text('Replay Tutorial'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget guideRow(String number, String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(number, style: label(orange)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: ink.withAlpha(175),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> showClub() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClubScreen(
          profile: profile,
          recorder: playtest,
          onPlay: (mode, level, date) {
            if (mode == GameMode.classic) profile.classicLevel = level;
            unawaited(profile.save());
            start(mode, challengeDate: date);
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> showSettings() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: cream,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .9,
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, update) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Make yourself at home.',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                TextButton.icon(
                  key: const ValueKey('replay-tutorial'),
                  onPressed: () {
                    Navigator.pop(context);
                    replayTutorial();
                  },
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Replay Tutorial'),
                ),
                const SizedBox(height: 14),
                ControlOptions(
                  value: profile.controlMode,
                  onChanged: (mode) {
                    update(() => profile.controlMode = mode);
                    setState(() {
                      game.setControlMode(mode);
                    });
                    unawaited(profile.save());
                  },
                ),
                const SizedBox(height: 8),
                SensitivitySetting(
                  id: 'analog-sensitivity',
                  title: 'Vertical Analog sensitivity',
                  value: profile.analogSensitivity,
                  onChanged: (value) {
                    update(() => profile.analogSensitivity = value);
                    game.analogSensitivity = value;
                    game.clearInput();
                  },
                  onChangeEnd: () => unawaited(profile.save()),
                ),
                SensitivitySetting(
                  id: 'two-finger-sensitivity',
                  title: 'Two-Finger sensitivity',
                  value: profile.twoFingerSensitivity,
                  onChanged: (value) {
                    update(() => profile.twoFingerSensitivity = value);
                    game.twoFingerSensitivity = value;
                    game.clearInput();
                  },
                  onChangeEnd: () => unawaited(profile.save()),
                ),
                const Text(
                  '0 = no touch movement · 1 = full response. Lower values make smaller adjustments. Sensitivity does not add delay.',
                  style: TextStyle(fontSize: 11, height: 1.4),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sound Effects'),
                  subtitle: Text(profile.sound ? 'ON' : 'OFF'),
                  value: profile.sound,
                  onChanged: (v) {
                    update(() => profile.sound = v);

                    unawaited(profile.save());
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Music'),
                  subtitle: Text(profile.music ? 'ON' : 'OFF'),
                  value: profile.music,
                  onChanged: (v) {
                    update(() => profile.music = v);
                    syncMusic();
                    unawaited(profile.save());
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Haptic feedback'),
                  value: profile.haptics,
                  onChanged: (v) {
                    update(() => profile.haptics = v);
                    unawaited(profile.save());
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Classic best ${profile.best}  •  ${profile.runs} runs',
                  style: label(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Infinite best ${profile.infiniteBest}m',
                  style: label().copyWith(fontSize: 9, letterSpacing: 1),
                ),
                if (!profile.available)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Local storage is unavailable. Records will last for this session.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'GILT / No rush. Just precision.',
                  style: TextStyle(fontSize: 11),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showBallShop();
                  },
                  icon: const Icon(Icons.palette_outlined),
                  label: const Text('Shop'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showClub();
                  },
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('Goals, friends & backup'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
