import 'dart:math' as math;
import 'hazards.dart';
import 'maze_gates.dart';
import 'levels.dart';
import 'spiders.dart';
import 'spider_web.dart';
import 'porcupines.dart';
import 'snakes.dart';
import 'late_enemies.dart';
import 'infinite_boss.dart';
import 'encounter_director.dart';
import 'rewards.dart';
import 'merge.dart';
import 'infinite_progress.dart';
import 'ball_cosmetics.dart';
import 'platforms.dart';
part 'infinite_gameplay.dart';

class Hole {
  const Hole(
    this.x,
    this.y, {
    this.target = 0,
    this.size = 1,
    this.motion,
    this.pulse,
  }) : homeX = x,
       homeY = y;
  const Hole._moved(
    this.x,
    this.y,
    this.homeX,
    this.homeY,
    this.target,
    this.size,
    this.motion,
    this.pulse,
  );

  /// Current position; for a moving hole this changes every tick.
  final double x, y;

  /// Where the level places the hole: a moving hole's path center.
  final double homeX, homeY;
  final int target;

  /// Current diameter relative to a normal hole, from [minSize] to
  /// [maxSize]. A breathing hole's [pulse] changes it every tick.
  final double size;
  final HoleMotion? motion;
  final HolePulse? pulse;
  static const minSize = .2, maxSize = 2.5;

  /// Normal rim radius in board units. Size scales only the opening; the
  /// brass rim around it keeps [rimWidth].
  static const rimRadius = 12.8, openingRadius = 10.4, rimWidth = 2.4;

  bool get animated => motion != null || pulse != null;

  /// How far the rim can reach from [homeX], [homeY] over a whole level.
  double get reach =>
      openingRadius * (pulse?.maxSize ?? size) +
      rimWidth +
      (motion?.extent ?? 0);

  /// Clearance to add beyond a normal stationary hole's; 0 for those.
  double get extraReach => reach - rimRadius;

  /// Clearance beyond a normal hole's at the hole's most passable moment:
  /// smallest size, at its home. A player can wait for a moving or breathing
  /// hole, so routes stay open where [extraReach] would wall them off.
  double get passReach =>
      openingRadius * (pulse?.minSize ?? size) + rimWidth - rimRadius;

  /// This hole at [seconds] into the level. Unanimated holes return themselves.
  Hole at(double seconds) {
    if (!animated) return this;
    final (dx, dy) = motion?.offset(seconds) ?? (0.0, 0.0);
    return Hole._moved(
      homeX + dx,
      homeY + dy,
      homeX,
      homeY,
      target,
      pulse?.sizeAt(seconds) ?? size,
      motion,
      pulse,
    );
  }
}

/// A hole that grows and shrinks between two sizes for the whole level,
/// starting at [minSize] when [phase] is 0.
class HolePulse {
  const HolePulse({
    this.minSize = .5,
    this.maxSize = 1.5,
    this.period = 3,
    this.phase = 0,
  });
  final double minSize, maxSize, period, phase;

  double sizeAt(double seconds) =>
      minSize +
      (maxSize - minSize) *
          (1 - math.cos(phase + seconds * math.pi * 2 / period)) /
          2;
}

/// A repeating path around a hole's home position, with the same shapes and
/// formulas as moving hazards so the level builder preview matches play.
class HoleMotion {
  const HoleMotion({
    this.path = HazardMotion.horizontal,
    this.radiusX = 40,
    this.radiusY = 25,
    this.period = 4,
    this.phase = 0,
  });
  final HazardMotion path;
  final double radiusX, radiusY, period, phase;

  double get extent => switch (path) {
    HazardMotion.horizontal || HazardMotion.circle => radiusX,
    HazardMotion.vertical => radiusY,
    HazardMotion.oval => math.max(radiusX, radiusY),
    _ => 0,
  };

  (double, double) offset(double seconds) {
    final angle = phase + seconds * math.pi * 2 / period;
    return switch (path) {
      HazardMotion.horizontal => (radiusX * math.sin(angle), 0.0),
      HazardMotion.vertical => (0.0, radiusY * math.sin(angle)),
      HazardMotion.circle => (
        radiusX * math.cos(angle),
        radiusX * math.sin(angle),
      ),
      HazardMotion.oval => (
        radiusX * math.cos(angle),
        radiusY * math.sin(angle),
      ),
      _ => (0.0, 0.0),
    };
  }
}

enum GamePhase { playing, sinking, returning, over }

enum GameEvent { target, miss, complete, coin, merge, star }

// Preserve mode identifiers for saved data and analytics. The displayed name
// of merge2048 is Number Merge.
enum GameMode { classic, infinite, practice, daily, merge2048 }

enum ControlMode { twoFinger, oneFinger, analog, tiltLift, boardTilt }

// Keep legacy modes for saved records and backups, but offer only these controls.
const selectableControlModes = [ControlMode.oneFinger, ControlMode.twoFinger];

extension ControlModeLabel on ControlMode {
  ControlMode get supportedMode =>
      selectableControlModes.contains(this) ? this : ControlMode.oneFinger;

  String get label => switch (this) {
    ControlMode.twoFinger => 'Two-finger',
    ControlMode.oneFinger => 'One-finger',
    ControlMode.analog => 'Vertical analog',
    ControlMode.tiltLift => 'Tilt Only',
    ControlMode.boardTilt => 'Board Tilt',
  };
}

/// Fixed-step simulation. No Flutter imports: physics can be tested in isolation.
class BalanceGame {
  BalanceGame({int? seed}) : _runRandom = math.Random(seed);
  final math.Random _runRandom;
  // Match the baked Infinite carousel image without consuming run randomness.
  math.Random? _previewRandom;
  math.Random get _random => _previewRandom ?? _runRandom;
  InfiniteProgress survival = InfiniteProgress();
  double infiniteStartingPace = 1;
  double infiniteStartingSpeedMultiplier = 1;
  double _runStartingSpeedMultiplier = 1;
  int infiniteMaxLives = InfiniteTuning.maxLives;
  double shieldDuration = InfiniteTuning.shieldSeconds;
  double magnetDuration = InfiniteTuning.magnetSeconds;
  BallCosmetic cosmetic = BallCosmetic.steel;
  PlatformStyle platformStyle = PlatformStyle.classic;
  double get equipmentMultiplier =>
      1 + cosmetic.scoreBonus + platformStyle.scoreBonus;
  ControlMode controlMode = ControlMode.twoFinger;

  /// Horizontal world metric chosen by the current viewport, never saved.
  double arenaStretch = 1;
  ControlMode preferredControlMode = ControlMode.twoFinger;
  // A visual alternative to the original one-finger pad, with identical input.
  bool haloJoystick = false;
  bool get analog => controlMode == ControlMode.analog;
  final analogInputs = [0.0, 0.0];
  void setAnalogInput(int side, double value) {
    if (!canControl || !analog || side < 0 || side > 1 || !value.isFinite)
      return;
    analogInputs[side] = value.clamp(-1.0, 1.0);
    if (value == 0) {
      if (side == 0) {
        leftSpeed = 0;
      } else {
        rightSpeed = 0;
      }
    }
  }

  bool get oneFinger => controlMode == ControlMode.oneFinger;
  bool get tiltLift => controlMode == ControlMode.tiltLift;
  bool get boardTilt => controlMode == ControlMode.boardTilt;
  bool get tiltOnly => tiltLift || boardTilt;
  bool get bottomControls => analog || tiltLift;
  bool tiltHeld = false, liftHeld = false;
  bool _tiltPending = false;
  double liftInput = 0;

  void grabTiltLiftAxis({required bool tilt}) {
    if (!canControl || !tiltOnly || (boardTilt && !tilt)) return;
    beginInput();
    if (tilt) {
      tiltHeld = true;
      controlPosition = ((right - left) / 140).clamp(-1.0, 1.0);
    } else {
      liftHeld = true;
    }
    controlHeld = tiltHeld || liftHeld;
  }

