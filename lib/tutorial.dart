import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'board_painter.dart';

/// A brief introduction; no live run, score, or failure timer is started here.
class FirstPlayTutorial extends StatefulWidget {
  const FirstPlayTutorial({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<FirstPlayTutorial> createState() => _FirstPlayTutorialState();
}

class _FirstPlayTutorialState extends State<FirstPlayTutorial>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();
  int step = 0;
  static const titles = [
    'Two fingers. One platform.',
    'Follow the glowing hole.',
    'Keep the ball alive.',
  ];
  static const descriptions = [
    'Drag the left and right grips up or down. Tilt to roll the ball. Raise both ends to lift it. Release to hold.',
    'In Classic, reach the glowing numbered hole. Avoid the others. Clear all ten with three balls.',
    'In Infinite, dodge the holes moving toward you. Red warnings signal new traps, lasers and platform gaps. Stop steering and the red floor rises.',
  ];
  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onDone();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'WELCOME TO GILT',
                            style: TextStyle(
                              letterSpacing: 2,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onDone,
                          child: const Text('SKIP'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: step == 0
                          ? 'Drag the two grips vertically to tilt the platform'
                          : step == 1
                          ? 'Aim for the glowing numbered target'
                          : 'Holes move down while you steer the ball away',
                      child: AspectRatio(
                        aspectRatio: 1.35,
                        child: AnimatedBuilder(
                          animation: motion,
                          builder: (context, _) => CustomPaint(
                            painter: _LessonPainter(
                              step,
                              reduced ? .35 : motion.value,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      titles[step],
                      style: const TextStyle(
                        fontSize: 29,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      descriptions[step],
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == step ? 24 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == step ? ink : ink.withAlpha(40),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        if (step == 2) {
                          widget.onDone();
                        } else {
                          setState(() => step++);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: ink,
                        foregroundColor: cream,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: Text(step == 2 ? "LET'S PLAY" : 'NEXT'),
                    ),
                    if (step > 0)
                      TextButton(
                        onPressed: () => setState(() => step--),
                        child: const Text('BACK'),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'You can replay this from How to Play.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonPainter extends CustomPainter {
  _LessonPainter(this.step, this.t);
  final int step;
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 324, size.height / 240);
    canvas.save();
    canvas.translate(
      (size.width - 324 * scale) / 2,
      (size.height - 240 * scale) / 2,
    );
    canvas.scale(scale);
    final board = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 324, 240),
      const Radius.circular(20),
    );
    canvas.drawRRect(board, Paint()..color = ink);
    canvas.drawRRect(board.deflate(5), Paint()..color = brass);
    canvas.save();
    canvas.clipRRect(board.deflate(7));
    for (final x in [26.0, 298.0]) {
      canvas.drawLine(
        Offset(x, 20),
        Offset(x, 220),
        Paint()
          ..color = ink.withAlpha(130)
          ..strokeWidth = 3,
      );
    }
    void hole(Offset p, {bool target = false}) {
      if (target)
        canvas.drawCircle(
          p,
          25,
          Paint()..color = const Color(0xFFDCFAD9).withAlpha(110),
        );
      canvas.drawCircle(
        p,
        15,
        Paint()..color = target ? const Color(0xFFDCFAD9) : cream,
      );
      canvas.drawCircle(p, 12, Paint()..color = ink);
      if (target) {
        final text = TextPainter(
          text: const TextSpan(
            text: '01',
            style: TextStyle(
              color: cream,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, p - Offset(text.width / 2, text.height / 2));
      }
    }

    if (step == 1) {
      hole(const Offset(85, 60));
      hole(const Offset(235, 120));
      hole(const Offset(162, 70), target: true);
    }
    if (step == 2) {
      for (var row = -1; row < 4; row++) {
        final y = row * 80 + t * 80;
        hole(Offset(row.isEven ? 80 : 120, y));
        hole(Offset(row.isEven ? 240 : 205, y));
      }
      canvas.drawRect(
        const Rect.fromLTWH(7, 217, 310, 23),
        Paint()..color = orange.withAlpha(150),
      );
    }
    final tilt = step == 1 ? 0.0 : math.sin(t * math.pi * 2) * 28;
    final base = step == 1 ? 180 - (1 - math.cos(t * math.pi * 2)) * 46 : 173.0;
    final a = Offset(26, base - tilt), b = Offset(298, base + tilt);
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = ink
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a - const Offset(0, 2),
      b - const Offset(0, 2),
      Paint()
        ..color = cream
        ..strokeWidth = 3,
    );
    for (final p in [a, b]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 24, height: 36),
          const Radius.circular(5),
        ),
        Paint()..color = ink,
      );
      for (final dy in [-6.0, 6.0])
        canvas.drawLine(
          p + Offset(-6, dy),
          p + Offset(6, dy),
          Paint()
            ..color = brass
            ..strokeWidth = 2,
        );
      if (step == 0) {
        for (final direction in [-1.0, 1.0]) {
          final tip = p + Offset(0, direction * 38);
          canvas.drawLine(
            p + Offset(0, direction * 24),
            tip,
            Paint()
              ..color = orange
              ..strokeWidth = 3,
          );
          canvas.drawLine(
            tip,
            tip + Offset(-5, -direction * 6),
            Paint()
              ..color = orange
              ..strokeWidth = 3,
          );
          canvas.drawLine(
            tip,
            tip + Offset(5, -direction * 6),
            Paint()
              ..color = orange
              ..strokeWidth = 3,
          );
        }
      }
    }
    final x = step == 1 ? 162.0 : 162 + math.sin(t * math.pi * 2) * 42;
    final ball = Offset(x, a.dy + (b.dy - a.dy) * (x - 26) / 272 - 10);
    canvas.drawCircle(
      ball,
      9,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Color(0xFF738C87)],
          center: Alignment(-.4, -.5),
        ).createShader(Rect.fromCircle(center: ball, radius: 9)),
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LessonPainter oldDelegate) =>
      oldDelegate.step != step || oldDelegate.t != t;
}
