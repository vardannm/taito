import 'one_finger_controls.dart';
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
      if (!widget.game.oneFinger) return buildBoard(context, bounds);
      final boardHeight = (bounds.maxHeight - OneFingerControls.height).clamp(
        1.0,
        double.infinity,
      );
      final scale = BoardViewport(Size(bounds.maxWidth, boardHeight)).scale;
      return Column(
        children: [
          Expanded(child: LayoutBuilder(builder: buildBoard)),
          SizedBox(
            height: OneFingerControls.height,
            child: OneFingerControls(
              key: const ValueKey('one-finger-pad'),
              game: widget.game,
              frame: widget.frame,
              boardScale: scale,
            ),
          ),
        ],
      );
    },
  );

  Widget buildBoard(BuildContext context, BoxConstraints bounds) {
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
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (!game.canControl || game.analog || game.oneFinger) return;
        if (!viewport.rect.contains(event.localPosition)) return;
        if (epoch != game.inputEpoch) {
          pointers.clear();
          lastY.clear();
          epoch = game.inputEpoch;
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
            ? 'Use the thumb area below the board to tilt and lift'
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
  }
}
