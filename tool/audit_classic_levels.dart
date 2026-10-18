import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:balance_arcade/classic_levels.dart';
import 'classic_level_routes.dart';

/// Snapshot the actual registered definitions for progression review/tools.
/// Run with the project-local Dart SDK; no Flutter engine is needed.
void main(List<String> args) {
  final output = args.isEmpty ? 'artifacts/classic-levels.json' : args.single;
  final levels = [
    for (var i = 0; i < classicLevelDefinitions.length; i++)
      _json(i + 1, classicLevelDefinitions[i]),
  ];
  File(output)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(levels));
  stdout.writeln(
    'Exported ${levels.length} registered Classic levels to $output',
  );
  var unreachable = 0;
  for (final level in levels) {
    final review = level['review'] as Map<String, Object>;
    final missing = review['unreachableTargets'] as List<int>;
    if (missing.isNotEmpty) {
      unreachable += missing.length;
      stdout.writeln('Level ${level['number']}: unreachable targets $missing');
    }
  }
  if (unreachable > 0) exitCode = 1;
}

Map<String, Object> _json(int number, ClassicLevelDefinition level) => {
  'version': 1,
  'number': number,
  'name': level.name,
  'holes': [
    for (final h in level.holes) {'x': h.x, 'y': h.y, 'target': h.target},
  ],
  'spiders': [
    for (final s in level.spiders)
      {
        'x': s.x,
        'y': s.y,
        'zoneRadius': s.zoneRadius,
        'phase': s.phase,
        'chaseSpeed': s.chaseSpeed,
        'bodyRadius': s.bodyRadius,
      },
  ],
  'hazards': [
    for (final h in level.hazards)
      {
        'kind': h.kind.name,
        'warningSeconds': h.warningSeconds,
        'liveSeconds': h.liveSeconds,
        'motion': h.motion.name,
        'orientation': h.orientation.name,
        'radiusX': h.radiusX,
        'radiusY': h.radiusY,
        'period': h.period,
        'phase': h.phase,
        'positions': [
          for (final p in h.positions) {'target': p.target, 'x': p.x, 'y': p.y},
        ],
      },
  ],
  'finaleTitle': level.finaleTitle,
  'finaleRule': level.finaleRule,
  'firstHazardAfter': level.firstHazardAfter,
  'hazardInterval': level.hazardInterval,
  'review': _review(level),
};

Map<String, Object> _review(ClassicLevelDefinition level) {
  final targets = level.holes.where((h) => h.target > 0).toList();
  final traps = level.holes.where((h) => h.target == 0).toList();
  var clearance = double.infinity, longestDetour = 1.0;
  final unreachable = <int>[];
  for (final target in targets) {
    for (final trap in traps) {
      clearance = math.min(
        clearance,
        math.sqrt(
          math.pow(trap.x - target.x, 2) + math.pow(trap.y - target.y, 2),
        ),
      );
    }
    final route = routeToTarget(level, target);
    if (route == null) {
      unreachable.add(target.target);
      continue;
    }
    var length = 0.0;
    for (var i = 1; i < route.length; i++) {
      length +=
          (route[i].$1 - route[i - 1].$1).abs() +
          (route[i].$2 - route[i - 1].$2).abs();
    }
    final direct = (target.x - 180).abs() + (target.y - 493).abs();
    longestDetour = math.max(longestDetour, length / direct);
  }
  return {
    'traps': traps.length,
    'spiders': level.spiders.length,
    'waveTypes': level.hazards.length,
    'minimumTargetTrapClearance': clearance.isFinite ? clearance : 0,
    'longestSpatialDetourRatio': longestDetour,
    'unreachableTargets': unreachable,
    'minimumQuietSeconds': level.hazards.isEmpty
        ? 0
        : level.hazards
              .map(
                (w) => level.hazardInterval - w.warningSeconds - w.liveSeconds,
              )
              .reduce(math.min),
  };
}
