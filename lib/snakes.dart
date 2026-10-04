import 'dart:math' as math;
import 'infinite_progress.dart';

typedef SnakePoint = ({double x, double y});

/// A travelling wave along a tapered body, moving diagonally in world space.
/// The same body samples drive drawing and swept collision, including the tail.
class BoardSnake {
  BoardSnake({
    required this.x,
    required this.y,
    this.fromLeft = true,
    this.phase = 0,
    this.variant = 0,
  }) {
    points = _body();
    _previous = points;
  }

  double x, y, age = 0;
  final bool fromLeft;
  final double phase;
  final int variant;
  static const samples = 29;
  static const length = 112.0;
  late List<SnakePoint> points, _previous;
  double get vx => (fromLeft ? 1 : -1) * InfiniteTuning.snakeSideSpeed;
  double get vy => InfiniteTuning.snakeDownSpeed;
  bool get expired => age > 15;
  static final _radii = List<double>.generate(
    samples,
    (i) => 1.2 + 7.3 * math.pow(1 - i / (samples - 1), .6),
  );
  static final _distances = List<double>.generate(
    samples,
    (i) => length * (i / (samples - 1)),
  );
  static final _waves = List<double>.generate(
    samples,
    (i) => 3 + 9 * math.sin(i / (samples - 1) * math.pi),
  );
  double radiusAt(int i) => _radii[i];

  List<SnakePoint> _body() {
    final speed = math.sqrt(vx * vx + vy * vy);
    final dx = vx / speed, dy = vy / speed;
    return List.generate(samples, (i) {
      final distance = _distances[i];
      final wave = math.sin(age * 5.5 - distance * .073 + phase) * _waves[i];
      return (
        x: x - dx * distance - dy * wave,
        y: y - dy * distance + dx * wave,
      );
    });
  }

  void step(double dt) {
    if (dt <= 0 || !dt.isFinite) return;
    _previous = points;
    age += dt;
    x += vx * dt;
    y += vy * dt;
    points = _body();
  }

  double? contact(double ax, double ay, double bx, double by) {
    double? first;
    for (var i = 0; i < samples; i++) {
      final before = _previous[i], after = points[i];
      final t = circleContact(
        ax - before.x,
        ay - before.y,
        bx - after.x,
        by - after.y,
        0,
        0,
        7 + radiusAt(i),
      );
      if (t != null && (first == null || t < first)) first = t;
    }
    return first;
  }
}