  void releaseTiltLiftAxis({required bool tilt}) {
    if (tilt) {
      tiltHeld = false;
    } else {
      liftHeld = false;
      liftInput = 0;
    }
    controlHeld = tiltHeld || liftHeld;
  }

  void setTiltLiftInput({required bool tilt, required double value}) {
    if (!canControl || !tiltOnly || !value.isFinite || (boardTilt && !tilt))
      return;
    if (tilt && tiltHeld) {
      setControlPosition(value);
      _tiltPending = true;
    } else if (!tilt && liftHeld) {
      liftInput = value.clamp(-1.0, 1.0);
    }
  }

  int level = 1, runSerial = 0;
  CabinetStyle cabinet = CabinetStyle.brass;
  DateTime? dailyDate;

  /// Modes whose camera follows the climb instead of holding the whole board.
  bool get scrolling => infinite;
  bool get laserSideRails => mode == GameMode.classic && level > 30;
  static const sideRailX = 20.0, sideLaserWidth = 6.0;
  static const sideLaserContactX = sideRailX + sideLaserWidth / 2 + ballRadius;
  // Infinite allows manual upward travel of 21.25% of the board from its start.
  double get minPivot =>
      infinite ? infiniteStart - height * .2125 - cameraOffset : 30.0;
  // A growing Merge tail may leave the screen; it never lifts the platform.
  double get maxPivot => scrolling ? 526 - cameraOffset : 526.0;
  bool get merging => mode == GameMode.merge2048;
  MergeRun? _mergeRun;
  MergeRun get mergeRun => _mergeRun ??= MergeRun();
  set mergeRun(MergeRun value) => _mergeRun = value;
  bool get hasMergeResources => _mergeRun != null;
  bool get daily => mode == GameMode.daily;
  String get dailyKey =>
      dailyDate == null ? '' : DailyChallenge.key(dailyDate!);
  bool get finale =>
      mode == GameMode.classic &&
      (ClassicLevels.definition(level).finaleTitle.isNotEmpty ||
          ClassicLevels.definition(level).hazards.isNotEmpty);
  String get finaleTitle => finale ? ClassicLevels.finaleTitle(level) : '';
  final coins = <BrassCoin>[];
  LevelStar? levelStar;
  bool levelStarAlreadyOwned = false;
  bool get levelStarCollected => levelStar?.collected ?? false;
  double lastStarAge = 99;
  int coinsCollected = 0;
  double lastCoinAge = 99, lastCoinX = 0, lastCoinY = 0;
  double targetTime = 180, _nextFinaleAt = 3;
  int _finaleSequence = 0;
  double _classicSceneTime = 0;
  final _spawnOverlappingHazards = <SpecialHazard>{};
  final _spawnOverlappingSpiders = <BoardSpider>{};
  int get earnedStarMask =>
      (mode == GameMode.classic && finished && won && levelStarCollected
          ? 8
          : 0) |
      (!finished || !won || practice || infinite || merging
          ? 0
          : 1 | (misses == 0 ? 2 : 0) | (elapsed <= targetTime ? 4 : 0));
  InfiniteSection get section => sectionAt(maxHeight / 10);

  final spiders = <BoardSpider>[];
  bool caughtBySpider = false;
  bool get spiderLevel =>
      mode == GameMode.classic &&
      ClassicLevels.definition(level).spiders.isNotEmpty;
  List<Hole> _classicBoard = [];

  /// Seconds of Classic hole animation. Moving and breathing holes run while
  /// the level is shown, before the first touch too, and stop only for pause.
  double holeTime = 0;
  int? _sinkingHole;
  void _moveHoles(double dt) {
    holeTime += dt;
    final holes = _classicBoard;
    for (var i = 0; i < holes.length; i++) {
      if (holes[i].animated) holes[i] = holes[i].at(holeTime);
    }
    // A ball sinking into a moving hole travels with it.
    if (phase == GamePhase.playing) _sinkingHole = null;
    final sinking = _sinkingHole;
    if (phase == GamePhase.sinking && sinking != null && sinking < holes.length) {
      captureX = holes[sinking].x;
      captureY = holes[sinking].y;
    }
  }

  double controlPosition = 0;
  bool controlHeld = false;
  double _controlLift = 0;
  void grabControl() {
    if (canControl && oneFinger) {
      beginInput();
      controlHeld = true;
    }
  }

  void releaseControl() {
    controlHeld = false;
  }

  /// Board units a second at full deflection: a whole rail in about 3.5s.
  static const liftMotor = 140.0;

  void dragControlVertical(double delta) {
    if (!canControl || !oneFinger || !controlHeld || !delta.isFinite) return;
    _controlLift += delta;
    if (infinite) {
      _steeringDistance += delta.abs();
      if (_steeringDistance >= 8) {
        stallTime = 0;
        _steeringDistance = 0;
      }
    }
  }

  void setControlPosition(double value) {
    if (!canControl || !value.isFinite) return;
    final next = value.clamp(-1.0, 1.0);
    if (infinite) {
      _steeringDistance += (next - controlPosition).abs() * 140;
      if (_steeringDistance >= 8) {
        stallTime = 0;
        _steeringDistance = 0;
      }
    }
    controlPosition = next;
  }

  void setControlMode(ControlMode value) {
    clearInput();
    preferredControlMode = value;
    controlMode = value;
    controlPosition = ((right - left) / 140).clamp(-1.0, 1.0);
  }

  static const width = 360.0, height = 560.0, ballRadius = 7.0;

  /// Where a Classic platform rests at the start. The same for every control,
  /// so the ball starts at the same height whichever one is chosen.
  static const launchHeight = 500.0;

  static const holes = <Hole>[
    Hole(103, 461, target: 1),
    Hole(265, 417, target: 2),
    Hole(72, 362, target: 3),
    Hole(220, 312, target: 4),
    Hole(128, 260, target: 5),
    Hole(284, 213, target: 6),
    Hole(73, 166, target: 7),
    Hole(225, 122, target: 8),
    Hole(131, 81, target: 9),
    Hole(244, 43, target: 10),
    Hole(46, 484),
    Hole(173, 478),
    Hole(310, 477),
    Hole(54, 423),
    Hole(155, 423),
    Hole(206, 402),
    Hole(120, 380),
    Hole(294, 370),
    Hole(167, 349),
    Hole(42, 308),
    Hole(108, 310),
    Hole(279, 314),
    Hole(321, 282),
    Hole(64, 251),
    Hole(188, 266),
    Hole(239, 247),
    Hole(116, 210),
    Hole(176, 205),
    Hole(43, 199),
    Hole(232, 177),
    Hole(312, 157),
    Hole(135, 155),
    Hole(48, 117),
    Hole(172, 113),
    Hole(279, 107),
    Hole(78, 69),
    Hole(190, 59),
    Hole(308, 53),
  ];

  GameMode mode = GameMode.classic;
  final List<Hole> _endlessHoles = [];
  double _nextRowY = 250, _corridor = 180;
  double _nextSpiderY = -1800;
  final webShots = <SpiderWebShot>[];
  double _nextWebTime = 0;
  final porcupines = <BoardPorcupine>[];
  final quills = <PorcupineQuill>[];
  final snakes = <BoardSnake>[];
  LateEnemyEncounter? lateEnemy;
  bool lateEnemiesEnabled = true;
  InfiniteBoss? boss;
  bool bossesEnabled = true;
  int bossesEncountered = 0;
  List<BossKind> _bossOrder = List.unmodifiable(BossKind.values);
  List<BossKind> get bossOrder => _bossOrder;
  List<int> _bossScoreThresholds = const [
    100000,
    300000,
    600000,
    900000,
    1275000,
  ];
  List<int> get bossScoreThresholds => _bossScoreThresholds;
  double _nextBossAt = 0;
  double _lastDamageAt = double.negativeInfinity;
  double? _bossWarningAt;
  int? get bossWarningSeconds => _bossWarningAt == null
      ? null
      : math.max(1, (_bossWarningAt! + 3 - elapsed).ceil());
  bool get bossPending =>
      infinite &&
      !tutorialCourse &&
      bossesEnabled &&
      bossesEncountered < BossKind.values.length &&
      elapsed >= _nextBossAt &&
      score >= bossScoreThresholds[bossesEncountered];
  EncounterDirector enemyDirector = EncounterDirector(0);
  // Like mazeSectionsEnabled, lets callers isolate the ordinary hazard stream.
  bool snakeEncountersEnabled = true;
  // Only the guided opening replaces generation; contacts and controls remain real.
  bool tutorialCourse = false;
  double tutorialAscent = 30;

