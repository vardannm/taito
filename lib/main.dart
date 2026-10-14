import 'playtest_recorder.dart';
import 'rewarded_revive_ads.dart';
import 'app_analytics.dart';
import 'privacy_policy.dart';
import 'music_credits.dart';
import 'infinite_music.dart';
export 'pivot_board.dart';
import 'pivot_board.dart';
import 'club.dart';
import 'control_options.dart';
import 'infinite_painter.dart';
import 'ball_shop.dart';
import 'ball_world.dart';
import 'daily_prize_sheet.dart';
import 'achievement_sheet.dart';
import 'infinite_progress.dart';
import 'dart:async';
import 'dart:math' as math;

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
import 'one_finger_controls.dart';
import 'boot_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: menuBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final profile = PlayerProfile();
  await profile.load();
  final analytics = await AppAnalytics.initialize();
  runApp(
    ArcadeApp(
      profile: profile,
      analytics: analytics,
      reviveAds: GoogleTestReviveAds(),
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
    this.intro = false,
  });
  final PlayerProfile profile;
  final AppAnalytics? analytics;
  final RewardedReviveAds? reviveAds;

  /// The boot animation belongs to the real launch only; tests pump this app
  /// straight into the menu rather than waiting an intro out.
  final bool intro;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'GILT • Precision Arcade',
    theme: arcadeMenuTheme(),
    // Wrapping the navigator keeps the intro above anything the menu opens.
    builder: intro
        ? (context, child) => GiltIntroGate(child: child ?? const SizedBox())
        : null,
    home: GameScreen(
      profile: profile,
      analytics: analytics,
      reviveAds: reviveAds,
    ),
  );
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.profile,
    this.analytics,
    this.reviveAds,
  });
  final PlayerProfile profile;
  final AppAnalytics? analytics;
  final RewardedReviveAds? reviveAds;
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
  List<CabinetStyle> newUnlocks = [];
  TutorialRun? tutorialRun;
  bool tutorialSheetOpen = false;
  final tutorialShopKey = GlobalKey();
  final shopOriginKey = GlobalKey();
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
        final locked = CabinetStyle.values
            .where((c) => !profile.isUnlocked(c))
            .toList();
        newBest = profile.recordResult(game);
        newUnlocks = locked.where(profile.isUnlocked).toList();
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
    if (!mounted || game.runSerial != serial) return;
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
    if (!mounted ||
        !identical(game, rewardedGame) ||
        game.runSerial != serial) {
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
    if ((!tutorialActive && !playArmed && game.waitingForInput) ||
        (tutorialActive &&
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
    game.analogSensitivity = profile.analogSensitivity;
    game.twoFingerSensitivity = profile.twoFingerSensitivity;
    profile.applyInfiniteStart(game, tutorial: tutorialActive);
    newUnlocks = [];
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: menuBackground,
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
            allLevelsUnlocked: profile.temporaryLevelAccess,
            controlMode: profile.controlMode,
            recordForControl: (number, mode) =>
                profile.levelRecord(number, mode),
            onControlChanged: (mode) {
              setState(() {
                profile.controlMode = mode;
                game.setControlMode(mode);
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
                        'Steer the solid head ball into numbers. Smaller balls trail below it from largest to smallest, following your turns like a snake. Matching values combine anywhere in the snake and can cascade into one bigger ball.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Collect equal or smaller numbers with the head ball. Touching a larger number ends the run: dodge the red rings! The first gate arrives at ${MergeRun.gateInterval} score. After clearing it, earn at least ${MergeRun.gateInterval} fresh points for the next; this gap grows with your main ball. Gates scale with your ball and at least double each time. Your main ball must be strictly greater than its number to pass. Matching values merge anywhere in the snake. Play continues beyond 2048.',
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
        (shopOriginKey.currentContext ?? tutorialShopKey.currentContext)
                ?.findRenderObject()
            as RenderBox?;
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
        if (game.waitingForInput) prepareWorld(selectedMode);
      });
  }

  /// Infinite and 2048 run to a loop; every other screen is quiet. Pausing
  /// holds the track rather than restarting it.
  static const themeTrack = 'audio/theme_dark.wav';
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
        (game.infinite || game.merging) &&
        profile.music &&
        game.started &&
        !game.finished;
    unawaited(
      feedback.updateMusic(
        track: wants
            ? (game.infinite ? InfiniteMusic.asset : themeTrack)
            : null,
        playing: !game.paused && !game.waitingForInput && !returning,
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
    newUnlocks = [];
    game.setControlMode(controlForMode(arcadeModes[index]));
    game.cabinet = profile.cabinet;
    profile.applySurvivalUpgrades(game);
    game.cosmetic = profile.selectedBall;
    game.platformStyle = profile.selectedPlatform;
    game.cabinet = profile.cabinet;
    game.analogSensitivity = profile.analogSensitivity;
    game.twoFingerSensitivity = profile.twoFingerSensitivity;
    profile.applyInfiniteStart(game, tutorial: tutorialActive);
    game.start(
      gameMode: arcadeModes[index],
      levelNumber: worldLevel(index),
      waitForInput: true,
    );
    game.inputLocked = !tutorialActive;
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
      bottomInset: guidedPlay || objective
          ? OneFingerControls.height + 12
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
                  eyebrow: 'EXPLORE GILT',
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

  Widget boardChrome() {
    if (!tutorialActive && game.waitingForInput) {
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
                        'Level ${game.level} · ${ClassicLevels.definition(game.level).name}',
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
                            label:
                                '${game.lives} of ${game.heartCapacity} hearts remaining',
                            excludeSemantics: true,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < game.heartCapacity; i++)
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
                                  '${game.score}',
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
    Color(0xFFE4E3F1),
  ];

  String worldTitle(int index) => switch (index) {
    0 => 'Infinite',
    1 => 'Classic',
    _ => '2048 Merge',
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
    ControlMode.oneFinger => 'Drag the thumb area to play',
    ControlMode.twoFinger => 'Move a platform end to play',
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
    if (game.oneFinger)
      return point.dy < board.size.height - OneFingerControls.height;
    if (game.bottomControls) return true;
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

  final Map<int, BalanceGame> _themedPreviews = {};

  /// Frozen boards reflect the equipped ball, without advancing any simulation.
  BalanceGame themedPreview(int index) {
    final existing = _themedPreviews[index];
    if (existing != null &&
        existing.level == worldLevel(index) &&
        existing.cosmetic == profile.selectedBall &&
        existing.cabinet == profile.cabinet &&
        existing.controlMode == controlForMode(arcadeModes[index]) &&
        existing.platformStyle == profile.selectedPlatform)
      return existing;
    return _themedPreviews[index] = BalanceGame(seed: index + 1)
      ..cosmetic = profile.selectedBall
      ..cabinet = profile.cabinet
      ..platformStyle = profile.selectedPlatform
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
                (!tutorialActive && !playArmed && game.waitingForInput),
            child: PivotBoard(
              key: boardKey,
              game: game,
              frame: frame,
              fillWidth: expansion,
              overlay: boardChrome(),
              showHint:
                  (tutorialActive || playArmed) &&
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
                  if (game.oneFinger)
                    const SizedBox(height: OneFingerControls.height),
                ],
              ),
            ),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: tutorialActive ? 1 : 1 - chromeOpacity,
          child: LayoutBuilder(
            builder: (context, bounds) => OverflowBox(
              minHeight: math.max(200, bounds.maxHeight),
              maxHeight: math.max(200, bounds.maxHeight),
              child: board,
            ),
          ),
        ),
        if (!tutorialActive && chromeOpacity > 0)
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

  /// Selection shortcuts share a dock below the unchanged world carousel.
  Widget menuDock(
    String title,
    IconData icon,
    String tooltip,
    VoidCallback action, {
    Key? targetKey,
    Key? tapKey,
  }) => Expanded(
    child: Tooltip(
      message: tooltip,
      child: Material(
        key: targetKey,
        color: menuPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: menuLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: tapKey,
          onTap: carouselMoving ? null : action,
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: menuGold),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: menuText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget shopButton() => menuDock(
    'Shop',
    Icons.storefront_rounded,
    'Gear shop',
    showBallShop,
    targetKey: tutorialShopKey,
    tapKey: game.waitingForInput ? const ValueKey('board-shop') : null,
  );

  Widget tutorialSelectionHeader(double page) {
    final index = page.round().clamp(0, arcadeModes.length - 1);
    final distance = page - index;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GILT',
                      style: TextStyle(
                        color: menuText,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    Text(
                      'PRECISION ARCADE',
                      style: TextStyle(
                        color: menuMuted,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!tutorialActive)
              Flexible(
                child: MenuPill(
                  profile.unlimitedCoins ? '∞' : '${profile.wallet}',
                  icon: Icons.toll_rounded,
                ),
              ),
            const SizedBox(width: 10),
            MenuIconButton(
              icon: Icons.redeem_rounded,
              tooltip: 'Daily prizes',
              badge: profile.dailyPrizes.canClaim(DateTime.now()),
              onPressed: carouselMoving ? null : showDailyPrizes,
            ),
            if (tutorialActive &&
                game.waitingForInput &&
                !returning &&
                [
                  TutorialStep.levels,
                  TutorialStep.level1,
                  TutorialStep.classicPlay,
                ].contains(tutorialStep))
              MenuIconButton(
                key: tutorialLevelsKey,
                icon: Icons.grid_view_rounded,
                tooltip: 'Classic levels',
                onPressed: selectLevel,
              ),
            if (tutorialActive &&
                game.waitingForInput &&
                !returning &&
                tutorialStep == TutorialStep.dailyChallenge)
              MenuIconButton(
                key: tutorialDailyKey,
                icon: Icons.today_outlined,
                tooltip: 'Daily Challenge',
                onPressed: () {
                  skipTutorial();
                  showDaily();
                },
              ),
          ],
        ),
        Expanded(
          child: Transform.translate(
            offset: Offset(reduced ? 0 : distance * -28, 0),
            child: Opacity(
              opacity: reduced ? 1 : 1 - distance.abs() * .8,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            worldTitle(index),
                            key: const ValueKey('selected-mode-title'),
                            style: TextStyle(
                              color: menuText,
                              fontSize: MediaQuery.sizeOf(context).height < 650
                                  ? 29
                                  : 38,
                              height: 1.05,
                              letterSpacing: -1.3,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            worldSubtitle(index),
                            key: const ValueKey('selected-mode-subtitle'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: menuMuted,
                              fontSize: 9,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: menuGold.withAlpha(70)),
                    ),
                    child: Center(
                      child: Text(
                        '0${index + 1}',
                        style: const TextStyle(
                          color: menuGold,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  Widget tutorialCarouselFooter(double page) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous mode',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 30,
                ),
                onPressed: selectedMode > 0 && !carouselMoving
                    ? () => carouselKey.currentState?.select(selectedMode - 1)
                    : null,
                icon: Icon(
                  Icons.chevron_left_rounded,
                  color: selectedMode > 0 ? menuMuted : menuLine,
                  size: 20,
                ),
              ),
              for (var index = 0; index < arcadeModes.length; index++)
                Expanded(
                  child: Semantics(
                    label:
                        '${worldTitle(index)}, ${index + 1} of ${arcadeModes.length}',
                    selected: selectedMode == index,
                    button: true,
                    child: GestureDetector(
                      key: ValueKey('mode-$index'),
                      behavior: HitTestBehavior.opaque,
                      onTap: carouselMoving
                          ? null
                          : () => carouselKey.currentState?.select(index),
                      child: Container(
                        height: 30,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            Colors.transparent,
                            menuGold.withAlpha(22),
                            1 - (page - index).abs().clamp(0.0, 1.0),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                ['Infinite', 'Classic', '2048'][index],
                                style: TextStyle(
                                  color: selectedMode == index
                                      ? menuGold
                                      : menuMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Next mode',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 30,
                ),
                onPressed:
                    selectedMode < arcadeModes.length - 1 && !carouselMoving
                    ? () => carouselKey.currentState?.select(selectedMode + 1)
                    : null,
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: selectedMode < 2 ? menuMuted : menuLine,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            shopButton(),
            const SizedBox(width: 8),
            menuDock('Arcade', Icons.apps_rounded, 'Modes', showModes),
            const SizedBox(width: 8),
            menuDock('Options', Icons.tune_rounded, 'Settings', showSettings),
          ],
        ),
      ],
    ),
  );

  Widget bottomInput(bool ready, double controlHeight) => SizedBox(
    key: analogKey,
    height: controlHeight,
    child: IgnorePointer(
      ignoring:
          carouselMoving ||
          (!tutorialActive && !playArmed && game.waitingForInput),
      child: Opacity(
        opacity: tutorialActive ? 1 : 1 - chromeOpacity,
        child: LayoutBuilder(
          builder: (context, bounds) => Stack(
            fit: StackFit.expand,
            children: [
              if (game.tiltLift)
                TiltLiftControls(game: game, frame: frame)
              else
                AnalogControls(game: game, frame: frame),
              if ((tutorialActive && ready ||
                      playArmed && game.waitingForInput) &&
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

  Widget selectionHeader(double page) {
    if (tutorialActive) return tutorialSelectionHeader(page);
    return Row(
      children: [
        MenuQuietButton(
          icon: Icons.emoji_events_outlined,
          tooltip: 'Achievements',
          badge: profile.achievementsReady > 0,
          onPressed: carouselMoving ? null : showAchievements,
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
                    'GILT',
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      color: menuText,
                      fontSize: 37,
                      letterSpacing: 9,
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

  Widget carouselFooter(double page) {
    if (tutorialActive) return tutorialCarouselFooter(page);
    final index = page.round().clamp(0, arcadeModes.length - 1);
    final classic = index == 1;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: compactMenu ? 26 : 34,
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
                            message: ClassicLevels.definition(
                              worldLevel(index),
                            ).name,
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
                        onPressed: carouselMoving ? null : showBallShop,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MenuActionButton(
                      label: 'Arcade',
                      icon: Icons.grid_view_rounded,
                      tooltip: 'Modes',
                      onPressed: carouselMoving ? null : showModes,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PremiumPlayButton(
                height: compactMenu ? 56 : 64,
                key: game.waitingForInput ? const ValueKey('menu-play') : null,
                onPressed: carouselMoving || !game.waitingForInput || returning
                    ? null
                    : playSelectedWorld,
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
          !tutorialActive && !playArmed && game.waitingForInput && !returning,
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
        controlInset: game.oneFinger ? OneFingerControls.height : 0,
        acceptSwipe: acceptsWorldSwipe,
        onMoving: (moving) => setState(() {
          carouselMoving = moving;
          game.inputLocked = moving || (!tutorialActive && !playArmed);
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
          final menuHeaderHeight = !tutorialActive
              ? compactMenu
                    ? 64.0
                    : 88.0
              : MediaQuery.sizeOf(context).height < 650 &&
                    MediaQuery.textScalerOf(context).scale(10) <= 10
              ? 104.0
              : 144.0;
          final headerHeight = menuHeaderHeight * (1 - expansion);
          final menuFooterHeight = tutorialActive
              ? 84.0
              : compactMenu
              ? 284.0
              : 310.0;
          final menuGap = !tutorialActive && compactMenu ? 4.0 : 12.0;
          final controlHeight = game.bottomControls
              ? (MediaQuery.sizeOf(context).height * .19).clamp(104.0, 140.0)
              : 0.0;
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
                              painter: tutorialActive
                                  ? MenuBackdrop()
                                  : PremiumMenuBackdrop(
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
                                              animation: tutorialActive
                                                  ? const AlwaysStoppedAnimation(
                                                      1.0,
                                                    )
                                                  : reveal,
                                              child: selectionHeader(page),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: menuGap * (1 - expansion),
                                  bottom:
                                      menuGap * (1 - expansion) +
                                      (tutorialActive
                                          ? 0
                                          : controlHeight * expansion),
                                ),
                                child: worlds,
                              ),
                            ),
                            SizedBox(
                              height: menuFooterHeight * (1 - expansion),
                              child: OverflowBox(
                                minHeight: menuFooterHeight,
                                maxHeight: menuFooterHeight,
                                alignment: Alignment.bottomCenter,
                                child: IgnorePointer(
                                  ignoring: !ready,
                                  child: ExcludeSemantics(
                                    excluding: !ready,
                                    child: Opacity(
                                      opacity: chromeOpacity,

                                      child: MenuReveal(
                                        animation: tutorialActive
                                            ? const AlwaysStoppedAnimation(1.0)
                                            : reveal,
                                        child: carouselFooter(page),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (tutorialActive && game.bottomControls)
                              SizedBox(height: controlHeight),
                          ],
                        ),
                        if (game.bottomControls)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: tutorialActive
                                ? 0
                                : menuFooterHeight * (1 - expansion),
                            child: bottomInput(ready, controlHeight),
                          ),
                      ],
                    ),
                  ),
                  if (!returning &&
                      resumeSeconds == 0 &&
                      (game.paused || game.finished))
                    SafeArea(
                      key: const ValueKey('run-overlay'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: boardOverlay(),
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
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
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
            '${game.coinsCollected} → ${game.coinsCollected * 2} coins.\n'
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
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_rounded, color: orange, size: 52),
              const SizedBox(height: 16),
              const Text(
                'One more chance?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cream,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${game.score} points · ${game.metres}m',
                style: label(brass),
              ),
              const SizedBox(height: 16),
              const Text(
                'Watch an ad to get 1 heart and continue this run.\nOne revive per run.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cream, height: 1.5),
              ),
              if (reviveError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    reviveError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: brass, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 24),
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
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
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
                  label: Text(adBusy ? 'Opening ad…' : 'Watch ad · +1 heart'),
                ),
              ),
              const SizedBox(height: 10),
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
      ),
    ),
  );

  Widget boardOverlay() => offeringRevive
      ? reviveOffer()
      : game.merging && game.finished
      ? MergeResult(
          run: game.mergeRun,
          newBest: newBest,
          onRetry: () => start(GameMode.merge2048),
          onHome: home,
        )
      : briefing
      ? FinaleBriefing(game: game, onPlay: pause)
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
                                    ? '${game.metres}m · Best combo x${game.survival.bestCombo}\n${game.message}  ${game.coinsCollected * (profile.infiniteCoinsDoubled(game) ? 2 : 1)} coins saved.'
                                    : game.message)
                              : '${game.completed}/10 holes  •  ${game.bestStreak} best streak',
                          style: const TextStyle(
                            fontSize: 12,
                            color: menuMuted,
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
                            unlocks: newUnlocks,
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
                          () => start(game.mode, challengeDate: game.dailyDate),
                        ),
                      // A paused run can be dropped for a fresh one in any mode.
                      if (game.paused)
                        pauseAction(
                          'RESTART RUN',
                          Icons.restart_alt_rounded,
                          () => start(game.mode, challengeDate: game.dailyDate),
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
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MenuHeading('A game of balance.', eyebrow: 'HOW TO PLAY'),
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
                'Infinite begins with ${profile.startingHearts} hearts. Upgrade starting hearts and pickup durations in the Gear Shop. Laser-wall sections arrive from time to time: the traps stop and wide laser walls come down instead, so steer through their openings. A hit costs a heart and resets your combo; the ball and platform blink for 2.5 seconds of protection while you keep steering from the same position. Gold crystals build combos up to x10; violet and midnight tiers build toward electric cyan at x9 and a golden maximum at x10. Blue shields protect for ${profile.shieldDuration} seconds. Red-and-blue magnets collect nearby coins, combo crystals, shields and hearts for ${profile.magnetDuration} seconds. Rare hearts restore a life. Keep steering to escape the rising red floor.',
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
              const Text(
                'Deep in Infinite, five new visitors unlock: the beetle at 2,600m marks an acid landing; the cricket at 3,100m bounces one pellet off a wall; the moth at 3,600m fires curved dust streams; the scorpion at 4,100m charges a laser along a locked aim line, then holds the beam for 1.5 seconds; and the seed spitter at 4,600m splits a seed into three. Watch their aim markers before they fire. These attacks take turns, and stop during breathing stretches and laser mazes.',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 20),
              guideRow(
                '07',
                'Face the second tier.',
                'Five bosses appear as your Infinite score grows. Sky Warden fires fixed lasers, Storm Colossus throws bouncing orbs and laser mines, and Eclipse Seraph fires laser curtains and comets. Between 850,000 and 950,000 points, Prism Reaver fires moving lasers and spinning rotors. Between 1,200,000 and 1,350,000 points, Venom Crown sends dense lime-green and acid-yellow bullet walls through a moving opening. Its walls change speed and the final corridor gets narrower. Read the warning trails and keep moving. Each boss lasts 28 active seconds.',
              ),
              guideRow(
                '08',
                'Three ways to master it.',
                'Earn a star for finishing, one for a finish without misses, and one for beating the active-time target in the HUD. Pauses and ball resets do not count. Stars and records are saved separately for each control mode.',
              ),
              guideRow(
                '09',
                'Take the detour.',
                'Classic and Daily brass coins are worth 250 points. Infinite coins save to your local wallet immediately. Open the Gear Shop for balls and platforms that add Infinite point multipliers. Selected balls also have permanent magnets with different collection ranges in Infinite; handling stays the same. Each coin can be collected once. Classic stars unlock cabinet styles with identical handling.',
              ),
              guideRow(
                '10',
                'Return for the daily.',
                'The daily board changes at midnight UTC. Retry its fixed layout to improve your local record. Infinite pace rises smoothly from x1 to x5, increasing speed, distance points and obstacle frequency. Every run starts gently at x1; pace rises gradually over longer distances. Combo crystals award 50 × combo × pace points. Missing a crystal keeps your combo; losing a heart resets it.',
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
    backgroundColor: menuBackground,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .9,
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, update) => MenuSurface(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MenuHeading(
                  'Options',
                  eyebrow: 'YOUR ARCADE. YOUR WAY.',
                  trailing: MenuIconButton(
                    icon: Icons.close,
                    tooltip: 'Close settings',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
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
                  subtitle: 'How GILT handles your data',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyPage(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const MenuSection('Choose your controls'),
                const SizedBox(height: 12),
                ControlOptions(
                  value: profile.controlMode,
                  onChanged: (mode) {
                    update(() => profile.controlMode = mode);
                    setState(() {
                      game.setControlMode(controlForMode(game.mode));
                    });
                    unawaited(profile.save());
                  },
                ),
                const SizedBox(height: 14),
                const MenuSection('Fine tune your movement'),
                const SizedBox(height: 12),
                MenuPanel(
                  child: Column(
                    children: [
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
                        'Two-Finger control: 1.0 follows your fingers fully. Lower values make smaller movements. Default: 1.0.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: menuMuted,
                        ),
                      ),
                    ],
                  ),
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
                MenuAction(
                  title: 'Music credits',
                  subtitle: 'Infinite & 2048 · Kevin MacLeod',
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
                        'Classic best ${profile.best}  •  ${profile.runs} runs',
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
                  'GILT / No rush. Just precision.',
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
