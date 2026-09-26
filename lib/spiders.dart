import 'dart:math' as math;
import 'laser_maze.dart';

/// A fixed territory with slow patrol and a persistent chase once disturbed.
class BoardSpider {
  BoardSpider(
    this.homeX,
    this.homeY,
    this.zoneRadius, {
    this.phase = 0,
    this.chaseSpeed = 72,
    this.bodyRadius = 6,
  }) {
    reset();
  }
  final double homeX, homeY, zoneRadius, phase, chaseSpeed, bodyRadius;
  late double x, y;
  double time = 0, heading = 0;
  bool chasing = false;
  double get zoneX => homeX;
  double get zoneY => homeY;

  void reset() {
    time = 0;
    chasing = false;
    x = homeX + math.cos(phase) * 12;
    y = homeY + math.sin(phase) * 12;
    heading = phase + math.pi / 2;
  }

  /// Returns true on physical contact, including crossings between physics ticks.
  bool step(
    double dt,
    double oldBallX,
    double oldBallY,
    double ballX,
    double ballY,
  ) {
    if (dt <= 0 || !dt.isFinite) return false;
    final oldX = x, oldY = y;
    final dx = ballX - oldBallX, dy = ballY - oldBallY;
    final length = dx * dx + dy * dy;
    final t = length == 0
        ? 0.0
        : (((homeX - oldBallX) * dx + (homeY - oldBallY) * dy) / length).clamp(
            0.0,
            1.0,
          );
    if (math.pow(oldBallX + dx * t - homeX, 2) +
            math.pow(oldBallY + dy * t - homeY, 2) <=
        math.pow(zoneRadius + 7, 2)) {
      chasing = true;
    }
    time += dt;
    if (chasing) {
      final vx = ballX - x,
          vy = ballY - y,
          distance = math.sqrt(vx * vx + vy * vy);
      if (distance > 0) {
        final travel = math.min(distance, chaseSpeed * dt);
        x += vx / distance * travel;
        y += vy / distance * travel;
        heading = math.atan2(vy, vx);
      }
    } else {
      final angle = phase + time * .65;
      x = homeX + math.cos(angle) * 12;
      y = homeY + math.sin(angle) * 12;
      heading = angle + math.pi / 2;
    }
    final rx = oldBallX - oldX, ry = oldBallY - oldY;
    final vx = (ballX - x) - rx, vy = (ballY - y) - ry;
    final v2 = vx * vx + vy * vy;
    final hitTime = v2 == 0 ? 0.0 : (-(rx * vx + ry * vy) / v2).clamp(0.0, 1.0);
    return math.pow(rx + vx * hitTime, 2) + math.pow(ry + vy * hitTime, 2) <=
        math.pow(7 + bodyRadius, 2);
  }
}

/// A bug patrols outside the road. Amber warns before the expanding circle
/// becomes red and active. Every placement protects all route centerlines.
class MazeSpider extends BoardSpider {
  MazeSpider(
    double x,
    double y,
    this.road, {
    required this.tangentX,
    required this.tangentY,
    required this.maxZone,
    double phase = 0,
  }) : super(x, y, maxZone, phase: phase, bodyRadius: 4.5);
  final LaserMazeCorridor road;
  final double tangentX, tangentY, maxZone;
  static const patrolDistance = 4.0, period = 10.0;
  double get cycle => (time + phase) % period;
  bool get warning => cycle >= 3 && cycle < 5;
  bool get active =>
      cycle >= 5 &&
      cycle < 6.6 &&
      road.circleOverlapsRoad(x, y, catchingRadius);
  double get warningProgress => warning ? (cycle - 3) / 2 : 0;
  double get catchingRadius => cycle < 3
      ? 8
      : cycle < 5
      ? 8 + (maxZone - 8) * (cycle - 3) / 2
      : cycle < 6.6
      ? maxZone
      : cycle < 7.8
      ? maxZone - (maxZone - 8) * (cycle - 6.6) / 1.2
      : 8;
  @override
  double get zoneX => x;
  @override
  double get zoneY => y;

  static MazeSpider? beside(
    LaserMazeCorridor road,
    MazeLeg leg,
    math.Random random,
  ) {
    final horizontal = leg.a.y == leg.b.y;
    final tx = horizontal ? 1.0 : 0.0, ty = horizontal ? 0.0 : 1.0;
    final fraction = .35 + random.nextDouble() * .3;
    for (final side in random.nextBool() ? [-1.0, 1.0] : [1.0, -1.0]) {
      final x =
          leg.a.x +
          (leg.b.x - leg.a.x) * fraction +
          ty * side * (leg.halfWidth + 12);
      final y =
          leg.a.y +
          (leg.b.y - leg.a.y) * fraction +
          tx * side * (leg.halfWidth + 12);
      final a = MazePoint(x - tx * patrolDistance, y - ty * patrolDistance);
      final b = MazePoint(x + tx * patrolDistance, y + ty * patrolDistance);
      if (math.min(a.x, b.x) < 16 ||
          math.max(a.x, b.x) > 344 ||
          road.roadDistanceAlong(a, b) <= 10)
        continue;
      // Protect a ball-sized tube plus three units around EVERY branch.
      final radius = math.min(28.0, road.centerlineDistanceAlong(a, b) - 10);
      if (radius < 20) continue;
      return MazeSpider(
        x,
        y,
        road,
        tangentX: tx,
        tangentY: ty,
        maxZone: radius,
        phase: random.nextDouble() * 2,
      );
    }
    return null;
  }

  @override
  void reset() {
    time = 0;
    chasing = false;
    x = homeX;
    y = homeY;
    heading = phase;
  }

  @override
  bool step(double dt, double ax, double ay, double bx, double by) {
    if (dt <= 0 || !dt.isFinite) return false;
    final oldX = x, oldY = y;
    time += dt;
    final travel = math.sin(time * .7) * patrolDistance;
    x = homeX + tangentX * travel;
    y = homeY + tangentY * travel;
    heading =
        math.atan2(tangentY, tangentX) +
        (math.cos(time * .7) < 0 ? math.pi : 0);
    chasing = active;
    if (!active) return false;
    final rx = ax - oldX, ry = ay - oldY;
    final dx = (bx - x) - rx, dy = (by - y) - ry;
    final length = dx * dx + dy * dy;
    final t = length == 0
        ? 0.0
        : (-(rx * dx + ry * dy) / length).clamp(0.0, 1.0);
    final px = ax + (bx - ax) * t, py = ay + (by - ay) * t;
    return road.contains(px, py) &&
        math.pow(rx + dx * t, 2) + math.pow(ry + dy * t, 2) <=
            math.pow(catchingRadius + 7, 2);
  }
}