  void endTutorialCourse() {
    if (!tutorialCourse) return;
    tutorialCourse = false;
    _nextRowY = ballY - 220;
    _nextCoinY = ballY - 140;
    survival.nextComboY = ballY - 300;
    survival.nextShieldY = ballY - 600;
    survival.nextHeartY = ballY - 1200;
    survival.nextMagnetY = ballY - 800;
    stallTime = 0;
    dangerY = math.max(dangerY, ballY + 120);
  }

  double _nextPorcupineY = -2700, _nextQuillTime = 0;
  double cameraOffset = 0, maxHeight = 0, stallTime = 0, dangerY = 580;
  double _steeringDistance = 0;
  double _nextCoinY = 380;

  /// Generate in world coordinates once, then prune below the camera. Coins
  /// remain separate from height so collecting them cannot inflate metres.
  void ensureEndlessExtras({bool retainForSweep = false}) {
    if (!infinite || tutorialCourse) return;
    final ahead = -cameraOffset - 100;
    while (_nextCoinY >= ahead) {
      final y = _nextCoinY;
      for (var attempt = 0; attempt < 100; attempt++) {
        final x = 38 + _random.nextDouble() * 284;
        if (board.any(
          (h) => math.pow(h.x - x, 2) + math.pow(h.y - y, 2) < 30 * 30,
        ))
          continue;
        if (spiders.any(
          (s) =>
              math.pow(s.homeX - x, 2) + math.pow(s.homeY - y, 2) <
              math.pow(s.zoneRadius + 12, 2),
        ))
          continue;
        if (porcupines.any(
          (p) => math.pow(p.x - x, 2) + math.pow(p.y - y, 2) < 42 * 42,
        ))
          continue;
        coins.add(BrassCoin(x, y));
        break;
      }
      _nextCoinY -=
          InfiniteTuning.coinSpacing +
          _random.nextDouble() * InfiniteTuning.coinSpacingJitter;
    }
    if (!retainForSweep) coins.removeWhere((c) => screenY(c.y) > 620);
  }

  static const infiniteStart = 440.0;
  // Logical top of the expanded portrait viewport, in board coordinates.
  double visibleTop = 0;

  /// Lowest visible world y; below 560 when a two-finger board is drawn
  /// down through its handle strip.
  double visibleBottom = height;
  static const firstRow = 300.0;

  static double difficultyAt(double progress) {
    return InfiniteTuning.difficultyAt(progress);
  }

  double get difficulty => difficultyAt(maxHeight / 10);
  double get ascentSpeed {
    final normalSpeed =
        InfiniteTuning.startSpeed +
        (InfiniteTuning.baseTopSpeed - InfiniteTuning.startSpeed) *
            difficulty *
            InfiniteDifficulty.speedGrowth +
        (infinite
            ? InfiniteTuning.paceSpeedBonus *
                  (pace - 1) *
                  InfiniteDifficulty.paceGrowth
            : 0);
    if (!infinite || tutorialCourse || _runStartingSpeedMultiplier <= 1) {
      return normalSpeed;
    }
    final t = (elapsed / InfiniteTuning.fastStartEaseSeconds).clamp(0.0, 1.0);
    final ease = t * t * (3 - 2 * t);
    final openingSpeed =
        InfiniteTuning.startSpeed *
        (1 + (_runStartingSpeedMultiplier - 1) * ease);
    // Normal progression catches up to this floor; the late-run ceiling stays.
    return math.max(normalSpeed, openingSpeed);
  }

  final specialHazards = <SpecialHazard>[];

  /// Infinite's laser maze interludes: a stretch where the hole stream stops
  /// and wide laser gates come down instead.
  final mazeGates = <MazeGate>[];

  /// Turns the interludes off for callers that want the plain hole climb,
  /// including tests that isolate the ordinary hazard scheduler.
  bool mazeSectionsEnabled = true;
  double _nextMazeMetres = 0, _mazeEndMetres = 0, _lastGateY = 0;
  double _mazeSectionTime = 0;
  bool get mazeSection => infinite && mazeSectionsEnabled && _mazeEndMetres > 0;
  double _nextHazardTime = 0;
  int _introducedHazards = 0, _hazardSequence = 0, _hardHazardSequence = 0;
  bool fellThroughGap = false;
  String get hazardLabel => mazeSection
      ? 'LASER MAZE'
      : specialHazards.isEmpty
      ? ''
      : specialHazards.first.label;

  void _updateSpecialHazards(double dt) {
    specialHazards.removeWhere((h) => h.expired || h.y > 620);
    for (final hazard in specialHazards) {
      hazard.step(dt, ascentSpeed, cameraOffset: cameraOffset);
    }
    if (specialHazards.isNotEmpty ||
        boss != null ||
        bossPending ||
        lateEnemy != null ||
        webShots.isNotEmpty ||
        snakes.isNotEmpty ||
        quills.isNotEmpty ||
        porcupines.any((p) => p.charge != null) ||
        mazeSection ||
        elapsed < _nextHazardTime ||
        metres * InfiniteDifficulty.hazardUnlocks <
            InfiniteTuning.hazardMilestones.first ||
        section == InfiniteSection.breath)
      return;
    final distanceUnlocked = InfiniteTuning.hazardMilestones
        .where((m) => metres * InfiniteDifficulty.hazardUnlocks >= m)
        .length;
    // The temporary platform cut is a late-score challenge. Earlier runs can
    // still introduce and repeat the other distance-based hazards.
    final unlocked = math.min(
      distanceUnlocked,
      score >= InfiniteTuning.platformGapUnlockScore
          ? HazardKind.values.length
          : HazardKind.platformGap.index,
    );
    final index = _introducedHazards < unlocked
        ? _introducedHazards++
        : (_hazardSequence + 1 + _random.nextInt(math.max(1, unlocked - 1))) %
              unlocked;
    _hazardSequence = index;
    final hard =
        _random.nextDouble() <
            InfiniteTuning.complexityAt(metres.toDouble()) *
                InfiniteDifficulty.hardHazards &&
        section == InfiniteSection.encounter &&
        distanceUnlocked >= 4 &&
        _introducedHazards >= 3;
    final sweeping = hard && _hardHazardSequence % 3 == 0;
    final zigzag = hard && _hardHazardSequence % 3 == 1;
    final orbiting = hard && _hardHazardSequence % 3 == 2;
    if (hard) _hardHazardSequence++;
    final kind = hard
        ? (sweeping ? HazardKind.laser : HazardKind.movingHole)
        : HazardKind.values[index];
    final lane = 95.0 + _random.nextDouble() * 170;
    specialHazards.add(
      SpecialHazard(
        kind,
        x: zigzag
            ? 180
            : orbiting
            ? lane.clamp(110.0, 250.0)
            : lane,
        y: zigzag
            ? 55
            : orbiting
            ? (screenY(ballY) - 45).clamp(visibleTop + 105, 405.0)
            : (screenY(ballY) - 150).clamp(75.0, 300.0),
        motion: orbiting ? HazardMotion.circle : HazardMotion.legacy,
        radiusX: InfiniteTuning.orbitRadius,
        period: InfiniteTuning.orbitPeriod,
        phase: orbiting ? -math.pi / 2 : 0,
        sweeping: sweeping,
        zigzag: zigzag,
        warningSeconds: kind == HazardKind.platformGap ? 2.4 : 2.0,
        cameraOffset: cameraOffset,
        liveSeconds: orbiting
            ? InfiniteTuning.orbitLifeSeconds
            : kind == HazardKind.formingHole
            ? double.infinity
            : sweeping
            ? 3.5
            : zigzag
            ? 550 / (ascentSpeed * 1.35 + 35)
            : kind == HazardKind.laser
            ? 1.4
            : kind == HazardKind.platformGap
            ? 2.5
            : 450 / ascentSpeed,
      ),
    );
    // One special hazard at a time, with recovery time before the next warning.
    _nextHazardTime =
        elapsed +
        (section == InfiniteSection.encounter ? 16 : 20) -
        (section == InfiniteSection.encounter ? 12.5 : 13.5) *
            difficulty *
            InfiniteDifficulty.hazardFrequency;
  }

