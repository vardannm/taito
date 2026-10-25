import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'menu_design.dart';

/// The intro is storyboarded in milliseconds, so every phase below is written
/// in the same units and the timeline reads top to bottom.
const _introMs = 2400;
const _reducedMs = 800;
const _expandMs = 1860;

/// Taken from the launcher icon, so the intro is that icon coming to life.
/// The icon art itself is never touched.
const _plate = Color(0xFF163D3B);
const _gold = Color(0xFFD9AE65);
const _hole = Color(0xFF0E2929);
const _board = Color(0xFFF2ECDD);
const _boardEdge = Color(0xFFE3E0D2);
const _ballLight = Color(0xFFF9FAF8);
const _ballMid = Color(0xFFC3CCC1);
const _ballDark = Color(0xFF4B6864);

/// The stage is laid out in the icon's own 1024 unit square and scaled to
/// whatever box it is given, so these are the icon's measurements.
const _plateInset = 99.5;
const _plateCorner = 156.0;
const _plateStroke = 8.0;
const _boardCenter = Offset(580, 420);
const _boardHalf = 265.0;
const _boardHalfThick = 8.25;

/// The icon's own board angle, then the angle it rolls the ball off at.
const _tiltRest = -0.2009;
const _tiltRoll = -0.46;
const _ballRadius = 51.0;

/// Where along the board the ball lands, and where it runs out of board.
const _landAt = 200.0;
const _leaveAt = -265.0;
const _holeCenter = Offset(330, 700);
const _holeRadius = 80.0;
const _ringRadius = 137.0;
const _ringStroke = 29.6;

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

/// Where the ball sits when it is resting on the board: out along the board by
/// [along], then off its face by the two radii.
Offset _ballOnBoard(double tilt, double along) {
  final dir = Offset(math.cos(tilt), math.sin(tilt));
  final up = Offset(math.sin(tilt), -math.cos(tilt));
  return _boardCenter + dir * along + up * (_boardHalfThick + _ballRadius);
}

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
      // Screen readers must not reach the menu hidden behind the intro.
      ExcludeSemantics(excluding: playing, child: widget.child),
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

/// The launcher icon, animated: the ball drops onto the icon's board, the board
/// tips, the ball rolls off into the hole, and the hole opens out over the
/// screen to hand the game over. A tap skips to the hole.
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

  /// A skip still opens the hole, so the game is never cut in abruptly.
  void skip() {
    final exit = reduced ? .6 : _expandMs / _introMs;
    if (controller.value >= exit) return;
    // Setting the value stops the controller, so run the rest from there.
    controller.value = exit;
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'ROLLRISE',
    container: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: skip,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final v = controller.value;
          if (reduced) {
            // One still of the icon, held briefly and handed over.
            final fade =
                Curves.easeOut.transform((v / .3).clamp(0.0, 1.0)) *
                (1 -
                    Curves.easeIn.transform(((v - .72) / .28).clamp(0.0, 1.0)));
            return CustomPaint(
              painter: _IntroPainter(
                plate: 1,
                board: 1,
                ring: 1,
                tilt: _tiltRest,
                ball: _ballOnBoard(_tiltRest, _landAt),
                ballIn: 1,
                grow: 1,
                fade: fade,
              ),
            );
          }
          final plate = _phase(v, 0, 320, Curves.easeOutCubic);
          final ring = _phase(v, 120, 420, Curves.easeOutCubic);
          final board = _phase(v, 180, 480, Curves.easeOutCubic);
          final fall = _phase(v, 420, 880, Curves.easeInCubic);
          // The board takes the hit, then swings itself quiet again.
          final hit = _phase(v, 880, 1180);
          final damp = math.exp(-5 * hit) * (1 - hit);
          final turn = _phase(v, 1040, 1620, Curves.easeInOutCubic);
          final roll = _phase(v, 1040, 1620, Curves.easeInQuad);
          final drop = _phase(v, 1620, 1880, Curves.easeInQuad);
          final open = _phase(v, _expandMs, 2280, Curves.easeInOutCubic);

          final tilt =
              _tiltRest +
              (_tiltRoll - _tiltRest) * turn +
              .035 * math.sin(hit * math.pi * 4) * damp;
          final resting = _ballOnBoard(
            tilt,
            _landAt + (_leaveAt - _landAt) * roll,
          );
          final ball = drop > 0
              ? Offset.lerp(
                  _ballOnBoard(_tiltRoll, _leaveAt),
                  // Far enough in to be out of sight under the rim.
                  _holeCenter + const Offset(0, 20),
                  drop,
                )!
              : Offset(resting.dx, resting.dy - (1 - fall) * 1150);

          return CustomPaint(
            painter: _IntroPainter(
              plate: plate,
              board: board,
              ring: ring,
              tilt: tilt,
              ball: ball,
              ballIn: fall,
              grow: open,
              fade: 1,
            ),
          );
        },
      ),
    ),
  );
}

