import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'board_painter.dart';

/// A cut-out follows real layout coordinates, including moving world objects.
/// Gameplay input passes through; menu guidance accepts only the lit target.
class TutorialSpotlight extends StatefulWidget {
  const TutorialSpotlight({
    super.key,
    required this.targets,
    required this.message,
    required this.onSkip,
    this.blockOutside = false,
    this.listenable,
    this.bottomInset = 16,
    this.messageTop,
  });
  final List<Rect> Function(RenderBox layer) targets;
  final String message;
  final VoidCallback onSkip;
  final bool blockOutside;
  final Listenable? listenable;
  final double bottomInset;
  final double? messageTop;
  @override
  State<TutorialSpotlight> createState() => _TutorialSpotlightState();
}

class _TutorialSpotlightState extends State<TutorialSpotlight>
    with SingleTickerProviderStateMixin {
  final layerKey = GlobalKey();
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant TutorialSpotlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Targets may have just entered the tree. Reduced motion has no pulse
    // ticker to measure them after layout, so explicitly refresh once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      pulse.stop();
      pulse.value = .5;
    } else {
      pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    key: layerKey,
    child: AnimatedBuilder(
      animation: Listenable.merge([
        pulse,
        if (widget.listenable != null) widget.listenable!,
      ]),
      builder: (context, _) {
        final layer = layerKey.currentContext?.findRenderObject() as RenderBox?;
        final rects = layer != null && layer.hasSize
            ? widget.targets(layer)
            : <Rect>[];
        final height = layer != null && layer.hasSize
            ? layer.size.height
            : MediaQuery.sizeOf(context).height;
        final anchor = rects.firstOrNull;
        final top =
            widget.messageTop ??
            (anchor == null
                ? 100.0
                : anchor.bottom + 130 < height - widget.bottomInset
                ? anchor.bottom + 14
                : math.max(40.0, anchor.top - 110));
        return Stack(
          fit: StackFit.expand,
          children: [
            if (widget.blockOutside)
              _OutsideBarrier(
                holes: rects,
                child: const ColoredBox(color: Colors.transparent),
              ),
            IgnorePointer(
              child: CustomPaint(
                painter: _SpotlightPainter(
                  rects,
                  pulse.value,
                  widget.blockOutside,
                ),
              ),
            ),
            Positioned(
              top: top,
              left: 20,
              right: 20,
              child: IgnorePointer(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    child: Semantics(
                      key: ValueKey(widget.message),
                      liveRegion: true,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 330),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: ink,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: brass.withAlpha(160)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x25000000),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: cream,
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: widget.bottomInset,
              child: TextButton(
                key: const ValueKey('skip-tutorial'),
                onPressed: widget.onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: cream,
                  backgroundColor: ink.withAlpha(210),
                ),
                child: const Text(
                  'Skip Tutorial',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Rect? tutorialTarget(GlobalKey key, RenderBox layer) {
  final target = key.currentContext?.findRenderObject();
  if (target is! RenderBox || !target.hasSize || !target.attached) return null;
  return layer.globalToLocal(target.localToGlobal(Offset.zero)) & target.size;
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.rects, this.pulse, this.menu);
  final List<Rect> rects;
  final double pulse;
  final bool menu;
  @override
  void paint(Canvas canvas, Size size) {
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    for (final rect in rects) {
      mask.addRRect(
        RRect.fromRectAndRadius(rect.inflate(5), const Radius.circular(18)),
      );
    }
    canvas.drawPath(mask, Paint()..color = ink.withAlpha(menu ? 145 : 62));
    for (final rect in rects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.inflate(5 + 3 * pulse),
          const Radius.circular(18),
        ),
        Paint()
          ..color = brass.withAlpha((180 + 75 * pulse).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
    if (rects.isNotEmpty) {
      final rect = rects.first;
      final y = rect.top - 10 - pulse * 5;
      if (y > 30) {
        final arrow = Path()
          ..moveTo(rect.center.dx - 6, y - 6)
          ..lineTo(rect.center.dx, y)
          ..lineTo(rect.center.dx + 6, y - 6);
        canvas.drawPath(
          arrow,
          Paint()
            ..color = brass
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => true;
}

class _OutsideBarrier extends SingleChildRenderObjectWidget {
  const _OutsideBarrier({required this.holes, required super.child});
  final List<Rect> holes;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _BarrierRender(holes);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _BarrierRender renderObject,
  ) => renderObject.holes = holes;
}

class _BarrierRender extends RenderProxyBox {
  _BarrierRender(this.holes);
  List<Rect> holes;
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (holes.any((rect) => rect.inflate(6).contains(position))) return false;
    return super.hitTest(result, position: position);
  }

  @override
  bool hitTestSelf(Offset position) => true;
}
