import 'dart:math' as math;
import 'late_enemies.dart';

enum BossKind { skyWarden, stormColossus, eclipseSeraph }

extension BossKindDetails on BossKind {
  int get minimumScore => switch (this) {
    BossKind.skyWarden => 90000,
    BossKind.stormColossus => 270000,
    BossKind.eclipseSeraph => 550000,
  };
  int get maximumScore => switch (this) {
    BossKind.skyWarden => 120000,
    BossKind.stormColossus => 330000,
    BossKind.eclipseSeraph => 650000,
  };
  String get name => switch (this) {
    BossKind.skyWarden => 'SKY WARDEN',
    BossKind.stormColossus => 'STORM COLOSSUS',
    BossKind.eclipseSeraph => 'ECLIPSE SERAPH',
  };
}

enum BossPhase {
  arriving,
  bullets,
  lasers,
  pools,
  ricochets,
  blades,
  mines,
  petals,
  curtains,
  comets,
  leaving,
}

/// A timed survival encounter. The boss stays in screen space as the board
/// climbs; thrown pools attach to the scrolling floor only after landing.
class InfiniteBoss {
  InfiniteBoss({this.top = 0, this.kind = BossKind.skyWarden});

  static const duration = 28.0;
  static const laserWarning = 1.1;
  static const laserLife = 1.3;
  static const throwFlight = .9;
  static const poolLife = 3.0;
  static const poolRadius = 30.0;
  static const name = 'SKY WARDEN';
  static const mineWarning = 1.35, mineLife = .65, mineRadius = 40.0;

  final BossKind kind;
  String get displayName => kind.name;
  double age = 0, top;
  final shots = <LateEnemyShot>[];
  int _bulletWave = 0, _laserWave = 0, _poolWave = 0;
  double _lastVolleyAt = double.negativeInfinity;

  /// Visual recoil follows the actual firing schedule and freezes on pause.
  double get recoil {
    final since = age - _lastVolleyAt;
    return since < 0
        ? 0
        : math.pow((1 - since / .35).clamp(0.0, 1.0), 2).toDouble();
  }

  double get charge {
    var result = 0.0;
    for (final shot in shots) {
      if (shot.age >= 0 || shot.cancelled) continue;
      final warning = shot.kind == LateShotKind.mine
          ? mineWarning
          : kind == BossKind.eclipseSeraph
          ? 1.2
          : laserWarning;
      if (shot.kind == LateShotKind.laser ||
          shot.kind == LateShotKind.mine ||
          (kind == BossKind.eclipseSeraph && shot.kind == LateShotKind.shard)) {
        result = math.max(result, (1 + shot.age / warning).clamp(0.0, 1.0));
      }
    }
    return result;
  }

  BossPhase get phase => age < 2
      ? BossPhase.arriving
      : age < 10
      ? switch (kind) {
          BossKind.skyWarden => BossPhase.bullets,
          BossKind.stormColossus => BossPhase.ricochets,
          BossKind.eclipseSeraph => BossPhase.petals,
        }
      : age < 18
      ? switch (kind) {
          BossKind.skyWarden => BossPhase.lasers,
          BossKind.stormColossus => BossPhase.blades,
          BossKind.eclipseSeraph => BossPhase.curtains,
        }
      : age < 26
      ? switch (kind) {
          BossKind.skyWarden => BossPhase.pools,
          BossKind.stormColossus => BossPhase.mines,
          BossKind.eclipseSeraph => BossPhase.comets,
        }
      : BossPhase.leaving;
  bool get expired => age >= duration;
  String get hint => switch (phase) {
    BossPhase.arriving => 'BOSS · $displayName',
    BossPhase.bullets => 'BOSS · Slip between the bullet volleys',
    BossPhase.lasers => 'BOSS · Move away from the laser aim line',
    BossPhase.pools => 'BOSS · Keep clear of the amber pools',
    BossPhase.ricochets => 'BOSS · Watch the energy orbs bounce off the rails',
    BossPhase.blades => 'BOSS · Dodge the curving blade volleys',
    BossPhase.mines =>
      'BOSS · Leave the black circles before their lasers fire',
    BossPhase.petals => 'BOSS · Slip between the crystal petals',
    BossPhase.curtains => 'BOSS · Find a lane between the laser curtains',
    BossPhase.comets => 'BOSS · Move away from the comet trails',
    BossPhase.leaving => 'BOSS · Clear! Keep climbing',
  };

  EnemyPoint positionAt(double time) {
    final x = time < 10
        ? 180 + math.sin(time * math.pi / 5) * 55
        : time < 18
        ? 180.0
        : time < 26
        ? 180 + math.sin((time - 18) * math.pi / 4) * 55
        : 180.0;
    final entrance = time < 2 ? -150 * math.pow(1 - time / 2, 2) : 0.0;
    final exit = time > 26 ? -170 * math.pow((time - 26) / 2, 2) : 0.0;
    return (x: x, y: top + 105 + entrance + exit);
  }

  EnemyPoint get position => positionAt(age);