  bool get infinite => mode == GameMode.infinite;
  bool get practice => mode == GameMode.practice;
  List<Hole> get board => merging
      ? const []
      : infinite
      ? _endlessHoles
      : _classicBoard;
  int get roundCompleted => completed;
  double screenY(double worldY) => worldY + (scrolling ? cameraOffset : 0);
  bool get dangerActive =>
      infinite && !tutorialCourse && boss == null && stallTime >= 10;
  double get dangerDistance => dangerY - ballY;

  void ensureInfiniteBoard({bool retainForSweep = false}) {
    if (!infinite || tutorialCourse) return;
    if (boss != null) {
      _nextRowY = math.min(_nextRowY, -cameraOffset + visibleTop - 121);
      return;
    }
    while (_nextRowY >= -cameraOffset + visibleTop - 120) {
      final growth = InfiniteTuning.runDensity(score, maxHeight / 10);
      final d = growth * InfiniteDifficulty.obstacleDensity;
      final stage = sectionAt(math.max(0, (infiniteStart - _nextRowY) / 10));
      final spacing =
          (210 - 130 * d + _random.nextDouble() * 30) *
          stage.spacingFactor /
          (1 + (pace - 1) * .035 * InfiniteDifficulty.paceGrowth);
      final previous = _corridor;
      final turn = math.min(52.0, spacing * .42);
      _corridor = (_corridor + (_random.nextDouble() * 2 - 1) * turn).clamp(
        70.0,
        290.0,
      );
      _spawnInfiniteSpider(_nextRowY, previous, _corridor, stage);
      _spawnInfinitePorcupine(_nextRowY, previous, _corridor, stage);
      final selected = <Hole>[];
      final recent = _endlessHoles.reversed.take(3).toList().reversed.toList();
      final density = ((1 + 3 * d) * stage.densityFactor).clamp(1.0, 4.0);
      final count =
          density.floor() + (_random.nextDouble() < density % 1 ? 1 : 0);
      for (
        int attempt = 0;
        attempt < 100 && selected.length < count;
        attempt++
      ) {
        final x = 28 + _random.nextDouble() * 304;
        final depth = _random.nextDouble();
        final y = _nextRowY - depth * spacing;
        final safeX = previous + (_corridor - previous) * depth;
        // Break accidental one-sided streaks without prescribing alternating pairs.
        if (recent.length == 3 &&
            recent.every((h) => (h.x < 180) == (x < 180))) {
          continue;
        }
        // Scatter in two dimensions. Only the local winding route is reserved;
        // there are no left/right templates or common horizontal hole rows.
        bool separated(Hole h) =>
            (h.y - y).abs() > 12 &&
            (h.x - x) * (h.x - x) + (h.y - y) * (h.y - y) > 36 * 36;
        if ((x - safeX).abs() >
                46 - 12 * growth * InfiniteDifficulty.pathNarrowing &&
            spiders.every(
              (s) =>
                  math.pow(s.zoneX - x, 2) + math.pow(s.zoneY - y, 2) >
                  math.pow(s.zoneRadius + 20, 2),
            ) &&
            porcupines.every(
              (p) => math.pow(p.x - x, 2) + math.pow(p.y - y, 2) > 44 * 44,
            ) &&
            selected.every(separated) &&
            _endlessHoles.where((h) => (h.y - y).abs() < 36).every(separated)) {
          selected.add(Hole(x, y));
          recent.add(selected.last);
          if (recent.length > 3) recent.removeAt(0);
        }
      }
      _endlessHoles.addAll(selected);
      _nextRowY -= spacing;
    }
    if (!retainForSweep)
      _endlessHoles.removeWhere((hole) => screenY(hole.y) > 620);
    if (!retainForSweep) _pruneInfiniteSpiders();
    if (!retainForSweep) _pruneInfinitePorcupines();
  }

  void _updateClimb(double dt) {
    maxHeight = math.max(maxHeight, infiniteStart - ballRadius - ballY);
    survival.step(dt, maxHeight / 10);
    score = survival.points.floor();
    _tryStartInfiniteBoss();
    if (leftInput != 0 || rightInput != 0) {
      stallTime = 0;
    } else {
      stallTime += dt;
    }
    // Only automatic ascent moves the camera; manual lifts stop at minPivot.
    if (tutorialCourse) {
      dangerY = 640 - cameraOffset;
      return;
    }
    if (boss != null) {
      stallTime = 0;
      dangerY = 580 - cameraOffset;
    } else {
      dangerY = math.min(dangerY, 580 - cameraOffset);
    }
    if (dangerActive) dangerY -= (24 + math.min(stallTime - 3, 5) * 16) * dt;
    message = dangerActive
        ? 'KEEP STEERING! The red is rising.'
        : 'Tilt to dodge. The board keeps moving.';
    _updateMazeSection(dt);
    // The maze replaces the course while it lasts: no new holes fall into it.
    if (!mazeSection) ensureInfiniteBoard(retainForSweep: true);
    ensureEndlessExtras(retainForSweep: true);
    _ensureInfiniteItems();
    if (survival.noticeTime > 0) message = survival.notice;
    if (boss != null) message = boss!.hint;
    if (bossWarningSeconds != null)
      message =
          'BOSS · ${bossOrder[bossesEncountered].name} IN $bossWarningSeconds';
  }

  void _loseClimb(String reason, {Hole? hole}) {
    if (survival.protected) return;
    survival.breakCombo();
    captureX = hole?.x ?? ballX;
    captureY = hole?.y ?? ballY;
    lives--;
    _lastDamageAt = elapsed;
    _bossWarningAt = null;
    misses++;
    lastSuccess = false;
    message = reason;
    event = GameEvent.miss;
    if (lives > 0) {
      _recoverInfinite();
      return;
    }
    clearInput();
    velocity = leftSpeed = rightSpeed = 0;
    phase = GamePhase.sinking;
    phaseTime = 0;
    if (boss != null) _nextBossAt = math.max(_nextBossAt, elapsed + 60);
    boss = null;
    _bossWarningAt = null;
  }

  double left = 526, right = 526, ballX = 180, velocity = 0;
  double ballRotation = 0;
  final ballTrail = <({double x, double y, double time})>[];
  double motionSpeed = 0;
  double leftSpeed = 0, rightSpeed = 0;
  double leftInput = 0, rightInput = 0;
  double clock = 0, legTime = 0, elapsed = 0, phaseTime = 0;
  double captureX = 180, captureY = 519, returnLeft = 526, returnRight = 526;
  int target = 1, lives = 3, score = 0, streak = 0, bestStreak = 0;
  int get heartCapacity => merging
      ? 1
      : infinite
      ? infiniteMaxLives
      : InfiniteTuning.maxLives;
  int lastAward = 0, completed = 0, misses = 0, inputEpoch = 0;
  bool started = false, paused = false, won = false;
  bool infiniteReviveUsed = false;
  bool get canReviveInfinite =>
      started &&
      infinite &&
      finished &&
      lives <= 0 &&
      !won &&
      !infiniteReviveUsed;

