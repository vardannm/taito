import 'playtest_recorder.dart';
import 'rewarded_revive_ads.dart';
import 'ad_consent.dart';
import 'app_analytics.dart';
import 'privacy_policy.dart';
import 'music_credits.dart';
import 'infinite_music.dart';
export 'pivot_board.dart';
import 'pivot_board.dart';
import 'club.dart';
import 'control_options.dart';
import 'settings_sheet.dart';
import 'run_coin_summary.dart';
import 'infinite_painter.dart';
import 'ball_shop.dart';
import 'ball_world.dart';
import 'daily_prize_sheet.dart';
import 'achievement_sheet.dart';
import 'infinite_progress.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'board_painter.dart';
import 'game.dart';
import 'menu_design.dart';
import 'premium_menu.dart';
import 'shop_design.dart';
import 'enemy_sounds.dart';
import 'levels.dart';
import 'level_picker.dart';
import 'profile.dart';
import 'onboarding.dart';
import 'tutorial_spotlight.dart';
import 'rewards.dart';
import 'mastery_widgets.dart';
import 'analog_controls.dart';
import 'tilt_lift_controls.dart';
import 'merge_widgets.dart';
import 'merge.dart';
import 'mode_carousel.dart';
import 'mode_world_preview.dart';
import 'heart_loss_effect.dart';
import 'control_hint.dart';
import 'control_glass.dart';
import 'one_finger_controls.dart';
import 'boot_splash.dart';
import 'responsive_layout.dart';
import 'infinite_coin_chip.dart';
import 'infinite_boss.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Full screen: hides the status bar (time, battery) and Android's nav bar;
  // a swipe from the edge shows them briefly. SafeAreas still avoid the notch.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: menuBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  // TEMPORARY store-screenshot build: every level open and at least 300,000
  // coins. Remove both before release.
  final profile = PlayerProfile(temporaryLevelAccess: true);
  await profile.load();
  if (profile.wallet < 300000) {
    profile.wallet = 300000;
    await profile.saveEconomy();
  }
  final analytics = await AppAnalytics.initialize();
  final adConsent = AdConsent();
  runApp(
    ArcadeApp(
      profile: profile,
      analytics: analytics,
      reviveAds: GoogleRewardedReviveAds(
        canRequestAds: adConsent.canRequestAds,
      ),
      adConsent: adConsent,
      intro: true,
    ),
  );
}

class ArcadeApp extends StatelessWidget {
  const ArcadeApp({
    super.key,
    required this.profile,
    this.analytics,
    this.reviveAds,
    this.adConsent,
    this.intro = false,
  });
  final PlayerProfile profile;
  final AppAnalytics? analytics;
  final RewardedReviveAds? reviveAds;
  final AdConsent? adConsent;

