import 'dart:math' as math;
import 'infinite_progress.dart';
import 'encounter_director.dart';

typedef EnemyPoint = ({double x, double y});

enum LateEnemyKind { beetle, cricket, moth, scorpion, seedSpitter }

extension LateEnemyDetails on LateEnemyKind {
  EncounterEnemy get encounterKind => EncounterEnemy.values[index + 1];
  String get name => switch (this) {
    LateEnemyKind.beetle => 'BOMBARDIER BEETLE',
    LateEnemyKind.cricket => 'RICOCHET CRICKET',
    LateEnemyKind.moth => 'MOTH',
    LateEnemyKind.scorpion => 'SCORPION',
    LateEnemyKind.seedSpitter => 'SEED SPITTER',
  };
  String get hint => switch (this) {
    LateEnemyKind.beetle => 'Leave the landing circle',
    LateEnemyKind.cricket => 'Watch the wall rebound',
    LateEnemyKind.moth => 'Slip between the curved streams',
    LateEnemyKind.scorpion => 'Step away from the laser aim line',
    LateEnemyKind.seedSpitter => 'Watch the seed split into three',
  };
}

enum LateShotKind { bomb, acid, ricochet, moth, laser, seed, shard }

/// These visitors perch on the rails (the moth hovers above the play area).
/// Warnings and flying shots use board/screen coordinates, independent of the
/// scrolling terrain. Acid attaches to the terrain on impact and scrolls away.
/// Every shot locks its aim when the encounter starts; none homes on the ball.
class LateEnemyEncounter {
  LateEnemyEncounter({
    required this.kind,
    required this.origin,
    required this.target,
  }) {
    final dx = target.x - origin.x, dy = target.y - origin.y;
    final length = math.max(1.0, math.sqrt(dx * dx + dy * dy));
    final direction = (x: dx / length, y: dy / length);
    void straight(
      LateShotKind type,
      double speed,
      double delay,
      double life, {
      EnemyPoint? start,
      EnemyPoint? aim,
      LateEnemyShot? parent,
    }) {
      final dir = aim ?? direction;
      shots.add(
        LateEnemyShot(
          kind: type,
          origin: start ?? origin,
          velocity: (x: dir.x * speed, y: dir.y * speed),
          delay: delay,
          life: life,
          parent: parent,
        ),
      );
    }

    const warning = InfiniteTuning.lateEnemyWarning;
    switch (kind) {
      case LateEnemyKind.beetle:
        shots.add(
          LateEnemyShot(
            kind: LateShotKind.bomb,
            origin: origin,
            velocity: (x: dx / .95, y: dy / .95),
            delay: warning,
            life: .95,
          ),
        );
        shots.add(
          LateEnemyShot(
            kind: LateShotKind.acid,
            origin: target,
            velocity: (x: 0, y: 0),
            delay: warning + .95,
            life: InfiniteTuning.acidLifeSeconds,
          ),
        );
      case LateEnemyKind.cricket:
        final wall = origin.x < 180 ? 332.0 : 28.0;
        final rx = wall * 2 - target.x - origin.x;
        final distance = math.sqrt(rx * rx + dy * dy);
        final vx = rx / distance * InfiniteTuning.ricochetSpeed;
        final bounceTime = (wall - origin.x) / vx;
        shots.add(
          LateEnemyShot(
            kind: LateShotKind.ricochet,
            origin: origin,
            velocity: (x: vx, y: dy / distance * InfiniteTuning.ricochetSpeed),
            delay: warning,
            // Vanish at the next wall: exactly one rebound, never a second.
            life: math.min(4.0, bounceTime + 304 / vx.abs()),
            bounceTime: bounceTime,
          ),
        );
      case LateEnemyKind.moth:
        for (var i = 0; i < 3; i++) {
          for (final side in [-1.0, 1.0]) {
            shots.add(
              LateEnemyShot(
                kind: LateShotKind.moth,
                origin: origin,
                velocity: (x: direction.x * 112, y: direction.y * 112),
                delay: warning + i * .22,
                life: 2.8,
                curve: side * 58,
              ),
            );
          }
        }
      case LateEnemyKind.scorpion:
        // The full ray is fixed before the warning starts. Stop at the board
        // edge, using the same finite segment for drawing and swept contact.
        final rayX = direction.x;
        final rayY = dx == 0 && dy == 0 ? 1.0 : direction.y;
        var rayLength = rayY > 0
            ? (537 - origin.y) / rayY
            : rayY < 0
            ? (42 - origin.y) / rayY
            : double.infinity;
        if (rayX.abs() > 1e-9) {
          final edge = rayX > 0 ? 336.0 : 24.0;
          rayLength = math.min(rayLength, (edge - origin.x) / rayX);
        }
        rayLength = math.max(0.0, rayLength);
        shots.add(
          LateEnemyShot(
            kind: LateShotKind.laser,
            origin: origin,
            velocity: (x: 0, y: 0),
            delay: warning,
            life: InfiniteTuning.scorpionLaserSeconds,
            beamEnd: (
              x: origin.x + rayX * rayLength,
              y: origin.y + rayY * rayLength,
            ),
          ),
        );
      case LateEnemyKind.seedSpitter:
        const splitTime = .9, seedSpeed = 95.0;
        straight(LateShotKind.seed, seedSpeed, warning, splitTime);
        final seed = shots.last;
        final split = seed.positionAt(splitTime);
        final angle = math.atan2(direction.y, direction.x);
        for (final spread in [-.48, 0.0, .48]) {
          straight(
            LateShotKind.shard,
            130,
            warning + splitTime,
            2.4,
            start: split,
            aim: (x: math.cos(angle + spread), y: math.sin(angle + spread)),
            parent: seed,
          );
        }
    }
    attackEnd = shots.map((s) => s.delay + s.life).reduce(math.max);
  }