  /// Called only after a rewarded ad has earned its reward and closed.
  /// Keep the same world, score, coin ledger and run identity.
  bool reviveInfinite() {
    if (!canReviveInfinite) return false;
    infiniteReviveUsed = true;
    lives = 1;
    phase = GamePhase.playing;
    phaseTime = 0;
    paused = waitingForInput = false;
    inputLocked = false;
    clearInput();
    velocity = leftSpeed = rightSpeed = 0;
    ballTrail.clear();
    motionSpeed = 0;
    fellThroughGap = caughtBySpider = false;
    stallTime = _steeringDistance = 0;
    dangerY = math.max(dangerY, ballY + 140);
    survival.recovery = 3;
    lateEnemy = null;
    boss = null;
    snakes.clear();
    _bossWarningAt = null;
    _lastDamageAt = elapsed;
    enemyDirector.rest(elapsed, metres.toDouble());
    survival.announce('BACK IN PLAY · 1 heart · 3 seconds of protection');
    message = survival.notice;
    event = null;
    return true;
  }

  bool waitingForInput = false;
  // Selection gestures block new control contacts synchronously, including a
  // second finger arriving before Flutter has rebuilt its IgnorePointer layer.
  bool inputLocked = false;
  void Function()? onInputStarted;
  bool lastSuccess = false;
  GamePhase phase = GamePhase.playing;
  GameEvent? event;
  String message = 'Ten holes. Two thumbs. Steady nerves.';
  bool get finished => phase == GamePhase.over;
  bool get canControl =>
      started && !paused && !inputLocked && phase == GamePhase.playing;

  // Draws from the preview random while waiting, so previews never consume
  // the real run's randomness; beginInput re-seeds from the run random.
  void _seedEncounters() {
    final encounterSeed = _random.nextInt(1 << 30);
    enemyDirector = EncounterDirector(encounterSeed);
    final bossRandom = math.Random(encounterSeed ^ 0xB055);
    _bossOrder = List.unmodifiable(
      BossKind.values.toList()..shuffle(bossRandom),
    );
    _bossScoreThresholds = List.unmodifiable([
      // Score windows belong to encounter slots, independently of boss order.
      for (final kind in BossKind.values)
        kind.minimumScore +
            bossRandom.nextInt(kind.maximumScore - kind.minimumScore + 1),
    ]);
  }

  /// Activate the prepared board without resetting input or rebuilding a run.
  /// The caller continues handling this same key/pointer event as movement.
  void beginInput() {
    if (!canControl || !waitingForInput) return;
    if (_previewRandom != null) {
      _previewRandom = null;
      // Replace only the course. Keep pointer ownership, platform and input
      // epoch intact so this very same event also controls the new run.
      if (infinite) {
        // Same draw order as a direct start: encounters first, then course.
        _seedEncounters();
        _endlessHoles.clear();
        coins.clear();
        _nextRowY = 300 + _random.nextDouble() * 20;
        _corridor = 150 + _random.nextDouble() * 60;
        // Drawn in the same order as a fresh start, so waiting first and
        // playing straight away consume identical run randomness.
        _nextMazeMetres =
            InfiniteTuning.mazeFirstMetres + _random.nextDouble() * 120;
        mazeGates.clear();
        _mazeEndMetres = _lastGateY = _mazeSectionTime = 0;
        _nextCoinY = 380;
        ensureInfiniteBoard();
      }
      if (merging) mergeRun = MergeRun(seed: _random.nextInt(1 << 30));
      ensureEndlessExtras();
    }
    waitingForInput = false;
    onInputStarted?.call();
  }

  Hole? get activeHole =>
      board.where((h) => h.target == target.clamp(1, 10)).firstOrNull;
  double get ballY =>
      platformY(ballX) - (merging ? MergeRun.ballRadius : ballRadius);
  double platformY(double x) => left + (right - left) * ((x - 20) / 320);
  double get visualX => phase == GamePhase.sinking ? captureX : ballX;
  double get visualY => phase == GamePhase.sinking
      ? captureY + (fellThroughGap ? 100 * phaseTime * phaseTime : 0)
      : ballY;
  double get ballScale => caughtBySpider
      ? 0
      : phase == GamePhase.sinking
      ? (1 - phaseTime / .38).clamp(0.0, 1.0)
      : phase == GamePhase.returning
      ? 0
      : 1;
  int get multiplier => (1 + streak ~/ 3).clamp(1, 4);

  final pivotTargets = <double?>[null, null];
  final _released = [false, false];

  void grabPivot(int side) {
    if (!canControl) return;
    beginInput();
    _released[side] = false;
    pivotTargets[side] = side == 0 ? left : right;
  }

  void dragPivot(int side, double delta) {
    if (!canControl || !delta.isFinite || pivotTargets[side] == null) return;
    final other = side == 0 ? right : left;
    final minimum = infinite ? math.max(other - 180, minPivot) : minPivot;
    final maximum = infinite ? math.min(maxPivot, other + 180) : maxPivot;
    final previous = pivotTargets[side]!;
    pivotTargets[side] = (previous + delta).clamp(minimum, maximum);
    if (infinite) {
      _steeringDistance += (pivotTargets[side]! - previous).abs();
      if (_steeringDistance >= 8) {
        stallTime = 0;
        _steeringDistance = 0;
      }
    }
  }

  void releasePivot(int side) {
    final position = side == 0 ? left : right;
    _released[side] =
        pivotTargets[side] != null &&
        (pivotTargets[side]! - position).abs() > .0001;
    if (!_released[side]) pivotTargets[side] = null;
    if (side == 0) {
      leftSpeed = 0;
    } else {
      rightSpeed = 0;
    }
  }

  void clearInput() {
    tiltHeld = liftHeld = _tiltPending = false;
    liftInput = 0;
    controlHeld = false;
    _controlLift = 0;
    leftSpeed = rightSpeed = 0;
    pivotTargets.fillRange(0, 2, null);
    _released.fillRange(0, 2, false);
    leftInput = rightInput = 0;
    analogInputs.fillRange(0, 2, 0);
    inputEpoch++;
  }

  void setPaused(bool value) {
    paused = value;
    clearInput();
  }

  void resetBall() {
    ballTrail.clear();
    motionSpeed = 0;
    left = right = infinite ? infiniteStart : launchHeight;
    ballX = 180;
    ballRotation = 0;
    velocity = leftSpeed = rightSpeed = 0;
    legTime = 0;
    controlPosition = 0;
    clearInput();
    _spawnOverlappingHazards.clear();
    _spawnOverlappingSpiders.clear();
    if (mode == GameMode.classic) {
      // Continuing enemies can occupy the launch point during the ball return.
      // Ignore only those overlaps until the ball separates; do not reset them.
      _spawnOverlappingHazards.addAll(
        specialHazards.where(
          (h) =>
              h.active &&
              h.hits(ballX, ballY, ballX, ballY, boardTop: visibleTop),
        ),
      );
      _spawnOverlappingSpiders.addAll(
        spiders.where(
          (s) =>
              math.pow(s.x - ballX, 2) + math.pow(s.y - ballY, 2) <=
              math.pow(s.bodyRadius + ballRadius, 2),
        ),
      );
    }
  }