  /// The boot animation belongs to the real launch only; tests pump this app
  /// straight into the menu rather than waiting an intro out.
  final bool intro;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Rollrise: Ball Balance',
    theme: arcadeMenuTheme(),
    // Wrapping the navigator keeps the intro above anything the menu opens.
    builder: intro
        ? (context, child) => GiltIntroGate(child: child ?? const SizedBox())
        : null,
    home: GameScreen(
      profile: profile,
      analytics: analytics,
      reviveAds: reviveAds,
      adConsent: adConsent,
    ),
  );
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.profile,
    this.analytics,
    this.reviveAds,
    this.adConsent,
  });
  final PlayerProfile profile;
  final AppAnalytics? analytics;
  final RewardedReviveAds? reviveAds;
  final AdConsent? adConsent;
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
  final enemySounds = EnemySoundDirector();
  final playtest = PlaytestRecorder();
  late final analytics = widget.analytics ?? AppAnalytics();
  late final reviveAds = widget.reviveAds ?? const UnavailableReviveAds();
  bool reviveDeclined = false, adBusy = false;
  String? reviveError;
  String? coinDoubleError;
  bool get offeringRevive =>
      game.canReviveInfinite && reviveAds.supported && !reviveDeclined;
  bool get offeringCoinDouble =>
      reviveAds.supported && profile.canDoubleInfiniteCoins(game);
  final touch = [0.0, 0.0];
  final keyboard = [0.0, 0.0];
  late final Ticker ticker;
  Duration? previous;
  double accumulator = 0;
  Timer? resumeTimer;
  int resumeSeconds = 0;
  bool recorded = false, newBest = false, briefing = false;
  TutorialRun? tutorialRun;
  bool tutorialSheetOpen = false;
  final shopOriginKey = GlobalKey();
  final tutorialLevelsKey = GlobalKey();
  final tutorialDailyKey = GlobalKey();
  final tutorialPlayKey = GlobalKey();
  final tutorialHeartsKey = GlobalKey();
  final tutorialScoreKey = GlobalKey();
  final tutorialCoinsKey = GlobalKey();
  bool get tutorialActive => !profile.tutorialSeen && profile.tutorial.active;
  TutorialStep get tutorialStep => profile.tutorial.step;

  /// Lessons play on the opened board. Between them the tutorial guides the
  /// ordinary menu, where only Play opens the board.
  bool get tutorialBoard => tutorialActive && !entrance.isDismissed;

  /// The Levels lessons point at Choose Level, which only Classic shows.
  bool get tutorialOnLevels =>
      tutorialActive &&
      const [
        TutorialStep.levels,
        TutorialStep.level1,
        TutorialStep.classicPlay,
      ].contains(tutorialStep);

  void tutorialChanged() {
    unawaited(profile.saveTutorial());
    restoreReplayControl();
    if (mounted) setState(() {});
  }

  /// Keep the player's choice while the replay picks its starting controls.
  /// The current layout's control availability still applies.
  ControlMode? controlBeforeReplay;

  void restoreReplayControl() {
    final mode = controlBeforeReplay;
    if (mode == null || tutorialActive) return;
    controlBeforeReplay = null;
    profile.controlMode = mode;
    unawaited(profile.save());
  }

  void advanceTutorial(TutorialStep step) {
    profile.tutorial.step = step;
    tutorialChanged();
  }

  void skipTutorial() {
    // The tutorial opens its boards full-screen before the first move. Once
    // it ends, nothing can start that board, so hand back to the menu.
    final unstarted = game.waitingForInput && !entrance.isDismissed;
    unawaited(profile.completeTutorial());
    game.endTutorialCourse();
    tutorialRun = null;
    restoreReplayControl();
    setState(() {});
    if (unstarted) unawaited(home());
  }

  void replayTutorial() {
    unawaited(profile.replayTutorial());
    controlBeforeReplay ??= profile.preferredControlMode;
    profile.controlMode = ControlMode.oneFinger;
    unawaited(profile.save());
    setState(() {
      // Open the board first, so the lesson board accepts the first touch.
      entrance.value = 1;
      prepareInfinite();
    });
  }

  bool readyRetry = false;

  /// TEMPORARY store-screenshot tool: hides the pause menu over the frozen
  /// run until the next tap. Remove before release.
  bool screenshotMode = false;
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
  double bottomControlHeight(BuildContext context) => game.bottomControls
      ? (MediaQuery.sizeOf(context).height * .19).clamp(104.0, 140.0)
      : 0;

  BoardViewport boardViewport(Size size) => BoardViewport.forGame(
    size,
    game,
    fillWidth: expansion,
    bottomInset: (boardKey.currentWidget as PivotBoard?)?.bottomInset,
  );
  int selectedMode = 0;
  bool carouselMoving = false;
  PlayerProfile get profile => widget.profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.adConsent?.initialize());
    });
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
    if (tutorialActive &&
        (tutorialStep.inInfinite || tutorialStep == TutorialStep.classicPlay))
      entrance.value = 1;
    if (tutorialOnLevels) {
      prepareWorld(1);
    } else {
      prepareInfinite();
    }
    game.onInputStarted = () {
      tutorialRun?.configure();
      analytics.startRun(game);
      if (game.mode == GameMode.classic) profile.classicLevel = game.level;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    profile.applyControlLayout(
      shortestSide: MediaQuery.sizeOf(context).shortestSide,
    );
    if (profile.applyInitialControlDefault(
      shortestSide: MediaQuery.sizeOf(context).shortestSide,
    )) {
      unawaited(profile.save());
    }
    if (game.controlMode != profile.controlMode) {
      clearControls();
      game.setControlMode(profile.controlMode);
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
    final viewport = boardViewport(board.size);
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
        '${game.phase}/${game.target}/${game.lives}/${game.inputEpoch}/$recorded/${game.boss?.phase}';
    final enemyCues = <EnemyCue>{};
    while (accumulator >= 1 / 120) {
      game.step(1 / 120);
      enemyCues.addAll(enemySounds.capture(game));
      tutorialRun?.tick(1 / 120);
      accumulator -= 1 / 120;
    }
    if (game.lives < observedLives) spawnHeartLoss();
    syncMusic();
    for (final cue in enemyCues) {
      unawaited(feedback.playEnemy(cue));
    }
    observedLives = game.lives;
    // Feedback (including a lost heart) must not invalidate held input.
    // Only simulation transitions that actually clear input release keys.
    if (game.inputEpoch != inputEpoch) {
      touch.fillRange(0, 2, 0);
      keyboard.fillRange(0, 2, 0);
    }
    profile.bankLevelStar(game);
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
    if (!offeringRevive) recordFinalResult();
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
      // Redraw the coin chip through its short pickup animation only.
      game.lastCoinAge < InfiniteCoinChip.popSeconds
          ? (game.lastCoinAge * 60).floor()
          : -1,
      game.coins.length,
      game.levelStarCollected,
      game.merging ? game.mergeRun.highest : 0,
    );
    backdrop.value = (game.survival.visualCombo * 64).round();
    frame.value++;
    if (game.finished && heartEffects.isEmpty) ticker.stop();
    if (before !=
        '${game.phase}/${game.target}/${game.lives}/${game.inputEpoch}/$recorded/${game.boss?.phase}')
      setState(() {});
  }

  void recordFinalResult() {
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
        newBest = profile.recordResult(game);
        unawaited(profile.save());
      }
    }
  }

  void declineRevive() {
    if (adBusy) return;
    setState(() {
      reviveDeclined = true;
      reviveError = null;
      recordFinalResult();
    });
  }

  Future<void> watchReviveAd() async {
    if (!offeringRevive || adBusy) return;
    final serial = game.runSerial;
    setState(() {
      adBusy = true;
      reviveError = null;
    });
    ticker.stop();
    clearControls();
    syncMusic();
    ReviveAdResult result;
    try {
      result = await reviveAds.show();
    } catch (_) {
      result = ReviveAdResult.unavailable;
    }
    if (!mounted) return;
    if (game.runSerial != serial) {
      setState(() => adBusy = false);
      return;
    }
    setState(() {
      adBusy = false;
      if (result == ReviveAdResult.earned && game.reviveInfinite()) {
        reviveDeclined = true;
        observedLives = game.lives;
        heartEffects.clear();
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
          game.setPaused(true);
        } else {
          runTicker();
        }
        frame.value++;
      } else {
        reviveError = result == ReviveAdResult.dismissed
            ? 'Finish watching the ad to earn your extra heart.'
            : 'No ad available right now. Try again or end the run.';
      }
    });
    syncMusic();
  }

  Future<void> watchCoinDoubleAd() async {
    if (!offeringCoinDouble || adBusy) return;
    final rewardedGame = game;
    final serial = game.runSerial;
    setState(() {
      adBusy = true;
      coinDoubleError = null;
      reviveDeclined = true;
      reviveError = null;
      recordFinalResult();
    });
    ticker.stop();
    clearControls();
    syncMusic();
    ReviveAdResult result;
    try {
      result = await reviveAds.show();
    } catch (_) {
      result = ReviveAdResult.unavailable;
    }
    if (!mounted) return;
    if (!identical(game, rewardedGame) || game.runSerial != serial) {
      setState(() => adBusy = false);
      return;
    }
    setState(() {
      adBusy = false;
      if (result == ReviveAdResult.earned) {
        profile.doubleInfiniteCoins(game);
      } else {
        coinDoubleError = result == ReviveAdResult.dismissed
            ? 'Finish watching the ad to double your coins.'
            : 'No ad available right now. Try again or keep your coins.';
      }
    });
    syncMusic();
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
    if ((!tutorialBoard && !playArmed && game.waitingForInput) ||
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

  ControlMode controlForMode(GameMode mode) => profile.controlMode;

  void start(GameMode mode, {DateTime? challengeDate}) => setState(() {
    if (adBusy) return;
    if (game.finished) recordFinalResult();
    reviveDeclined = false;
    reviveError = null;
    coinDoubleError = null;
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
      "control": controlForMode(mode).name,
      "level": profile.classicLevel,
      "retry":
          game.finished &&
          game.mode == mode &&
          (mode != GameMode.classic || profile.classicLevel == game.level) &&
          (mode != GameMode.daily ||
              DailyChallenge.key(challengeDate ?? DateTime.now()) ==
                  game.dailyKey),
    });
    clearControls();
    recorded = newBest = false;
    game.setControlMode(controlForMode(mode));
    game.cabinet = profile.cabinet;
    profile.applySurvivalUpgrades(game);
    game.cosmetic = profile.selectedBall;
    game.platformStyle = profile.selectedPlatform;
    game.cabinet = profile.cabinet;
    game.haloJoystick = profile.haloJoystick;
    game.levelStarAlreadyOwned = profile.hasCollectedLevelStar(
      profile.classicLevel,
    );
    profile.applyInfiniteStart(game, tutorial: tutorialActive);
    game.start(
      gameMode: mode,
      levelNumber: profile.classicLevel,
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
    final originBox =
        tutorialLevelsKey.currentContext?.findRenderObject() as RenderBox?;
    final viewport = MediaQuery.sizeOf(context);
    final origin = originBox != null && originBox.hasSize
        ? originBox.localToGlobal(Offset.zero) & originBox.size
        : Rect.fromCenter(
            center: Offset(viewport.width / 2, viewport.height - 48),
            width: 48,
            height: 48,
          );
    await Navigator.of(context).push<void>(
      ShopRevealRoute(
        name: '/levels',
        origin: origin,
        reducedMotion: MediaQuery.disableAnimationsOf(context),
        builder: (context) => SafeArea(
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
            allLevelsUnlocked: profile.temporaryLevelAccess,
            controlMode: profile.preferredControlMode,
            haloJoystick: profile.haloJoystick,
            recordForControl: (number, mode) =>
                profile.levelRecord(number, mode),
            onControlChanged: (choice) {
              final mode = profile.temporaryLevelAccess
                  ? choice
                  : choice.supportedMode;
              setState(() {
                if (mode == ControlMode.oneFinger &&
                    !profile.oneFingerPadAvailable) {
                  profile.haloJoystick = true;
                }
                profile.controlMode = mode;
                game.haloJoystick = profile.haloJoystick;
                game.setControlMode(profile.controlMode);
              });
              unawaited(profile.save());
            },
            records: {
              for (var i = 1; i <= ClassicLevels.count; i++)
                i: profile.levelRecord(i, controlForMode(GameMode.classic)),
            },
            controlLabel: controlForMode(GameMode.classic).label,
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

  Future<void> showMerge() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: menuBackground,
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
                'NUMBER MERGE',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Steer the solid head ball into numbers. Smaller balls trail below it from largest to smallest, following your turns like a snake. Matching values combine anywhere in the snake and can cascade into one bigger ball.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Collect equal or smaller numbers with the head ball. Touching a larger number ends the run: dodge the red rings! The first gate arrives at ${MergeRun.gateInterval} score. After clearing it, earn at least ${MergeRun.gateInterval} fresh points for the next; this gap grows with your main ball. Gates scale with your ball and at least double each time. Your main ball must be strictly greater than its number to pass. Matching values merge anywhere in the snake. Keep merging to reach higher numbers.',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'BEST ${profile.mergeBest}  ·  HIGHEST ${formatMergeNumber(profile.mergeHighest)}',
                        style: label(menuGold),
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
                  child: const Text('PLAY MERGE'),
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
      backgroundColor: menuBackground,
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

  Future<void> showAchievements() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: menuBackground,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .85,
        child: AchievementSheet(profile: profile),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> showDailyPrizes() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: menuBackground,
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
    final originBox =
        shopOriginKey.currentContext?.findRenderObject() as RenderBox?;
    final viewport = MediaQuery.sizeOf(context);
    final origin = originBox != null && originBox.hasSize
        ? originBox.localToGlobal(Offset.zero) & originBox.size
        : Rect.fromCenter(
            center: Offset(48, viewport.height - 48),
            width: 48,
            height: 48,
          );
    await Navigator.of(context).push<void>(
      ShopRevealRoute(
        origin: origin,
        reducedMotion: MediaQuery.disableAnimationsOf(context),
        builder: (_) => BallShop(
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
        profile.applySurvivalUpgrades(game);
        game.cosmetic = profile.selectedBall;
        game.platformStyle = profile.selectedPlatform;
        game.cabinet = profile.cabinet;
        if (game.waitingForInput) {
          prepareWorld(tutorialOnLevels ? 1 : selectedMode);
        }
      });
  }

  /// Infinite runs to a loop; every other screen is quiet. Pausing
  /// holds the track rather than restarting it.
  void syncMusic() {
    feedback.setEnemyEffectsEnabled(
      profile.sound &&
          game.started &&
          game.phase == GamePhase.playing &&
          !game.paused &&
          !game.waitingForInput &&
          !returning,
    );
    final wants =
        InfiniteMusic.bundled &&
        game.infinite &&
        profile.music &&
        game.started &&
        !game.finished;
    unawaited(
      feedback.updateMusic(
        track: wants ? InfiniteMusic.asset : null,
        playing: !game.paused && !game.waitingForInput && !returning,
        playbackSession: game.runSerial,
        playbackRate: game.infinite
            ? InfiniteMusic.rateFor(seconds: game.elapsed, pace: game.pace)
            : 1,
      ),
    );
  }

  void pause() => setState(() {
    briefing = false;
    clearControls();
    if (resumeSeconds > 0) {
      cancelResumeCountdown();
      return;
    }
    if (game.paused && (game.infinite || game.merging)) {
      resumeSeconds = 3;
      resumeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          resumeSeconds--;
          if (resumeSeconds == 0) {
            cancelResumeCountdown();
            clearControls();
            game.setPaused(false);
            syncMusic();
            runTicker();
          }
        });
      });
      return;
    }
    game.setPaused(!game.paused);
    syncMusic();
    if (game.paused) {
      ticker.stop();
    } else {
      runTicker();
    }
  });

  void cancelResumeCountdown() {
    resumeTimer?.cancel();
    resumeTimer = null;
    resumeSeconds = 0;
  }

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
    _ => 1,
  };

  void prepareWorld(int index, {bool retry = false}) {
    if (adBusy) return;
    cancelResumeCountdown();
    if (game.finished) recordFinalResult();
    screenshotMode = false;
    reviveDeclined = false;
    reviveError = null;
    coinDoubleError = null;
    analytics.selectMode(arcadeModes[index]);
    ticker.stop();
    previous = null;
    accumulator = 0;
    heartEffects.clear();
    carouselKey.currentState?.jumpTo(index);
    carouselMoving = false;
    selectedMode = index;
    readyRetry = retry;
    playArmed = false;
    clearControls();
    recorded = newBest = briefing = false;
    game.setControlMode(controlForMode(arcadeModes[index]));
    game.cabinet = profile.cabinet;
    profile.applySurvivalUpgrades(game);
    game.cosmetic = profile.selectedBall;
    game.platformStyle = profile.selectedPlatform;
    game.cabinet = profile.cabinet;
    game.haloJoystick = profile.haloJoystick;
    game.levelStarAlreadyOwned = profile.hasCollectedLevelStar(
      worldLevel(index),
    );
    profile.applyInfiniteStart(game, tutorial: tutorialActive);
    game.start(
      gameMode: arcadeModes[index],
      levelNumber: worldLevel(index),
      waitForInput: true,
    );
    game.inputLocked = !tutorialBoard;
    tutorialRun = tutorialActive && tutorialStep.inInfinite && game.infinite
        ? TutorialRun(game, profile.tutorial, tutorialChanged)
        : null;
    tutorialRun?.configure();
    observedLives = game.lives;
    syncMusic();
    frame.value++;
  }

  Future<void> home() async {
    if (returning || adBusy) return;
    if (game.finished) recordFinalResult();
    profile.bankLevelStar(game);
    profile.bankCoins(game);
    final index = arcadeModes.indexOf(game.mode);
    setState(() {
      returning = true;
      cancelResumeCountdown();
      clearControls();
      game.setPaused(true);
      ticker.stop();
      heartEffects.clear();
    });
    syncMusic();
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
      prepareWorld(
        tutorialOnLevels
            ? 1
            : index < 0
            ? 0
            : index,
      );
      returning = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // The OS may end the process while in the background.
      unawaited(
        game.finished && offeringRevive && !adBusy
            ? profile.saveProvisionalInfinite(game)
            : profile.save(),
      );
    }
    if (state != AppLifecycleState.resumed && game.started && !game.finished) {
      unawaited(profile.saveTutorial());
      if (game.waitingForInput) {
        clearControls();
        return;
      }
      setState(() {
        cancelResumeCountdown();
        clearControls();
        game.setPaused(true);
        ticker.stop();
      });
    }
    syncMusic();
  }

  @override
  void dispose() {
    cancelResumeCountdown();
    game.onInputStarted = null;
    if (game.infinite && game.finished) recordFinalResult();
    reviveAds.dispose();
    profile.bankLevelStar(game);
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
  Color get chromeInk => infiniteBoardInk(game, const Offset(180, 500));

  TextStyle label([Color color = ink]) => TextStyle(
    fontSize: 10,
    letterSpacing: 1.8,
    fontWeight: FontWeight.w700,
    color: color,
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: backLeavesApp,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) handleBack();
    },
    child: playScreen(context),
  );

  /// System back leaves the app only from the mode menu.
  bool get backLeavesApp =>
      !playArmed &&
      game.waitingForInput &&
      !returning &&
      !adBusy &&
      entrance.isDismissed;

  /// Back pauses a live run; from a paused, armed or finished board it
  /// returns to the menu (recording any finished result) instead of exiting.
  void handleBack() {
    if (adBusy || returning) return;
    if (screenshotMode) {
      setState(() => screenshotMode = false);
      return;
    }
    if (game.started &&
        !game.finished &&
        !game.paused &&
        !game.waitingForInput) {
      pause();
      return;
    }
    unawaited(home());
  }

  Widget? tutorialOverlay() {
    if (!tutorialActive ||
        tutorialSheetOpen ||
        returning ||
        game.paused ||
        game.finished)
      return null;
    final step = tutorialStep;
    final guidedPlay = tutorialBoard && step.scripted && game.infinite;
    final objective =
        tutorialBoard &&
        step == TutorialStep.classicPlay &&
        game.mode == GameMode.classic &&
        game.waitingForInput;
    final menu = !tutorialBoard && game.waitingForInput && entrance.isDismissed;
    if (!guidedPlay && !objective && !menu) return null;
    // The boss card introduces the fight, then clears the sky for it.
    if (guidedPlay &&
        step == TutorialStep.boss &&
        (game.boss?.phase ?? BossPhase.arriving) != BossPhase.arriving)
      return null;
    final controlsText = game.oneFinger
        ? game.haloJoystick
              ? 'Touch anywhere on the board. Drag sideways to tilt, up or down to lift. The Halo hides when you release.'
              : 'Drag the thumb pad: sideways to tilt, up or down to lift. Hold still to keep the height.'
        : 'Drag up or down on the left or right side. Move both sides to lift; move one to tilt.';
    final (String title, IconData icon, String message) = menu
        ? step.inShop
              ? (
                  'Gear Shop',
                  Icons.storefront_rounded,
                  'Coins buy balls, platforms and permanent Infinite upgrades. A gold dot on Shop means you can afford something new. Open Shop.',
                )
              : tutorialOnLevels
              ? (
                  'Handmade levels',
                  Icons.route_rounded,
                  'Classic is a road of handmade boards with stars to earn. Tap Choose Level.',
                )
              : step == TutorialStep.dailyChallenge
              ? (
                  'Daily Challenge',
                  Icons.today_rounded,
                  'Daily Challenge: a new board each day. Earn stars and beat your best. It lives in Modes with Practice and How to Play. Tap Modes to finish.',
                )
              : (
                  'Back to practice',
                  Icons.play_arrow_rounded,
                  'Your Infinite lessons pick up where you left off. Tap Play.',
                )
        : switch (step) {
            TutorialStep.controls => (
              'Move the platform',
              Icons.open_with_rounded,
              controlsText,
            ),
            TutorialStep.heartsHoles => (
              'Dodge the holes',
              Icons.favorite_rounded,
              'Avoid holes. A fall costs 1 heart, and the run ends when they run out. Steer around this one.',
            ),
            TutorialStep.heartsFeedback => (
              'Hearts',
              Icons.favorite_rounded,
              game.misses > 0
                  ? 'One heart lost. Keep going; your hearts sit top left.'
                  : 'Nicely dodged. Keep going and protect your hearts.',
            ),
            TutorialStep.coins => (
              'Grab the coin',
              Icons.toll_rounded,
              'Collect coins. They fill your wallet for the Shop.',
            ),
            TutorialStep.coinsFeedback => (
              'Coin saved',
              Icons.toll_rounded,
              'Coin saved. Spend it later. Coins are kept even when a run ends.',
            ),
            TutorialStep.shield => (
              'Shield',
              Icons.shield_rounded,
              'Shield protects you from danger for a few seconds. Grab the blue pickup.',
            ),
            TutorialStep.shieldFeedback => (
              'Protected',
              Icons.shield_rounded,
              'Protected! Watch the blue ring around your ball.',
            ),
            TutorialStep.magnet => (
              'Magnet',
              Icons.attractions_rounded,
              'Collect the red-and-blue magnet. It pulls nearby rewards toward you.',
            ),
            TutorialStep.magnetFeedback => (
              'Magnet on',
              Icons.attractions_rounded,
              'The magnet icon and seconds show how long the pickup lasts.',
            ),
            TutorialStep.metrics => (
              'Climb for points',
              Icons.trending_up_rounded,
              'Climb higher. Grow your score.',
            ),
            TutorialStep.combo => (
              'Combo crystal',
              Icons.diamond_rounded,
              'Collect the gold crystal. Crystals multiply your points.',
            ),
            TutorialStep.comboFeedback => (
              'Combo',
              Icons.diamond_rounded,
              'Collect crystals to grow your Combo. A lost heart resets it.',
            ),
            TutorialStep.boss => (
              'Boss incoming',
              Icons.local_fire_department_rounded,
              'Bosses arrive as your score climbs. This practice boss is gentle: slip between its bullets and leave the marked laser lines until its timer ends.',
            ),
            TutorialStep.bossFeedback => (
              'Boss cleared',
              Icons.emoji_events_rounded,
              'Real bosses hit harder and stay longer. Next: 45 seconds of free play.',
            ),
            TutorialStep.classicPlay => (
              'Level 1',
              Icons.flag_rounded,
              game.oneFinger
                  ? game.haloJoystick
                        ? 'Same floating Halo controls. Lift to glowing holes in order, 1–10. Avoid dark holes. Drag anywhere to begin.'
                        : 'Same thumb-pad controls. Lift to glowing holes in order, 1–10. Avoid dark holes. Drag to begin.'
                  : 'Reach glowing holes in order, 1–10. Avoid dark holes. Drag on either side to begin.',
            ),
            _ => ('', Icons.school_rounded, ''),
          };
    if (message.isEmpty) return null;
    return TutorialSpotlight(
      key: const ValueKey('onboarding-spotlight'),
      title: title,
      icon: icon,
      badge:
          !menu &&
              (step == TutorialStep.coins || step == TutorialStep.coinsFeedback)
          ? const CoinIcon(size: 30)
          : null,
      lesson: step.lesson,
      lessons: TutorialStep.lessons,
      message: message,
      onSkip: skipTutorial,
      listenable: frame,
      blockOutside: menu,
      bottomInset: guidedPlay || objective
          ? OneFingerControls.heightFor(game) + 12
          : 100,
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
        void boardPoint(Offset at, double radius) {
          if (board == null || !board.hasSize) return;
          final viewport = boardViewport(board.size);
          final point = layer.globalToLocal(
            board.localToGlobal(viewport.project(at)),
          );
          result.add(
            Rect.fromCircle(center: point, radius: radius * viewport.scale),
          );
        }

        void worldPoint(double x, double y, [double radius = 22]) =>
            boardPoint(Offset(x, game.screenY(y)), radius);

        void controls() {
          if (game.boardTilt) {
            ui(boardKey);
            return;
          }
          if (game.bottomControls) {
            ui(analogKey);
            return;
          }
          if (board == null || !board.hasSize) return;
          if (game.oneFinger) {
            if (game.haloJoystick) {
              final top = layer.globalToLocal(board.localToGlobal(Offset.zero));
              result.add(top & board.size);
              return;
            }
            final top = layer.globalToLocal(
              board.localToGlobal(
                Offset(
                  12,
                  board.size.height -
                      OneFingerControls.heightFor(game) -
                      ((boardKey.currentWidget as PivotBoard?)?.bottomPadding ??
                          0) +
                      10,
                ),
              ),
            );
            result.add(
              top &
                  Size(
                    board.size.width - 24,
                    OneFingerControls.extendedHeightFor(
                          game,
                          (boardKey.currentWidget as PivotBoard?)
                                  ?.bottomPadding ??
                              0,
                        ) -
                        20,
                  ),
            );
          } else {
            worldPoint(20, game.left, 28);
            worldPoint(340, game.right, 28);
          }
        }

        if (objective) {
          final hole = game.activeHole;
          if (hole != null) worldPoint(hole.x, hole.y);
          controls();
        } else if (menu) {
          ui(
            step.inShop
                ? shopOriginKey
                : tutorialOnLevels
                ? tutorialLevelsKey
                : step == TutorialStep.dailyChallenge
                ? tutorialDailyKey
                : tutorialPlayKey,
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
            case TutorialStep.shield ||
                TutorialStep.magnet ||
                TutorialStep.combo:
              if (tutorialRun?.pickup case final item?)
                worldPoint(item.x, item.y);
            case TutorialStep.shieldFeedback:
              worldPoint(game.ballX, game.ballY, 28);
            case TutorialStep.magnetFeedback:
              worldPoint(game.ballX, game.ballY - 35, 40);
            case TutorialStep.metrics || TutorialStep.comboFeedback:
              ui(tutorialScoreKey);
            case TutorialStep.boss:
              if (game.boss case final boss?)
                boardPoint(Offset(boss.position.x, boss.position.y), 50);
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
    backgroundColor: menuBackground,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .9,
    ),
    builder: (sheetContext) {
      Widget choice(
        String title,
        String subtitle,
        IconData icon,
        VoidCallback action,
      ) => MenuAction(
        title: title,
        subtitle: subtitle,
        icon: icon,
        onTap: () {
          Navigator.pop(sheetContext);
          action();
        },
      );
      return MenuSurface(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MenuHeading(
                  'Your arcade',
                  eyebrow: 'EXPLORE ROLLRISE',
                  subtitle: 'A new challenge. Your next personal best.',
                ),
                choice(
                  'Classic levels',
                  'Master every board and collect stars',
                  Icons.grid_view_rounded,
                  selectLevel,
                ),
                choice(
                  'DAILY',
                  'A fresh board, every day',
                  Icons.today_outlined,
                  showDaily,
                ),
                choice(
                  'PRACTICE',
                  'Find your balance at your own pace',
                  Icons.touch_app,
                  () => start(GameMode.practice),
                ),
                const SizedBox(height: 12),
                const MenuSection('MAKE IT YOURS'),
                const SizedBox(height: 12),
                choice(
                  'GEAR SHOP',
                  'Balls, worlds, platforms and upgrades',
                  Icons.palette_outlined,
                  showBallShop,
                ),
                choice(
                  profile.achievementsReady > 0
                      ? 'ACHIEVEMENTS (${profile.achievementsReady} ready)'
                      : 'ACHIEVEMENTS',
                  'Milestones worth celebrating',
                  Icons.workspace_premium_outlined,
                  showAchievements,
                ),
                choice(
                  'Goals, friends & backup',
                  'Your progress, connected',
                  Icons.emoji_events_outlined,
                  showClub,
                ),
                choice(
                  'HOW TO PLAY',
                  'Learn the art of balance',
                  Icons.help_outline,
                  showGuide,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget wideBoardChrome() => Align(
    alignment: Alignment.topCenter,
    child: Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: math.min(1280, MediaQuery.sizeOf(context).width * .8),
        height: 80,
        child: AnimatedBuilder(
          animation: Listenable.merge([hud, backdrop]),
          builder: (context, _) {
            const detail = TextStyle(
              color: menuText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: Row(
                      children: [
                        SizedBox(
                          key: tutorialHeartsKey,
                          child: game.practice
                              ? null
                              : Semantics(
                                  key: const ValueKey('board-hearts'),
                                  label:
                                      '${game.lives} of ${game.heartCapacity} hearts remaining',
                                  excludeSemantics: true,
                                  child: Row(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < game.heartCapacity;
                                        i++
                                      )
                                        Icon(
                                          i < game.lives
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          key: ValueKey('board-heart-$i'),
                                          size: 22,
                                          color: i < game.lives
                                              ? const Color(0xFFEF6958)
                                              : menuMuted,
                                        ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(width: 20),
                        AnimatedOpacity(
                          opacity: bossHidesHud ? 0 : 1,
                          duration: const Duration(milliseconds: 250),
                          child: IgnorePointer(
                            key: tutorialScoreKey,
                            child: Column(
                              key: const ValueKey('board-hud'),
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  game.mode == GameMode.classic
                                      ? '${game.completed}/10'
                                      : '${game.score}',
                                  key: game.infinite
                                      ? const ValueKey('infinite-score')
                                      : null,
                                  style: const TextStyle(
                                    color: menuText,
                                    fontSize: 32,
                                    height: 1.1,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                if (game.infinite)
                                  Text(
                                    '${game.survival.combo}×${game.survival.combo == InfiniteTuning.maxCombo ? ' MAX' : ''}',
                                    style: detail,
                                  )
                                else if (game.merging) ...[
                                  Text(
                                    'TOP ${formatMergeNumber(game.mergeRun.highest)}',
                                    style: detail,
                                  ),
                                  MergeStatus(
                                    run: game.mergeRun,
                                    color: menuText,
                                  ),
                                ] else
                                  Text(
                                    game.practice
                                        ? 'PRACTICE · ${formatRunTime(game.elapsed)}'
                                        : game.daily
                                        ? 'L${game.level} · TARGET ${game.target.clamp(1, 10)}/10 · ${formatRunTime(game.elapsed)}'
                                        : 'LEVEL ${game.level} · ${formatRunTime(game.elapsed)}',
                                    style: detail,
                                  ),
                                if (game.mode == GameMode.classic)
                                  Row(
                                    key: const ValueKey(
                                      'classic-bonus-star-status',
                                    ),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: menuGold,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        game.levelStarAlreadyOwned
                                            ? 'COLLECTED'
                                            : game.levelStarCollected
                                            ? 'WIN TO KEEP'
                                            : 'BONUS STAR',
                                        style: detail,
                                      ),
                                    ],
                                  ),
                                if (game.infinite && !offeringRevive)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: coinChip(menuText),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                IconButton.filledTonal(
                  key: const ValueKey('board-pause'),
                  tooltip: game.paused ? 'Resume' : 'Pause',
                  onPressed: pause,
                  style: IconButton.styleFrom(
                    backgroundColor: menuRaised,
                    foregroundColor: menuText,
                  ),
                  icon: Icon(
                    game.paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    size: 24,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  /// A boss fight clears score, combo and coins from the HUD so the attacks
  /// read clearly; they return when the boss leaves. Hearts stay visible.
  bool get bossHidesHud => game.infinite && game.boss != null;

  /// Infinite's coin counter under the combo; [ink] is the HUD text color.
  Widget coinChip(Color ink) => KeyedSubtree(
    key: tutorialCoinsKey,
    child: InfiniteCoinChip(
      key: const ValueKey('run-coins'),
      wallet: profile.wallet,
      collected: game.coinsCollected,
      unlimited: profile.unlimitedCoins,
      ink: ink,
      sinceCoin: game.lastCoinAge,
      reducedMotion: MediaQuery.disableAnimationsOf(context),
    ),
  );

  Widget boardChrome() {
    if (!tutorialBoard && game.waitingForInput) {
      if (!playArmed) return const SizedBox();
      return Center(
        child: IgnorePointer(
          child: MenuPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.touch_app_rounded, color: menuGold, size: 32),
                const SizedBox(height: 12),
                Text(
                  startInstruction,
                  key: const ValueKey('start-control-prompt'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: menuText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your run starts when you move.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: menuMuted),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (tutorialActive &&
        tutorialStep == TutorialStep.classicPlay &&
        game.waitingForInput)
      return const SizedBox();
    if (game.waitingForInput && !(tutorialActive && tutorialStep.inInfinite)) {
      if (game.mode != GameMode.classic) return const SizedBox();
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
                    onPressed: carouselMoving ? null : selectLevel,
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
                        color: menuPanel.withAlpha(235),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Level ${game.level}',
                        key: const ValueKey('board-level-name'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: menuText,
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
    if (usesWideStage(MediaQuery.sizeOf(context))) return wideBoardChrome();
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
            // Classic shows target progress; score-based modes keep their score.
            final detail = TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );
            return LayoutBuilder(
              builder: (context, constraints) {
                final sideWidth = math.min(72.0, constraints.maxWidth * .25);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      key: tutorialHeartsKey,
                      width: sideWidth,
                      child: game.practice
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Semantics(
                                key: const ValueKey('board-hearts'),
                                label:
                                    '${game.lives} of ${game.heartCapacity} hearts remaining',
                                excludeSemantics: true,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (
                                        var i = 0;
                                        i < game.heartCapacity;
                                        i++
                                      )
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
                      child: AnimatedOpacity(
                        opacity: bossHidesHud ? 0 : 1,
                        duration: const Duration(milliseconds: 250),
                        child: IgnorePointer(
                          key: tutorialScoreKey,
                          child: Column(
                            key: const ValueKey('board-hud'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  game.mode == GameMode.classic
                                      ? '${game.completed}/10'
                                      : '${game.score}',
                                  key: game.infinite
                                      ? const ValueKey('infinite-score')
                                      : null,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 30,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              if (game.infinite)
                                Text(
                                  '${game.survival.combo}×${game.survival.combo == InfiniteTuning.maxCombo ? ' MAX' : ''}',
                                  style: detail,
                                )
                              else if (game.merging) ...[
                                Text(
                                  'TOP ${formatMergeNumber(game.mergeRun.highest)}',
                                  style: detail,
                                ),
                                MergeStatus(run: game.mergeRun, color: color),
                              ] else
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    game.mode == GameMode.classic
                                        ? 'LEVEL ${game.level} · ${formatRunTime(game.elapsed)}'
                                        : game.practice
                                        ? 'PRACTICE · ${formatRunTime(game.elapsed)}'
                                        : 'L${game.level} · TARGET ${game.target.clamp(1, 10)}/10 · ${formatRunTime(game.elapsed)}',
                                    maxLines: 1,
                                    style: detail,
                                  ),
                                ),
                              if (game.mode == GameMode.classic)
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    key: const ValueKey(
                                      'classic-bonus-star-status',
                                    ),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        game.levelStarAlreadyOwned ||
                                                game.levelStarCollected
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        size: 16,
                                        color: const Color(0xFFE9B853),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        game.levelStarAlreadyOwned
                                            ? 'COLLECTED'
                                            : game.levelStarCollected
                                            ? 'WIN TO KEEP'
                                            : 'BONUS STAR',
                                        style: detail.copyWith(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              if (game.infinite && !offeringRevive)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: coinChip(color),
                                  ),
                                ),
                            ],
                          ),
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
          },
        ),
      ),
    );
  }

  static const worldColors = [
    Color(0xFFE9E9DC),
    Color(0xFFF1E4C8),
    Color(0xFFE4E3F1),
  ];

  String worldTitle(int index) => switch (index) {
    0 => 'Infinite',
    1 => 'Classic',
    _ => 'Number Merge',
  };

  String worldSubtitle(int index) => switch (index) {
    0 => 'NO FINISH LINE. FIND YOUR FLOW.',
    1 => 'Classic • Level ${worldLevel(index)}',
    _ => 'SMALL NUMBERS. BIG POSSIBILITIES.',
  };

  String get startInstruction => switch (game.controlMode) {
    ControlMode.analog => 'Touch a joystick to play',
    ControlMode.tiltLift => 'Drag sideways to play',
    ControlMode.boardTilt => 'Drag on the board to tilt',
    ControlMode.oneFinger =>
      game.haloJoystick
          ? 'Drag anywhere to play'
          : 'Drag the thumb area to play',
    ControlMode.twoFinger => 'Drag either side to play',
  };

  bool playArmed = false;

  bool acceptsWorldSwipe(Offset global) {
    if (tutorialActive ||
        !game.waitingForInput ||
        returning ||
        !entrance.isDismissed ||
        carouselMoving ||
        ModalRoute.of(context)?.isCurrent != true)
      return false;
    if (!tutorialActive && !playArmed) return true;
    final analog = analogKey.currentContext?.findRenderObject() as RenderBox?;
    if (game.bottomControls && analog != null) {
      final point = analog.globalToLocal(global);
      if ((Offset.zero & analog.size).contains(point) &&
          (game.tiltLift ||
              point.dx <= 106 ||
              point.dx >= analog.size.width - 106))
        return false;
    }
    final board = boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (board == null) return true;
    final point = board.globalToLocal(global);
    if (!(Offset.zero & board.size).contains(point)) return true;
    if (game.boardTilt) return false;
    if (game.oneFinger && game.haloJoystick) return false;
    if (game.oneFinger)
      return point.dy < board.size.height - OneFingerControls.heightFor(game);
    if (game.bottomControls) return true;
    // The same layout the board paints with: once armed, a touch on either
    // half controls the platform rather than swiping worlds.
    final viewport = boardViewport(board.size);
    for (final side in [0, 1]) {
      if (viewport.controlsSide(point, side)) return false;
    }
    return true;
  }

  final Map<int, BalanceGame> _themedPreviews = {};

  /// Frozen boards reflect the equipped ball, without advancing any simulation.
  BalanceGame themedPreview(int index) {
    final existing = _themedPreviews[index];
    if (existing != null &&
        existing.level == worldLevel(index) &&
        existing.cosmetic == profile.selectedBall &&
        existing.cabinet == profile.cabinet &&
        existing.controlMode == controlForMode(arcadeModes[index]) &&
        existing.haloJoystick == profile.haloJoystick &&
        existing.levelStarAlreadyOwned ==
            profile.hasCollectedLevelStar(worldLevel(index)) &&
        existing.platformStyle == profile.selectedPlatform)
      return existing;
    return _themedPreviews[index] = BalanceGame(seed: index + 1)
      ..cosmetic = profile.selectedBall
      ..cabinet = profile.cabinet
      ..platformStyle = profile.selectedPlatform
      ..haloJoystick = profile.haloJoystick
      ..levelStarAlreadyOwned = profile.hasCollectedLevelStar(worldLevel(index))
      ..setControlMode(controlForMode(arcadeModes[index]))
      ..start(
        gameMode: arcadeModes[index],
        levelNumber: worldLevel(index),
        waitForInput: true,
      );
  }

  Widget world(BuildContext context, int index, Animation<double> drift) {
    final active = index == selectedMode;
    final visibility =
        1 -
        ((carouselKey.currentState?.page ?? selectedMode.toDouble()) - index)
            .abs()
            .clamp(0.0, 1.0);
    final board = active
        ? IgnorePointer(
            ignoring:
                carouselMoving ||
                (!tutorialBoard && !playArmed && game.waitingForInput),
            child: PivotBoard(
              key: boardKey,
              game: game,
              frame: frame,
              fillWidth: expansion,
              bottomInset:
                  controlStrip(game) +
                  bottomControlHeight(context) * expansion +
                  MediaQuery.paddingOf(context).bottom * expansion,
              bottomPadding: MediaQuery.paddingOf(context).bottom * expansion,
              overlay: Padding(
                // The board extends behind the status bar; its HUD stays below it.
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top * expansion,
                ),
                child: boardChrome(),
              ),
              dimUntilInput:
                  game.infinite &&
                  game.waitingForInput &&
                  (tutorialBoard || playArmed) &&
                  !returning,
              showHint:
                  (tutorialBoard || playArmed) &&
                  game.waitingForInput &&
                  !carouselMoving &&
                  !returning &&
                  (playArmed || entrance.isDismissed),
            ),
          )
        : Opacity(
            opacity: 1 - expansion,
            child: IgnorePointer(
              child: Column(
                children: [
                  Expanded(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: ValueKey('mode-preview-$index'),
                        painter: ModeWorldPreview(themedPreview(index)),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  if (controlStrip(game) > 0)
                    SizedBox(height: controlStrip(game)),
                ],
              ),
            ),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 1 - chromeOpacity,
          child: LayoutBuilder(
            builder: (context, bounds) => OverflowBox(
              minHeight: math.max(200, bounds.maxHeight),
              maxHeight: math.max(200, bounds.maxHeight),
              child: board,
            ),
          ),
        ),
        if (chromeOpacity > 0)
          IgnorePointer(
            child: ExcludeSemantics(
              child: Opacity(
                opacity: chromeOpacity * visibility,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: MenuBallStage(
                      profile.selectedBall,
                      drift,
                      mode: arcadeModes[index],
                      platform: profile.selectedPlatform,
                      reducedMotion: MediaQuery.disableAnimationsOf(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget bottomInput(double controlHeight) => SizedBox(
    key: analogKey,
    height: controlHeight,
    child: IgnorePointer(
      ignoring:
          carouselMoving ||
          (!tutorialBoard && !playArmed && game.waitingForInput),
      child: Opacity(
        opacity: 1 - chromeOpacity,
        child: LayoutBuilder(
          builder: (context, bounds) => Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: ControlGlass(
                  child: game.tiltLift
                      ? TiltLiftControls(game: game, frame: frame)
                      : AnalogControls(game: game, frame: frame),
                ),
              ),
              if ((tutorialBoard || playArmed) &&
                  game.waitingForInput &&
                  !carouselMoving)
                ControlHint(
                  sideways: game.tiltLift,
                  anchors: [
                    if (game.tiltLift)
                      Offset(bounds.maxWidth / 2, bounds.maxHeight / 2)
                    else ...[
                      Offset(62, bounds.maxHeight / 2),
                      Offset(bounds.maxWidth - 62, bounds.maxHeight / 2),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );

  void playSelectedWorld() {
    if (carouselMoving ||
        returning ||
        !game.waitingForInput ||
        ModalRoute.of(context)?.isCurrent != true)
      return;
    setState(() {
      playArmed = true;
      game.inputLocked = false;
    });
    // Reveal the prepared board; simulation starts on the first control input.
    if (MediaQuery.disableAnimationsOf(context)) {
      entrance.value = 1;
    } else {
      entrance.forward();
    }
  }

  int savedWorldScore(int index) => switch (arcadeModes[index]) {
    GameMode.infinite => profile.infiniteBestScore,
    GameMode.merge2048 => profile.mergeBest,
    _ => profile.levelRecord(worldLevel(index), profile.controlMode).bestScore,
  };

  bool get compactMenu =>
      MediaQuery.sizeOf(context).height -
          MediaQuery.paddingOf(context).vertical <
      560;

  /// Modes holds Daily Challenge, where the tutorial hands over.
  void openModes() {
    if (tutorialActive && tutorialStep == TutorialStep.dailyChallenge) {
      skipTutorial();
    }
    showModes();
  }

  Widget selectionHeader(double page) {
    return Row(
      children: [
        // Modes are also one swipe away in the carousel, so the full mode
        // list sits in the quiet corner and Achievements gets the big button.
        MenuQuietButton(
          key: tutorialDailyKey,
          icon: Icons.grid_view_rounded,
          tooltip: 'Modes',
          onPressed: carouselMoving ? null : openModes,
        ),
        MenuQuietButton(
          icon: Icons.redeem_outlined,
          tooltip: 'Daily prizes',
          badge: profile.dailyPrizes.canClaim(DateTime.now()),
          onPressed: carouselMoving ? null : showDailyPrizes,
        ),
        const Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ROLLRISE',
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      color: menuText,
                      fontSize: 30,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w300,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'THE ART OF BALANCE',
                    style: TextStyle(
                      color: menuMuted,
                      fontSize: 8,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        MenuQuietButton(
          icon: Icons.tune_rounded,
          tooltip: 'Settings',
          onPressed: carouselMoving ? null : showSettings,
        ),
      ],
    );
  }

  /// Side arrows hint that more modes sit beside the current one.
  Widget modeArrow(int index, int step) {
    final target = index + step;
    final enabled = target >= 0 && target < arcadeModes.length;
    return SizedBox(
      width: 44,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: IconButton(
          key: ValueKey(step < 0 ? 'mode-previous' : 'mode-next'),
          tooltip: step < 0 ? 'Previous mode' : 'Next mode',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          onPressed: enabled && !carouselMoving
              ? () => carouselKey.currentState?.select(target)
              : null,
          icon: Icon(
            step < 0 ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            color: menuGold,
            size: 30,
          ),
        ),
      ),
    );
  }

  Widget carouselFooter(double page) {
    final index = page.round().clamp(0, arcadeModes.length - 1);
    final classic = index == 1;
    final landscape = usesLandscapeMenu(MediaQuery.sizeOf(context));
    return Align(
      alignment: landscape ? Alignment.center : Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: landscape ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: compactMenu ? 26 : 34,
                child: Row(
                  children: [
                    modeArrow(index, -1),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          worldTitle(index),
                          key: const ValueKey('selected-mode-title'),
                          style: const TextStyle(
                            color: menuText,
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -.4,
                          ),
                        ),
                      ),
                    ),
                    modeArrow(index, 1),
                  ],
                ),
              ),
              SizedBox(
                height: compactMenu ? 14 : 18,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    worldSubtitle(index),
                    key: const ValueKey('selected-mode-subtitle'),
                    style: const TextStyle(
                      color: menuMuted,
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: classic
                          ? MenuEarnedStars(stars: profile.totalStars)
                          : MenuBestScore(score: savedWorldScore(index)),
                    ),
                    if (classic) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Center(
                          child: Tooltip(
                            key: tutorialLevelsKey,
                            message: 'Level ${worldLevel(index)}',
                            child: SizedBox(
                              height: 40,
                              child: FilledButton.icon(
                                key: const ValueKey('choose-level'),
                                onPressed: carouselMoving ? null : selectLevel,
                                style: FilledButton.styleFrom(
                                  backgroundColor: menuGold,
                                  foregroundColor: menuBackground,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  minimumSize: const Size(0, 40),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  textStyle: const TextStyle(
                                    fontFamily: 'sans-serif',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                icon: const Icon(Icons.route_rounded, size: 20),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Choose Level'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: KeyedSubtree(
                      key: shopOriginKey,
                      child: MenuActionButton(
                        key: game.waitingForInput
                            ? const ValueKey('board-shop')
                            : null,
                        label: 'Shop',
                        icon: Icons.storefront_outlined,
                        tooltip: 'Gear shop',
                        upgradeAvailable: profile.shopUpgradeAvailable,
                        onPressed: carouselMoving ? null : showBallShop,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MenuActionButton(
                      label: 'Achievements',
                      icon: Icons.emoji_events_outlined,
                      tooltip: 'Achievements',
                      upgradeAvailable: profile.achievementsReady > 0,
                      hintLabel: 'Achievement rewards ready',
                      hintKey: 'achievement-ready-hint',
                      onPressed: carouselMoving ? null : showAchievements,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              KeyedSubtree(
                key: tutorialPlayKey,
                child: PremiumPlayButton(
                  height: compactMenu ? 56 : 64,
                  key: game.waitingForInput
                      ? const ValueKey('menu-play')
                      : null,
                  onPressed:
                      carouselMoving || !game.waitingForInput || returning
                      ? null
                      : playSelectedWorld,
                ),
              ),
              SizedBox(height: compactMenu ? 8 : 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var mode = 0; mode < arcadeModes.length; mode++)
                          Flexible(
                            child: Tooltip(
                              message: worldTitle(mode),
                              child: Semantics(
                                label: '${worldTitle(mode)}, ${mode + 1} of 3',
                                selected: selectedMode == mode,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    key: ValueKey('mode-$mode'),
                                    onTap: carouselMoving
                                        ? null
                                        : () => carouselKey.currentState
                                              ?.select(mode),
                                    borderRadius: BorderRadius.circular(18),
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Center(
                                        child: Container(
                                          width:
                                              7 +
                                              15 *
                                                  (1 -
                                                      (page - mode).abs().clamp(
                                                        0.0,
                                                        1.0,
                                                      )),
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: selectedMode == mode
                                                ? menuGold
                                                : menuMuted.withAlpha(80),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget playScreen(BuildContext context) => Scaffold(
    body: MenuMotion(
      enabled:
          !tutorialBoard && !playArmed && game.waitingForInput && !returning,
      builder: (context, drift, reveal) => ModeCarousel(
        key: carouselKey,
        selected: selectedMode,
        locked:
            tutorialActive ||
            playArmed ||
            !game.waitingForInput ||
            returning ||
            !entrance.isDismissed,
        expansion: expansion,
        controlInset: controlStrip(game),
        acceptSwipe: acceptsWorldSwipe,
        onMoving: (moving) => setState(() {
          carouselMoving = moving;
          game.inputLocked = moving || (!tutorialBoard && !playArmed);
        }),
        onSelected: (index) => setState(() {
          if (index != selectedMode) prepareWorld(index);
        }),
        worldBuilder: (context, index) => world(context, index, drift),
        builder: (context, worlds, page) {
          final low = page.floor().clamp(0, arcadeModes.length - 1),
              high = page.ceil().clamp(0, arcadeModes.length - 1);
          final background = Color.lerp(
            Color.lerp(
              worldColors[low],
              BallWorld.of(game.cosmetic).surround,
              .85,
            ),
            Color.lerp(
              worldColors[high],
              BallWorld.of(game.cosmetic).surround,
              .85,
            ),
            page - page.floor(),
          )!;
          final ready =
              game.waitingForInput && !returning && entrance.isDismissed;
          final menuScale = wideMenuScale(MediaQuery.sizeOf(context));
          final landscapeMenu = usesLandscapeMenu(MediaQuery.sizeOf(context));
          final menuFooterWidth = 460.0 * menuScale;
          final menuHeaderHeight = compactMenu ? 64.0 : 88.0 * menuScale;
          final headerHeight = menuHeaderHeight * (1 - expansion);
          final menuFooterHeight = compactMenu ? 284.0 : 310.0 * menuScale;
          final menuGap = compactMenu ? 4.0 : 12.0;
          final controlHeight = bottomControlHeight(context);
          final stageBackground = Color.lerp(
            background,
            menuBackground,
            chromeOpacity,
          )!;
          final stageBrightness = ThemeData.estimateBrightnessForColor(
            stageBackground,
          );
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarBrightness: stageBrightness,
              statusBarIconBrightness: stageBrightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
            ),
            child: ColoredBox(
              color: stageBackground,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (chromeOpacity > 0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: chromeOpacity,
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: PremiumMenuBackdrop(
                                profile.selectedBall,
                                drift,
                                page: page,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (game.infinite)
                    Opacity(
                      opacity: 1 - chromeOpacity,

                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: InfiniteBackdropPainter(
                            game,
                            reducedMotion: MediaQuery.disableAnimationsOf(
                              context,
                            ),
                            repaint: backdrop,
                          ),
                        ),
                      ),
                    ),
                  SafeArea(
                    key: const ValueKey('arcade-stage'),
                    top: false,
                    bottom: false,
                    minimum: EdgeInsets.only(
                      top: MediaQuery.paddingOf(context).top * (1 - expansion),
                      bottom:
                          MediaQuery.paddingOf(context).bottom *
                          (1 - expansion),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Column(
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
                                            child: MenuReveal(
                                              animation: reveal,
                                              child: ScaledMenuChrome(
                                                scale: menuScale,
                                                child: selectionHeader(page),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Flex(
                                direction: landscapeMenu
                                    ? Axis.horizontal
                                    : Axis.vertical,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        top: menuGap * (1 - expansion),
                                        bottom: menuGap * (1 - expansion),
                                      ),
                                      child: worlds,
                                    ),
                                  ),
                                  SizedBox(
                                    width: landscapeMenu
                                        ? menuFooterWidth * (1 - expansion)
                                        : null,
                                    height: landscapeMenu
                                        ? null
                                        : menuFooterHeight * (1 - expansion),
                                    child: ClipRect(
                                      child: OverflowBox(
                                        minWidth: landscapeMenu
                                            ? menuFooterWidth
                                            : null,
                                        maxWidth: landscapeMenu
                                            ? menuFooterWidth
                                            : null,
                                        minHeight: landscapeMenu
                                            ? null
                                            : menuFooterHeight,
                                        maxHeight: landscapeMenu
                                            ? null
                                            : menuFooterHeight,
                                        alignment: landscapeMenu
                                            ? Alignment.centerRight
                                            : Alignment.bottomCenter,
                                        child: IgnorePointer(
                                          ignoring: !ready,
                                          child: ExcludeSemantics(
                                            excluding: !ready,
                                            child: Opacity(
                                              opacity: chromeOpacity,
                                              child: MenuReveal(
                                                animation: reveal,
                                                child: ScaledMenuChrome(
                                                  scale: menuScale,
                                                  child: carouselFooter(page),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (game.bottomControls)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom:
                                MediaQuery.paddingOf(context).bottom *
                                    expansion +
                                menuFooterHeight * (1 - expansion),
                            child: bottomInput(controlHeight),
                          ),
                      ],
                    ),
                  ),
                  if (!returning &&
                      resumeSeconds == 0 &&
                      (game.paused || game.finished) &&
                      !screenshotMode)
                    SafeArea(
                      key: const ValueKey('run-overlay'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: responsiveRunOverlay(context),
                      ),
                    ),
                  // TEMPORARY: any tap leaves the frozen screenshot view.
                  if (screenshotMode)
                    Positioned.fill(
                      child: GestureDetector(
                        key: const ValueKey('screenshot-mode'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => screenshotMode = false),
                      ),
                    ),
                  if (resumeSeconds > 0)
                    Positioned.fill(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ModalBarrier(
                            color: ink.withAlpha(160),
                            dismissible: false,
                          ),
                          Center(
                            child: Semantics(
                              liveRegion: true,
                              label: 'Resuming in $resumeSeconds',
                              child: Text(
                                '$resumeSeconds',
                                key: const ValueKey('resume-countdown'),
                                style: const TextStyle(
                                  color: cream,
                                  fontSize: 96,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  IgnorePointer(
                    child: RepaintBoundary(
                      key: effectsKey,
                      child: CustomPaint(
                        painter: HeartLossPainter(
                          heartEffects,
                          reducedMotion: MediaQuery.disableAnimationsOf(
                            context,
                          ),
                          repaint: frame,
                        ),
                      ),
                    ),
                  ),
                  if (tutorialOverlay() case final overlay?) overlay,
                ],
              ),
            ),
          );
        },
      ),
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
              : ink.withAlpha(190),
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
            backgroundColor: menuGold,
            foregroundColor: menuBackground,
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
                  child: Text(text, style: label(menuBackground)),
                ),
              ),
              const SizedBox(width: 8),
              trailing != null
                  ? Text(trailing, style: label(menuBackground))
                  : const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      );

  Widget coinDoubleOffer() => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: MenuPanel(
      key: const ValueKey('coin-double-offer'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Double your coins',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: menuGold,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${offeringRevive ? 'End this run and watch an ad' : 'Watch an ad'}: '
            '${game.coinsCollected} to ${game.coinsCollected * 2} coins.\n'
            'Your collected coins are already saved.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: menuText, fontSize: 12, height: 1.5),
          ),
          if (coinDoubleError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                coinDoubleError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: menuGold, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('watch-coin-double-ad'),
            onPressed: adBusy ? null : watchCoinDoubleAd,
            icon: adBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_circle_outline),
            label: Text(adBusy ? 'Opening ad…' : 'Watch ad · 2× coins'),
          ),
        ],
      ),
    ),
  );

  Widget reviveOffer() => PopScope(
    canPop: !adBusy,
    child: Container(
      key: const ValueKey('revive-offer'),
      decoration: BoxDecoration(
        color: menuBackground.withAlpha(245),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: menuLine),
      ),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final compact = bounds.maxHeight < 640;
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(compact ? 16 : 25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RunCoinSummary(
                    key: const ValueKey('revive-coin-summary'),
                    wallet: profile.wallet,
                    collected: game.coinsCollected,
                    unlimited: profile.unlimitedCoins,
                  ),
                  SizedBox(height: compact ? 12 : 28),
                  Icon(
                    Icons.favorite_rounded,
                    color: orange,
                    size: compact ? 36 : 52,
                  ),
                  SizedBox(height: compact ? 8 : 16),
                  Text(
                    'One more chance?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cream,
                      fontSize: compact ? 23 : 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  Text(
                    '${game.score} points · ${game.metres}m',
                    style: label(brass),
                  ),
                  SizedBox(height: compact ? 10 : 16),
                  const Text(
                    'Watch an ad to continue with 1 heart.\nOne revive per run.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cream, height: 1.5),
                  ),
                  if (reviveError != null)
                    Padding(
                      padding: EdgeInsets.only(top: compact ? 8 : 16),
                      child: Text(
                        reviveError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: brass, fontSize: 12),
                      ),
                    ),
                  SizedBox(height: compact ? 14 : 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('watch-revive-ad'),
                      onPressed: adBusy ? null : watchReviveAd,
                      style: FilledButton.styleFrom(
                        backgroundColor: brass,
                        foregroundColor: ink,
                        disabledBackgroundColor: brass.withAlpha(120),
                        disabledForegroundColor: cream,
                        padding: EdgeInsets.symmetric(
                          vertical: compact ? 12 : 15,
                          horizontal: 12,
                        ),
                      ),
                      icon: adBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cream,
                              ),
                            )
                          : const Icon(Icons.play_circle_outline),
                      label: Text(
                        adBusy ? 'Opening ad…' : 'Watch ad · +1 heart',
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 10),
                  TextButton(
                    key: const ValueKey('decline-revive'),
                    onPressed: adBusy ? null : declineRevive,
                    child: const Text(
                      'No thanks · End run',
                      style: TextStyle(color: cream),
                    ),
                  ),
                  if (offeringCoinDouble) coinDoubleOffer(),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget responsiveRunOverlay(BuildContext context) {
    final scale = wideMenuScale(MediaQuery.sizeOf(context));
    final overlay = boardOverlay();
    if (scale == 1) return overlay;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520 * scale),
        child: ScaledMenuChrome(scale: scale, child: overlay),
      ),
    );
  }

  Widget boardOverlay() => offeringRevive
      ? reviveOffer()
      : game.merging && game.finished
      ? MergeResult(
          run: game.mergeRun,
          coinsEarned: game.coinsCollected,
          newBest: newBest,
          onRetry: () => start(GameMode.merge2048),
          onHome: home,
        )
      : briefing
      ? FinaleBriefing(
          game: game,
          onPlay: pause,
          onBack: () async {
            setState(() => briefing = false);
            await home();
            if (mounted) unawaited(selectLevel());
          },
        )
      : PopScope(
          canPop: !adBusy,
          child: Container(
            decoration: BoxDecoration(
              color: menuBackground.withAlpha(245),
              borderRadius: BorderRadius.circular(28),
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
                        size: 48,
                        color: menuGold,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        game.paused
                            ? 'Take a breath.'
                            : game.won
                            ? (game.merging
                                  ? 'A brilliant chain.'
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
                          game.mode == GameMode.classic
                              ? game.won
                                    ? 'LEVEL COMPLETE'
                                    : 'TRY AGAIN'
                              : newBest
                              ? 'NEW PERSONAL BEST'
                              : game.practice
                              ? 'PRACTICE COMPLETE'
                              : game.infinite
                              ? 'INFINITE RUN COMPLETE'
                              : 'RUN COMPLETE',
                          style: label(brass),
                        ),
                        const SizedBox(height: 8),
                        if (game.mode != GameMode.classic)
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
                                    ? '${game.metres}m · Best combo x${game.survival.bestCombo}\n${game.message}  ${game.coinsCollected * (profile.infiniteCoinsDoubled(game) ? 2 : 1)} coins saved.'
                                    : game.message)
                              : '${game.completed}/10 holes  •  ${game.bestStreak} best streak',
                          style: const TextStyle(
                            fontSize: 12,
                            color: menuMuted,
                          ),
                        ),
                        if (game.mode == GameMode.classic && game.won)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              '+$classicLevelCoinPrize coins · Level complete',
                              key: const ValueKey('level-coin-prize'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: menuGold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (offeringCoinDouble) coinDoubleOffer(),
                        if (game.infinite && profile.infiniteCoinsDoubled(game))
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              'Coins doubled! +${game.coinsCollected} bonus coins saved.',
                              key: const ValueKey('coins-doubled'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: menuGold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (profile.achievementsReady > 0)
                          TextButton.icon(
                            onPressed: adBusy ? null : showAchievements,
                            style: TextButton.styleFrom(foregroundColor: brass),
                            icon: const Icon(Icons.emoji_events_outlined),
                            label: Text(
                              '${profile.achievementsReady} achievement rewards ready',
                            ),
                          ),
                        if (!game.infinite && !game.practice && !game.merging)
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
                            unlocks: const [],
                          ),
                      ] else
                        const Text(
                          'Your run is right where you left it.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: menuMuted, fontSize: 12),
                        ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: menuGold,
                            foregroundColor: menuBackground,
                          ),
                          onPressed: adBusy
                              ? null
                              : game.paused
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
                                  start(
                                    game.mode,
                                    challengeDate: game.dailyDate,
                                  );
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
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
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
                        pauseAction(
                          'RETRY THIS BOARD',
                          Icons.refresh_rounded,
                          () {
                            // The win already moved progress to the next level.
                            if (game.mode == GameMode.classic) {
                              profile.selectClassicLevel(game.level);
                            }
                            start(game.mode, challengeDate: game.dailyDate);
                          },
                        ),
                      // A paused run can be dropped for a fresh one in any mode.
                      if (game.paused)
                        pauseAction(
                          'RESTART RUN',
                          Icons.restart_alt_rounded,
                          () => start(game.mode, challengeDate: game.dailyDate),
                        ),
                      // TEMPORARY store-screenshot tool. Remove before release.
                      if (game.paused || game.finished)
                        pauseAction(
                          'SCREENSHOT MODE',
                          Icons.photo_camera_outlined,
                          () => setState(() => screenshotMode = true),
                        ),
                      if (tutorialActive)
                        TextButton(
                          onPressed: skipTutorial,
                          child: const Text('Skip Tutorial'),
                        ),
                      pauseAction('BACK TO MENU', Icons.home_outlined, home),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

  Widget pauseAction(String text, IconData icon, VoidCallback onPressed) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 58),
              backgroundColor: const Color(0xFF2C4448),
              foregroundColor: menuText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontFamily: 'sans-serif',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: adBusy ? null : onPressed,
            icon: Icon(icon, size: 23),
            label: Text(text, textAlign: TextAlign.center),
          ),
        ),
      );

  Future<void> showGuide() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: menuBackground,
    showDragHandle: true,
    isScrollControlled: true,
    // Leave a visible strip above the sheet so tapping outside also closes it.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .9,
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: MenuHeading(
              'A game of balance.',
              eyebrow: 'HOW TO PLAY',
              trailing: MenuIconButton(
                key: const ValueKey('guide-close'),
                icon: Icons.close_rounded,
                tooltip: 'Close how to play',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 2, 28, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  guideRow(
                    '01',
                    'One finger. Full control.',
                    'Drag in the thumb pad below the board: left or right tilts the platform, up or down raises or lowers it with your finger. Holding still keeps its height. Release and grab anywhere to continue without a jump. The same controls work in Levels, Infinite and Merge.',
                  ),
                  guideRow(
                    '02',
                    'Prefer two fingers?',
                    'Choose One-finger or Two-finger in Options. With two fingers, drag up or down anywhere on the left or right half of the board. Each side moves its end of the platform, so keep your thumbs low and clear of the ball. Move both together to lift, or one to tilt and roll. Release to hold the platform.',
                  ),
                  guideRow(
                    '03',
                    'Levels: follow the light.',
                    'Lift and tilt into the glowing numbered holes in order, 1–10. Dark holes are traps. Each target returns the platform to the bottom; clear all ten with three balls. Consecutive targets build a multiplier and faster climbs earn bonus points. Choose your board with Choose Level.',
                  ),
                  guideRow(
                    '04',
                    'Infinite: keep climbing.',
                    'Start with ${profile.startingHearts} hearts and steer as the board climbs. A hit costs one heart and resets your combo. You keep your position and controls, with ${InfiniteTuning.recoverySeconds} seconds of protection. Keep moving to escape the rising red floor. Pace grows from x1 to x${InfiniteTuning.maxPace} as you climb; gold crystals build your combo up to x${InfiniteTuning.maxCombo}. Missing a crystal keeps the combo; losing a heart resets it.',
                  ),
                  const Text(
                    'Desktop: W / S = left end. ↑ / ↓ = right end. Esc = pause.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                  guideRow(
                    '05',
                    'Collect the power-ups.',
                    'Blue shields protect you for ${profile.shieldDuration.toInt()} seconds. Red-and-blue magnets pull in nearby coins, crystals, shields and hearts for ${profile.magnetDuration.toInt()} seconds; the magnet icon and countdown show time left. Another pickup refreshes its timer. Hearts restore a life up to your upgraded limit. Pausing freezes pickup timers.',
                  ),
                  guideRow(
                    '06',
                    'Read the warnings.',
                    'Infinite adds forming holes, moving holes and lasers as you climb. Temporary platform cuts unlock at 1,000,000 points. Leave red warnings before they activate. During laser mazes, steer through the openings in the descending walls. Spiders fire aimed webs and later enemies attack in turns. In Levels, entering a spider territory starts a chase; contact ends the run. Each target resets the spiders.',
                  ),
                  guideRow(
                    '07',
                    'Merge: grow your number.',
                    'Swipe to Number Merge before starting. Collect numbers equal to or smaller than your head and dodge larger numbers. Matching values merge and grow your chain. Build enough value to pass each numbered gate. Use the same tilt and lift controls to line up your next catch.',
                  ),
                  guideRow(
                    '08',
                    'Three ways to master it.',
                    'Earn a star for finishing, one for a finish without misses, and one for beating the active-time target in the HUD. Classic also has one gold star to collect on each board: it adds a permanent star immediately, even if the run ends later. Each bonus star can only be earned once across all controls. Pauses and ball resets do not count toward active time.',
                  ),
                  guideRow(
                    '09',
                    'Make your coins count.',
                    'Infinite coins save to your wallet. Shop offers balls with their own backgrounds, platforms, and permanent Infinite upgrades for hearts, shields and magnets. Stronger gear increases Infinite points; some balls add a built-in magnet. A gold dot on Shop means you can afford stronger gear or an upgrade. Equipment keeps the same movement and collision size.',
                  ),
                  guideRow(
                    '10',
                    'Choose your next run.',
                    'Swipe between Infinite, Levels and Number Merge, tap Play, then touch your controls to begin. Arcade opens Daily, Practice and How to Play. Daily changes at midnight UTC; retry the same board to improve your record. Replay Tutorial in Options walks you through the controls, pickups and shop again.',
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
        ],
      ),
    ),
  );

  Widget guideRow(String number, String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(number, style: label(menuGold)),
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
                style: TextStyle(fontSize: 13, height: 1.5, color: menuMuted),
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
          // The playtest recorder is a study tool, not a player feature.
          recorder: kReleaseMode ? null : playtest,
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
    backgroundColor: menuBackground,
    showDragHandle: false,
    enableDrag: false,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .9,
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, update) => MenuSurface(
        child: SettingsSheet(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MenuAction(
                  key: const ValueKey('replay-tutorial'),
                  title: 'Replay Tutorial',
                  subtitle: 'A quick refresher on the essentials',
                  icon: Icons.school_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    replayTutorial();
                  },
                ),
                const SizedBox(height: 14),
                MenuAction(
                  key: const ValueKey('privacy-policy'),
                  title: 'Privacy Policy',
                  subtitle: 'How Rollrise handles your data',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyPage(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (widget.adConsent != null)
                  ListenableBuilder(
                    listenable: widget.adConsent!,
                    builder: (context, _) =>
                        widget.adConsent!.privacyOptionsRequired
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: MenuAction(
                              key: const ValueKey('ad-privacy-options'),
                              title: 'Ad privacy choices',
                              subtitle:
                                  'Review or change your advertising choices',
                              icon: Icons.manage_accounts_outlined,
                              onTap: () async {
                                final error = await widget.adConsent!
                                    .showPrivacyOptions();
                                if (context.mounted && error != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error)),
                                  );
                                }
                              },
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                SwitchListTile.adaptive(
                  key: const ValueKey('analytics-opt-in'),
                  title: const Text('Share gameplay analytics'),
                  subtitle: const Text(
                    'Optional usage data to help improve Rollrise',
                  ),
                  value: analytics.collectionEnabled,
                  onChanged: (enabled) async {
                    final saved = await analytics.setCollectionEnabled(enabled);
                    if (!context.mounted) return;
                    update(() {});
                    if (!saved)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not update analytics. Please try again.',
                          ),
                        ),
                      );
                  },
                ),
                const SizedBox(height: 14),
                const MenuSection('Choose your controls'),
                const SizedBox(height: 12),
                ControlOptions(
                  value: profile.preferredControlMode,
                  haloJoystick: profile.haloJoystick,
                  onHaloChanged: (halo) {
                    profile.haloJoystick = halo;
                    game.haloJoystick = halo;
                  },
                  onChanged: (mode) {
                    update(() => profile.controlMode = mode);
                    setState(() {
                      game.setControlMode(controlForMode(game.mode));
                    });
                    unawaited(profile.save());
                  },
                ),
                if (profile.infiniteBestScore >
                    InfiniteTuning.fastStartUnlockScore) ...[
                  const SizedBox(height: 26),
                  const MenuSection('Infinite'),
                  const SizedBox(height: 12),
                  MenuToggle(
                    key: const ValueKey('infinite-fast-start'),
                    title: 'Faster start',
                    icon: Icons.speed_rounded,
                    subtitle:
                        'Start up to ${InfiniteTuning.startingSpeedMultiplier(profile.infiniteBestScore).toStringAsFixed(2)}× faster with a higher pace. Turn off for a relaxed opening. Applies to your next run.',
                    value: profile.infiniteFastStart,
                    onChanged: (value) {
                      update(() => profile.infiniteFastStart = value);
                      setState(() {
                        if (game.infinite && game.waitingForInput) {
                          prepareInfinite(retry: readyRetry);
                        }
                      });
                      unawaited(profile.save());
                    },
                  ),
                ],
                const SizedBox(height: 26),
                const MenuSection('Feel & sound'),
                const SizedBox(height: 12),
                MenuToggle(
                  title: 'Sound Effects',
                  icon: Icons.graphic_eq_rounded,
                  subtitle: 'Shots, lasers, rewards, and game cues',
                  value: profile.sound,
                  onChanged: (v) {
                    update(() => profile.sound = v);
                    syncMusic();
                    unawaited(profile.save());
                  },
                ),
                if (InfiniteMusic.bundled)
                  MenuToggle(
                    title: 'Music',
                    icon: Icons.music_note_rounded,
                    subtitle: 'Background soundtrack',
                    value: profile.music,
                    onChanged: (v) {
                      update(() => profile.music = v);
                      syncMusic();
                      unawaited(profile.save());
                    },
                  ),
                MenuToggle(
                  title: 'Haptic feedback',
                  icon: Icons.vibration_rounded,
                  subtitle: 'Feel targets and impacts',
                  value: profile.haptics,
                  onChanged: (v) {
                    update(() => profile.haptics = v);
                    unawaited(profile.save());
                  },
                ),
                if (InfiniteMusic.bundled)
                  MenuAction(
                    title: 'Music credits',
                    subtitle: 'The Complex · Kevin MacLeod',
                    icon: Icons.piano_rounded,
                    onTap: () => showMusicCredits(context),
                  ),
                const SizedBox(height: 16),
                MenuPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MenuSection('Your records'),
                      const SizedBox(height: 10),
                      Text(
                        '${profile.totalStars} Classic stars  •  ${profile.runs} runs',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Infinite best ${profile.infiniteBest}m',
                        style: const TextStyle(color: menuMint),
                      ),
                      if (!profile.available)
                        const Text(
                          'Local storage is unavailable. Records will last for this session.',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                MenuAction(
                  title: 'Goals, friends & backup',
                  icon: Icons.emoji_events_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    showClub();
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Rollrise / No rush. Just precision.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: menuMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
