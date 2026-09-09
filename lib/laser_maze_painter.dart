import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'laser_maze.dart';

void paintLaserMaze(
  Canvas canvas,
  LaserMazeRun run,
  double clock,
  bool reducedMotion,
) {
  final route = run.route;
  Path wallPath(List<MazePoint> points) => Path()
    ..moveTo(points.first.x, points.first.y)
    ..addPolygon(points.map((p) => Offset(p.x, p.y)).toList(), false);
  final road = Path()
    ..addPolygon([
      ...route.leftWall.map((p) => Offset(p.x, p.y)),
      ...route.rightWall.reversed.map((p) => Offset(p.x, p.y)),
    ], true);
  canvas.drawPath(road, Paint()..color = const Color(0xF21A3738));
  final pulse = reducedMotion ? 1.0 : .86 + .14 * math.sin(clock * 3);
  for (final wall in [route.leftWall, route.rightWall]) {
    final path = wallPath(wall);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF343E).withValues(alpha: .3 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF3D49)
        ..style = PaintingStyle.stroke
        ..strokeWidth = LaserMazeRoute.beamRadius * 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFD5CE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..strokeJoin = StrokeJoin.round,
    );
  }
  // Small chevrons make the upward route readable without obscuring the ball.
  for (var y = 440.0; y >= 90; y -= 70) {
    final x = route.centerAt(y);
    canvas.drawPath(
      Path()
        ..moveTo(x - 4, y + 3)
        ..lineTo(x, y - 1)
        ..lineTo(x + 4, y + 3),
      Paint()
        ..color = const Color(0x558FC9BC)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }
  final finishLeft = 180 - route.halfWidth + 6;
  final finishWidth = route.halfWidth * 2 - 12;
  for (var row = 0; row < 2; row++) {
    for (var col = 0; col < 10; col++) {
      canvas.drawRect(
        Rect.fromLTWH(
          finishLeft + col * finishWidth / 10,
          LaserMazeRoute.finishY - 5 + row * 5,
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
  void label(String value, double y, double size, Color color) {
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
    text.paint(canvas, Offset(180 - text.width / 2, y - text.height / 2));
  }

  label('FINISH', 31, 8, const Color(0xFFFFF0C9));
  label('START', 537, 7, const Color(0xFF9CC8BC));
  if (run.hitLaser) {
    canvas.drawCircle(
      Offset(run.contactX, run.contactY),
      13,
      Paint()
        ..color = const Color(0xFFFF6C71)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

class MazeRoutePreview extends CustomPainter {
  MazeRoutePreview(this.number);
  final int number;
  @override
  void paint(Canvas canvas, Size size) {
    final route = LaserMazeRoute(number);
    canvas.save();
    canvas.scale(size.width / 360, size.height / 560);
    for (final wall in [route.leftWall, route.rightWall]) {
      canvas.drawPath(
        Path()..addPolygon(wall.map((p) => Offset(p.x, p.y)).toList(), false),
        Paint()
          ..color = const Color(0xFFEF515A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MazeRoutePreview oldDelegate) =>
      number != oldDelegate.number;
}