  void start({
    GameMode gameMode = GameMode.classic,
    int levelNumber = 1,
    DateTime? challengeDate,
    bool waitForInput = false,
  }) {
    runSerial++;
    infiniteReviveUsed = false;
    tutorialCourse = false;
    mode = gameMode;
    // Every generated mode holds the baked carousel layout while it waits, so
    // swiping back shows the same starting position instead of a new draw.
    _previewRandom = waitForInput && (infinite || merging)
        ? math.Random(711)
        : null;
    // A mode switch releases the previous mode's generated world. These
    // objects own no tickers; the screen drives only this active simulation.
    if (!merging) _mergeRun = null;
    _runStartingSpeedMultiplier = infinite
        ? infiniteStartingSpeedMultiplier.clamp(
            1.0,
            InfiniteTuning.maxStartingSpeedMultiplier,
          )
        : 1;
    survival = InfiniteProgress(
      startingPace: infinite ? infiniteStartingPace : 1,
      scoreBoost: equipmentMultiplier,
    );
    controlMode = preferredControlMode;
    if (merging) mergeRun = MergeRun(seed: _random.nextInt(1 << 30));
    dailyDate = daily
        ? DailyChallenge.day(challengeDate ?? DateTime.now())
        : null;
    level = daily ? 15 : levelNumber.clamp(1, ClassicLevels.count);
    _classicSceneTime = 0;
    _nextFinaleAt = mode == GameMode.classic
        ? ClassicLevels.definition(level).firstHazardAfter
        : 3;
    _finaleSequence = 0;
    holeTime = 0;
    _sinkingHole = null;
    _classicBoard = infinite || merging
        ? []
        : practice
        ? List<Hole>.of(holes)
        : ClassicLevels.build(
            level,
            dailySeed: daily ? DailyChallenge.seed(dailyDate!) : null,
          );
    // Place animated holes at their first frame before anything is drawn.
    _moveHoles(0);
    spiders.clear();
    webShots.clear();
    _nextWebTime = 0;
    porcupines.clear();
    quills.clear();
    snakes.clear();
    lateEnemy = null;
    boss = null;
    bossesEncountered = 0;
    _nextBossAt = 0;
    _lastDamageAt = double.negativeInfinity;
    _bossWarningAt = null;
    if (infinite) _seedEncounters();
    _nextPorcupineY = -2700;
    _nextQuillTime = 0;
    if (spiderLevel)
      spiders.addAll(
        ClassicLevels.definition(level).spiders.map((s) => s.create()),
      );
    caughtBySpider = false;
    coins.clear();
    if (daily) coins.addAll(ClassicLevels.coinsFor(_classicBoard, spiders));
    levelStar = mode == GameMode.classic && !levelStarAlreadyOwned
        ? ClassicLevels.starForLevel(level)
        : null;
    lastStarAge = 99;
    coinsCollected = 0;
    lastCoinAge = 99;
    // Active-time targets: fixed lift time plus steering allowance and trap detours.
    const launch = launchHeight;
    final liftTime =
        _classicBoard
            .where((h) => h.target > 0)
            .fold(
              0.0,
              (sum, h) => sum + (launch - h.y - ballRadius).clamp(0.0, 560.0),
            ) /
        (oneFinger ? 20 : 60);
    targetTime =
        (liftTime +
                60 +
                _classicBoard.where((h) => h.target == 0).length * .7 +
                (spiderLevel ? 25 : 0) +
                (finale ? 20 : 0))
            .ceilToDouble();
    cameraOffset = maxHeight = stallTime = _steeringDistance = 0;
    dangerY = 580;
    _nextRowY = 300 + _random.nextDouble() * 20;
    _corridor = 150 + _random.nextDouble() * 60;
    _nextSpiderY = -1800;
    specialHazards.clear();
    mazeGates.clear();
    _nextMazeMetres =
        InfiniteTuning.mazeFirstMetres + _random.nextDouble() * 120;
    _mazeEndMetres = _lastGateY = _mazeSectionTime = 0;
    _nextHazardTime = 0;
    _introducedHazards = _hazardSequence = _hardHazardSequence = 0;
    fellThroughGap = false;
    _endlessHoles.clear();
    score = 0;
    if (infinite) ensureInfiniteBoard();
    _nextCoinY = 380;
    ensureEndlessExtras();
    target = 1;
    if (mode == GameMode.classic) {
      for (final wave in ClassicLevels.definition(level).hazards) {
        if (wave.kind != HazardKind.movingHole) continue;
        final position = wave.positions.firstWhere((p) => p.target == 1);
        specialHazards.add(
          SpecialHazard(
            wave.kind,
            x: position.x,
            y: position.y,
            warningSeconds: 0,
            liveSeconds: double.infinity,
            motion: wave.motion,
            radiusX: wave.radiusX,
            radiusY: wave.radiusY,
            period: wave.period,
            phase: wave.phase,
          ),
        );
      }
    }
    lives = merging
        ? 1
        : infinite
        ? infiniteMaxLives
        : InfiniteTuning.maxLives;
    score = streak = bestStreak = completed = misses = 0;
    elapsed = phaseTime = 0;
    won = paused = false;
    started = true;
    waitingForInput = waitForInput;
    inputLocked = false;
    phase = GamePhase.playing;
    event = null;
    message = merging
        ? mergeRun.notice
        : infinite
        ? 'Tilt to dodge. The board keeps moving.'
        : laserSideRails
        ? 'Avoid the side lasers. Find the glowing 01.'
        : 'Raise both ends. Find the glowing 01.';
    resetBall();
  }

  void home() {
    start();
    started = false;
  }

  void step(double dt) {
    if (!dt.isFinite || dt <= 0) return;
    if (waitingForInput) {
      if (!paused && started && mode == GameMode.classic) {
        _moveHoles(math.min(dt, .1));
        for (final hazard in specialHazards) {
          if (hazard.kind == HazardKind.movingHole) {
            hazard.step(math.min(dt, .1), 0);
          }
        }
      }
      return;
    }
    // Bound individual substeps even if a caller accidentally supplies a long frame.
    var remaining = math.min(dt, .1);
    while (remaining > .000001) {
      final h = math.min(remaining, 1 / 120);
      final oldX = ballX, oldY = ballY;
      _tick(h);
      if (!paused) {
        if (started && phase == GamePhase.playing) {
          final distance = math.sqrt(
            math.pow((ballX - oldX) * arenaStretch, 2) +
                math.pow(ballY - oldY, 2),
          );
          // Visual decay spans the two physics ticks in a 60 Hz display frame.
          // It never feeds back into movement or the touch targets.
          motionSpeed = math.max(
            distance / h,
            motionSpeed * math.exp(-h / .07),
          );
          if (motionSpeed < .5) motionSpeed = 0;
          ballTrail.removeWhere((p) => clock - p.time > .2);
          if (distance > .08 && distance < 45) {
            ballTrail.add((x: oldX, y: oldY, time: clock));
            if (ballTrail.length > 24) ballTrail.removeAt(0);
          }
        } else {
          ballTrail.clear();
          motionSpeed = 0;
        }
      }
      remaining -= h;
    }
  }

  void _syncArenaGeometry() {
    for (final h in specialHazards) {
      h.arenaStretch = arenaStretch;
    }
    for (final s in spiders) {
      s.arenaStretch = arenaStretch;
    }
    for (final s in snakes) {
      s.arenaStretch = arenaStretch;
    }
    for (final s in webShots) {
      s.arenaStretch = arenaStretch;
    }
    for (final q in quills) {
      q.arenaStretch = arenaStretch;
    }
    for (final g in mazeGates) {
      g.arenaStretch = arenaStretch;
    }
    final visitor = lateEnemy;
    if (visitor != null) {
      visitor.arenaStretch = arenaStretch;
      for (final shot in visitor.shots) {
        shot.arenaStretch = arenaStretch;
      }
    }
    for (final shot in boss?.shots ?? <LateEnemyShot>[]) {
      shot.arenaStretch = arenaStretch;
    }
  }

