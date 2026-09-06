import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'board_painter.dart';
import 'game.dart';
import 'profile.dart';

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
  PlayerProfile get profile => widget.profile;

  @override
  void initState() {
    super.initState();
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
    game.start(gameMode: mode);
  });
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
    final playing = game.started;
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
                          if (!playing) ...[
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
                          ] else
                            scoreboard(),
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
                          if (!playing) ...[
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
                                    () => start(GameMode.classic),
                                    trailing: '10',
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
                          ] else ...[
                            status(),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ThumbRocker(
                                  key: ValueKey('left-${game.inputEpoch}'),
                                  label: 'LEFT',
                                  enabled: game.canControl,
                                  onChanged: (v) => input(0, v),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      AnimatedBuilder(
                                        animation: frame,
                                        builder: (context, _) =>
                                            Transform.rotate(
                                              angle:
                                                  math.atan2(
                                                    game.right - game.left,
                                                    320,
                                                  ) *
                                                  .6,
                                              child: Container(
                                                width: 44,
                                                height: 3,
                                                decoration: BoxDecoration(
                                                  color: orange,
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                            ),
                                      ),
                                      const SizedBox(height: 15),
                                      Text(
                                        'HOLD TO LIFT',
                                        style: label(ink.withAlpha(130))
                                            .copyWith(
                                              fontSize: 8,
                                              letterSpacing: 1,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Slide down to lower',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: ink.withAlpha(130),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        game.practice
                                            ? 'NO LIFE LIMIT'
                                            : '${game.multiplier}× MULTIPLIER',
                                        style: label(
                                          orange,
                                        ).copyWith(fontSize: 9),
                                      ),
                                    ],
                                  ),
                                ),
                                ThumbRocker(
                                  key: ValueKey('right-${game.inputEpoch}'),
                                  label: 'RIGHT',
                                  enabled: game.canControl,
                                  onChanged: (v) => input(1, v),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
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
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SCORE', style: label(ink.withAlpha(140))),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    game.score.toString().padLeft(5, '0'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 33,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                game.practice
                    ? 'PRACTICE'
                    : game.infinite
                    ? 'INFINITE'
                    : 'BALLS LEFT',
                style: label(ink.withAlpha(140)),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.circle,
                      size: 14,
                      color: game.practice || i < game.lives
                          ? orange
                          : ink.withAlpha(30),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Text(
            '${game.infinite ? 'R${game.round} / ' : ''}HOLE ${game.target.clamp(1, 10).toString().padLeft(2, '0')}',
            style: label(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: List.generate(
                10,
                (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: i < game.roundCompleted
                          ? ink
                          : i == game.roundCompleted
                          ? orange
                          : ink.withAlpha(25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('10', style: label(ink.withAlpha(120))),
        ],
      ),
    ],
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
                      ? 'Round ${game.round}  •  ${game.completed} holes cleared'
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
                  onPressed: game.paused ? pause : () => start(game.mode),
                  child: Text(
                    game.paused ? 'RESUME RUN' : 'ONE MORE RUN',
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
                'Hold the upper half of each control to lift that end. Slide to the lower half to lower it. Release to stop the motor.',
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
                'Infinite keeps going until all three balls are lost. Each cleared round mirrors the board and increases speed up to a fair cap. Score and streak carry over, with a 1,000 × round-number bonus for clearing all ten.',
              ),
              const Text(
                'Desktop: W / S = left end. ↑ / ↓ = right end. Esc = pause.',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 20),
              primary('TRY PRACTICE', () {
                Navigator.pop(context);
                start(GameMode.practice);
              }),
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
                'Infinite best ${profile.infiniteBest}  •  Round ${profile.infiniteRound}',
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
  );
}

/// Single-pointer rocker per thumb: slide across the neutral zone without lifting.
class ThumbRocker extends StatefulWidget {
  const ThumbRocker({
    super.key,
    required this.label,
    required this.enabled,
    required this.onChanged,
  });
  final String label;
  final bool enabled;
  final ValueChanged<double> onChanged;
  @override
  State<ThumbRocker> createState() => _ThumbRockerState();
}

class _ThumbRockerState extends State<ThumbRocker> {
  int? pointer;
  double value = 0;
  void move(double y) {
    final next = y < 49
        ? -1.0
        : y > 63
        ? 1.0
        : 0.0;
    if (next != value) {
      setState(() => value = next);
      widget.onChanged(next);
    }
  }

  void release() {
    pointer = null;
    setState(() => value = 0);
    widget.onChanged(0);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        label:
            '${widget.label} bar control. Hold top to raise, bottom to lower.',
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            if (widget.enabled && pointer == null) {
              pointer = e.pointer;
              move(e.localPosition.dy);
            }
          },
          onPointerMove: (e) {
            if (e.pointer == pointer) move(e.localPosition.dy);
          },
          onPointerUp: (e) {
            if (e.pointer == pointer) release();
          },
          onPointerCancel: (e) {
            if (e.pointer == pointer) release();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 86,
            height: 112,
            decoration: BoxDecoration(
              color: widget.enabled ? ink : ink.withAlpha(100),
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: brass.withAlpha(140)),
              boxShadow: [
                BoxShadow(
                  color: ink.withAlpha(35),
                  offset: const Offset(0, 4),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value < 0 ? brass : Colors.transparent,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: value < 0 ? ink : cream,
                      size: 32,
                    ),
                  ),
                ),
                Container(width: 26, height: 1, color: cream.withAlpha(45)),
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value > 0 ? brass : Colors.transparent,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(22),
                      ),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: value > 0 ? ink : cream,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 7),
      Text(
        widget.label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: ink.withAlpha(160),
        ),
      ),
    ],
  );
}
