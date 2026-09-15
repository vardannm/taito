import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'analog_controls.dart';
import 'board_painter.dart';
import 'game.dart';
import 'pivot_board.dart';

/// An isolated practice game: lesson scores and coins never reach the profile.
class FirstPlayTutorial extends StatefulWidget {
  const FirstPlayTutorial({
    super.key,
    required this.onDone,
    this.control = ControlMode.twoFinger,
    this.onControlChanged,
    this.onLessonComplete,
    this.onExit,
    this.analogSensitivity = 1,
    this.twoFingerSensitivity = 1,
  });
  final VoidCallback onDone;
  final ControlMode control;
  final ValueChanged<ControlMode>? onControlChanged;
  final ValueChanged<int>? onLessonComplete;
  final ValueChanged<bool>? onExit;
  final double analogSensitivity, twoFingerSensitivity;
  @override
  State<FirstPlayTutorial> createState() => _FirstPlayTutorialState();
}

class _FirstPlayTutorialState extends State<FirstPlayTutorial>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final game = BalanceGame(seed: 1);
  final frame = ValueNotifier(0);
  late final Ticker ticker;
  Duration? previous;
  double accumulator = 0, heldFor = 0;
  int lesson = 0;
  bool passed = false, suspended = false;
  double initialHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reset(widget.control);
    ticker = createTicker(tick)..start();
  }

  void reset(ControlMode control) {
    game.setControlMode(control);
    game.start(gameMode: GameMode.practice);
    // A zero sensitivity would make the lesson impossible. Applies only here.
    game.analogSensitivity = math.max(.25, widget.analogSensitivity);
    game.twoFingerSensitivity = math.max(.25, widget.twoFingerSensitivity);
    game.board.clear();
    game.left = game.right = lesson == 0 ? 440 : 370;
    initialHeight = (game.left + game.right) / 2;
    passed = false;
    heldFor = accumulator = 0;
    previous = null;
    if (lesson == 2) game.board.add(const Hole(180, 310, target: 1));
    frame.value++;
  }

  void tick(Duration now) {
    final delta = previous == null
        ? 0.0
        : (now - previous!).inMicroseconds / 1e6;
    previous = now;
    if (suspended || passed) return;
    accumulator += math.min(delta, .05);
    while (accumulator >= 1 / 120) {
      game.step(1 / 120);
      accumulator -= 1 / 120;
      final released =
          !game.controlHeld && game.pivotTargets.every((p) => p == null);
      final lifted = (game.left + game.right) / 2 <= initialHeight - 25;
      if (lesson == 0) {
        heldFor = lifted && released ? heldFor + 1 / 120 : 0;
        if (heldFor >= .4) passed = true;
      } else if (lesson == 1) {
        if ((game.ballX - 180).abs() >= 35) passed = true;
      } else if (game.completed > 0) {
        passed = true;
      }
      if (passed) {
        game.clearInput();
        widget.onLessonComplete?.call(lesson + 1);
        setState(() {});
        break;
      }
    }
    frame.value++;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    suspended = state != AppLifecycleState.resumed;
    game.clearInput();
    previous = null;
    accumulator = 0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker.dispose();
    frame.dispose();
    super.dispose();
  }

  String get instruction => switch (lesson) {
    0 =>
      game.oneFinger
          ? 'Drag up in the thumb area below the board, then let go. The platform holds its height.'
          : game.analog
          ? 'Drag both bottom joysticks up, then let go. The platform holds its height.'
          : 'Drag both end grips up, then let go. The platform holds its height.',
    1 =>
      game.oneFinger
          ? 'Drag sideways in the thumb area below the board. Tilt until the ball rolls to either side.'
          : game.analog
          ? 'Move one bottom joystick up or down. Tilt until the ball rolls to either side.'
          : 'Move one end grip up or down. Tilt until the ball rolls to either side.',
    _ =>
      'Lift toward the glowing hole. Use a little tilt to line up the ball. Take your time.',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cream,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, bounds) {
          final height = math.max(
            bounds.maxHeight,
            MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 920.0 : 630.0,
          );
          return SingleChildScrollView(
            child: SizedBox(
              height: height,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'LEARN BY PLAYING',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                widget.onExit?.call(false);
                                widget.onDone();
                              },
                              child: const Text('SKIP'),
                            ),
                          ],
                        ),
                        DropdownButton<ControlMode>(
                          value: game.controlMode,
                          isExpanded: true,
                          items: [
                            for (final mode in ControlMode.values)
                              DropdownMenuItem(
                                value: mode,
                                child: Text(mode.label),
                              ),
                          ],
                          onChanged: (mode) {
                            if (mode == null) return;
                            setState(() {
                              lesson = 0;
                              reset(mode);
                            });
                            widget.onControlChanged?.call(mode);
                          },
                        ),
                        Text(
                          '${lesson + 1}/3 · ${['Lift and release', 'Tilt to roll', 'Catch the glow'][lesson]}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          instruction,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onPanUpdate: (_) {},
                            child: PivotBoard(
                              key: ValueKey(
                                'lesson-$lesson-${game.controlMode.name}',
                              ),
                              game: game,
                              frame: frame,
                            ),
                          ),
                        ),
                        if (game.analog)
                          SizedBox(
                            height: 104,
                            child: GestureDetector(
                              onPanUpdate: (_) {},
                              child: AnalogControls(game: game, frame: frame),
                            ),
                          ),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            passed
                                ? 'You did it. Ready for the next step!'
                                : 'Safe practice · no lives or records at stake',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  setState(() => reset(game.controlMode)),
                              child: const Text('RESET'),
                            ),
                            if (lesson > 0)
                              TextButton(
                                onPressed: () => setState(() {
                                  lesson--;
                                  reset(game.controlMode);
                                }),
                                child: const Text('BACK'),
                              ),
                            FilledButton(
                              onPressed: passed
                                  ? () {
                                      if (lesson == 2) {
                                        widget.onExit?.call(true);
                                        widget.onDone();
                                      } else {
                                        setState(() {
                                          lesson++;
                                          reset(game.controlMode);
                                        });
                                      }
                                    }
                                  : null,
                              child: Text(lesson == 2 ? "LET'S PLAY" : 'NEXT'),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Replay anytime from How to Play.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
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