  void _tick(double dt) {
    if (paused) return;
    _syncArenaGeometry();
    clock += dt;
    if (!started || finished) return;
    if (mode == GameMode.classic) {
      _classicSceneTime += dt;
      _moveHoles(dt);
      if (phase == GamePhase.sinking || phase == GamePhase.returning) {
        // The ball is hidden, but the level's patrols, chases and hazard cycle
        // keep advancing. Pause still freezes everything at the top of _tick.
        for (final spider in spiders) {
          spider.step(dt, captureX, captureY, captureX, captureY);
        }
        if (finale) _updateFinale(dt, captureX, captureY, canDamage: false);
      }
    }
    if (phase == GamePhase.sinking) {
      phaseTime += dt;
      if (phaseTime >= .7) {
        if (won || (!practice && lives <= 0)) {
          phase = GamePhase.over;
        } else {
          returnLeft = left;
          returnRight = right;
          phase = GamePhase.returning;
          phaseTime = 0;
        }
      }
      return;
    }
    if (phase == GamePhase.returning) {
      phaseTime += dt;
      final t = (phaseTime / .65).clamp(0.0, 1.0);
      final ease = 1 - math.pow(1 - t, 3);
      const launch = launchHeight;
      left = returnLeft + (launch - returnLeft) * ease;
      right = returnRight + (launch - returnRight) * ease;
      if (t >= 1) {
        resetBall();
        phase = GamePhase.playing;
        phaseTime = 0;
      }
      return;
    }
    elapsed += dt;
    lastCoinAge += dt;
    lastStarAge += dt;
    legTime += dt;
    final oldX = ballX, oldY = ballY;
    final oldScreenY = screenY(ballY);
    if (infinite) {
      // Translate the platform and camera equally: grips stay under the fingers
      // while stationary world hazards approach from above. Keep the old world
      // ball position for swept collision against those approaching hazards.
      final travel = (tutorialCourse ? tutorialAscent : ascentSpeed) * dt;
      cameraOffset += travel;
      left -= travel;
      right -= travel;
      dangerY -= travel;
      for (var side = 0; side < 2; side++) {
        if (pivotTargets[side] != null)
          pivotTargets[side] = pivotTargets[side]! - travel;
      }
    }
    // Keyboard motors retain easing. Touch targets below follow in one step.
    final response = 1 - math.exp(-22 * dt);
    final motor = practice ? 78.0 : 91.0;
    leftSpeed += ((leftInput.clamp(-1, 1) * motor) - leftSpeed) * response;
    rightSpeed += ((rightInput.clamp(-1, 1) * motor) - rightSpeed) * response;
    // Consume the latest finger position in one fixed step, with swept collision.
    if (pivotTargets[0] != null) {
      leftSpeed = (pivotTargets[0]! - left) / dt;
    }
    if (pivotTargets[1] != null) {
      rightSpeed = (pivotTargets[1]! - right) / dt;
    }
    final minimum = minPivot;
    final maximum = maxPivot;
    left = (left + leftSpeed * dt).clamp(minimum, maximum);
    right = (right + rightSpeed * dt).clamp(minimum, maximum);
    for (var side = 0; side < 2; side++) {
      if (_released[side]) {
        pivotTargets[side] = null;
        _released[side] = false;
        if (side == 0) {
          leftSpeed = 0;
        } else {
          rightSpeed = 0;
        }
      }
    }
    if (tiltOnly && (_tiltPending || liftHeld)) {
      final halfTilt =
          (_tiltPending ? controlPosition * 70 : (right - left) / 2).clamp(
            -(maximum - minimum) / 2,
            (maximum - minimum) / 2,
          );
      final previousCenter = (left + right) / 2;
      final center = (previousCenter + liftInput * liftMotor * dt).clamp(
        minimum + halfTilt.abs(),
        maximum - halfTilt.abs(),
      );
      left = center - halfTilt;
      right = center + halfTilt;
      _tiltPending = false;
      if (infinite) {
        _steeringDistance += (center - previousCenter).abs();
        if (_steeringDistance >= 8) {
          stallTime = 0;
          _steeringDistance = 0;
        }
      }
    }
    if (oneFinger) {
      final halfTilt = controlPosition * 70;
      final center =
          (controlHeld || _controlLift != 0
                  ? (left + right) / 2 + _controlLift
                  : (left + right) / 2)
              .clamp(minimum + halfTilt.abs(), maximum - halfTilt.abs());
      left = center - halfTilt;
      right = center + halfTilt;
      _controlLift = 0;
    }
    if (infinite && (right - left).abs() > 180) {
      if (left < right) {
        left = right - 180;
      } else {
        right = left - 180;
      }
    }
    // A rolling sphere: 5/7 of gravity projected onto the bar, then onto x.
    final slope = (right - left) / (320 * arenaStretch);
    velocity +=
        (6 / 7) * 1700 * slope / (1 + slope * slope) * dt / arenaStretch;
    velocity *= math.exp(-.48 * dt);
    velocity = velocity.clamp(-265.0 / arenaStretch, 265.0 / arenaStretch);
    ballX += velocity * dt;
    final laserContactX =
        sideRailX + (sideLaserWidth / 2 + ballRadius) / arenaStretch;
    if (laserSideRails &&
        (ballX <= laserContactX || ballX >= width - laserContactX)) {
      ballX = ballX.clamp(laserContactX, width - laserContactX);
      captureX = ballX;
      captureY = ballY;
      lives--;
      misses++;
      streak = 0;
      lastSuccess = false;
      message = 'Side laser hit. Keep the ball away from the edges.';
      event = GameEvent.miss;
      phase = GamePhase.sinking;
      phaseTime = 0;
      velocity = leftSpeed = rightSpeed = 0;
      clearInput();
      return;
    }
    if (merging) mergeRun.arenaStretch = arenaStretch;
    final minimumX = merging ? mergeRun.minHeadX : 20 + 8 / arenaStretch;
    final maximumX = merging ? mergeRun.maxHeadX : 340 - 8 / arenaStretch;
    if (ballX < minimumX) {
      ballX = minimumX;
      velocity = velocity.abs() * .22;
    }
    if (ballX > maximumX) {
      ballX = maximumX;
      velocity = -velocity.abs() * .22;
    }
    // Rolling relative to the bar, excluding its lift and the camera scroll.
    // Signed distance reverses the artwork when the ball rolls back.
    if (!merging) {
      final rolled =
          (ballX - oldX) * arenaStretch * math.sqrt(1 + slope * slope);
      ballRotation = (ballRotation + rolled / ballRadius) % (math.pi * 2);
    }
    if (infinite) {
      _updateClimb(dt);
      if (phase != GamePhase.playing) return;
    }
    if (merging) {
      final collectedBefore = mergeRun.collected;
      mergeRun.step(dt, oldX, oldY, ballX, ballY);
      score = mergeRun.score;
      message = mergeRun.notice;
      if (mergeRun.collected != collectedBefore) event = GameEvent.merge;
      if (mergeRun.ended) {
        won = false;
        phase = GamePhase.over;
        lives = 0;
        event = GameEvent.miss;
        velocity = 0;
        clearInput();
      }
      return;
    }
    if (infinite) {
      if (!tutorialCourse) {
        _updateInfiniteBoss(dt, cameraOffset - (oldScreenY - oldY));
        _updateLateEnemies(dt, cameraOffset - (oldScreenY - oldY));
        _updateSnakes(dt);
        _updateSpecialHazards(dt);
      }
      _resolveInfiniteContacts(oldX, oldY, oldScreenY, dt);
      // Discard only after the entire swept movement has been resolved.
      _endlessHoles.removeWhere((h) => screenY(h.y) > 620);
      specialHazards.removeWhere((h) => h.expired || h.y > 620);
      coins.removeWhere((c) => screenY(c.y) > 620);
      survival.items.removeWhere((item) => screenY(item.y) > 610);
      _pruneInfiniteSpiders();
      _pruneInfinitePorcupines();
      final hadSnake = snakes.isNotEmpty;
      snakes.removeWhere(
        (s) =>
            s.expired ||
            s.points.every((p) => screenY(p.y) > 640 || p.x < -24 || p.x > 384),
      );
      if (hadSnake && snakes.isEmpty)
        enemyDirector.rest(elapsed, metres.toDouble());
      quills.removeWhere(
        (q) =>
            q.expired ||
            q.x < -12 ||
            q.x > 372 ||
            screenY(q.y) < visibleTop - 30 ||
            screenY(q.y) > 622,
      );
      webShots.removeWhere(
        (shot) =>
            shot.expired ||
            shot.x < 0 ||
            shot.x > 360 ||
            screenY(shot.y) < visibleTop - 30 ||
            screenY(shot.y) > 610,
      );
      return;
    }
    Hole? hit;
    if (_updateSpiders(dt, oldX, oldY)) return;
    var firstContact = double.infinity;
    for (final hole in board) {
      // Swept segment collision prevents fast balls skipping a hole between frames.
      final dx = (ballX - oldX) * arenaStretch, dy = ballY - oldY;
      final length2 = dx * dx + dy * dy;
      final t = length2 == 0
          ? 0.0
          : (((hole.x - oldX) * arenaStretch * dx + (hole.y - oldY) * dy) /
                    length2)
                .clamp(0.0, 1.0);
      final hx = (oldX - hole.x) * arenaStretch + dx * t,
          hy = oldY + dy * t - hole.y;
      final radius =
          (practice && hole.target == target ? 10.5 : 8.5) * hole.size;
      if (hx * hx + hy * hy <= radius * radius) {
        final ox = (oldX - hole.x) * arenaStretch, oy = oldY - hole.y;
        final projection = ox * dx + oy * dy;
        final contact = length2 == 0
            ? 0.0
            : ((-projection -
                          math.sqrt(
                            math.max(
                              0,
                              projection * projection -
                                  length2 *
                                      (ox * ox + oy * oy - radius * radius),
                            ),
                          )) /
                      length2)
                  .clamp(0.0, 1.0);
        if (contact < firstContact) {
          firstContact = contact;
          hit = hole;
        }
      }
    }
    if (finale) {
      _updateFinale(dt, oldX, oldY, canDamage: hit == null);
      if (phase != GamePhase.playing) return;
    }
    final fraction = firstContact.isFinite ? firstContact : 1.0;
    _collectLevelStar(
      oldX,
      oldY,
      oldX + (ballX - oldX) * fraction,
      oldY + (ballY - oldY) * fraction,
    );
    _collectCoins(
      oldX,
      oldY,
      oldX + (ballX - oldX) * fraction,
      oldY + (ballY - oldY) * fraction,
    );
    if (hit != null) _capture(hit);
  }

