part of 'laser_maze.dart';

class MazeLeg {
  const MazeLeg(
    this.a,
    this.b,
    this.halfWidth,
    this.rect, {
    required this.primary,
    required this.openA,
    required this.openB,
    required this.arcStart,
    required this.arcEnd,
    required this.chunk,
  });
  final MazePoint a, b;
  final MazeRect rect;
  final double halfWidth, arcStart, arcEnd;
  final bool primary, openA, openB;
  final int chunk;
}

class MazeBranch {
  MazeBranch(this.points, this.halfWidth, this.fromArc, this.toArc, this.chunk);
  final List<MazePoint> points;
  final double halfWidth, fromArc, toArc;
  final int chunk;
  double get length {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += LaserMazeCorridor.pointDistance(points[i - 1], points[i]);
    }
    return total;
  }
}

enum MazeStructure {
  returnBend,
  longCrossing,
  shortcut,
  doubleReturn,
  twinFork,
  windingLoop,
}

/// A self-avoiding route on a generously spaced four-column graph. Missing
/// edges are solid land; shortcuts add real cycles, not disconnected drawings.
class _MazePlan {
  _MazePlan(this.cells, this.shortcuts, this.structure);
  final List<int> cells;
  final List<List<int>> shortcuts;
  final MazeStructure structure;
  String get signature =>
      '${cells.join(',')}/${shortcuts.map((s) => s.join(',')).join('/')}';
  int get downCount {
    var count = 0;
    for (var i = 1; i < cells.length; i++) {
      if (cells[i] ~/ 4 > cells[i - 1] ~/ 4) count++;
    }
    return count;
  }

  static _MazePlan generate(math.Random random, MazeStructure structure) {
    final requiredBranches = structure == MazeStructure.twinFork
        ? 2
        : [
            MazeStructure.shortcut,
            MazeStructure.windingLoop,
          ].contains(structure)
        ? 1
        : 0;
    final requiredDown =
        structure == MazeStructure.doubleReturn ||
            structure == MazeStructure.windingLoop
        ? 2
        : 1;
    for (var attempt = 0; attempt < 100; attempt++) {
      final start = 20 + random.nextInt(4), goal = random.nextInt(4);
      final path = <int>[start], used = <int>{start};
      var budget = 1800;
      bool search(int cell, int down) {
        if (--budget <= 0) return false;
        if (cell == goal) {
          if (path.length < 10 || down < requiredDown) return false;
          if (structure == MazeStructure.longCrossing) {
            var longest = 0, straight = 0;
            for (var i = 1; i < path.length; i++) {
              straight = path[i] ~/ 4 == path[i - 1] ~/ 4 ? straight + 1 : 0;
              longest = math.max(longest, straight);
            }
            if (longest < 2) return false;
          }
          return true;
        }
        if (path.length >= 18) return false;
        final row = cell ~/ 4, col = cell % 4;
        final options = <int>[
          if (row > 0) cell - 4,
          if (row < 4) cell + 4,
          if (col > 0) cell - 1,
          if (col < 3) cell + 1,
        ]..shuffle(random);
        for (final next in options) {
          if (used.contains(next) || (next < 4 && next != goal) || next >= 20)
            continue;
          used.add(next);
          path.add(next);
          if (search(next, down + (next ~/ 4 > row ? 1 : 0))) return true;
          path.removeLast();
          used.remove(next);
        }
        return false;
      }

      if (!search(start, 0)) continue;
      final branches = _shortcuts(path, random, requiredBranches);
      if (branches.length < requiredBranches) continue;
      return _MazePlan(List.of(path), branches, structure);
    }
    // Bounded, verified fallback: one descending U and two optional chords.
    const path = [21, 17, 18, 19, 15, 14, 10, 9, 13, 12, 8, 4, 5, 6, 2];
    return _MazePlan(
      List.of(path),
      requiredBranches == 0
          ? []
          : [
              [17, 13],
              if (requiredBranches > 1) [10, 6],
            ],
      structure,
    );
  }

