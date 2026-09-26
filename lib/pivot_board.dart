import 'one_finger_controls.dart';
import 'control_hint.dart';
import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'game.dart';

/// Pointer ownership stays with the grabbed pivot through crossing and release.
class PivotBoard extends StatefulWidget {
  const PivotBoard({
    super.key,
    required this.game,
    required this.frame,
    this.fillWidth = 0,
    this.showHint = false,
  });
  final BalanceGame game;
  final Listenable frame;
  final double fillWidth;
  final bool showHint;
  @override
  State<PivotBoard> createState() => _PivotBoardState();
}

class _PivotBoardState extends State<PivotBoard> {
  final pointers = <int, int>{};
  int epoch = -1;

  void synchronize() {
    if (epoch != widget.game.inputEpoch) {
      pointers.clear();
      epoch = widget.game.inputEpoch;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (!widget.game.oneFinger) return buildBoard(context, bounds);
      final boardHeight = (bounds.maxHeight - OneFingerControls.height).clamp(
        1.0,
        double.infinity,
      );
      final scale = BoardViewport.forGame(
        Size(bounds.maxWidth, boardHeight),
        widget.game,
        fillWidth: widget.fillWidth,
      ).scale;
      return Column(
        children: [
          Expanded(child: LayoutBuilder(builder: buildBoard)),
          SizedBox(
            height: OneFingerControls.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                OneFingerControls(
                  key: const ValueKey('one-finger-pad'),
                  game: widget.game,
                  frame: widget.frame,
                  boardScale: scale,
                ),
                if (widget.showHint)
                  ControlHint(
                    anchors: [Offset(bounds.maxWidth / 2, 60)],
                    sideways: true,
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget buildBoard(BuildContext context, BoxConstraints bounds) {
    final game = widget.game;
    synchronize();
    BoardViewport viewportNow() => BoardViewport.forGame(
      bounds.biggest,
      game,
      fillWidth: widget.fillWidth,
    );
    void release(PointerEvent event) {
      synchronize();
      final side = pointers.remove(event.pointer);
      if (side != null && side < 2) game.releasePivot(side);
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        synchronize();
        if (!game.canControl || game.analog || game.oneFinger) return;
        final viewport = viewportNow();
        if (!viewport.rect.contains(event.localPosition)) return;
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
        game.grabPivot(side);
      },
      onPointerMove: (event) {
        synchronize();
        final side = pointers[event.pointer];
        if (side == null || !game.canControl || epoch != game.inputEpoch)
          return;
        // Layout can expand under an already-held finger. Only physical pointer
        // motion is input; movement of the viewport itself must not move a pivot.
        final delta = event.localDelta.dy / viewportNow().scale;
        game.dragPivot(side, delta);
      },
      onPointerUp: release,
      onPointerCancel: release,
      child: Semantics(
        // Lives are painted on the board itself, so they are announced here.
        label:
            (game.infinite ? '${game.lives} of 3 hearts. ' : '') +
            (game.analog
            ? 'Use the bottom left and right vertical joysticks to move the platform ends'
            : game.oneFinger
            ? 'Use the thumb area below the board to tilt and lift'
            : 'Drag the left and right ends of the platform up or down'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: BoardPainter(
                  game,
                  repaint: widget.frame,
                  reducedMotion: MediaQuery.of(context).disableAnimations,
                  fillWidth: widget.fillWidth,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            if (widget.showHint && !game.analog && !game.oneFinger)
              ControlHint(
                anchors: [
                  for (final side in [0, 1])
                    viewportNow().project(
                      Offset(
                        side == 0 ? 20 : 340,
                        game.screenY(side == 0 ? game.left : game.right),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
