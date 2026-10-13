import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ball_cosmetics.dart';
import 'ball_painter.dart';
import 'ball_world.dart';
import 'menu_design.dart';
import 'game.dart' show GameMode;

/// Menu clocks repaint the decorative canvases only. They never advance a run.
class MenuMotion extends StatefulWidget {
  const MenuMotion({super.key, required this.enabled, required this.builder});
  final bool enabled;
  final Widget Function(
    BuildContext context,
    Animation<double> drift,
    Animation<double> reveal,
  )
  builder;

  @override
  State<MenuMotion> createState() => _MenuMotionState();
}

class _MenuMotionState extends State<MenuMotion>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );
  late final reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  bool visible = false;
  bool foreground = true;

  @override
  void initState() {
    super.initState();
    foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  void synchronize() {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final enabled =
        widget.enabled &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true) &&
        foreground;
    if (enabled && !reduced) {
      if (!drift.isAnimating) drift.repeat();
      if (!visible) reveal.forward(from: 0);
      if (visible && reveal.value < 1 && !reveal.isAnimating) reveal.forward();
    } else {
      drift.stop();
      reveal.stop();
      if (reduced) {
        drift.value = 0;
        reveal.value = 1;
      }
    }
    visible = enabled;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    synchronize();
  }

  @override
  void didUpdateWidget(covariant MenuMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    synchronize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    synchronize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    drift.dispose();
    reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, drift, reveal);
}

class MenuReveal extends StatelessWidget {
  const MenuReveal({super.key, required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final value = Curves.easeOutCubic.transform(animation.value);
      // Entrance animation changes paint only, so controls are usable immediately.
      return Transform.translate(
        offset: Offset(0, 8 * (1 - value)),
        child: Opacity(opacity: .4 + .6 * value, child: child),
      );
    },
  );
}

class PremiumMenuBackdrop extends CustomPainter {
  PremiumMenuBackdrop(this.ball, this.drift, {this.page = 0})
    : super(repaint: drift);
  final BallCosmetic ball;
  final double page;
  final Animation<double> drift;

  @override
  void paint(Canvas canvas, Size size) {
    final world = BallWorld.of(ball);
    final w = size.width, h = size.height;
    final phase = drift.value * math.pi * 2;
    Color modeColor(List<Color> colors) {
      final p = page.clamp(0.0, 2.0);
      return Color.lerp(colors[p.floor()], colors[p.ceil()], p - p.floor())!;
    }

    final horizon = Color.lerp(
      modeColor(const [
        Color(0xFF3A6666),
        Color(0xFF907442),
        Color(0xFF8265AF),
      ]),
      world.accent,
      .18,
    )!;
    final night = modeColor(const [
      Color(0xFF07171E),
      Color(0xFF201B14),
      Color(0xFF1C162E),
    ]);
    final middle = modeColor(const [
      Color(0xFF183336),
      Color(0xFF36352A),
      Color(0xFF302944),
    ]);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, .38, .64, 1],
          colors: [
            night,
            Color.lerp(const Color(0xFF24474D), horizon, .45)!,
            middle,
            menuBackground,
          ],
        ).createShader(Offset.zero & size),
    );
    final light = Offset(w * (.58 + .012 * math.sin(phase)), h * .31);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [horizon.withAlpha(95), horizon.withAlpha(0)],
        ).createShader(Rect.fromCircle(center: light, radius: w * .95)),
    );

    // Far architecture: large quiet silhouettes, softened by the lit horizon.
    for (final side in [-1.0, 1.0]) {
      final x = w * .5 + side * w * .35;
      final shift = math.sin(phase) * side * 1.5;
      final top = h * .23 + shift;
      canvas.drawPath(
        Path()
          ..moveTo(x - w * .09, h * .58)
          ..lineTo(x - w * .09, top + h * .07)
          ..lineTo(x, top)
          ..lineTo(x + w * .09, top + h * .04)
          ..lineTo(x + w * .09, h * .58)
          ..close(),
        Paint()..color = const Color(0xFF142F38).withAlpha(140),
      );
      canvas.drawLine(
        Offset(x, top),
        Offset(x, h * .53),
        Paint()
          ..color = horizon.withAlpha(40)
          ..strokeWidth = 1,
      );
    }
    final arch = Rect.fromCenter(
      center: Offset(w * .5, h * .37),
      width: w * .9,
      height: w * .9,
    );
    canvas.drawArc(
      arch,
      math.pi * 1.04,
      math.pi * .92,
      false,
      Paint()
        ..color = const Color(0xFF6D9591).withAlpha(30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .055,
    );
    canvas.drawArc(
      arch.deflate(w * .026),
      math.pi * 1.05,
      math.pi * .9,
      false,
      Paint()
        ..color = menuGold.withAlpha(25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // A shaft of warm light and distant terraces add depth without a texture.
    canvas.drawPath(
      Path()
        ..moveTo(w * .62, h * .14)
        ..lineTo(w * .8, h * .14)
        ..lineTo(w * .46, h * .62)
        ..lineTo(w * .28, h * .62)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [menuGold.withAlpha(13), menuGold.withAlpha(0)],
        ).createShader(Offset.zero & size),
    );
    for (var i = 0; i < 3; i++) {
      final y = h * (.55 + i * .075);
      canvas.drawPath(
        Path()
          ..moveTo(0, y + h * .05)
          ..lineTo(w * .25, y)
          ..lineTo(w * .75, y + h * .015)
          ..lineTo(w, y - h * .025)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close(),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF233F42),
            menuBackground,
            (i + 1) / 4,
          )!,
      );
    }
    for (var i = 0; i < 7; i++) {
      final x = w * (.14 + ((i * .137) % .72)) + math.sin(phase + i) * 4;
      final y = h * (.22 + ((i * .081) % .31)) + math.cos(phase + i) * 5;
      canvas.drawCircle(
        Offset(x, y),
        i.isEven ? 1.2 : .7,
        Paint()..color = menuGold.withAlpha(35 + (i % 3) * 8),
      );
    }
  }

  @override
  bool shouldRepaint(PremiumMenuBackdrop old) =>
      old.ball != ball || old.drift != drift || old.page != page;
}

