import 'package:flutter/material.dart';
import 'game.dart';
import 'infinite_painter.dart';

/// Relative tilt from a single contact anywhere on the board. No lift axis.
class BoardTiltControls extends StatefulWidget {
  const BoardTiltControls({
    super.key,
    required this.game,
    required this.frame,
    required this.child,
  });
  final BalanceGame game;
  final Listenable frame;
  final Widget child;

  @override
  State<BoardTiltControls> createState() => _BoardTiltControlsState();
}

class _BoardTiltControlsState extends State<BoardTiltControls> {
  int? pointer;
  int epoch = -1;
  Offset anchor = Offset.zero;
  double input = 0, initialInput = 0;

  void synchronize() {
    if (epoch != widget.game.inputEpoch) {
      pointer = null;
      epoch = widget.game.inputEpoch;
    }
  }

  void releaseOwned() {
    if (pointer != null && epoch == widget.game.inputEpoch) {
      widget.game.releaseTiltLiftAxis(tilt: true);
    }
    pointer = null;
  }

  @override
  void didUpdateWidget(covariant BoardTiltControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game) {
      if (pointer != null && epoch == oldWidget.game.inputEpoch) {
        oldWidget.game.releaseTiltLiftAxis(tilt: true);
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final game = widget.game;
      final travel = (bounds.maxWidth * .34).clamp(80.0, 120.0);
      void release(PointerEvent event) {
        synchronize();
        if (pointer == event.pointer) setState(releaseOwned);
      }

      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          synchronize();
          if (!game.canControl || !game.boardTilt || pointer != null) return;
          game.grabTiltLiftAxis(tilt: true);
          setState(() {
            pointer = event.pointer;
            epoch = game.inputEpoch;
            anchor = event.position;
            input = initialInput = game.controlPosition;
          });
        },
        onPointerMove: (event) {
          synchronize();
          if (pointer != event.pointer || !game.canControl || !game.boardTilt)
            return;
          // Screen motion only: expanding the board never introduces input.
          setState(
            () => input = (input + event.delta.dx / travel).clamp(-1.0, 1.0),
          );
          game.setTiltLiftInput(tilt: true, value: input);
        },
        onPointerUp: release,
        onPointerCancel: release,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            IgnorePointer(
              child: AnimatedBuilder(
                animation: widget.frame,
                builder: (context, _) {
                  synchronize();
                  if (pointer == null || !game.tiltHeld || !game.canControl)
                    return const SizedBox.shrink();
                  final box = this.context.findRenderObject() as RenderBox?;
                  final point =
                      box?.globalToLocal(anchor) ??
                      bounds.biggest.center(Offset.zero);
                  return CustomPaint(
                    key: const ValueKey('board-tilt-cue'),
                    painter: _TiltCue(
                      point,
                      (input - initialInput).clamp(-1.0, 1.0),
                      contrastInk(boardFieldColors(game)[1]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _TiltCue extends CustomPainter {
  const _TiltCue(this.point, this.delta, this.color);
  final Offset point;
  final double delta;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      point.dx.clamp(46.0, size.width - 46),
      point.dy.clamp(18.0, size.height - 18),
    );
    canvas.drawLine(
      center - const Offset(32, 0),
      center + const Offset(32, 0),
      Paint()
        ..color = color.withAlpha(70)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      center + Offset(delta * 28, 0),
      11,
      Paint()
        ..color = color.withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_TiltCue old) =>
      old.point != point || old.delta != delta || old.color != color;
}
