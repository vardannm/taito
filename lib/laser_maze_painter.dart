import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'laser_maze.dart';

void paintLaserMaze(
  Canvas canvas,
  LaserMazeRun run,
  double clock,
  bool reducedMotion, {
  double cameraOffset = 0,
}) {
  final corridor = run.corridor;
  canvas.save();
  canvas.translate(0, cameraOffset);
  // One filled path unions the overlapping legs, so corners blend once only.
  final road = Path();
  for (final rect in corridor.rects) {
    if (rect.bottom + cameraOffset < 12 || rect.top + cameraOffset > 548)
      continue;
    road.addRect(Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom));
  }
  canvas.drawPath(road, Paint()..color = const Color(0xF21A3738));
  final beams = Path();
  for (final wall in corridor.walls) {
    if (math.max(wall.a.y, wall.b.y) + cameraOffset < 12 ||
        math.min(wall.a.y, wall.b.y) + cameraOffset > 548)
      continue;
    beams
      ..moveTo(wall.a.x, wall.a.y)
      ..lineTo(wall.b.x, wall.b.y);
  }
  final pulse = reducedMotion ? 1.0 : .86 + .14 * math.sin(clock * 3);
  canvas.drawPath(
    beams,
    Paint()
      ..color = const Color(0xFFFF343E).withValues(alpha: .3 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
  );
  canvas.drawPath(
    beams,
    Paint()
      ..color = const Color(0xFFFF3D49)
      ..style = PaintingStyle.stroke
      ..strokeWidth = LaserMazeCorridor.beamRadius * 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawPath(
    beams,
    Paint()
      ..color = const Color(0xFFFFD5CE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..strokeJoin = StrokeJoin.round,
  );
  // Arrows follow the centerline, so a sideways leg reads as a sideways leg.
  final arrow = Paint()
    ..color = const Color(0x558FC9BC)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  for (final leg in corridor.legs) {
    final a = leg.a, b = leg.b;
    arrow.color = leg.primary
        ? const Color(0x889FCFC2)
        : const Color(0xDDFFD078);
    final dx = b.x - a.x, dy = b.y - a.y;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 34) continue;
    final tx = dx / length, ty = dy / length;
    for (var travel = 26.0; travel < length - 12; travel += 62) {
      final x = a.x + tx * travel, y = a.y + ty * travel;
      final screen = y + cameraOffset;
      if (screen < 24 || screen > 542) continue;
      canvas.drawPath(
        Path()
          ..moveTo(x - tx * 4 - ty * 4, y - ty * 4 + tx * 4)
          ..lineTo(x, y)
          ..lineTo(x - tx * 4 + ty * 4, y - ty * 4 - tx * 4),
        arrow,
      );
    }
  }
  for (final branch in corridor.branches) {
    final a = branch.points[0], b = branch.points[1];
    final label = TextPainter(
      text: const TextSpan(
        text: 'SHORT',
        style: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: 6,
          fontWeight: FontWeight.w800,
          color: Color(0xFFFFD078),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate((a.x + b.x) / 2, (a.y + b.y) / 2);
    if (a.x == b.x) canvas.rotate(-math.pi / 2);
    label.paint(canvas, Offset(-label.width / 2, -label.height / 2));
    canvas.restore();
  }
  if (run.route case final route?) {
    final finishLeft = route.finishX - route.halfWidth + 6;
    final finishWidth = route.halfWidth * 2 - 12;
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 10; col++) {
        canvas.drawRect(
          Rect.fromLTWH(
            finishLeft + col * finishWidth / 10,
            route.finishLineY - 5 + row * 5,
            finishWidth / 10,
            5,
          ),
          Paint()
            ..color = (row + col).isEven
                ? const Color(0xFFFFF0C9)
                : const Color(0xFF152C2C),
        );
      }
    }
  }
  canvas.restore();
  void label(String value, double x, double y, double size, Color color) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(x - text.width / 2, y - text.height / 2));
  }

  if (run.route case final route?) {
    final y = route.finishLineY - 13 + cameraOffset;
    if (y > 16 && y < 542) {
      label('FINISH', route.finishX, y, 8, const Color(0xFFFFF0C9));
    }
  }
  final start = 537 + cameraOffset;
  if (start > 24 && start < 542) {
    label('START', 180, start, 7, const Color(0xFF9CC8BC));
  }
  if (run.hitLaser) {
    canvas.drawCircle(
      Offset(run.contactX, run.contactY + cameraOffset),
      13,
      Paint()
        ..color = const Color(0xFFFF6C71)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

class MazeRoutePreview extends CustomPainter {
  MazeRoutePreview(this.number) : route = LaserMazeRoute(number);
  final int number;
  final LaserMazeRoute route;
  @override
  void paint(Canvas canvas, Size size) {
    if (route.tall) {
      // A constant-width route diagram stays legible for multi-screen towers.
      Offset project(MazePoint p) => Offset(
        p.x / 360 * size.width,
        (p.y - route.routeTop + 12) / route.mapHeight * size.height,
      );
      for (final leg in route.legs) {
        canvas.drawLine(
          project(leg.a),
          project(leg.b),
          Paint()
            ..color = leg.primary
                ? const Color(0xFFDD5960)
                : const Color(0xFFB78B37)
            ..strokeWidth = leg.primary ? 1.25 : .85
            ..strokeCap = StrokeCap.round,
        );
      }
      for (final p in [route.centers.first, route.centers.last]) {
        canvas.drawCircle(
          project(p),
          2,
          Paint()..color = const Color(0xFF388B7D),
        );
      }
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / 360, size.height / route.mapHeight);
    canvas.translate(0, 12 - route.routeTop);
    final beams = Path();
    for (final wall in route.walls) {
      beams
        ..moveTo(wall.a.x, wall.a.y)
        ..lineTo(wall.b.x, wall.b.y);
    }
    canvas.drawPath(
      beams,
      Paint()
        ..color = const Color(0xFFEF515A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(MazeRoutePreview oldDelegate) =>
      number != oldDelegate.number;
}


