import 'dart:math' as math;

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
  }) {
    if (centers.isEmpty) centers.add(a);
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
    centers.add(b);
    _lengths.add(
      _lengths.last +
          math.sqrt(math.pow(b.x - a.x, 2) + math.pow(b.y - a.y, 2)),
    );
  }

  /// Recomputes the union outline: every leg edge minus the parts that fall
  /// inside another leg. Exact for axis-aligned legs, and cheap at these sizes.
  void rebuildWalls() {
    walls.clear();
    for (var i = 0; i < rects.length; i++) {
      final r = rects[i];
      final openBottom = openStart && i == 0;
      final openTop = openFinish && i == rects.length - 1;
      for (var edge = 0; edge < 4; edge++) {
        final vertical = edge < 2;
        if (!vertical && (edge == 2 ? openTop : openBottom)) continue;
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
          if (span.first > cursor) _addWall(vertical, fixed, cursor, span.first);
          cursor = math.max(cursor, span.last);
        }
        if (cursor < to) _addWall(vertical, fixed, cursor, to);
      }
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

  /// Drops the first [count] legs, keeping the centerline and its arc lengths
  /// aligned with the remaining road.
  void dropLeadingLegs(int count) {
    if (count <= 0) return;
    rects.removeRange(0, count);
    centers.removeRange(0, count);
    _lengths.removeRange(0, count);
  }

  /// Distance travelled along the centerline, as a fraction of the full route.
  double progressAt(double x, double y) {
    if (finishArc <= startArc) return 0;
    var best = double.infinity, arc = 0.0;
    for (var i = 1; i < centers.length; i++) {
      final a = centers[i - 1], b = centers[i];
      final dx = b.x - a.x, dy = b.y - a.y;
      final length2 = dx * dx + dy * dy;
      final t = length2 == 0
          ? 0.0
          : (((x - a.x) * dx + (y - a.y) * dy) / length2).clamp(0.0, 1.0);
      final px = a.x + dx * t - x, py = a.y + dy * t - y;
      final distance = px * px + py * py;
      if (distance < best) {
        best = distance;
        arc = _lengths[i - 1] + math.sqrt(length2) * t;
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

/// One of the ten hand-built routes. Every route climbs, crosses sideways and
/// climbs again: the turns are real right angles, not a leaning column.
class LaserMazeRoute extends LaserMazeCorridor {
  LaserMazeRoute(int number) : number = number.clamp(1, count) {
    final index = this.number - 1;
    halfWidth = widths[index];
    final lanes = patterns[index];
    final step = (entryY - lastTurnY) / lanes.length;
    openStart = openFinish = true;
    var previous = const MazePoint(180, bottomY);
    addLeg(previous, const MazePoint(180, entryY), halfWidth, capA: false);
    previous = const MazePoint(180, entryY);
    for (var i = 0; i < lanes.length; i++) {
      final turnY = entryY - (i + 1) * step;
      final corner = MazePoint(previous.x, turnY);
      addLeg(previous, corner, halfWidth);
      final lane = MazePoint(180 + lanes[i] * (150 - halfWidth), turnY);
      addLeg(corner, lane, halfWidth);
      previous = lane;
    }
    addLeg(previous, MazePoint(previous.x, topY), halfWidth, capB: false);
    rebuildWalls();
  }
  static const count = 10;
  static const bottomY = 548.0, entryY = 476.0, lastTurnY = 104.0;
  static const topY = 24.0;
  static const names = [
    'First light',
    'Soft turns',
    'Red river',
    'Double bend',
    'Switchback',
    'Lightning lane',
    'Narrow passage',
    'The zigzag',
    'Needle road',
    'Final circuit',
  ];
  static const widths = <double>[40, 38, 37, 35, 34, 32, 31, 29, 28, 26];
  // Lane targets per turn, as a fraction of the free half-width. Signs
  // alternate, so each route is a stack of climb / cross / climb switchbacks.
  static const patterns = <List<double>>[
    [.5, -.5],
    [-.5, .5, 0],
    [.6, -.5, .55],
    [-.6, .45, -.55, .6],
    [.7, -.35, .7, -.6],
    [-.7, .3, -.6, .55, -.45],
    [.8, -.25, .7, -.45, .8],
    [-.8, .2, -.7, .35, -.8, .45],
    [.85, -.15, .8, -.3, .85, -.5],
    [-.9, .25, -.85, .3, -.9, .35],
  ];
  final int number;
  late final double halfWidth;
  String get name => names[number - 1];
  double get finishX => centers.last.x;
  int get turns => patterns[number - 1].length;
  // A run ends at the finish line, a little below the top of the last leg.
  @override
  double get finishArc => pathLength - (LaserMazeCorridor.finishY - topY);
  @override
  double get startArc => bottomY - LaserMazeCorridor.startY;
}

/// The endless corridor: the same right-angled legs, generated forever and
/// tightening as the climb goes on.
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
  static const firstTurnY = 440.0, ramp = 2400.0;
  final math.Random _random;
  double _lane = 180, _topY = firstTurnY;
  int _direction = 1, prunedLegs = 0;
  double get lane => _lane;
  double get topY => _topY;
  double get climbed => 548 - _topY;

  static double halfWidthAt(double climbed) =>
      40 - 14 * (climbed / ramp).clamp(0.0, 1.0);
  static double legHeightAt(double climbed) =>
      120 - 45 * (climbed / ramp).clamp(0.0, 1.0);

  /// Grows the corridor until it covers [aheadY] and drops the legs left below
  /// [behindY], so a long climb keeps a constant amount of live geometry.
  void extendTo(double aheadY, {double? behindY}) {
    var changed = false;
    while (_topY > aheadY) {
      final halfWidth = halfWidthAt(climbed);
      final legHeight =
          legHeightAt(climbed) * (.85 + _random.nextDouble() * .3);
      final turnY = _topY - legHeight;
      addLeg(MazePoint(_lane, _topY), MazePoint(_lane, turnY), halfWidth);
      // Switch sides most of the time: switchbacks, not a slow drift.
      if (_random.nextDouble() < .78) _direction = -_direction;
      final low = 30 + halfWidth, high = 330 - halfWidth;
      final travel = 70 + _random.nextDouble() * (110 - halfWidth);
      var next = (_lane + _direction * travel).clamp(low, high);
      if ((next - _lane).abs() < 60) {
        _direction = -_direction;
        next = (_lane + _direction * travel).clamp(low, high);
      }
      addLeg(MazePoint(_lane, turnY), MazePoint(next, turnY), halfWidth);
      _lane = next;
      _topY = turnY;
      changed = true;
    }
    if (behindY != null) {
      final stale = rects.indexWhere((rect) => rect.top <= behindY);
      if (stale > 0) {
        prunedLegs += stale;
        dropLeadingLegs(stale);
        changed = true;
      }
    }
    if (changed) rebuildWalls();
  }

  @override
  double progressAt(double x, double y) => 0;
}

class LaserMazeRun {
  LaserMazeRun(int level) : corridor = LaserMazeRoute(level);
  LaserMazeRun.endless({int? seed}) : corridor = EndlessMaze(seed: seed);
  final LaserMazeCorridor corridor;
  bool get endless => corridor is EndlessMaze;
  LaserMazeRoute? get route =>
      corridor is LaserMazeRoute ? corridor as LaserMazeRoute : null;
  String get name => route?.name ?? 'Endless climb';
  bool hitLaser = false, won = false;
  double progress = 0, contactX = 180, contactY = LaserMazeCorridor.startY;
  double contactFraction = 1;
  bool get ended => hitLaser || won;

  /// Keeps the endless corridor generated above the ball and trimmed below it.
  void ensure(double ballY) {
    final maze = corridor;
    if (maze is EndlessMaze) {
      maze.extendTo(ballY - 620, behindY: ballY + 360);
    }
  }

  void step(double ax, double ay, double bx, double by, double radius) {
    if (ended) return;
    final hit = corridor.firstContact(ax, ay, bx, by, radius);
    const finishY = LaserMazeCorridor.finishY;
    var finish = !endless && by < ay && ay >= finishY && by <= finishY
        ? (ay - finishY) / (ay - by)
        : null;
    // Only the last leg reaches the finish line: crossing it elsewhere is a
    // wall, not a win.
    if (finish != null &&
        !corridor.contains(ax + (bx - ax) * finish, finishY)) {
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
