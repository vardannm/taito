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

  Path crest(double y, double phase) => Path()
    ..moveTo(-10, y)
    ..cubicTo(95, y - 65 + phase, 230, y + 65, 350, y - 20);

  void dune(double y, Color tint, double phase) =>
      c.drawPath(dunePath(y, phase), Paint()..color = tint);

  Path dunePath(double y, double phase) => crest(y, phase)
    ..lineTo(350, 550)
    ..lineTo(-10, 550)
    ..close();

  /// A dune whose fill drifts sideways through [colors], lit along its crest.
  void sheenDune(double y, double phase, List<Color> colors, Color rim) {
    c.drawPath(
      dunePath(y, phase),
      Paint()
        ..shader = LinearGradient(
          colors: colors,
        ).createShader(Rect.fromLTWH(0, y - 60, 340, 120)),
    );
    c.drawPath(
      crest(y, phase),
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  /// Stable pseudo-random value in [0, 1) for hand-placed scatter.
  double hash(int n) {
    final v = math.sin(n * 12.9898 + 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  /// Flat-shaded triangles in a single draw call; three colors per triangle.
  /// Opaque colors only: renderers disagree on translucent vertex colors.
  void triangles(List<Offset> points, List<Color> colors) => c.drawVertices(
    ui.Vertices(VertexMode.triangles, points, colors: colors),
    BlendMode.dst,
    Paint(),
  );

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

  /// Batched: towers, roof lines and windows are one path each.
  void skyline(double base, Color tint, int seed, {bool windows = false}) {
    final towers = Path(), roofs = Path(), lights = Path();
    for (var i = 0; i < 12; i++) {
      final x = i * 31.0 - 15, h = 35.0 + (i * 47 + seed * 31) % 80;
      towers.addRect(Rect.fromLTWH(x, base - h, 25, h + 80));
      if (i % 3 == 0)
        towers.addRect(Rect.fromLTWH(x + 11, base - h - 15, 2, 15));
      if (windows) {
        roofs
          ..moveTo(x + 1, base - h)
          ..lineTo(x + 24, base - h);
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
    c.drawPath(towers, Paint()..color = tint);
    if (!windows) return;
    c.drawPath(
      roofs,
      Paint()
        ..color = accent.withAlpha(170)
        ..style = PaintingStyle.stroke,
    );
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
      color(0xFFDCD6FF).withAlpha(22),
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
    // Rose-gold orbital rings: their back halves pass behind the sun.
    const rings = [
      (330.0, 96.0, 1.2, 60),
      (250.0, 70.0, .7, 45),
      (410.0, 128.0, 2.0, 22),
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
        c.drawCircle(p, 2.2, Paint()..color = color(0xFFFFE8D6).withAlpha(120));
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
            Colors.white.withAlpha(30),
            color(0xFFE9E1FF).withAlpha(14),
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
          colors: [
            color(0xFFF6F2FF).withAlpha(110),
            color(0xFFD9D4F2).withAlpha(90),
            color(0xFFA9B9DA).withAlpha(70),
          ],
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
    // One faint clock face high above a quiet board; nothing else competes
    // with the playfield.
    const o = Offset(170, 132);
    final gold = accent;
    wash(
      Rect.fromCircle(center: o, radius: 210),
      color(0xFF7CE6D6).withAlpha(20),
    );
    stars(color(0xFFEADAA6), 14);
    c.drawCircle(
      o,
      104,
      Paint()
        ..color = gold.withAlpha(40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    c.drawCircle(
      o,
      80,
      Paint()
        ..color = gold.withAlpha(22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    final ticks = Path();
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 - math.pi / 2;
      final d = Offset(math.cos(a), math.sin(a));
      final p = o + d * 98, q = o + d * (i % 3 == 0 ? 86 : 91);
      ticks
        ..moveTo(p.dx, p.dy)
        ..lineTo(q.dx, q.dy);
    }
    c.drawPath(
      ticks,
      Paint()
        ..color = gold.withAlpha(50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    void hand(double turns, double length, double width) {
      final a = turns * math.pi * 2 - math.pi / 2;
      final d = Offset(math.cos(a), math.sin(a));
      line(o, o + d * length, gold.withAlpha(55), width);
    }

    hand((10 + 9 / 60) / 12, 46, 2.4);
    hand(9 / 60, 70, 1.6);
    c.drawCircle(o, 3, Paint()..color = gold.withAlpha(70));
    // A low line of faint spires, then a scrim that sets the board apart.
    for (final (x, h, w) in [
      (40.0, 70.0, 11.0),
      (128.0, 56.0, 10.0),
      (214.0, 64.0, 10.0),
      (300.0, 80.0, 12.0),
    ]) {
      crystalTower(x, 540, w, h, .75);
    }
    c.drawRect(
      const Rect.fromLTWH(0, 0, 340, 540),
      Paint()..color = top.withAlpha(70),
    );
  }

  /// A board-level chip package with pins and a pin-one mark.
  void chip(Rect body) {
    final pins = Path();
    for (var y = body.top + 6; y < body.bottom - 3; y += 7) {
      pins
        ..moveTo(body.left - 5, y)
        ..lineTo(body.left, y)
        ..moveTo(body.right, y)
        ..lineTo(body.right + 5, y);
    }
    c.drawPath(
      pins,
      Paint()
        ..color = accent.withAlpha(70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final package = RRect.fromRectAndRadius(body, const Radius.circular(3));
    c.drawRRect(package, Paint()..color = color(0xFF0B3134));
    c.drawRRect(
      package,
      Paint()
        ..color = accent.withAlpha(60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(body.deflate(7), const Radius.circular(2)),
      Paint()
        ..color = accent.withAlpha(28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    c.drawCircle(
      body.topLeft + const Offset(5, 5),
      1.4,
      Paint()..color = accent.withAlpha(90),
    );
  }

  /// A jade leaf whose veins are routed like traces, ending in gold pads.
  void circuitLeaf(Offset base, double length, double angle, Color tint) {
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(angle);
    final w = length * .34;
    c.drawPath(
      Path()
        ..moveTo(0, 0)
        ..cubicTo(-w * 1.1, -length * .25, -w * .9, -length * .8, 0, -length)
        ..cubicTo(w * .9, -length * .8, w * 1.1, -length * .25, 0, 0)
        ..close(),
      Paint()..color = tint,
    );
    final veins = Path()
      ..moveTo(0, 0)
      ..lineTo(0, -length * .88);
    final pads = <Offset>[];
    for (var i = 0; i < 3; i++) {
      final y = -length * (.22 + i * .2), reach = w * (.55 - i * .1);
      for (final side in [-1.0, 1.0]) {
        final end = Offset(side * reach, y - reach - 5);
        veins
          ..moveTo(0, y)
          ..lineTo(side * reach, y - reach)
          ..lineTo(end.dx, end.dy);
        pads.add(end);
      }
    }
    c.drawPath(
      veins,
      Paint()
        ..color = accent.withAlpha(85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9,
    );
    c.drawPoints(
      ui.PointMode.points,
      pads,
      Paint()
        ..color = color(0xFFE6D59B).withAlpha(150)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    c.restore();
  }

  void circuitGarden() {
    wash(const Rect.fromLTWH(-120, -110, 470, 300), accent.withAlpha(26));
    wash(
      const Rect.fromLTWH(-80, 370, 500, 300),
      color(0xFF3FA98F).withAlpha(30),
    );
    // A faint via lattice in both margins gives the board its texture.
    c.drawPoints(
      ui.PointMode.points,
      [
        for (var y = 9.0; y < 540; y += 18)
          for (final x in [6.0, 20.0, 34.0, 306.0, 320.0, 334.0])
            if (hash((x * 7 + y).toInt()) > .3) Offset(x, y),
      ],
      Paint()
        ..color = accent.withAlpha(30)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    // Bus traces run down each margin with 45-degree jogs; the two sides
    // use different routes so they never read as a mirror image.
    final traces = Path(), rings = <Offset>[];
    void bus(double edge, double dir, List<(double, double, double)> jogs) {
      for (var k = 0; k < 3; k++) {
        var x = edge + dir * (10 + k * 7);
        traces.moveTo(x, -10);
        for (final (y, depth, length) in jogs) {
          final d = dir * depth, ky = y + k * 3;
          traces
            ..lineTo(x, ky)
            ..lineTo(x + d, ky + depth)
            ..lineTo(x + d, ky + depth + length)
            ..lineTo(x, ky + depth * 2 + length);
          if (k == 2) {
            // The innermost trace taps off toward the field and ends in a via.
            final tap = Offset(x + d, ky + depth + length * .5);
            final end = tap + Offset(dir * 16, 16);
            traces
              ..moveTo(tap.dx, tap.dy)
              ..lineTo(end.dx, end.dy)
              ..moveTo(x, ky + depth * 2 + length);
            rings.add(end);
          }
        }
        traces.lineTo(x, 560);
      }
    }

    bus(0, 1, [(70, 14, 60), (250, 10, 40), (400, 16, 30)]);
    bus(340, -1, [(130, 12, 70), (310, 16, 36)]);
    // A header bus along the top edge.
    final header = Path();
    for (var k = 0; k < 2; k++) {
      final y = 18.0 + k * 7;
      header
        ..moveTo(-10, y)
        ..lineTo(84 - k * 7, y)
        ..lineTo(98 - k * 7, y + 14)
        ..lineTo(126, y + 14)
        ..moveTo(350, y + 4)
        ..lineTo(262 + k * 7, y + 4)
        ..lineTo(250 + k * 7, y + 16)
        ..lineTo(222, y + 16);
      rings
        ..add(Offset(129, y + 14))
        ..add(Offset(219, y + 16));
    }
    traces.addPath(header, Offset.zero);
    c.drawPath(
      traces,
      Paint()
        ..color = accent.withAlpha(60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round,
    );
    final via = Path();
    for (final p in rings) {
      via.addOval(Rect.fromCircle(center: p, radius: 2.6));
    }
    c.drawPath(
      via,
      Paint()
        ..color = accent.withAlpha(110)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    chip(const Rect.fromLTWH(-16, 168, 42, 52));
    chip(const Rect.fromLTWH(312, 222, 40, 44));
    // Small parts seated beside the traces.
    final parts = Path(), leads = <Offset>[];
    for (final (x, y, vertical) in [
      (48.0, 96.0, true),
      (40.0, 330.0, true),
      (300.0, 120.0, true),
      (291.0, 410.0, true),
      (164.0, 38.0, false),
    ]) {
      final body = Rect.fromCenter(
        center: Offset(x, y),
        width: vertical ? 5 : 10,
        height: vertical ? 10 : 5,
      );
      parts.addRRect(RRect.fromRectAndRadius(body, const Radius.circular(1)));
      leads.addAll(
        vertical
            ? [body.topCenter, body.bottomCenter]
            : [body.centerLeft, body.centerRight],
      );
    }
    c.drawPath(parts, Paint()..color = color(0xFF0B3134));
    c.drawPath(
      parts,
      Paint()
        ..color = accent.withAlpha(70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    c.drawPoints(
      ui.PointMode.points,
      leads,
      Paint()
        ..color = color(0xFFE6D59B).withAlpha(120)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    // Jade foliage grows from the bottom corners over a dark bed.
    dune(512, color(0xFF0C3436).withAlpha(200), 22);
    circuitLeaf(const Offset(18, 556), 118, .32, color(0xFF1E5E54));
    circuitLeaf(const Offset(2, 548), 84, -.12, color(0xFF2A7464));
    circuitLeaf(const Offset(56, 560), 58, .78, color(0xFF22685A));
    circuitLeaf(const Offset(330, 556), 104, -.36, color(0xFF1E5E54));
    circuitLeaf(const Offset(300, 562), 64, -.82, color(0xFF2A7464));
    dune(546, color(0xFF0A2B30), -14);
  }

  void obsidianCavern() {
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
    wash(const Rect.fromLTWH(-130, 260, 240, 360), accent.withAlpha(42));
    wash(
      const Rect.fromLTWH(250, 120, 220, 300),
      color(0xFF5867C8).withAlpha(26),
    );
    // Faceted volcanic glass walls with their own profile on each side.
    // Facets turned toward the light get a glassy violet edge.
    final points = <Offset>[], colors = <Color>[], glints = Path();
    void wall(double edge, double dir, List<double> profile) {
      final step = 580 / (profile.length - 1);
      for (var i = 0; i < profile.length - 1; i++) {
        final y0 = i * step - 20, y1 = y0 + step;
        final a = Offset(edge + dir * profile[i], y0);
        final b = Offset(edge + dir * profile[i + 1], y1);
        final lit = profile[i + 1] < profile[i];
        final face = lit ? color(0xFF2E2552) : color(0xFF1B1733);
        final back = Color.lerp(face, color(0xFF141228), .45)!;
        points.addAll([Offset(edge, y0), a, b, Offset(edge, y0), b]);
        points.add(Offset(edge, y1));
        colors.addAll([back, face, face, back, face, back]);
        if (lit) {
          glints
            ..moveTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy);
        }
      }
    }

    wall(0, 1, [22, 34, 14, 26, 40, 18, 30, 12, 24, 36, 20, 28, 16]);
    wall(340, -1, [16, 28, 38, 20, 12, 30, 22, 36, 26, 14, 32, 18, 26]);
    triangles(points, colors);
    c.drawPath(
      glints,
      Paint()
        ..color = accent.withAlpha(80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9,
    );
    ridge(555, 48, color(0xFF211C3D));
    // One leaning crystal cluster per corner, each with its own shape.
    for (final (x, y, h, w, lean, tint) in [
      (20.0, 556.0, 128.0, 21.0, .16, color(0xFF8E72D6)),
      (-2.0, 552.0, 82.0, 16.0, -.1, color(0xFF5E5DB4)),
      (52.0, 560.0, 56.0, 13.0, .42, color(0xFFB39BEA)),
      (322.0, 556.0, 98.0, 19.0, -.22, color(0xFF5E5DB4)),
      (342.0, 558.0, 62.0, 14.0, .05, color(0xFF9479DA)),
    ]) {
      c.save();
      c.translate(x, y);
      c.rotate(lean);
      crystal(0, 0, h, tint, w);
      c.restore();
    }
  }

  void pearlBead(Offset p, double r) => c.drawCircle(
    p,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.35, -.45),
        colors: [
          Colors.white,
          color(0xFFF7E8EC),
          color(0xFFDCC4D3),
          color(0xFFB8CAD6),
        ],
        stops: const [0, .3, .75, 1],
      ).createShader(Rect.fromCircle(center: p, radius: r)),
  );

  /// A pearl strand hanging between [a] and [b] through [sag].
  void strand(Offset a, Offset sag, Offset b, int count, double size) {
    Offset at(double t) =>
        a * ((1 - t) * (1 - t)) + sag * (2 * t * (1 - t)) + b * (t * t);
    c.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(sag.dx, sag.dy, b.dx, b.dy),
      Paint()
        ..color = color(0xFFC9A3B3).withAlpha(110)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6,
    );
    for (var i = 0; i <= count; i++) {
      final t = i / count;
      pearlBead(at(t), size * (.7 + .45 * math.sin(math.pi * t)));
    }
  }

  void pearlTides() {
    wash(
      const Rect.fromLTWH(-170, -150, 400, 340),
      color(0xFFF4C2D2).withAlpha(95),
    );
    wash(
      const Rect.fromLTWH(170, 110, 340, 340),
      color(0xFFB9E6DE).withAlpha(70),
    );
    wash(
      const Rect.fromLTWH(-150, 300, 340, 300),
      color(0xFFD6C8EF).withAlpha(80),
    );
    strand(
      const Offset(-8, 18),
      const Offset(66, 130),
      const Offset(168, -8),
      17,
      3.4,
    );
    strand(
      const Offset(-8, 52),
      const Offset(34, 120),
      const Offset(92, -8),
      9,
      2.6,
    );
    strand(
      const Offset(262, -8),
      const Offset(318, 92),
      const Offset(350, 30),
      9,
      3,
    );
    for (final (p, s) in [
      (const Offset(118, 70), 4.0),
      (const Offset(300, 92), 3.0),
      (const Offset(54, 312), 2.5),
    ]) {
      sparkle(p, s, Colors.white.withAlpha(200));
    }
    sheenDune(442, 22, [
      color(0xFFC6E3DF),
      color(0xFFE9D3E1),
      color(0xFFC8DCEB),
    ], Colors.white.withAlpha(150));
    sheenDune(484, -14, [
      color(0xFFEBD6DF),
      color(0xFFB8D7D9),
      color(0xFFDCCDEB),
    ], Colors.white.withAlpha(170));
    sheenDune(522, 30, [
      color(0xFFF4E6DA),
      color(0xFFEAD4DC),
      color(0xFFF2E4D6),
    ], Colors.white.withAlpha(190));
    // A scallop shell with its pearl at left, two loose pearls at right.
    const hinge = Offset(42, 540);
    final fan = Path()..moveTo(hinge.dx, hinge.dy);
    final ribs = Path();
    for (var i = 0; i <= 8; i++) {
      final a = math.pi * (1.1 + .8 * i / 8);
      final p = hinge + Offset(math.cos(a), math.sin(a)) * 44;
      if (i > 0) {
        final m = math.pi * (1.1 + .8 * (i - .5) / 8);
        final q = hinge + Offset(math.cos(m), math.sin(m)) * 49;
        fan.quadraticBezierTo(q.dx, q.dy, p.dx, p.dy);
      } else {
        fan.lineTo(p.dx, p.dy);
      }
      ribs
        ..moveTo(hinge.dx, hinge.dy)
        ..lineTo(p.dx, p.dy);
    }
    fan.close();
    c.drawPath(
      fan,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 1),
          radius: 1,
          colors: [color(0xFFE7C3CC), color(0xFFFBEEE7)],
        ).createShader(Rect.fromCircle(center: hinge, radius: 48)),
    );
    c.drawPath(
      ribs,
      Paint()
        ..color = color(0xFFD3A9B4).withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9,
    );
    for (final (p, r) in [
      (const Offset(84, 530), 7.5),
      (const Offset(294, 524), 6.0),
      (const Offset(311, 532), 4.2),
    ]) {
      c.drawCircle(
        p + Offset(r * .3, r * .45),
        r,
        Paint()..color = color(0xFF9C8A9E).withAlpha(45),
      );
      pearlBead(p, r);
    }
    sparkle(const Offset(80, 525), 3, Colors.white.withAlpha(230));
  }

  /// Low-poly alloy facets: absent behind play, crisper toward the margins
  /// and floor. Facets share a handful of batched paths.
  void titaniumFacets() {
    const cols = 7, rows = 11;
    final grid = [
      for (var r = 0; r <= rows; r++)
        [
          for (var q = 0; q <= cols; q++)
            Offset(
              q * 340 / cols +
                  (q == 0 || q == cols ? 0 : (hash(r * 17 + q) - .5) * 30),
              r * 540 / rows +
                  (r == 0 || r == rows ? 0 : (hash(r * 31 + q * 7) - .5) * 28),
            ),
        ],
    ];
    double smooth(double from, double to, double v) {
      final t = ((v - from) / (to - from)).clamp(0.0, 1.0);
      return t * t * (3 - 2 * t);
    }

    final facets = <int, Path>{}, edges = Path();
    final light = color(0xFFEFF5F8), dark = color(0xFF4F7390);
    var n = 0;
    for (var r = 0; r < rows; r++) {
      for (var q = 0; q < cols; q++) {
        final a = grid[r][q], b = grid[r][q + 1];
        final d = grid[r + 1][q], e = grid[r + 1][q + 1];
        final split = (r + q).isEven;
        for (final tri
            in split
                ? [
                    [a, b, e],
                    [a, e, d],
                  ]
                : [
                    [a, b, d],
                    [b, e, d],
                  ]) {
          n++;
          final center = (tri[0] + tri[1] + tri[2]) / 3;
          final side = (center.dx - 170).abs() / 170;
          final strength = math.max(
            smooth(.45, .95, side),
            math.max(
              smooth(.72, 1, center.dy / 540),
              smooth(.84, 1, 1 - center.dy / 540) * .5,
            ),
          );
          // Behind the playfield the facets vanish entirely.
          if (strength < .08) continue;
          // Light falls from the upper left: facets facing it brighten.
          final normal =
              (tri[1] - tri[0]).dx * (tri[2] - tri[0]).dy -
              (tri[1] - tri[0]).dy * (tri[2] - tri[0]).dx;
          final tone = ((hash(n) * .55 + (normal > 0 ? .45 : 0)) * 4).round();
          final alpha = ((.06 + .3 * strength) * 20).round();
          // Quantized tone and opacity keep the batch to a few paths.
          final tint = Color.lerp(
            dark,
            light,
            tone / 4,
          )!.withValues(alpha: alpha / 20);
          facets.putIfAbsent(tint.toARGB32(), Path.new).addPolygon(tri, true);
          if (strength > .6) {
            edges
              ..moveTo(tri[0].dx, tri[0].dy)
              ..lineTo(tri[1].dx, tri[1].dy);
          }
        }
      }
    }
    for (final MapEntry(:key, :value) in facets.entries) {
      c.drawPath(value, Paint()..color = Color(key));
    }
    c.drawPath(
      edges,
      Paint()
        ..color = Colors.white.withAlpha(55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    wash(const Rect.fromLTWH(-120, -140, 420, 320), Colors.white.withAlpha(60));
  }

  /// A tilted spiral galaxy: soft halo, two dusty arms and a bright core.
  void spiralGalaxy(Offset o, double r, double tilt) {
    final arm = color(0xFFD6A9F2), core = color(0xFFFFE8F3);
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(tilt);
    c.scale(1, .4);
    final disk = Rect.fromCircle(center: Offset.zero, radius: r);
    c.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [arm.withAlpha(80), arm.withAlpha(22), arm.withAlpha(0)],
          stops: const [0, .45, 1],
        ).createShader(disk),
    );
    final arms = Path(), dust = Path();
    for (final start in [0.0, math.pi]) {
      for (var i = 0; i <= 40; i++) {
        final theta = i / 40 * math.pi * 2.2;
        final radius = r * (.1 + .85 * i / 40);
        final p = Offset(
          math.cos(theta + start) * radius,
          math.sin(theta + start) * radius,
        );
        if (i == 0) {
          arms.moveTo(p.dx, p.dy);
        } else {
          arms.lineTo(p.dx, p.dy);
        }
        if (i % 3 == 0 && i > 4) {
          dust.addOval(
            Rect.fromCircle(
              center: p + Offset(hash(i) - .5, hash(i + 9) - .5) * 14,
              radius: 1 + hash(i + 4) * 1.4,
            ),
          );
        }
      }
    }
    c.drawPath(
      arms,
      Paint()
        ..color = arm.withAlpha(30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16,
    );
    c.drawPath(
      arms,
      Paint()
        ..color = arm.withAlpha(75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    c.drawPath(dust, Paint()..color = core.withAlpha(120));
    c.drawCircle(
      Offset.zero,
      r * .26,
      Paint()
        ..shader = RadialGradient(
          colors: [core.withAlpha(170), core.withAlpha(50), core.withAlpha(0)],
          stops: const [0, .35, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * .26)),
    );
    c.restore();
  }

  void opalFire() {
    // Milky stone with play-of-color gathered at the margins.
    wash(
      const Rect.fromLTWH(-160, -140, 370, 320),
      color(0xFFFFC2AE).withAlpha(85),
    );
    wash(
      const Rect.fromLTWH(170, -120, 340, 340),
      color(0xFF92EBD3).withAlpha(95),
    );
    wash(
      const Rect.fromLTWH(-160, 290, 340, 330),
      color(0xFF94C6F6).withAlpha(85),
    );
    wash(
      const Rect.fromLTWH(180, 320, 330, 330),
      color(0xFFC3A2F4).withAlpha(85),
    );
    // Opal fire: a few diagonal flashes of small spectral facets at the
    // margins. Hue drifts along each flash and fades out at its ends, so the
    // middle of the stone stays milky and calm.
    const spectrum = [
      Color(0xFF52D6B8),
      Color(0xFF62B4F2),
      Color(0xFF9E86EE),
      Color(0xFFEE88B6),
      Color(0xFFF0B864),
      Color(0xFF86DA7A),
    ];
    const flashes = [
      (Offset(14, 150), 74.0, 0),
      (Offset(328, 248), 80.0, 2),
      (Offset(18, 382), 56.0, 4),
      (Offset(276, 20), 66.0, 1),
    ];
    const cell = 9.0, along = Offset(.82, -.57), across = Offset(.57, .82);
    final facets = <int, Path>{}, glints = Path();
    for (final (k, (o, length, shift)) in flashes.indexed) {
      for (var i = -length ~/ cell; i <= length ~/ cell; i++) {
        for (var j = -3; j <= 3; j++) {
          final n = k * 997 + i * 31 + j;
          final u = i / (length / cell), v = j / 3.5;
          final strength = (1 - u * u) * (1 - v * v);
          if (strength < .12 || hash(n) < .18) continue;
          final p =
              o +
              along * (i * cell + (hash(n + 1) - .5) * 5) +
              across * (j * cell * .9 + (hash(n + 2) - .5) * 5);
          final size = cell * (.55 + hash(n + 3) * .35);
          final spin = hash(n + 4) * math.pi;
          final tri = [
            for (final turn in [0.0, 2.1, 4.2])
              p + Offset(math.cos(spin + turn), math.sin(spin + turn)) * size,
          ];
          final hue =
              spectrum[(shift + (u + 1) * 2.2 + hash(n + 5) * .8).floor() % 6];
          final level = strength > .6 ? 3 : (strength > .3 ? 2 : 1);
          facets
              .putIfAbsent(
                hue.withValues(alpha: .13 * level).toARGB32(),
                Path.new,
              )
              .addPolygon(tri, true);
          if (level == 3 && hash(n + 6) > .75) glints.addPolygon(tri, true);
        }
      }
    }
    for (final MapEntry(:key, :value) in facets.entries) {
      c.drawPath(value, Paint()..color = Color(key));
    }
    c.drawPath(glints, Paint()..color = Colors.white.withAlpha(70));
    // Cut strata at the floor: angular bands, unlike Pearl's soft tides.
    void stratum(double y, int seed, List<Color> colors, Color rim) {
      final edge = <Offset>[
        for (var i = 0; i <= 9; i++)
          Offset(i * 40.0 - 10, y - i * 2.5 + (hash(seed * 13 + i) - .5) * 16),
      ];
      c.drawPath(
        Path()..addPolygon([
          ...edge,
          const Offset(350, 560),
          const Offset(-10, 560),
        ], true),
        Paint()
          ..shader = LinearGradient(
            colors: colors,
          ).createShader(Rect.fromLTWH(0, y - 40, 340, 80)),
      );
      c.drawPath(
        Path()..addPolygon(edge, false),
        Paint()
          ..color = rim
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    stratum(474, 1, [
      color(0xFFA7E6D8).withAlpha(140),
      color(0xFFB9C8F3).withAlpha(140),
      color(0xFFF2C3D6).withAlpha(140),
    ], Colors.white.withAlpha(170));
    stratum(504, 2, [
      color(0xFFC8B4F1).withAlpha(170),
      color(0xFF9FDCE6).withAlpha(170),
      color(0xFFF4D5AE).withAlpha(170),
    ], Colors.white.withAlpha(180));
    stratum(532, 3, [
      color(0xFF8FC7D2),
      color(0xFFA7B7E2),
      color(0xFF94D2C0),
    ], Colors.white.withAlpha(150));
    for (final (p, s) in [
      (const Offset(26, 140), 4.0),
      (const Offset(318, 244), 3.5),
      (const Offset(272, 24), 3.0),
      (const Offset(150, 500), 3.0),
    ]) {
      sparkle(p, s, Colors.white.withAlpha(210));
    }
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
      case BallCosmetic.circuit:
        circuitGarden();
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
        obsidianCavern();
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
          // Shaded toward the screen edge, with a soft glow around the
          // conduit, lit brace edges and clamps between the braces.
          final column = Rect.fromLTWH(x, 0, 46, 540);
          final inner = x < 0 ? column.right : column.left;
          c.drawRect(
            column,
            Paint()
              ..shader = LinearGradient(
                colors: [color(0xFF1A2F45), color(0xFF26425A)],
                begin: x < 0 ? Alignment.centerLeft : Alignment.centerRight,
                end: x < 0 ? Alignment.centerRight : Alignment.centerLeft,
              ).createShader(column),
          );
          c.drawRect(
            Rect.fromLTWH(x + 12.5, 0, 14, 540),
            Paint()..color = accent.withAlpha(24),
          );
          c.drawRect(
            Rect.fromLTWH(x + 17.5, 0, 4, 540),
            Paint()..color = accent.withAlpha(120),
          );
          c.drawRect(
            Rect.fromLTWH(x + 19, 0, 1, 540),
            Paint()..color = Colors.white.withAlpha(60),
          );
          final braces = Path(), edges = Path(), clamps = Path();
          for (var i = 0; i < 8; i++) {
            final y = i * 78.0;
            braces.addPolygon([
              Offset(x, y),
              Offset(x + 46, y + 24),
              Offset(x + 46, y + 40),
              Offset(x, y + 16),
            ], true);
            edges
              ..moveTo(x, y)
              ..lineTo(x + 46, y + 24);
            clamps.addRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: Offset(x + 19.5, y + 59),
                  width: 13,
                  height: 6,
                ),
                const Radius.circular(2),
              ),
            );
          }
          c.drawPath(braces, Paint()..color = color(0xFF3A5066));
          c.drawPath(
            edges,
            Paint()
              ..color = color(0xFF7D98AE).withAlpha(110)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .8,
          );
          c.drawPath(clamps, Paint()..color = color(0xFF2E4A62));
          for (var i = 0; i < 8; i++) {
            c.drawCircle(
              Offset(x + 19.5, i * 78.0 + 59),
              1.1,
              Paint()..color = accent.withAlpha(170),
            );
          }
          line(Offset(inner, 0), Offset(inner, 540), accent.withAlpha(40));
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
        stars(color(0xFFFFD4E6), 52);
        spiralGalaxy(const Offset(232, 104), 104, -.38);
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
        pearlTides();
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
        titaniumFacets();
      case BallCosmetic.opal:
        opalFire();
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
