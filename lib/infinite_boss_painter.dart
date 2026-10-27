import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game.dart';
import 'infinite_boss.dart';
import 'infinite_painter.dart';
import 'late_enemies.dart';

Paint _outline(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Offset _point(EnemyPoint point) => Offset(point.x, point.y);
const toxicLime = Color(0xFFB6FF19), toxicYellow = Color(0xFFEFFF35);
const toxicMagenta = Color(0xFFFF3ABF);
const colossusShotViolet = Color(0xFF6418A6), colossusShotPink = Color(0xFFFF3ABF);
const novaCyan = Color(0xFF6FF2FF), novaViolet = Color(0xFF9B5CFF);

/// Lit arcs of a [LaserRing] at [time], as (start angle, sweep) pairs.
List<(double, double)> _ringArcs(LaserRing ring, double time) {
  final gaps = [
    for (final (start, width) in ring.gaps)
      ((start + ring.spin * time) % (math.pi * 2), width),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return [
    for (var i = 0; i < gaps.length; i++)
      (
        gaps[i].$1 + gaps[i].$2,
        (i + 1 < gaps.length ? gaps[i + 1].$1 : gaps.first.$1 + math.pi * 2) -
            gaps[i].$1 -
            gaps[i].$2,
      ),
  ];
}

/// Shared shot geometry keeps the aim warnings, pools and laser hitboxes in
/// agreement. Bullets are batched; the encounter uses no blur or saveLayer.
void paintInfiniteBoss(Canvas canvas, BalanceGame game, bool reducedMotion) {
  final boss = game.boss;
  if (!game.infinite || boss == null) return;
  final storm = boss.kind == BossKind.stormColossus;
  final seraph = boss.kind == BossKind.eclipseSeraph;
  final prism = boss.kind == BossKind.prismReaver;
  final venom = boss.kind == BossKind.venomCrown;
  final nova = boss.kind == BossKind.novaPulsar;
  final amber = nova
      ? novaCyan
      : venom
      ? toxicLime
      : prism
      ? const Color(0xFF70F3D4)
      : storm
      ? const Color(0xFF51D6E7)
      : const Color(0xFFFFB543);
  final hot = nova
      ? novaViolet
      : venom
      ? toxicMagenta
      : prism
      ? const Color(0xFFF884D4)
      : seraph
      ? const Color(0xFFF66C9E)
      : storm
      ? const Color(0xFFAA6DF0)
      : const Color(0xFFE45A42);
  const shell = Color(0xFF243638), pale = Color(0xFFFFF0C5);
  final position = _point(boss.position);
  final ink = infiniteBoardInk(game, position);
  canvas.save();
  canvas.clipRect(Rect.fromLTRB(24, game.visibleTop + 42, 336, 537));
  final bullets = Path(), bulletCores = Path();
  final toxicBullets = Path(), toxicCores = Path(), toxicWarnings = Path();
  final crystalTrails = Path(), cometWarnings = Path(), cometMarks = Path();
  if (venom) {
    final routes = Path();
    for (final wall in boss.toxicWalls) {
      if (boss.age >= wall.at + InfiniteBoss.toxicWarning) continue;
      for (final side in [-1.0, 1.0]) {
        for (var i = 0; i < 24; i++) {
          final time = i * InfiniteBoss.toxicLife / 24;
          final a = wall.positionAt(
            time,
            side,
            side < 0 ? ToxicWall.bulletsPerSide - 1 : 0,
          );
          final b = wall.positionAt(
            time + .045,
            side,
            side < 0 ? ToxicWall.bulletsPerSide - 1 : 0,
          );
          routes.moveTo(a.x, a.y);
          routes.lineTo(b.x, b.y);
        }
      }
    }
    canvas.drawPath(routes, _outline(toxicLime.withAlpha(190), 1.5));
  }
  for (final shot in boss.shots) {
    if (shot.cancelled) continue;
    final at = _point(shot.position);
    if (venom && shot.kind == LateShotKind.shard) {
      final oval = Rect.fromCircle(center: at, radius: shot.radius);
      if (shot.age < 0) {
        toxicWarnings.addOval(oval);
      } else if (shot.visible) {
        toxicBullets.addOval(oval);
        toxicCores.addOval(
          Rect.fromCircle(center: at + const Offset(-1.5, -1.5), radius: 2.5),
        );
      }
    } else if (shot.kind == LateShotKind.spinner) {
      if (shot.age < 0) {
        final trail = Path();
        for (var t = 0.0; t < shot.life; t += .12) {
          final a = _point(shot.positionAt(t));
          final b = _point(shot.positionAt(math.min(t + .045, shot.life)));
          trail.moveTo(a.dx, a.dy);
          trail.lineTo(b.dx, b.dy);
        }
        canvas.drawPath(trail, _outline(hot.withAlpha(150), 1.25));
      } else if (shot.visible) {
        final rotor = Path();
        // Four asymmetric vanes spin independently of the travel direction.
        for (var i = 0; i < 8; i++) {
          final angle =
              (reducedMotion ? shot.pathPhase : shot.rotation) +
              i * math.pi / 4;
          final radius = i.isEven ? shot.radius : shot.radius * .4;
          final point = at + Offset(math.cos(angle), math.sin(angle)) * radius;
          if (i == 0) {
            rotor.moveTo(point.dx, point.dy);
          } else {
            rotor.lineTo(point.dx, point.dy);
          }
        }
        rotor.close();
        canvas.drawPath(rotor, _outline(ink, 4));
        canvas.drawPath(rotor, Paint()..color = amber);
        canvas.drawCircle(at, 2.5, Paint()..color = hot);
      }
    } else if (seraph &&
        (shot.kind == LateShotKind.moth || shot.kind == LateShotKind.shard)) {
      if (shot.age < 0 && shot.kind == LateShotKind.shard) {
        final end = _point(shot.positionAt(2.1));
        final start = _point(shot.origin);
        final delta = end - start;
        for (var d = 0.0; d < delta.distance; d += 19) {
          final a = start + delta * (d / delta.distance);
          final b =
              start +
              delta * (math.min(d + 7, delta.distance) / delta.distance);
          cometWarnings.moveTo(a.dx, a.dy);
          cometWarnings.lineTo(b.dx, b.dy);
        }
        cometMarks.addOval(Rect.fromCircle(center: end, radius: 7));
      } else if (shot.visible) {
        final comet = shot.kind == LateShotKind.shard;
        final previous = _point(shot.positionAt(math.max(0, shot.age - .16)));
        crystalTrails.moveTo(previous.dx, previous.dy);
        crystalTrails.lineTo(at.dx, at.dy);
        final angle = math.atan2(at.dy - previous.dy, at.dx - previous.dx);
        final forward = Offset(math.cos(angle), math.sin(angle));
        final side = Offset(-forward.dy, forward.dx);
        final tip = at + forward * (comet ? 11 : 9);
        final tail = at - forward * 8;
        bullets.moveTo(tip.dx, tip.dy);
        bullets.lineTo((at + side * 5).dx, (at + side * 5).dy);
        bullets.lineTo(tail.dx, tail.dy);
        bullets.lineTo((at - side * 5).dx, (at - side * 5).dy);
        bullets.close();
        bulletCores.addOval(Rect.fromCircle(center: at, radius: 2));
      }
    } else if (shot.kind == LateShotKind.mine) {
      const black = Color(0xFF08090B), laserRed = Color(0xFFF13735);
      final stripes = Path();
      final direction = Offset(math.cos(.35), math.sin(.35));
      final normal = Offset(-direction.dy, direction.dx);
      for (final offset in [-24.0, -12.0, 0.0, 12.0, 24.0]) {
        final center = at + normal * offset;
        final half = math.sqrt(shot.radius * shot.radius - offset * offset) - 4;
        final a = center - direction * half, b = center + direction * half;
        stripes.moveTo(a.dx, a.dy);
        stripes.lineTo(b.dx, b.dy);
      }
      if (shot.age < 0) {
        final progress = (1 + shot.age / InfiniteBoss.mineWarning).clamp(
          0.0,
          1.0,
        );
        canvas.drawCircle(at, shot.radius, Paint()..color = black);
        canvas.drawPath(stripes, _outline(laserRed.withAlpha(65), 1));
        canvas.drawCircle(
          at,
          shot.radius,
          _outline(laserRed.withAlpha(95), 1.5),
        );
        canvas.drawArc(
          Rect.fromCircle(center: at, radius: shot.radius),
          -math.pi / 2,
          math.pi * 2 * progress,
          false,
          _outline(laserRed, 3),
        );
      } else if (shot.visible) {
        // The whole marked disk damages during the burst, including its center.
        canvas.drawCircle(at, shot.radius + 2, Paint()..color = black);
        canvas.drawCircle(at, shot.radius, _outline(laserRed, 2));
        canvas.drawPath(stripes, _outline(const Color(0xFF8C1519), 7));
        canvas.drawPath(stripes, _outline(laserRed, 3.5));
        canvas.drawPath(stripes, _outline(const Color(0xFFFFB7A2), .8));
      }
    } else if (storm && shot.visible && shot.kind == LateShotKind.ricochet) {
      canvas.drawCircle(at, 9, Paint()..color = ink);
      canvas.drawCircle(at, 6, Paint()..color = colossusShotViolet);
      canvas.drawCircle(at, 3, Paint()..color = colossusShotPink);
    } else if (storm && shot.visible && shot.kind == LateShotKind.moth) {
      final ahead = shot.positionAt(math.min(shot.age + .01, shot.life));
      final angle = math.atan2(ahead.y - at.dy, ahead.x - at.dx);
      final blade = Path();
      // Crescent blades are visibly different from the Warden's small bullets.
      for (var i = 0; i <= 10; i++) {
        final a = angle - math.pi * .7 + i * math.pi * 1.4 / 10;
        final p = at + Offset(math.cos(a), math.sin(a)) * 12;
        if (i == 0) {
          blade.moveTo(p.dx, p.dy);
        } else {
          blade.lineTo(p.dx, p.dy);
        }
      }
      final inner = at + Offset(math.cos(angle), math.sin(angle)) * 3;
      blade.quadraticBezierTo(
        inner.dx,
        inner.dy,
        at.dx + math.cos(angle - math.pi * .7) * 12,
        at.dy + math.sin(angle - math.pi * .7) * 12,
      );
      blade.close();
      canvas.drawPath(blade, _outline(ink, 4));
      canvas.drawPath(blade, Paint()..color = colossusShotViolet);
      canvas.drawPath(blade, _outline(colossusShotPink, 1.5));
    } else if (shot.kind == LateShotKind.laser && shot.ring != null) {
      final ring = shot.ring!;
      final center = _point(shot.origin);
      if (shot.age < 0) {
        // Charging: a tight pulsing ring at the core, and a dashed ray along
        // every opening so the player can move into line before it grows.
        final progress = (1 + shot.age / InfiniteBoss.laserWarning).clamp(
          0.0,
          1.0,
        );
        canvas.drawCircle(
          center,
          ring.startRadius + 4 * progress,
          _outline(hot.withAlpha((90 + 120 * progress).round()), 2),
        );
        final rays = Path();
        for (final (start, width) in ring.gaps) {
          final mid = start + width / 2;
          final direction = Offset(math.cos(mid), math.sin(mid));
          for (var d = ring.startRadius + 8; d < 520; d += 16) {
            final a = center + direction * d, b = center + direction * (d + 7);
            rays.moveTo(a.dx, a.dy);
            rays.lineTo(b.dx, b.dy);
          }
        }
        canvas.drawPath(rays, _outline(amber.withAlpha(170), 1.5));
      } else if (shot.visible) {
        final radius = ring.radiusAt(shot.age);
        final rect = Rect.fromCircle(center: center, radius: radius);
        // One path per layer, so more openings never mean more draws.
        final arcs = Path();
        for (final (start, sweep) in _ringArcs(ring, shot.age)) {
          arcs.addArc(rect, start, sweep);
        }
        canvas.drawPath(arcs, _outline(ink, 12));
        canvas.drawPath(arcs, _outline(hot, 8));
        canvas.drawPath(arcs, _outline(pale, 2.5));
      }
    } else if (shot.kind == LateShotKind.laser && shot.dashes != null) {
      final pattern = shot.dashes!;
      final beam = shot.beam;
      final start = _point(beam.start), end = _point(beam.end);
      final delta = end - start;
      final length = delta.distance;
      Offset along(double d) =>
          length < 1e-9 ? start : start + delta * (d / length);
      final segments = pattern.segments(length, math.max(0, shot.age));
      if (shot.age < 0) {
        // Outlined capsules show exactly where the dashes and gaps will be.
        for (final (a, b) in segments) {
          canvas.drawLine(along(a), along(b), _outline(hot.withAlpha(150), 7));
          canvas.drawLine(along(a), along(b), _outline(shell, 4));
        }
        final destination = _point(shot.beamAt(shot.life).start);
        canvas.drawLine(start, destination, _outline(amber.withAlpha(150), 1.5));
        canvas.drawCircle(destination, 4, _outline(amber, 1.5));
      } else if (shot.visible) {
        for (final (a, b) in segments) {
          canvas.drawLine(along(a), along(b), _outline(ink, 12));
          canvas.drawLine(along(a), along(b), _outline(hot, shot.radius * 2));
          canvas.drawLine(along(a), along(b), _outline(pale, 2.5));
        }
      }
    } else if (shot.kind == LateShotKind.laser) {
      final beam = shot.beam;
      final start = _point(beam.start), end = _point(beam.end);
      if (shot.age < 0) {
        final delta = end - start;
        final dashes = Path();
        for (var d = 0.0; d < delta.distance; d += 14) {
          final a = start + delta * (d / delta.distance);
          final b =
              start +
              delta * (math.min(d + 6, delta.distance) / delta.distance);
          dashes.moveTo(a.dx, a.dy);
          dashes.lineTo(b.dx, b.dy);
        }
        canvas.drawPath(dashes, _outline(hot, 2));
        canvas.drawCircle(end, 9, _outline(ink, 1.5));
        if (shot.beamPath != null) {
          final sweep = Path();
          for (final t in [0.0, shot.life / 2, shot.life]) {
            final preview = shot.beamAt(t);
            sweep.moveTo(preview.start.x, preview.start.y);
            sweep.lineTo(preview.end.x, preview.end.y);
          }
          canvas.drawPath(sweep, _outline(amber.withAlpha(90), 1));
          final destination = _point(shot.beamAt(shot.life).end);
          canvas.drawLine(
            end,
            destination,
            _outline(amber.withAlpha(170), 1.5),
          );
          canvas.drawCircle(destination, 4, _outline(amber, 1.5));
        }
      } else if (shot.visible) {
        canvas.drawLine(start, end, _outline(ink, 14));
        canvas.drawLine(start, end, _outline(hot, shot.radius * 2));
        canvas.drawLine(start, end, _outline(pale, 3));
      }
    } else if (shot.kind == LateShotKind.acid) {
      if (shot.age < 0) {
        final progress = (1 + shot.age / InfiniteBoss.throwFlight).clamp(
          0.0,
          1.0,
        );
        final circle = Rect.fromCircle(center: at, radius: shot.radius);
        canvas.drawCircle(
          at,
          shot.radius,
          Paint()..color = amber.withAlpha(45),
        );
        canvas.drawCircle(at, shot.radius, _outline(ink, 1.5));
        canvas.drawArc(
          circle,
          -math.pi / 2,
          math.pi * 2 * progress,
          false,
          _outline(hot, 3),
        );
        canvas.drawLine(
          at - const Offset(5, 0),
          at + const Offset(5, 0),
          _outline(hot, 2),
        );
        canvas.drawLine(
          at - const Offset(0, 5),
          at + const Offset(0, 5),
          _outline(hot, 2),
        );
      } else if (shot.visible) {
        canvas.drawCircle(at, shot.radius + 2, Paint()..color = shell);
        canvas.drawCircle(
          at,
          shot.radius,
          Paint()..color = amber.withAlpha(210),
        );
        canvas.drawCircle(at, shot.radius, _outline(hot, 2));
        canvas.drawCircle(
          at,
          shot.radius * .55,
          _outline(pale.withAlpha(150), 1.5),
        );
        for (final dx in [-10.0, 0.0, 10.0]) {
          canvas.drawLine(
            at + Offset(dx - 2, -5),
            at + Offset(dx + 2, 5),
            _outline(shell, 2),
          );
        }
      }
    } else if (shot.visible && shot.kind == LateShotKind.bomb) {
      canvas.drawCircle(at, 9, Paint()..color = shell);
      canvas.drawCircle(at, 6, Paint()..color = amber);
      canvas.drawCircle(at, 2, Paint()..color = pale);
    } else if (shot.visible) {
      final angle = math.atan2(shot.velocity.y, shot.velocity.x);
      final forward = Offset(math.cos(angle), math.sin(angle));
      final side = Offset(-forward.dy, forward.dx);
      final tip = at + forward * 7;
      final tail = at - forward * 5;
      bullets.moveTo(tip.dx, tip.dy);
      bullets.lineTo((tail + side * 4).dx, (tail + side * 4).dy);
      bullets.lineTo((tail - side * 4).dx, (tail - side * 4).dy);
      bullets.close();
      bulletCores.addOval(Rect.fromCircle(center: at, radius: 1.4));
    }
  }
  if (seraph) {
    canvas.drawPath(crystalTrails, _outline(hot.withAlpha(150), 5));
    canvas.drawPath(crystalTrails, _outline(pale, 1));
    canvas.drawPath(cometWarnings, _outline(hot, 2));
    canvas.drawPath(cometMarks, _outline(ink, 3));
    canvas.drawPath(cometMarks, _outline(amber, 1.5));
  }
  canvas.drawPath(bullets, _outline(ink, 4));
  canvas.drawPath(bullets, Paint()..color = amber);
  canvas.drawPath(bulletCores, Paint()..color = pale);
  if (venom) {
    // Dense volleys are batched, so bullet count does not multiply draw calls.
    canvas.drawPath(toxicWarnings, _outline(toxicMagenta.withAlpha(150), 1.5));
    canvas.drawPath(toxicBullets, _outline(ink, 4));
    canvas.drawPath(toxicBullets, Paint()..color = toxicLime);
    canvas.drawPath(toxicBullets, _outline(toxicMagenta, 1));
    canvas.drawPath(toxicCores, Paint()..color = toxicYellow);
  }

  canvas.save();
  canvas.translate(position.dx, position.dy);
  // The practice boss reads as a smaller, lesser version of the real one.
  if (boss.training) canvas.scale(.75);
  if (nova) {
    _paintNova(canvas, boss, reducedMotion, ink);
    canvas.restore();
    canvas.restore();
    return;
  }
  if (venom) {
    _paintVenom(canvas, boss, reducedMotion, ink);
    canvas.restore();
    canvas.restore();
    return;
  }
  if (prism) {
    _paintPrism(canvas, boss, reducedMotion, ink, amber, hot);
    canvas.restore();
    canvas.restore();
    return;
  }
  if (seraph) {
    _paintSeraph(canvas, boss, reducedMotion, ink);
    canvas.restore();
    canvas.restore();
    return;
  }
  if (storm) {
    _paintColossus(canvas, boss, reducedMotion, ink, amber, hot);
    canvas.restore();
    canvas.restore();
    return;
  }
  // A broad armored hornet silhouette, larger than ordinary rail visitors.
  final pulse = reducedMotion ? 0.0 : boss.recoil;
  final time = reducedMotion ? 0.0 : boss.age;
  canvas.rotate(math.sin(time * 2.8) * .035);
  final flap = math.sin(time * 12) * 8 + pulse * 5;
  final wingLines = Path();
  for (final side in [-1.0, 1.0]) {
    final wing = Path()
      ..moveTo(side * 26, -14)
      ..lineTo(side * 87, -34 - flap)
      ..lineTo(side * 75, 10 + flap)
      ..lineTo(side * 34, 17)
      ..close();
    canvas.drawPath(
      wing,
      Paint()
        ..shader = LinearGradient(
          colors: [
            pale.withAlpha(220),
            amber.withAlpha(180),
            hot.withAlpha(110),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTRB(-90, -45, 90, 30)),
    );
    canvas.drawPath(wing, _outline(ink, 2));
    wingLines.moveTo(side * 36, -6);
    wingLines.lineTo(side * 74, -22 - flap / 2);
    wingLines.moveTo(side * 39, 4);
    wingLines.lineTo(side * 67, -8);
    wingLines.moveTo(side * 20, -23);
    wingLines.lineTo(side * 30, -43);
    wingLines.lineTo(side * 38, -46);
  }
  canvas.drawPath(wingLines, _outline(ink, 2));
  final armor = Path()
    ..moveTo(0, -36)
    ..lineTo(34, -22)
    ..lineTo(40, 11)
    ..lineTo(24, 32)
    ..lineTo(0, 43)
    ..lineTo(-24, 32)
    ..lineTo(-40, 11)
    ..lineTo(-34, -22)
    ..close();
  canvas.drawPath(armor, _outline(ink, 5));
  canvas.drawPath(armor, Paint()..color = shell);
  canvas.drawPath(armor, _outline(amber, 2));
  final brow = Path()
    ..moveTo(-27, -14)
    ..lineTo(0, -23)
    ..lineTo(27, -14)
    ..lineTo(19, 4)
    ..lineTo(-19, 4)
    ..close();
  canvas.drawPath(brow, Paint()..color = amber);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTRB(-21, -9, 21, 1),
      const Radius.circular(5),
    ),
    Paint()..color = shell,
  );
  final eyeColor = boss.phase == BossPhase.lasers ? hot : pale;
  canvas.drawCircle(const Offset(-11, -4), 3, Paint()..color = eyeColor);
  canvas.drawCircle(const Offset(11, -4), 3, Paint()..color = eyeColor);
  canvas.drawCircle(const Offset(0, 18), 10, _outline(amber, 2));
  canvas.drawCircle(const Offset(0, 18), 4, Paint()..color = eyeColor);
  final energy = Path(), sparks = Path();
  for (final side in [-1.0, 1.0]) {
    final lift = math.sin(time * 5 + side) * 4;
    energy.moveTo(side * 32, 13);
    energy.quadraticBezierTo(side * 56, 38 + lift, side * 75, 26 + lift);
    final p = Offset(side * 76, 26 + lift);
    sparks.addOval(Rect.fromCircle(center: p, radius: 2 + pulse));
  }
  canvas.drawPath(energy, _outline(amber.withAlpha(130), 2));
  canvas.drawPath(sparks, Paint()..color = pale);
  canvas.drawArc(
    Rect.fromCircle(center: const Offset(0, 18), radius: 14 + boss.charge * 4),
    time * 3,
    math.pi * (1 + boss.charge),
    false,
    _outline(hot, 2),
  );
  if (!reducedMotion && pulse > 0) {
    canvas.drawCircle(
      const Offset(0, 18),
      9 + (1 - pulse) * 14,
      _outline(pale.withAlpha((pulse * 220).round()), 2),
    );
  }
  canvas.restore();
  canvas.restore();
}

void _paintColossus(
  Canvas canvas,
  InfiniteBoss boss,
  bool reducedMotion,
  Color ink,
  Color cyan,
  Color violet,
) {
  const shell = Color(0xFF243638), pale = Color(0xFFE9FBFF);
  final tilt = reducedMotion ? 0.0 : math.sin(boss.age * 4) * .05;
  final time = reducedMotion ? 0.0 : boss.age;
  final recoil = reducedMotion ? 0.0 : boss.recoil;
  canvas.rotate(tilt);
  final cables = Path();
  final turbines = Path(), turbineCores = Path(), jets = Path();
  for (final side in [-1.0, 1.0]) {
    // Heavy floating gauntlets and circular turbines replace the hornet wings.
    final fistY = 9 + math.sin(time * 3.4 + side) * 5 - recoil * 8;
    final fistX = side * (65 + math.sin(time * 2.1) * 3);
    final fist = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(fistX, fistY), width: 42, height: 45),
      const Radius.circular(10),
    );
    canvas.drawRRect(fist, Paint()..color = shell);
    canvas.drawRRect(fist, _outline(ink, 4));
    canvas.drawRRect(fist, _outline(cyan, 1.5));
    canvas.drawCircle(Offset(fistX, fistY), 12, _outline(violet, 3));
    canvas.drawCircle(
      Offset(fistX, fistY),
      5 + boss.charge * 2,
      Paint()..color = pale,
    );
    for (var i = 0; i < 3; i++) {
      final a = time * side * 3 + i * math.pi * 2 / 3;
      final center = Offset(fistX, fistY);
      final p = center + Offset(math.cos(a), math.sin(a)) * 9;
      final q = center + Offset(math.cos(a + .65), math.sin(a + .65)) * 16;
      turbines.moveTo(p.dx, p.dy);
      turbines.lineTo(q.dx, q.dy);
    }
    jets.moveTo(fistX - 6, fistY + 24);
    jets.lineTo(fistX, fistY + 33 + math.sin(time * 10) * 3 + boss.charge * 6);
    jets.lineTo(fistX + 6, fistY + 24);
    jets.close();
    turbineCores.addOval(
      Rect.fromCircle(center: Offset(fistX, fistY), radius: 2),
    );
    cables.moveTo(side * 35, -10);
    cables.lineTo(side * 57, -27);
    cables.lineTo(side * 79, -19);
    cables.moveTo(side * 24, 28);
    cables.lineTo(side * 47, 36);
  }
  canvas.drawPath(cables, _outline(cyan, 3));
  canvas.drawPath(turbines, _outline(cyan, 2));
  canvas.drawPath(jets, Paint()..color = violet.withAlpha(160));
  canvas.drawPath(turbineCores, Paint()..color = pale);
  final body = Path()
    ..moveTo(-23, -43)
    ..lineTo(23, -43)
    ..lineTo(40, -20)
    ..lineTo(32, 31)
    ..lineTo(0, 47)
    ..lineTo(-32, 31)
    ..lineTo(-40, -20)
    ..close();
  canvas.drawPath(body, _outline(ink, 5));
  canvas.drawPath(body, Paint()..color = shell);
  canvas.drawPath(body, _outline(cyan, 2));
  canvas.drawCircle(const Offset(0, 7), 25, _outline(violet, 3));
  canvas.drawCircle(const Offset(0, 7), 19, _outline(cyan, 2));
  canvas.drawCircle(
    const Offset(0, 7),
    10 + boss.charge * 3,
    Paint()
      ..shader = RadialGradient(
        colors: [pale, cyan, violet],
      ).createShader(const Rect.fromLTRB(-14, -7, 14, 21)),
  );
  canvas.drawCircle(const Offset(0, 7), 4, Paint()..color = pale);
  final visor = Path()
    ..moveTo(-25, -23)
    ..lineTo(25, -23)
    ..lineTo(17, -11)
    ..lineTo(-17, -11)
    ..close();
  canvas.drawPath(visor, Paint()..color = violet);
  canvas.drawLine(
    const Offset(-14, -19),
    const Offset(14, -19),
    _outline(pale, 2),
  );
  final vents = Path();
  for (final side in [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      vents.moveTo(side * (17 + i * 5), 29.0 - i * 2);
      vents.lineTo(side * (17 + i * 5), 36.0 - i * 2);
    }
  }
  canvas.drawPath(vents, _outline(cyan, 1.5));
  canvas.drawArc(
    Rect.fromCircle(center: const Offset(0, 7), radius: 22),
    -time * 2.2,
    math.pi * 1.1,
    false,
    _outline(pale, 1.5),
  );
  if (!reducedMotion && recoil > 0) {
    canvas.drawCircle(
      const Offset(0, 7),
      26 + (1 - recoil) * 12,
      _outline(violet.withAlpha((recoil * 200).round()), 2),
    );
  }
}

