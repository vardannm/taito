import 'dart:math' as math;

/// All survival balancing lives here. Pace is a level, not a literal 5x motor.
abstract final class InfiniteTuning {
  static const denseScore = 60000.0;
  static double difficultyAt(double metres) {
    final t = (metres / 2400).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  // Equipment and combo rewards cannot skip the gentle opening of a run.
  static double runDensity(num score, double metres) =>
      math.min(densityAt(score), difficultyAt(metres));
  static const hazardMilestones = [450, 900, 1500, 2250];
  static double complexityAt(double metres) =>
      ((metres - 2400) / 1800).clamp(0.0, 1.0);
  static double densityAt(num score) {
    final t = (score / denseScore).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static const startSpeed = 68.0, baseTopSpeed = 180.0, paceSpeedBonus = 9.0;
  static const coinSpacing = 85.0, coinSpacingJitter = 65.0;
  static const visualIntensity = 1.0, maxParticles = 42;
  static const maxLives = 3, maxPace = 5, maxCombo = 10;
  static const shieldSeconds = 10.0, recoverySeconds = 2.5;
  static const metresPerPace = 600.0, comboPoints = 50;
  static const firstComboY = 190.0, firstShieldY = -950.0;
  static const firstHeartY = -1650.0;
  static const comboSpacing = 280.0, shieldSpacing = 2400.0;

  /// Laser maze sections, measured in metres climbed: the first arrives here,
  /// each covers this stretch, and the next follows after this much clear air.
  /// Distance, not score, so a lucky crystal cannot cut a maze short.
  static const mazeFirstMetres = 550.0, mazeSectionMetres = 170.0;
  static const mazeRestMetres = 600.0, mazeGateSpacing = 290.0;

  /// How far a gap may move between gates, so the run is always steerable.
  static const mazeGapShift = 150.0;

  /// A section also ends on the clock, so a stalled climb cannot sit inside a
  /// maze that its own distance would never finish.
  static const mazeSectionSeconds = 38.0;
  static const heartSpacing = 3600.0, maxItems = 12;
  static int startingPace(int bestMetres) => 1;
}

enum InfiniteItemKind { combo, shield, heart }

class InfiniteItem {
  InfiniteItem(this.kind, this.x, this.y);
  final InfiniteItemKind kind;
  final double x, y;
}

class InfiniteProgress {
  InfiniteProgress({int startingPace = 1, this.scoreBoost = 1})
    : startingPace = startingPace.clamp(1, 3);
  final int startingPace;
  final double scoreBoost;
  int combo = 1, bestCombo = 1, damageSerial = 0;
  double shield = 0, recovery = 0, points = 0, scoredMetres = 0;
  double visualCombo = 0, flash = 0, noticeTime = 0;
  String notice = '';
  double nextComboY = InfiniteTuning.firstComboY;
  double nextShieldY = InfiniteTuning.firstShieldY;
  double nextHeartY = InfiniteTuning.firstHeartY;
  final items = <InfiniteItem>[];
  bool get protected => shield > 0 || recovery > 0;

  /// Two gentle blinks per second during hit protection; never drives physics.
  double get recoveryOpacity {
    if (recovery <= 0) return 1;
    final age = InfiniteTuning.recoverySeconds - recovery;
    return .35 + .65 * (1 + math.cos(age * math.pi * 4)) / 2;
  }

  double paceAt(double metres) =>
      (startingPace + metres / InfiniteTuning.metresPerPace).clamp(
        1.0,
        InfiniteTuning.maxPace.toDouble(),
      );
  int levelAt(double metres) => paceAt(metres).floor();
  void step(double dt, double metres) {
    shield = math.max(0, shield - dt);
    recovery = math.max(0, recovery - dt);
    flash = math.max(0, flash - dt);
    noticeTime = math.max(0, noticeTime - dt);
    visualCombo +=
        ((combo - 1) / (InfiniteTuning.maxCombo - 1) - visualCombo) *
        (1 - math.exp(-5 * dt));
    if (metres > scoredMetres) {
      points +=
          (metres - scoredMetres) *
          paceAt((metres + scoredMetres) / 2) *
          scoreBoost;
      scoredMetres = metres;
    }
  }

  void announce(String text) {
    notice = text;
    noticeTime = 2.5;
  }

  void breakCombo() {
    combo = 1;
    visualCombo = flash = 0;
    damageSerial++;
  }
}

/// Entry time for swept circle contact. Shared by pickups and normal holes.
double? circleContact(
  double ax,
  double ay,
  double bx,
  double by,
  double x,
  double y,
  double radius,
) {
  final ox = ax - x, oy = ay - y, dx = bx - ax, dy = by - ay;
  final c = ox * ox + oy * oy - radius * radius;
  if (c <= 0) return 0;
  final a = dx * dx + dy * dy;
  if (a < 1e-12) return null;
  final b = ox * dx + oy * dy, discriminant = b * b - a * c;
  if (discriminant < 0) return null;
  final t = (-b - math.sqrt(discriminant)) / a;
  return t >= 0 && t <= 1 ? t : null;
}
