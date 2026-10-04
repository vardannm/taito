import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'game.dart';

/// Temporary tilt-only trial; the lift axis is intentionally not mounted.
class TiltLiftControls extends StatelessWidget {
  const TiltLiftControls({super.key, required this.game, required this.frame});
  final BalanceGame game;
  final Listenable frame;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
    child: TiltLiftAxis(
      key: const ValueKey('tilt-lift-tilt'),
      game: game,
      frame: frame,
      tilt: true,
    ),
  );
}

class TiltLiftAxis extends StatefulWidget {
  const TiltLiftAxis({
    super.key,
    required this.game,
    required this.frame,
    required this.tilt,
  });
  final BalanceGame game;
  final Listenable frame;
  final bool tilt;

  @override
  State<TiltLiftAxis> createState() => _TiltLiftAxisState();
}

class _TiltLiftAxisState extends State<TiltLiftAxis> {
  int? pointer;
  int epoch = -1;
  double input = 0;

  void synchronize() {
    if (epoch != widget.game.inputEpoch) {
      pointer = null;
      epoch = widget.game.inputEpoch;
    }
  }

  void releaseOwned() {
    if (pointer != null && epoch == widget.game.inputEpoch) {
      widget.game.releaseTiltLiftAxis(tilt: widget.tilt);
    }
    pointer = null;
  }

  @override
  void didUpdateWidget(covariant TiltLiftAxis oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game || oldWidget.tilt != widget.tilt) {
      if (pointer != null && epoch == oldWidget.game.inputEpoch) {
        oldWidget.game.releaseTiltLiftAxis(tilt: oldWidget.tilt);
      }
      pointer = null;
    }
  }

  @override
  void dispose() {
    releaseOwned();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.frame,
    builder: (context, _) {
      synchronize();
      final game = widget.game, tilt = widget.tilt;
      return LayoutBuilder(
        builder: (context, bounds) {
          final travel = tilt
              ? ((bounds.maxWidth - 48) / 2).clamp(24.0, 120.0)
              : ((bounds.maxHeight - 54) / 2).clamp(18.0, 40.0);
          void release(PointerEvent event) {
            synchronize();
            if (event.pointer == pointer) releaseOwned();
          }

          return Semantics(
            label: tilt
                ? 'Tilt. Drag left or right to angle the platform. Release to keep the angle.'
                : 'Lift. Slide up or down and hold to move the whole platform. Release to stop.',
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                synchronize();
                if (!game.canControl || !game.tiltLift || pointer != null)
                  return;
                game.grabTiltLiftAxis(tilt: tilt);
                pointer = event.pointer;
                epoch = game.inputEpoch;
                input = tilt ? game.controlPosition : 0;
              },
              onPointerMove: (event) {
                synchronize();
                if (event.pointer != pointer ||
                    !game.canControl ||
                    !game.tiltLift)
                  return;
                // Only physical motion counts, even while the board expands.
                final delta = tilt ? event.localDelta.dx : event.localDelta.dy;
                input = (input + delta / travel).clamp(-1.0, 1.0);
                game.setTiltLiftInput(tilt: tilt, value: input);
              },
              onPointerUp: release,
              onPointerCancel: release,
              child: CustomPaint(
                painter: _AxisPainter(
                  tilt: tilt,
                  value: tilt
                      ? ((game.right - game.left) / 140).clamp(-1.0, 1.0)
                      : game.liftInput,
                  held: tilt ? game.tiltHeld : game.liftHeld,
                  enabled: game.canControl,
                  travel: travel,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          );
        },
      );
    },
  );
}

class _AxisPainter extends CustomPainter {
  const _AxisPainter({
    required this.tilt,
    required this.value,
    required this.held,
    required this.enabled,
    required this.travel,
  });
  final bool tilt, held, enabled;
  final double value, travel;

  @override
  void paint(Canvas canvas, Size size) {
    final color = enabled ? ink : ink.withAlpha(85);
    final center = Offset(size.width / 2, size.height / 2 + 7);
    final axis = tilt ? Offset(travel, 0) : Offset(0, travel);
    final track = Paint()
      ..color = brass.withAlpha(90)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center - axis, center + axis, track);
    canvas.drawCircle(center, 3, Paint()..color = color.withAlpha(110));
    final knob = center + axis * value;
    canvas.drawCircle(
      knob,
      19,
      Paint()..color = held ? orange.withAlpha(70) : const Color(0xFFEAE3D0),
    );
    canvas.drawCircle(
      knob,
      19,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final direction = tilt ? const Offset(7, 0) : const Offset(0, 7);
    canvas.drawLine(
      knob - direction,
      knob + direction,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    final label = TextPainter(
      text: TextSpan(
        text: tilt ? 'TILT' : 'LIFT',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset((size.width - label.width) / 2, 0));
  }

  @override
  bool shouldRepaint(_AxisPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.held != held ||
      oldDelegate.enabled != enabled ||
      oldDelegate.travel != travel ||
      oldDelegate.tilt != tilt;
}