  void step(
    double dt, {
    required EnemyPoint target,
    double scrollDistance = 0,
    double? visibleTop,
  }) {
    if (dt <= 0 || !dt.isFinite || expired) return;
    if (visibleTop != null) top = visibleTop;
    final before = age;
    age += dt;
    // Keep shots that expire in this step until their last swept contact has
    // been resolved. Discard them at the start of the following step.
    shots.removeWhere((shot) => shot.age >= shot.life || shot.cancelled);

    if (kind != BossKind.skyWarden) {
      if (kind == BossKind.stormColossus) {
        _stormWeapons(before, target);
      } else {
        _seraphWeapons(before, target);
      }
      for (final shot in shots) {
        shot.step(dt, scrollDistance: scrollDistance);
      }
      return;
    }

    while (_bulletWave < 5 && age >= 2.6 + _bulletWave) {
      final at = 2.6 + _bulletWave++;
      _lastVolleyAt = at;
      final origin = positionAt(at);
      final angle = math.atan2(target.y - origin.y, target.x - origin.x);
      // Expanded portrait boards put the boss farther above the platform.
      // Keep the flight time dodgeable while letting shots reach the player.
      final dx = target.x - origin.x, dy = target.y - origin.y;
      final speed = math.max(145.0, math.sqrt(dx * dx + dy * dy) / 2.4);
      for (final spread in [-.48, -.24, 0.0, .24, .48]) {
        shots.add(
          LateEnemyShot(
            kind: LateShotKind.shard,
            origin: origin,
            velocity: (
              x: math.cos(angle + spread) * speed,
              y: math.sin(angle + spread) * speed,
            ),
            delay: at - before,
            life: 2.8,
            radiusOverride: 4,
            reasonOverride: 'Boss bullet. Slip between the volleys.',
          ),
        );
      }
    }
    while (_laserWave < 3 && age >= 10 + _laserWave * 2.5) {
      final at = 10 + _laserWave++ * 2.5;
      _lastVolleyAt = at + laserWarning;
      final origin = positionAt(at);
      // Lock the complete ray during the warning; never track the player.
      final dx = target.x - origin.x;
      final dy = math.max(60.0, target.y - origin.y);
      final scale = math.min(
        (537 - origin.y) / dy,
        dx.abs() < 1e-9
            ? double.infinity
            : ((dx > 0 ? 336 : 24) - origin.x) / dx,
      );
      shots.add(
        LateEnemyShot(
          kind: LateShotKind.laser,
          origin: origin,
          velocity: (x: 0, y: 0),
          delay: at - before + laserWarning,
          life: laserLife,
          beamEnd: (x: origin.x + dx * scale, y: origin.y + dy * scale),
          radiusOverride: 5,
          reasonOverride: 'Boss laser. Leave the marked aim line.',
        ),
      );
    }
    while (_poolWave < 3 && age >= 18 + _poolWave * 2) {
      final wave = _poolWave++;
      final at = 18 + wave * 2.0;
      _lastVolleyAt = at;
      final origin = positionAt(at);
      // Two circles leave a wide escape lane: one aimed at the player's
      // position when the throw begins, and the other on the farther side.
      final aimedX = target.x.clamp(65.0, 295.0);
      final otherX = aimedX < 180 ? 280.0 : 80.0;
      for (final x in [aimedX, otherX]) {
        final landing = (x: x, y: target.y.clamp(top + 180, 470.0));
        shots.add(
          LateEnemyShot(
            kind: LateShotKind.bomb,
            origin: origin,
            velocity: (
              x: (landing.x - origin.x) / throwFlight,
              y: (landing.y - origin.y) / throwFlight,
            ),
            delay: at - before,
            life: throwFlight,
          ),
        );
        shots.add(
          LateEnemyShot(
            kind: LateShotKind.acid,
            origin: landing,
            velocity: (x: 0, y: 0),
            delay: at - before + throwFlight,
            life: poolLife,
            radiusOverride: poolRadius,
            reasonOverride: 'Boss pool. Stay outside the amber circles.',
          ),
        );
      }
    }
    for (final shot in shots) {
      shot.step(dt, scrollDistance: scrollDistance);
    }
  }

