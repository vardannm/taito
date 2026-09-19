import 'dart:math' as math;

/// Laser walls that drift down the Infinite board during a maze section. Each
/// one spans the playfield except for a single wide opening to steer through.
class MazeGate {
  MazeGate({required this.y, required this.gapCenter, required this.gapWidth});
  static const beamHalf = 3.5, edge = 10.0, span = 340.0;
  double y;
  final double gapCenter, gapWidth;
  double _oldY = 0, age = 0;

  /// Beams light up as they enter, so one never appears already on the ball.
  static const fadeIn = .45;
  double get intensity => (age / fadeIn).clamp(0.0, 1.0);
  double get gapLeft => gapCenter - gapWidth / 2;
  double get gapRight => gapCenter + gapWidth / 2;

  void step(double dt, double scrollSpeed) {
    _oldY = y;
    age += dt;
    y += scrollSpeed * dt;
  }

  /// Entry time of the ball's swept path into the lit part of the beam, or
  /// null when it passes through the opening. Both bodies move, so the test
  /// runs in the frame of the beam.
  double? contact(
    double oldX,
    double oldY,
    double newX,
    double newY,
    double radius,
  ) {
    if (intensity < 1) return null;
    final ay = oldY - _oldY, by = newY - y;
    final reach = beamHalf + radius;
    // Solve for the slice of the step that overlaps the beam's band.
    var lo = 0.0, hi = 1.0;
    final travel = by - ay;
    if (travel.abs() < .000001) {
      if (ay < -reach || ay > reach) return null;
    } else {
      final a = (-reach - ay) / travel, b = (reach - ay) / travel;
      lo = math.max(0.0, math.min(a, b));
      hi = math.min(1.0, math.max(a, b));
      if (lo > hi) return null;
    }
    // Inside that slice, the opening is the only safe horizontal window.
    for (var i = 0; i <= 8; i++) {
      final t = lo + (hi - lo) * i / 8;
      final x = oldX + (newX - oldX) * t;
      if (x - radius < gapLeft || x + radius > gapRight) {
        if (x + radius >= edge && x - radius <= edge + span) return t;
      }
    }
    return null;
  }
}
