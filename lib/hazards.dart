import 'dart:math' as math;

enum HazardKind { formingHole, movingHole, laser, platformGap }

/// Screen-space hazards keep their full warning visible before activation.
/// A forming hole starts travelling with the board only after it opens.
class SpecialHazard {
  SpecialHazard(
    this.kind, {
    required this.x,
    required this.y,
    this.warningSeconds = 2.0,
    this.liveSeconds = 3.0,
  }) : originX = x;
  final HazardKind kind;
  final double originX, warningSeconds, liveSeconds;
  double x, y, age = 0;
  double _oldX = 0, _oldY = 0, _from = 0, _until = 0;
  bool get warning => age < warningSeconds;
  bool get expired => age >= warningSeconds + liveSeconds;
  bool get active => !warning && !expired;
  double get countdown => math.max(0, warningSeconds - age);
  double get gapLeft => x - 30;
  double get gapRight => x + 30;
  String get label => switch (kind) {
    HazardKind.formingHole => warning ? 'HOLE OPENING' : 'HOLE OPEN',
    HazardKind.movingHole => warning ? 'MOVING HOLE INCOMING' : 'MOVING HOLE',
    HazardKind.laser => warning ? 'LASER CHARGING' : 'LASER LIVE',
    HazardKind.platformGap => warning ? 'PLATFORM BREAKING' : 'GAP OPEN',
  };

  void step(double dt, double scrollSpeed) {
    final before = age;
    _oldX = x;
    _oldY = y;
    age += dt;
    _from = ((warningSeconds - before) / dt).clamp(0.0, 1.0);
    _until = ((warningSeconds + liveSeconds - before) / dt).clamp(0.0, 1.0);
    final liveDt = math.max(0.0, _until - _from) * dt;
    if (kind == HazardKind.formingHole || kind == HazardKind.movingHole) {
      y += scrollSpeed * liveDt;
    }
    if (kind == HazardKind.movingHole && liveDt > 0) {
      final liveAge = (age - warningSeconds).clamp(0.0, liveSeconds);
      x = originX + 48 * math.sin(liveAge * 2.2);
    }
  }

  bool hits(double oldX, double oldY, double newX, double newY) {
    if (_until <= _from) return false;
    // Only the active fraction of a boundary-crossing step can cause damage.
    final ax = oldX + (newX - oldX) * _from;
    final ay = oldY + (newY - oldY) * _from;
    final bx = oldX + (newX - oldX) * _until;
    final by = oldY + (newY - oldY) * _until;
    if (kind == HazardKind.laser) {
      return _crossesRect(ax, ay, bx, by, x - 10, x + 10, 33, 537);
    }
    if (kind == HazardKind.platformGap) {
      return math.max(ax, bx) > gapLeft + 3 && math.min(ax, bx) < gapRight - 3;
    }
    final rx = ax - _oldX, ry = ay - _oldY;
    final dx = (bx - x) - rx, dy = (by - y) - ry;
    final length = dx * dx + dy * dy;
    final t = length == 0
        ? 0.0
        : (-(rx * dx + ry * dy) / length).clamp(0.0, 1.0);
    return math.pow(rx + dx * t, 2) + math.pow(ry + dy * t, 2) <= 8.5 * 8.5;
  }

  static bool _crossesRect(
    double ax,
    double ay,
    double bx,
    double by,
    double left,
    double right,
    double top,
    double bottom,
  ) {
    var lo = 0.0, hi = 1.0;
    for (final axis in [
      (ax, bx - ax, left, right),
      (ay, by - ay, top, bottom),
    ]) {
      if (axis.$2.abs() < .000001) {
        if (axis.$1 < axis.$3 || axis.$1 > axis.$4) return false;
      } else {
        final a = (axis.$3 - axis.$1) / axis.$2,
            b = (axis.$4 - axis.$1) / axis.$2;
        lo = math.max(lo, math.min(a, b));
        hi = math.min(hi, math.max(a, b));
        if (lo > hi) return false;
      }
    }
    return true;
  }
}
