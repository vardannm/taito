import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ball_cosmetics.dart';
import 'ball_painter.dart';
import 'ball_world.dart';
import 'menu_design.dart';
import 'game.dart' show GameMode;
import 'platform_painter.dart';
import 'platforms.dart';

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

    final night = modeColor(const [
      Color(0xFF07171E),
      Color(0xFF201B14),
      Color(0xFF1C162E),
    ]);
    // The equipped ball's own world fills the screen, scaled to cover it, so
    // a new ball changes the whole menu. The scenery picture is cached.
    final scale = math.max(w / 340, h / 540);
    final art = Rect.fromCenter(
      center: Offset(w / 2, h * .42),
      width: 340 * scale,
      height: 540 * scale,
    );
    canvas.drawRect(Offset.zero & size, Paint()..color = world.bottom);
    canvas.save();
    // A slow breath of movement keeps the scene alive without distraction.
    canvas.translate(0, math.sin(phase) * 2);
    paintBallWorld(canvas, art.inflate(4), ball);
    canvas.restore();
    // Dim the top behind the title and fade into the menu colour behind the
    // buttons, so text stays readable and the ball stays the brightest thing.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, .3, .62, .84, 1],
          colors: [
            night.withAlpha(150),
            night.withAlpha(60),
            night.withAlpha(40),
            menuBackground.withAlpha(185),
            menuBackground,
          ],
        ).createShader(Offset.zero & size),
    );
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
    this.platform = PlatformStyle.classic,
  }) : super(repaint: drift);
  final BallCosmetic ball;
  final GameMode mode;
  final PlatformStyle platform;
  final Animation<double> drift;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = reducedMotion ? 0.0 : drift.value * math.pi * 2;
    final w = size.width, h = size.height;
    final radius = math.min(w * .17, h * .19);
    final center = Offset(w * .5, h * .47 + math.sin(phase) * 3);
    final tint = Color(platform.color);
    final baseY = h * .47 + radius * 1.75;

    if (mode == GameMode.merge2048) {
      paintMergeStage(canvas, center.dx, baseY, radius, phase);
    }
    // No pedestal in Infinite or Classic: the rail floats, lighting the
    // ground below.
    // The equipped rail lights the stage below it.
    final pool = Rect.fromCenter(
      center: Offset(center.dx, baseY),
      width: radius * 5.2,
      height: radius * .9,
    );
    canvas.drawOval(
      pool,
      Paint()
        ..shader = RadialGradient(
          colors: [
            tint.withAlpha(platform.energized ? 75 : 45),
            tint.withAlpha(0),
          ],
        ).createShader(pool),
    );
    final shadow = Rect.fromCenter(
      center: Offset(center.dx, baseY),
      width: radius * (4.8 - math.sin(phase) * .08),
      height: radius * .42,
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
    paintRail(canvas, center + Offset(0, radius * 1.15), radius, phase);
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

  /// The equipped rail, held level under the ball like a display plinth.
  /// Drawn in game units so every style keeps its in-game detail.
  void paintRail(Canvas canvas, Offset mid, double r, double phase) {
    final tint = Color(platform.color);
    const half = 2.35 * 18;
    final scale = r / 18;
    const a = Offset(-half, 0), b = Offset(half, 0);
    canvas.save();
    canvas.translate(mid.dx, mid.dy);
    canvas.scale(scale);
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = tint.withAlpha(platform.energized ? 90 : 50)
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawLine(
      a + const Offset(0, 5),
      b + const Offset(0, 5),
      Paint()
        ..color = Colors.black.withAlpha(80)
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0xFF2C3A37)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a - const Offset(0, 1),
      b - const Offset(0, 1),
      Paint()
        ..color = tint
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a - const Offset(0, 2.5),
      b - const Offset(0, 2.5),
      Paint()
        ..color = const Color(0xFFFFFFE8)
        ..strokeWidth = 1.2,
    );
    paintPlatformDetail(
      canvas,
      a,
      b,
      platform,
      time: phase / (math.pi * 2) * 24,
      reducedMotion: reducedMotion,
    );
    // A soft sheen where the ball rests on the rail.
    final sheen = Rect.fromCenter(
      center: const Offset(0, -1.5),
      width: 30,
      height: 4,
    );
    canvas.drawOval(
      sheen,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withAlpha(150), Colors.white.withAlpha(0)],
        ).createShader(sheen),
    );
    canvas.restore();
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

  @override
  bool shouldRepaint(MenuBallStage old) =>
      old.mode != mode ||
      old.ball != ball ||
      old.platform != platform ||
      old.drift != drift ||
      old.reducedMotion != reducedMotion;
}