  final LateEnemyKind kind;
  final EnemyPoint origin, target;
  final shots = <LateEnemyShot>[];
  late final double attackEnd;
  double age = 0, _previousAge = 0;
  bool get warning => age < InfiniteTuning.lateEnemyWarning;
  bool get expired => age >= attackEnd + .45;
  double get warningProgress =>
      (age / InfiniteTuning.lateEnemyWarning).clamp(0.0, 1.0);
  double get presence => math.min(
    (age / .3).clamp(0.0, 1.0),
    ((attackEnd + .45 - age) / .45).clamp(0.0, 1.0),
  );

  void step(double dt, {double scrollDistance = 0}) {
    if (dt <= 0 || !dt.isFinite) return;
    _previousAge = age;
    age += dt;
    for (final shot in shots) {
      shot.step(dt, scrollDistance: scrollDistance);
    }
  }

  double? bodyContact(double ax, double ay, double bx, double by) {
    final dt = age - _previousAge;
    if (dt <= 0) return null;
    final from = ((InfiniteTuning.lateEnemyWarning - _previousAge) / dt).clamp(
      0.0,
      1.0,
    );
    final until = ((attackEnd - _previousAge) / dt).clamp(0.0, 1.0);
    if (until <= from) return null;
    final t = circleContact(
      ax + (bx - ax) * from,
      ay + (by - ay) * from,
      ax + (bx - ax) * until,
      ay + (by - ay) * until,
      origin.x,
      origin.y,
      18,
    );
    return t == null ? null : from + t * (until - from);
  }
}

/// An analytic path with timed activation. Collision splits a rebound at its
/// exact wall time and samples curves at <= 1/120s, sweeping each segment.
/// Pending and expired fractions never damage the ball, even on a long frame.
class LateEnemyShot {
  LateEnemyShot({
    required this.kind,
    required this.origin,
    required this.velocity,
    required this.delay,
    required this.life,
    this.bounceTime = double.infinity,
    this.curve = 0,
    this.parent,
    this.beamEnd,
  }) : age = -delay,
       _previousAge = -delay;

  final LateShotKind kind;
  final EnemyPoint origin, velocity;
  final double delay, life, bounceTime, curve;
  final LateEnemyShot? parent;
  final EnemyPoint? beamEnd;
  double age, _previousAge, _dt = 0, _groundShift = 0, _previousGroundShift = 0;
  bool consumed = false;
  bool get cancelled => consumed || (parent?.consumed ?? false);
  bool get visible => !cancelled && age >= 0 && age < life;
  bool get persistent =>
      kind == LateShotKind.acid || kind == LateShotKind.laser;
  double get radius => switch (kind) {
    LateShotKind.acid => InfiniteTuning.acidRadius,
    LateShotKind.seed => 5.0,
    LateShotKind.ricochet => 4.0,
    LateShotKind.laser => InfiniteTuning.scorpionLaserRadius,
    _ => 3.0,
  };
  String get reason => switch (kind) {
    LateShotKind.bomb ||
    LateShotKind.acid => 'Acid hit. Leave the beetle landing circle.',
    LateShotKind.ricochet => 'Cricket pellet. Watch the wall rebound.',
    LateShotKind.moth => 'Moth dust. Slip between the curved streams.',
    LateShotKind.laser => 'Scorpion laser. Step away from its aim line.',
    LateShotKind.seed ||
    LateShotKind.shard => 'Seed hit. Watch the three-way split.',
  };

