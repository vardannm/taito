import 'dart:collection';
import 'game.dart';
import 'hazards.dart';
import 'infinite_boss.dart';
import 'late_enemies.dart';

enum EnemyCue {
  insectArrival,
  wingArrival,
  snakeHiss,
  wardenArrival,
  colossusArrival,
  seraphArrival,
  bullet,
  ricochet,
  bounce,
  petal,
  crystal,
  laserCharge,
  laserFire,
  bombThrow,
  poolLand,
  mineCharge,
  mineFire,
  cometCharge,
  cometFire,
  web,
  quills,
}

extension EnemyCueAudio on EnemyCue {
  String get asset => 'audio/enemy_$name.wav';
  double get seconds => switch (this) {
    EnemyCue.insectArrival => .28,
    EnemyCue.wingArrival => .4,
    EnemyCue.snakeHiss => .5,
    EnemyCue.wardenArrival => .85,
    EnemyCue.colossusArrival => .95,
    EnemyCue.seraphArrival => 1.05,
    EnemyCue.bullet => .14,
    EnemyCue.ricochet => .22,
    EnemyCue.bounce => .16,
    EnemyCue.petal => .28,
    EnemyCue.crystal => .32,
    EnemyCue.laserCharge => .8,
    EnemyCue.laserFire => .75,
    EnemyCue.bombThrow => .3,
    EnemyCue.poolLand => .36,
    EnemyCue.mineCharge => .85,
    EnemyCue.mineFire => .4,
    EnemyCue.cometCharge => .65,
    EnemyCue.cometFire => .38,
    EnemyCue.web => .22,
    EnemyCue.quills => .25,
  };
  double get volume => switch (this) {
    EnemyCue.wardenArrival ||
    EnemyCue.colossusArrival ||
    EnemyCue.seraphArrival => .5,
    EnemyCue.laserFire || EnemyCue.mineFire => .4,
    EnemyCue.insectArrival || EnemyCue.wingArrival || EnemyCue.snakeHiss => .27,
    _ => .3,
  };
}

/// Observes actual physics transitions without changing gameplay or allocating
/// audio players. A whole volley gets one cue, not one per projectile.
class EnemySoundDirector {
  int? _runSerial;
  final _ages = HashMap<Object, double>.identity();
  final _arrivals = HashSet<Object>.identity();
  final _lastCue = <EnemyCue, double>{};

  List<EnemyCue> capture(BalanceGame game) {
    if (_runSerial != game.runSerial) {
      _runSerial = game.runSerial;
      _ages.clear();
      _arrivals.clear();
      _lastCue.clear();
    }
    if (!game.started ||
        game.waitingForInput ||
        game.paused ||
        game.phase != GamePhase.playing)
      return const [];
    final result = <EnemyCue>[];
    final present = HashSet<Object>.identity();
    void emit(EnemyCue cue, {double interval = .08}) {
      if (game.elapsed - (_lastCue[cue] ?? double.negativeInfinity) < interval)
        return;
      _lastCue[cue] = game.elapsed;
      result.add(cue);
    }

    bool visible(double y) => y >= game.visibleTop + 32 && y <= 537;
    void arrival(Object object, EnemyCue cue, {bool onBoard = true}) {
      present.add(object);
      if (onBoard && _arrivals.add(object)) emit(cue, interval: .3);
    }

    void shots(List<LateEnemyShot> shots, BossKind? bossKind) {
      for (final shot in shots) {
        present.add(shot);
        final previous = _ages[shot];
        _ages[shot] = shot.age;
        if (shot.cancelled) continue;
        final seraph = bossKind == BossKind.eclipseSeraph;
        if (previous == null && shot.age < 0) {
          if (shot.kind == LateShotKind.laser) emit(EnemyCue.laserCharge);
          if (shot.kind == LateShotKind.mine) emit(EnemyCue.mineCharge);
          if (seraph && shot.kind == LateShotKind.shard)
            emit(EnemyCue.cometCharge);
        }
        if ((previous ?? double.negativeInfinity) < 0 && shot.age >= 0) {
          emit(switch (shot.kind) {
            LateShotKind.shard => seraph ? EnemyCue.cometFire : EnemyCue.bullet,
            LateShotKind.seed => EnemyCue.bullet,
            LateShotKind.ricochet => EnemyCue.ricochet,
            LateShotKind.moth => seraph ? EnemyCue.crystal : EnemyCue.petal,
            LateShotKind.laser => EnemyCue.laserFire,
            LateShotKind.bomb => EnemyCue.bombThrow,
            LateShotKind.acid => EnemyCue.poolLand,
            LateShotKind.mine => EnemyCue.mineFire,
            LateShotKind.spinner => EnemyCue.ricochet,
          });
        }
        if (shot.kind == LateShotKind.ricochet &&
            (previous ?? double.negativeInfinity) < shot.bounceTime &&
            shot.age >= shot.bounceTime)
          emit(EnemyCue.bounce);
      }
    }

    final boss = game.boss;
    if (boss != null) {
      arrival(boss, switch (boss.kind) {
        BossKind.skyWarden => EnemyCue.wardenArrival,
        BossKind.stormColossus => EnemyCue.colossusArrival,
        BossKind.eclipseSeraph => EnemyCue.seraphArrival,
        BossKind.prismReaver => EnemyCue.colossusArrival,
        BossKind.venomCrown => EnemyCue.seraphArrival,
      });
      shots(boss.shots, boss.kind);
    }
    final visitor = game.lateEnemy;
    if (visitor != null) {
      arrival(
        visitor,
        visitor.kind == LateEnemyKind.moth
            ? EnemyCue.wingArrival
            : EnemyCue.insectArrival,
      );
      shots(visitor.shots, null);
    }
    for (final snake in game.snakes) {
      arrival(
        snake,
        EnemyCue.snakeHiss,
        onBoard: visible(game.screenY(snake.y)),
      );
    }
    for (final spider in game.spiders) {
      arrival(
        spider,
        EnemyCue.insectArrival,
        onBoard: visible(game.screenY(spider.y)),
      );
    }
    for (final porcupine in game.porcupines) {
      arrival(
        porcupine,
        EnemyCue.insectArrival,
        onBoard: visible(game.screenY(porcupine.y)),
      );
    }
    for (final web in game.webShots) {
      present.add(web);
      final previous = _ages[web] ?? 0;
      _ages[web] = web.age;
      if (previous < web.warningSeconds && web.age >= web.warningSeconds)
        emit(EnemyCue.web);
    }
    for (final quill in game.quills) {
      present.add(quill);
      if (!_ages.containsKey(quill)) emit(EnemyCue.quills);
      _ages[quill] = quill.age;
    }
    for (final hazard in game.specialHazards) {
      present.add(hazard);
      final previous = _ages[hazard];
      _ages[hazard] = hazard.age;
      if (hazard.kind != HazardKind.laser) continue;
      if (previous == null && hazard.warning) emit(EnemyCue.laserCharge);
      if ((previous ?? 0) < hazard.warningSeconds &&
          hazard.age >= hazard.warningSeconds)
        emit(EnemyCue.laserFire);
    }
    for (final gate in game.mazeGates) {
      arrival(gate, EnemyCue.laserFire, onBoard: visible(gate.y));
    }
    _ages.removeWhere((object, _) => !present.contains(object));
    _arrivals.removeWhere((object) => !present.contains(object));
    return result;
  }
}
