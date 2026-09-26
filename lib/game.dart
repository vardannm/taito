import 'dart:math' as math;
import 'hazards.dart';
import 'maze_gates.dart';
import 'levels.dart';
import 'spiders.dart';
import 'spider_web.dart';
import 'porcupines.dart';
import 'snakes.dart';
import 'rewards.dart';
import 'merge.dart';
import 'laser_maze.dart';
import 'infinite_progress.dart';
import 'ball_cosmetics.dart';
import 'platforms.dart';
part 'infinite_gameplay.dart';

class Hole {
  const Hole(this.x, this.y, {this.target = 0});
  final double x, y;
  final int target;
}

enum GamePhase { playing, sinking, returning, over }

enum GameEvent { target, miss, complete, coin, merge }

enum GameMode { classic, infinite, practice, daily, merge2048, laserMaze }

enum ControlMode { twoFinger, oneFinger, analog }

extension ControlModeLabel on ControlMode {
  String get label => switch (this) {
    ControlMode.twoFinger => 'Two-finger',
    ControlMode.oneFinger => 'One-finger',
    ControlMode.analog => 'Vertical analog',
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
  int infiniteStartingPace = 1;
  BallCosmetic cosmetic = BallCosmetic.steel;
  PlatformStyle platformStyle = PlatformStyle.classic;
  double analogSensitivity = 1, twoFingerSensitivity = 1;
  double get equipmentMultiplier =>
      1 + cosmetic.scoreBonus + platformStyle.scoreBonus;
  ControlMode controlMode = ControlMode.twoFinger;
  ControlMode preferredControlMode = ControlMode.twoFinger;
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
  int level = 1, runSerial = 0;
  CabinetStyle cabinet = CabinetStyle.brass;
  DateTime? dailyDate;
  bool get maze => mode == GameMode.laserMaze;

  /// Modes whose camera follows the climb instead of holding the whole board.
  bool get scrolling => infinite || (maze && mazeRun.route!.tall);
  // Infinite allows manual upward travel of 15% of the board from its start.
  double get minPivot => infinite
      ? infiniteStart - height * .25 - cameraOffset
      : scrolling
      ? 40 - cameraOffset
      : 30.0;
  double get maxPivot => scrolling ? 526 - cameraOffset : 526.0;
  LaserMazeRun? _mazeRun;
  LaserMazeRun get mazeRun => _mazeRun ??= LaserMazeRun(1);
  set mazeRun(LaserMazeRun value) => _mazeRun = value;
  bool get merging => mode == GameMode.merge2048;
  MergeRun? _mergeRun;
  MergeRun get mergeRun => _mergeRun ??= MergeRun();
  set mergeRun(MergeRun value) => _mergeRun = value;
  bool get hasMazeResources => _mazeRun != null;
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
  int coinsCollected = 0;
  double lastCoinAge = 99, lastCoinX = 0, lastCoinY = 0;
  double targetTime = 180, _nextFinaleAt = 3;
  int _finaleSequence = 0;
  int get earnedStarMask =>
      !finished || !won || practice || infinite || merging || maze
      ? 0
      : 1 | (misses == 0 ? 2 : 0) | (elapsed <= targetTime ? 4 : 0);
  InfiniteSection get section => sectionAt(maxHeight / 10);

  final spiders = <BoardSpider>[];
  bool caughtBySpider = false;
  bool get spiderLevel =>
      mode == GameMode.classic &&
      ClassicLevels.definition(level).spiders.isNotEmpty;
  List<Hole> _classicBoard = [];
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
    _liftInput = 0;
  }

  /// Levels and mazes read the one-finger pad as a stick, so a held deflection
  /// keeps climbing. Infinite and 2048 keep their one-to-one finger drag.
  bool get stickLift => oneFinger && !infinite && !merging;

  /// Held deflection of that stick, -1 (full up) to 1 (full down).
  double _liftInput = 0;

