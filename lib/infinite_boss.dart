import 'dart:math' as math;
import 'late_enemies.dart';

enum BossKind {
  skyWarden,
  stormColossus,
  eclipseSeraph,
  prismReaver,
  venomCrown,
  novaPulsar,
}

/// Score windows for the 1st to 6th boss of a run. Each run picks one score
/// inside every window; the bosses themselves are shuffled, so any of the
/// six can fill any slot.
const bossScoreWindows = [
  (70000, 110000),
  (220000, 250000),
  (450000, 520000),
  (700000, 780000),
  (1000000, 1100000),
  (1300000, 1400000),
];

extension BossKindDetails on BossKind {
  String get name => switch (this) {
    BossKind.skyWarden => 'SKY WARDEN',
    BossKind.stormColossus => 'STORM COLOSSUS',
    BossKind.eclipseSeraph => 'ECLIPSE SERAPH',
    BossKind.prismReaver => 'PRISM REAVER',
    BossKind.venomCrown => 'VENOM CROWN',
    BossKind.novaPulsar => 'NOVA PULSAR',
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
  sweepingLaser,
  twinLasers,
  rotors,
  toxicSlalom,
  toxicPulse,
  toxicGauntlet,
  novaRings,
  dashedRails,
  novaLance,
  leaving,
}

/// A timed survival encounter. The boss stays in screen space as the board
/// climbs; thrown pools attach to the scrolling floor only after landing.
class InfiniteBoss {
  InfiniteBoss({this.top = 0, this.kind = BossKind.skyWarden, int seed = 0})
    : _random = math.Random(seed);

  static const duration = 28.0;
  static const laserWarning = 1.1;
  static const laserLife = 1.3;
  static const throwFlight = .9;
  static const poolLife = 3.0;
  static const poolRadius = 30.0;
  static const name = 'SKY WARDEN';
  static const mineWarning = 1.35, mineLife = .65, mineRadius = 40.0;
  static const toxicWarning = .9, toxicLife = 2.5;

  final BossKind kind;
  final math.Random _random;
  String get displayName => kind.name;
  double age = 0, top;
  final shots = <LateEnemyShot>[];
  final toxicWalls = <ToxicWall>[];
  double? _toxicAnchor;
  double _toxicDirection = 1;

  /// Every overlapping wall shares this corridor. It moves independently of
  /// the player after the first warning, at a speed the rolling ball can match.
  double toxicLaneAt(double time) {
    final t = math.max(0.0, time - 2.6 - toxicWarning);
    return (180 +
            ((_toxicAnchor ?? 180) - 180) * math.exp(-t / 2) +
            _toxicDirection * 72 * math.sin(t * .9) * (1 - math.exp(-t / 1.4)))
        .clamp(80.0, 280.0);
  }

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
      final warning = kind == BossKind.venomCrown
          ? toxicWarning
          : shot.kind == LateShotKind.mine
          ? mineWarning
          : kind == BossKind.eclipseSeraph
          ? 1.2
          : laserWarning;
      if (shot.kind == LateShotKind.laser ||
          (kind == BossKind.venomCrown && shot.kind == LateShotKind.shard) ||
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
          BossKind.prismReaver => BossPhase.sweepingLaser,
          BossKind.venomCrown => BossPhase.toxicSlalom,
          BossKind.novaPulsar => BossPhase.novaRings,
        }
      : age < 18
      ? switch (kind) {
          BossKind.skyWarden => BossPhase.lasers,
          BossKind.stormColossus => BossPhase.blades,
          BossKind.eclipseSeraph => BossPhase.curtains,
          BossKind.prismReaver => BossPhase.twinLasers,
          BossKind.venomCrown => BossPhase.toxicPulse,
          BossKind.novaPulsar => BossPhase.dashedRails,
        }
      : age < 26
      ? switch (kind) {
          BossKind.skyWarden => BossPhase.pools,
          BossKind.stormColossus => BossPhase.mines,
          BossKind.eclipseSeraph => BossPhase.comets,
          BossKind.prismReaver => BossPhase.rotors,
          BossKind.venomCrown => BossPhase.toxicGauntlet,
          BossKind.novaPulsar => BossPhase.novaLance,
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
    BossPhase.sweepingLaser => 'BOSS · Keep moving as the laser sweeps',
    BossPhase.twinLasers => 'BOSS · Follow the gap between the moving lasers',
    BossPhase.rotors => 'BOSS · Watch the spinning rotors change direction',
    BossPhase.toxicSlalom => 'BOSS · Follow the opening in the toxic walls',
    BossPhase.toxicPulse => 'BOSS · Watch the poison walls change speed',
    BossPhase.toxicGauntlet =>
      'BOSS · Stay inside the narrowing toxic corridor',
    BossPhase.novaRings => 'BOSS · Meet each growing ring at an opening',
    BossPhase.dashedRails =>
      'BOSS · Slip through the gaps as the side lasers pass',
    BossPhase.novaLance => 'BOSS · Cross the sweeping laser through its gaps',
    BossPhase.leaving => 'BOSS · Clear! Keep climbing',
  };

