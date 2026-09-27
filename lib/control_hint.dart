import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'board_painter.dart';

/// A decorative demonstration, never a gesture target or a simulation ticker.
class ControlHint extends StatefulWidget {
  const ControlHint({
    super.key,
    required this.anchors,
    this.sideways = false,
    this.highlightBorder = false,
  });
  final List<Offset> anchors;
  final bool sideways;
  final bool highlightBorder;
  @override
  State<ControlHint> createState() => _ControlHintState();
}

class _ControlHintState extends State<ControlHint>
    with SingleTickerProviderStateMixin {
  late final motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      motion.stop();
      motion.value = 0;
    } else if (!motion.isAnimating) {
      motion.repeat();
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: motion,
        builder: (context, _) {
          final wave = math.sin(motion.value * math.pi * 2);
          return Stack(
            children: [
              if (widget.highlightBorder)
                Positioned.fill(
                  child: Container(
                    key: const ValueKey('one-finger-glow'),
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(
                          0xFFE9B64F,
                        ).withValues(alpha: .75 + .2 * wave),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFE9B64F,
                          ).withValues(alpha: .18 + .08 * wave),
                          blurRadius: 8 + 3 * wave,
                          spreadRadius: 1 + wave,
                        ),
                      ],
                    ),
                  ),
                ),
              for (var i = 0; i < widget.anchors.length; i++)
                Positioned(
                  left:
                      widget.anchors[i].dx -
                      15 +
                      (widget.sideways ? wave * 12 : 0),
                  top: widget.anchors[i].dy - 8 - wave * 18,
                  child: Icon(
                    Icons.touch_app_rounded,
                    key: ValueKey('hint-finger-$i'),
                    size: 34,
                    color: cream,
                    shadows: const [
                      Shadow(color: ink, blurRadius: 3),
                      Shadow(color: ink, offset: Offset(1, 1)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
