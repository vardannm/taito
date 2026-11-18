import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Local character artwork. All pose changes stay around the fixed perch.
void paintScorpionSkin(
  Canvas canvas, {
  required bool lightInk,
  required Color accent,
  required double time,
  required double motion,
  required double sway,
  required double charge,
  required double recoil,
}) {
  const deep = Color(0xFF301E30);
  const shell = Color(0xFF833D48);
  const copper = Color(0xFFD66B50);
  const gold = Color(0xFFF5BE88);
  const ivory = Color(0xFFFFF2D3);
  final edge = lightInk ? const Color(0xFFF1C6AC) : deep;
  final fill = Paint();
  Paint line(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final outline = line(edge, 1.6);
  void armor(Path path, Color color) {
    canvas.drawPath(path, outline);
    canvas.drawPath(path, fill..color = color);
  }

  // Four jointed legs per side; one batched path keeps their cost constant.
  final legs = Path(), legLight = Path();
  for (final side in [-1.0, 1.0]) {
    for (var i = 0; i < 4; i++) {
      final stride = math.sin(time * 8 + i * 1.7 + side) * motion;
      final y = -7 + i * 5.0;
      final knee = Offset(side * (17 + i * .6), y - 5 + stride);
      final foot = Offset(side * (24 + stride), y + i * 1.5);
      legs.moveTo(side * 7, y);
      legs.lineTo(knee.dx, knee.dy);
      legs.lineTo(foot.dx, foot.dy);
      legLight.moveTo(side * 11, y - 1);
      legLight.lineTo(knee.dx, knee.dy);
    }
  }
  canvas.drawPath(legs, line(edge, 4.2));
  canvas.drawPath(legs, line(shell, 2.8));
  canvas.drawPath(legLight, line(copper, .8));

  // A raised, articulated tail with a curved venom hook, rather than an arrow.
  canvas.save();
  canvas.translate(0, -6);
  canvas.rotate(.09 * sway + .15 * charge - .2 * recoil);
  canvas.translate(0, 6);
  final tail = Path()
    ..moveTo(0, -8)
    ..cubicTo(-13, -15, -15, -28, -5, -34)
    ..cubicTo(4, -40, 17, -32, 15, -23);
  canvas.drawPath(tail, line(edge, 9));
  canvas.drawPath(tail, line(shell, 7.4));
  canvas.drawPath(tail, line(copper, 4.8));
  final joints = Path()
    ..moveTo(-9, -13)
    ..lineTo(-3, -18)
    ..moveTo(-14, -22)
    ..lineTo(-7, -23)
    ..moveTo(-11, -31)
    ..lineTo(-5, -28)
    ..moveTo(-3, -38)
    ..lineTo(-1, -31)
    ..moveTo(8, -37)
    ..lineTo(6, -30)
    ..moveTo(17, -30)
    ..lineTo(11, -27);
  canvas.drawPath(joints, line(deep, 1.4));
  final shine = Path()
    ..moveTo(-10, -24)
    ..quadraticBezierTo(-10, -31, -5, -33)
    ..moveTo(1, -35)
    ..quadraticBezierTo(6, -35, 9, -32);
  canvas.drawPath(shine, line(gold, 1));
  armor(Path()..addOval(const Rect.fromLTWH(10, -28, 10, 11)), shell);
  armor(
    Path()
      ..moveTo(17, -23)
      ..cubicTo(24, -19, 23, -12, 13, -9)
      ..quadraticBezierTo(18, -15, 15, -18)
      ..close(),
    accent,
  );
  canvas.drawLine(const Offset(18, -20), const Offset(19, -17), line(ivory, 1));
  canvas.restore();

  for (final side in [-1.0, 1.0]) {
    canvas.save();
    canvas.translate(side * 8, 5);
    canvas.rotate(side * (.04 * sway + .1 * charge - .12 * recoil));
    canvas.translate(-side * 8, -5);
    armor(
      Path()
        ..moveTo(side * 6, 2)
        ..lineTo(side * 16, 4)
        ..lineTo(side * 22, 15)
        ..lineTo(side * 16, 19)
        ..lineTo(side * 12, 10)
        ..lineTo(side * 6, 9)
        ..close(),
      shell,
    );
    final claw = Path()
      ..moveTo(side * 17, 13)
      ..cubicTo(side * 28, 10, side * 34, 20, side * 29, 28)
      ..quadraticBezierTo(side * 27, 31, side * 24, 32)
      ..lineTo(side * 22, 23)
      ..lineTo(side * 18, 31)
      ..cubicTo(side * 9, 29, side * 10, 17, side * 17, 13)
      ..close();
    armor(claw, copper);
    final clawShade = Path()
      ..moveTo(side * 14, 19)
      ..quadraticBezierTo(side * 13, 26, side * 18, 29)
      ..lineTo(side * 22, 21)
      ..lineTo(side * 24, 30)
      ..quadraticBezierTo(side * 31, 26, side * 30, 21)
      ..quadraticBezierTo(side * 26, 27, side * 25, 19)
      ..close();
    canvas.drawPath(clawShade, fill..color = shell);
    final clawLight = Path()
      ..moveTo(side * 15, 18)
      ..quadraticBezierTo(side * 22, 13, side * 28, 20)
      ..moveTo(side * 24, 26)
      ..lineTo(side * 24, 29);
    canvas.drawPath(clawLight, line(gold, 1.1));
    canvas.drawCircle(Offset(side * 17, 11), 2, fill..color = gold);
    canvas.restore();
  }

  final body = Path()
    ..moveTo(0, -13)
    ..cubicTo(-9, -13, -11, -5, -10, 3)
    ..lineTo(-7, 13)
    ..quadraticBezierTo(0, 18, 7, 13)
    ..lineTo(10, 3)
    ..cubicTo(11, -5, 9, -13, 0, -13)
    ..close();
  armor(body, deep);
  final plates = Path();
  final plateLight = Path();
  for (var i = 0; i < 4; i++) {
    final y = -10 + i * 5.0;
    final width = 6.0 + (i == 0 ? 0 : 1.5);
    plates.moveTo(-width, y);
    plates.quadraticBezierTo(0, y - 3, width, y);
    plates.lineTo(width - 1, y + 3);
    plates.quadraticBezierTo(0, y + 5, -width + 1, y + 3);
    plates.close();
    plateLight.moveTo(-width + 1, y + .4);
    plateLight.quadraticBezierTo(0, y - 1.4, width - 1, y + .4);
  }
  canvas.drawPath(plates, fill..color = copper);
  canvas.drawPath(plateLight, line(gold, .8));
  armor(
    Path()
      ..moveTo(-8, 7)
      ..lineTo(0, 9)
      ..lineTo(8, 7)
      ..lineTo(6, 15)
      ..quadraticBezierTo(0, 19, -6, 15)
      ..close(),
    shell,
  );
  final eyes = Path(), eyeCores = Path();
  for (final side in [-1.0, 1.0]) {
    eyes.moveTo(side * 1.5, 12);
    eyes.lineTo(side * 6, 10.5);
    eyes.lineTo(side * 5, 13.5);
    eyes.lineTo(side * 2.5, 14);
    eyes.close();
    eyeCores.addOval(
      Rect.fromCircle(center: Offset(side * 3.8, 12.4), radius: .7),
    );
  }
  canvas.drawPath(eyes, fill..color = ivory);
  canvas.drawPath(eyeCores, fill..color = accent);
  canvas.drawLine(const Offset(-2, 16), const Offset(2, 16), line(deep, 1.2));
}
