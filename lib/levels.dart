import 'dart:math' as math;
import 'game.dart';

/// Thirty authored route profiles. Trap placement is deterministic per level.
class ClassicLevels {
  static const names = [
    'First steps',
    'Gentle bend',
    'Wide valley',
    'Little wave',
    'Open crossing',
    'Left bank',
    'Right bank',
    'Switchback',
    'Twin bays',
    'Long sweep',
    'Slalom',
    'Crescent',
    'Hourglass',
    'Stairway',
    'Crosswind',
    'Narrow river',
    'Double switch',
    'Broken rhythm',
    'Inside line',
    'Outward bound',
    'Needlework',
    'Tidal turn',
    'Chicane',
    'Off balance',
    'Brass passage',
    'Razor bend',
    'Three turns',
    'Pendulum',
    'Final ascent',
    'Masterwork',
  ];
  static const routes = <List<double>>[
    [160, 180, 200, 180, 160],
    [140, 150, 180, 210, 220],
    [210, 180, 140, 170, 210],
    [150, 190, 160, 200, 180],
    [140, 170, 200, 220, 180],
    [100, 120, 160, 130, 110],
    [250, 230, 190, 220, 250],
    [120, 210, 130, 220, 150],
    [110, 150, 230, 190, 120],
    [100, 140, 200, 250, 200],
    [100, 230, 120, 240, 130],
    [120, 200, 250, 200, 120],
    [110, 180, 250, 180, 110],
    [90, 130, 180, 220, 260],
    [230, 130, 200, 100, 220],
    [95, 180, 260, 170, 105],
    [100, 240, 110, 250, 120],
    [140, 260, 200, 90, 170],
    [250, 190, 110, 160, 240],
    [170, 90, 180, 270, 190],
    [90, 250, 110, 260, 100],
    [250, 180, 90, 170, 270],
    [110, 240, 180, 90, 250],
    [260, 120, 200, 90, 240],
    [90, 190, 270, 160, 100],
    [80, 250, 110, 270, 100],
    [250, 90, 240, 110, 260],
    [90, 260, 100, 250, 90],
    [260, 180, 80, 200, 270],
    [85, 255, 110, 270, 90],
  ];
  static List<Hole> build(int number) {
    final level = number.clamp(1, 30);
    final route = routes[level - 1];
    final targets = List<Hole>.generate(10, (i) {
      final t = i / 9 * 4;
      final k = math.min(t.floor(), 3);
      return Hole(
        route[k] + (route[k + 1] - route[k]) * (t - k),
        462 - i * 46,
        target: i + 1,
      );
    });
    final result = <Hole>[...targets];
    final random = math.Random(1907 + level * 811);
    final count = 4 + level;
    final clearance = 65 - level * .8;
    for (
      var attempt = 0;
      attempt < 2000 && result.length < 10 + count;
      attempt++
    ) {
      final x = 30 + random.nextDouble() * 300;
      final y = 36 + random.nextDouble() * 448;
      // Reserve a continuous route through the target sequence and launch.
      final path = [const Hole(180, 519), ...targets];
      var nearRoute = false;
      for (var i = 1; i < path.length; i++) {
        final a = path[i - 1], b = path[i];
        final t = ((y - a.y) / (b.y - a.y)).clamp(0.0, 1.0);
        if ((y - (a.y + (b.y - a.y) * t)).abs() < 28 &&
            (x - (a.x + (b.x - a.x) * t)).abs() < clearance)
          nearRoute = true;
      }
      if (!nearRoute &&
          result.every(
            (h) => math.pow(h.x - x, 2) + math.pow(h.y - y, 2) > 30 * 30,
          )) {
        result.add(Hole(x, y));
      }
    }
    return result;
  }
}
