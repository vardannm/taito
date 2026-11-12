import 'dart:math' as math;
import 'infinite_progress.dart';

/// A stationary Infinite enemy. Its wind-up stays attached to the scrolling
/// board; released quills travel in world space independently of the camera.
class BoardPorcupine {
  BoardPorcupine(this.x, this.y, {this.heading = 0});

  final double x, y, heading;
  static const bodyRadius = 13.0;
  double? charge;
  int bursts = 0;
  double get burstAngle =>
      heading + bursts * math.pi / InfiniteTuning.quillCount;

  List<PorcupineQuill> burst() {
    final shots = List.generate(InfiniteTuning.quillCount, (i) {
      final angle = burstAngle + i * math.pi * 2 / InfiniteTuning.quillCount;
      return PorcupineQuill(
        x: x + math.cos(angle) * 20,
        y: y + math.sin(angle) * 20,
        angle: angle,
      );
    });
    bursts++;
    charge = null;
    return shots;
  }
}

class PorcupineQuill {
  double arenaStretch = 1;
  PorcupineQuill({required this.x, required this.y, required this.angle});

  double x, y, age = 0;
  final double angle;
  bool consumed = false;
  double _oldX = 0, _oldY = 0;
  bool _stepped = false;
  // The game prunes shots after they leave the viewport. A fixed lifetime
  // makes upward shots vanish mid-board as the camera follows the climb.
  bool get expired => consumed;

  void step(double dt) {
    if (consumed || dt <= 0 || !dt.isFinite) return;
    _oldX = x;
    _oldY = y;
    _stepped = true;
    age += dt;
    x += math.cos(angle) * InfiniteTuning.quillSpeed * dt;
    y += math.sin(angle) * InfiniteTuning.quillSpeed * dt;
  }

  /// Sweep relative motion so fast steering cannot pass through a quill.
  /// The small hit circle leaves the narrow decorative tip forgiving.
  double? contact(double ax, double ay, double bx, double by) {
    if (consumed || !_stepped) return null;
    return circleContact(
      ax - _oldX,
      ay - _oldY,
      bx - x,
      by - y,
      0,
      0,
      7 + InfiniteTuning.quillRadius,
      xScale: arenaStretch,
    );
  }
}