class _IntroPainter extends CustomPainter {
  _IntroPainter({
    required this.plate,
    required this.board,
    required this.ring,
    required this.tilt,
    required this.ball,
    required this.ballIn,
    required this.grow,
    required this.fade,
  });

  /// How far each piece has arrived, the board angle, the ball's place on the
  /// stage, how far the hole has opened, and the overall fade.
  final double plate, board, ring, tilt, ballIn, grow, fade;
  final Offset ball;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = menuBackground);
    if (fade <= 0) return;
    // The icon sits a little above centre.
    final stage = math.min(size.width * .82, size.height * .46);
    final origin = Offset(
      (size.width - stage) / 2,
      (size.height - stage) / 2 - stage * .1,
    );
    final unit = stage / 1024;
    final holeAt = origin + _holeCenter * unit;
    // Opening all the way means reaching the furthest corner of the screen.
    final full = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((corner) => (corner - holeAt).distance).reduce(math.max);
    final open = _holeRadius * unit + (full - _holeRadius * unit) * grow;

    if (fade < 1) canvas.saveLayer(Offset.zero & size, _alpha(fade));
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(unit);
    _paintPlate(canvas);
    _paintBoard(canvas);
    _paintRing(canvas);
    _paintBall(canvas);
    canvas.restore();
    // Drawn over the stage in screen space: this is what swallows the ball and
    // then the icon, and it lands on the menu's own colour.
    canvas.drawCircle(
      holeAt,
      open,
      Paint()..color = Color.lerp(_hole, menuBackground, grow)!,
    );
    _paintRim(canvas, holeAt, open, unit);
    if (fade < 1) canvas.restore();
  }

  Paint _alpha(double value) =>
      Paint()..color = Colors.white.withValues(alpha: value);

  void _paintPlate(Canvas canvas) {
    if (plate <= 0) return;
    canvas.save();
    canvas.translate(512, 512);
    canvas.scale(.93 + .07 * plate);
    canvas.translate(-512, -512);
    final shape = RRect.fromRectAndRadius(
      const Rect.fromLTRB(
        _plateInset,
        _plateInset,
        1024 - _plateInset,
        1024 - _plateInset,
      ),
      const Radius.circular(_plateCorner),
    );
    canvas.drawRRect(shape, Paint()..color = _plate.withValues(alpha: plate));
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _plateStroke
        ..color = _gold.withValues(alpha: plate),
    );
    canvas.restore();
  }

  /// The icon's gold ring, while the hole is still the icon's hole.
  void _paintRing(Canvas canvas) {
    if (ring <= 0 || grow > 0) return;
    canvas.drawCircle(
      _holeCenter,
      _ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringStroke
        ..color = _gold.withValues(alpha: ring),
    );
  }

  /// Once the hole opens, the same ring becomes its rim: it closes the icon's
  /// gap onto the edge and rides outwards with it.
  void _paintRim(Canvas canvas, Offset at, double open, double unit) {
    if (ring <= 0 || grow <= 0) return;
    final gap = (_ringRadius - _holeRadius) * unit * (1 - grow);
    canvas.drawCircle(
      at,
      open + gap,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringStroke * unit
        ..color = _gold.withValues(alpha: ring * (1 - grow * grow)),
    );
  }

  void _paintBoard(Canvas canvas) {
    if (board <= 0) return;
    canvas.save();
    canvas.translate(_boardCenter.dx, _boardCenter.dy);
    canvas.rotate(tilt);
    final length = _boardHalf * board;
    final bar = Rect.fromLTRB(
      -length,
      -_boardHalfThick,
      length,
      _boardHalfThick,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(_boardHalfThick)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_board, _board, _boardEdge],
        ).createShader(bar),
    );
    canvas.restore();
  }

  void _paintBall(Canvas canvas) {
    if (ballIn <= 0) return;
    // A shadow on the board that tightens as the ball arrives.
    if (ballIn < 1) {
      canvas.save();
      canvas.translate(_boardCenter.dx, _boardCenter.dy);
      canvas.rotate(tilt);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_landAt, -_boardHalfThick),
          width: 150 - 60 * ballIn,
          height: 18,
        ),
        Paint()
          ..color = _plate.withValues(alpha: .22 * ballIn)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.restore();
    }
    canvas.drawCircle(
      ball,
      _ballRadius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.38, -.45),
          radius: .95,
          colors: [_ballLight, _ballMid, _ballDark],
        ).createShader(Rect.fromCircle(center: ball, radius: _ballRadius)),
    );
  }

  @override
  bool shouldRepaint(_IntroPainter old) =>
      old.plate != plate ||
      old.board != board ||
      old.ring != ring ||
      old.tilt != tilt ||
      old.ball != ball ||
      old.ballIn != ballIn ||
      old.grow != grow ||
      old.fade != fade;
}