  static List<List<int>> _shortcuts(
    List<int> path,
    math.Random random,
    int count,
  ) {
    if (count == 0) return [];
    final candidates = <List<int>>[];
    final occupied = path.toSet();
    for (var i = 1; i < path.length - 4; i++) {
      for (var j = i + 3; j < path.length - 1; j++) {
        final start = path[i], goal = path[j];
        final queue = <List<int>>[
              [start],
            ],
            seen = <int>{start};
        for (var head = 0; head < queue.length; head++) {
          final route = queue[head], cell = route.last;
          if (cell == goal) {
            if (route.length - 1 <= (j - i) * .6) candidates.add(route);
            break;
          }
          if (route.length >= 4) continue;
          final row = cell ~/ 4, col = cell % 4;
          for (final next in [
            if (row > 1) cell - 4,
            if (row < 4) cell + 4,
            if (col > 0) cell - 1,
            if (col < 3) cell + 1,
          ]) {
            if ((occupied.contains(next) && next != goal) || !seen.add(next))
              continue;
            queue.add([...route, next]);
          }
        }
      }
    }
    candidates.shuffle(random);
    final chosen = <List<int>>[],
        usedInterior = <int>{},
        usedEdges = <String>{};
    for (final candidate in candidates) {
      if (chosen.length >= count) break;
      final interior = candidate.skip(1).take(candidate.length - 2).toSet();
      final edges = <String>{};
      for (var i = 1; i < candidate.length; i++) {
        edges.add(
          '${math.min(candidate[i - 1], candidate[i])}:${math.max(candidate[i - 1], candidate[i])}',
        );
      }
      if (interior.intersection(usedInterior).isNotEmpty ||
          edges.intersection(usedEdges).isNotEmpty)
        continue;
      chosen.add(candidate);
      usedInterior.addAll(interior);
      usedEdges.addAll(edges);
    }
    return chosen;
  }
}

/// Converts a graph into corridors. Grid spacing always exceeds the sum of
/// neighbouring half-widths, preserving the intended solid islands and loops.
void _buildPlan(
  LaserMazeCorridor road,
  _MazePlan plan,
  List<double> columns,
  double bottom,
  double height,
  double wide,
  double narrow,
  int chunk,
) {
  MazePoint point(int cell) =>
      MazePoint(columns[cell % 4], bottom - height + cell ~/ 4 * height / 5);
  final arcs = <int, double>{plan.cells.first: road.pathLength};
  for (var i = 1; i < plan.cells.length; i++) {
    road.addLeg(
      point(plan.cells[i - 1]),
      point(plan.cells[i]),
      wide,
      chunk: chunk,
    );
    arcs[plan.cells[i]] = road.pathLength;
  }
  for (final shortcut in plan.shortcuts) {
    road.addBranch(
      shortcut.map(point).toList(),
      narrow,
      arcs[shortcut.first]!,
      arcs[shortcut.last]!,
      chunk: chunk,
    );
  }
}

class LaserMazeRoute extends LaserMazeCorridor {
  LaserMazeRoute(int number) : number = number.clamp(1, count) {
    if (this.number > 20) {
      _buildCustom(customMazeLevels[this.number - 21]);
      return;
    }
    final random = math.Random(72031 + this.number * 997);
    if (this.number > 10) {
      _buildExpert(random);
      return;
    }
    halfWidth = 26 - (this.number - 1) * .5;
    structure = structures[this.number - 1];
    final plan = _MazePlan.generate(random, structure);
    final columns = [
      60.0,
      136.0 + random.nextDouble() * 8,
      216.0 + random.nextDouble() * 8,
      300.0,
    ];
    final entry = MazePoint(columns[plan.cells.first % 4], entryY);
    openStart = openFinish = true;
    addLeg(
      const MazePoint(180, bottomY),
      const MazePoint(180, entryY),
      halfWidth,
      capA: false,
    );
    addLeg(const MazePoint(180, entryY), entry, halfWidth);
    _buildPlan(
      this,
      plan,
      columns,
      entryY,
      entryY - 96,
      halfWidth,
      15 - (this.number - 1) * .2,
      0,
    );
    addLeg(
      centers.last,
      MazePoint(centers.last.x, topY),
      halfWidth,
      capB: false,
    );
    rebuildWalls();
  }
  void _buildExpert(math.Random random) {
    final difficulty = number - 11;
    halfWidth = 19 - difficulty * .5;
    structure = MazeStructure.values[difficulty % MazeStructure.values.length];
    openStart = openFinish = true;
    addLeg(
      const MazePoint(180, bottomY),
      const MazePoint(180, entryY),
      halfWidth,
      capA: false,
    );
    var bottom = entryY;
    for (var section = 0; section < 3 + difficulty ~/ 2; section++) {
      final family = MazeStructure
          .values[(difficulty + section * 5) % MazeStructure.values.length];
      final plan = _MazePlan.generate(random, family);
      final columns = [
        60.0,
        132 + random.nextDouble() * 14,
        212 + random.nextDouble() * 14,
        300.0,
      ];
      final height = 420 + random.nextDouble() * 100;
      addLeg(
        centers.last,
        MazePoint(columns[plan.cells.first % 4], bottom),
        halfWidth,
      );
      _buildPlan(
        this,
        plan,
        columns,
        bottom,
        height,
        halfWidth,
        13 - difficulty * .15,
        section,
      );
      bottom -= height;
    }
    routeTop = bottom - 72;
    addLeg(
      centers.last,
      MazePoint(centers.last.x, routeTop),
      halfWidth,
      capB: false,
    );
    rebuildWalls();
  }

