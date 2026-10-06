import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game.dart';
import 'infinite_painter.dart';
import 'late_enemies.dart';

Color _enemyAccent(LateEnemyKind kind, bool light) => switch (kind) {
  LateEnemyKind.beetle =>
    light ? const Color(0xFFBDFA6A) : const Color(0xFF436F08),
  LateEnemyKind.cricket =>
    light ? const Color(0xFFFFD080) : const Color(0xFF97520C),
  LateEnemyKind.moth =>
    light ? const Color(0xFFE7BBFF) : const Color(0xFF7931A3),
  LateEnemyKind.scorpion =>
    light ? const Color(0xFFFFAD8B) : const Color(0xFFA53417),
  LateEnemyKind.seedSpitter =>
    light ? const Color(0xFF79E8CB) : const Color(0xFF076D58),
};

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Offset _offset(EnemyPoint p) => Offset(p.x, p.y);

/// Dotted aim paths share the simulation's actual geometry. No blur, filters,
/// textures, or unbounded particle lists; reduced motion retains all warnings.
void paintLateEnemy(Canvas canvas, BalanceGame game, bool reducedMotion) {
  final enemy = game.lateEnemy;
  if (!game.infinite || enemy == null) return;
  final ink = infiniteBoardInk(game, _offset(enemy.origin));
  final accent = _enemyAccent(enemy.kind, ink == Colors.white);
  final origin = _offset(enemy.origin), target = _offset(enemy.target);
  canvas.save();
  canvas.clipRect(Rect.fromLTRB(24, game.visibleTop + 42, 336, 537));

  void dottedPath(LateEnemyShot shot, double from, double until, Color color) {
    final path = Path();
    for (var t = from; t < until; t += .075) {
      final a = _offset(shot.positionAt(t));
      final b = _offset(shot.positionAt(math.min(t + .03, until)));
      path.moveTo(a.dx, a.dy);
      path.lineTo(b.dx, b.dy);
    }
    canvas.drawPath(path, _stroke(color, 1.25));
  }

  if (enemy.warning) {
    switch (enemy.kind) {
      case LateEnemyKind.beetle:
        dottedPath(enemy.shots.first, 0, .95, accent.withAlpha(120));
      case LateEnemyKind.cricket:
        final shot = enemy.shots.first;
        dottedPath(shot, 0, shot.life, accent.withAlpha(160));
        final bounce = _offset(shot.positionAt(shot.bounceTime));
        canvas.drawCircle(bounce, 9, _stroke(ink, 1.5));
        canvas.drawCircle(bounce, 3, Paint()..color = accent);
      case LateEnemyKind.moth:
        for (final shot in enemy.shots.take(2)) {
          dottedPath(shot, 0, shot.life, accent.withAlpha(135));
        }
      case LateEnemyKind.scorpion:
        dottedPath(enemy.shots.first, 0, 2.4, accent.withAlpha(155));
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(
            origin + Offset((i - 1) * 7, 32),
            2,
            Paint()..color = accent,
          );
        }
      case LateEnemyKind.seedSpitter:
        dottedPath(enemy.shots.first, 0, .9, accent.withAlpha(140));
        for (final shot in enemy.shots.skip(1)) {
          dottedPath(shot, 0, .8, accent.withAlpha(140));
        }
    }
  }

  // The landing ring remains visible throughout the lob, with a filling arc
  // instead of flashing. The actual acid then travels with the scrolling floor.
  if (enemy.kind == LateEnemyKind.beetle && enemy.shots[1].age < 0) {
    final progress = (enemy.age / enemy.shots[1].delay).clamp(0.0, 1.0);
    canvas.drawCircle(target, 22, Paint()..color = accent.withAlpha(25));
    canvas.drawCircle(target, 25, _stroke(ink.withAlpha(160), 1));
    canvas.drawArc(
      Rect.fromCircle(center: target, radius: 25),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      _stroke(accent, 2.5),
    );
    for (final side in [-1.0, 1.0]) {
      canvas.drawLine(
        target + Offset(side * 29, 0),
        target + Offset(side * 34, 0),
        _stroke(ink, 1.5),
      );
      canvas.drawLine(
        target + Offset(0, side * 29),
        target + Offset(0, side * 34),
        _stroke(ink, 1.5),
      );
    }
  }

  if (enemy.kind == LateEnemyKind.seedSpitter &&
      !enemy.shots.first.consumed &&
      enemy.shots.first.age < .9) {
    final split = _offset(enemy.shots.first.positionAt(.9));
    canvas.drawCircle(split, 12, _stroke(accent.withAlpha(190), 1.5));
    for (final shot in enemy.shots.skip(1)) {
      final end = _offset(shot.positionAt(.22));
      canvas.drawLine(split, end, _stroke(accent.withAlpha(190), 1.5));
    }
  }

  for (final shot in enemy.shots) {
    if (!shot.visible) continue;
    final p = _offset(shot.position);
    if (p.dx < 12 || p.dx > 348 || p.dy < game.visibleTop - 30 || p.dy > 575)
      continue;
    final shotInk = infiniteBoardInk(game, p);
    final color = _enemyAccent(enemy.kind, shotInk == Colors.white);
    final backing = shotInk == Colors.white
        ? const Color(0xFF172026)
        : Colors.white;
    if (shot.kind == LateShotKind.acid) {
      final fade = ((shot.life - shot.age) / .4).clamp(0.0, 1.0);
      final path = Path();
      for (var i = 0; i <= 32; i++) {
        final a = i * math.pi / 16;
        final radius = shot.radius + 1.5 * math.sin(a * 5);
        final point = p + Offset(math.cos(a), math.sin(a)) * radius;
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: .32 * fade),
      );
      canvas.drawPath(path, _stroke(shotInk.withValues(alpha: fade), 1.5));
      for (var i = 0; i < 3; i++) {
        final phase = reducedMotion ? 0.0 : math.sin(shot.age * 3 + i);
        canvas.drawCircle(
          p + Offset(-10 + i * 9.0, (i.isEven ? -4 : 6) + phase),
          2.5,
          _stroke(color.withValues(alpha: fade), 1.2),
        );
      }
      continue;
    }
    canvas.save();
    canvas.translate(p.dx, p.dy);
    final ahead = shot.positionAt(math.min(shot.age + .01, shot.life));
    canvas.rotate(math.atan2(ahead.y - p.dy, ahead.x - p.dx));
    if (shot.kind == LateShotKind.needle || shot.kind == LateShotKind.shard) {
      final shape = Path()
        ..moveTo(8, 0)
        ..lineTo(-5, -2.8)
        ..lineTo(-3, 0)
        ..lineTo(-5, 2.8)
        ..close();
      canvas.drawPath(shape, _stroke(backing, 3));
      canvas.drawPath(shape, Paint()..color = color);
      canvas.drawPath(shape, _stroke(shotInk, .8));
    } else if (shot.kind == LateShotKind.moth) {
      final diamond = Path()
        ..moveTo(6, 0)
        ..lineTo(0, -4)
        ..lineTo(-6, 0)
        ..lineTo(0, 4)
        ..close();
      canvas.drawPath(diamond, _stroke(backing, 3));
      canvas.drawPath(diamond, Paint()..color = color);
      canvas.drawPath(diamond, _stroke(shotInk, 1));
      canvas.drawCircle(Offset.zero, 1.2, Paint()..color = shotInk);
    } else {
      final radius = shot.kind == LateShotKind.bomb ? 6.0 : shot.radius;
      canvas.drawCircle(Offset.zero, radius + 2, Paint()..color = backing);
      canvas.drawCircle(Offset.zero, radius, Paint()..color = color);
      canvas.drawCircle(Offset.zero, radius, _stroke(shotInk, 1.1));
      canvas.drawCircle(
        const Offset(-1.5, -1.5),
        1.3,
        Paint()..color = Colors.white,
      );
      if (shot.kind == LateShotKind.seed && shot.age > .6) {
        final radius = 7 + (shot.age - .6) * 18;
        canvas.drawCircle(Offset.zero, radius, _stroke(color, 1.2));
      }
    }
    canvas.restore();
  }
  canvas.restore();

  // Pose is derived from the encounter clock: no extra tickers, particles,
  // simulation objects, blur, or offscreen layers. Motion stays near the fixed
  // perch; all aim, warnings, projectile paths, and collision geometry stay put.
  canvas.save();
  canvas.translate(origin.dx, origin.dy);
  canvas.scale(.7 + .3 * enemy.presence);
  const dark = Color(0xFF20282A);
  final shell = switch (enemy.kind) {
    LateEnemyKind.beetle => const Color(0xFF688B24),
    LateEnemyKind.cricket => const Color(0xFFC08A3B),
    LateEnemyKind.moth => const Color(0xFFAB79CA),
    LateEnemyKind.scorpion => const Color(0xFFAD5638),
    LateEnemyKind.seedSpitter => const Color(0xFF439777),
  };
  final contrast = ink == Colors.white ? Colors.black : Colors.white;
  canvas.drawCircle(Offset.zero, 23, Paint()..color = contrast.withAlpha(135));
  if (enemy.warning) {
    canvas.drawArc(
      const Rect.fromLTWH(-27, -27, 54, 54),
      -math.pi / 2,
      math.pi * 2 * enemy.warningProgress,
      false,
      _stroke(accent, 2),
    );
  }
  // Reuse paints throughout this single visitor instead of allocating a paint
  // per leg, wing marking, or shell detail.
  final fill = Paint();
  final keyline = _stroke(ink, 2.6);
  final detail = _stroke(dark, 1);
  final limbOutline = _stroke(ink, 1);
  final limbFill = _stroke(shell, 1);
  void outlined(Path p, Color color) {
    canvas.drawPath(p, keyline);
    canvas.drawPath(p, fill..color = color);
    canvas.drawPath(p, detail);
  }

  void oval(Rect r, Color color) => outlined(Path()..addOval(r), color);
  void limb(List<Offset> points, double width, Color color) {
    final p = Path()..addPolygon(points, false);
    canvas.drawPath(p, limbOutline..strokeWidth = width + 1.8);
    canvas.drawPath(
      p,
      limbFill
        ..color = color
        ..strokeWidth = width,
    );
  }

  void legs(Path path, double width, Color color) {
    canvas.drawPath(path, limbOutline..strokeWidth = width + 1.8);
    canvas.drawPath(
      path,
      limbFill
        ..color = color
        ..strokeWidth = width,
    );
  }

  final time = enemy.age;
  final motion = reducedMotion ? 0.0 : 1.0;
  final breathe = math.sin(time * 3.4) * motion;
  final sway = math.sin(time * 5.2) * motion;
  final charge = enemy.warning ? enemy.warningProgress * motion : 0.0;
  // One short recoil per actual shot, including the scorpion's staggered burst.
  var recoil = 0.0;
  if (!reducedMotion) {
    for (final shot in enemy.shots) {
      if (shot.kind == LateShotKind.acid || shot.parent != null) continue;
      final since = time - shot.delay;
      if (since >= 0 && since < .32) {
        recoil = math.max(recoil, math.sin(since / .32 * math.pi));
      }
    }
  }
  final facing =
      (math.atan2(target.dy - origin.dy, target.dx - origin.dx) - math.pi / 2)
          .clamp(-.7, .7);
  canvas.rotate(facing * .35 + sway * .025);
  canvas.translate(0, -recoil * 2 + breathe * .7);

  switch (enemy.kind) {
    case LateEnemyKind.beetle:
      final feet = Path();
      for (final side in [-1.0, 1.0]) {
        for (var i = 0; i < 3; i++) {
          final stride = math.sin(time * 10 + i * 2.1 + side * 1.6) * motion;
          feet.moveTo(side * 8, -6 + i * 7.0);
          feet.lineTo(side * (17 + stride), -9 + i * 9.0 + stride * 2);
          feet.lineTo(side * (21 - stride), -4 + i * 8.0 + stride * 3);
        }
        limb(
          [
            Offset(side * 4, 15),
            Offset(side * (10 + sway), 23),
            Offset(side * (15 + sway * 2), 22 + breathe),
          ],
          1,
          dark,
        );
      }
      legs(feet, 2, dark);
      canvas.scale(1 + breathe * .025, 1 + charge * .04 - recoil * .05);
      oval(const Rect.fromLTWH(-12, -13, 24, 30), shell);
      oval(const Rect.fromLTWH(-8, 8, 16, 12), dark);
      for (final side in [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(side * charge * 1.5, 0);
        canvas.rotate(side * (.04 * breathe + .06 * charge));
        oval(
          Rect.fromCenter(center: Offset(side * 6, -2), width: 9, height: 23),
          enemy.warning ? accent : const Color(0xFF9DC445),
        );
        canvas.drawArc(
          Rect.fromLTWH(side * 6 - 3, -10, 6, 14),
          -2.4,
          1.8,
          false,
          _stroke(Colors.white.withAlpha(170), 1.2),
        );
        canvas.restore();
      }
    case LateEnemyKind.cricket:
      final crouch = charge * 2.5 - recoil * 3;
      final feet = Path();
      for (final side in [-1.0, 1.0]) {
        final flex = sway * side + charge * 2 - recoil * 4;
        feet.moveTo(side * 7, 3);
        feet.lineTo(side * (20 - flex), -16 + crouch);
        feet.lineTo(side * (24 + flex), 14);
        feet.lineTo(side * (15 + flex), 19 - recoil * 2);
        limb(
          [
            Offset(side * 5, 12),
            Offset(side * 11, 24 + sway * side),
            Offset(side * 16, 26 + sway * side),
          ],
          1.2,
          dark,
        );
        limb(
          [
            Offset(side * 4, -11),
            Offset(side * (9 + sway), -24),
            Offset(side * (16 + sway * 3), -29 + breathe),
          ],
          1,
          shell,
        );
      }
      legs(feet, 3, shell);
      canvas.translate(0, crouch * .45);
      oval(const Rect.fromLTWH(-7, -15, 14, 32), shell);
      canvas.drawLine(
        const Offset(0, -9),
        const Offset(0, 12),
        _stroke(dark, 1),
      );
      canvas.drawArc(
        const Rect.fromLTWH(-5, -12, 10, 24),
        -2.4,
        1.7,
        false,
        _stroke(const Color(0xFFF2DCA3), 1.5),
      );
      oval(const Rect.fromLTWH(-8, 5, 16, 12), const Color(0xFFDEBA72));
    case LateEnemyKind.moth:
      final flutter = reducedMotion ? 1.0 : .72 + .28 * math.cos(time * 14);
      canvas.translate(0, math.sin(time * 4.2) * 2.5 * motion);
      for (final side in [-1.0, 1.0]) {
        canvas.save();
        canvas.scale(flutter, 1);
        canvas.rotate(side * sway * .035);
        final wing = Path()
          ..moveTo(0, -6)
          ..cubicTo(side * 34, -33, side * 35, 6, side * 12, 9)
          ..cubicTo(side * 28, 22, side * 4, 27, 0, 10)
          ..close();
        outlined(wing, shell);
        final veins = Path()
          ..moveTo(side * 3, -5)
          ..quadraticBezierTo(side * 12, -18, side * 25, -16)
          ..moveTo(side * 3, 7)
          ..quadraticBezierTo(side * 12, 12, side * 17, 17);
        canvas.drawPath(veins, _stroke(const Color(0xFFDEC3EB), 1.3));
        oval(Rect.fromCircle(center: Offset(side * 16, -3), radius: 5), dark);
        canvas.drawCircle(Offset(side * 16, -3), 2.3, Paint()..color = accent);
        canvas.restore();
        limb([Offset(side * 2, -10), Offset(side * (8 + sway), -21)], 1, shell);
      }
      oval(const Rect.fromLTWH(-4, -13, 8, 32), const Color(0xFFE8CEEF));
    case LateEnemyKind.scorpion:
      final feet = Path();
      for (final side in [-1.0, 1.0]) {
        for (var i = 0; i < 3; i++) {
          final stride = math.sin(time * 8 + i * 2 + side * 1.6) * motion;
          feet.moveTo(side * 6, -4 + i * 5.0);
          feet.lineTo(side * 15, -8 + i * 8.0 + stride * 1.5);
          feet.lineTo(side * (19 + stride), -5 + i * 8.0 + stride * 2);
        }
        canvas.save();
        canvas.rotate(side * (.06 * sway + .12 * charge - .16 * recoil));
        limb(
          [Offset(side * 6, 5), Offset(side * 19, 13), Offset(side * 17, 24)],
          3,
          shell,
        );
        final claw = Path()
          ..moveTo(side * 17, 16)
          ..lineTo(side * 25, 24)
          ..lineTo(side * 18, 22)
          ..lineTo(side * 14, 28)
          ..lineTo(side * 12, 19)
          ..close();
        outlined(claw, shell);
        canvas.restore();
      }
      legs(feet, 1.5, shell);
      canvas.save();
      canvas.translate(0, -4);
      canvas.rotate(.14 * sway + .2 * charge - .28 * recoil);
      canvas.translate(0, 4);
      final tail = Path()
        ..moveTo(0, -4)
        ..cubicTo(-20, -19, 10, -36, 14, -18);
      canvas.drawPath(tail, _stroke(ink, 6));
      canvas.drawPath(tail, _stroke(shell, 4));
      outlined(
        Path()
          ..moveTo(10, -22)
          ..lineTo(20, -15)
          ..lineTo(10, -12)
          ..close(),
        enemy.warning ? accent : shell,
      );
      canvas.restore();
      oval(const Rect.fromLTWH(-8, -10, 16, 28), shell);
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(-5, -4 + i * 5.0),
          Offset(5, -4 + i * 5.0),
          _stroke(dark, 1),
        );
      }
    case LateEnemyKind.seedSpitter:
      for (final side in [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(0, 10);
        canvas.rotate(side * (.09 * sway + .12 * charge - .1 * recoil));
        canvas.translate(0, -10);
        outlined(
          Path()
            ..moveTo(0, 10)
            ..quadraticBezierTo(side * 27, -7, side * 23, 18)
            ..quadraticBezierTo(side * 8, 27, 0, 10)
            ..close(),
          shell,
        );
        limb([Offset.zero, Offset(side * 14, 15)], 1, dark);
        canvas.restore();
      }
      canvas.scale(
        1 + breathe * .025 + charge * .07 - recoil * .06,
        1 - charge * .035 + recoil * .09,
      );
      oval(const Rect.fromLTWH(-12, -18, 24, 30), shell);
      for (final side in [-1.0, 1.0]) {
        canvas.drawArc(
          Rect.fromLTWH(-8 + side * 3, -15, 14, 23),
          -1.2,
          2.4,
          false,
          _stroke(accent.withAlpha(170), 1),
        );
      }
      oval(const Rect.fromLTWH(-8, 0, 16, 18), const Color(0xFF82C398));
      oval(
        Rect.fromLTWH(-5 - charge, 7, 10 + charge * 2, 8 + charge * 2),
        dark,
      );
  }
  if (enemy.kind != LateEnemyKind.seedSpitter) {
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(side * 3.5, 11),
        1.8,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(Offset(side * 3.5, 11.5), .8, Paint()..color = dark);
    }
  }
  canvas.restore();
}
