import 'dart:math' as math;
import 'hazards.dart';
import 'levels.dart';

class Hole {
  const Hole(this.x, this.y, {this.target = 0});
  final double x, y;
  final int target;
}

enum GamePhase { playing, sinking, returning, over }

enum GameEvent { target, miss, complete }

enum GameMode { classic, infinite, practice }

enum ControlMode { twoFinger, oneFinger }

/// Fixed-step simulation. No Flutter imports: physics can be tested in isolation.
class BalanceGame {
  BalanceGame({int? seed}) : _random = math.Random(seed);
  final math.Random _random;
  ControlMode controlMode = ControlMode.twoFinger;
  bool get oneFinger => controlMode == ControlMode.oneFinger;
  int level = 1;
  List<Hole> _classicBoard = ClassicLevels.build(1);
  double controlPosition = 0;
  double get controlY => (screenY((left + right) / 2) + 38).clamp(65.0, 532.0);
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
    controlMode = value;
    controlPosition = ((right - left) / 140).clamp(-1.0, 1.0);
  }

  static const width = 360.0, height = 560.0, ballRadius = 7.0;
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
  double cameraOffset = 0, maxHeight = 0, stallTime = 0, dangerY = 580;
  double _steeringDistance = 0;
  static const infiniteStart = 440.0;
  static const firstRow = 300.0;

  static double difficultyAt(double progress) {
    final t = (progress / 900).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  double get difficulty => difficultyAt(maxHeight / 10);
  double get ascentSpeed => 60 + 120 * difficulty;
  final specialHazards = <SpecialHazard>[];
  double _nextHazardTime = 0;
  int _introducedHazards = 0, _hazardSequence = 0;
  bool fellThroughGap = false;
  String get hazardLabel =>
      specialHazards.isEmpty ? '' : specialHazards.first.label;

  void _updateSpecialHazards(double dt, double oldX, double oldScreenY) {
    for (final hazard in specialHazards) {
      hazard.step(dt, ascentSpeed);
      if (hazard.hits(oldX, oldScreenY, ballX, screenY(ballY))) {
        fellThroughGap = hazard.kind == HazardKind.platformGap;
        _loseClimb(switch (hazard.kind) {
          HazardKind.laser => 'Laser hit. Move out of the blinking beam.',
          HazardKind.platformGap => 'The platform broke beneath you.',
          HazardKind.formingHole => 'The warning hole opened beneath you.',
          HazardKind.movingHole => 'Caught by a moving hole.',
        });
        return;
      }
    }
    specialHazards.removeWhere((h) => h.expired || h.y > 600);
    if (specialHazards.isNotEmpty || elapsed < _nextHazardTime || score < 180)
      return;
    final unlocked = score >= 900
        ? 4
        : score >= 600
        ? 3
        : score >= 350
        ? 2
        : 1;
    final index = _introducedHazards < unlocked
        ? _introducedHazards++
        : (_hazardSequence + 1 + _random.nextInt(math.max(1, unlocked - 1))) %
              unlocked;
    _hazardSequence = index;
    final kind = HazardKind.values[index];
    final lane = 95.0 + _random.nextDouble() * 170;
    specialHazards.add(
      SpecialHazard(
        kind,
        x: lane,
        y: (screenY(ballY) - 150).clamp(75.0, 300.0),
        warningSeconds: kind == HazardKind.platformGap ? 2.4 : 2.0,
        liveSeconds: kind == HazardKind.laser
            ? 1.4
            : kind == HazardKind.platformGap
            ? 2.5
            : 450 / ascentSpeed,
      ),
    );
    // One special hazard at a time, with recovery time before the next warning.
    _nextHazardTime = elapsed + 12 - 5.5 * difficulty;
  }

  bool get infinite => mode == GameMode.infinite;
  bool get practice => mode == GameMode.practice;
  List<Hole> get board => infinite ? _endlessHoles : _classicBoard;
  int get roundCompleted => completed;
  double screenY(double worldY) => worldY + (infinite ? cameraOffset : 0);
  bool get dangerActive => infinite && stallTime >= 3;
  double get dangerDistance => dangerY - ballY;

  void ensureInfiniteBoard() {
    if (!infinite) return;
    while (_nextRowY >= -cameraOffset - 120) {
      final d = difficultyAt(math.max(0, (infiniteStart - _nextRowY) / 10));
      final spacing = 120 - 45 * d + _random.nextDouble() * 20;
      final previous = _corridor;
      final turn = math.min(52.0, spacing * .42);
      _corridor = (_corridor + (_random.nextDouble() * 2 - 1) * turn).clamp(
        70.0,
        290.0,
      );
      final selected = <Hole>[];
      final recent = _endlessHoles.reversed.take(3).toList().reversed.toList();
      final density = 2 + 2 * d;
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
        if ((x - safeX).abs() > 46 - 12 * d &&
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
    _endlessHoles.removeWhere((hole) => screenY(hole.y) > 620);
  }

  void _updateClimb(double dt) {
    maxHeight = math.max(maxHeight, infiniteStart - ballRadius - ballY);
    score = (maxHeight / 10).floor();
    if (leftInput != 0 || rightInput != 0) {
      stallTime = 0;
    } else {
      stallTime += dt;
    }
    // A manual climb may also move the camera; automatic ascent runs every tick.
    cameraOffset = math.max(cameraOffset, 240 - ballY);
    dangerY = math.min(dangerY, 580 - cameraOffset);
    if (dangerActive) dangerY -= (24 + math.min(stallTime - 3, 5) * 16) * dt;
    message = dangerActive
        ? 'KEEP STEERING! The red is rising.'
        : 'Tilt to dodge. The board keeps moving.';
    ensureInfiniteBoard();
    if (ballY + ballRadius >= dangerY) {
      _loseClimb('The red caught you. Keep moving next time.');
    }
  }

  void _loseClimb(String reason, {Hole? hole}) {
    captureX = hole?.x ?? ballX;
    captureY = hole?.y ?? ballY;
    lives = 0;
    misses++;
    lastSuccess = false;
    message = reason;
    event = GameEvent.miss;
    clearInput();
    velocity = leftSpeed = rightSpeed = 0;
    phase = GamePhase.sinking;
    phaseTime = 0;
  }

  double left = 526, right = 526, ballX = 180, velocity = 0;
  double leftSpeed = 0, rightSpeed = 0;
  double leftInput = 0, rightInput = 0;
  double clock = 0, legTime = 0, elapsed = 0, phaseTime = 0;
  double captureX = 180, captureY = 519, returnLeft = 526, returnRight = 526;
  int target = 1, lives = 3, score = 0, streak = 0, bestStreak = 0;
  int lastAward = 0, completed = 0, misses = 0, inputEpoch = 0;
  bool started = false, paused = false, won = false;
  bool lastSuccess = false;
  GamePhase phase = GamePhase.playing;
  GameEvent? event;
  String message = 'Ten holes. Two thumbs. Steady nerves.';
  bool get finished => phase == GamePhase.over;
  bool get canControl => started && !paused && phase == GamePhase.playing;
  Hole get activeHole =>
      board.firstWhere((h) => h.target == target.clamp(1, 10));
  double get ballY => left + (right - left) * ((ballX - 20) / 320) - ballRadius;
  double get visualX => phase == GamePhase.sinking ? captureX : ballX;
  double get visualY => phase == GamePhase.sinking
      ? captureY + (fellThroughGap ? 100 * phaseTime * phaseTime : 0)
      : ballY;
  double get ballScale => phase == GamePhase.sinking
      ? (1 - phaseTime / .38).clamp(0.0, 1.0)
      : phase == GamePhase.returning
      ? 0
      : 1;
  int get multiplier => (1 + streak ~/ 3).clamp(1, 4);

  final pivotTargets = <double?>[null, null];
  final _released = [false, false];

  void grabPivot(int side) {
    if (!canControl) return;
    _released[side] = false;
    pivotTargets[side] = side == 0 ? left : right;
  }

  void dragPivot(int side, double delta) {
    if (!canControl || !delta.isFinite || pivotTargets[side] == null) return;
    final other = side == 0 ? right : left;
    final minimum = infinite ? math.max(other - 180, 40 - cameraOffset) : 30.0;
    final maximum = infinite
        ? math.min(526 - cameraOffset, other + 180)
        : 526.0;
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
    leftSpeed = rightSpeed = 0;
    pivotTargets.fillRange(0, 2, null);
    _released.fillRange(0, 2, false);
    leftInput = rightInput = 0;
    inputEpoch++;
  }

  void setPaused(bool value) {
    paused = value;
    clearInput();
  }

  void resetBall() {
    left = right = infinite
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

  void start({GameMode gameMode = GameMode.classic, int levelNumber = 1}) {
    mode = gameMode;
    level = levelNumber.clamp(1, 30);
    _classicBoard = practice
        ? List<Hole>.of(holes)
        : ClassicLevels.build(level);
    cameraOffset = maxHeight = stallTime = _steeringDistance = 0;
    dangerY = 580;
    _nextRowY = 300 + _random.nextDouble() * 20;
    _corridor = 150 + _random.nextDouble() * 60;
    specialHazards.clear();
    _nextHazardTime = 0;
    _introducedHazards = _hazardSequence = 0;
    fellThroughGap = false;
    _endlessHoles.clear();
    if (infinite) ensureInfiniteBoard();
    target = 1;
    lives = infinite ? 1 : 3;
    score = streak = bestStreak = completed = misses = 0;
    elapsed = phaseTime = 0;
    won = paused = false;
    started = true;
    phase = GamePhase.playing;
    event = null;
    message = infinite
        ? 'Tilt to dodge. The board keeps moving.'
        : 'Raise both ends. Find the glowing 01.';
    resetBall();
  }

  void home() {
    start();
    started = false;
  }

  void step(double dt) {
    if (!dt.isFinite || dt <= 0) return;
    // Bound individual substeps even if a caller accidentally supplies a long frame.
    var remaining = math.min(dt, .1);
    while (remaining > .000001) {
      final h = math.min(remaining, 1 / 120);
      _tick(h);
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
    legTime += dt;
    final oldX = ballX, oldY = ballY;
    final oldScreenY = screenY(ballY);
    if (infinite) {
      // Translate the platform and camera equally: grips stay under the fingers
      // while stationary world hazards approach from above. Keep the old world
      // ball position for swept collision against those approaching hazards.
      final travel = ascentSpeed * dt;
      cameraOffset += travel;
      left -= travel;
      right -= travel;
      dangerY -= travel;
      for (var side = 0; side < 2; side++) {
        if (pivotTargets[side] != null)
          pivotTargets[side] = pivotTargets[side]! - travel;
      }
    }
    // Motor easing removes abrupt starts; near-immediate braking keeps it precise.
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
    final minimum = infinite ? 40 - cameraOffset : 30.0;
    final maximum = infinite ? 526 - cameraOffset : 526.0;
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
      // Horizontal control changes tilt; Classic supplies the missing lift axis.
      final halfTilt = controlPosition * 70;
      final center =
          (infinite
                  ? (left + right) / 2
                  : math.max(
                      activeHole.y + ballRadius,
                      (left + right) / 2 - 20 * dt,
                    ))
              .clamp(minimum + halfTilt.abs(), maximum - halfTilt.abs());
      left = center - halfTilt;
      right = center + halfTilt;
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
    velocity += (5 / 7) * 710 * slope / (1 + slope * slope) * dt;
    velocity *= math.exp(-.48 * dt);
    velocity = velocity.clamp(-265.0, 265.0);
    ballX += velocity * dt;
    if (ballX < 28) {
      ballX = 28;
      velocity = velocity.abs() * .22;
    }
    if (ballX > 332) {
      ballX = 332;
      velocity = -velocity.abs() * .22;
    }
    if (infinite) {
      _updateClimb(dt);
      if (phase != GamePhase.playing) return;
    }
    Hole? hit;
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
    if (hit != null) _capture(hit);
    if (infinite && phase == GamePhase.playing) {
      _updateSpecialHazards(dt, oldX, oldScreenY);
    }
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
