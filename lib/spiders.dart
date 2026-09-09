import 'dart:math' as math;

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
