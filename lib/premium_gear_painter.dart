import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ball_cosmetics.dart';
import 'platforms.dart';

Paint _line(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;
const _gold = Color(0xFFFFDA9B),
    _rose = Color(0xFFF5BDAF),
    _mint = Color(0xFFA8FFF0);

Path _star(Offset center, double radius, {double angle = 0}) {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final a = angle + i * math.pi / 4;
    final p =
        center +
        Offset(math.cos(a), math.sin(a)) * radius * (i.isEven ? 1 : .24);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}

/// Body patterns stay inside the rolling sphere. Outer jewels and rings use
/// the separate effect pass, so the actual game ball remains easy to track.
void paintPremiumBallBody(
  Canvas canvas,
  Offset center,
  double radius,
  BallCosmetic ball,
  double time,
  bool reducedMotion,
) {
  final r = radius, phase = reducedMotion ? 0.0 : time * .45;
  final area = Rect.fromCircle(center: center, radius: r);
  if (ball == BallCosmetic.aether) {
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.45),
          colors: [
            Color(0xFFFFFCF3),
            Color(0xFFD4E5FF),
            Color(0xFF8D9CCA),
            Color(0xFF363D68),
          ],
          stops: [0, .3, .72, 1],
        ).createShader(area),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(0, r * (i - 1) * .27),
          width: r * 1.9,
          height: r * (.6 + i * .15),
        ),
        _line(_rose.withAlpha(195), r * .05),
      );
    }
    canvas.drawPath(
      _star(center, r * .56, angle: .3),
      Paint()..color = const Color(0xFFFFF5DA),
    );
    canvas.drawPath(_star(center, r * .56, angle: .3), _line(_rose, r * .035));
    canvas.drawCircle(
      center,
      r * .12,
      Paint()..color = const Color(0xFF8CBADF),
    );
  } else if (ball == BallCosmetic.phoenix) {
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFFF2B2),
            Color(0xFFF7AA4F),
            Color(0xFFA92D50),
            Color(0xFF431E3D),
          ],
          stops: [0, .23, .62, 1],
        ).createShader(area),
    );
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + phase * .35;
      final direction = Offset(math.cos(a), math.sin(a));
      final side = Offset(-direction.dy, direction.dx);
      final root = center + direction * r * .14;
      final tip = center + direction * r * .92;
      final feather = Path()
        ..moveTo(root.dx, root.dy)
        ..cubicTo(
          (center + side * r * .45).dx,
          (center + side * r * .45).dy,
          (tip + side * r * .18).dx,
          (tip + side * r * .18).dy,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          (center + direction * r * .58 - side * r * .19).dx,
          (center + direction * r * .58 - side * r * .19).dy,
          root.dx,
          root.dy,
        )
        ..close();
      canvas.drawPath(
        feather,
        Paint()..color = (i.isEven ? _gold : _rose).withAlpha(180),
      );
      canvas.drawLine(root, tip, _line(const Color(0xFFFFF2CA), r * .03));
    }
    canvas.drawCircle(
      center,
      r * .25,
      Paint()..color = const Color(0xFFFFF6CF),
    );
  } else if (ball == BallCosmetic.chronosphere) {
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.3, -.3),
          colors: [Color(0xFFBAFFEB), Color(0xFF368B96), Color(0xFF172B4B)],
        ).createShader(area),
    );
    final gear = Path(), ticks = Path();
    for (var i = 0; i < 48; i++) {
      final a = i * math.pi / 24;
      final p =
          center +
          Offset(math.cos(a), math.sin(a)) * r * (i % 4 < 2 ? .9 : .78);
      if (i == 0) {
        gear.moveTo(p.dx, p.dy);
      } else {
        gear.lineTo(p.dx, p.dy);
      }
    }
    gear.close();
    canvas.drawPath(gear, _line(_gold, r * .045));
    canvas.drawCircle(center, r * .62, _line(_gold.withAlpha(185), r * .03));
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final d = Offset(math.cos(a), math.sin(a));
      final p = center + d * r * .48, q = center + d * r * .57;
      ticks.moveTo(p.dx, p.dy);
      ticks.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(ticks, _line(_gold, r * .055));
    canvas.drawLine(
      center,
      center + Offset(math.sin(phase), -math.cos(phase)) * r * .45,
      _line(_mint, r * .065),
    );
    canvas.drawLine(
      center,
      center +
          Offset(math.sin(phase * .23 + 1), -math.cos(phase * .23 + 1)) *
              r *
              .29,
      _line(_gold, r * .07),
    );
    canvas.drawCircle(
      center,
      r * .105,
      Paint()..color = const Color(0xFFF7FFED),
    );
  } else if (ball == BallCosmetic.genesis) {
    const facets = [
      Color(0xFFFFBCEB),
      Color(0xFFACFFF1),
      Color(0xFFC9C2FF),
      Color(0xFFFFDFAD),
    ];
    canvas.drawCircle(center, r, Paint()..color = const Color(0xFF473459));
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 + phase * .15;
      final d = Offset(math.cos(a), math.sin(a)), normal = Offset(-d.dy, d.dx);
      final tip = center + d * r * .96;
      final petal = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          (center + normal * r * .56 + d * r * .5).dx,
          (center + normal * r * .56 + d * r * .5).dy,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          (center - normal * r * .22 + d * r * .6).dx,
          (center - normal * r * .22 + d * r * .6).dy,
          center.dx,
          center.dy,
        )
        ..close();
      canvas.drawPath(
        petal,
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.white, facets[i % 4], facets[i % 4].withAlpha(70)],
            begin: Alignment.center,
            end: Alignment(math.cos(a), math.sin(a)),
          ).createShader(area),
      );
      canvas.drawPath(petal, _line(Colors.white.withAlpha(165), r * .025));
    }
    canvas.drawPath(
      _star(center, r * .39, angle: math.pi / 4),
      Paint()..color = const Color(0xFFFFFEED),
    );
  }
}

