import 'one_finger_controls.dart';
import 'board_tilt_controls.dart';
import 'control_hint.dart';
import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'game.dart';
import 'responsive_layout.dart';

/// Pointer ownership stays with the grabbed pivot through crossing and release.
class PivotBoard extends StatefulWidget {
  const PivotBoard({
    super.key,
    required this.game,
    required this.frame,
    this.fillWidth = 0,
    this.bottomInset,
    this.bottomPadding = 0,
    this.showHint = false,
    this.dimUntilInput = false,
    this.overlay,
  });
  final BalanceGame game;
  final Listenable frame;
  final double fillWidth;

  /// Keeps gameplay above the controls while scenery fills the whole widget.
  final double? bottomInset;

  /// Keeps the thumb pad clear of the device's home indicator.
  final double bottomPadding;
  final bool showHint;
  final bool dimUntilInput;
  final Widget? overlay;
  @override
  State<PivotBoard> createState() => _PivotBoardState();
}

class _PivotBoardState extends State<PivotBoard> {
  double get bottomInset => widget.bottomInset ?? controlStrip(widget.game);
  final pointers = <int, int>{};
  final gripOffsets = <int, double>{};
  int epoch = -1;

  void synchronize() {
    if (epoch != widget.game.inputEpoch) {
      pointers.clear();
      gripOffsets.clear();
      epoch = widget.game.inputEpoch;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (!widget.game.oneFinger || widget.game.haloJoystick) {
        return buildBoard(context, bounds);
      }
      final scale = BoardViewport.forGame(
        bounds.biggest,
        widget.game,
        fillWidth: widget.fillWidth,
        bottomInset: bottomInset,
      ).scale;
      return Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(builder: buildBoard),
          Positioned(
            left: 0,
            right: 0,
            bottom: OneFingerControls.bottomMargin(widget.bottomPadding),
            height: OneFingerControls.extendedHeightFor(
              widget.game,
              widget.bottomPadding,
            ),
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
      bottomInset: bottomInset,
    );
    game.arenaStretch = viewportNow().stretch;
    game.visibleTop = -viewportNow().topExtension;
    game.visibleBottom = viewportNow().paintBottom;
    void release(PointerEvent event) {
      synchronize();
      final side = pointers.remove(event.pointer);
      if (side != null && side < 2) {
        gripOffsets.remove(side);
        game.releasePivot(side);
      }
    }

    final board = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        synchronize();
        if (!game.canControl ||
            game.bottomControls ||
            game.oneFinger ||
            game.boardTilt)
          return;
        final viewport = viewportNow();
        final side = event.localPosition.dx < viewport.rect.center.dx ? 0 : 1;
        if (!viewport.controlsSide(event.localPosition, side) ||
            pointers.containsValue(side))
          return;
        pointers[event.pointer] = side;
        final pivotY = viewport
            .project(
              Offset(0, game.screenY(side == 0 ? game.left : game.right)),
            )
            .dy;
        // Keep the handle on the same side of the platform for this gesture.
        gripOffsets[side] = viewport.gripCenter(game, side).dy - pivotY;
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
            (game.boardTilt
                ? 'Drag anywhere on the board sideways to tilt. Release to keep the angle. No manual lift.'
                : game.tiltLift
                ? 'Drag the bottom slider sideways to tilt. Manual lift is disabled in this test mode.'
                : game.analog
                ? 'Use the bottom left and right vertical joysticks to move the platform ends'
                : game.oneFinger
                ? game.haloJoystick
                      ? 'Touch anywhere on the board to tilt and lift with the floating Halo joystick'
                      : 'Use the thumb area below the board to tilt and lift'
                : 'Drag up or down on the left or right half of the board to move that end of the platform'),
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
                  bottomInset: bottomInset,
                  showHud: widget.overlay == null,
                  gripOffsets: gripOffsets,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            if (widget.dimUntilInput)
              Positioned.fill(
                bottom: game.oneFinger && !game.haloJoystick ? bottomInset : 0,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: AnimatedBuilder(
                      animation: widget.frame,
                      builder: (context, _) => game.waitingForInput
                          ? const ColoredBox(
                              key: ValueKey('infinite-start-dimmer'),
                              color: Color(0x73000000),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            if (game.oneFinger && game.haloJoystick)
              OneFingerControls(
                key: const ValueKey('halo-joystick'),
                game: game,
                frame: widget.frame,
                boardScale: viewportNow().scale,
              ),
            if (widget.showHint &&
                !game.bottomControls &&
                !game.oneFinger &&
                !game.boardTilt)
              ControlHint(
                anchors: [
                  for (final side in [0, 1])
                    viewportNow().gripCenter(game, side),
                ],
              ),
            if (widget.overlay != null)
              Positioned.fromRect(
                rect: usesWideStage(bounds.biggest)
                    ? Offset.zero & bounds.biggest
                    : viewportNow().rect.intersect(
                        Offset.zero & bounds.biggest,
                      ),
                child: widget.overlay!,
              ),
          ],
        ),
      ),
    );
    return game.boardTilt
        ? BoardTiltControls(game: game, frame: widget.frame, child: board)
        : board;
  }
}
