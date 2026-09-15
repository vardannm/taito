import 'playtest_recorder.dart';
export 'pivot_board.dart';
import 'pivot_board.dart';
import 'club.dart';
import 'control_options.dart';
import 'infinite_painter.dart';
import 'ball_cosmetics.dart';
import 'ball_shop.dart';
import 'infinite_progress.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'board_painter.dart';
import 'game.dart';
import 'levels.dart';
import 'level_picker.dart';
import 'profile.dart';
import 'tutorial.dart';
import 'rewards.dart';
import 'mastery_widgets.dart';
import 'analog_controls.dart';
import 'merge_widgets.dart';
import 'merge.dart';
import 'laser_maze.dart';
import 'laser_maze_widgets.dart';
import 'maze_editor.dart';

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
  runApp(ArcadeApp(profile: profile));
}

class ArcadeApp extends StatelessWidget {
  const ArcadeApp({super.key, required this.profile});
  final PlayerProfile profile;
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
    home: GameScreen(profile: profile),
  );
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.profile});
  final PlayerProfile profile;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final game = BalanceGame();
  final frame = ValueNotifier<int>(0);
  final feedback = GameFeedback();
  final playtest = PlaytestRecorder();
  final touch = [0.0, 0.0];
  final keyboard = [0.0, 0.0];
  late final Ticker ticker;
  Duration? previous;
  double accumulator = 0;
  bool recorded = false, newBest = false, briefing = false;
  List<CabinetStyle> newUnlocks = [];
  late bool tutorialOpen;
  bool commandOpen = false;
  PlayerProfile get profile => widget.profile;

  @override
  void initState() {
    super.initState();
    tutorialOpen = !profile.tutorialSeen;
    game.cabinet = profile.cabinet;
    game.cosmetic = profile.selectedBall;
    game.platformStyle = profile.selectedPlatform;
    game.analogSensitivity = profile.analogSensitivity;
    game.twoFingerSensitivity = profile.twoFingerSensitivity;
    game.infiniteStartingPace = InfiniteTuning.startingPace(
      profile.infiniteBest,
    );
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(onKey);
    ticker = createTicker(tick)..start();
  }

  void tick(Duration now) {
    final delta = previous == null
        ? 0.0
        : (now - previous!).inMicroseconds / 1000000;
    previous = now;
    accumulator += math.min(delta, .05);
    final before =
        '${game.phase}/${game.target}/${game.lives}/${game.inputEpoch}/$recorded';
    while (accumulator >= 1 / 120) {
      game.step(1 / 120);
      accumulator -= 1 / 120;
    }
    profile.bankCoins(game);
    if (game.event != null) {
      playtest.record(game.event!.name, {
        "mode": game.mode.name,
        "target": game.completed,
        "misses": game.misses,
      });
      unawaited(feedback.play(game.event!, profile));
      if (game.event != GameEvent.coin && game.event != GameEvent.merge) {
        touch.fillRange(0, 2, 0);
        keyboard.fillRange(0, 2, 0);
      }
      game.event = null;
    }
    if (game.finished && !recorded) {
      recorded = true;
      playtest.record("run_finished", {
        "mode": game.mode.name,
        "won": game.won,
        "score": game.score,
        "activeSeconds": game.elapsed,
      });
      if (!game.practice) {
        final locked = CabinetStyle.values
            .where((c) => !profile.isUnlocked(c))
            .toList();
        newBest = profile.recordResult(game);
        newUnlocks = locked.where(profile.isUnlocked).toList();
        unawaited(profile.save());
      }
    }
    frame.value++;
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
    if (commandOpen) return false;
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
        !game.finished) {
      pause();
      return true;
    }
    if (!controlKeys.contains(key)) return false;
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
          : mode == GameMode.mazeEndless
          ? 1
          : profile.classicLevel,
      challengeDate: challengeDate,
    );
    briefing = game.finale;
    if (briefing) game.setPaused(true);
  });
  Future<void> selectLevel() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: cream,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .84,
      child: SafeArea(
        child: LevelPicker(
          selected: profile.classicLevel,
          records: {
            for (var i = 1; i <= ClassicLevels.count; i++)
              i: profile.levelRecord(i),
          },
          controlLabel: profile.controlMode.label,
          onSelected: (number) {
            profile.classicLevel = number;
            unawaited(profile.save());
            Navigator.pop(context);
            start(GameMode.classic);
          },
        ),
      ),
    ),
  );
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
          endlessBest: profile.mazeEndlessBest,
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
          onEndless: () {
            Navigator.pop(context);
            start(GameMode.mazeEndless);
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

  Future<void> showCabinet() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: cream,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .84,
        child: StatefulBuilder(
          builder: (context, updateSheet) => CabinetPicker(
            profile: profile,
            onSelected: (style) {
              if (!profile.selectCabinet(style)) return;
              setState(() => game.cabinet = style);
              updateSheet(() {});
              unawaited(profile.save());
            },
          ),
        ),
      ),
    ),
  );

  Future<void> showBallShop() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cream,
      builder: (_) => FractionallySizedBox(
        heightFactor: .85,
        child: BallShop(profile: profile),
      ),
    );
    if (mounted)
      setState(() {
        game.cosmetic = profile.selectedBall;
        game.platformStyle = profile.selectedPlatform;
      });
  }

  void pause() => setState(() {
    briefing = false;
    clearControls();
    game.setPaused(!game.paused);
  });
  void home() => setState(() {
    clearControls();
    profile.bankCoins(game);
    game.home();
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && game.started && !game.finished) {
      setState(() {
        clearControls();
        game.setPaused(true);
      });
    }
  }

  @override
  void dispose() {
    profile.bankCoins(game);
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(onKey);
    ticker.dispose();
    frame.dispose();
    feedback.dispose();
    super.dispose();
  }

  TextStyle label([Color color = ink]) => TextStyle(
    fontSize: 10,
    letterSpacing: 1.8,
    fontWeight: FontWeight.w700,
    color: color,
  );

  @override
  Widget build(BuildContext context) {
    if (tutorialOpen) {
      return FirstPlayTutorial(
        control: profile.controlMode,
        onLessonComplete: (step) => playtest.record("tutorial_step", {
          "step": step,
          "control": profile.controlMode.name,
        }),
        onExit: (completed) => playtest.record(
          completed ? "tutorial_completed" : "tutorial_skipped",
        ),
        analogSensitivity: profile.analogSensitivity,
        twoFingerSensitivity: profile.twoFingerSensitivity,
        onControlChanged: (mode) {
          playtest.record("tutorial_control_changed", {"control": mode.name});
          profile.controlMode = mode;
          unawaited(profile.save());
        },
        onDone: () {
          unawaited(profile.completeTutorial());
          setState(() => tutorialOpen = false);
        },
      );
    }
    if (game.started) return playScreen(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            // Preserve usable controls in landscape and with larger accessibility text.
            final minHeight = MediaQuery.textScalerOf(context).scale(1) > 1.3
                ? 800.0
                : 580.0;
            final height = math.max(viewport.maxHeight, minHeight);
            return SingleChildScrollView(
              physics: viewport.maxHeight < minHeight
                  ? null
                  : const NeverScrollableScrollPhysics(),
              child: SizedBox(
                height: height,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Column(
                        children: [
                          SizedBox(height: height > 760 ? 16 : 8),
                          header(),
                          SizedBox(height: height > 760 ? 22 : 12),
                          ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'A little tilt.\nA lot of nerve.',
                                      style: TextStyle(
                                        fontSize: 35,
                                        fontWeight: FontWeight.w800,
                                        height: 1.05,
                                        letterSpacing: -1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Icon(
                                        Icons.stars_rounded,
                                        color: orange.withAlpha(230),
                                        size: 24,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        'CLASSIC BEST',
                                        style: label(ink.withAlpha(135))
                                            .copyWith(
                                              fontSize: 8,
                                              letterSpacing: 1,
                                            ),
                                      ),
                                      Text(
                                        profile.best.toString().padLeft(5, '0'),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    profile.totalStars == 0
                                        ? 'TEN HOLES. NO LIMITS.'
                                        : '${profile.totalStars} / 150 CLASSIC STARS',
                                    style: label(ink.withAlpha(160)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),
                          if (viewport.maxHeight >= 700)
                            Expanded(
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 360 / 560,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: ink.withAlpha(30),
                                              blurRadius: 18,
                                              offset: const Offset(0, 9),
                                            ),
                                          ],
                                        ),
                                        child: RepaintBoundary(
                                          child: CustomPaint(
                                            painter: BoardPainter(
                                              game,
                                              repaint: frame,
                                              reducedMotion: MediaQuery.of(
                                                context,
                                              ).disableAnimations,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (game.paused || game.finished)
                                        boardOverlay(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (viewport.maxHeight < 700) const Spacer(),
                          const SizedBox(height: 12),
                          ...[
                            TextButton.icon(
                              onPressed: showClub,
                              icon: const Icon(Icons.flag_outlined, size: 18),
                              label: Text(
                                'NEXT: ${NextGoal.forProfile(profile).title}',
                                maxLines: 2,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: primary(
                                    'CLASSIC',
                                    selectLevel,
                                    trailing: '${ClassicLevels.count}',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: primary(
                                    'INFINITE',
                                    () => start(GameMode.infinite),
                                    trailing: '∞',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: showMerge,
                                icon: const Icon(Icons.auto_awesome, size: 17),
                                label: const Text(
                                  '2048  /  MERGE',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: selectMaze,
                                icon: const Icon(Icons.route_rounded, size: 17),
                                label: const Text(
                                  'LASER MAZE',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: showDaily,
                                    icon: const Icon(
                                      Icons.today_outlined,
                                      size: 17,
                                    ),
                                    label: const Text(
                                      'DAILY',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: showBallShop,
                                    icon: const Icon(
                                      Icons.palette_outlined,
                                      size: 17,
                                    ),
                                    label: const Text(
                                      'GEAR SHOP',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () => start(GameMode.practice),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                  ),
                                  child: Text(
                                    'PRACTICE',
                                    style: label().copyWith(fontSize: 9),
                                  ),
                                ),
                                TextButton(
                                  onPressed: showGuide,
                                  child: Text(
                                    'HOW TO PLAY',
                                    style: label().copyWith(
                                      fontSize: 9,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget header() => Row(
    children: [
      const Icon(Icons.adjust, size: 26, color: orange),
      const SizedBox(width: 8),
      const Text(
        'GILT',
        style: TextStyle(
          fontSize: 26,
          letterSpacing: 5,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          'MECHANICAL\nARCADE CLUB',
          style: label(
            ink.withAlpha(130),
          ).copyWith(fontSize: 8, height: 1.5, letterSpacing: 1.5),
        ),
      ),
      IconButton(
        tooltip: game.started && !game.finished
            ? (game.paused ? 'Resume' : 'Pause')
            : 'Settings',
        onPressed: game.started && !game.finished ? pause : showSettings,
        style: IconButton.styleFrom(side: BorderSide(color: ink.withAlpha(45))),
        icon: Icon(
          game.started && !game.finished
              ? (game.paused ? Icons.play_arrow_rounded : Icons.pause_rounded)
              : Icons.tune_rounded,
          size: 20,
        ),
      ),
    ],
  );

  Widget scoreboard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.mazeEndless
                      ? 'LASER MAZE / ENDLESS'
                      : game.maze
                      ? 'LASER MAZE / ROUTE ${game.level}'
                      : game.merging
                      ? '2048 / SCORE'
                      : game.infinite
                      ? 'INFINITE / POINTS'
                      : 'SCORE',
                  style: label(),
                ),
                Text(
                  game.mazeEndless
                      ? '${game.score}m'
                      : game.maze
                      ? '${game.score}%'
                      : game.score.toString().padLeft(5, '0'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Text(
            game.maze
                ? formatRunTime(game.elapsed)
                : game.merging
                ? 'TOP ${formatMergeNumber(game.mergeRun.highest)}'
                : game.infinite
                ? '${game.metres}m'
                : game.practice
                ? 'PRACTICE'
                : '${game.lives} BALLS',
            style: label(),
          ),
        ],
      ),
      Text(
        game.maze
            ? game.mazeRun.name.toUpperCase()
            : game.merging
            ? 'MERGE SMALL · DODGE BIG'
            : game.infinite
            ? (game.dangerActive
                  ? 'RED RISING'
                  : game.hazardLabel.isNotEmpty
                  ? game.hazardLabel
                  : game.section.label)
            : '${game.daily ? 'DAILY' : 'L${game.level.toString().padLeft(2, '0')}'}  •  HOLE ${game.target.clamp(1, 10).toString().padLeft(2, '0')} / 10',
        style: label(
          game.dangerActive || game.hazardLabel.isNotEmpty ? orange : ink,
        ),
      ),
      if (game.infinite) ...[
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              label: '${game.lives} of 3 hearts',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(
                      i < game.lives ? Icons.favorite : Icons.favorite_border,
                      color: orange,
                      size: 16,
                    ),
                ],
              ),
            ),
            Text(
              'PACE x${game.paceLevel} · COMBO x${game.survival.combo}',
              style: label(),
            ),
          ],
        ),
        SizedBox(
          height: 14,
          child: Text(
            game.survival.noticeTime > 0
                ? game.survival.notice
                : 'GEAR x${formatBoost(game.survival.scoreBoost)} · Gold: combo · Blue: shield · Red: heart',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: ink),
          ),
        ),
        if (game.survival.protected)
          Text(
            game.survival.shield > 0
                ? 'SHIELD ${game.survival.shield.ceil()}s'
                : 'RECOVERY ${game.survival.recovery.ceil()}s',
            style: label(ink),
          ),
      ],
      if (!game.infinite && !game.practice && !game.merging && !game.maze)
        Text(
          '${formatRunTime(game.elapsed)} / ${formatRunTime(game.targetTime)}  ·  ${game.coinsCollected}/${game.coins.length} COINS',
          style: TextStyle(fontSize: 10, color: ink.withAlpha(175)),
        ),
      if (game.finale)
        Text(
          game.hazardLabel.isEmpty
              ? 'FINALE · ${game.finaleTitle}'
              : game.hazardLabel,
          style: const TextStyle(
            fontSize: 10,
            color: orange,
            fontWeight: FontWeight.w700,
          ),
        ),
    ],
  );

  Widget playScreen(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        if (game.infinite)
          RepaintBoundary(
            child: CustomPaint(
              painter: InfiniteBackdropPainter(
                game,
                reducedMotion: MediaQuery.disableAnimationsOf(context),
                repaint: frame,
              ),
            ),
          ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedBuilder(
                        animation: frame,
                        builder: (context, _) => scoreboard(),
                      ),
                    ),
                    IconButton(
                      tooltip: game.paused ? 'Resume' : 'Pause',
                      onPressed: pause,
                      icon: Icon(
                        game.paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              if (game.merging)
                AnimatedBuilder(
                  animation: frame,
                  builder: (context, _) => MergeStatus(run: game.mergeRun),
                ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PivotBoard(
                      key: ValueKey(game.inputEpoch),
                      game: game,
                      frame: frame,
                    ),
                    if (game.paused || game.finished) boardOverlay(),
                  ],
                ),
              ),
              if (game.analog)
                SizedBox(
                  height: (MediaQuery.sizeOf(context).height * .19).clamp(
                    104.0,
                    140.0,
                  ),
                  child: AnalogControls(game: game, frame: frame),
                ),
            ],
          ),
        ),
      ],
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
          onNext: !game.mazeEndless && game.level < LaserMazeRoute.count
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
                                  profile.classicLevel = game.level + 1;
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
                              ? 'NEXT LEVEL'
                              : 'ONE MORE RUN',
                          style: label(),
                        ),
                      ),
                    ),
                    if (game.won && !game.practice)
                      TextButton(
                        onPressed: () =>
                            start(game.mode, challengeDate: game.dailyDate),
                        child: Text('RETRY THIS BOARD', style: label(brass)),
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
                'Infinite begins with three hearts. A hit costs a heart and resets your combo; a nearby safe landing gives 2.5 seconds of protection while preserving the course. Gold crystals build combos up to x5. Blue shields protect for 10 seconds. Rare hearts restore a life. Keep steering to escape the rising red floor.',
              ),
              const Text(
                'Desktop: W / S = left end. ↑ / ↓ = right end. Esc = pause.',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
              guideRow(
                '05',
                'Watch the warnings.',
                'Infinite starts with open spaces and builds difficulty with height. Warning holes unlock at 180m, moving holes at 350m, lasers at 600m and platform gaps at 900m. Move away from red warnings before they activate.',
              ),
              guideRow(
                '06',
                'Stay out of the web.',
                'Classic levels 31–50 have slow patrolling spiders. Enter a marked territory and its spider chases you. Contact ends the run immediately. Each successful target resets the spiders.',
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
                'Classic and Daily brass coins are worth 250 points. Infinite and Laser Endless coins save to your local wallet immediately. Open the Gear Shop for balls and platforms that add Infinite point multipliers; handling stays the same. Each coin can be collected once. Classic stars unlock cabinet styles with identical handling.',
              ),
              guideRow(
                '09',
                'Return for the daily.',
                'The daily board changes at midnight UTC. Retry its fixed layout to improve your local record. Infinite pace rises smoothly from x1 to x5, increasing speed, distance points and obstacle frequency. A best of 150m starts future runs at x2; 450m starts at x3. Combo crystals award 50 × combo × pace points. Missing a crystal keeps your combo; losing a heart resets it.',
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
                  playtest.record("tutorial_started", {
                    "control": profile.controlMode.name,
                  });
                  setState(() => tutorialOpen = true);
                },
                child: const Text('REPLAY QUICK TUTORIAL'),
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

  Future<void> openCommandPanel() async {
    commandOpen = true;
    clearControls();
    ticker.stop();
    try {
      await showMazeEditorCommand(
        context,
        control: profile.controlMode,
        analogSensitivity: profile.analogSensitivity,
        twoFingerSensitivity: profile.twoFingerSensitivity,
      );
    } finally {
      if (mounted) {
        commandOpen = false;
        previous = null;
        accumulator = 0;
        ticker.start();
      }
    }
  }

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
                const SizedBox(height: 14),
                ControlOptions(
                  value: profile.controlMode,
                  onChanged: (mode) {
                    update(() => profile.controlMode = mode);
                    game.setControlMode(mode);
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
                  title: const Text('Arcade sounds'),
                  value: profile.sound,
                  onChanged: (v) {
                    update(() => profile.sound = v);
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
                    showCabinet();
                  },
                  icon: const Icon(Icons.palette_outlined),
                  label: const Text('Cabinet styles'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showClub();
                  },
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('Goals, friends & backup'),
                ),
                TextButton.icon(
                  key: const ValueKey('open-command'),
                  onPressed: () {
                    Navigator.pop(context);
                    unawaited(openCommandPanel());
                  },
                  icon: const Icon(Icons.terminal, size: 18),
                  label: const Text('Command'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
