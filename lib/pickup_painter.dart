import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pickup faces: the brass coin and the three Infinite crystals. Every one is
/// built from flat fills and gradients — no blurs, no layers — so a screenful
/// of them costs the same handful of draws as a single one.

const _coinEdge = Color(0xFF6B4A1E), _coinRim = Color(0xFFC9973E);
const _coinFace = Color(0xFFFFE9A8), _coinDeep = Color(0xFFE0A93F);

/// A minted coin, turning slowly on its axis. [spin] is the cosine of its
/// angle. The turn is deliberately shallow: at thirteen pixels across, a coin
/// edge-on is an unreadable sliver, so it never narrows past half its face.
/// Purely visual; the collection radius never changes with it.
void paintBrassCoin(Canvas c, Offset p, double radius, double spin) {
  final turn = .55 + .45 * spin.abs();
  final width = radius * turn;
  final face = Rect.fromCenter(center: p, width: width * 2, height: radius * 2);
  // Seated shadow, always the full width so the coin never looks unmoored.
  c.drawOval(
    Rect.fromCenter(
      center: p + const Offset(0, 1.6),
      width: radius * 1.9,
      height: radius * 1.5,
    ),
    Paint()..color = const Color(0x33261504),
  );
  c.drawOval(
    face,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_coinFace, _coinDeep],
      ).createShader(face),
  );
  c.drawOval(
    face,
    Paint()
      ..color = _coinEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  // Milled rim, then the raised face inside it.
  c.drawOval(
    Rect.fromCenter(center: p, width: width * 2 - 3, height: radius * 2 - 3),
    Paint()
      ..color = _coinRim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1,
  );
  final mark = Path();
  final unit = radius / 6;
  // A four-point star struck into the face: reads at six pixels across.
  for (var i = 0; i < 4; i++) {
    final angle = i * math.pi / 2;
    final long = Offset(math.cos(angle), math.sin(angle)) * (unit * 3.6);
    final short =
        Offset(math.cos(angle + math.pi / 4), math.sin(angle + math.pi / 4)) *
        (unit * 1.35);
    final point = Offset(p.dx + long.dx * turn, p.dy + long.dy);
    final waist = Offset(p.dx + short.dx * turn, p.dy + short.dy);
    if (i == 0) {
      mark.moveTo(point.dx, point.dy);
    } else {
      mark.lineTo(point.dx, point.dy);
    }
    mark.lineTo(waist.dx, waist.dy);
  }
  mark.close();
  c.drawPath(mark, Paint()..color = const Color(0xFF8A6524));
  // One specular sweep across the upper left, the only highlight it needs.
  c.drawArc(
    Rect.fromCenter(
      center: p,
      width: width * 2 - 4.5,
      height: radius * 2 - 4.5,
    ),
    math.pi * 1.12,
    math.pi * .55,
    false,
    Paint()
      ..color = const Color(0xCCFFF6D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round,
  );
}

/// Distinct faces for Infinite rewards.
enum PickupFace { combo, shield, heart, magnet }

const _faces = {
  PickupFace.magnet: (Color(0xFFD0B5FF), Color(0xFF8655CF), Color(0xFF48277E)),
  PickupFace.combo: (Color(0xFFFFD873), Color(0xFFC27A15), Color(0xFF7A4A0C)),
  PickupFace.shield: (Color(0xFF8FD9EC), Color(0xFF2489A6), Color(0xFF0F4B5E)),
  PickupFace.heart: (Color(0xFFFF8E97), Color(0xFFD5404C), Color(0xFF7C1F28)),
};

/// [glint] runs 0..1 and sweeps the highlight; pass 0 for reduced motion.
void paintPickup(Canvas c, Offset p, PickupFace face, double glint) {
  final (light, mid, dark) = _faces[face]!;
  // A cream setting keeps every pickup readable on any board tint.
  c.drawCircle(p, 13.5, Paint()..color = mid.withAlpha(46));
  c.drawCircle(p, 11.5, Paint()..color = const Color(0xFFFBF6E7));
  c.drawCircle(
    p,
    11.5,
    Paint()
      ..color = dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6,
  );
  final body = Path(), crown = Path();
  switch (face) {
    case PickupFace.magnet:
      body
        ..moveTo(p.dx - 7, p.dy - 7)
        ..lineTo(p.dx - 7, p.dy + 1)
        ..cubicTo(p.dx - 7, p.dy + 11, p.dx + 7, p.dy + 11, p.dx + 7, p.dy + 1)
        ..lineTo(p.dx + 7, p.dy - 7)
        ..lineTo(p.dx + 3, p.dy - 7)
        ..lineTo(p.dx + 3, p.dy + 1)
        ..cubicTo(p.dx + 3, p.dy + 5, p.dx - 3, p.dy + 5, p.dx - 3, p.dy + 1)
        ..lineTo(p.dx - 3, p.dy - 7)
        ..close();
      crown
        ..addRect(Rect.fromLTWH(p.dx - 7, p.dy - 7, 4, 4))
        ..addRect(Rect.fromLTWH(p.dx + 3, p.dy - 7, 4, 4));
    case PickupFace.combo:
      // Brilliant cut: flat table, crown shoulders, deep pavilion.
      body
        ..moveTo(p.dx - 4.6, p.dy - 4.4)
        ..lineTo(p.dx + 4.6, p.dy - 4.4)
        ..lineTo(p.dx + 7.6, p.dy - 1)
        ..lineTo(p.dx, p.dy + 8.4)
        ..lineTo(p.dx - 7.6, p.dy - 1)
        ..close();
      crown
        ..moveTo(p.dx - 4.6, p.dy - 4.4)
        ..lineTo(p.dx + 4.6, p.dy - 4.4)
        ..lineTo(p.dx + 2.4, p.dy - 1)
        ..lineTo(p.dx - 2.4, p.dy - 1)
        ..close();
    case PickupFace.shield:
      body
        ..moveTo(p.dx, p.dy - 8)
        ..lineTo(p.dx + 6.8, p.dy - 4.6)
        ..lineTo(p.dx + 6.1, p.dy + 1.6)
        ..lineTo(p.dx, p.dy + 8.2)
        ..lineTo(p.dx - 6.1, p.dy + 1.6)
        ..lineTo(p.dx - 6.8, p.dy - 4.6)
        ..close();
      crown
        ..moveTo(p.dx, p.dy - 8)
        ..lineTo(p.dx + 6.8, p.dy - 4.6)
        ..lineTo(p.dx + 6.3, p.dy - 1.4)
        ..lineTo(p.dx - 6.3, p.dy - 1.4)
        ..lineTo(p.dx - 6.8, p.dy - 4.6)
        ..close();
    case PickupFace.heart:
      body
        ..moveTo(p.dx, p.dy + 7.6)
        ..cubicTo(
          p.dx - 13.2,
          p.dy - 1.4,
          p.dx - 6.4,
          p.dy - 11.6,
          p.dx,
          p.dy - 4.2,
        )
        ..cubicTo(
          p.dx + 6.4,
          p.dy - 11.6,
          p.dx + 13.2,
          p.dy - 1.4,
          p.dx,
          p.dy + 7.6,
        )
        ..close();
      crown
        ..moveTo(p.dx - 1.4, p.dy - 4.6)
        ..cubicTo(
          p.dx - 6.4,
          p.dy - 9.2,
          p.dx - 9.4,
          p.dy - 3.4,
          p.dx - 5.2,
          p.dy - .4,
        )
        ..cubicTo(
          p.dx - 6.2,
          p.dy - 4.4,
          p.dx - 4.2,
          p.dy - 6.6,
          p.dx - 1.4,
          p.dy - 4.6,
        )
        ..close();
  }
  final bounds = Rect.fromCircle(center: p, radius: 9);
  c.drawPath(
    body,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [light, mid, dark],
        stops: const [0, .55, 1],
      ).createShader(bounds),
  );
  // The upper facet catches the light; the lower body keeps its depth.
  c.drawPath(crown, Paint()..color = light.withAlpha(150));
  if (face == PickupFace.combo) {
    // The cut is what makes it a gem: shoulders folding down to the tip.
    final facets = Path()
      ..moveTo(p.dx - 4.6, p.dy - 4.4)
      ..lineTo(p.dx, p.dy + 8.4)
      ..moveTo(p.dx + 4.6, p.dy - 4.4)
      ..lineTo(p.dx, p.dy + 8.4)
      ..moveTo(p.dx - 7.6, p.dy - 1)
      ..lineTo(p.dx - 4.6, p.dy - 4.4)
      ..moveTo(p.dx + 7.6, p.dy - 1)
      ..lineTo(p.dx + 4.6, p.dy - 4.4);
    c.drawPath(
      facets,
      Paint()
        ..color = dark.withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9,
    );
    // One face of the pavilion stays bright, the way a real stone does.
    c.drawPath(
      Path()
        ..moveTo(p.dx - 4.6, p.dy - 4.4)
        ..lineTo(p.dx, p.dy - 4.4)
        ..lineTo(p.dx, p.dy + 8.4)
        ..close(),
      Paint()..color = light.withAlpha(58),
    );
  }
  c.drawPath(
    body,
    Paint()
      ..color = dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round,
  );
  if (glint <= 0) return;
  // A single travelling spark, brightest as it crosses the crown.
  final sweep = math.sin(glint * math.pi * 2);
  c.drawCircle(
    Offset(p.dx + sweep * 4.2, p.dy - 5 + sweep.abs() * 1.4),
    1.5,
    Paint()
      ..color = Colors.white.withValues(alpha: .35 + .45 * (1 - sweep.abs())),
  );
}
