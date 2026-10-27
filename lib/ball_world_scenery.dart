import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ball_cosmetics.dart';

// One immutable display list per ball. Scenery has no per-frame geometry,
// blur filters, offscreen layers, timers or simulation state.
final _scenes = <BallCosmetic, ui.Picture>{};

void paintWorldScenery(
  Canvas canvas,
  BallCosmetic ball,
  Color top,
  Color bottom,
  Color accent,
) {
  final picture = _scenes.putIfAbsent(ball, () {
    final recorder = ui.PictureRecorder();
    _Scenery(Canvas(recorder), top, bottom, accent).paint(ball);
    return recorder.endRecording();
  });
  canvas.drawPicture(picture);
}

class _Scenery {
  _Scenery(this.c, this.top, this.bottom, this.accent);
  final Canvas c;
  final Color top, bottom, accent;
  Color color(int hex) => Color(hex);
  void polygon(List<Offset> points, Color tint) =>
      c.drawPath(Path()..addPolygon(points, true), Paint()..color = tint);
  void line(Offset a, Offset b, Color tint, [double width = 1]) => c.drawLine(
    a,
    b,
    Paint()
      ..color = tint
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
  void wash(Rect rect, Color tint) => c.drawOval(
    rect,
    Paint()
      ..shader = RadialGradient(
        colors: [tint, tint.withAlpha(0)],
      ).createShader(rect),
  );
  void stars(Color tint, [int count = 30]) {
    final dots = Path();
    for (var i = 0; i < count; i++) {
      final p = Offset(
        12 + (i * 97 % 317).toDouble(),
        24 + (i * 137 % 470).toDouble(),
      );
      dots.addOval(Rect.fromCircle(center: p, radius: i % 7 == 0 ? 1.5 : .65));
    }
    c.drawPath(dots, Paint()..color = tint.withAlpha(125));
  }

  void ridge(double y, double height, Color tint, {int seed = 1}) {
    const profile = [.12, .78, .36, .93, .46, .58, .18, .72, .29];
    const xs = [-15.0, 24.0, 69.0, 104.0, 149.0, 202.0, 238.0, 295.0, 356.0];
    final points = <Offset>[const Offset(-10, 550)];
    for (var i = 0; i <= 8; i++) {
      points.add(
        Offset(xs[i], y - profile[(i + seed) % profile.length] * height),
      );
    }
    points.add(const Offset(350, 550));
    polygon(points, tint);
    for (var i = 2; i < points.length - 2; i++) {
      final peak = points[i];
      if (peak.dy < points[i - 1].dy && peak.dy < points[i + 1].dy) {
        polygon([
          peak,
          points[i + 1],
          Offset(peak.dx + 12, y + 15),
        ], Color.lerp(tint, top, .22)!);
      }
    }
  }

  void dune(double y, Color tint, double phase) {
    c.drawPath(
      Path()
        ..moveTo(-10, y)
        ..cubicTo(95, y - 65 + phase, 230, y + 65, 350, y - 20)
        ..lineTo(350, 550)
        ..lineTo(-10, 550)
        ..close(),
      Paint()..color = tint,
    );
  }

  void crystal(double x, double y, double h, Color tint, [double width = 32]) {
    final tip = Offset(x + width * .12, y - h);
    polygon([
      Offset(x - width, y),
      Offset(x - width * .75, y - h * .7),
      tip,
      Offset(x + width * .75, y - h * .62),
      Offset(x + width, y),
    ], Color.lerp(tint, top, .42)!);
    polygon([
      Offset(x - width, y),
      Offset(x - width * .75, y - h * .7),
      tip,
      Offset(x, y),
    ], tint.withAlpha(180));
    polygon([
      tip,
      Offset(x + width * .75, y - h * .62),
      Offset(x, y),
    ], Color.lerp(tint, Colors.white, .42)!.withAlpha(190));
    line(tip, Offset(x, y), Colors.white.withAlpha(100), .8);
  }

  void forest(double y, Color tint, {double size = 1}) {
    for (var i = 0; i < 9; i++) {
      final x = i * 46.0 - 10;
      final h = (28 + i * 13 % 39) * size;
      polygon([
        Offset(x, y - h),
        Offset(x - h * .35, y - h * .3),
        Offset(x - h * .2, y - h * .3),
        Offset(x - h * .45, y),
        Offset(x + h * .45, y),
        Offset(x + h * .2, y - h * .3),
        Offset(x + h * .35, y - h * .3),
      ], tint);
    }
  }

  void aurora(Color first, Color second) {
    final ribbon = Path()
      ..moveTo(-30, 15)
      ..cubicTo(80, 120, 220, -50, 360, 100)
      ..lineTo(360, 190)
      ..cubicTo(210, 15, 95, 205, -30, 55)
      ..close();
    c.drawPath(
      ribbon,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            first.withAlpha(0),
            first.withAlpha(110),
            second.withAlpha(0),
          ],
        ).createShader(const Rect.fromLTWH(0, 0, 340, 200)),
    );
    c.drawPath(
      Path()
        ..moveTo(-20, 42)
        ..cubicTo(110, 169, 200, -22, 355, 146),
      Paint()
        ..color = first.withAlpha(85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void reef(double x, double y, Color tint, double scale) {
    c.save();
    c.translate(x, y);
    c.scale(scale);
    final branch = Path()
      ..moveTo(0, 0)
      ..cubicTo(10, -24, -13, -65, 0, -105);
    for (var i = 0; i < 4; i++) {
      final h = -20.0 - i * 20;
      branch
        ..moveTo(0, h)
        ..quadraticBezierTo(-30, h - 6, -26, h - 29)
        ..moveTo(0, h - 8)
        ..quadraticBezierTo(30, h - 12, 28, h - 38);
    }
    c.drawPath(
      branch,
      Paint()
        ..color = tint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    c.restore();
  }

  void skyline(double base, Color tint, int seed, {bool windows = false}) {
    final lights = Path();
    for (var i = 0; i < 12; i++) {
      final x = i * 31.0 - 15, h = 35.0 + (i * 47 + seed * 31) % 80;
      c.drawRect(Rect.fromLTWH(x, base - h, 25, h + 80), Paint()..color = tint);
      if (i % 3 == 0)
        line(Offset(x + 12, base - h), Offset(x + 12, base - h - 15), tint, 2);
      if (windows) {
        line(
          Offset(x + 1, base - h),
          Offset(x + 24, base - h),
          accent.withAlpha(170),
        );
        for (var row = 0; row < 5; row++) {
          if (row * 14 > h - 10) break;
          lights.addRect(Rect.fromLTWH(x + 5, base - h + 8 + row * 14, 3, 5));
          if ((i + row).isEven)
            lights.addRect(
              Rect.fromLTWH(x + 16, base - h + 8 + row * 14, 3, 5),
            );
        }
      }
    }
    c.drawPath(lights, Paint()..color = accent.withAlpha(130));
  }

  /// A four-pointed glint: brighter than a dot, still one small fill.
  void sparkle(Offset p, double size, Color tint) {
    polygon([
      p.translate(0, -size),
      p.translate(size * .18, -size * .18),
      p.translate(size, 0),
      p.translate(size * .18, size * .18),
      p.translate(0, size),
      p.translate(-size * .18, size * .18),
      p.translate(-size, 0),
      p.translate(-size * .18, -size * .18),
    ], tint);
  }

  /// Pointed gothic window, [w] wide, from [bottom] up to its apex at [top].
  Path lancet(double x, double top, double bottom, double w) => Path()
    ..moveTo(x - w / 2, bottom)
    ..lineTo(x - w / 2, top + w * .9)
    ..quadraticBezierTo(x - w / 2, top + w * .15, x, top)
    ..quadraticBezierTo(x + w / 2, top + w * .15, x + w / 2, top + w * .9)
    ..lineTo(x + w / 2, bottom)
    ..close();

  /// Scalloped cloud bank: a row of overlapping lobes over a solid base, lit
  /// along its upper edge by [rim].
  void cloudBank(double y, Color body, Color rim, int seed, {double size = 1}) {
    final path = Path()..addRect(Rect.fromLTRB(-20, y, 360, 560));
    for (var i = 0; i < 11; i++) {
      final x = i * 36.0 - 18 + (seed * 13 % 17);
      final r = (17 + (i * 37 + seed * 11) % 19) * size;
      path.addOval(
        Rect.fromCircle(
          center: Offset(x, y - (i * 53 + seed * 7) % 13 * size),
          radius: r,
        ),
      );
    }
    c.drawPath(path.shift(const Offset(0, -2.2)), Paint()..color = rim);
    c.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(body, rim.withAlpha(255), .18)!, body],
        ).createShader(Rect.fromLTRB(0, y - 40 * size, 340, y + 50)),
    );
  }

