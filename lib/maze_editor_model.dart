part of 'laser_maze.dart';

typedef MazeNode = (int, int);

class MazeRoad {
  const MazeRoad(this.from, this.to, this.halfWidth);
  final MazePoint from, to;
  final double halfWidth;
  List<num> toJson() => [from.x, from.y, to.x, to.y, halfWidth];
}

class MazeDraftAnalysis {
  const MazeDraftAnalysis(this.errors, this.path, this.distances);
  final List<String> errors;
  final List<MazeRoad> path;
  final Map<MazeNode, int> distances;
  bool get valid => errors.isEmpty;
}

class CustomMazeDefinition {
  const CustomMazeDefinition({
    required this.name,
    required this.height,
    required this.finish,
    required this.roads,
  });
  final String name;
  final int height;
  final MazePoint finish;
  final List<MazeRoad> roads;
  static const heights = [560, 1120, 2240, 3360, 4480];
  static const launch = MazePoint(180, 480);
  static const starter = CustomMazeDefinition(
    name: 'My laser tower',
    height: 1120,
    finish: MazePoint(280, -480),
    roads: [
      MazeRoad(MazePoint(180, 480), MazePoint(180, 240), 20),
      MazeRoad(MazePoint(180, 240), MazePoint(280, 240), 20),
      MazeRoad(MazePoint(280, 240), MazePoint(280, -480), 20),
    ],
  );

  CustomMazeDefinition copyWith({
    String? name,
    int? height,
    MazePoint? finish,
    List<MazeRoad>? roads,
  }) => CustomMazeDefinition(
    name: name ?? this.name,
    height: height ?? this.height,
    finish: finish ?? this.finish,
    roads: List.unmodifiable(roads ?? this.roads),
  );

  Map<String, Object> toJson() => {
    'version': 1,
    'name': name,
    'height': height,
    'finish': [finish.x, finish.y],
    'roads': roads.map((r) => r.toJson()).toList(),
  };

  factory CustomMazeDefinition.fromJson(Map<String, dynamic> data) {
    if (data['version'] != 1 ||
        data['name'] is! String ||
        !heights.contains(data['height']) ||
        data['roads'] is! List ||
        (data['roads'] as List).length > 300) {
      throw const FormatException('Unsupported editor draft.');
    }
    double number(Object? value) {
      if (value is! num || !value.isFinite)
        throw const FormatException('Invalid coordinate.');
      return value.toDouble();
    }

    final end = data['finish'] as List;
    final roads = (data['roads'] as List).map((row) {
      final values = row as List;
      if (values.length != 5) throw const FormatException('Invalid road.');
      return MazeRoad(
        MazePoint(number(values[0]), number(values[1])),
        MazePoint(number(values[2]), number(values[3])),
        number(values[4]),
      );
    }).toList();
    final result = CustomMazeDefinition(
      name: data['name'] as String,
      height: data['height'] as int,
      finish: MazePoint(number(end[0]), number(end[1])),
      roads: roads,
    );
    if (result._shapeErrors().isNotEmpty)
      throw const FormatException(
        'Draft geometry is outside the editor limits.',
      );
    return result;
  }

  List<String> _shapeErrors() {
    final errors = <String>[];
    if (!heights.contains(height))
      errors.add('Choose a supported canvas height.');
    if (name.trim().isEmpty || name.length > 48)
      errors.add('Use a name between 1 and 48 characters.');
    if (roads.length > 300) errors.add('Use at most 300 road segments.');
    bool pointOk(MazePoint p) =>
        p.x.isFinite &&
        p.y.isFinite &&
        p.x >= 40 &&
        p.x <= 320 &&
        p.y >= 560 - height + 60 &&
        p.y <= 480 &&
        p.x % 10 == 0 &&
        p.y % 10 == 0;
    if (!pointOk(finish))
      errors.add('Place the finish on the grid inside the canvas.');
    for (final road in roads) {
      if (!pointOk(road.from) ||
          !pointOk(road.to) ||
          !road.halfWidth.isFinite ||
          road.halfWidth < 11 ||
          road.halfWidth > 28 ||
          (road.from.x != road.to.x && road.from.y != road.to.y) ||
          (road.from.x == road.to.x && road.from.y == road.to.y)) {
        errors.add(
          'Roads must follow the grid, stay inside the canvas and be 22–56 units wide.',
        );
        break;
      }
    }
    return errors;
  }

  LaserMazeCorridor drawingCorridor({bool finishExit = false}) {
    final road = LaserMazeCorridor();
    road.addLeg(const MazePoint(180, 548), launch, 20, capA: false);
    for (final segment in roads) {
      road.addLeg(segment.from, segment.to, segment.halfWidth, primary: false);
    }
    if (finishExit) {
      final width = roads
          .where(
            (r) =>
                r.from.x == finish.x &&
                r.to.x == finish.x &&
                (r.from.y == finish.y || r.to.y == finish.y),
          )
          .first
          .halfWidth;
      road.addLeg(
        finish,
        MazePoint(finish.x, finish.y - 40),
        width,
        primary: false,
        capB: false,
      );
    }
    road.rebuildWalls();
    return road;
  }