  LaserMazeRoute.custom(CustomMazeDefinition definition) : number = 0 {
    _buildCustom(definition);
  }
  CustomMazeDefinition? _custom;
  Map<MazeNode, int> _customDistances = {};
  void _buildCustom(CustomMazeDefinition definition) {
    final check = definition.analyze();
    if (!check.valid) throw ArgumentError(check.errors.join('\n'));
    _custom = definition;
    _customDistances = check.distances;
    halfWidth = check.path.last.halfWidth;
    structure = MazeStructure.windingLoop;
    routeTop = definition.finish.y - 40;
    openStart = openFinish = true;
    addLeg(
      const MazePoint(180, bottomY),
      CustomMazeDefinition.launch,
      20,
      capA: false,
    );
    for (final road in check.path) addLeg(road.from, road.to, road.halfWidth);
    addLeg(
      definition.finish,
      MazePoint(definition.finish.x, routeTop),
      halfWidth,
      capB: false,
    );
    for (final road in definition.roads) {
      addLeg(road.from, road.to, road.halfWidth, primary: false);
    }
    rebuildWalls();
  }

  @override
  double progressAt(double x, double y) {
    if (_custom == null) return super.progressAt(x, y);
    var nearest = double.infinity, remaining = 0.0;
    final gx = (x / 10).round() * 10, gy = (y / 10).round() * 10;
    // Only nearby road nodes can be closest while the ball is on the road.
    // This bounds authored-map progress work even for an eight-screen maze.
    for (var dx = -50; dx <= 50; dx += 10) {
      for (var dy = -50; dy <= 50; dy += 10) {
        final nx = gx + dx, ny = gy + dy;
        final value = _customDistances[(nx, ny)];
        if (value == null) continue;
        final distance = math.sqrt(math.pow(x - nx, 2) + math.pow(y - ny, 2));
        if (distance < nearest) {
          nearest = distance;
          remaining = value + distance;
        }
      }
    }
    if (!nearest.isFinite) return 0;
    final total = _customDistances[(180, 480)]! + 39;
    return (1 - remaining / total).clamp(0.0, 1.0);
  }

  static int get count => 20 + customMazeLevels.length;
  static const bottomY = 548.0, entryY = 480.0, topY = 24.0;
  static List<String> get names => [
    ..._builtInNames,
    ...customMazeLevels.map((l) => l.name),
  ];
  static const _builtInNames = [
    'Return bend',
    'Long crossing',
    'Split decision',
    'Double descent',
    'Twin forks',
    'The winding loop',
    'Deep return',
    'Crossroads',
    'Sidewinder',
    'Final labyrinth',
    'The ascent',
    'Broken staircase',
    'Needle tower',
    'False summit',
    'Serpent spire',
    'Crossfire climb',
    'Razor switchbacks',
    'Vertigo',
    'The long ordeal',
    'Skyline gauntlet',
  ];
  static const structures = [
    MazeStructure.returnBend,
    MazeStructure.longCrossing,
    MazeStructure.shortcut,
    MazeStructure.doubleReturn,
    MazeStructure.twinFork,
    MazeStructure.windingLoop,
    MazeStructure.doubleReturn,
    MazeStructure.twinFork,
    MazeStructure.longCrossing,
    MazeStructure.windingLoop,
  ];
  final int number;
  double routeTop = topY;
  bool get tall =>
      _custom != null ? finishLineY < LaserMazeCorridor.finishY : number > 10;
  double get finishLineY => _custom?.finish.y ?? routeTop + 20;
  double get mapHeight => bottomY - routeTop + 24;
  late final double halfWidth;
  late final MazeStructure structure;
  String get name => _custom?.name ?? names[number - 1];
  double get finishX => centers.last.x;
  int get turns => legs.where((l) => l.primary && l.a.y == l.b.y).length;
  @override
  double get finishArc => pathLength - 20;
  @override
  double get startArc => bottomY - LaserMazeCorridor.startY;
}