class MenuBallStage extends CustomPainter {
  MenuBallStage(
    this.ball,
    this.drift, {
    required this.reducedMotion,
    this.mode = GameMode.infinite,
  }) : super(repaint: drift);
  final BallCosmetic ball;
  final GameMode mode;
  final Animation<double> drift;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = reducedMotion ? 0.0 : drift.value * math.pi * 2;
    final w = size.width, h = size.height;
    final radius = math.min(w * .17, h * .19);
    final center = Offset(w * .5, h * .47 + math.sin(phase) * 3);
    final baseY = h * .47 + radius * 1.75;
    final rx = radius * 2.2, ry = radius * .55;

    if (mode == GameMode.merge2048) {
      paintMergeStage(canvas, center.dx, baseY, radius, phase);
    } else if (mode == GameMode.classic) {
      paintClassicStage(canvas, center.dx, baseY, radius, phase);
    } else {
      // Three suspended stone steps, rendered with the game's native canvas.
      for (var i = 2; i >= 0; i--) {
        final spread = 1 + i * .16;
        final y = baseY + i * radius * .28;
        final edge = Path()
          ..moveTo(center.dx - rx * spread, y)
          ..lineTo(center.dx, y + ry * spread)
          ..lineTo(center.dx + rx * spread, y)
          ..lineTo(center.dx + rx * spread, y + radius * .2)
          ..lineTo(center.dx, y + ry * spread + radius * .2)
          ..lineTo(center.dx - rx * spread, y + radius * .2)
          ..close();
        canvas.drawPath(
          edge,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFF152C31), Color(0xFF29464A), Color(0xFF10262C)],
            ).createShader(edge.getBounds()),
        );
        final top = Path()
          ..moveTo(center.dx, y - ry * spread)
          ..lineTo(center.dx + rx * spread, y)
          ..lineTo(center.dx, y + ry * spread)
          ..lineTo(center.dx - rx * spread, y)
          ..close();
        canvas.drawPath(
          top,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF648481), Color(0xFF335359)],
            ).createShader(top.getBounds()),
        );
        canvas.drawPath(
          top,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .8
            ..color = menuGold.withAlpha(i == 0 ? 70 : 25),
        );
      }
    }
    final shadow = Rect.fromCenter(
      center: Offset(center.dx, baseY),
      width: radius * (2.5 - math.sin(phase) * .04),
      height: radius * .48,
    );
    canvas.save();
    canvas.translate(shadow.center.dx, shadow.center.dy);
    canvas.scale(shadow.width / 2, shadow.height / 2);
    canvas.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = RadialGradient(
          radius: .5,
          colors: [
            const Color(0xFF061318).withAlpha(150),
            const Color(0x00061318),
          ],
        ).createShader(const Rect.fromLTRB(-1, -1, 1, 1)),
    );
    canvas.restore();
    canvas.drawCircle(
      center,
      radius * 2.5,
      Paint()
        ..shader = RadialGradient(
          colors: [BallWorld.of(ball).accent.withAlpha(30), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 2.5)),
    );
    paintCosmetic(
      canvas,
      center,
      radius,
      ball,
      time: phase,
      rotation: math.sin(phase) * .035,
      reducedMotion: reducedMotion,
    );
  }

  void paintMergeStage(
    Canvas canvas,
    double x,
    double y,
    double r,
    double phase,
  ) {
    const colors = [
      Color(0xFF70D8CA),
      Color(0xFFAA86F1),
      Color(0xFFF29A87),
      Color(0xFFF2CD77),
    ];
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        final cx = x + (col - row) * r * .72;
        final cy = y + (col + row - 2) * r * .26;
        final color = colors[(row * 3 + col) % colors.length];
        final top = Path()
          ..moveTo(cx, cy - r * .24)
          ..lineTo(cx + r * .68, cy)
          ..lineTo(cx, cy + r * .24)
          ..lineTo(cx - r * .68, cy)
          ..close();
        final side = Path()
          ..moveTo(cx - r * .68, cy)
          ..lineTo(cx, cy + r * .24)
          ..lineTo(cx + r * .68, cy)
          ..lineTo(cx + r * .68, cy + r * .2)
          ..lineTo(cx, cy + r * .44)
          ..lineTo(cx - r * .68, cy + r * .2)
          ..close();
        canvas.drawPath(
          side,
          Paint()..color = Color.lerp(color, menuBackground, .55)!,
        );
        canvas.drawPath(
          top,
          Paint()
            ..shader = LinearGradient(
              colors: [Color.lerp(color, Colors.white, .25)!, color],
            ).createShader(top.getBounds()),
        );
        canvas.drawPath(
          top,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.white.withAlpha(90),
        );
        final label = TextPainter(
          text: TextSpan(
            text: '${1 << ((row + col) % 3 + 1)}',
            style: TextStyle(
              fontFamily: 'sans-serif',
              fontSize: r * .19,
              fontWeight: FontWeight.w800,
              color: menuBackground.withAlpha(170),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(
          canvas,
          Offset(cx - label.width / 2, cy - label.height / 2),
        );
      }
    }
    for (var i = 0; i < 3; i++) {
      final p = Offset(
        x + (i - 1) * r * 1.6,
        y - r * (1.1 + .15 * math.sin(phase + i)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: r * .22, height: r * .22),
          Radius.circular(r * .04),
        ),
        Paint()..color = colors[i].withAlpha(130),
      );
    }
  }

  void paintClassicStage(
    Canvas canvas,
    double x,
    double y,
    double r,
    double phase,
  ) {
    final base = Rect.fromCenter(
      center: Offset(x, y + r * .17),
      width: r * 4.5,
      height: r * 1.2,
    );
    canvas.drawOval(
      base,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF785C37), Color(0xFF302F2A)],
        ).createShader(base),
    );
    final top = Rect.fromCenter(
      center: Offset(x, y),
      width: r * 4.5,
      height: r * .95,
    );
    canvas.drawOval(
      top,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFE1C88D), Color(0xFF927B53)],
        ).createShader(top),
    );
    canvas.drawOval(
      top.deflate(r * .12),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .025
        ..color = const Color(0xFF655638),
    );
    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi * 2 / 16;
      canvas.drawLine(
        Offset(x + math.cos(angle) * r * 1.95, y + math.sin(angle) * r * .37),
        Offset(x + math.cos(angle) * r * 2.12, y + math.sin(angle) * r * .42),
        Paint()
          ..color = const Color(0xFF6D5638)
          ..strokeWidth = r * .025,
      );
    }
    for (final side in [-1, 1]) {
      final postX = x + side * r * 1.8;
      final post = RRect.fromRectAndRadius(
        Rect.fromLTRB(postX - r * .1, y - r * .65, postX + r * .1, y),
        Radius.circular(r * .05),
      );
      canvas.drawRRect(
        post,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFADE99), Color(0xFF75643F)],
          ).createShader(post.outerRect),
      );
      canvas.drawCircle(
        Offset(postX, y - r * .72),
        r * .13,
        Paint()..color = menuGold,
      );
    }
    final arch = Path()
      ..moveTo(x - r * 1.8, y - r * .65)
      ..cubicTo(
        x - r * 1.9,
        y - r * 3.6,
        x + r * 1.9,
        y - r * 3.6,
        x + r * 1.8,
        y - r * .65,
      );
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .055
        ..color = menuGold.withAlpha(105),
    );
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .013
        ..color = menuGold,
    );
  }

  @override
  bool shouldRepaint(MenuBallStage old) =>
      old.mode != mode ||
      old.ball != ball ||
      old.drift != drift ||
      old.reducedMotion != reducedMotion;
}

