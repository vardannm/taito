import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'board_painter.dart';
import 'game.dart';
import 'infinite_painter.dart';

/// Shared relative input for the original pad and the floating Halo trial.
class OneFingerControls extends StatefulWidget {
  const OneFingerControls({
    super.key,
    required this.game,
    required this.frame,
    required this.boardScale,
  });
  static const height = controlStripHeight;
  static double heightFor(BalanceGame game) => game.haloJoystick ? 0 : height;
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
  Offset? visualAnchor, visualPosition;
  double initialTilt = 0;

  void synchronize() {
    if (epoch != widget.game.inputEpoch) {
      pointer = null;
      contact = null;
      visualAnchor = visualPosition = null;
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
      visualAnchor = visualPosition = null;
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
            label: game.haloJoystick
                ? 'Floating Halo joystick. Touch anywhere on the board and drag sideways to tilt, up to lift, down to lower. The guide appears only while touching.'
                : 'One-finger thumb area at the bottom of the board. Drag sideways to tilt, up to lift, down to lower. Keep dragging beyond the area to move further.',
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
                  visualAnchor = visualPosition = event.position;
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
                  visualPosition = event.position;
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
                child: game.haloJoystick
                    ? CustomPaint(
                        painter: HaloJoystickPainter(
                          anchor: contact == null || visualAnchor == null
                              ? null
                              : (this.context.findRenderObject() as RenderBox?)
                                    ?.globalToLocal(visualAnchor!),
                          displacement:
                              visualAnchor == null || visualPosition == null
                              ? Offset.zero
                              : visualPosition! - visualAnchor!,
                        ),
                        child: const SizedBox.expand(),
                      )
                    : ClipRRect(
                        clipper: const _ThumbPadClipper(),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: CustomPaint(
                            painter: _ThumbPadPainter(game, contact),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// A touch-anchored guide drawn only while the floating Halo is held.
class HaloJoystickPainter extends CustomPainter {
  const HaloJoystickPainter({required this.anchor, required this.displacement});
  final Offset? anchor;
  final Offset displacement;
  static const opacity = .42;
  static const _gold = Color(0xFFE9C47C);

  @override
  void paint(Canvas canvas, Size size) {
    final center = anchor;
    if (center == null) return;
    final knob =
        center + displacement / math.max(1.0, displacement.distance / 22);
    canvas.drawCircle(
      center,
      43,
      Paint()..color = const Color(0xFF09252A).withValues(alpha: opacity * .6),
    );
    canvas.drawCircle(
      center,
      41,
      Paint()
        ..color = _gold.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final direction in [
      const Offset(1, 0),
      const Offset(-1, 0),
      const Offset(0, 1),
      const Offset(0, -1),
    ]) {
      canvas.drawLine(
        center + direction * 35,
        center + direction * 39,
        Paint()
          ..color = _gold.withValues(alpha: opacity)
          ..strokeWidth = 2,
      );
    }
    canvas.drawLine(
      center,
      knob,
      Paint()
        ..color = _gold.withValues(alpha: opacity)
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      knob + const Offset(0, 3),
      26,
      Paint()..color = const Color(0xFF081F24).withValues(alpha: opacity * .5),
    );
    canvas.drawCircle(
      knob,
      26,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.4, -.5),
          radius: 1.1,
          colors: [
            const Color(0xFFFFF0BB).withValues(alpha: opacity),
            _gold.withValues(alpha: opacity),
            const Color(0xFFAD803E).withValues(alpha: opacity),
          ],
          stops: const [0, .55, 1],
        ).createShader(Rect.fromCircle(center: knob, radius: 26)),
    );
    canvas.drawCircle(
      knob,
      25,
      Paint()
        ..color = const Color(0xFFF9E1A1).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    for (final x in [-6.0, 0.0, 6.0]) {
      for (final y in [-6.0, 0.0, 6.0]) {
        canvas.drawCircle(
          knob + Offset(x, y),
          1.5,
          Paint()..color = const Color(0xFF244747).withValues(alpha: opacity),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant HaloJoystickPainter oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.displacement != displacement;
}

RRect _thumbPadArea(Size size) => RRect.fromRectAndRadius(
  Rect.fromLTWH(12, 8, size.width - 24, size.height - 14),
  const Radius.circular(22),
);

class _ThumbPadClipper extends CustomClipper<RRect> {
  const _ThumbPadClipper();

  @override
  RRect getClip(Size size) => _thumbPadArea(size);

  @override
  bool shouldReclip(_ThumbPadClipper oldClipper) => false;
}

class _ThumbPadPainter extends CustomPainter {
  _ThumbPadPainter(BalanceGame game, this.contact)
    : enabled = game.canControl,
      controlPosition = game.controlPosition,
      color = infiniteBoardInk(game, Offset(180, game.visibleBottom - 30));
  final bool enabled;
  final Color color;
  final double controlPosition;
  final Offset? contact;

  // The pad repaints every frame; lay its label out once per state instead.
  static final _labels = <(bool, Color), TextPainter>{};
  static double _labelWidth = 0;

  TextPainter _label(double maxWidth) {
    if (_labelWidth != maxWidth) {
      for (final label in _labels.values) {
        label.dispose();
      }
      _labels.clear();
      _labelWidth = maxWidth;
    }
    return _labels[(enabled, color)] ??= TextPainter(
      text: TextSpan(
        text: 'TILT LEFT/RIGHT  ·  LIFT UP/DOWN',
        style: TextStyle(
          color: color.withAlpha(enabled ? 220 : 130),
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
    final area = _thumbPadArea(size);
    canvas.drawRRect(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withAlpha(40), Colors.white.withAlpha(12)],
        ).createShader(area.outerRect),
    );
    canvas.drawRRect(
      area,
      Paint()
        ..color = Colors.white.withAlpha(enabled ? 95 : 50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final center = Offset(size.width / 2, size.height / 2 + 7);
    canvas.drawLine(
      Offset(40, center.dy),
      Offset(size.width - 40, center.dy),
      Paint()
        ..color = color.withAlpha(55)
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
      Paint()..color = color.withAlpha(enabled ? 26 : 14),
    );
    canvas.drawCircle(
      knob,
      19,
      Paint()
        ..color = color.withAlpha(enabled ? 160 : 80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    for (final dy in [-5.0, 0.0, 5.0]) {
      canvas.drawLine(
        knob + Offset(-7, dy),
        knob + Offset(7, dy),
        Paint()
          ..color = color.withAlpha(enabled ? 230 : 120)
          ..strokeWidth = 2,
      );
    }
    final text = _label(size.width - 40);
    text.paint(canvas, Offset((size.width - text.width) / 2, 16));
  }

  @override
  bool shouldRepaint(covariant _ThumbPadPainter oldDelegate) =>
      oldDelegate.enabled != enabled ||
      oldDelegate.color != color ||
      oldDelegate.controlPosition != controlPosition ||
      oldDelegate.contact != contact;
}