  void _collectCoins(double ax, double ay, double bx, double by) {
    final dx = (bx - ax) * arenaStretch,
        dy = by - ay,
        length = dx * dx + dy * dy;
    for (final coin in coins.where((c) => !c.collected)) {
      final t = length == 0
          ? 0.0
          : (((coin.x - ax) * arenaStretch * dx + (coin.y - ay) * dy) / length)
                .clamp(0.0, 1.0);
      if (math.pow((ax - coin.x) * arenaStretch + t * dx, 2) +
              math.pow(ay + t * dy - coin.y, 2) <=
          12 * 12) {
        _takeCoin(coin);
      }
    }
  }

  void _takeCoin(BrassCoin coin) {
    if (mode == GameMode.classic) return;
    if (coin.collected) return;
    coin.collected = true;
    coinsCollected++;
    if (!scrolling) score += 250;
    lastCoinAge = 0;
    lastCoinX = coin.x;
    lastCoinY = coin.y;
    event = GameEvent.coin;
  }

  void _collectLevelStar(double ax, double ay, double bx, double by) {
    final star = levelStar;
    if (mode != GameMode.classic || star == null || star.collected) return;
    final dx = (bx - ax) * arenaStretch,
        dy = by - ay,
        length = dx * dx + dy * dy;
    final t = length == 0
        ? 0.0
        : (((star.x - ax) * arenaStretch * dx + (star.y - ay) * dy) / length)
              .clamp(0.0, 1.0);
    if (math.pow((ax - star.x) * arenaStretch + t * dx, 2) +
            math.pow(ay + t * dy - star.y, 2) >
        12 * 12)
      return;
    star.collected = true;
    lastStarAge = 0;
    event = GameEvent.star;
  }

  bool _updateSpiders(double dt, double oldX, double oldY) {
    for (final spider in spiders) {
      final hit = spider.step(dt, oldX, oldY, ballX, ballY);
      if (_spawnOverlappingSpiders.contains(spider)) {
        if (!hit) _spawnOverlappingSpiders.remove(spider);
        continue;
      }
      if (!hit) continue;
      lives = 0;
      misses++;
      streak = 0;
      lastSuccess = false;
      caughtBySpider = true;
      message = 'Caught by a spider. Stay outside its territory.';
      event = GameEvent.miss;
      phase = GamePhase.over;
      velocity = 0;
      clearInput();
      return true;
    }
    return false;
  }

  void _updateFinale(
    double dt,
    double oldX,
    double oldY, {
    bool canDamage = true,
  }) {
    final definition = ClassicLevels.definition(level);
    if (definition.hazards.isEmpty) return;
    for (final h in specialHazards) {
      h.step(dt, 0);
      if (!canDamage) continue;
      final hit = h.hits(oldX, oldY, ballX, ballY, boardTop: visibleTop);
      if (_spawnOverlappingHazards.contains(h)) {
        if (!hit || !h.active) _spawnOverlappingHazards.remove(h);
        continue;
      }
      if (hit) {
        captureX = ballX;
        captureY = ballY;
        lives--;
        misses++;
        streak = 0;
        lastSuccess = false;
        message = h.kind == HazardKind.laser
            ? 'Laser hit. Cross while the lane is dark.'
            : 'The wandering hole caught you.';
        event = GameEvent.miss;
        phase = GamePhase.sinking;
        phaseTime = 0;
        velocity = 0;
        clearInput();
        return;
      }
    }
    specialHazards.removeWhere((h) => h.expired);
    _spawnOverlappingHazards.removeWhere((h) => h.expired);
    final waves = definition.hazards
        .where((wave) => wave.kind != HazardKind.movingHole)
        .toList();
    if (waves.isEmpty ||
        specialHazards.any((h) => h.kind != HazardKind.movingHole) ||
        _classicSceneTime < _nextFinaleAt)
      return;
    final wave = waves[_finaleSequence % waves.length];
    final positions = wave.positions.where((p) => p.target == target).toList();
    if (positions.isEmpty) {
      _finaleSequence++;
      _nextFinaleAt = _classicSceneTime + definition.hazardInterval;
      return;
    }
    final position = positions[_finaleSequence % positions.length];
    specialHazards.add(
      SpecialHazard(
        wave.kind,
        x: position.x,
        y: position.y,
        warningSeconds: wave.warningSeconds,
        liveSeconds: wave.liveSeconds,
        motion: wave.motion,
        orientation: wave.orientation,
        radiusX: wave.radiusX,
        radiusY: wave.radiusY,
        period: wave.period,
        phase: wave.phase,
        dashLength: wave.dashLength,
        dashGap: wave.dashGap,
        dashSpeed: wave.dashSpeed,
      ),
    );
    _finaleSequence++;
    _nextFinaleAt = _classicSceneTime + definition.hazardInterval;
  }

  void _capture(Hole hole) {
    if (infinite) {
      _loseClimb('Into a trap. One more climb?', hole: hole);
      return;
    }
    captureX = hole.x;
    captureY = hole.y;
    _sinkingHole = hole.motion == null ? null : board.indexOf(hole);
    lastSuccess = hole.target == target;
    if (lastSuccess) {
      streak++;
      bestStreak = math.max(bestStreak, streak);
      completed++;
      final timeBonus = (math.max(0, 35 - legTime) * 10).round();
      lastAward = mode == GameMode.classic
          ? 0
          : (target * 100 + timeBonus) * multiplier;
      score += lastAward;
      target++;
      won = target > 10;
      message = won
          ? 'All ten. Beautifully done.'
          : mode == GameMode.classic
          ? '$completed/10 targets complete'
          : '+$lastAward  /  ${streak > 1 ? '$streak in a row' : 'Beautifully balanced'}';
      event = won ? GameEvent.complete : GameEvent.target;
    } else {
      misses++;
      streak = 0;
      if (!practice) lives--;
      message = practice
          ? 'Keep going. Every attempt teaches you.'
          : lives == 0
          ? 'One more run?'
          : 'Breathe. You have another shot.';
      event = GameEvent.miss;
    }
    clearInput();
    velocity = leftSpeed = rightSpeed = 0;
    phase = GamePhase.sinking;
    phaseTime = 0;
  }
}
