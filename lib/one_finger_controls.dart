import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'board_painter.dart';
import 'game.dart';

/// Relative touch control below the playfield. Re-grabbing never repositions it.
class OneFingerControls extends StatefulWidget {
  const OneFingerControls({
    super.key,
    required this.game,
    required this.frame,
    required this.boardScale,
  });
  static const height = controlStripHeight;
  static double heightFor(BalanceGame game) =>
      game.haloJoystick ? haloControlStripHeight : height;
  final BalanceGame game;
  final Listenable frame;
  final double boardScale;
  @override
  State<OneFingerControls> createState() => _OneFingerControlsState();
}

class _OneFingerControlsState extends State<OneFingerControls> {
  int? pointer;
  int epoch = -1;
  Offset origin = Offset.zero, previous = Offset.zero, position = Offset.zero;
  Offset? contact;
  double initialTilt = 0;

  void synchronize() {
    if (epoch != widget.game.inputEpoch) {
      pointer = null;
      contact = null;
      epoch = widget.game.inputEpoch;
    }
  }

  @override
  void didUpdateWidget(covariant OneFingerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game) {
      oldWidget.game.releaseControl();
      pointer = null;
      contact = null;
    } else if (oldWidget.boardScale != widget.boardScale) {
      // A layout change is not a release. Rebase tilt at the held contact so
      // resizing never drops pointer ownership or jumps to a new tilt. The
      // next vertical delta still comes from the held contact.
      origin = Offset(previous.dx, origin.dy);
      initialTilt = widget.game.controlPosition;
    }
  }

  @override
  void dispose() {
    widget.game.releaseControl();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.frame,
    builder: (context, _) {
      synchronize();
      return LayoutBuilder(
        builder: (context, bounds) {
          final game = widget.game;
          final scale = widget.boardScale.clamp(.1, 10.0);
          Offset limited(Offset p) => Offset(
            p.dx.clamp(0.0, bounds.maxWidth),
            p.dy, // Vertical input follows the finger beyond the visible pad.
          );
          return Semantics(
            label:
                '${game.haloJoystick ? 'Halo joystick' : 'One-finger thumb area'} below the board. Drag sideways to tilt, up to lift, down to lower. Keep dragging beyond the area to move further.',
            child: GestureDetector(
              onPanUpdate:
                  (_) {}, // Keep tutorial page scrolling out of control drags.
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  synchronize();
                  if (!game.canControl || !game.oneFinger || pointer != null)
                    return;
                  pointer = event.pointer;
                  position = event.localPosition;
                  origin = previous = limited(position);
                  initialTilt = game.controlPosition;
                  game.grabControl();
                  setState(() => contact = origin);
                },
                onPointerMove: (event) {
                  synchronize();
                  if (pointer != event.pointer ||
                      !game.canControl ||
                      !game.oneFinger)
                    return;
                  // Deltas retain the held contact when the pad moves in the
                  // layout; a changed local origin must not become movement.
                  position += event.delta;
                  final point = limited(position);
                  game.setControlPosition(
                    initialTilt + (point.dx - origin.dx) / (110 * scale),
                  );
                  // Every mode follows the same one-to-one finger movement.
                  game.dragControlVertical((point.dy - previous.dy) / scale);
                  previous = point;
                  setState(() => contact = point);
                },
                onPointerUp: (event) {
                  synchronize();
                  if (pointer != event.pointer) return;
                  game.releaseControl();
                  setState(() {
                    pointer = null;
                    contact = null;
                  });
                },
                onPointerCancel: (event) {
                  synchronize();
                  if (pointer != event.pointer) return;
                  game.clearInput();
                  setState(() {
                    pointer = null;
                    contact = null;
                  });
                },
                child: CustomPaint(
                  painter: game.haloJoystick
                      ? HaloJoystickPainter(
                          contact == null ? null : contact! - origin,
                        )
                      : _ThumbPadPainter(game, contact),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Larger, high-contrast trial artwork; it shares the original input listener.
class HaloJoystickPainter extends CustomPainter {
  HaloJoystickPainter(this.displacement);
  final Offset? displacement;
  static const _gold = Color(0xFFE9C47C);
  static final _labels = <String, TextPainter>{};

  void label(
    Canvas canvas,
    String text,
    Offset at, {
    bool centered = false,
    bool right = false,
  }) {
    final painter = _labels.putIfAbsent(
      text,
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontFamily: 'sans-serif',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFFD4E4DC),
            letterSpacing: .3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    painter.paint(
      canvas,
      at -
          Offset(
            right
                ? painter.width
                : centered
                ? painter.width / 2
                : 0,
            painter.height / 2,
          ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(12, 6, size.width - 24, size.height - 12);
    final area = RRect.fromRectAndRadius(rect, const Radius.circular(22));
    canvas.drawRRect(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C4145), Color(0xFF102D33)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      area,
      Paint()
        ..color = displacement == null ? const Color(0xFF577573) : _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final center = Offset(size.width / 2, size.height * .53);
    canvas.drawCircle(center, 45, Paint()..color = const Color(0xFF09252A));
    canvas.drawCircle(
      center,
      40,
      Paint()
        ..color = _gold.withAlpha(160)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final delta = displacement ?? Offset.zero;
    final offset = delta / math.max(1.0, delta.distance / 22);
    final knob = center + offset;
    if (displacement != null)
      canvas.drawLine(
        center,
        knob,
        Paint()
          ..color = _gold
          ..strokeWidth = 2.5,
      );
    canvas.drawCircle(
      knob + const Offset(0, 4),
      27,
      Paint()..color = const Color(0xFF081F24),
    );
    canvas.drawCircle(
      knob,
      26,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.4, -.5),
          radius: 1.1,
          colors: [Color(0xFFFFF0BB), _gold, Color(0xFFAD803E)],
          stops: [0, .55, 1],
        ).createShader(Rect.fromCircle(center: knob, radius: 26)),
    );
    canvas.drawCircle(
      knob,
      25,
      Paint()
        ..color = const Color(0xFFF9E1A1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (final x in [-6.0, 0.0, 6.0]) {
      for (final y in [-6.0, 0.0, 6.0]) {
        canvas.drawCircle(
          knob + Offset(x, y),
          1.5,
          Paint()..color = const Color(0xFF244747),
        );
      }
    }
    label(canvas, '↑ LIFT', Offset(center.dx, 18), centered: true);
    label(
      canvas,
      '↓ LOWER',
      Offset(center.dx, size.height - 16),
      centered: true,
    );
    label(canvas, '← TILT', Offset(26, center.dy));
    label(canvas, 'TILT →', Offset(size.width - 26, center.dy), right: true);
  }

  @override
  bool shouldRepaint(covariant HaloJoystickPainter oldDelegate) =>
      oldDelegate.displacement != displacement;
}

class _ThumbPadPainter extends CustomPainter {
  _ThumbPadPainter(BalanceGame game, this.contact)
    : enabled = game.canControl,
      controlPosition = game.controlPosition;
  final bool enabled;
  final double controlPosition;
  final Offset? contact;

  // The pad repaints every frame; lay its label out once per state instead.
  static final _labels = <bool, TextPainter>{};
  static double _labelWidth = 0;

  TextPainter _label(double maxWidth) {
    if (_labelWidth != maxWidth) {
      for (final label in _labels.values) {
        label.dispose();
      }
      _labels.clear();
      _labelWidth = maxWidth;
    }
    return _labels[enabled] ??= TextPainter(
      text: TextSpan(
        text: 'TILT LEFT/RIGHT  ·  LIFT UP/DOWN',
        style: TextStyle(
          color: ink.withAlpha(enabled ? 210 : 100),
          fontSize: 10,
          fontFamily: 'sans-serif',
          letterSpacing: .7,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final area = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 8, size.width - 24, size.height - 14),
      const Radius.circular(22),
    );
    canvas.drawRRect(area, Paint()..color = cream);
    canvas.drawRRect(
      area,
      Paint()
        ..color = ink.withAlpha(enabled ? 65 : 25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final center = Offset(size.width / 2, size.height / 2 + 7);
    canvas.drawLine(
      Offset(40, center.dy),
      Offset(size.width - 40, center.dy),
      Paint()
        ..color = ink.withAlpha(45)
        ..strokeWidth = 2,
    );
    final knob = contact == null
        ? center + Offset(controlPosition * (size.width / 2 - 48), 0)
        : Offset(
            contact!.dx.clamp(36.0, size.width - 36),
            contact!.dy.clamp(40.0, size.height - 26),
          );
    canvas.drawCircle(
      knob,
      22,
      Paint()..color = ink.withAlpha(enabled ? 255 : 90),
    );
    canvas.drawCircle(
      knob,
      19,
      Paint()
        ..color = brass
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    for (final dy in [-5.0, 0.0, 5.0]) {
      canvas.drawLine(
        knob + Offset(-7, dy),
        knob + Offset(7, dy),
        Paint()
          ..color = brass
          ..strokeWidth = 2,
      );
    }
    final text = _label(size.width - 40);
    text.paint(canvas, Offset((size.width - text.width) / 2, 16));
  }

  @override
  bool shouldRepaint(covariant _ThumbPadPainter oldDelegate) =>
      oldDelegate.enabled != enabled ||
      oldDelegate.controlPosition != controlPosition ||
      oldDelegate.contact != contact;
}