  MazeDraftAnalysis analyze() {
    final errors = _shapeErrors();
    MazeDraftAnalysis failed(String message) =>
        MazeDraftAnalysis([...errors, message], [], {});
    if (errors.isNotEmpty) return MazeDraftAnalysis(errors, [], {});
    if (roads.isEmpty) return failed('Draw a road from START to the finish.');
    final graph = <MazeNode, Map<MazeNode, double>>{};
    for (final road in roads) {
      var node = (road.from.x.toInt(), road.from.y.toInt());
      final end = (road.to.x.toInt(), road.to.y.toInt());
      final dx = (end.$1 - node.$1).sign * 10;
      final dy = (end.$2 - node.$2).sign * 10;
      while (node != end) {
        final next = (node.$1 + dx, node.$2 + dy);
        for (final pair in [(node, next), (next, node)]) {
          final edges = graph.putIfAbsent(pair.$1, () => {});
          edges[pair.$2] = math.max(edges[pair.$2] ?? 0, road.halfWidth);
        }
        node = next;
      }
    }
    const start = (180, 480);
    final end = (finish.x.toInt(), finish.y.toInt());
    if (!graph.containsKey(start))
      return failed('Connect your first road to START at (180, 480).');
    if (!graph.containsKey(end))
      return failed('Place FINISH on a road endpoint.');
    final endEdges = graph[end]!;
    if (endEdges.length != 1 ||
        endEdges.keys.first.$1 != end.$1 ||
        endEdges.keys.first.$2 <= end.$2) {
      return failed(
        'Finish must be the upper end of a vertical road, with no junction at the marker.',
      );
    }
    if (graph.keys.any((p) => p.$2 < end.$2))
      return failed('Put the finish at the highest part of your map.');
    final distances = <MazeNode, int>{end: 0}, queue = <MazeNode>[end];
    for (var head = 0; head < queue.length; head++) {
      for (final next in graph[queue[head]]!.keys) {
        if (distances.containsKey(next)) continue;
        distances[next] = distances[queue[head]]! + 10;
        queue.add(next);
      }
    }
    if (!distances.containsKey(start))
      return failed('START and FINISH are disconnected. Join their roads.');
    if (distances.length != graph.length)
      return failed(
        'Some roads are disconnected. Connect or erase the isolated roads.',
      );
    final path = <MazeRoad>[];
    var node = start;
    while (node != end) {
      final next = graph[node]!.keys.firstWhere(
        (p) => distances[p] == distances[node]! - 10,
      );
      final width = graph[node]![next]!;
      final leg = MazeRoad(
        MazePoint(node.$1.toDouble(), node.$2.toDouble()),
        MazePoint(next.$1.toDouble(), next.$2.toDouble()),
        width,
      );
      if (path.isNotEmpty &&
          path.last.halfWidth == width &&
          ((path.last.from.x == leg.to.x && path.last.to.x == leg.to.x) ||
              (path.last.from.y == leg.to.y && path.last.to.y == leg.to.y))) {
        path[path.length - 1] = MazeRoad(path.last.from, leg.to, width);
      } else {
        path.add(leg);
      }
      node = next;
    }
    final corridor = drawingCorridor(finishExit: true);
    for (final leg in path) {
      if (corridor.firstContact(
            leg.from.x,
            leg.from.y,
            leg.to.x,
            leg.to.y,
            7,
          ) !=
          null) {
        return failed(
          'A turn cannot fit the ball. Widen the road near that turn.',
        );
      }
    }
    return MazeDraftAnalysis([], path, distances);
  }

  String toDart() {
    final check = analyze();
    if (!check.valid) throw StateError(check.errors.join('\n'));
    final escaped = name
        .trim()
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll(r'$', r'\$')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
    String n(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    String point(MazePoint p) => 'MazePoint(${n(p.x)}, ${n(p.y)})';
    return "// Paste inside customMazeLevels in lib/custom_maze_levels.dart.\n"
        "CustomMazeDefinition(\n  name: '$escaped',\n  height: $height,\n"
        "  finish: ${point(finish)},\n  roads: [\n"
        "${roads.map((r) => '    MazeRoad(${point(r.from)}, ${point(r.to)}, ${n(r.halfWidth)}),').join('\n')}\n  ],\n),\n";
  }
}

class MazeEditorHistory {
  MazeEditorHistory(this.value);
  CustomMazeDefinition value;
  final _undo = <CustomMazeDefinition>[], _redo = <CustomMazeDefinition>[];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  void change(CustomMazeDefinition next) {
    _undo.add(value);
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
    value = next;
  }

  void undo() {
    if (canUndo) {
      _redo.add(value);
      value = _undo.removeLast();
    }
  }

  void redo() {
    if (canRedo) {
      _undo.add(value);
      value = _redo.removeLast();
    }
  }
}
