import 'dart:math' as math;
import 'game.dart';
import 'spiders.dart';
import 'rewards.dart';

/// Reproducible scattered boards; target order is independent of height.
class ClassicLevels {
  static const count = 50;
  static int requiredStars(int level) => (level.clamp(1, count) - 1) * 2;
  static bool isUnlocked(int level, int stars) =>
      level >= 1 && level <= count && stars >= requiredStars(level);
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
    'Silken threshold',
    'Quiet legs',
    'The watchful corner',
    'Thread crossing',
    'First bite',
    'Two keepers',
    'Dust and silk',
    'Hidden courtyard',
    'Tangled brass',
    'Patient hunters',
    'The long web',
    'Narrow escape',
    'Three sentinels',
    'Silk labyrinth',
    'Midnight patrol',
    'Crossed territories',
    'The gathering',
    'Last safe passage',
    'Widow gallery',
    'Heart of the web',
  ];
  static List<Hole> build(int number, {int? dailySeed}) {
    final level = number.clamp(1, count);
    final random = dailySeed == null
        ? math.Random(1907 + level * 811)
        : DailyRandom(dailySeed);
    final slots = level <= 5
        ? [9, 7, 8, 5, 6, 3, 4, 1, 2, 0]
        : ([for (var i = 0; i < 9; i++) i]..shuffle(random));
    if (level > 5) slots.insert(0, 9);
    final result = <Hole>[];
    for (var i = 0; i < 10; i++) {
      for (var attempt = 0; attempt < 1000; attempt++) {
        final x = 44 + random.nextDouble() * 272;
        final y = 54 + slots[i] * 44 + random.nextDouble() * 20 - 10;
        if (result.isNotEmpty && (x - result.last.x).abs() < 75) continue;
        if (result.any(
          (h) => math.pow(h.x - x, 2) + math.pow(h.y - y, 2) < 52 * 52,
        ))
          continue;
        result.add(Hole(x, y, target: i + 1));
        break;
      }
    }
    // Never ship an incomplete sequence if a future daily seed exhausts placement.
    if (result.length != 10) return List<Hole>.of(BalanceGame.holes);
    final trapCount = level <= 30 ? 4 + level : 26 + (level - 31) ~/ 3;
    for (
      var attempt = 0;
      attempt < 3000 && result.length < 10 + trapCount;
      attempt++
    ) {
      final x = 34 + random.nextDouble() * 292;
      final y = 36 + random.nextDouble() * 442;
      if (result.every(
        (h) => math.pow(h.x - x, 2) + math.pow(h.y - y, 2) > 38 * 38,
      )) {
        result.add(Hole(x, y));
      }
    }
    return result;
  }

  static List<BoardSpider> spidersFor(int level, List<Hole> board) {
    if (level < 31) return [];
    final random = math.Random(8917 + level * 97);
    final result = <BoardSpider>[];
    final wanted = level < 36
        ? 1
        : level < 43
        ? 2
        : 3;
    for (var attempt = 0; attempt < 1200 && result.length < wanted; attempt++) {
      final keeper = (level == 40 || level == 50) && result.isEmpty;
      final radius = 38.0 + (level - 31) * .4 + (keeper ? 10 : 0);
      final x = 52 + random.nextDouble() * 256,
          y = 82 + random.nextDouble() * 336;
      if (board
          .where((h) => h.target > 0)
          .any(
            (h) =>
                math.pow(h.x - x, 2) + math.pow(h.y - y, 2) <
                math.pow(radius + 24, 2),
          ))
        continue;
      if (result.any(
        (s) =>
            math.pow(s.homeX - x, 2) + math.pow(s.homeY - y, 2) <
            math.pow(radius + s.zoneRadius + 30, 2),
      ))
        continue;
      final candidate = BoardSpider(
        x,
        y,
        radius,
        phase: random.nextDouble() * math.pi * 2,
        chaseSpeed: 65 + (level - 31),
        bodyRadius: keeper ? 11 : 6,
      );
      if (!hasSafeRoutes(board, [...result, candidate])) continue;
      result.add(candidate);
    }
    return result;
  }

  static List<BrassCoin> coinsFor(List<Hole> board, List<BoardSpider> spiders) {
    final result = <BrassCoin>[];
    for (final trap in board.where((h) => h.target == 0)) {
      for (var angle = 0; angle < 8; angle++) {
        final x = trap.x + math.cos(angle * math.pi / 4) * 32;
        final y = trap.y + math.sin(angle * math.pi / 4) * 32;
        if (x < 44 || x > 316 || y < 55 || y > 470) continue;
        if (board.any(
          (h) =>
              math.pow(h.x - x, 2) + math.pow(h.y - y, 2) <
              math.pow(h.target > 0 ? 34 : 25, 2),
        ))
          continue;
        if (spiders.any(
          (s) =>
              math.pow(s.homeX - x, 2) + math.pow(s.homeY - y, 2) <
              math.pow(s.zoneRadius + 12, 2),
        ))
          continue;
        if (result.any(
          (c) => math.pow(c.x - x, 2) + math.pow(c.y - y, 2) < 100 * 100,
        ))
          continue;
        result.add(BrassCoin(x, y));
        break;
      }
      if (result.length == 3) break;
    }
    return result;
  }

  static String finaleTitle(int level) => switch (level) {
    10 => 'The light gate',
    20 => 'The wandering eye',
    30 => 'Clockwork trial',
    40 => 'The silk keeper',
    50 => 'Heart of the web',
    _ => '',
  };
  static String finaleRule(int level) => switch (level) {
    10 => 'A red lane warns before the laser fires. Cross while it is dark.',
    20 => 'A marked hole wakes and sweeps sideways. Watch its path.',
    30 => 'Laser lanes and roaming holes take turns. Read each warning.',
    40 =>
      'A larger spider guards an expanded territory. Stay beyond the dashed circle.',
    50 => 'The keeper and its spiders guard the web while laser lanes charge.',
    _ => '',
  };

  /// Check connected space around all targets before accepting a territory.
  static bool hasSafeRoutes(List<Hole> board, List<BoardSpider> spiders) {
    const columns = 51, rows = 82;
    final visited = List<bool>.filled(columns * rows, false);
    final queue = <int>[80 * columns + 25];
    visited[queue.first] = true;
    for (var head = 0; head < queue.length; head++) {
      final cell = queue[head], cx = cell % columns, cy = cell ~/ columns;
      for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nx = cx + dx, ny = cy + dy;
        if (nx < 0 || nx >= columns || ny < 0 || ny >= rows) continue;
        final next = ny * columns + nx;
        if (visited[next]) continue;
        final x = 30 + nx * 6.0, y = 36 + ny * 6.0;
        if (board.any(
              (h) => math.pow(h.x - x, 2) + math.pow(h.y - y, 2) < 14 * 14,
            ) ||
            spiders.any(
              (s) =>
                  math.pow(s.homeX - x, 2) + math.pow(s.homeY - y, 2) <
                  math.pow(s.zoneRadius + 10, 2),
            ))
          continue;
        visited[next] = true;
        queue.add(next);
      }
    }
    return board
        .where((h) => h.target > 0)
        .every(
          (h) => queue.any(
            (cell) =>
                math.pow(30 + (cell % columns) * 6 - h.x, 2) +
                    math.pow(36 + (cell ~/ columns) * 6 - h.y, 2) <
                22 * 22,
          ),
        );
  }
}