/// A thumb-sized bespoke control with keyboard and screen-reader support.
class PremiumPlayButton extends StatefulWidget {
  const PremiumPlayButton({
    super.key,
    required this.onPressed,
    this.height = 64,
    this.label = 'PLAY',
  });
  final VoidCallback? onPressed;
  final double height;

  /// Says what Play starts, such as "PLAY LEVEL 12" on the Classic page.
  final String label;
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
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.label,
                            style: const TextStyle(
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

/// Scores below 10,000 stay exact; larger ones shorten to 28.6K, 148.6K, 1.2M.
String formatCompactScore(int score) {
  if (score.abs() < 10000) return formatMenuScore(score);
  const units = ['K', 'M', 'B', 'T'];
  var value = score / 1000;
  var unit = 0;
  while (value.abs() >= 999.95 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  final digits = value.toStringAsFixed(1);
  return '${digits.endsWith('.0') ? digits.substring(0, digits.length - 2) : digits}${units[unit]}';
}

/// Longer score labels get a smaller font so big numbers keep their layout.
double scoreFontSize(double base, String text) =>
    base *
    switch (text.length) {
      <= 4 => 1.0,
      5 => .9,
      6 => .8,
      _ => .7,
    };

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
            formatCompactScore(score),
            key: const ValueKey('menu-best-score'),
            style: TextStyle(
              color: menuText,
              fontSize: scoreFontSize(18, formatCompactScore(score)),
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
    this.upgradeAvailable = false,
    this.hintLabel = 'Upgrade available in Shop',
    this.hintKey = 'shop-upgrade-hint',
    this.tint = const Color(0xFF91C7C5),
    this.height = 60,
  });
  final double height;
  final String label, tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool upgradeAvailable;

  /// The equipped world's accent, lightly tinting the frosted glass.
  final Color tint;

  /// What the gold dot announces to screen readers, and its test key.
  final String hintLabel, hintKey;
  @override
  Widget build(BuildContext context) {
    // Frosted glass over the world behind the menu: blurred, darkened enough
    // for the label, and tinted toward the equipped world so it belongs there.
    final glass = Color.lerp(const Color(0xFF0C1C21), tint, .16)!;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: buildButton(glass),
          ),
        ),
      ),
    );
  }

  Widget buildButton(Color glass) => FilledButton.icon(
    style: FilledButton.styleFrom(
      backgroundColor: glass.withAlpha(140),
      disabledBackgroundColor: glass.withAlpha(140),
      foregroundColor: menuText,
      disabledForegroundColor: menuText.withAlpha(150),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      side: BorderSide(
        color: Color.lerp(Colors.white, tint, .4)!.withAlpha(55),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(
        fontFamily: 'sans-serif',
        fontSize: 19,
        fontWeight: FontWeight.w600,
      ),
    ),
    onPressed: onPressed,
    icon: ShopHintIcon(
      icon,
      size: 26,
      available: upgradeAvailable,
      hintLabel: hintLabel,
      hintKey: hintKey,
    ),
    label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
  );
}

/// A quiet gold notification dot for an affordable gear improvement.
class ShopHintIcon extends StatelessWidget {
  const ShopHintIcon(
    this.icon, {
    super.key,
    required this.size,
    this.available = false,
    this.color,
    this.hintLabel = 'Upgrade available in Shop',
    this.hintKey = 'shop-upgrade-hint',
  });
  final IconData icon;
  final double size;
  final bool available;
  final Color? color;
  final String hintLabel, hintKey;

  @override
  Widget build(BuildContext context) => Semantics(
    label: available ? hintLabel : null,
    child: Badge(
      key: available ? ValueKey(hintKey) : null,
      isLabelVisible: available,
      backgroundColor: menuGold,
      smallSize: 8,
      child: Icon(icon, size: size, color: color),
    ),
  );
}

/// A full-screen menu page opened like the shop: a back button that stays
/// above [child] while it scrolls, and a right swipe that closes the page
/// like going back.
class SwipeBackPage extends StatefulWidget {
  const SwipeBackPage({super.key, required this.child});
  final Widget child;

  @override
  State<SwipeBackPage> createState() => _SwipeBackPageState();
}

class _SwipeBackPageState extends State<SwipeBackPage> {
  double swipeDistance = 0;

  void finishSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (swipeDistance < 56 && velocity < 500) return;
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) => MenuSurface(
    child: GestureDetector(
      key: const ValueKey('page-swipe-area'),
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => swipeDistance = 0,
      onHorizontalDragUpdate: (details) => swipeDistance += details.delta.dx,
      onHorizontalDragEnd: finishSwipe,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: MenuQuietButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    ),
  );
}
