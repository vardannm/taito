import 'dart:math' as math;

part 'maze_routes.dart';
part 'maze_editor_model.dart';
part 'custom_maze_levels.dart';

class MazePoint {
  const MazePoint(this.x, this.y);
  final double x, y;
}

/// One axis-aligned leg of a corridor. The playable road is the union of these,
/// so legs may run vertically or horizontally and may overlap freely.
class MazeRect {
  const MazeRect(this.left, this.top, this.right, this.bottom);
  final double left, top, right, bottom;
  static const _eps = .01;
  bool contains(double x, double y) =>
      x >= left - _eps &&
      x <= right + _eps &&
      y >= top - _eps &&
      y <= bottom + _eps;
  bool spansX(double x) => x > left + _eps && x < right - _eps;
  bool spansY(double y) => y > top + _eps && y < bottom - _eps;
}

class MazeWall {
  const MazeWall(this.a, this.b);
  final MazePoint a, b;
  bool get vertical => a.x == b.x;
}

/// A laser corridor: axis-aligned legs whose union is the road, plus the exact
/// boundary of that union as the deadly wall set. A horizontal leg is an
/// ordinary leg here, so a route can climb, cross sideways and climb again.
class LaserMazeCorridor {
  static const startY = 519.0, finishY = 44.0;
  static const beamRadius = 2.0;
  final rects = <MazeRect>[];
  final centers = <MazePoint>[];
  final walls = <MazeWall>[];
  final legs = <MazeLeg>[];
  final branches = <MazeBranch>[];
  final _lengths = <double>[0];
  bool openStart = false, openFinish = false;

  double get pathLength => _lengths.last;

  /// Arc length already covered by the launch area, and the arc length that
  /// counts as a finished route.
  double get startArc => 0;
  double get finishArc => pathLength;

  /// Adds a leg between two centerline points. Square caps let neighbouring
  /// legs fill each other corner; an uncapped end leaves the road open.
  void addLeg(
    MazePoint a,
    MazePoint b,
    double halfWidth, {
    bool capA = true,
    bool capB = true,
    bool primary = true,
    double? arcStart,
    double? arcEnd,
  }) {
    if (a.x == b.x && a.y == b.y) return;
    assert(a.x == b.x || a.y == b.y);
    if (primary && centers.isEmpty) centers.add(a);
    final horizontal = a.y == b.y;
    final ascending = horizontal ? a.x < b.x : a.y < b.y;
    final lowCap = (ascending ? capA : capB) ? halfWidth : 0.0;
    final highCap = (ascending ? capB : capA) ? halfWidth : 0.0;
    rects.add(
      horizontal
          ? MazeRect(
              math.min(a.x, b.x) - lowCap,
              a.y - halfWidth,
              math.max(a.x, b.x) + highCap,
              a.y + halfWidth,
            )
          : MazeRect(
              a.x - halfWidth,
              math.min(a.y, b.y) - lowCap,
              a.x + halfWidth,
              math.max(a.y, b.y) + highCap,
            ),
    );
    final length = (b.x - a.x).abs() + (b.y - a.y).abs();
    legs.add(
      MazeLeg(
        a,
        b,
        halfWidth,
        rects.last,
        primary: primary,
        openA: !capA,
        openB: !capB,
        arcStart: arcStart ?? _lengths.last,
        arcEnd: arcEnd ?? _lengths.last + length,
      ),
    );
    if (primary) {
      centers.add(b);
      _lengths.add(_lengths.last + length);
    }
  }

  void addBranch(
    List<MazePoint> points,
    double halfWidth,
    double fromArc,
    double toArc,
  ) {
    final branch = MazeBranch(points, halfWidth, fromArc, toArc);
    branches.add(branch);
    var covered = 0.0;
    for (var i = 1; i < points.length; i++) {
      final length = pointDistance(points[i - 1], points[i]);
      addLeg(
        points[i - 1],
        points[i],
        halfWidth,
        primary: false,
        arcStart: fromArc + (toArc - fromArc) * covered / branch.length,
        arcEnd:
            fromArc + (toArc - fromArc) * (covered + length) / branch.length,
      );
      covered += length;
    }
  }