void _paintVenom(
  Canvas canvas,
  InfiniteBoss boss,
  bool reducedMotion,
  Color ink,
) {
  const carapace = Color(0xFF293018), purple = Color(0xFF51224F);
  final time = reducedMotion ? 0.0 : boss.age;
  final pulse = reducedMotion ? 0.0 : boss.recoil;
  final crown = Path();
  for (final side in [-1.0, 1.0]) {
    crown.moveTo(side * 15, -20);
    crown.lineTo(side * 23, -54);
    crown.lineTo(side * 35, -26);
    crown.lineTo(side * 57, -41);
    crown.lineTo(side * 46, -3);
    crown.lineTo(side * 24, 7);
    crown.close();
  }
  canvas.drawPath(crown, _outline(ink, 6));
  canvas.drawPath(crown, Paint()..color = purple);
  canvas.drawPath(crown, _outline(toxicLime, 2));
  final body = Path()
    ..moveTo(0, -36)
    ..lineTo(30, -16)
    ..lineTo(33, 14)
    ..lineTo(20, 34)
    ..lineTo(0, 45)
    ..lineTo(-20, 34)
    ..lineTo(-33, 14)
    ..lineTo(-30, -16)
    ..close();
  canvas.drawPath(body, _outline(ink, 5));
  canvas.drawPath(body, Paint()..color = carapace);
  canvas.drawPath(body, _outline(toxicLime, 2));
  final eyes = Path(), vents = Path();
  for (final side in [-1.0, 1.0]) {
    eyes.addOval(
      Rect.fromCenter(center: Offset(side * 14, -12), width: 14, height: 7),
    );
    final center = Offset(side * 35, 16 + math.sin(time * 2) * 2 - pulse * 3);
    canvas.drawCircle(center, 12, Paint()..color = purple);
    canvas.drawCircle(center, 12, _outline(toxicMagenta, 2));
    for (var i = 0; i < 3; i++) {
      vents.moveTo(center.dx - 5 + i * 5, center.dy - 5);
      vents.lineTo(center.dx - 5 + i * 5, center.dy + 5);
    }
  }
  canvas.drawPath(eyes, Paint()..color = toxicYellow);
  canvas.drawPath(vents, _outline(toxicLime, 1.5));
  canvas.drawCircle(const Offset(0, 11), 13, _outline(toxicMagenta, 2));
  final emblem = Path();
  for (var i = 0; i < 3; i++) {
    final angle = time * .5 + i * math.pi * 2 / 3;
    final center =
        Offset(math.cos(angle), math.sin(angle)) * 7 + const Offset(0, 11);
    emblem.addOval(Rect.fromCircle(center: center, radius: 4 + boss.charge));
  }
  canvas.drawPath(emblem, _outline(toxicLime, 2));
  canvas.drawCircle(const Offset(0, 11), 3, Paint()..color = toxicYellow);
  canvas.drawLine(
    const Offset(-9, 31),
    const Offset(9, 31),
    _outline(toxicLime, 2),
  );
}