  void _stormWeapons(double before, EnemyPoint target) {
    while (_bulletWave < 4 && age >= 2.6 + _bulletWave * 1.2) {
      final at = 2.6 + _bulletWave++ * 1.2;
      _lastVolleyAt = at;
      final body = positionAt(at);
      for (final side in [-1.0, 1.0]) {
        final origin = (x: body.x + side * 40, y: body.y + 12);
        final wall = side < 0 ? 28.0 : 332.0;
        // Aim at a mirror of the ball across the chosen rail. The orb reaches
        // that fixed aim after exactly one reflection, never homing afterward.
        final dx = wall * 2 - target.x - origin.x;
        final dy = math.max(60.0, target.y - origin.y);
        final length = math.sqrt(dx * dx + dy * dy);
        final speed = math.max(155.0, length / 2.6);
        final vx = dx / length * speed;
        final bounce = (wall - origin.x) / vx;
        shots.add(
          LateEnemyShot(
            kind: LateShotKind.ricochet,
            origin: origin,
            velocity: (x: vx, y: dy / length * speed),
            delay: at - before,
            life: math.min(4.0, bounce + 304 / vx.abs()),
            bounceTime: bounce,
            radiusOverride: 6,
            reasonOverride: 'Colossus orb. Watch its rail rebound.',
          ),
        );
      }
    }
    while (_laserWave < 4 && age >= 10.7 + _laserWave * 1.1) {
      final wave = _laserWave++;
      final at = 10.7 + wave * 1.1;
      _lastVolleyAt = at;
      final origin = positionAt(at);
      final dx = target.x - origin.x, dy = target.y - origin.y;
      final length = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      final speed = math.max(140.0, length / 2.5);
      for (final side in [-1.0, 1.0]) {
        shots.add(
          LateEnemyShot(
            kind: LateShotKind.moth,
            origin: origin,
            velocity: (x: dx / length * speed, y: dy / length * speed),
            delay: at - before,
            life: 3.0,
            curve: side * (wave.isEven ? 72 : 48),
            radiusOverride: 7,
            reasonOverride: 'Colossus blade. Dodge its curved path.',
          ),
        );
      }
    }
    while (_poolWave < 3 && age >= 18 + _poolWave * 2.6) {
      final wave = _poolWave++;
      final at = 18 + wave * 2.6;
      _lastVolleyAt = at + mineWarning;
      // Mines stay in screen space while charging. Side mines alternate a
      // broad safe lane; the center mine locks the ball's current position.
      final aimed = target.x.clamp(65.0, 295.0);
      final side = aimed < 180 ? 285.0 : 75.0;
      for (final x in [aimed, side]) {
        shots.add(
          LateEnemyShot(
            kind: LateShotKind.mine,
            origin: (x: x, y: target.y.clamp(top + 180, 470.0)),
            velocity: (x: 0, y: 0),
            delay: at - before + mineWarning,
            life: mineLife,
            radiusOverride: mineRadius,
            reasonOverride:
                'Colossus laser mine. Leave the black circle before it fires.',
          ),
        );
      }
    }
  }

  void _seraphWeapons(double before, EnemyPoint target) {
    while (_bulletWave < 4 && age >= 2.6 + _bulletWave * 1.4) {
      final wave = _bulletWave++;
      final at = 2.6 + wave * 1.4;
      _lastVolleyAt = at;
      final origin = positionAt(at);
      final dx = target.x - origin.x, dy = target.y - origin.y;
      final length = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      final speed = math.max(135.0, length / 2.4);
      for (final curve in [-85.0, -35.0, 35.0, 85.0]) {
        shots.add(
          LateEnemyShot(
            kind: LateShotKind.moth,
            origin: origin,
            velocity: (x: dx / length * speed, y: dy / length * speed),
            delay: at - before,
            life: 3,
            curve: curve * (wave.isEven ? 1 : -1),
            radiusOverride: 5,
            reasonOverride: 'Seraph crystal. Slip between the petal paths.',
          ),
        );
      }
    }
    while (_laserWave < 3 && age >= 10.2 + _laserWave * 2.3) {
      final wave = _laserWave++;
      final at = 10.2 + wave * 2.3;
      _lastVolleyAt = at + 1.2;
      // Parallel curtains leave multiple broad escape lanes. Their positions
      // are marked for 1.2 seconds and remain fixed during the active beam.
      final lanes = switch (wave) {
        0 => [100.0, 260.0],
        1 => [140.0, 300.0],
        _ => [60.0, 220.0],
      };
      for (final x in lanes) {
        shots.add(
          LateEnemyShot(
            kind: LateShotKind.laser,
            origin: (x: x, y: top + 165),
            velocity: (x: 0, y: 0),
            delay: at - before + 1.2,
            life: 1.3,
            beamEnd: (x: x, y: 537),
            radiusOverride: 6,
            reasonOverride: 'Seraph curtain. Step into an open lane.',
          ),
        );
      }
    }
    while (_poolWave < 3 && age >= 18 + _poolWave * 2.1) {
      final wave = _poolWave++;
      final at = 18 + wave * 2.1;
      _lastVolleyAt = at + .9;
      final aim = target.x.clamp(70.0, 290.0);
      for (final x in [70.0, 180.0, 290.0]) {
        final origin = (x: x, y: top + 160);
        // Lock a sparse diagonal rain pattern before the warning. The dashed
        // trail shares the projectile's exact path; no late homing or pools.
        final landingX = (x + (aim - 180) * .25 + (wave.isEven ? 25 : -25))
            .clamp(40.0, 320.0);
        final landingY = target.y.clamp(top + 220, 470.0);
        shots.add(
          LateEnemyShot(
            kind: LateShotKind.shard,
            origin: origin,
            velocity: (x: (landingX - x) / 2.1, y: (landingY - origin.y) / 2.1),
            delay: at - before + .9,
            life: 2.6,
            radiusOverride: 6,
            reasonOverride: 'Seraph comet. Leave the marked trail.',
          ),
        );
      }
    }
  }
}
