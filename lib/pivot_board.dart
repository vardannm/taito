import 'one_finger_controls.dart';
import 'board_tilt_controls.dart';
import 'control_hint.dart';
import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'game.dart';
import 'responsive_layout.dart';
import 'two_finger_feedback.dart';

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
    this.fitHeight = false,
    this.contentTop,
  });
  final BalanceGame game;
  final Listenable frame;
  final double fillWidth;

  /// Fit the complete route when a side cutout leaves a short, wide display.
  final bool fitHeight;
  final double? contentTop;

  /// Keeps gameplay above the controls while scenery fills the whole widget.
  final double? bottomInset;

  /// Keeps the thumb pad clear of the device's home indicator.
  final double bottomPadding;
  final bool showHint;
  final bool dimUntilInput;
  final Widget? overlay;

  // Only landscape arenas narrow; scenery still paints the full window.
  double _arenaWidthFraction(Size window) =>
      usesWideStage(window) && window.width > window.height ? .41 : .74;

  double get _bottomInset => bottomInset ?? controlStrip(game);

  BoardViewport viewportFor(Size size, Size window) => BoardViewport.forGame(
    size,
    game,
    fillWidth: fillWidth,
    bottomInset: _bottomInset,
    fitHeight: fitHeight,
    contentTop: contentTop,
    arenaWidthFraction: _arenaWidthFraction(window),
  );

  @override
  State<PivotBoard> createState() => _PivotBoardState();
}

class _PivotBoardState extends State<PivotBoard> {
  final pointers = <int, int>{};
  // Where each side's finger is, for the two-finger feedback overlay.
  final fingers = <int, Offset>{};
  int epoch = -1;

  void synchronize() {
    if (epoch != widget.game.inputEpoch) {
      pointers.clear();
      fingers.clear();
      epoch = widget.game.inputEpoch;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (!widget.game.oneFinger || widget.game.haloJoystick) {
        return buildBoard(context, bounds);
      }
      final scale = widget
          .viewportFor(bounds.biggest, MediaQuery.sizeOf(context))
          .scale;
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
    final window = MediaQuery.sizeOf(context);
    synchronize();
    BoardViewport viewportNow() => widget.viewportFor(bounds.biggest, window);
    game.arenaStretch = viewportNow().stretch;
    game.visibleTop = -viewportNow().topExtension;
    game.visibleBottom = viewportNow().paintBottom;
    final twoFinger =
        !game.bottomControls && !game.oneFinger && !game.boardTilt;
    void release(PointerEvent event) {
      synchronize();
      final side = pointers.remove(event.pointer);
      if (side != null && side < 2) {
        fingers.remove(side);
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
        fingers[side] = event.localPosition;
        game.grabPivot(side);
      },
      onPointerMove: (event) {
        synchronize();
        final side = pointers[event.pointer];
        if (side == null || !game.canControl || epoch != game.inputEpoch)
          return;
        fingers[side] = event.localPosition;
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
                  fitHeight: widget.fitHeight,
                  contentTop: widget.contentTop,
                  arenaWidthFraction: widget._arenaWidthFraction(window),
                  bottomInset: widget._bottomInset,
                  showHud: widget.overlay == null,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            if (twoFinger)
              IgnorePointer(
                child: CustomPaint(
                  painter: TwoFingerFeedbackPainter(
                    game,
                    viewportNow,
                    fingers,
                    arrows: !widget.showHint,
                    repaint: widget.frame,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            if (game.oneFinger && game.haloJoystick)
              OneFingerControls(
                key: const ValueKey('halo-joystick'),
                game: game,
                frame: widget.frame,
                boardScale: viewportNow().scale,
              ),
            if (widget.showHint && twoFinger)
              ControlHint(
                anchors: [
                  for (final side in [0, 1])
                    TwoFingerFeedbackPainter.halfCenter(
                      viewportNow(),
                      game,
                      side,
                    ),
                ],
              ),
            if (widget.dimUntilInput)
              Positioned.fill(
                bottom: game.oneFinger && !game.haloJoystick
                    ? widget._bottomInset
                    : 0,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: AnimatedBuilder(
                      animation: widget.frame,
                      builder: (context, _) => game.waitingForInput
                          ? CustomPaint(
                              key: const ValueKey('infinite-start-dimmer'),
                              painter: _StartDimmerPainter(
                                holes: twoFinger
                                    ? [
                                        for (final side in [0, 1])
                                          TwoFingerFeedbackPainter.halfCenter(
                                            viewportNow(),
                                            game,
                                            side,
                                          ),
                                      ]
                                    : const [],
                              ),
                              child: const SizedBox.expand(),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
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

/// Neutral shade with clear windows over the in-board two-finger controls.
class _StartDimmerPainter extends CustomPainter {
  const _StartDimmerPainter({required this.holes});
  final List<Offset> holes;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    for (final center in holes) {
      path.addOval(Rect.fromCircle(center: center, radius: 66));
    }
    canvas.drawPath(path, Paint()..color = const Color(0xB3000000));
  }

  @override
  bool shouldRepaint(_StartDimmerPainter old) {
    if (old.holes.length != holes.length) return true;
    for (var i = 0; i < holes.length; i++) {
      if (old.holes[i] != holes[i]) return true;
    }
    return false;
  }
}