void paintPremiumBallEffects(
  Canvas c,
  Offset center,
  double r,
  BallCosmetic ball,
  double time,
  bool reducedMotion,
) {
  final phase = reducedMotion ? 0.0 : time * .5;
  if (ball == BallCosmetic.aether || ball == BallCosmetic.genesis) {
    final colors = ball == BallCosmetic.aether
        ? [_rose, const Color(0xFFDDEEFF)]
        : [_mint, const Color(0xFFFFBEDF)];
    for (var i = 0; i < 2; i++) {
      final path = Path(), tilt = i.isEven ? .42 : -.5;
      for (var j = 0; j <= 48; j++) {
        final a = phase * (i.isEven ? 1 : -1) + j * math.pi * 1.45 / 48;
        final x = math.cos(a) * r * 1.45, y = math.sin(a) * r * (.6 + i * .1);
        final p =
            center +
            Offset(
              x * math.cos(tilt) - y * math.sin(tilt),
              x * math.sin(tilt) + y * math.cos(tilt),
            );
        if (j == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      c.drawPath(path, _line(colors[i].withAlpha(210), r * .055));
    }
    for (var i = 0; i < 3; i++) {
      final a = phase + i * math.pi * 2 / 3;
      c.drawPath(
        _star(center + Offset(math.cos(a), math.sin(a)) * r * 1.4, r * .13),
        Paint()..color = colors[i % 2],
      );
    }
  } else if (ball == BallCosmetic.phoenix) {
    final rays = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + phase * .15;
      final d = Offset(math.cos(a), math.sin(a)), side = Offset(-d.dy, d.dx);
      final p = center + d * r * 1.08,
          q = center + d * r * (1.45 + .1 * math.sin(phase + i));
      rays.moveTo(p.dx, p.dy);
      rays.quadraticBezierTo(
        (q + side * r * .1).dx,
        (q + side * r * .1).dy,
        q.dx,
        q.dy,
      );
    }
    c.drawPath(rays, _line(_gold.withAlpha(210), r * .06));
  } else if (ball == BallCosmetic.chronosphere) {
    c.drawArc(
      Rect.fromCircle(center: center, radius: r * 1.25),
      phase,
      math.pi * 1.7,
      false,
      _line(_gold.withAlpha(185), r * .04),
    );
    c.drawCircle(
      center + Offset(math.cos(phase), math.sin(phase)) * r * 1.25,
      r * .09,
      Paint()..color = _mint,
    );
  }
}

void paintPremiumPlatform(
  Canvas c,
  double span,
  PlatformStyle style,
  double time,
  bool reducedMotion,
) {
  final phase = reducedMotion ? 0.0 : time * .3;
  final tint = Color(style.color);
  c.drawLine(
    Offset.zero,
    Offset(span, 0),
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF273746), Color(0xFF526279), Color(0xFF172033)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, -4, span, 8))
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round,
  );
  c.drawLine(const Offset(0, -2.5), Offset(span, -2.5), _line(tint, 1.2));
  c.drawLine(
    const Offset(0, 2.5),
    Offset(span, 2.5),
    _line(_gold.withAlpha(175), .7),
  );
  final inlays = Path(), highlights = Path();
  for (var x = 10.0; x < span - 8; x += 22) {
    if (style == PlatformStyle.aether) {
      inlays.addPath(_star(Offset(x, 0), 3.3), Offset.zero);
      highlights.moveTo(x - 7, 0);
      highlights.quadraticBezierTo(x, -5, x + 7, 0);
    } else if (style == PlatformStyle.phoenix) {
      inlays.moveTo(x - 7, 2);
      inlays.quadraticBezierTo(x, -6, x + 8, -1);
      inlays.quadraticBezierTo(x + 2, 3, x - 7, 2);
    } else if (style == PlatformStyle.chrono) {
      inlays.addOval(Rect.fromCircle(center: Offset(x, 0), radius: 2.8));
      highlights.moveTo(x, -2);
      highlights.lineTo(x + 1.5, 1);
    } else {
      inlays.moveTo(x - 5, 0);
      inlays.lineTo(x, -3.5);
      inlays.lineTo(x + 5, 0);
      inlays.lineTo(x, 3.5);
      inlays.close();
      highlights.addOval(Rect.fromCircle(center: Offset(x, 0), radius: 1));
    }
  }
  c.drawPath(
    inlays,
    style == PlatformStyle.phoenix || style == PlatformStyle.chrono
        ? _line(_gold, 1)
        : (Paint()..color = tint.withAlpha(230)),
  );
  c.drawPath(highlights, _line(_rose, .8));
  final sparks = Path();
  for (var i = 0; i < 6; i++) {
    final x = ((phase + i / 6) % 1) * span;
    sparks.addPath(
      _star(Offset(x, -6 - 2 * math.sin(x / span * math.pi)), 1.5),
      Offset.zero,
    );
  }
  c.drawPath(sparks, Paint()..color = tint.withAlpha(200));
}
