import 'dart:math' as math;
import 'infinite_progress.dart';

/// Screen-space web shots stay dodgeable even as Infinite ascent accelerates.
/// Aim is fixed at launch; neither the warning nor the shot tracks the player.
class SpiderWebShot {
  SpiderWebShot({
    required this.x,
    required this.y,
    required this.targetX,
    required this.targetY,
    this.speed = InfiniteTuning.webSpeed,
    this.warningSeconds = InfiniteTuning.webWarningSeconds,
    this.liveSeconds = InfiniteTuning.webLifeSeconds,
  }) {
    final dx = targetX - x, dy = targetY - y;
    final distance = math.sqrt(dx * dx + dy * dy);
    vx = distance == 0 ? 0 : dx / distance * speed;
    vy = distance == 0 ? speed : dy / distance * speed;
  }
  double x, y, age = 0;
  final double targetX, targetY, speed, warningSeconds, liveSeconds;
  late final double vx, vy;
  bool consumed = false;
  double _oldX = 0, _oldY = 0, _from = 0, _until = 0;
  bool get warning => age < warningSeconds;
  bool get expired => consumed || age >= warningSeconds + liveSeconds;

  void step(double dt) {
    if (dt <= 0 || !dt.isFinite) return;
    final before = age;
    _oldX = x;
    _oldY = y;
    age += dt;
    _from = ((warningSeconds - before) / dt).clamp(0.0, 1.0);
    _until = ((warningSeconds + liveSeconds - before) / dt).clamp(0.0, 1.0);
    final travelTime = math.max(0.0, _until - _from) * dt;
    x += vx * travelTime;
    y += vy * travelTime;
  }

  double? contact(double ax, double ay, double bx, double by) {
    if (consumed || _until <= _from) return null;
    final t = circleContact(
      ax + (bx - ax) * _from - _oldX,
      ay + (by - ay) * _from - _oldY,
      ax + (bx - ax) * _until - x,
      ay + (by - ay) * _until - y,
      0,
      0,
      7 + InfiniteTuning.webRadius,
    );
    return t == null ? null : _from + (_until - _from) * t;
  }
}
