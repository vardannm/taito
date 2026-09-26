import 'package:flutter/material.dart';
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
  static const height = 96.0;
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

  /// Stick travel, in logical pixels, that means a full-speed climb or drop.
  static const throw_ = 42.0, deadZone = 7.0;
  double deflection(Offset point) {
    final offset = point.dy - origin.dy;
    if (offset.abs() <= deadZone) return 0;
    final past = offset.abs() - deadZone;
    return offset.sign * (past / (throw_ - deadZone)).clamp(0.0, 1.0);
  }

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
      // vertical reference stays put: the pad keeps its own frame, and moving
      // it must not re-centre a stick the player is still holding.
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
                'One-finger thumb area below the board. Drag sideways to tilt, up to lift, down to lower. Keep dragging beyond the area to move further.',
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
                  if (game.stickLift) game.setLiftInput(0);
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
                  if (game.stickLift) {
                    // Levels and mazes read a stick: hold it up and the
                    // platform keeps climbing until it reaches the rail.
                    game.setLiftInput(deflection(point));
                  } else {
                    // Infinite and 2048 steer one-to-one with the finger.
                    game.dragControlVertical((point.dy - previous.dy) / scale);
                  }
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
                  painter: _ThumbPadPainter(game, contact),
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

class _ThumbPadPainter extends CustomPainter {
  _ThumbPadPainter(this.game, this.contact);
  final BalanceGame game;
  final Offset? contact;
  @override
  void paint(Canvas canvas, Size size) {
    final enabled = game.canControl;
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
        ? center + Offset(game.controlPosition * (size.width / 2 - 48), 0)
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
    final text = TextPainter(
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
    )..layout(maxWidth: size.width - 40);
    text.paint(canvas, Offset((size.width - text.width) / 2, 16));
  }

  @override
  bool shouldRepaint(covariant _ThumbPadPainter oldDelegate) => true;
}
