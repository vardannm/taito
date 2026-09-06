import 'dart:math' as math;

class Hole {
  const Hole(this.x, this.y, {this.target = 0});
  final double x, y;
  final int target;
}

enum GamePhase { playing, sinking, returning, over }

enum GameEvent { target, miss, complete }

enum GameMode { classic, infinite, practice }

/// Fixed-step simulation. No Flutter imports: physics can be tested in isolation.
class BalanceGame {
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
  int _nextRow = 0;
  double cameraOffset = 0, maxHeight = 0, stallTime = 0, dangerY = 580;
  double _progressAnchor = 0;
  bool get infinite => mode == GameMode.infinite;
  bool get practice => mode == GameMode.practice;
  List<Hole> get board => infinite ? _endlessHoles : holes;
  int get roundCompleted => completed;
  double screenY(double worldY) => worldY + (infinite ? cameraOffset : 0);
  bool get dangerActive => infinite && stallTime >= 3;
  double get dangerDistance => dangerY - ballY;

  void _extendBoard() {
    while (420 - _nextRow * 72 >= -cameraOffset - 120) {
      final row = _nextRow++;
      final corridor = 180 + 78 * math.sin(row * .65);
      final random = math.Random(731 + row * 7919);
      final selected = <double>[];
      // Seal alternating edges and vary x positions so no straight safe lane repeats forever.
      if (row % 4 == 0) selected.add(28);
      if (row % 4 == 1) selected.add(332);
      for (int attempt = 0; attempt < 60 && selected.length < 3; attempt++) {
        final x = 28 + random.nextDouble() * 304;
        if ((x - corridor).abs() > 54 &&
            selected.every((other) => (other - x).abs() > 27))
          selected.add(x);
      }
      for (final x in selected) {
        _endlessHoles.add(Hole(x, 420 - row * 72.0));
      }
    }
    _endlessHoles.removeWhere((hole) => screenY(hole.y) > 620);
  }

  void _updateClimb(double dt) {
    maxHeight = math.max(maxHeight, 519 - ballY);
    score = (maxHeight / 10).floor();
    if (maxHeight >= _progressAnchor + 4) {
      _progressAnchor = maxHeight;
      stallTime = 0;
    } else {
      stallTime += dt;
    }
    cameraOffset = math.max(cameraOffset, 320 - ballY);
    // The floor follows below the viewport but only enters it when progress stalls.
    dangerY = math.min(dangerY, 580 - cameraOffset);
    if (dangerActive) dangerY -= (24 + math.min(stallTime - 3, 5) * 16) * dt;
    message = dangerActive
        ? 'KEEP CLIMBING! The red is rising.'
        : 'Climb higher. Every hole is a trap.';
    _extendBoard();
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
  double get visualY => phase == GamePhase.sinking ? captureY : ballY;
  double get ballScale => phase == GamePhase.sinking
      ? (1 - phaseTime / .38).clamp(0.0, 1.0)
      : phase == GamePhase.returning
      ? 0
      : 1;
  int get multiplier => (1 + streak ~/ 3).clamp(1, 4);

  final pivotTargets = <double?>[null, null];

  void grabPivot(int side) {
    if (!canControl) return;
    pivotTargets[side] = side == 0 ? left : right;
  }

  void dragPivot(int side, double delta) {
    if (!canControl || !delta.isFinite || pivotTargets[side] == null) return;
    final other = side == 0 ? right : left;
    final minimum = infinite ? other - 180 : 30.0;
    final maximum = infinite ? math.min(526.0, other + 180) : 526.0;
    pivotTargets[side] = (pivotTargets[side]! + delta).clamp(minimum, maximum);
  }

  void releasePivot(int side) {
    pivotTargets[side] = null;
    if (side == 0) {
      leftSpeed = 0;
    } else {
      rightSpeed = 0;
    }
  }

  void clearInput() {
    pivotTargets.fillRange(0, 2, null);
    leftInput = rightInput = 0;
    inputEpoch++;
  }

  void setPaused(bool value) {
    paused = value;
    clearInput();
  }

  void resetBall() {
    left = right = 526;
    ballX = 180;
    velocity = leftSpeed = rightSpeed = 0;
    legTime = 0;
    clearInput();
  }

  void start({GameMode gameMode = GameMode.classic}) {
    mode = gameMode;
    cameraOffset = maxHeight = stallTime = _progressAnchor = 0;
    dangerY = 580;
    _nextRow = 0;
    _endlessHoles.clear();
    if (infinite) _extendBoard();
    target = 1;
    lives = infinite ? 1 : 3;
    score = streak = bestStreak = completed = misses = 0;
    elapsed = phaseTime = 0;
    won = paused = false;
    started = true;
    phase = GamePhase.playing;
    event = null;
    message = infinite
        ? 'Climb higher. Every hole is a trap.'
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
      left = returnLeft + (526 - returnLeft) * ease;
      right = returnRight + (526 - returnRight) * ease;
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
    // Motor easing removes abrupt starts; near-immediate braking keeps it precise.
    final response = 1 - math.exp(-22 * dt);
    final motor = practice ? 78.0 : 91.0;
    leftSpeed += ((leftInput.clamp(-1, 1) * motor) - leftSpeed) * response;
    rightSpeed += ((rightInput.clamp(-1, 1) * motor) - rightSpeed) * response;
    // Follow the finger through fixed physics steps, preserving swept collisions.
    // Cap catch-up speed so a fast swipe cannot teleport through hazards.
    if (pivotTargets[0] != null) {
      leftSpeed = ((pivotTargets[0]! - left) / dt).clamp(-300.0, 300.0);
    }
    if (pivotTargets[1] != null) {
      rightSpeed = ((pivotTargets[1]! - right) / dt).clamp(-300.0, 300.0);
    }
    final minimum = infinite ? double.negativeInfinity : 30.0;
    left = (left + leftSpeed * dt).clamp(minimum, 526.0);
    right = (right + rightSpeed * dt).clamp(minimum, 526.0);
    if (infinite && (right - left).abs() > 180) {
      if (left < right) {
        left = right - 180;
      } else {
        right = left - 180;
      }
    }
    // A rolling sphere: 5/7 of gravity projected onto the bar, then onto x.
    final slope = (right - left) / 320;
    velocity += (5 / 7) * 660 * slope / (1 + slope * slope) * dt;
    velocity *= math.exp(-.48 * dt);
    velocity = velocity.clamp(-245.0, 245.0);
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
        _capture(hole);
        break;
      }
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