/// A pulsar: a white-hot core inside two tilted orbit rings that spin
/// opposite ways, with emitter nodes that flare while an attack charges.
void _paintNova(Canvas canvas, InfiniteBoss boss, bool reducedMotion, Color ink) {
  const shell = Color(0xFF151A3A), pale = Color(0xFFF4FBFF);
  final time = reducedMotion ? 0.0 : boss.age;
  final charge = boss.charge, recoil = reducedMotion ? 0.0 : boss.recoil;
  canvas.drawCircle(
    const Offset(0, InfiniteBoss.novaCoreOffset),
    44 + recoil * 6,
    Paint()..color = novaViolet.withAlpha((30 + 50 * charge).round()),
  );
  for (final (tilt, speed) in [(.55, 1.0), (-.55, -1.3)]) {
    canvas.save();
    canvas.translate(0, InfiniteBoss.novaCoreOffset);
    canvas.rotate(tilt + time * .25 * speed);
    final orbit = Rect.fromCenter(center: Offset.zero, width: 92, height: 34);
    canvas.drawOval(orbit, _outline(ink, 6));
    canvas.drawOval(orbit, _outline(speed > 0 ? novaCyan : novaViolet, 2.5));
    final node = Offset(
      math.cos(time * 2.2 * speed) * 46,
      math.sin(time * 2.2 * speed) * 17,
    );
    canvas.drawCircle(node, 5.5, Paint()..color = shell);
    canvas.drawCircle(node, 3 + charge * 2, Paint()..color = novaCyan);
    canvas.restore();
  }
  final body = Path();
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4 + math.pi / 8;
    final r = i.isEven ? 30.0 : 24.0;
    final p = Offset(math.cos(a) * r, math.sin(a) * r + InfiniteBoss.novaCoreOffset);
    if (i == 0) {
      body.moveTo(p.dx, p.dy);
    } else {
      body.lineTo(p.dx, p.dy);
    }
  }
  body.close();
  canvas.drawPath(body, _outline(ink, 5));
  canvas.drawPath(body, Paint()..color = shell);
  canvas.drawPath(body, _outline(novaViolet, 2));
  canvas.drawCircle(
    const Offset(0, InfiniteBoss.novaCoreOffset),
    15 + charge * 4,
    Paint()
      ..shader = const RadialGradient(
        colors: [pale, novaCyan, novaViolet],
        stops: [0, .45, 1],
      ).createShader(
        Rect.fromCircle(
          center: const Offset(0, InfiniteBoss.novaCoreOffset),
          radius: 19,
        ),
      ),
  );
  canvas.drawCircle(
    const Offset(0, InfiniteBoss.novaCoreOffset),
    5,
    Paint()..color = pale,
  );
}

