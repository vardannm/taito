import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'game.dart';

/// Pointer ownership stays with the grabbed pivot through crossing and release.
class PivotBoard extends StatefulWidget {
  const PivotBoard({super.key, required this.game, required this.frame});
  final BalanceGame game;
  final Listenable frame;
  @override
  State<PivotBoard> createState() => _PivotBoardState();
}

class _PivotBoardState extends State<PivotBoard> {
  final pointers = <int, int>{};
  final lastY = <int, double>{};
  int epoch = -1;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final game = widget.game;
      if (epoch != game.inputEpoch) {
        pointers.clear();
        lastY.clear();
        epoch = game.inputEpoch;
      }
      final viewport = BoardViewport(bounds.biggest);
      void release(PointerEvent event) {
        final side = pointers.remove(event.pointer);
        lastY.remove(event.pointer);
        if (side != null && side < 2) game.releasePivot(side);
        if (side == 2) game.releaseControl();
      }

      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (!game.canControl || game.analog) return;
          if (!viewport.rect.contains(event.localPosition)) return;
          if (epoch != game.inputEpoch) {
            pointers.clear();
            lastY.clear();
            epoch = game.inputEpoch;
          }
          if (game.oneFinger) {
            final point =
                (event.localPosition - viewport.offset) / viewport.scale;
            if (pointers.isNotEmpty ||
                (point.dy - game.controlY).abs() > 30 ||
                (point.dx - (180 + game.controlPosition * 110)).abs() > 32)
              return;
            pointers[event.pointer] = 2;
            lastY[event.pointer] = point.dx - game.controlPosition * 110;
            game.grabControl();
            return;
          }
          final side = event.localPosition.dx < viewport.rect.center.dx ? 0 : 1;
          final pivot = viewport.project(
            Offset(
              side == 0 ? 20 : 340,
              game.screenY(side == 0 ? game.left : game.right),
            ),
          );
          final x = pivot.dx, y = pivot.dy;
          if ((event.localPosition.dx - x).abs() > 44 ||
              (event.localPosition.dy - y).abs() > 48 ||
              pointers.containsValue(side))
            return;
          pointers[event.pointer] = side;
          lastY[event.pointer] = event.localPosition.dy;
          game.grabPivot(side);
        },
        onPointerMove: (event) {
          final side = pointers[event.pointer];
          if (side == null || !game.canControl || epoch != game.inputEpoch)
            return;
          if (side == 2) {
            final x =
                (event.localPosition.dx - viewport.offset.dx) / viewport.scale;
            game.setControlPosition((x - lastY[event.pointer]!) / 110);
            game.dragControlVertical(event.localDelta.dy / viewport.scale);
            return;
          }
          final delta =
              (event.localPosition.dy - lastY[event.pointer]!) / viewport.scale;
          lastY[event.pointer] = event.localPosition.dy;
          game.dragPivot(side, delta);
        },
        onPointerUp: release,
        onPointerCancel: release,
        child: Semantics(
          label: game.analog
              ? 'Use the bottom left and right vertical joysticks to move the platform ends'
              : game.oneFinger
              ? 'Drag the lower handle left or right to tilt, up to lift, down to lower'
              : 'Drag the left and right ends of the platform up or down',
          child: RepaintBoundary(
            child: CustomPaint(
              painter: BoardPainter(
                game,
                repaint: widget.frame,
                reducedMotion: MediaQuery.of(context).disableAnimations,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
    },
  );
}
