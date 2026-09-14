import 'dart:math' as math;
import 'infinite_progress.dart';

enum HazardKind { formingHole, movingHole, laser, platformGap }

/// Screen-space hazards keep their full warning visible before activation.
/// Opened forming holes are anchored in world space, including manual camera movement.
class SpecialHazard {
  SpecialHazard(
    this.kind, {
    required this.x,
    required this.y,
    this.warningSeconds = 2.0,
    this.liveSeconds = 3.0,
    this.sweeping = false,
    this.zigzag = false,
    double? cameraOffset,
  }) : originX = x,
       _lastCameraOffset = cameraOffset;
  final HazardKind kind;
  final bool sweeping, zigzag;
  final double originX, warningSeconds, liveSeconds;
  double x, y, age = 0;
  double? _worldY, _lastCameraOffset;
  double? get worldY => _worldY;
  double _oldX = 0, _oldY = 0, _from = 0, _until = 0;
  bool get warning => age < warningSeconds;
  bool get expired => age >= warningSeconds + liveSeconds;
  bool get active => !warning && !expired;
  double get countdown => math.max(0, warningSeconds - age);
  double get gapLeft => x - 30;
  double get gapRight => x + 30;
  String get label => switch (kind) {
    HazardKind.formingHole => warning ? 'HOLE OPENING' : 'HOLE OPEN',
    HazardKind.movingHole =>
      zigzag
          ? (warning ? 'ZIGZAG INCOMING' : 'ZIGZAG HOLE')
          : (warning ? 'MOVING HOLE INCOMING' : 'MOVING HOLE'),
    HazardKind.laser =>
      sweeping
          ? (warning ? 'SWEEP LASER CHARGING' : 'SWEEP LASER LIVE')
          : (warning ? 'LASER CHARGING' : 'LASER LIVE'),
    HazardKind.platformGap => warning ? 'PLATFORM BREAKING' : 'GAP OPEN',
  };

  void step(double dt, double scrollSpeed, {double? cameraOffset}) {
    final before = age;
    _oldX = x;
    _oldY = y;
    age += dt;
    _from = ((warningSeconds - before) / dt).clamp(0.0, 1.0);
    _until = ((warningSeconds + liveSeconds - before) / dt).clamp(0.0, 1.0);
    final liveDt = math.max(0.0, _until - _from) * dt;
    if (kind == HazardKind.formingHole && cameraOffset != null) {
      final previousCamera =
          _lastCameraOffset ?? cameraOffset - scrollSpeed * dt;
      final cameraAtStart =
          previousCamera + (cameraOffset - previousCamera) * _from;
      final cameraAtEnd =
          previousCamera + (cameraOffset - previousCamera) * _until;
      if (liveDt > 0) _worldY ??= y - cameraAtStart;
      if (_worldY != null) {
        _oldY = _worldY! + cameraAtStart;
        y = _worldY! + cameraAtEnd;
      }
    } else if (kind == HazardKind.formingHole ||
        kind == HazardKind.movingHole) {
      y += (zigzag ? scrollSpeed * 1.35 + 35 : scrollSpeed) * liveDt;
    }
    _lastCameraOffset = cameraOffset;
    if (kind == HazardKind.movingHole && liveDt > 0) {
      final liveAge = (age - warningSeconds).clamp(0.0, liveSeconds);
      x =
          originX +
          (zigzag
              ? 125 * (2 / math.pi) * math.asin(math.sin(liveAge * 2.4))
              : 48 * math.sin(liveAge * 2.2));
    }
    if (kind == HazardKind.laser && sweeping && liveDt > 0) {
      final liveAge = (age - warningSeconds).clamp(0.0, liveSeconds);
      x = originX + 65 * math.sin(liveAge * 1.6);
    }
  }

  bool hits(double oldX, double oldY, double newX, double newY) =>
      contact(oldX, oldY, newX, newY) != null;

  double? contact(double oldX, double oldY, double newX, double newY) {
    if (_until <= _from) return null;
    final ax = oldX + (newX - oldX) * _from;
    final ay = oldY + (newY - oldY) * _from;
    final bx = oldX + (newX - oldX) * _until;
    final by = oldY + (newY - oldY) * _until;
    final double? t;
    if (kind == HazardKind.laser) {
      t = _rectContact(ax - _oldX, ay, bx - x, by, -10, 10, 33, 537);
    } else if (kind == HazardKind.platformGap) {
      t = _rectContact(ax, 0, bx, 0, gapLeft + 3, gapRight - 3, -1, 1);
    } else {
      t = circleContact(ax - _oldX, ay - _oldY, bx - x, by - y, 0, 0, 8.5);
    }
    return t == null ? null : _from + (_until - _from) * t;
  }

  static double? _rectContact(
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
        if (axis.$1 < axis.$3 || axis.$1 > axis.$4) return null;
      } else {
        final a = (axis.$3 - axis.$1) / axis.$2,
            b = (axis.$4 - axis.$1) / axis.$2;
        lo = math.max(lo, math.min(a, b));
        hi = math.min(hi, math.max(a, b));
        if (lo > hi) return null;
      }
    }
    return lo;
  }
}