  static double pointDistance(MazePoint a, MazePoint b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

  static double boxDistance(
    double al,
    double at,
    double ar,
    double ab,
    double bl,
    double bt,
    double br,
    double bb,
  ) {
    final dx = math.max(0.0, math.max(al - br, bl - ar));
    final dy = math.max(0.0, math.max(at - bb, bt - ab));
    return math.sqrt(dx * dx + dy * dy);
  }

  double roadDistanceAlong(MazePoint a, MazePoint b) => rects.fold(
    double.infinity,
    (distance, r) => math.min(
      distance,
      boxDistance(
        math.min(a.x, b.x),
        math.min(a.y, b.y),
        math.max(a.x, b.x),
        math.max(a.y, b.y),
        r.left,
        r.top,
        r.right,
        r.bottom,
      ),
    ),
  );

  double centerlineDistanceAlong(MazePoint a, MazePoint b) => legs.fold(
    double.infinity,
    (distance, leg) => math.min(
      distance,
      boxDistance(
        math.min(a.x, b.x),
        math.min(a.y, b.y),
        math.max(a.x, b.x),
        math.max(a.y, b.y),
        math.min(leg.a.x, leg.b.x),
        math.min(leg.a.y, leg.b.y),
        math.max(leg.a.x, leg.b.x),
        math.max(leg.a.y, leg.b.y),
      ),
    ),
  );

  bool circleOverlapsRoad(double x, double y, double radius) =>
      roadDistanceAlong(MazePoint(x, y), MazePoint(x, y)) < radius;

  /// Recomputes the union outline: every leg edge minus the parts that fall
  /// inside another leg. Exact for axis-aligned legs, and cheap at these sizes.
  void rebuildWalls() {
    walls.clear();
    for (var i = 0; i < rects.length; i++) {
      final r = rects[i];
      final leg = legs[i];
      for (var edge = 0; edge < 4; edge++) {
        final vertical = edge < 2;
        bool atEnd(MazePoint p) => switch (edge) {
          0 => p.x == r.left && leg.a.y == leg.b.y,
          1 => p.x == r.right && leg.a.y == leg.b.y,
          2 => p.y == r.top && leg.a.x == leg.b.x,
          _ => p.y == r.bottom && leg.a.x == leg.b.x,
        };
        if ((leg.openA && atEnd(leg.a)) || (leg.openB && atEnd(leg.b)))
          continue;
        final fixed = switch (edge) {
          0 => r.left,
          1 => r.right,
          2 => r.top,
          _ => r.bottom,
        };
        final from = vertical ? r.top : r.left;
        final to = vertical ? r.bottom : r.right;
        final covered = <List<double>>[];
        for (var j = 0; j < rects.length; j++) {
          if (j == i) continue;
          final o = rects[j];
          if (vertical ? !o.spansX(fixed) : !o.spansY(fixed)) continue;
          final low = math.max(from, vertical ? o.top : o.left);
          final high = math.min(to, vertical ? o.bottom : o.right);
          if (high > low) covered.add([low, high]);
        }
        covered.sort((a, b) => a.first.compareTo(b.first));
        var cursor = from;
        for (final span in covered) {
          if (span.first > cursor)
            _addWall(vertical, fixed, cursor, span.first);
          cursor = math.max(cursor, span.last);
        }
        if (cursor < to) _addWall(vertical, fixed, cursor, to);
      }
    }
    final groups = <(bool, double), List<MazeWall>>{};
    for (final wall in walls) {
      groups
          .putIfAbsent((
            wall.vertical,
            wall.vertical ? wall.a.x : wall.a.y,
          ), () => [])
          .add(wall);
    }
    walls.clear();
    for (final entry in groups.entries) {
      final vertical = entry.key.$1, fixed = entry.key.$2;
      final spans =
          entry.value
              .map((w) => vertical ? (w.a.y, w.b.y) : (w.a.x, w.b.x))
              .toList()
            ..sort((a, b) => a.$1.compareTo(b.$1));
      var from = spans.first.$1, to = spans.first.$2;
      for (final span in spans.skip(1)) {
        if (span.$1 <= to + .001) {
          to = math.max(to, span.$2);
        } else {
          _addWall(vertical, fixed, from, to);
          from = span.$1;
          to = span.$2;
        }
      }
      _addWall(vertical, fixed, from, to);
    }
  }

  void _addWall(bool vertical, double fixed, double from, double to) {
    if (to - from < .01) return;
    walls.add(
      vertical
          ? MazeWall(MazePoint(fixed, from), MazePoint(fixed, to))
          : MazeWall(MazePoint(from, fixed), MazePoint(to, fixed)),
    );
  }

  bool contains(double x, double y) => rects.any((rect) => rect.contains(x, y));

  /// Branches interpolate between their junctions on the main route. A short
  /// route and its long detour therefore agree when they reconnect.
  double progressAt(double x, double y) {
    if (finishArc <= startArc) return 0;
    var best = double.infinity, arc = 0.0;
    for (final leg in legs) {
      final dx = leg.b.x - leg.a.x, dy = leg.b.y - leg.a.y;
      final length2 = dx * dx + dy * dy;
      final t = (((x - leg.a.x) * dx + (y - leg.a.y) * dy) / length2).clamp(
        0.0,
        1.0,
      );
      final px = leg.a.x + dx * t - x, py = leg.a.y + dy * t - y;
      final distance = px * px + py * py;
      if (distance < best) {
        best = distance;
        arc = leg.arcStart + (leg.arcEnd - leg.arcStart) * t;
      }
    }
    return ((arc - startArc) / (finishArc - startArc)).clamp(0.0, 1.0);
  }

  /// True when there is still road above the ball, so an automatic climb is
  /// safe. One-finger control uses this to hold height across sideways legs.
  bool canClimb(double x, double y, double clearance) =>
      contains(x, y - clearance);

  /// Earliest swept-circle contact with a laser wall, including its corners.
  double? firstContact(
    double ax,
    double ay,
    double bx,
    double by,
    double radius,
  ) {
    if (!contains(ax, ay)) return 0;
    double? first;
    for (final wall in walls) {
      final t = _capsuleContact(
        ax,
        ay,
        bx,
        by,
        wall.a,
        wall.b,
        radius + beamRadius,
      );
      if (t != null && (first == null || t < first)) first = t;
    }
    return first;
  }

  static double? _capsuleContact(
    double ax,
    double ay,
    double bx,
    double by,
    MazePoint a,
    MazePoint b,
    double radius,
  ) {
    final wx = b.x - a.x, wy = b.y - a.y;
    final length = math.sqrt(wx * wx + wy * wy);
    final tx = wx / length, ty = wy / length;
    final px = ax - a.x, py = ay - a.y;
    final along = px * tx + py * ty, normal = -px * ty + py * tx;
    final vx = bx - ax, vy = by - ay;
    final speedAlong = vx * tx + vy * ty, speedNormal = -vx * ty + vy * tx;
    final closest = along.clamp(0.0, length);
    if ((along - closest) * (along - closest) + normal * normal <=
        radius * radius) {
      return 0;
    }
    double? first;
    if (speedNormal.abs() > 1e-10) {
      for (final edge in [-radius, radius]) {
        final t = (edge - normal) / speedNormal;
        final u = along + speedAlong * t;
        if (t >= 0 &&
            t <= 1 &&
            u >= 0 &&
            u <= length &&
            (first == null || t < first))
          first = t;
      }
    }
    final speed2 = vx * vx + vy * vy;
    if (speed2 > 0) {
      for (final endpoint in [a, b]) {
        final ox = ax - endpoint.x, oy = ay - endpoint.y;
        final dot = ox * vx + oy * vy;
        final c = ox * ox + oy * oy - radius * radius;
        final disc = dot * dot - speed2 * c;
        if (disc < 0) continue;
        final t = (-dot - math.sqrt(disc)) / speed2;
        if (t >= 0 && t <= 1 && (first == null || t < first)) first = t;
      }
    }
    return first;
  }
}

class LaserMazeRun {
  LaserMazeRun(int level) : corridor = LaserMazeRoute(level);
  LaserMazeRun.custom(CustomMazeDefinition definition)
    : corridor = LaserMazeRoute.custom(definition);
  final LaserMazeCorridor corridor;
  LaserMazeRoute? get route =>
      corridor is LaserMazeRoute ? corridor as LaserMazeRoute : null;
  String get name => route?.name ?? 'Custom route';
  bool hitLaser = false, won = false;
  double progress = 0, contactX = 180, contactY = LaserMazeCorridor.startY;
  double contactFraction = 1;
  bool get ended => hitLaser || won;

  void step(double ax, double ay, double bx, double by, double radius) {
    if (ended) return;
    final hit = corridor.firstContact(ax, ay, bx, by, radius);
    final finishY = route?.finishLineY ?? LaserMazeCorridor.finishY;
    var finish = by < ay && ay >= finishY && by <= finishY
        ? (ay - finishY) / (ay - by)
        : null;
    // Only the last leg reaches the finish line: crossing it elsewhere is a
    // wall, not a win.
    if (finish != null &&
        (!corridor.contains(ax + (bx - ax) * finish, finishY) ||
            (ax + (bx - ax) * finish - route!.finishX).abs() >
                route!.halfWidth)) {
      finish = null;
    }
    var until = 1.0;
    if (hit != null && (finish == null || hit <= finish)) {
      hitLaser = true;
      until = hit;
    } else if (finish != null) {
      won = true;
      until = finish;
    }
    contactFraction = until;
    contactX = ax + (bx - ax) * until;
    contactY = ay + (by - ay) * until;
    progress = math.max(progress, corridor.progressAt(contactX, contactY));
    if (won) progress = 1;
  }
}