  /// A gothic cathedral silhouette standing on [base], [s] times life size.
  void cathedral(Offset base, double s, Color lit, Color body, Color shade) {
    c.save();
    c.translate(base.dx, base.dy);
    c.scale(s);
    final hull = Path()
      // Nave and gable.
      ..moveTo(-44, 0)
      ..lineTo(-44, -64)
      ..lineTo(0, -96)
      ..lineTo(44, -64)
      ..lineTo(44, 0)
      ..close()
      // Crossing tower and its needle spire.
      ..addPolygon(const [
        Offset(-10, -60),
        Offset(-10, -122),
        Offset(-4, -128),
        Offset(0, -198),
        Offset(4, -128),
        Offset(10, -122),
        Offset(10, -60),
      ], true);
    for (final side in [-1.0, 1.0]) {
      // West towers with needle spires and corner pinnacles.
      final x = side * 52;
      hull
        ..addPolygon([
          Offset(x - 12, 0),
          Offset(x - 12, -118),
          Offset(x - 9, -124),
          Offset(x, -160),
          Offset(x + 9, -124),
          Offset(x + 12, -118),
          Offset(x + 12, 0),
        ], true)
        ..addPolygon([
          Offset(x - 15, -112),
          Offset(x - 13, -134),
          Offset(x - 11, -112),
        ], true)
        ..addPolygon([
          Offset(x + 11, -112),
          Offset(x + 13, -134),
          Offset(x + 15, -112),
        ], true);
      // Flying buttress piers.
      hull.addPolygon([
        Offset(side * 70, 0),
        Offset(side * 70, -46),
        Offset(side * 72, -60),
        Offset(side * 74, -46),
        Offset(side * 74, 0),
      ], true);
      hull.addPath(
        Path()
          ..moveTo(side * 72, -40)
          ..quadraticBezierTo(side * 62, -62, side * 44, -58)
          ..lineTo(side * 44, -54)
          ..quadraticBezierTo(side * 62, -56, side * 72, -34)
          ..close(),
        Offset.zero,
      );
    }
    c.drawPath(
      hull,
      Paint()
        ..shader = LinearGradient(
          colors: [lit, body, shade],
          stops: const [0, .45, 1],
        ).createShader(const Rect.fromLTRB(-76, -200, 76, 0)),
    );
    c.drawPath(
      hull,
      Paint()
        ..color = accent.withAlpha(70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7 / s,
    );
    // Warm light behind the glass.
    final glow = accent.withAlpha(185);
    final windows = Path()
      ..addPath(lancet(-22, -50, -14, 7), Offset.zero)
      ..addPath(lancet(22, -50, -14, 7), Offset.zero)
      ..addPath(lancet(0, -44, -6, 9), Offset.zero)
      ..addPath(lancet(-52, -100, -70, 6), Offset.zero)
      ..addPath(lancet(52, -100, -70, 6), Offset.zero)
      ..addPath(lancet(-52, -52, -28, 6), Offset.zero)
      ..addPath(lancet(52, -52, -28, 6), Offset.zero)
      ..addPath(lancet(0, -112, -92, 5), Offset.zero);
    c.drawPath(windows, Paint()..color = glow);
    const rose = Offset(0, -68);
    c.drawCircle(
      rose,
      14,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withAlpha(150), accent.withAlpha(0)],
        ).createShader(Rect.fromCircle(center: rose, radius: 14)),
    );
    c.drawCircle(rose, 7.5, Paint()..color = glow);
    final tracery = Path()..addOval(Rect.fromCircle(center: rose, radius: 7.5));
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      tracery
        ..moveTo(rose.dx, rose.dy)
        ..lineTo(rose.dx + math.cos(a) * 7.5, rose.dy + math.sin(a) * 7.5);
    }
    c.drawPath(
      tracery,
      Paint()
        ..color = shade.withAlpha(200)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9,
    );
    c.restore();
  }

  void aetherCathedral() {
    const sun = Offset(170, 128);
    // A lavender dawn above the cloud sea, warming to rose at the horizon.
    const dawn = Rect.fromLTWH(0, 230, 340, 310);
    c.drawRect(
      dawn,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x00C9B8F0),
            Color(0x50C9B8F0),
            Color(0x70F4CDBF),
            Color(0x30F4CDBF),
          ],
          stops: [0, .45, .75, 1],
        ).createShader(dawn),
    );
    wash(
      Rect.fromCircle(center: sun, radius: 230),
      color(0xFFDCD6FF).withAlpha(55),
    );
    stars(color(0xFFF8E6D2), 44);
    const glints = [
      Offset(38, 62),
      Offset(292, 44),
      Offset(64, 248),
      Offset(306, 210),
      Offset(250, 318),
      Offset(22, 352),
      Offset(118, 30),
    ];
    for (var i = 0; i < glints.length; i++) {
      sparkle(glints[i], i.isEven ? 4.5 : 3, color(0xFFFFF1E2).withAlpha(170));
    }
    // A faint constellation drawn across the upper vault.
    const figure = [
      Offset(30, 118),
      Offset(62, 92),
      Offset(98, 104),
      Offset(232, 66),
      Offset(266, 96),
      Offset(310, 84),
    ];
    c.drawPath(
      Path()
        ..addPolygon(figure.sublist(0, 3), false)
        ..addPolygon(figure.sublist(3), false),
      Paint()
        ..color = color(0xFFF8E6D2).withAlpha(55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    for (final p in figure) {
      c.drawCircle(p, 1.4, Paint()..color = color(0xFFFFF1E2).withAlpha(190));
    }
    // Long celestial rays from the aether sun.
    final rays = Path();
    for (var i = 0; i < 18; i++) {
      final a = i * math.pi / 9 + .09;
      final spread = i.isEven ? .035 : .018;
      rays
        ..moveTo(sun.dx, sun.dy)
        ..lineTo(
          sun.dx + math.cos(a - spread) * 420,
          sun.dy + math.sin(a - spread) * 420,
        )
        ..lineTo(
          sun.dx + math.cos(a + spread) * 420,
          sun.dy + math.sin(a + spread) * 420,
        )
        ..close();
    }
    c.drawPath(
      rays,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withAlpha(34),
            color(0xFFE6DCFF).withAlpha(16),
            Colors.white.withAlpha(0),
          ],
          stops: const [0, .45, 1],
        ).createShader(Rect.fromCircle(center: sun, radius: 420)),
    );
    // Rose-gold orbital rings: their back halves pass behind the sun.
    const rings = [
      (330.0, 96.0, 1.5, 120),
      (250.0, 70.0, .8, 95),
      (410.0, 128.0, 3.0, 45),
    ];
    void orbit(bool front) {
      c.save();
      c.translate(sun.dx, sun.dy);
      c.rotate(-.3);
      for (final (w, h, stroke, alpha) in rings) {
        c.drawArc(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          front ? 0 : math.pi,
          math.pi,
          false,
          Paint()
            ..color = (stroke < 1 ? color(0xFFD5ECFF) : accent).withAlpha(
              front ? alpha : alpha ~/ 2,
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke,
        );
      }
      for (final (i, a) in [.7, 2.2, 3.6, 5.2].indexed) {
        if ((math.sin(a) > 0) != front) continue;
        final (w, h, _, _) = rings[i % 2];
        final p = Offset(math.cos(a) * w / 2, math.sin(a) * h / 2);
        c.drawCircle(p, 6, Paint()..color = accent.withAlpha(40));
        c.drawCircle(p, 2.6, Paint()..color = color(0xFFFFE8D6));
      }
      c.restore();
    }

    orbit(false);
    c.drawCircle(
      sun,
      58,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withAlpha(95),
            color(0xFFE9E1FF).withAlpha(45),
            color(0xFFC9B8F0).withAlpha(0),
          ],
          stops: const [0, .4, 1],
        ).createShader(Rect.fromCircle(center: sun, radius: 58)),
    );
    c.drawCircle(
      sun,
      17,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.4),
          colors: [color(0xFFF6F2FF), color(0xFFD9D4F2), color(0xFFA9B9DA)],
        ).createShader(Rect.fromCircle(center: sun, radius: 17)),
    );
    orbit(true);
    // Distant sister spires, then the cathedral itself above the clouds.
    final haze = color(0xFF8D93BC);
    final hazeLit = Color.lerp(haze, Colors.white, .25)!;
    final hazeShade = Color.lerp(haze, top, .35)!;
    cathedral(const Offset(44, 478), .5, hazeLit, haze, hazeShade);
    cathedral(const Offset(300, 484), .45, hazeLit, haze, hazeShade);
    cloudBank(468, color(0xFF7F84B0), color(0xFFF2D6D0).withAlpha(150), 2);
    cathedral(
      const Offset(170, 500),
      .78,
      color(0xFFB4BED6),
      color(0xFF66739A),
      color(0xFF3B4565),
    );
    cloudBank(500, color(0xFF5E6890), color(0xFFF4CDBF).withAlpha(170), 5);
    cloudBank(
      528,
      color(0xFF39445F),
      color(0xFFC9B8F0).withAlpha(150),
      8,
      size: 1.2,
    );
  }

  /// Gear outline with [teeth] square-shouldered teeth.
  Path gear(Offset center, double r, int teeth) {
    final points = <Offset>[];
    final step = math.pi * 2 / teeth;
    for (var i = 0; i < teeth; i++) {
      for (final (t, radius) in [
        (0.0, r * .86),
        (.18, r),
        (.5, r),
        (.68, r * .86),
      ]) {
        final angle = (i + t) * step;
        points.add(center + Offset(math.cos(angle), math.sin(angle)) * radius);
      }
    }
    return Path()..addPolygon(points, true);
  }

  void clockGear(Offset center, double r, int teeth, double turn) {
    final outline = gear(center, r, teeth);
    c.drawPath(outline, Paint()..color = accent.withAlpha(26));
    c.drawPath(
      outline,
      Paint()
        ..color = accent.withAlpha(80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9,
    );
    final detail = Path()
      ..addOval(Rect.fromCircle(center: center, radius: r * .7))
      ..addOval(Rect.fromCircle(center: center, radius: r * .2));
    for (var i = 0; i < 5; i++) {
      final a = turn + i * math.pi * 2 / 5;
      final d = Offset(math.cos(a), math.sin(a));
      detail
        ..moveTo(center.dx + d.dx * r * .2, center.dy + d.dy * r * .2)
        ..lineTo(center.dx + d.dx * r * .7, center.dy + d.dy * r * .7);
    }
    c.drawPath(
      detail,
      Paint()
        ..color = accent.withAlpha(70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * .05),
    );
    c.drawCircle(center, r * .08, Paint()..color = accent.withAlpha(150));
  }

  /// A faceted hexagonal crystal tower with gilded bands and lit windows.
  /// [fade] sinks distant towers into the sky colour.
  void crystalTower(
    double x,
    double base,
    double w,
    double h,
    double fade, {
    bool clock = false,
  }) {
    Color tone(int hex) => Color.lerp(color(hex), top, fade)!;
    final roof = base - h, apex = roof - w * 1.7, inner = w * .38;
    final shoulder = roof + w * .12;
    final faces = [
      (
        [
          Offset(x - w, 560),
          Offset(x - w, roof),
          Offset(x - inner, shoulder),
          Offset(x - inner, 560),
        ],
        tone(0xFF2C7378),
      ),
      (
        [
          Offset(x - inner, 560),
          Offset(x - inner, shoulder),
          Offset(x + inner, shoulder),
          Offset(x + inner, 560),
        ],
        tone(0xFF4FA6A2),
      ),
      (
        [
          Offset(x + inner, 560),
          Offset(x + inner, shoulder),
          Offset(x + w, roof),
          Offset(x + w, 560),
        ],
        tone(0xFF19494F),
      ),
      // The crystal cap: lit, front and shaded facets meeting at the apex.
      (
        [Offset(x - w, roof), Offset(x, apex), Offset(x - inner, shoulder)],
        tone(0xFF67C2B9),
      ),
      (
        [
          Offset(x - inner, shoulder),
          Offset(x, apex),
          Offset(x + inner, shoulder),
        ],
        tone(0xFF9AE6D9),
      ),
      (
        [Offset(x + inner, shoulder), Offset(x, apex), Offset(x + w, roof)],
        tone(0xFF2E7D7E),
      ),
    ];
    for (final (points, tint) in faces) {
      polygon(points, tint);
    }
    final gilt = Color.lerp(accent, top, fade)!.withAlpha(200);
    final bands = Path();
    for (final y in [shoulder, roof + h * .38, roof + h * .72]) {
      bands
        ..moveTo(x - w, y - w * .12)
        ..lineTo(x - inner, y)
        ..lineTo(x + inner, y)
        ..lineTo(x + w, y - w * .12);
    }
    bands
      ..moveTo(x, apex)
      ..lineTo(x, shoulder);
    c.drawPath(
      bands,
      Paint()
        ..color = gilt
        ..style = PaintingStyle.stroke
        ..strokeWidth = fade > .3 ? .6 : 1,
    );
    line(
      Offset(x - inner, shoulder),
      Offset(x - inner, 560),
      Colors.white.withAlpha(fade > .3 ? 25 : 60),
      .7,
    );
    final windows = Path();
    for (var row = 0; row < 6; row++) {
      final y = roof + h * .14 + row * h * .1;
      if (y > base - 6 || (row + x.toInt()) % 3 == 0) continue;
      windows.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: w * .22, height: 6),
          const Radius.circular(2),
        ),
      );
    }
    c.drawPath(
      windows,
      Paint()..color = Color.lerp(accent, top, fade)!.withAlpha(180),
    );
    if (clock) {
      final face = Offset(x, roof + h * .2);
      c.drawCircle(face, inner * .85, Paint()..color = tone(0xFF123A44));
      c.drawCircle(
        face,
        inner * .85,
        Paint()
          ..color = gilt
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      line(face, face + Offset(0, -inner * .6), gilt, 1);
      line(face, face + Offset(inner * .45, inner * .2), gilt, 1);
    }
  }

  void chronoCitadel() {
    const o = Offset(170, 150);
    final gold = accent;
    wash(
      Rect.fromCircle(center: o, radius: 250),
      color(0xFF7CE6D6).withAlpha(42),
    );
    stars(color(0xFFEADAA6), 26);
    // Gears turn behind the dial, half hidden past the board edges.
    clockGear(const Offset(-8, 318), 76, 20, .2);
    clockGear(const Offset(336, 254), 54, 15, .5);
    clockGear(const Offset(292, 330), 31, 9, 0);
    clockGear(const Offset(58, 40), 40, 12, .9);
    // The astronomical dial: sapphire glass, bezel, ticks and a zodiac band.
    c.drawCircle(
      o,
      130,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color(0xFF8AF3E6).withAlpha(55),
            color(0xFF1F7C80).withAlpha(30),
            color(0xFF113D49).withAlpha(0),
          ],
          stops: const [0, .72, 1],
        ).createShader(Rect.fromCircle(center: o, radius: 130)),
    );
    final rings = Path();
    for (final r in [122.0, 98.0, 84.0, 40.0]) {
      rings.addOval(Rect.fromCircle(center: o, radius: r));
    }
    c.drawPath(
      rings,
      Paint()
        ..color = gold.withAlpha(75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9,
    );
    c.drawCircle(
      o,
      128,
      Paint()
        ..color = gold.withAlpha(95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );
    final ticks = Path(), markers = Path();
    for (var i = 0; i < 60; i++) {
      final a = i * math.pi / 30 - math.pi / 2;
      final d = Offset(math.cos(a), math.sin(a));
      final p = o + d * 122;
      final q = o + d * (i % 5 == 0 ? 114 : 118);
      ticks
        ..moveTo(p.dx, p.dy)
        ..lineTo(q.dx, q.dy);
      if (i % 5 == 0) {
        final n = Offset(-d.dy, d.dx) * (i % 15 == 0 ? 4.2 : 2.8);
        markers.addPolygon([
          o + d * 112,
          o + d * 106 + n,
          o + d * 99,
          o + d * 106 - n,
        ], true);
      }
    }
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 + math.pi / 12;
      final d = Offset(math.cos(a), math.sin(a));
      final p = o + d * 84, q = o + d * 98;
      ticks
        ..moveTo(p.dx, p.dy)
        ..lineTo(q.dx, q.dy);
    }
    c.drawPath(
      ticks,
      Paint()
        ..color = gold.withAlpha(105)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    c.drawPath(markers, Paint()..color = gold.withAlpha(150));
    final signs = Path();
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      signs.addOval(
        Rect.fromCircle(
          center: o + Offset(math.cos(a), math.sin(a)) * 91,
          radius: i % 3 == 0 ? 2.4 : 1.5,
        ),
      );
    }
    c.drawPath(signs, Paint()..color = color(0xFF9AF0E2).withAlpha(150));
    // Guilloché rosette, engraved like a watch dial.
    final rosette = Path();
    for (var k = 0; k < 6; k++) {
      for (var i = 0; i <= 180; i++) {
        final a = i * math.pi / 90;
        final r = 60 + 16 * math.sin(a * 9 + k * math.pi / 9);
        final p = o + Offset(math.cos(a), math.sin(a)) * r;
        if (i == 0) {
          rosette.moveTo(p.dx, p.dy);
        } else {
          rosette.lineTo(p.dx, p.dy);
        }
      }
    }
    c.drawPath(
      rosette,
      Paint()
        ..color = gold.withAlpha(34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6,
    );
    // Hands at ten past ten, with spade tips and a counterweighted seconds.
    void hand(double turns, double length, double width) {
      final a = turns * math.pi * 2 - math.pi / 2;
      final d = Offset(math.cos(a), math.sin(a)), n = Offset(-d.dy, d.dx);
      polygon([
        o - d * 12,
        o + n * width / 2,
        o + d * length * .72 + n * width * .3,
        o + d * length * .8 + n * width,
        o + d * length,
        o + d * length * .8 - n * width,
        o + d * length * .72 - n * width * .3,
        o - n * width / 2,
      ], gold.withAlpha(150));
    }

    hand((10 + 9 / 60) / 12, 58, 5.5);
    hand(9 / 60, 90, 4);
    const second = 38 / 60 * math.pi * 2 - math.pi / 2;
    final sd = Offset(math.cos(second), math.sin(second));
    final teal = color(0xFF9AF0E2).withAlpha(160);
    line(o - sd * 22, o + sd * 108, teal, .9);
    c.drawCircle(o - sd * 18, 3, Paint()..color = teal);
    c.drawCircle(o, 6, Paint()..color = gold.withAlpha(200));
    c.drawCircle(o, 2.4, Paint()..color = color(0xFF4FD6C8));
    // A sapphire moon riding the bezel.
    final moon = o + Offset(math.cos(2.45), math.sin(2.45)) * 128;
    c.drawCircle(moon, 9, Paint()..color = color(0xFF4FD6C8).withAlpha(45));
    c.drawCircle(
      moon,
      4.5,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.4, -.4),
          colors: [color(0xFFD8FFF8), color(0xFF3FBFB4), color(0xFF145A63)],
        ).createShader(Rect.fromCircle(center: moon, radius: 4.5)),
    );
    // Drifting gold chronons.
    for (var i = 0; i < 9; i++) {
      final p = Offset(
        18 + (i * 113 % 304).toDouble(),
        268 + (i * 71 % 150).toDouble(),
      );
      sparkle(p, i % 3 == 0 ? 3.5 : 2.2, gold.withAlpha(140));
    }
    // The citadel: pale far spires, then the gilded crystal towers.
    for (final (x, h, w) in [
      (22.0, 112.0, 13.0),
      (98.0, 92.0, 11.0),
      (244.0, 104.0, 12.0),
      (318.0, 130.0, 14.0),
    ]) {
      crystalTower(x, 512, w, h * .8, .6);
    }
    for (final (x, h, w, clock) in [
      (54.0, 84.0, 18.0, false),
      (126.0, 118.0, 16.0, false),
      (170.0, 168.0, 22.0, true),
      (216.0, 108.0, 16.0, false),
      (290.0, 92.0, 19.0, false),
    ]) {
      crystalTower(x, 540, w, h * .78, .3, clock: clock);
    }
    ridge(560, 34, color(0xFF0E3240), seed: 3);
  }

  void paint(BallCosmetic ball) {
    switch (ball) {
      case BallCosmetic.steel:
        // Soft light at the edges leaves a quiet, high-contrast playfield.
        wash(const Rect.fromLTWH(-130, -120, 430, 400), accent.withAlpha(34));
        wash(
          const Rect.fromLTWH(185, 290, 300, 380),
          color(0xFF68A7B4).withAlpha(28),
        );
        for (final x in [6.0, 334.0]) {
          c.drawRect(
            Rect.fromLTWH(x - 2, 0, 4, 540),
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accent.withAlpha(0),
                  accent.withAlpha(85),
                  accent.withAlpha(0),
                ],
              ).createShader(Rect.fromLTWH(x - 2, 0, 4, 540)),
          );
        }
        for (var i = 0; i < 2; i++) {
          final y = 465.0 + i * 32;
          c.drawPath(
            Path()
              ..moveTo(-20, y)
              ..cubicTo(85, y - 26, 245, y + 26, 360, y - 12),
            Paint()
              ..color = accent.withAlpha(18)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .8,
          );
        }
      case BallCosmetic.coral:
        for (var i = 0; i < 3; i++)
          polygon([
            Offset(55 + i * 75.0, 0),
            Offset(105 + i * 75.0, 0),
            Offset(210 + i * 80.0, 350),
            Offset(185 + i * 80.0, 350),
          ], Colors.white.withAlpha(20));
        dune(448, color(0xFF398C94).withAlpha(105), 30);
        reef(20, 505, color(0xFF287D84), 1.15);
        reef(323, 480, color(0xFF327D87), .8);
        dune(505, color(0xFF205E72), -10);
        reef(12, 551, color(0xFFF69A88), 1.0);
        reef(325, 563, color(0xFFD87595), 1.3);
        reef(53, 560, color(0xFFF1BE8F), .55);
        for (var i = 0; i < 8; i++) {
          final p = Offset(i.isEven ? 34 : 310, 95 + i * 40.0);
          c.drawCircle(
            p,
            2 + i % 3.0,
            Paint()
              ..color = Colors.white.withAlpha(85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .8,
          );
        }
      case BallCosmetic.circuit:
        for (var i = 0; i < 9; i++) {
          final y = i * 65.0;
          for (final right in [false, true]) {
            c.save();
            if (right) {
              c.translate(340, 0);
              c.scale(-1, 1);
            }
            polygon([
              Offset(-10, y),
              Offset(38, y - 18),
              Offset(75, y + 4),
              Offset(75, y + 38),
              Offset(32, y + 57),
              Offset(-10, y + 32),
            ], color(0xFF24635B).withAlpha(140));
            c.drawPath(
              Path()
                ..moveTo(0, y + 20)
                ..lineTo(25, y + 20)
                ..lineTo(44, y + 36)
                ..lineTo(66, y + 36),
              Paint()
                ..color = accent.withAlpha(120)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4,
            );
            c.drawRect(
              Rect.fromLTWH(60, y + 33, 5, 5),
              Paint()..color = accent.withAlpha(170),
            );
            c.restore();
          }
        }
        wash(const Rect.fromLTWH(-120, -100, 470, 300), accent.withAlpha(24));
      case BallCosmetic.neon:
        wash(
          const Rect.fromLTWH(50, 310, 320, 200),
          color(0xFFEC62AD).withAlpha(75),
        );
        skyline(457, color(0xFF424773), 2);
        skyline(516, color(0xFF152844), 1, windows: true);
        for (var i = -3; i <= 3; i++)
          line(
            const Offset(170, 510),
            Offset(170 + i * 110.0, 560),
            accent.withAlpha(50),
          );
        for (final y in [523.0, 540.0, 558.0])
          line(Offset(0, y), Offset(340, y), accent.withAlpha(70));
        stars(color(0xFF9AABEC), 15);
      case BallCosmetic.obsidian:
        polygon([
          const Offset(0, 0),
          const Offset(340, 0),
          const Offset(340, 36),
          const Offset(305, 15),
          const Offset(283, 55),
          const Offset(236, 9),
          const Offset(197, 26),
          const Offset(167, 4),
          const Offset(115, 41),
          const Offset(78, 13),
          const Offset(40, 67),
          const Offset(0, 30),
        ], color(0xFF342541));
        wash(const Rect.fromLTWH(-130, 210, 220, 350), accent.withAlpha(40));
        for (var i = 0; i < 6; i++)
          crystal(
            i.isEven ? 5 : 337,
            190 + i * 70.0,
            80 + i % 3 * 24.0,
            i.isEven ? color(0xFF997BDC) : color(0xFF565FAC),
          );
        ridge(555, 48, color(0xFF211C3D));
      case BallCosmetic.prism:
        for (var i = 0; i < 5; i++) {
          final y = i * 135.0 - 30;
          polygon([
            Offset(0, y),
            Offset(65, y + 35),
            Offset(28, y + 120),
            Offset(0, y + 130),
          ], color(0xFFC78096).withAlpha(125));
          polygon([
            Offset(340, y + 35),
            Offset(260, y + 75),
            Offset(307, y + 160),
            Offset(340, y + 165),
          ], color(0xFF659BA9).withAlpha(125));
          line(Offset(0, y), Offset(65, y + 35), color(0xFFEACF97), 2);
          line(Offset(340, y + 35), Offset(260, y + 75), color(0xFFEACF97), 2);
        }
        crystal(8, 554, 110, color(0xFFD6AB68), 46);
        crystal(325, 550, 80, color(0xFFCA839A), 50);
      case BallCosmetic.reactor:
        for (final x in [-18.0, 312.0]) {
          c.drawRect(
            Rect.fromLTWH(x, 0, 46, 540),
            Paint()..color = color(0xFF223B53),
          );
          c.drawRect(
            Rect.fromLTWH(x + 17, 0, 5, 540),
            Paint()..color = accent.withAlpha(140),
          );
          for (var i = 0; i < 8; i++)
            polygon([
              Offset(x, i * 78.0),
              Offset(x + 46, i * 78.0 + 24),
              Offset(x + 46, i * 78.0 + 40),
              Offset(x, i * 78.0 + 16),
            ], color(0xFF3E5368));
        }
        polygon([
          const Offset(24, 0),
          const Offset(110, 50),
          const Offset(230, 50),
          const Offset(316, 0),
        ], color(0xFF2B455C));
        line(
          const Offset(110, 50),
          const Offset(230, 50),
          accent.withAlpha(160),
          2,
        );
        wash(const Rect.fromLTWH(-100, -160, 540, 320), accent.withAlpha(45));
      case BallCosmetic.aurora:
        stars(color(0xFFB4E4E7), 30);
        aurora(color(0xFF64F6C7), color(0xFF6D85E9));
        ridge(470, 80, color(0xFF456B86));
        ridge(499, 90, color(0xFF73919F), seed: 3);
        ridge(535, 70, color(0xFF244C66), seed: 4);
        forest(553, color(0xFF112F42));
      case BallCosmetic.nebula:
        wash(
          const Rect.fromLTWH(-200, -50, 420, 370),
          color(0xFF985DA8).withAlpha(100),
        );
        wash(
          const Rect.fromLTWH(220, 40, 300, 490),
          color(0xFF506FE5).withAlpha(85),
        );
        aurora(color(0xFFDA80BA), color(0xFF7165CA));
        stars(color(0xFFFFD4E6), 52);
        ridge(553, 65, color(0xFF262341), seed: 5);
      case BallCosmetic.nova:
        wash(
          const Rect.fromLTWH(-100, -130, 480, 320),
          color(0xFFFFB460).withAlpha(110),
        );
        for (var i = 0; i < 3; i++)
          dune(
            410 + i * 47.0,
            [color(0xFF99564A), color(0xFF783C40), color(0xFF4D2636)][i],
            i * 22.0,
          );
        for (var i = 0; i < 3; i++)
          c.drawPath(
            Path()
              ..moveTo(0, 475 + i * 28.0)
              ..cubicTo(110, 440 + i * 28.0, 220, 545, 350, 462 + i * 30.0),
            Paint()
              ..color = accent.withAlpha(90 - i * 20)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
      case BallCosmetic.eclipse:
        stars(color(0xFFF7CEDD), 24);
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(const Rect.fromLTWH(251, 40, 39, 39)),
          Path()..addOval(const Rect.fromLTWH(260, 34, 36, 36)),
        );
        c.drawPath(moon, Paint()..color = color(0xFFE6C1BD));
        dune(438, color(0xFF645574), 15);
        dune(489, color(0xFF8A6379), -10);
        dune(536, color(0xFF392F50), 30);
      case BallCosmetic.pearl:
        for (var i = 0; i < 4; i++)
          dune(
            425 + i * 36.0,
            [
              color(0xFFA4CDCD),
              color(0xFF92B9C8),
              color(0xFFC7AFC5),
              color(0xFFEED9C3),
            ][i],
            i * 17.0,
          );
        for (final x in [20.0, 320.0]) {
          final shell = Path()
            ..moveTo(x, 535)
            ..quadraticBezierTo(x - 60, 480, x, 461)
            ..quadraticBezierTo(x + 60, 480, x, 535)
            ..close();
          c.drawPath(shell, Paint()..color = color(0xFFF8E4D8));
          for (var i = -2; i <= 2; i++)
            line(
              Offset(x, 532),
              Offset(x + i * 12.0, 478 + i.abs() * 5),
              color(0xFFD0A5AC),
              1.2,
            );
        }
      case BallCosmetic.malachite:
        dune(390, color(0xFF438878), 40);
        dune(465, color(0xFF2A6A62), -10);
        for (final x in [-10.0, 345.0]) {
          for (var i = 0; i < 5; i++) {
            final y = 45 + i * 115.0;
            c.drawPath(
              Path()
                ..moveTo(x, y + 125)
                ..cubicTo(x - 65, y + 85, x - 65, y + 38, x - 34, y)
                ..cubicTo(x + 5, y + 48, x + 9, y + 87, x, y + 125)
                ..close(),
              Paint()..color = color(0xFF245849),
            );
            c.drawPath(
              Path()
                ..moveTo(x, y + 125)
                ..cubicTo(x + 10, y + 64, x + 27, y + 24, x + 59, y + 8)
                ..cubicTo(x + 73, y + 53, x + 50, y + 108, x, y + 125)
                ..close(),
              Paint()..color = color(0xFF35836A),
            );
            line(
              Offset(x, y + 125),
              Offset(x + 32, y + 18),
              color(0xFF84BF86).withAlpha(130),
            );
          }
        }
        dune(542, color(0xFF164B4A), 0);
      case BallCosmetic.titanium:
        for (final x in [-8.0, 309.0]) {
          c.drawRect(
            Rect.fromLTWH(x, 0, 39, 540),
            Paint()..color = color(0xFF7893A5),
          );
          for (var i = 0; i < 5; i++) {
            final y = i * 120.0;
            polygon([
              Offset(x, y),
              Offset(x + 39, y + 70),
              Offset(x + 39, y + 100),
              Offset(x, y + 30),
            ], color(0xFF38576F));
            line(
              Offset(x + 5, y + 6),
              Offset(x + 34, y + 65),
              color(0xFFC4D9DD),
              2,
            );
          }
        }
        ridge(542, 60, color(0xFF587689), seed: 2);
      case BallCosmetic.opal:
        dune(465, color(0xFFC5BFD9), 25);
        dune(510, color(0xFF96C2C9), 0);
        for (var i = 0; i < 7; i++)
          crystal(
            i.isEven ? 12 + i * 5.0 : 327 - i * 3.0,
            450 + i * 25.0,
            90 + i % 3 * 38.0,
            [color(0xFF73BEBB), color(0xFFAB95CF), color(0xFFCCAE8F)][i % 3],
            23 + i % 2 * 10.0,
          );
      case BallCosmetic.plasma:
        aurora(color(0xFFAF69FF), color(0xFFEE8DBB));
        for (final x in [23.0, 320.0]) {
          final bolt = Path()
            ..moveTo(x, 0)
            ..lineTo(x - 20, 90)
            ..lineTo(x + 15, 160)
            ..lineTo(x - 12, 210)
            ..lineTo(x + 5, 240);
          c.drawPath(
            bolt,
            Paint()
              ..color = accent.withAlpha(35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 10,
          );
          c.drawPath(
            bolt,
            Paint()
              ..color = accent.withAlpha(180)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
        }
        ridge(465, 80, color(0xFF534576), seed: 3);
        ridge(530, 100, color(0xFF29243F), seed: 5);
      case BallCosmetic.comet:
        stars(color(0xFFD6F4F4), 32);
        polygon([
          const Offset(232, 92),
          const Offset(312, -10),
          const Offset(327, -10),
        ], accent.withAlpha(65));
        line(
          const Offset(232, 92),
          const Offset(322, -10),
          accent.withAlpha(170),
          1.2,
        );
        ridge(467, 75, color(0xFF4E8B9F));
        ridge(525, 115, color(0xFF98C7D2), seed: 2);
        ridge(562, 100, color(0xFF34637D), seed: 6);
      case BallCosmetic.quasar:
        wash(
          const Rect.fromLTWH(-200, -130, 530, 360),
          color(0xFFE5A28D).withAlpha(70),
        );
        stars(color(0xFFF1C5A3), 35);
        for (var i = 0; i < 3; i++) {
          c.drawPath(
            Path()
              ..moveTo(-25, 160 + i * 18.0)
              ..cubicTo(100, 25 + i * 15.0, 240, 35 + i * 15.0, 365, -10),
            Paint()
              ..color = accent.withAlpha(70 - i * 15)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
        dune(467, color(0xFF71526A), 12);
        dune(525, color(0xFF3B314B), -20);
      case BallCosmetic.singularity:
        // No dark disk: celestial dust and gold strata cannot read as a hole.
        stars(color(0xFFECD29B), 42);
        for (var i = 0; i < 3; i++) {
          final p = Path()
            ..moveTo(-20, 85 + i * 23.0)
            ..cubicTo(80, 15, 290, 190 + i * 28.0, 360, 80 + i * 16.0);
          c.drawPath(
            p,
            Paint()
              ..color = accent.withAlpha(40 - i * 8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = i == 0 ? 18 : 1,
          );
        }
        ridge(490, 70, color(0xFF3E3C48), seed: 3);
        ridge(542, 80, color(0xFF212738), seed: 7);
        c.drawPath(
          Path()
            ..moveTo(-5, 515)
            ..lineTo(39, 475)
            ..lineTo(75, 496)
            ..moveTo(230, 516)
            ..lineTo(281, 478)
            ..lineTo(345, 511),
          Paint()
            ..color = accent.withAlpha(130)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      case BallCosmetic.aether:
        aetherCathedral();
      case BallCosmetic.phoenix:
        wash(
          const Rect.fromLTWH(-40, -100, 420, 300),
          color(0xFFFFB95D).withAlpha(72),
        );
        stars(color(0xFFFFDEAD), 29);
        for (var i = 0; i < 7; i++) {
          final x = 40.0 + i * 45;
          c.drawPath(
            Path()
              ..moveTo(170, 515)
              ..cubicTo(x - 80, 280, x - 60, 130, x, 35),
            Paint()
              ..color = accent.withAlpha(20 + i % 3 * 9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = i.isEven ? 12 : 2,
          );
        }
        ridge(494, 80, color(0xFFAA615D), seed: 2);
        ridge(550, 96, color(0xFF542B46), seed: 5);
      case BallCosmetic.chronosphere:
        chronoCitadel();
      case BallCosmetic.genesis:
        wash(
          const Rect.fromLTWH(-100, -80, 410, 330),
          color(0xFFF5B1EC).withAlpha(55),
        );
        wash(
          const Rect.fromLTWH(80, 80, 390, 360),
          color(0xFF9DFFF1).withAlpha(24),
        );
        stars(color(0xFFFFE1F4), 39);
        const ribbons = [
          Color(0xFFF9C5EA),
          Color(0xFFBAF5EC),
          Color(0xFFD3C3FF),
        ];
        for (var i = 0; i < 3; i++) {
          c.drawPath(
            Path()
              ..moveTo(-30, 90 + i * 33.0)
              ..cubicTo(
                75,
                -15 + i * 20,
                195,
                280 + i * 22,
                375,
                86 + i * 22.0,
              ),
            Paint()
              ..color = ribbons[i].withAlpha(40)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 15 - i * 3.0,
          );
        }
        for (var i = 0; i < 8; i++) {
          final x = i * 48.0 - 15, h = 35.0 + i * 27 % 60;
          polygon([
            Offset(x - 14, 550),
            Offset(x - 7, 550 - h),
            Offset(x, 534 - h),
            Offset(x + 15, 550 - h * .3),
            Offset(x + 20, 550),
          ], ribbons[i % 3].withAlpha(100));
          line(
            Offset(x, 534 - h),
            Offset(x + 4, 550),
            accent.withAlpha(110),
            .8,
          );
        }
    }
  }
}
