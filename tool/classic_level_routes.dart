import 'dart:typed_data';
import 'package:balance_arcade/classic_levels.dart';
import 'package:balance_arcade/game.dart';

/// Conservative spatial check, not a human dexterity/difficulty estimate.
/// Captures return to launch. Other numbered holes remain obstacles, and
/// patrol territories remain forbidden with 12 units beyond the drawn circle.
List<(double, double)>? routeToTarget(
  ClassicLevelDefinition level,
  Hole target, {
  double holeClearance = 16,
}) {
  const columns = 77, rows = 124, step = 4.0;
  const start =
      117 * columns + 38; // (180, 492), beside real launch (180, 493).
  final previous = Int32List(columns * rows)..fillRange(0, columns * rows, -1);
  final blocked = Uint8List(columns * rows);
  for (var cell = 0; cell < blocked.length; cell++) {
    final x = 28 + cell % columns * step, y = 24 + cell ~/ columns * step;
    for (final h in level.holes) {
      if (identical(h, target)) continue;
      final dx = x - h.x, dy = y - h.y;
      if (dx * dx + dy * dy < holeClearance * holeClearance) {
        blocked[cell] = 1;
        break;
      }
    }
    if (blocked[cell] != 0) continue;
    for (final s in level.spiders) {
      final dx = x - s.x, dy = y - s.y, radius = s.zoneRadius + 12;
      if (dx * dx + dy * dy < radius * radius) {
        blocked[cell] = 1;
        break;
      }
    }
  }
  if (blocked[start] != 0) return null;
  final queue = <int>[start];
  previous[start] = start;
  for (var head = 0; head < queue.length; head++) {
    final cell = queue[head], cx = cell % columns, cy = cell ~/ columns;
    final x = 28 + cx * step, y = 24 + cy * step;
    final dx = x - target.x, dy = y - target.y;
    if (dx * dx + dy * dy < 6 * 6) {
      final route = <(double, double)>[(target.x, target.y)];
      var at = cell;
      while (at != start) {
        route.add((28 + at % columns * step, 24 + at ~/ columns * step));
        at = previous[at];
      }
      route.add((180, 493));
      return route.reversed.toList();
    }
    for (final (nx, ny) in [
      (cx - 1, cy),
      (cx + 1, cy),
      (cx, cy - 1),
      (cx, cy + 1),
    ]) {
      if (nx < 0 || nx >= columns || ny < 0 || ny >= rows) continue;
      final next = ny * columns + nx;
      if (previous[next] != -1 || blocked[next] != 0) continue;
      previous[next] = cell;
      queue.add(next);
    }
  }
  return null;
}
