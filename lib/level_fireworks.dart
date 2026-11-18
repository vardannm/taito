import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'board_painter.dart' show cream;

/// A short, one-shot fireworks show behind a 3-4 star level result. It plays
/// once and settles, so it never keeps a frame callback alive, and it stays
/// away entirely when the system asks for reduced motion.
class LevelFireworks extends StatefulWidget {
  const LevelFireworks({super.key});

  static const duration = Duration(milliseconds: 3200);

  @override
  State<LevelFireworks> createState() => _LevelFireworksState();
}

class _LevelFireworksState extends State<LevelFireworks>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: LevelFireworks.duration,
  );
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (!_still && !_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _still
      ? const SizedBox.shrink()
      : IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: FireworksPainter(_controller),
              size: Size.infinite,
            ),
          ),
        );
}

class _Burst {
  const _Burst(this.start, this.x, this.y, this.color, this.seed);
  final double start, x, y;
  final Color color;
  final int seed;
}

class FireworksPainter extends CustomPainter {
  FireworksPainter(this.progress) : super(repaint: progress);
  final Animation<double> progress;

  static const _life = 1.15, _sparks = 26;
  static const _bursts = [
    _Burst(.10, .26, .20, Color(0xFFE9C47C), 1),
    _Burst(.42, .74, .16, Color(0xFFFF7A6B), 2),
    _Burst(.78, .50, .30, Color(0xFF7DE3B5), 3),
    _Burst(1.12, .20, .40, Color(0xFF8EC9FF), 4),
    _Burst(1.42, .80, .36, Color(0xFFE9C47C), 5),
    _Burst(1.80, .46, .14, Color(0xFFFFB86B), 6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final seconds =
        progress.value * LevelFireworks.duration.inMilliseconds / 1000;
    final scale = math.min(size.width, 420) / 360;
    final spark = Paint()..strokeCap = StrokeCap.round;
    final glow = Paint();
    for (final burst in _bursts) {
      final t = (seconds - burst.start) / _life;
      if (t <= 0 || t >= 1) continue;
      final center = Offset(burst.x * size.width, burst.y * size.height);
      final fade = math.pow(1 - t, 1.6).toDouble();
      if (t < .18) {
        glow.color = burst.color.withValues(alpha: (1 - t / .18) * .45);
        canvas.drawCircle(center, (10 + 26 * t / .18) * scale, glow);
      }
      final random = math.Random(burst.seed);
      for (var i = 0; i < _sparks; i++) {
        final angle =
            i * 2 * math.pi / _sparks + (random.nextDouble() - .5) * .25;
        final speed = (70 + random.nextDouble() * 45) * scale;
        Offset at(double time) {
          final travel = 1 - math.pow(1 - time, 3).toDouble();
          return center +
              Offset(math.cos(angle), math.sin(angle)) * speed * travel +
              Offset(0, 34 * scale * time * time);
        }

        final color = i.isEven ? burst.color : cream;
        spark
          ..color = color.withValues(alpha: fade)
          ..strokeWidth = (3.4 - 2.2 * t) * scale;
        canvas.drawLine(at(math.max(0, t - .1)), at(t), spark);
      }
    }
  }

  @override
  bool shouldRepaint(covariant FireworksPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
