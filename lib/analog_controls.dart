import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'cabinet.dart';
import 'game.dart';

class AnalogControls extends StatelessWidget {
  const AnalogControls({super.key, required this.game, required this.frame});
  final BalanceGame game;
  final Listenable frame;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 88,
          child: VerticalAnalog(
            key: const ValueKey('analog-left'),
            game: game,
            frame: frame,
            side: 0,
          ),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'UP TO LIFT\nDOWN TO LOWER',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                height: 1.6,
                letterSpacing: .8,
                color: ink,
              ),
            ),
          ),
        ),
        SizedBox(
          width: 88,
          child: VerticalAnalog(
            key: const ValueKey('analog-right'),
            game: game,
            frame: frame,
            side: 1,
          ),
        ),
      ],
    ),
  );
}

class VerticalAnalog extends StatefulWidget {
  const VerticalAnalog({
    super.key,
    required this.game,
    required this.frame,
    required this.side,
  });
  final BalanceGame game;
  final Listenable frame;
  final int side;
  @override
  State<VerticalAnalog> createState() => _VerticalAnalogState();
}

class _VerticalAnalogState extends State<VerticalAnalog> {
  int? pointer;
  int epoch = -1;
  double originY = 0;
  void synchronize() {
    if (epoch != widget.game.inputEpoch) {
      pointer = null;
      epoch = widget.game.inputEpoch;
    }
  }

  @override
  void didUpdateWidget(covariant VerticalAnalog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game || oldWidget.side != widget.side)
      pointer = null;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.frame,
    builder: (context, _) {
      synchronize();
      return LayoutBuilder(
        builder: (context, bounds) {
          final game = widget.game,
              travel = ((bounds.maxHeight - 54) / 2).clamp(18.0, 40.0);
          void release(PointerEvent event) {
            synchronize();
            if (pointer != event.pointer) return;
            pointer = null;
            game.setAnalogInput(widget.side, 0);
            game.releasePivot(widget.side);
          }

          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              synchronize();
              if (!game.canControl || !game.analog || pointer != null) return;
              pointer = event.pointer;
              originY = event.localPosition.dy;
              game.grabPivot(widget.side);
              game.setAnalogInput(widget.side, 0);
            },
            onPointerMove: (event) {
              synchronize();
              if (pointer != event.pointer || !game.canControl) return;
              final raw = ((event.localPosition.dy - originY) / travel).clamp(
                -1.0,
                1.0,
              );
              // Direct displacement: no dead zone, easing, or velocity integration.
              game.dragPivot(widget.side, event.localDelta.dy * 180 / travel);
              game.setAnalogInput(widget.side, raw);
            },
            onPointerUp: release,
            onPointerCancel: release,
            child: Semantics(
              label:
                  '${widget.side == 0 ? 'Left' : 'Right'} vertical joystick. Drag up to raise, down to lower. Release to hold the platform.',
              child: CustomPaint(
                painter: _AnalogPainter(game, widget.side, travel),
                child: const SizedBox.expand(),
              ),
            ),
          );
        },
      );
    },
  );
}

class _AnalogPainter extends CustomPainter {
  _AnalogPainter(this.game, this.side, this.travel);
  final BalanceGame game;
  final int side;
  final double travel;
  @override
  void paint(Canvas c, Size size) {
    final palette = CabinetPalette.of(game.cabinet),
        center = Offset(size.width / 2, size.height / 2);
    final enabled = game.canControl;
    final track = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 60, height: size.height - 4),
      const Radius.circular(30),
    );
    c.drawRRect(
      track,
      Paint()..color = palette.frame.withAlpha(enabled ? 25 : 12),
    );
    c.drawRRect(
      track,
      Paint()
        ..color = palette.frame.withAlpha(80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    c.drawLine(
      center - Offset(0, travel),
      center + Offset(0, travel),
      Paint()
        ..color = palette.frame.withAlpha(70)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    for (final sign in [-1.0, 1.0]) {
      final y = center.dy + sign * (travel + 9);
      c.drawPath(
        Path()
          ..moveTo(center.dx - 4, y - sign * 3)
          ..lineTo(center.dx, y)
          ..lineTo(center.dx + 4, y - sign * 3),
        Paint()
          ..color = palette.frame.withAlpha(140)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    final knob = center + Offset(0, game.analogInputs[side] * travel);
    c.drawCircle(
      knob + const Offset(0, 2),
      22,
      Paint()..color = Colors.black.withAlpha(25),
    );
    c.drawCircle(
      knob,
      22,
      Paint()..color = palette.frame.withAlpha(enabled ? 255 : 115),
    );
    c.drawCircle(
      knob,
      19,
      Paint()
        ..color = palette.trim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    for (final dy in [-4.0, 0.0, 4.0]) {
      c.drawLine(
        knob + Offset(-6, dy),
        knob + Offset(6, dy),
        Paint()
          ..color = palette.trim
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnalogPainter oldDelegate) => true;
}