void _paintPrism(
  Canvas canvas,
  InfiniteBoss boss,
  bool reducedMotion,
  Color ink,
  Color mint,
  Color pink,
) {
  const shell = Color(0xFF202C40), pale = Color(0xFFF5FFF5);
  final time = reducedMotion ? 0.0 : boss.age;
  final ring = Path();
  for (var i = 0; i < 6; i++) {
    final angle = i * math.pi / 3 + time * .7;
    final p = Offset(math.cos(angle), math.sin(angle)) * 39;
    if (i == 0) {
      ring.moveTo(p.dx, p.dy);
    } else {
      ring.lineTo(p.dx, p.dy);
    }
  }
  ring.close();
  canvas.drawPath(ring, _outline(ink, 6));
  canvas.drawPath(ring, _outline(mint, 2));
  final body = Path()
    ..moveTo(0, -32)
    ..lineTo(24, -10)
    ..lineTo(19, 25)
    ..lineTo(0, 38)
    ..lineTo(-19, 25)
    ..lineTo(-24, -10)
    ..close();
  canvas.drawPath(body, _outline(ink, 5));
  canvas.drawPath(body, Paint()..color = shell);
  canvas.drawPath(body, _outline(pink, 2));
  final arms = Path();
  for (final side in [-1.0, 1.0]) {
    arms.moveTo(side * 22, -2);
    arms.lineTo(side * 48, 12);
    arms.lineTo(side * 18, 26);
    canvas.drawCircle(Offset(side * 18, 26), 7, Paint()..color = shell);
    canvas.drawCircle(
      Offset(side * 18, 26),
      4 + boss.charge * 2,
      Paint()..color = mint,
    );
  }
  canvas.drawPath(arms, _outline(ink, 6));
  canvas.drawPath(arms, _outline(pink, 2));
  canvas.drawCircle(const Offset(0, 4), 14, _outline(mint, 2));
  canvas.drawCircle(
    const Offset(0, 4),
    7 + boss.charge * 4,
    Paint()..color = pink,
  );
  canvas.drawCircle(const Offset(0, 4), 3, Paint()..color = pale);
  canvas.drawCircle(const Offset(0, 26), 4, Paint()..color = mint);
  canvas.drawLine(
    const Offset(-8, -17),
    const Offset(8, -17),
    _outline(pale, 2),
  );
}

