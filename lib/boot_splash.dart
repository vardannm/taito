import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'menu_design.dart';

/// The intro is storyboarded in milliseconds, so every phase below is written
/// in the same units and the timeline reads top to bottom.
const _introMs = 1900;
const _reducedMs = 700;
const _exitMs = 1540;

/// Progress of one phase of the storyboard, 0 before it starts and 1 once it
/// has run out.
double _phase(
  double value,
  int startMs,
  int endMs, [
  Curve curve = Curves.linear,
]) => curve.transform(
  ((value * _introMs - startMs) / (endMs - startMs)).clamp(0.0, 1.0),
);

/// Holds the intro over the running app until it finishes. The game builds and
/// loads underneath, so the animation costs no start-up time.
class GiltIntroGate extends StatefulWidget {
  const GiltIntroGate({super.key, required this.child});
  final Widget child;
  @override
  State<GiltIntroGate> createState() => _GiltIntroGateState();
}

class _GiltIntroGateState extends State<GiltIntroGate> {
  bool playing = true;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (playing)
        Positioned.fill(
          child: GiltIntro(
            onFinished: () {
              if (mounted) setState(() => playing = false);
            },
          ),
        ),
    ],
  );
}

/// The gilt ball drops onto its beam, the beam rocks level, and the wordmark
/// lands under it. A tap skips ahead to the fade.
class GiltIntro extends StatefulWidget {
  const GiltIntro({super.key, required this.onFinished});
  final VoidCallback onFinished;
  @override
  State<GiltIntro> createState() => _GiltIntroState();
}