  EnemyPoint positionAt(double time) {
    final x = kind == BossKind.venomCrown
        ? 180 + math.sin(time * .65) * 35
        : kind == BossKind.novaPulsar
        ? 180 + math.sin(time * .55) * 28
        : kind == BossKind.prismReaver
        ? 180 + math.sin(time * 1.05) * 52 + math.sin(time * 1.83) * 16
        : time < 10
        ? 180 + math.sin(time * math.pi / 5) * 55
        : time < 18
        ? 180.0
        : time < 26
        ? 180 + math.sin((time - 18) * math.pi / 4) * 55
        : 180.0;
    final entrance = time < 2 ? -150 * math.pow(1 - time / 2, 2) : 0.0;
    final exit = time > 26 ? -170 * math.pow((time - 26) / 2, 2) : 0.0;
    final drift = kind == BossKind.prismReaver ? math.sin(time * 1.4) * 8 : 0.0;
    return (x: x, y: top + 105 + entrance + exit + drift);
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
    toxicWalls.removeWhere(
      (wall) => before >= wall.at + toxicWarning + toxicLife,
    );

    if (kind != BossKind.skyWarden) {
      if (kind == BossKind.stormColossus) {
        _stormWeapons(before, target);
      } else if (kind == BossKind.eclipseSeraph) {
        _seraphWeapons(before, target);
      } else if (kind == BossKind.prismReaver) {
        _prismWeapons(before, target);
      } else if (kind == BossKind.novaPulsar) {
        _novaWeapons(before, target);
      } else {
        _toxicWeapons(before, target);
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

  /// Nova Pulsar: growing rings with turning openings, then dashed side
  /// lasers that cross the board, then one sweeping dashed lance. Every gap
  /// is wider than the ball plus the beam, and every attack is marked first.
  void _novaWeapons(double before, EnemyPoint target) {
    void ring(double at, int gaps, double width, double speed, double spin) {
      _lastVolleyAt = at + laserWarning;
      final body = positionAt(at);
      // The first opening always faces down toward the player's side of the
      // board; the others are spread evenly around the ring.
      final first = math.pi * (.35 + _random.nextDouble() * .3);
      shots.add(
        LateEnemyShot(
          kind: LateShotKind.laser,
          origin: (x: body.x, y: body.y + novaCoreOffset),
          velocity: (x: 0, y: 0),
          delay: at - before + laserWarning,
          life: novaRingLife,
          radiusOverride: 4,
          ring: LaserRing(
            startRadius: novaRingStart,
            speed: speed,
            spin: spin,
            gaps: [
              for (var i = 0; i < gaps; i++)
                (first + i * math.pi * 2 / gaps - width / 2, width),
            ],
          ),
          reasonOverride: 'Nova ring. Meet it at one of its openings.',
        ),
      );
    }

    void lance(
      double at,
      double life,
      EnemyPoint Function(double time) at0,
      LaserDashes dashes,
      String reason,
    ) {
      _lastVolleyAt = at + laserWarning;
      EnemyBeam path(double time) {
        final p = at0(time);
        return (start: p, end: (x: p.x, y: 537.0));
      }

      final first = path(0);
      shots.add(
        LateEnemyShot(
          kind: LateShotKind.laser,
          origin: first.start,
          velocity: (x: 0, y: 0),
          delay: at - before + laserWarning,
          life: life,
          beamEnd: first.end,
          beamPath: path,
          radiusOverride: 4,
          dashes: dashes,
          reasonOverride: reason,
        ),
      );
    }

    final beamTop = top + 150;
    // Phase 1: four rings, 1.5 seconds (about 160 units) apart.
    while (_bulletWave < 4 && age >= 2.6 + _bulletWave * 1.5) {
      final wave = _bulletWave++;
      ring(
        2.6 + wave * 1.5,
        wave < 2 ? 3 : 2,
        .36,
        105,
        wave.isEven ? .22 : -.22,
      );
    }
    // Phase 2: two dashed side lasers. First they cross the whole board in
    // opposite directions, then they slide together as a moving corridor.
    while (_laserWave < 2 && age >= 10 + _laserWave * 4.2) {
      final wave = _laserWave++;
      final at = 10 + wave * 4.2;
      for (final side in [-1.0, 1.0]) {
        lance(
          at,
          wave == 0 ? 3.0 : 2.6,
          wave == 0
              ? (t) => (
                  x: 180 + side * 136 * math.cos(math.pi * t / 3),
                  y: beamTop,
                )
              : (t) => (
                  x: 180 + side * 60 + 70 * math.sin(math.pi * 2 * t / 2.6),
                  y: beamTop,
                ),
          LaserDashes(length: 62, gap: 54, speed: side * -45),
          'Nova rail. Slip through a gap as it passes.',
        );
      }
    }
    // Phase 3: one dashed lance sweeps the full width, starting on the side
    // away from the player, while two more rings pulse through it.
    if (_poolWave == 0 && age >= 18) {
      _poolWave++;
      final phase = target.x < 180 ? math.pi / 2 : -math.pi / 2;
      lance(
        18,
        6.5,
        (t) => (
          x: 180 + 138 * math.sin(math.pi * 2 * t / 3.4 + phase),
          y: beamTop,
        ),
        const LaserDashes(length: 70, gap: 52, speed: 90),
        'Nova lance. Cross it through a gap.',
      );
    }
    while (_poolWave >= 1 && _poolWave < 3 && age >= 19.6 + (_poolWave - 1) * 3) {
      final wave = _poolWave++;
      ring(19.6 + (wave - 1) * 3, 3, .38, 85, wave.isEven ? .18 : -.18);
    }
  }

  static const novaCoreOffset = 6.0, novaRingStart = 30.0, novaRingLife = 5.0;

  void _toxicWeapons(double before, EnemyPoint target) {
    if (_toxicAnchor == null && age >= 2.6) {
      _toxicAnchor = target.x.clamp(80.0, 280.0);
      _toxicDirection = _random.nextBool() ? 1 : -1;
    }
    void wall(double at, BossPhase mode) {
      final formation = ToxicWall(
        at: at,
        top: top,
        mode: mode,
        laneAt: toxicLaneAt,
      );
      toxicWalls.add(formation);
      _lastVolleyAt = at + toxicWarning;
      for (final side in [-1.0, 1.0]) {
        for (var i = 0; i < ToxicWall.bulletsPerSide; i++) {
          shots.add(
            LateEnemyShot(
              kind: LateShotKind.shard,
              origin: formation.positionAt(0, side, i),
              velocity: (x: 0, y: 0),
              delay: at - before + toxicWarning,
              life: toxicLife,
              positionPath: (t) => formation.positionAt(t, side, i),
              radiusOverride: ToxicWall.bulletRadius,
              reasonOverride: 'Toxic wall. Follow the marked moving opening.',
            ),
          );
        }
      }
    }

    while (_bulletWave < 5 && age >= 2.6 + _bulletWave * .95) {
      wall(2.6 + _bulletWave++ * .95, BossPhase.toxicSlalom);
    }
    while (_laserWave < 5 && age >= 10.2 + _laserWave * .95) {
      wall(10.2 + _laserWave++ * .95, BossPhase.toxicPulse);
    }
    while (_poolWave < 7 && age >= 18.1 + _poolWave * .65) {
      wall(18.1 + _poolWave++ * .65, BossPhase.toxicGauntlet);
    }
  }

  void _prismWeapons(double before, EnemyPoint target) {
    void laser(double at, int wave, double side) {
      final body = positionAt(at);
      final aim = math
          .atan2(math.max(80.0, target.y - body.y), target.x - body.x)
          .clamp(1.15, 1.99);
      final direction = wave.isEven ? 1.0 : -1.0;
      final baseAngle = aim + side * .30;
      EnemyBeam path(double time) {
        final body = positionAt(at + laserWarning + time);
        final origin = (x: body.x + side * 18, y: body.y + 26);
        // Warning follows the emitter; live sweep starts only after charging.
        final progress = time.clamp(0.0, 1.65) / 1.65;
        final angle = baseAngle + direction * (progress - .5) * .30;
        final dx = math.cos(angle), dy = math.sin(angle);
        final length = math.min(
          (537 - origin.y) / dy,
          dx.abs() < 1e-9
              ? double.infinity
              : ((dx > 0 ? 336 : 24) - origin.x) / dx,
        );
        return (
          start: origin,
          end: (x: origin.x + dx * length, y: origin.y + dy * length),
        );
      }

      final initial = path(0);
      shots.add(
        LateEnemyShot(
          kind: LateShotKind.laser,
          origin: initial.start,
          velocity: (x: 0, y: 0),
          delay: at - before + laserWarning,
          life: 1.65,
          beamEnd: initial.end,
          beamPath: path,
          radiusOverride: 5,
          reasonOverride: side == 0
              ? 'Reaver laser. Keep clear of the moving beam.'
              : 'Reaver twin lasers. Follow the moving escape lane.',
        ),
      );
      _lastVolleyAt = at + laserWarning;
    }

    while (_bulletWave < 2 && age >= 2.6 + _bulletWave * 3.2) {
      final wave = _bulletWave++;
      laser(2.6 + wave * 3.2, wave, 0);
    }
    while (_laserWave < 2 && age >= 10.2 + _laserWave * 3.2) {
      final wave = _laserWave++;
      for (final side in [-1.0, 1.0]) laser(10.2 + wave * 3.2, wave, side);
    }
    while (_poolWave < 3 && age >= 18.1 + _poolWave * 1.9) {
      final wave = _poolWave++;
      final at = 18.1 + wave * 1.9;
      _lastVolleyAt = at + .8;
      final origin = positionAt(at);
      final aim = math.atan2(
        math.max(80.0, target.y - origin.y),
        target.x - origin.x,
      );
      final distance = math.sqrt(
        math.pow(target.x - origin.x, 2) + math.pow(target.y - origin.y, 2),
      );
      final speed = math.max(135.0, distance / 2.3);
      for (var i = 0; i < 4; i++) {
        final angle = aim + (i - 1.5) * .23 + (_random.nextDouble() - .5) * .12;
        final pattern = (wave + i) % 3;
        shots.add(
          LateEnemyShot(
            kind: LateShotKind.spinner,
            origin: origin,
            velocity: (x: math.cos(angle) * speed, y: math.sin(angle) * speed),
            delay: at - before + .8,
            life: 3.0,
            radiusOverride: 8,
            curve: 26 + _random.nextDouble() * 24,
            pathFrequency: [2.1, 3.4, 4.7][pattern],
            pathPhase: _random.nextDouble() * math.pi * 2,
            pathMix: pattern == 2 ? .45 : 0,
            spin: (i.isEven ? 1 : -1) * (4 + _random.nextDouble() * 4),
          ),
        );
      }
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

/// A dense horizontal poison formation, with a shared moving gap rather than
/// aimed fans, homing shots, lasers or rebounds. Twelve bullets on either side
/// close incidental slits; the deliberate opening never becomes smaller than
/// 64 units (38 units remain after ball and bullet collision radii).
class ToxicWall {
  ToxicWall({
    required this.at,
    required this.top,
    required this.mode,
    required this.laneAt,
  });
  static const bulletsPerSide = 12, bulletRadius = 6.0;
  final double at, top;
  final BossPhase mode;
  final double Function(double) laneAt;
  double gapAt(double time) => switch (mode) {
    BossPhase.toxicSlalom => 94.0,
    BossPhase.toxicPulse =>
      88 - 20 * math.pow(math.sin(time * 2.1), 2).toDouble(),
    _ => 64.0,
  };
  double yAt(double liveTime) {
    final t = (liveTime / InfiniteBoss.toxicLife).clamp(0.0, 1.0);
    final progress = switch (mode) {
      BossPhase.toxicPulse => t - .1 * math.sin(math.pi * 2 * t),
      BossPhase.toxicGauntlet => .35 * t + .65 * t * t,
      _ => t,
    };
    return top + 202 + (570 - top - 202) * progress;
  }

  EnemyPoint positionAt(double liveTime, double side, int index) {
    final time = at + InfiniteBoss.toxicWarning + math.max(0.0, liveTime);
    final center = laneAt(time), halfGap = gapAt(time) / 2;
    final fraction = index / (bulletsPerSide - 1);
    final x = side < 0
        ? 24 + (center - halfGap - 24) * fraction
        : center + halfGap + (336 - center - halfGap) * fraction;
    return (x: x, y: yAt(liveTime));
  }
}
