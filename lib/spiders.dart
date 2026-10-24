import 'dart:math' as math;

/// A fixed territory with slow patrol and a persistent chase once disturbed.
class BoardSpider {
  double arenaStretch = 1;
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

  /// Walking back to its patrol after a chase was called off.
  bool returning = false;
  double get zoneX => homeX;
  double get zoneY => homeY;

  void reset() {
    time = 0;
    chasing = returning = false;
    x = homeX + math.cos(phase) * 12;
    y = homeY + math.sin(phase) * 12;
    heading = phase + math.pi / 2;
  }

  /// Calls off a chase: the spider walks back to its patrol ring and only
  /// chases again once the ball enters its territory anew.
  void calm() {
    if (!chasing) return;
    chasing = false;
    returning = true;
  }

  /// Returns true on physical contact, including crossings between physics ticks.
  /// While the ball is out of play ([noticing] false) it cannot start a chase.
  bool step(
    double dt,
    double oldBallX,
    double oldBallY,
    double ballX,
    double ballY, {
    bool noticing = true,
  }) {
    if (dt <= 0 || !dt.isFinite) return false;
    final oldX = x, oldY = y;
    final dx = (ballX - oldBallX) * arenaStretch, dy = ballY - oldBallY;
    final length = dx * dx + dy * dy;
    final t = length == 0
        ? 0.0
        : (((homeX - oldBallX) * arenaStretch * dx + (homeY - oldBallY) * dy) /
                  length)
              .clamp(0.0, 1.0);
    if (noticing &&
        math.pow((oldBallX - homeX) * arenaStretch + dx * t, 2) +
                math.pow(oldBallY + dy * t - homeY, 2) <=
            math.pow(zoneRadius + 7, 2)) {
      chasing = true;
      returning = false;
    }
    time += dt;
    if (chasing) {
      final vx = ballX - x,
          vy = ballY - y,
          distance = math.sqrt(vx * vx * arenaStretch * arenaStretch + vy * vy);
      if (distance > 0) {
        final travel = math.min(distance, chaseSpeed * dt);
        x += vx / distance * travel;
        y += vy / distance * travel;
        heading = math.atan2(vy, vx * arenaStretch);
      }
    } else {
      final angle = phase + time * .65;
      final px = homeX + math.cos(angle) * 12 / arenaStretch;
      final py = homeY + math.sin(angle) * 12;
      final vx = px - x, vy = py - y;
      final distance = math.sqrt(
        vx * vx * arenaStretch * arenaStretch + vy * vy,
      );
      if (returning && distance > chaseSpeed * dt) {
        x += vx / distance * chaseSpeed * dt;
        y += vy / distance * chaseSpeed * dt;
        heading = math.atan2(vy, vx * arenaStretch);
      } else {
        returning = false;
        x = px;
        y = py;
        heading = angle + math.pi / 2;
      }
    }
    final rx = (oldBallX - oldX) * arenaStretch, ry = oldBallY - oldY;
    final vx = (ballX - x) * arenaStretch - rx, vy = (ballY - y) - ry;
    final v2 = vx * vx + vy * vy;
    final hitTime = v2 == 0 ? 0.0 : (-(rx * vx + ry * vy) / v2).clamp(0.0, 1.0);
    return math.pow(rx + vx * hitTime, 2) + math.pow(ry + vy * hitTime, 2) <=
        math.pow(7 + bodyRadius, 2);
  }
}
