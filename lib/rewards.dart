import 'dart:math' as math;

enum CabinetStyle { brass, jade, porcelain, ember }

extension CabinetDetails on CabinetStyle {
  String get title =>
      ['Original brass', 'Jade garden', 'Porcelain club', 'Ember forge'][index];
  int get requiredStars => [0, 3, 12, 30][index];
}

String formatRunTime(double seconds) {
  final total = seconds.ceil();
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

class LevelRecord {
  const LevelRecord({
    this.starMask = 0,
    this.bestScore = 0,
    this.bestTime,
    this.attempts = 0,
  });
  final int starMask, bestScore, attempts;
  final double? bestTime;
  int get stars => starCount(starMask);
  static int starCount(int mask) =>
      (mask & 1) + ((mask >> 1) & 1) + ((mask >> 2) & 1);
  LevelRecord withRun({
    required int mask,
    required int score,
    required double seconds,
    required bool won,
  }) => LevelRecord(
    starMask: starMask | mask,
    bestScore: math.max(bestScore, score),
    bestTime: won ? math.min(bestTime ?? seconds, seconds) : bestTime,
    attempts: attempts + 1,
  );
  Map<String, Object?> toJson() => {
    'stars': starMask,
    'score': bestScore,
    'time': bestTime,
    'attempts': attempts,
  };
  static LevelRecord fromJson(Map<String, dynamic> json) {
    int nonnegative(String key) =>
        json[key] is num ? math.max(0, (json[key] as num).toInt()) : 0;
    final time = json['time'];
    return LevelRecord(
      starMask: nonnegative('stars') & 7,
      bestScore: nonnegative('score'),
      attempts: nonnegative('attempts'),
      bestTime: time is num && time.isFinite && time > 0
          ? time.toDouble()
          : null,
    );
  }
}

class BrassCoin {
  BrassCoin(this.x, this.y);
  final double x, y;
  bool collected = false;
}

enum InfiniteSection { rush, breath, encounter }

InfiniteSection sectionAt(double meters) {
  final phase = meters % 360;
  // Lengthen recovery stretches early; encounters grow to the original share.
  final growth = ((meters - 600) / 1800).clamp(0.0, 1.0);
  return phase < 180
      ? InfiniteSection.rush
      : phase < 360 - 120 * growth
      ? InfiniteSection.breath
      : InfiniteSection.encounter;
}

extension SectionDetails on InfiniteSection {
  String get label => switch (this) {
    InfiniteSection.rush => 'THE RUSH',
    InfiniteSection.breath => 'CATCH YOUR BREATH',
    InfiniteSection.encounter => 'DANGER AHEAD',
  };
  double get densityFactor => switch (this) {
    InfiniteSection.rush => 1.15,
    InfiniteSection.breath => .55,
    InfiniteSection.encounter => .85,
  };
  double get spacingFactor => this == InfiniteSection.breath ? 1.3 : 1.0;
}

class DailyChallenge {
  static DateTime day(DateTime date) {
    final utc = date.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  static String key(DateTime date) =>
      day(date).toIso8601String().substring(0, 10);
  static int seed(DateTime date) {
    final d = day(date);
    return d.year * 10000 + d.month * 100 + d.day;
  }
}

/// Explicit integer generator makes a daily seed identical on web, Android and iOS.
class DailyRandom implements math.Random {
  DailyRandom(int seed) : _state = seed % 2147483646 + 1;
  int _state;
  @override
  double nextDouble() {
    _state = (_state * 48271) % 2147483647;
    return (_state - 1) / 2147483646;
  }

  @override
  int nextInt(int max) => (nextDouble() * max).floor();
  @override
  bool nextBool() => nextInt(2) == 0;
}