class MazeChunk {
  const MazeChunk(
    this.id,
    this.bottom,
    this.top,
    this.structure,
    this.signature,
  );
  final int id;
  final double bottom, top;
  final MazeStructure structure;
  final String signature;
}

class EndlessMaze extends LaserMazeCorridor {
  EndlessMaze({int? seed}) : _random = math.Random(seed) {
    openStart = true;
    addLeg(
      const MazePoint(180, 548),
      const MazePoint(180, firstTurnY),
      halfWidthAt(0),
      capA: false,
    );
    extendTo(0);
  }
  static const firstTurnY = 440.0, ramp = 6000.0;
  final math.Random _random;
  final chunks = <MazeChunk>[];
  final _bag = <MazeStructure>[], _recent = <String>[];
  MazeStructure? _lastStructure;
  double _lane = 180, _topY = firstTurnY;
  int _serial = 0, prunedLegs = 0;
  double get lane => _lane;
  double get topY => _topY;
  double get climbed => 548 - _topY;
  static double halfWidthAt(double climbed) =>
      26 - 5 * (climbed / ramp).clamp(0.0, 1.0);
  static double legHeightAt(double climbed) =>
      108 - 20 * (climbed / ramp).clamp(0.0, 1.0);

  void extendTo(double aheadY, {double? behindY}) {
    var changed = false;
    while (_topY > aheadY) {
      if (_bag.isEmpty) {
        _bag.addAll(MazeStructure.values);
        _bag.shuffle(_random);
        if (_bag.last == _lastStructure) {
          final first = _bag.first;
          _bag[0] = _bag.last;
          _bag[_bag.length - 1] = first;
        }
      }
      final structure = _bag.removeLast();
      _lastStructure = structure;
      var plan = _MazePlan.generate(_random, structure);
      for (
        var retry = 0;
        retry < 8 && _recent.contains(plan.signature);
        retry++
      ) {
        plan = _MazePlan.generate(_random, structure);
      }
      _recent.add(plan.signature);
      if (_recent.length > 8) _recent.removeAt(0);
      final columns = [
        60.0,
        132.0 + _random.nextDouble() * 14,
        212.0 + _random.nextDouble() * 14,
        300.0,
      ];
      final wide = halfWidthAt(climbed), narrow = math.max(13.0, wide - 11);
      final height =
          legHeightAt(climbed) * 5 * (.96 + _random.nextDouble() * .12);
      final entryX = columns[plan.cells.first % 4];
      final id = _serial++;
      addLeg(
        MazePoint(_lane, _topY),
        MazePoint(entryX, _topY),
        wide,
        chunk: id,
      );
      _buildPlan(this, plan, columns, _topY, height, wide, narrow, id);
      chunks.add(
        MazeChunk(id, _topY, _topY - height, structure, plan.signature),
      );
      _lane = columns[plan.cells.last % 4];
      _topY -= height;
      changed = true;
    }
    if (behindY != null) {
      final stale = chunks
          .where((c) => c.top > behindY)
          .map((c) => c.id)
          .toSet();
      if (stale.isNotEmpty) {
        if (stale.contains(0)) stale.add(-1);
        prunedLegs += legs.where((l) => stale.contains(l.chunk)).length;
        dropChunks(stale);
        chunks.removeWhere((c) => stale.contains(c.id));
        changed = true;
      }
    }
    if (changed) rebuildWalls();
  }

  @override
  double progressAt(double x, double y) => 0;
}