  EnemyPoint positionAt(double time) {
    var x = origin.x + velocity.x * time;
    var y = origin.y + velocity.y * time;
    if (kind == LateShotKind.ricochet && time > bounceTime) {
      x -= velocity.x * (time - bounceTime) * 2;
    }
    if (kind == LateShotKind.bomb) y -= math.sin(time / life * math.pi) * 48;
    if (curve != 0) {
      final speed = math.sqrt(
        velocity.x * velocity.x + velocity.y * velocity.y,
      );
      final offset = math.sin(time / life * math.pi) * curve;
      x -= velocity.y / speed * offset;
      y += velocity.x / speed * offset;
    }
    return (x: x, y: y);
  }

  EnemyPoint get position {
    final p = positionAt(age.clamp(0.0, life));
    return (x: p.x, y: p.y + _groundShift);
  }

  void step(double dt, {double scrollDistance = 0}) {
    if (dt <= 0 || !dt.isFinite) return;
    _previousAge = age;
    _previousGroundShift = _groundShift;
    _dt = dt;
    age += dt;
    if (kind == LateShotKind.acid) {
      final activeDt = age.clamp(0.0, life) - _previousAge.clamp(0.0, life);
      _groundShift += scrollDistance * activeDt / dt;
    }
  }

  double? contact(double ax, double ay, double bx, double by) {
    if (cancelled || kind == LateShotKind.bomb || _dt <= 0) return null;
    final start = math.max(0.0, _previousAge), end = math.min(life, age);
    if (end <= start) return null;
    if (kind == LateShotKind.laser) {
      final from = (start - _previousAge) / _dt;
      final until = (end - _previousAge) / _dt;
      final t = _beamContact(
        ax + (bx - ax) * from,
        ay + (by - ay) * from,
        ax + (bx - ax) * until,
        ay + (by - ay) * until,
      );
      return t == null ? null : from + t * (until - from);
    }
    final cuts = <double>[start];
    if (bounceTime > start && bounceTime < end) cuts.add(bounceTime);
    if (curve != 0) {
      final count = ((end - start) * 120).ceil();
      for (var i = 1; i < count; i++) {
        cuts.add(start + (end - start) * i / count);
      }
    }
    cuts.add(end);
    cuts.sort();
    EnemyPoint at(double t) {
      final p = positionAt(t);
      final shift =
          _previousGroundShift +
          (_groundShift - _previousGroundShift) * (t - start) / (end - start);
      return (x: p.x, y: p.y + shift);
    }

    for (var i = 1; i < cuts.length; i++) {
      final a = at(cuts[i - 1]), b = at(cuts[i]);
      final from = (cuts[i - 1] - _previousAge) / _dt;
      final until = (cuts[i] - _previousAge) / _dt;
      final t = circleContact(
        ax + (bx - ax) * from - a.x,
        ay + (by - ay) * from - a.y,
        ax + (bx - ax) * until - b.x,
        ay + (by - ay) * until - b.y,
        0,
        0,
        7 + radius,
      );
      if (t != null) return from + t * (until - from);
    }
    return null;
  }

  // Sweep the ball through a finite capsule: a rectangle in beam coordinates
  // plus circular end caps. This catches fast crossings without sampling.
  double? _beamContact(double ax, double ay, double bx, double by) {
    final tip = beamEnd ?? origin;
    final dx = tip.x - origin.x, dy = tip.y - origin.y;
    final length = math.sqrt(dx * dx + dy * dy);
    final contactRadius = 7 + radius;
    final near = circleContact(
      ax,
      ay,
      bx,
      by,
      origin.x,
      origin.y,
      contactRadius,
    );
    if (length < 1e-9) return near;
    final far = circleContact(ax, ay, bx, by, tip.x, tip.y, contactRadius);
    final ux = dx / length, uy = dy / length;
    double along(double x, double y) =>
        (x - origin.x) * ux + (y - origin.y) * uy;
    double across(double x, double y) =>
        -(x - origin.x) * uy + (y - origin.y) * ux;
    var lo = 0.0, hi = 1.0;
    for (final axis in [
      (along(ax, ay), along(bx, by), 0.0, length),
      (across(ax, ay), across(bx, by), -contactRadius, contactRadius),
    ]) {
      final delta = axis.$2 - axis.$1;
      if (delta.abs() < 1e-9) {
        if (axis.$1 < axis.$3 || axis.$1 > axis.$4) hi = -1;
      } else {
        final a = (axis.$3 - axis.$1) / delta;
        final b = (axis.$4 - axis.$1) / delta;
        lo = math.max(lo, math.min(a, b));
        hi = math.min(hi, math.max(a, b));
      }
    }
    double? result = lo <= hi ? lo : null;
    for (final cap in [near, far]) {
      if (cap != null) result = result == null ? cap : math.min(result, cap);
    }
    return result;
  }
}
