import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game.dart';
import 'board_painter.dart';

class ControlOptions extends StatefulWidget {
  const ControlOptions({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final ControlMode value;
  final ValueChanged<ControlMode> onChanged;
  @override
  State<ControlOptions> createState() => _ControlOptionsState();
}

class _ControlOptionsState extends State<ControlOptions>
    with SingleTickerProviderStateMixin {
  late final AnimationController demo = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      demo.stop();
      demo.value = .2;
    } else if (!demo.isAnimating) {
      demo.repeat();
    }
  }

  @override
  void dispose() {
    demo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final mode in ControlMode.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: widget.value == mode
                ? const Color(0xFFD9EDE7)
                : const Color(0xFFFAF7EF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: widget.value == mode ? ink : brass.withAlpha(100),
                width: widget.value == mode ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('control-${mode.name}'),
              onTap: () => widget.onChanged(mode),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          switch (mode) {
                            ControlMode.twoFinger => Icons.touch_app,
                            ControlMode.oneFinger => Icons.pan_tool_alt,
                            ControlMode.analog => Icons.swap_vert,
                          },
                          size: 22,
                          color: ink,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            switch (mode) {
                              ControlMode.twoFinger => 'Two-Finger Control',
                              ControlMode.oneFinger => 'One-Finger Control',
                              ControlMode.analog => 'Vertical Analog Control',
                            },
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (widget.value == mode)
                          const Icon(Icons.check_circle, color: ink, size: 20),
                      ],
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: 106,
                          height: 83,
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _ControlDemo(mode, demo),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(switch (mode) {
                            ControlMode.twoFinger =>
                              'Drag each platform end. Lift together, or tilt independently.',
                            ControlMode.oneFinger =>
                              'Use the thumb area below the board. Drag sideways to tilt, up or down to move.',
                            ControlMode.analog =>
                              'Slide the two bottom controls vertically. Release to hold position.',
                          }, style: const TextStyle(fontSize: 12, height: 1.4)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class SensitivitySetting extends StatelessWidget {
  const SensitivitySetting({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.id,
    this.onChangeEnd,
  });
  final VoidCallback? onChangeEnd;
  final String title, id;
  final double value;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      Slider(
        key: ValueKey(id),
        value: value,
        min: 0,
        max: 1,
        divisions: 20,
        label: value.toStringAsFixed(2),
        onChanged: onChanged,
        onChangeEnd: (_) => onChangeEnd?.call(),
      ),
    ],
  );
}

class _ControlDemo extends CustomPainter {
  _ControlDemo(this.mode, this.demo) : super(repaint: demo);
  final ControlMode mode;
  final Animation<double> demo;
  @override
  void paint(Canvas c, Size size) {
    final t = demo.value * math.pi * 2;
    c.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = const Color(0xFFEAE3D0),
    );
    final a = Offset(10, 34 + math.sin(t) * 9),
        b = Offset(96, 34 + math.sin(t + 1) * 9);
    c.drawLine(
      a,
      b,
      Paint()
        ..color = ink
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    final ball =
        Offset.lerp(a, b, .5 + math.sin(t - 1) * .15)! - const Offset(0, 5);
    c.drawCircle(ball, 4, Paint()..color = orange);
    void finger(Offset p) {
      c.drawCircle(p, 8, Paint()..color = orange.withAlpha(45));
      c.drawCircle(p, 3, Paint()..color = orange);
    }

    if (mode == ControlMode.twoFinger) {
      finger(a);
      finger(b);
    }
    if (mode == ControlMode.oneFinger) {
      final p = Offset(53 + math.sin(t) * 20, 65 + math.cos(t) * 3);
      c.drawLine(
        const Offset(20, 65),
        const Offset(86, 65),
        Paint()
          ..color = ink.withAlpha(90)
          ..strokeWidth = 2,
      );
      finger(p);
    }
    if (mode == ControlMode.analog) {
      for (final x in [21.0, 85.0]) {
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, 65), width: 15, height: 28),
            const Radius.circular(8),
          ),
          Paint()..color = ink.withAlpha(45),
        );
        finger(Offset(x, 65 + math.sin(t + (x == 21 ? 0 : 1)) * 8));
      }
    }
  }

  @override
  bool shouldRepaint(_ControlDemo old) => old.mode != mode;
}