class _GiltIntroState extends State<GiltIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) finish();
    });
  bool reduced = false, started = false, finished = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    reduced = MediaQuery.disableAnimationsOf(context);
    controller.duration = Duration(
      milliseconds: reduced ? _reducedMs : _introMs,
    );
    controller.forward();
  }

  void finish() {
    if (finished) return;
    finished = true;
    widget.onFinished();
  }

  /// A skip still plays the fade, so the menu is never cut in abruptly.
  void skip() {
    final exit = reduced ? .72 : _exitMs / _introMs;
    if (controller.value >= exit) return;
    // Setting the value stops the controller, so run the fade out from there.
    controller.value = exit;
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final v = controller.value;
      final ring = reduced ? 1.0 : _phase(v, 100, 760, Curves.easeOutCubic);
      final land = reduced ? 1.0 : _phase(v, 160, 720, Curves.easeInCubic);
      final settle = reduced ? 1.0 : _phase(v, 720, 1450);
      // A decaying swing, forced to exactly zero so the beam ends dead level.
      final damp = math.exp(-5.2 * settle) * (1 - settle);
      final tilt = .085 * math.sin(settle * math.pi * 5) * damp;
      final word = reduced ? 1.0 : _phase(v, 800, 1280, Curves.easeOutCubic);
      final tag = reduced ? 1.0 : _phase(v, 1050, 1430, Curves.easeOut);
      final exit = reduced
          ? Curves.easeIn.transform(((v - .72) / .28).clamp(0.0, 1.0))
          : _phase(v, _exitMs, _introMs, Curves.easeIn);
      final enter = reduced
          ? Curves.easeOut.transform((v / .25).clamp(0.0, 1.0))
          : 1.0;
      final spacing = 9 + (1 - word) * 13;
      return Opacity(
        opacity: (1 - exit) * enter,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: skip,
          child: ColoredBox(
            color: menuBackground,
            child: Center(
              child: Transform.scale(
                scale: 1 + exit * .06,
                // A short viewport shrinks the mark rather than clipping it.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 132,
                        child: CustomPaint(
                          painter: _GiltMarkPainter(
                            ring: ring,
                            land: land,
                            tilt: tilt,
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Opacity(
                        opacity: word,
                        child: Transform.translate(
                          offset: Offset(0, (1 - word) * 10),
                          child: Padding(
                            // Letter spacing trails the last glyph; shifting by
                            // one step puts the wordmark back on the axis.
                            padding: EdgeInsets.only(left: spacing),
                            child: Text(
                              'GILT',
                              style: TextStyle(
                                fontFamily: 'sans-serif',
                                color: menuText,
                                fontSize: 37,
                                height: 1.15,
                                fontWeight: FontWeight.w300,
                                letterSpacing: spacing,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: tag,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 2.6),
                          child: Text(
                            'THE ART OF BALANCE',
                            style: TextStyle(
                              color: menuMuted,
                              fontSize: 9,
                              letterSpacing: 2.6,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// The mark: a gilt ball resting on a fulcrum beam inside a closing ring. Laid
/// out in a 132 unit square and scaled to whatever box it is given.
class _GiltMarkPainter extends CustomPainter {
  _GiltMarkPainter({
    required this.ring,
    required this.land,
    required this.tilt,
  });

  /// How far the ring has closed, how far the ball has fallen, and the beam
  /// angle in radians.
  final double ring, land, tilt;

  static const _pivot = Offset(66, 88);
  static const _ringCenter = Offset(66, 66);
  static const _ringRadius = 58.0;
  static const _beamHalf = 40.0;
  static const _beamHalfThick = 3.0;
  static const _ballRadius = 15.5;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / 132);
    final ball = Offset.lerp(
      const Offset(66, -26),
      _pivot + _rotate(const Offset(0, -(_beamHalfThick + _ballRadius)), tilt),
      land,
    )!;
    _paintRing(canvas);
    _paintBeam(canvas);
    _paintContact(canvas, ball);
    _paintBall(canvas, ball);
    canvas.restore();
  }

  void _paintRing(Canvas canvas) {
    canvas.drawCircle(
      _ringCenter,
      _ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = menuLine.withValues(alpha: .7),
    );
    if (ring <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: _ringCenter, radius: _ringRadius),
      -math.pi / 2,
      math.pi * 2 * ring,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = menuGold,
    );
    if (ring >= 1) return;
    final head = -math.pi / 2 + math.pi * 2 * ring;
    canvas.drawCircle(
      _ringCenter + Offset(math.cos(head), math.sin(head)) * _ringRadius,
      3.2,
      Paint()..color = menuGold,
    );
  }

  void _paintBeam(Canvas canvas) {
    // The fulcrum stands still; only the beam above it swings.
    final base = Path()
      ..moveTo(_pivot.dx, _pivot.dy)
      ..lineTo(_pivot.dx - 9.5, _pivot.dy + 14)
      ..lineTo(_pivot.dx + 9.5, _pivot.dy + 14)
      ..close();
    canvas.drawPath(
      base,
      Paint()..color = Color.lerp(menuGold, menuBackground, .45)!,
    );
    canvas.drawPath(
      base,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = menuGold,
    );
    canvas.drawLine(
      Offset(_pivot.dx - 14, _pivot.dy + 14.7),
      Offset(_pivot.dx + 14, _pivot.dy + 14.7),
      Paint()
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = menuGold,
    );
    canvas.save();
    canvas.translate(_pivot.dx, _pivot.dy);
    canvas.rotate(tilt);
    const bar = Rect.fromLTRB(
      -_beamHalf,
      -_beamHalfThick,
      _beamHalf,
      _beamHalfThick,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(3)),
      // Lit from above, the way the ball is.
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [menuText, menuMuted, Color.lerp(menuLine, menuText, .15)!],
        ).createShader(bar),
    );
    canvas.restore();
  }

  /// A shadow that tightens under the ball as it arrives.
  void _paintContact(Canvas canvas, Offset ball) {
    if (land <= 0) return;
    canvas.save();
    canvas.translate(_pivot.dx, _pivot.dy);
    canvas.rotate(tilt);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, -_beamHalfThick + .6),
        width: 30 - land * 12,
        height: 5,
      ),
      Paint()
        ..color = menuBackground.withValues(alpha: .3 + land * .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    canvas.restore();
  }

  void _paintBall(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      _ballRadius * 1.7,
      // Gold laid over near-black at low alpha only turns grey; adding light
      // keeps the halo gold.
      Paint()
        ..blendMode = BlendMode.plus
        ..shader =
            RadialGradient(
              colors: [
                menuGold.withValues(alpha: .2 * land),
                menuGold.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: center, radius: _ballRadius * 1.7),
            ),
    );
    canvas.drawCircle(
      center,
      _ballRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.4, -.5),
          radius: .95,
          colors: [
            Color.lerp(menuGold, Colors.white, .8)!,
            menuGold,
            Color.lerp(menuGold, menuBackground, .62)!,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: _ballRadius)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(-4.6, -5.4),
        width: 8.4,
        height: 5.6,
      ),
      Paint()..color = Colors.white.withValues(alpha: .55),
    );
  }

  Offset _rotate(Offset point, double angle) => Offset(
    point.dx * math.cos(angle) - point.dy * math.sin(angle),
    point.dx * math.sin(angle) + point.dy * math.cos(angle),
  );

  @override
  bool shouldRepaint(_GiltMarkPainter old) =>
      old.ring != ring || old.land != land || old.tilt != tilt;
}
