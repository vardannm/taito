import 'dart:math' as math;

class MazePoint {
  const MazePoint(this.x, this.y);
  final double x, y;
}

class LaserMazeRoute {
  LaserMazeRoute(int number) : number = number.clamp(1, count) {
    final amplitude = 24 + this.number * 4.6;
    halfWidth = 48 - (this.number - 1) * 1.8;
    centers = List.unmodifiable([
      const MazePoint(180, 548),
      const MazePoint(180, 476),
      for (var i = 0; i < patterns[this.number - 1].length; i++)
        MazePoint(
          180 + patterns[this.number - 1][i] * amplitude,
          408 - i * 68.0,
        ),
      const MazePoint(180, 64),
      const MazePoint(180, 24),
    ]);
    leftWall = List.unmodifiable(
      centers.map((p) => MazePoint(p.x - halfWidth, p.y)),
    );
    rightWall = List.unmodifiable(
      centers.map((p) => MazePoint(p.x + halfWidth, p.y)),
    );
  }
  static const count = 10, startY = 519.0, finishY = 44.0;
  static const beamRadius = 2.0;
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
  static const patterns = <List<double>>[
    [-.6, -.4, .4, .6, .2],
    [.7, .4, -.6, -.4, .5],
    [-.8, -.1, .8, .2, -.7],
    [.8, -.6, -.8, .6, .8],
    [-1, .8, .3, -.9, .6],
    [.9, -.9, .8, -.6, .9],
    [-.8, .9, -.6, .9, -.8],
    [1, -1, .9, -.9, .7],
    [-1, .9, -.9, 1, -.8],
    [1, -.95, 1, -1, .9],
  ];
  final int number;
  late final double halfWidth;
  late final List<MazePoint> centers, leftWall, rightWall;
  String get name => names[number - 1];

  double centerAt(double y) {
    for (var i = 1; i < centers.length; i++) {
      final a = centers[i - 1], b = centers[i];
      if (y >= b.y) {
        final t = ((a.y - y) / (a.y - b.y)).clamp(0.0, 1.0);
        return a.x + (b.x - a.x) * t;
      }
    }
    return centers.last.x;
  }

  bool contains(double x, double y) =>
      y >= centers.last.y &&
      y <= centers.first.y &&
      (x - centerAt(y)).abs() < halfWidth;

  /// Earliest swept-circle contact with a red wall, including rounded corners.
  double? firstContact(
    double ax,
    double ay,
    double bx,
    double by,
    double radius,
  ) {
    if (!contains(ax, ay)) return 0;
    double? first;
    for (final wall in [leftWall, rightWall]) {
      for (var i = 1; i < wall.length; i++) {
        final t = _capsuleContact(
          ax,
          ay,
          bx,
          by,
          wall[i - 1],
          wall[i],
          radius + beamRadius,
        );
        if (t != null && (first == null || t < first)) first = t;
      }
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
  LaserMazeRun(int level) : route = LaserMazeRoute(level);
  final LaserMazeRoute route;
  bool hitLaser = false, won = false;
  double progress = 0, contactX = 180, contactY = LaserMazeRoute.startY;
  double contactFraction = 1;
  bool get ended => hitLaser || won;

  void step(double ax, double ay, double bx, double by, double radius) {
    if (ended) return;
    final hit = route.firstContact(ax, ay, bx, by, radius);
    final finish =
        by < ay && ay >= LaserMazeRoute.finishY && by <= LaserMazeRoute.finishY
        ? (ay - LaserMazeRoute.finishY) / (ay - by)
        : null;
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
    progress = math.max(
      progress,
      ((LaserMazeRoute.startY - contactY) /
              (LaserMazeRoute.startY - LaserMazeRoute.finishY))
          .clamp(0.0, 1.0),
    );
    if (won) progress = 1;
  }
}