void _paintSeraph(
  Canvas canvas,
  InfiniteBoss boss,
  bool reducedMotion,
  Color ink,
) {
  const gold = Color(0xFFFFCF79), rose = Color(0xFFF66C9E);
  const pearl = Color(0xFFFFF4DF), plum = Color(0xFF38213E);
  final time = reducedMotion ? 0.0 : boss.age;
  final recoil = reducedMotion ? 0.0 : boss.recoil;
  final unfold = reducedMotion
      ? 1.0
      : Curves.easeOutCubic.transform((boss.age / 2).clamp(0.0, 1.0));
  canvas.rotate(math.sin(time * 2) * .045);
  // Three layered feathers on each side open during the entrance. Their
  // outlines and facets stay crisp without expensive blur passes.
  final facets = Path(), filigree = Path(), gems = Path();
  for (final side in [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      final beat = math.sin(time * 3.2 - i * .65) * (6 - i) + recoil * 5;
      final root = Offset(side * 19, -12.0 + i * 15);
      final tip = Offset(
        side * (48 + unfold * (48 - i * 10)),
        -46.0 + i * 35 + beat,
      );
      final feather = Path()
        ..moveTo(root.dx, root.dy)
        ..cubicTo(
          side * 42,
          root.dy - 30,
          tip.dx - side * 22,
          tip.dy - 25,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          tip.dx - side * 7,
          tip.dy + 30,
          root.dx,
          root.dy + 18,
        )
        ..close();
      canvas.drawPath(
        feather,
        Paint()
          ..shader =
              LinearGradient(
                colors: i.isEven ? [pearl, gold, rose] : [pearl, rose, plum],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(
                Rect.fromPoints(
                  root - const Offset(15, 30),
                  tip + const Offset(15, 30),
                ),
              ),
      );
      canvas.drawPath(feather, _outline(ink, 1.5));
      facets.moveTo(root.dx, root.dy + 7);
      facets.quadraticBezierTo(
        side * 52,
        root.dy - 5,
        tip.dx - side * 5,
        tip.dy,
      );
    }
    final sway = math.sin(time * 2.5 + side) * 9;
    filigree.moveTo(side * 18, 24);
    filigree.cubicTo(side * 53, 35, side * 15 + sway, 67, side * 42 + sway, 78);
    gems.addOval(
      Rect.fromCenter(
        center: Offset(side * 42 + sway, 78),
        width: 5,
        height: 9,
      ),
    );
  }
  canvas.drawPath(facets, _outline(pearl.withAlpha(190), 1));
  canvas.drawPath(filigree, _outline(gold, 2));
  canvas.drawPath(gems, Paint()..color = rose);

  final halo = Path(), haloGems = Path();
  for (var i = 0; i < 6; i++) {
    final angle = time * .45 + i * math.pi / 3;
    final radius = 49 + boss.charge * 5;
    halo.addArc(
      Rect.fromCircle(center: const Offset(0, -7), radius: radius),
      angle,
      .64,
    );
    final p =
        const Offset(0, -7) +
        Offset(math.cos(angle + .84), math.sin(angle + .84)) * radius;
    haloGems.moveTo(p.dx, p.dy - 4);
    haloGems.lineTo(p.dx + 3, p.dy);
    haloGems.lineTo(p.dx, p.dy + 4);
    haloGems.lineTo(p.dx - 3, p.dy);
    haloGems.close();
  }
  canvas.drawPath(halo, _outline(plum, 5));
  canvas.drawPath(halo, _outline(gold, 2));
  canvas.drawPath(haloGems, Paint()..color = pearl);

  final armor = Path()
    ..moveTo(0, -42)
    ..lineTo(23, -22)
    ..lineTo(28, 9)
    ..lineTo(17, 35)
    ..lineTo(0, 54)
    ..lineTo(-17, 35)
    ..lineTo(-28, 9)
    ..lineTo(-23, -22)
    ..close();
  canvas.drawPath(armor, _outline(ink, 5));
  canvas.drawPath(
    armor,
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF684369), plum, Color(0xFF1D2539)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(const Rect.fromLTRB(-28, -42, 28, 54)),
  );
  canvas.drawPath(armor, _outline(gold, 1.5));
  final crown = Path()
    ..moveTo(-20, -21)
    ..lineTo(-29, -50)
    ..lineTo(-10, -36)
    ..lineTo(0, -60)
    ..lineTo(10, -36)
    ..lineTo(29, -50)
    ..lineTo(20, -21)
    ..lineTo(0, -29)
    ..close();
  canvas.drawPath(crown, _outline(plum, 4));
  canvas.drawPath(crown, Paint()..color = gold);
  final eyes = Path()
    ..moveTo(-17, -15)
    ..lineTo(-7, -10)
    ..moveTo(17, -15)
    ..lineTo(7, -10);
  canvas.drawPath(eyes, _outline(pearl, 2.5));
  final heart = Rect.fromCircle(
    center: const Offset(0, 12),
    radius: 17 + boss.charge * 3 + math.sin(time * 4) * 1.2,
  );
  canvas.drawOval(
    heart,
    Paint()
      ..shader = const RadialGradient(
        colors: [pearl, gold, rose, plum],
        stops: [0, .25, .65, 1],
      ).createShader(heart),
  );
  canvas.drawOval(heart, _outline(gold, 1.5));
  final core = Path()
    ..moveTo(0, 0)
    ..lineTo(7, 12)
    ..lineTo(0, 27)
    ..lineTo(-7, 12)
    ..close();
  canvas.drawPath(core, Paint()..color = pearl);
  canvas.drawLine(const Offset(0, 32), const Offset(0, 45), _outline(rose, 2));
  if (!reducedMotion && recoil > 0) {
    canvas.drawCircle(
      const Offset(0, 12),
      19 + (1 - recoil) * 20,
      _outline(gold.withAlpha((recoil * 220).round()), 2),
    );
  }
}
