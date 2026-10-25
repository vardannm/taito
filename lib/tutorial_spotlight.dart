import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'menu_design.dart';

/// A cut-out follows real layout coordinates, including moving world objects.
/// Gameplay input passes through; menu guidance accepts only the lit target.
class TutorialSpotlight extends StatefulWidget {
  const TutorialSpotlight({
    super.key,
    required this.targets,
    required this.message,
    required this.onSkip,
    this.title,
    this.icon = Icons.school_rounded,
    this.badge,
    this.lesson,
    this.lessons,
    this.blockOutside = false,
    this.listenable,
    this.bottomInset = 16,
    this.messageTop,
  });
  final List<Rect> Function(RenderBox layer) targets;
  final String message;
  final String? title;
  final IconData icon;

  /// Replaces the lit [icon] disc, such as with the painted coin.
  final Widget? badge;

  /// Shown as "lesson of lessons" above a segmented progress bar.
  final int? lesson, lessons;
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

  /// Room the card needs below a target. Above a target the card is anchored
  /// by its bottom edge, so its exact height never matters there.
  static const cardRoom = 200.0;

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
        final above =
            widget.messageTop == null &&
            anchor != null &&
            anchor.bottom + cardRoom >= height - widget.bottomInset &&
            anchor.top >= cardRoom + 40;
        final reduced = MediaQuery.disableAnimationsOf(context);
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
                  arrowAbove: !above,
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: above
                  ? null
                  : widget.messageTop ??
                        (anchor == null ? 100.0 : anchor.bottom + 22),
              bottom: above ? height - anchor.top + 24 : null,
              child: Align(
                alignment: above ? Alignment.bottomCenter : Alignment.topCenter,
                // One Skip outlives the cards cross-fading beneath it.
                child: Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, .08),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _TutorialCard(
                        key: ValueKey('${widget.title}|${widget.message}'),
                        title: widget.title,
                        message: widget.message,
                        icon: widget.icon,
                        badge: widget.badge,
                        lesson: widget.lesson,
                        lessons: widget.lessons,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: TextButton(
                        key: const ValueKey('skip-tutorial'),
                        onPressed: widget.onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: menuMuted,
                          backgroundColor: menuBackground.withAlpha(150),
                          minimumSize: const Size(54, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: const StadiumBorder(
                            side: BorderSide(color: menuLine),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text(
                          'Skip',
                          semanticsLabel: 'Skip tutorial',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// The lesson card: a lit icon, the lesson count and title, the instruction
/// and a progress bar. It ignores touches, so play continues beneath it.
class _TutorialCard extends StatelessWidget {
  const _TutorialCard({
    super.key,
    required this.message,
    required this.icon,
    this.title,
    this.badge,
    this.lesson,
    this.lessons,
  });
  final String message;
  final String? title;
  final IconData icon;
  final Widget? badge;
  final int? lesson, lessons;

  @override
  Widget build(BuildContext context) {
    final count = lessons ?? 0;
    final current = (lesson ?? 0).clamp(0, count);
    final body = Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [menuRaised.withAlpha(246), menuPanel.withAlpha(250)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: menuGold.withAlpha(120)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(90),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
          BoxShadow(color: menuGold.withAlpha(30), blurRadius: 18),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (badge != null)
                SizedBox.square(dimension: 38, child: Center(child: badge))
              else
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment(-.3, -.4),
                      colors: [Color(0xFFFFE6A8), menuGold, Color(0xFFB98A3E)],
                      stops: [0, .55, 1],
                    ),
                  ),
                  child: Icon(icon, size: 20, color: menuBackground),
                ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count > 0 ? 'TUTORIAL · $current OF $count' : 'TUTORIAL',
                      style: const TextStyle(
                        color: menuGold,
                        fontSize: 9,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (title != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        title!,
                        style: const TextStyle(
                          color: menuText,
                          fontSize: 17,
                          height: 1.15,
                          letterSpacing: -.3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Room for the Skip chip laid over this corner.
              const SizedBox(width: 62),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              color: menuText.withAlpha(228),
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (count > 1) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 1; i <= count; i++) ...[
                  if (i > 1) const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: i < current
                            ? menuGold.withAlpha(140)
                            : i == current
                            ? menuGold
                            : menuLine,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
    return Semantics(liveRegion: true, child: IgnorePointer(child: body));
  }
}

Rect? tutorialTarget(GlobalKey key, RenderBox layer) {
  final target = key.currentContext?.findRenderObject();
  if (target is! RenderBox || !target.hasSize || !target.attached) return null;
  return layer.globalToLocal(target.localToGlobal(Offset.zero)) & target.size;
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(
    this.rects,
    this.pulse,
    this.menu, {
    this.arrowAbove = true,
  });
  final List<Rect> rects;
  final double pulse;
  final bool menu;

  /// False when the card sits right above the target, where the arrow goes.
  final bool arrowAbove;
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
    canvas.drawPath(
      mask,
      Paint()..color = menuBackground.withAlpha(menu ? 170 : 66),
    );
    for (final rect in rects) {
      final ring = RRect.fromRectAndRadius(
        rect.inflate(5 + 3 * pulse),
        const Radius.circular(18),
      );
      canvas.drawRRect(
        ring,
        Paint()
          ..color = menuGold.withAlpha((40 + 50 * pulse).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8,
      );
      canvas.drawRRect(
        ring,
        Paint()
          ..color = menuGold.withAlpha((190 + 65 * pulse).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
    if (rects.isNotEmpty && arrowAbove) {
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
            ..color = menuGold
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
