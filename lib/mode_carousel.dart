import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'game.dart';

/// The four arcade worlds, in their permanent navigation order.
const arcadeModes = [
  GameMode.infinite,
  GameMode.classic,
  GameMode.laserMaze,
  GameMode.merge2048,
];

/// A page viewport with a screen-wide swipe surface. Its recognizer never
/// enters the arena for a control touch, and is absent during gameplay.
class ModeCarousel extends StatefulWidget {
  const ModeCarousel({
    super.key,
    required this.selected,
    required this.locked,
    required this.acceptSwipe,
    required this.onMoving,
    required this.onSelected,
    required this.worldBuilder,
    required this.builder,
    this.controlInset = 0,
    this.expansion = 0,
  });

  final int selected;
  final bool locked;
  final double controlInset;
  final double expansion;
  final bool Function(Offset globalPosition) acceptSwipe;
  final ValueChanged<bool> onMoving;
  final ValueChanged<int> onSelected;
  final Widget Function(BuildContext, int) worldBuilder;
  final Widget Function(BuildContext, Widget worlds, double page) builder;

  @override
  State<ModeCarousel> createState() => ModeCarouselState();
}

class ModeCarouselState extends State<ModeCarousel> {
  late final PageController controller = PageController(
    initialPage: widget.selected,
    viewportFraction: .88,
  );
  bool moving = false;
  int origin = 0, generation = 0;
  double get page =>
      controller.hasClients && controller.position.hasContentDimensions
      ? controller.page ?? widget.selected.toDouble()
      : widget.selected.toDouble();

  @override
  void didUpdateWidget(covariant ModeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected && !moving) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.hasClients && !moving) {
          controller.jumpToPage(widget.selected);
        }
      });
    }
  }

  Future<void> select(int index) async {
    if (widget.locked || moving || index == widget.selected) return;
    moving = true;
    origin = widget.selected;
    widget.onMoving(true);
    await settle(index.clamp(0, arcadeModes.length - 1));
  }

  /// Direct launches from a level picker center before the next frame paints.
  void jumpTo(int index) {
    generation++;
    moving = false;
    if (controller.hasClients) controller.jumpToPage(index);
  }

  void dragStart(DragStartDetails details) {
    if (widget.locked || moving) return;
    moving = true;
    origin = widget.selected;
    widget.onMoving(true);
  }

  void dragUpdate(DragUpdateDetails details) {
    if (!moving || widget.locked || !controller.hasClients) return;
    final position = controller.position;
    final stride = position.viewportDimension * controller.viewportFraction;
    // A gesture traverses at most one world. Clamping at the ends prevents
    // rubber-band blanks and keeps the selected environment centered.
    controller.jumpTo(
      (position.pixels - details.delta.dx).clamp(
        ((origin - 1) * stride).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
        ((origin + 1) * stride).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      ),
    );
  }

  void dragEnd(DragEndDetails details) {
    if (!moving || widget.locked) return;
    final velocity = details.primaryVelocity ?? 0;
    final displacement = page - origin;
    final target = velocity.abs() > 450
        ? origin + (velocity < 0 ? 1 : -1)
        : displacement.abs() > .22
        ? origin + displacement.sign.toInt()
        : origin;
    settle(target.clamp(0, arcadeModes.length - 1));
  }

  Future<void> settle(int index) async {
    final token = ++generation;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpToPage(index);
    } else {
      await controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted || token != generation) return;
    moving = false;
    widget.onSelected(index);
    widget.onMoving(false);
  }

  @override
  void dispose() {
    generation++;
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    behavior: HitTestBehavior.translucent,
    gestures: widget.locked
        ? const {}
        : {
            _WorldSwipe: GestureRecognizerFactoryWithHandlers<_WorldSwipe>(
              () => _WorldSwipe(),
              (recognizer) {
                recognizer.accept = (position) =>
                    !moving && !widget.locked && widget.acceptSwipe(position);
                recognizer.onStart = dragStart;
                recognizer.onUpdate = dragUpdate;
                recognizer.onEnd = dragEnd;
                recognizer.onCancel = () {
                  if (moving) settle(origin);
                };
              },
            ),
          },
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => widget.builder(
        context,
        LayoutBuilder(
          builder: (context, bounds) => OverflowBox(
            minWidth: bounds.maxWidth * (1 + widget.expansion * (1 / .88 - 1)),
            maxWidth: bounds.maxWidth * (1 + widget.expansion * (1 / .88 - 1)),
            child: PageView.builder(
              key: const ValueKey('mode-worlds'),
              controller: controller,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: arcadeModes.length,
              itemBuilder: (context, index) {
                final distance = (page - index).clamp(-1.0, 1.0);
                final reduced = MediaQuery.disableAnimationsOf(context);
                return LayoutBuilder(
                  builder: (context, bounds) {
                    final boardWidth =
                        ((bounds.maxHeight - widget.controlInset) *
                                BalanceGame.width /
                                BalanceGame.height)
                            .clamp(0.0, bounds.maxWidth);
                    final inset = (bounds.maxWidth - boardWidth) / 2 + 24;
                    return ClipRect(
                      child: Transform.translate(
                        offset: Offset(distance * inset, 0),
                        child: Transform.scale(
                          scale: reduced ? 1 : 1 - distance.abs() * .055,
                          child: Opacity(
                            opacity: 1 - distance.abs() * .35,
                            child: ExcludeSemantics(
                              excluding: index != widget.selected,
                              child: widget.worldBuilder(context, index),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        page,
      ),
    ),
  );
}

class _WorldSwipe extends HorizontalDragGestureRecognizer {
  bool Function(Offset)? accept;
  @override
  bool isPointerAllowed(PointerEvent event) =>
      (accept?.call(event.position) ?? false) && super.isPointerAllowed(event);
}