/// A thumb-sized bespoke control with keyboard and screen-reader support.
class PremiumPlayButton extends StatefulWidget {
  const PremiumPlayButton({
    super.key,
    required this.onPressed,
    this.height = 64,
  });
  final VoidCallback? onPressed;
  final double height;
  @override
  State<PremiumPlayButton> createState() => _PremiumPlayButtonState();
}

class _PremiumPlayButtonState extends State<PremiumPlayButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return AnimatedScale(
      scale: pressed && enabled ? .985 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: Opacity(
        opacity: enabled ? 1 : .55,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF5D9A0), Color(0xFFDDB574)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(45),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
              const BoxShadow(color: Color(0xFF99783F), offset: Offset(0, 3)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onPressed,
              onHighlightChanged: (value) => setState(() => pressed = value),
              splashColor: Colors.white.withAlpha(30),
              highlightColor: Colors.black.withAlpha(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    const Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'PLAY',
                            style: TextStyle(
                              fontFamily: 'sans-serif',
                              color: Color(0xFF243239),
                              fontSize: 19,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.play_arrow_rounded,
                      size: 24,
                      color: Color(0xFF243239),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MenuQuietButton extends StatelessWidget {
  const MenuQuietButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
    this.badge = false,
  });
  final IconData icon;
  final String tooltip;
  final String? label;
  final VoidCallback? onPressed;
  final bool badge;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: label == null ? 48 : 64,
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 21, color: menuMuted),
                  if (badge)
                    Positioned(
                      right: -4,
                      top: -1,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: menuGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              if (label != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: SizedBox(
                    height: 16,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label!,
                        style: const TextStyle(
                          fontFamily: 'sans-serif',
                          fontSize: 10,
                          color: menuMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

String formatMenuScore(int score) => score.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]},',
);

class MenuBestScore extends StatelessWidget {
  const MenuBestScore({super.key, required this.score});
  final int score;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Best score: $score',
    excludeSemantics: true,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_outlined, color: menuGold, size: 15),
          const SizedBox(width: 7),
          const Text(
            'BEST',
            style: TextStyle(
              color: menuMuted,
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            formatMenuScore(score),
            key: const ValueKey('menu-best-score'),
            style: const TextStyle(
              color: menuText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class MenuEarnedStars extends StatelessWidget {
  const MenuEarnedStars({super.key, required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$stars Classic stars earned',
    excludeSemantics: true,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: menuGold, size: 25),
          const SizedBox(width: 7),
          Text(
            formatMenuScore(stars),
            key: const ValueKey('menu-earned-stars'),
            style: const TextStyle(
              color: menuText,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class MenuActionButton extends StatelessWidget {
  const MenuActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final String label, tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: SizedBox(
      height: 60,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2C4448),
          foregroundColor: menuText,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'sans-serif',
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 26),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
      ),
    ),
  );
}