  /// Board units a second at full deflection: a whole rail in about 3.5s.
  static const liftMotor = 140.0;
  void setLiftInput(double value) {
    if (!canControl || !oneFinger || !value.isFinite) return;
    _liftInput = value.clamp(-1.0, 1.0);
  }

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

  /// Road the automatic climb needs overhead before it lifts again. Larger
  /// than the fatal contact distance, so the gate stops short of a beam.
  static const mazeClearance = ballRadius + 9;
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

  double _nextSnakeTime = 0;
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
  static const firstRow = 300.0;

  static double difficultyAt(double progress) {
    return InfiniteTuning.difficultyAt(progress);
  }

  double get difficulty => difficultyAt(maxHeight / 10);
  double get ascentSpeed =>
      InfiniteTuning.startSpeed +
      (InfiniteTuning.baseTopSpeed - InfiniteTuning.startSpeed) *
          difficulty *
          InfiniteDifficulty.speedGrowth +
      (infinite
          ? InfiniteTuning.paceSpeedBonus *
                (pace - 1) *
                InfiniteDifficulty.paceGrowth
          : 0);
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
        snakes.isNotEmpty ||
        quills.isNotEmpty ||
        porcupines.any((p) => p.charge != null) ||
        mazeSection ||
        elapsed < _nextHazardTime ||
        metres * InfiniteDifficulty.hazardUnlocks <
            InfiniteTuning.hazardMilestones.first ||
        section == InfiniteSection.breath)
      return;
    final unlocked = InfiniteTuning.hazardMilestones
        .where((m) => metres * InfiniteDifficulty.hazardUnlocks >= m)
        .length;
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
        _introducedHazards >= 4;
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
  List<Hole> get board => merging || maze
      ? const []
      : infinite
      ? _endlessHoles
      : _classicBoard;
  int get roundCompleted => completed;
  double screenY(double worldY) => worldY + (scrolling ? cameraOffset : 0);
  bool get dangerActive => infinite && !tutorialCourse && stallTime >= 3;
  double get dangerDistance => dangerY - ballY;

  void ensureInfiniteBoard({bool retainForSweep = false}) {
    if (!infinite || tutorialCourse) return;
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
    dangerY = math.min(dangerY, 580 - cameraOffset);
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
  }

  void _loseClimb(String reason, {Hole? hole}) {
    if (survival.protected) return;
    survival.breakCombo();
    captureX = hole?.x ?? ballX;
    captureY = hole?.y ?? ballY;
    lives--;
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
  }

  double left = 526, right = 526, ballX = 180, velocity = 0;
  final ballTrail = <({double x, double y, double time})>[];
  double motionSpeed = 0;
  double leftSpeed = 0, rightSpeed = 0;
  double leftInput = 0, rightInput = 0;
  double clock = 0, legTime = 0, elapsed = 0, phaseTime = 0;
  double captureX = 180, captureY = 519, returnLeft = 526, returnRight = 526;
  int target = 1, lives = 3, score = 0, streak = 0, bestStreak = 0;
  int lastAward = 0, completed = 0, misses = 0, inputEpoch = 0;
  bool started = false, paused = false, won = false;
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

  /// Activate the prepared board without resetting input or rebuilding a run.
  /// The caller continues handling this same key/pointer event as movement.
  void beginInput() {
    if (!canControl || !waitingForInput) return;
    if (_previewRandom != null) {
      _previewRandom = null;
      // Replace only the course. Keep pointer ownership, platform and input
      // epoch intact so this very same event also controls the new run.
      if (infinite) {
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

  Hole get activeHole =>
      board.firstWhere((h) => h.target == target.clamp(1, 10));
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
    delta *= (analog ? analogSensitivity : twoFingerSensitivity).clamp(
      0.0,
      1.0,
    );
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
    controlHeld = false;
    _controlLift = 0;
    _liftInput = 0;
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
    if (!infinite) {
      specialHazards.clear();
      _nextFinaleAt = mode == GameMode.classic
          ? ClassicLevels.definition(level).firstHazardAfter
          : 3;
      _finaleSequence = 0;
    }
    for (final spider in spiders) {
      spider.reset();
    }
    left = right = maze
        ? 526
        : infinite
        ? infiniteStart
        : oneFinger
        ? 500
        : 526;
    ballX = 180;
    velocity = leftSpeed = rightSpeed = 0;
    legTime = 0;
    controlPosition = 0;
    clearInput();
  }

  void start({
    GameMode gameMode = GameMode.classic,
    int levelNumber = 1,
    DateTime? challengeDate,
    bool waitForInput = false,
  }) {
    runSerial++;
    tutorialCourse = false;
    mode = gameMode;
    // Every generated mode holds the baked carousel layout while it waits, so
    // swiping back shows the same starting position instead of a new draw.
    _previewRandom = waitForInput && (infinite || merging)
        ? math.Random(711)
        : null;
    // A mode switch releases the previous mode's generated world. These
    // objects own no tickers; the screen drives only this active simulation.
    if (!maze) _mazeRun = null;
    if (!merging) _mergeRun = null;
    survival = InfiniteProgress(
      startingPace: infiniteStartingPace,
      scoreBoost: equipmentMultiplier,
    );
    controlMode = preferredControlMode;
    if (merging) mergeRun = MergeRun(seed: _random.nextInt(1 << 30));
    dailyDate = daily
        ? DailyChallenge.day(challengeDate ?? DateTime.now())
        : null;
    level = daily
        ? 15
        : levelNumber.clamp(
            1,
            maze ? LaserMazeRoute.count : ClassicLevels.count,
          );
    if (mode == GameMode.laserMaze) mazeRun = LaserMazeRun(level);
    _classicBoard = infinite || merging || maze
        ? []
        : practice
        ? List<Hole>.of(holes)
        : ClassicLevels.build(
            level,
            dailySeed: daily ? DailyChallenge.seed(dailyDate!) : null,
          );
    spiders.clear();
    webShots.clear();
    _nextWebTime = 0;
    porcupines.clear();
    quills.clear();
    snakes.clear();
    _nextSnakeTime = 0;
    _nextPorcupineY = -2700;
    _nextQuillTime = 0;
    if (spiderLevel)
      spiders.addAll(
        ClassicLevels.definition(level).spiders.map((s) => s.create()),
      );
    caughtBySpider = false;
    coins.clear();
    if (!infinite && !practice && !merging && !maze)
      coins.addAll(ClassicLevels.coinsFor(_classicBoard, spiders));
    coinsCollected = 0;
    lastCoinAge = 99;
    // Active-time targets: fixed lift time plus steering allowance and trap detours.
    final launch = oneFinger ? 500.0 : 526.0;
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
    lives = merging || maze ? 1 : InfiniteTuning.maxLives;
    score = streak = bestStreak = completed = misses = 0;
    elapsed = phaseTime = 0;
    won = paused = false;
    started = true;
    waitingForInput = waitForInput;
    inputLocked = false;
    phase = GamePhase.playing;
    event = null;
    message = maze
        ? 'Stay between the red lasers. Reach the checkered finish.'
        : merging
        ? mergeRun.notice
        : infinite
        ? 'Tilt to dodge. The board keeps moving.'
        : 'Raise both ends. Find the glowing 01.';
    resetBall();
  }

  void home() {
    start();
    started = false;
  }

  void step(double dt) {
    if (!dt.isFinite || dt <= 0 || waitingForInput) return;
    // Bound individual substeps even if a caller accidentally supplies a long frame.
    var remaining = math.min(dt, .1);
    while (remaining > .000001) {
      final h = math.min(remaining, 1 / 120);
      final oldX = ballX, oldY = ballY;
      _tick(h);
      if (!paused) {
        if (started && phase == GamePhase.playing) {
          final distance = math.sqrt(
            math.pow(ballX - oldX, 2) + math.pow(ballY - oldY, 2),
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

  void _tick(double dt) {
    if (paused) return;
    clock += dt;
    if (!started || finished) return;
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
      final launch = oneFinger ? 500.0 : 526.0;
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
    legTime += dt;
    final oldX = ballX, oldY = ballY;
    final oldLeft = left, oldRight = right;
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
    if (oneFinger) {
      // A held handle supplies both axes. Only mazes auto-lift on release.
      final halfTilt = controlPosition * 70;
      // The automatic climb only rises while there is road overhead, so a
      // sideways leg holds its height until the ball reaches the next column.
      final climbing =
          !maze ||
          mazeRun.corridor.canClimb(ballX, ballY, mazeClearance) ||
          ballY <= mazeRun.route!.finishLineY + mazeClearance;
      final lift = climbing ? 14 * dt : 0.0;
      // Two lift models. Infinite reads the finger one-to-one. Levels and
      // mazes read the pad as a stick, so a held deflection keeps climbing
      // until the platform reaches the rail. Both keep the headroom the tilt
      // needs, so the bar never hangs off the board.
      final push = stickLift ? _liftInput * liftMotor * dt : 0.0;
      final center =
          (controlHeld || _controlLift != 0
                  ? (left + right) / 2 + _controlLift + push
                  : maze
                  ? math.max(
                      mazeRun.route!.finishLineY + ballRadius,
                      (left + right) / 2 - lift,
                    )
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
    final slope = (right - left) / 320;
    velocity += (6 / 7) * 1300 * slope / (1 + slope * slope) * dt;
    velocity *= math.exp(-.48 * dt);
    velocity = velocity.clamp(-265.0, 265.0);
    ballX += velocity * dt;
    final minimumX = merging ? mergeRun.minHeadX : 28.0;
    final maximumX = merging ? mergeRun.maxHeadX : 332.0;
    if (ballX < minimumX) {
      ballX = minimumX;
      velocity = velocity.abs() * .22;
    }
    if (ballX > maximumX) {
      ballX = maximumX;
      velocity = -velocity.abs() * .22;
    }
    if (infinite) {
      _updateClimb(dt);
      if (phase != GamePhase.playing) return;
    }
    if (maze) {
      mazeRun.step(oldX, oldY, ballX, ballY, ballRadius);
      if (mazeRun.ended) {
        won = mazeRun.won;
        phase = GamePhase.over;
        if (!won) {
          lives = 0;
          misses++;
        }
        // Stop the whole platform at the contact, not at the end of a fast drag.
        final t = mazeRun.contactFraction;
        left = oldLeft + (left - oldLeft) * t;
        right = oldRight + (right - oldRight) * t;
        ballX = mazeRun.contactX;
        final alignment = mazeRun.contactY - ballY;
        left += alignment;
        right += alignment;
        captureX = mazeRun.contactX;
        captureY = mazeRun.contactY;
        message = won
            ? 'Finish reached. Beautifully balanced.'
            : 'You touched a red laser.';
        event = won ? GameEvent.complete : GameEvent.miss;
        velocity = 0;
        clearInput();
      }
      // Height and camera follow the corrected position, so a swipe that ends
      // on a beam cannot bank the height beyond it.
      if (scrolling) {
        if (screenY(ballY) < 360) cameraOffset = math.max(0, 360 - ballY);
        if (screenY(ballY) > 440) cameraOffset = math.max(0, 440 - ballY);
        cameraOffset = math.min(
          cameraOffset,
          LaserMazeCorridor.finishY - mazeRun.route!.finishLineY,
        );
      }
      score = (mazeRun.progress * 100).floor();
      return;
    }
    if (merging) {
      final collectedBefore = mergeRun.collected;
      mergeRun.step(dt, oldX, oldY, ballX, ballY);
      // Make room for new segments without treating the attachment as a sweep.
      ballX = ballX.clamp(mergeRun.minHeadX, mergeRun.maxHeadX);
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
      snakes.removeWhere(
        (s) =>
            s.expired ||
            s.points.every((p) => screenY(p.y) > 640 || p.x < -24 || p.x > 384),
      );
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
      final dx = ballX - oldX, dy = ballY - oldY;
      final length2 = dx * dx + dy * dy;
      final t = length2 == 0
          ? 0.0
          : (((hole.x - oldX) * dx + (hole.y - oldY) * dy) / length2).clamp(
              0.0,
              1.0,
            );
      final hx = oldX + dx * t - hole.x, hy = oldY + dy * t - hole.y;
      final radius = practice && hole.target == target ? 10.5 : 8.5;
      if (hx * hx + hy * hy <= radius * radius) {
        final ox = oldX - hole.x, oy = oldY - hole.y;
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
    if (finale && hit == null) {
      _updateFinale(dt, oldX, oldY);
      if (phase != GamePhase.playing) return;
    }
    final fraction = firstContact.isFinite ? firstContact : 1.0;
    _collectCoins(
      oldX,
      oldY,
      oldX + (ballX - oldX) * fraction,
      oldY + (ballY - oldY) * fraction,
    );
    if (hit != null) _capture(hit);
  }

  void _collectCoins(double ax, double ay, double bx, double by) {
    final dx = bx - ax, dy = by - ay, length = dx * dx + dy * dy;
    for (final coin in coins.where((c) => !c.collected)) {
      final t = length == 0
          ? 0.0
          : (((coin.x - ax) * dx + (coin.y - ay) * dy) / length).clamp(
              0.0,
              1.0,
            );
      if (math.pow(ax + t * dx - coin.x, 2) +
              math.pow(ay + t * dy - coin.y, 2) <=
          12 * 12) {
        _takeCoin(coin);
      }
    }
  }

  void _takeCoin(BrassCoin coin) {
    if (coin.collected) return;
    coin.collected = true;
    coinsCollected++;
    if (!scrolling) score += 250;
    lastCoinAge = 0;
    lastCoinX = coin.x;
    lastCoinY = coin.y;
    event = GameEvent.coin;
  }

  bool _updateSpiders(double dt, double oldX, double oldY) {
    for (final spider in spiders) {
      if (!spider.step(dt, oldX, oldY, ballX, ballY)) continue;
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

  void _updateFinale(double dt, double oldX, double oldY) {
    final definition = ClassicLevels.definition(level);
    if (definition.hazards.isEmpty) return;
    for (final h in specialHazards) {
      h.step(dt, 0);
      if (h.hits(oldX, oldY, ballX, ballY, boardTop: visibleTop)) {
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
    if (specialHazards.isNotEmpty || legTime < _nextFinaleAt) return;
    final wave =
        definition.hazards[_finaleSequence % definition.hazards.length];
    final positions = wave.positions.where((p) => p.target == target).toList();
    if (positions.isEmpty) {
      _finaleSequence++;
      _nextFinaleAt = legTime + definition.hazardInterval;
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
      ),
    );
    _finaleSequence++;
    _nextFinaleAt = legTime + definition.hazardInterval;
  }

  void _capture(Hole hole) {
    if (infinite) {
      _loseClimb('Into a trap. One more climb?', hole: hole);
      return;
    }
    captureX = hole.x;
    captureY = hole.y;
    lastSuccess = hole.target == target;
    if (lastSuccess) {
      streak++;
      bestStreak = math.max(bestStreak, streak);
      completed++;
      final timeBonus = (math.max(0, 35 - legTime) * 10).round();
      lastAward = (target * 100 + timeBonus) * multiplier;
      score += lastAward;
      target++;
      won = target > 10;
      message = won
          ? 'All ten. Beautifully done.'
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
