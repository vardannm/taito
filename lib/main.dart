import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'board_painter.dart';
import 'game.dart';
import 'levels.dart';
import 'profile.dart';
import 'tutorial.dart';

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
  final touch = [0.0, 0.0];
  final keyboard = [0.0, 0.0];
  late final Ticker ticker;
  Duration? previous;
  double accumulator = 0;
  bool recorded = false, newBest = false;
  late bool tutorialOpen;
  PlayerProfile get profile => widget.profile;

  @override
  void initState() {
    super.initState();
    tutorialOpen = !profile.tutorialSeen;
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
        '${game.phase}/${game.target}/${game.lives}/${game.inputEpoch}';
    while (accumulator >= 1 / 120) {
      game.step(1 / 120);
      accumulator -= 1 / 120;
    }
    if (game.event != null) {
      unawaited(feedback.play(game.event!, profile));
      game.event = null;
      touch.fillRange(0, 2, 0);
      keyboard.fillRange(0, 2, 0);
    }
    if (game.finished && !recorded) {
      recorded = true;
      if (!game.practice) {
        newBest = profile.recordResult(game);
        unawaited(profile.save());
      }
    }
    frame.value++;
    if (before !=
        '${game.phase}/${game.target}/${game.lives}/${game.inputEpoch}')
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

  void start(GameMode mode) => setState(() {
    clearControls();
    recorded = newBest = false;
    game.setControlMode(profile.controlMode);
    game.start(gameMode: mode, levelNumber: profile.classicLevel);
  });
  Future<void> selectLevel() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: cream,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView.builder(
        itemCount: 30,
        itemBuilder: (context, index) => ListTile(
          leading: Text('${index + 1}'.padLeft(2, '0'), style: label()),
          title: Text(ClassicLevels.names[index]),
          subtitle: Text(
            [
              'Beginner',
              'Easy',
              'Medium',
              'Medium / Hard',
              'Hard',
              'Expert',
            ][index ~/ 5],
          ),
          selected: profile.classicLevel == index + 1,
          onTap: () {
            profile.classicLevel = index + 1;
            unawaited(profile.save());
            Navigator.pop(context);
            start(GameMode.classic);
          },
        ),
      ),
    ),
  );
  void pause() => setState(() {
    clearControls();
    game.setPaused(!game.paused);
  });
  void home() => setState(() {
    clearControls();
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
                : 520.0;
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
                                Text(
                                  'TEN HOLES. NO LIMITS.',
                                  style: label(ink.withAlpha(160)),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),
                          Expanded(
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 360 / 560,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(22),
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
                          const SizedBox(height: 12),
                          ...[
                            Text(
                              'Guide the steel ball. Chase the glow.',
                              style: TextStyle(
                                fontSize: 12,
                                color: ink.withAlpha(170),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: primary(
                                    'CLASSIC',
                                    selectLevel,
                                    trailing: '30',
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
                  game.infinite ? 'HEIGHT / METERS' : 'SCORE',
                  style: label(),
                ),
                Text(
                  game.score.toString().padLeft(5, '0'),
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
            game.infinite
                ? 'INFINITE'
                : game.practice
                ? 'PRACTICE'
                : '${game.lives} BALLS',
            style: label(),
          ),
        ],
      ),
      Text(
        game.infinite
            ? (game.dangerActive
                  ? 'RED RISING'
                  : game.hazardLabel.isNotEmpty
                  ? game.hazardLabel
                  : 'TILT TO DODGE')
            : 'L${game.level.toString().padLeft(2, '0')}  •  HOLE ${game.target.clamp(1, 10).toString().padLeft(2, '0')} / 10',
        style: label(
          game.dangerActive || game.hazardLabel.isNotEmpty ? orange : ink,
        ),
      ),
    ],
  );

  Widget playScreen(BuildContext context) => Scaffold(
    body: SafeArea(
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
        ],
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

  Widget boardOverlay() => Container(
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
                    ? 'Pure precision.'
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
                  game.infinite
                      ? game.message
                      : '${game.completed}/10 holes  •  ${game.bestStreak} best streak',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB5C5BB),
                  ),
                ),
              ] else
                const Text(
                  'Your run is right where you left it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFB5C5BB), fontSize: 12),
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
                              !game.infinite &&
                              !game.practice &&
                              game.level < 30) {
                            profile.classicLevel = game.level + 1;
                            unawaited(profile.save());
                          }
                          start(game.mode);
                        },
                  child: Text(
                    game.paused
                        ? 'RESUME RUN'
                        : game.won &&
                              !game.infinite &&
                              !game.practice &&
                              game.level < 30
                        ? 'NEXT LEVEL'
                        : 'ONE MORE RUN',
                    style: label(),
                  ),
                ),
              ),
              TextButton(
                onPressed: home,
                child: Text('BACK TO CLUB', style: label(cream.withAlpha(180))),
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
                'The board moves down continuously as you ascend. Tilt the platform to dodge approaching holes. The pace gradually increases. Score comes from height. After three seconds without steering, the red floor rises. Keep moving!',
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
              const SizedBox(height: 20),
              primary('TRY PRACTICE', () {
                Navigator.pop(context);
                start(GameMode.practice);
              }),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
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

  Future<void> showSettings() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: cream,
    showDragHandle: true,
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
                DropdownButtonFormField<ControlMode>(
                  isExpanded: true,
                  initialValue: profile.controlMode,
                  decoration: const InputDecoration(labelText: 'Control mode'),
                  items: const [
                    DropdownMenuItem(
                      value: ControlMode.twoFinger,
                      child: Text('Two-Finger Control'),
                    ),
                    DropdownMenuItem(
                      value: ControlMode.oneFinger,
                      child: Text('One-Finger Control'),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode == null) return;
                    update(() => profile.controlMode = mode);
                    game.setControlMode(mode);
                    unawaited(profile.save());
                  },
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'One finger: slide the short lower handle left or right to tilt. In Classic the platform rises automatically.',
                    style: TextStyle(fontSize: 12),
                  ),
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
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Pointer ownership stays with the grabbed pivot through crossing and release.
class PivotBoard extends StatefulWidget {
  const PivotBoard({super.key, required this.game, required this.frame});
  final BalanceGame game;
  final Listenable frame;
  @override
  State<PivotBoard> createState() => _PivotBoardState();
}

class _PivotBoardState extends State<PivotBoard> {
  final pointers = <int, int>{};
  final lastY = <int, double>{};
  int epoch = -1;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final game = widget.game;
      if (epoch != game.inputEpoch) {
        pointers.clear();
        lastY.clear();
        epoch = game.inputEpoch;
      }
      final viewport = BoardViewport(bounds.biggest);
      void release(PointerEvent event) {
        final side = pointers.remove(event.pointer);
        lastY.remove(event.pointer);
        if (side != null && side < 2) game.releasePivot(side);
      }

      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (!game.canControl) return;
          if (!viewport.rect.contains(event.localPosition)) return;
          if (epoch != game.inputEpoch) {
            pointers.clear();
            lastY.clear();
            epoch = game.inputEpoch;
          }
          if (game.oneFinger) {
            final point =
                (event.localPosition - viewport.offset) / viewport.scale;
            if (pointers.isNotEmpty ||
                (point.dy - game.controlY).abs() > 30 ||
                (point.dx - (180 + game.controlPosition * 110)).abs() > 32)
              return;
            pointers[event.pointer] = 2;
            lastY[event.pointer] = point.dx - game.controlPosition * 110;
            return;
          }
          final side = event.localPosition.dx < viewport.rect.center.dx ? 0 : 1;
          final pivot = viewport.project(
            Offset(
              side == 0 ? 20 : 340,
              game.screenY(side == 0 ? game.left : game.right),
            ),
          );
          final x = pivot.dx, y = pivot.dy;
          if ((event.localPosition.dx - x).abs() > 44 ||
              (event.localPosition.dy - y).abs() > 48 ||
              pointers.containsValue(side))
            return;
          pointers[event.pointer] = side;
          lastY[event.pointer] = event.localPosition.dy;
          game.grabPivot(side);
        },
        onPointerMove: (event) {
          final side = pointers[event.pointer];
          if (side == null || !game.canControl || epoch != game.inputEpoch)
            return;
          if (side == 2) {
            final x =
                (event.localPosition.dx - viewport.offset.dx) / viewport.scale;
            game.setControlPosition((x - lastY[event.pointer]!) / 110);
            return;
          }
          final delta =
              (event.localPosition.dy - lastY[event.pointer]!) / viewport.scale;
          lastY[event.pointer] = event.localPosition.dy;
          game.dragPivot(side, delta);
        },
        onPointerUp: release,
        onPointerCancel: release,
        child: Semantics(
          label: game.oneFinger
              ? 'Drag the short lower handle left or right to tilt'
              : 'Drag the left and right ends of the platform up or down',
          child: RepaintBoundary(
            child: CustomPaint(
              painter: BoardPainter(
                game,
                repaint: widget.frame,
                reducedMotion: MediaQuery.of(context).disableAnimations,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
    },
  );
}
