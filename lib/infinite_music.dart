/// Alternate arrangements of one theme, edited to the same beat and loop length.
abstract final class InfiniteMusic {
  static const bundled = true;
  static const asset = 'audio/theme_infinite_climb.wav';
  static const fastAsset = 'audio/theme_infinite_fast.wav';
  static const bossAsset = 'audio/theme_infinite_boss.wav';
  static const assets = [asset, fastAsset, bossAsset];
  static const sourceBpm = 96.0;
  static const loopDuration = Duration(seconds: 30);
  static const loopOverlap = Duration(milliseconds: 2500);
  static const fileDuration = Duration(milliseconds: 32750);

  static double intensityFor({required double seconds, required double pace}) {
    final timeGrowth = ((seconds - 20) / 220).clamp(0.0, 1.0);
    final paceGrowth = ((pace - 1) / 4).clamp(0.0, 1.0);
    final growth = (.35 * timeGrowth + .65 * paceGrowth).clamp(0.0, 1.0);
    // Smooth the build, and avoid issuing a new platform request every frame.
    return (growth * growth * (3 - 2 * growth) * 100).round() / 100;
  }

  static MusicMix mixFor({
    required double seconds,
    required double pace,
    required bool boss,
  }) => boss
      ? const MusicMix(0, 0, 1)
      : MusicMix.forClimb(intensityFor(seconds: seconds, pace: pace));
}

/// Linear complementary gains keep complete arrangements from stacking loudly.
class MusicMix {
  const MusicMix(this.climb, this.fast, this.boss)
    : assert(climb >= 0 && fast >= 0 && boss >= 0),
      assert(climb + fast + boss <= 1.000001);

  factory MusicMix.forClimb(double intensity) {
    final value = intensity.clamp(0.0, 1.0);
    return MusicMix(1 - value, value, 0);
  }

  final double climb, fast, boss;
  List<double> get gains => [climb, fast, boss];

  @override
  bool operator ==(Object other) =>
      other is MusicMix &&
      other.climb == climb &&
      other.fast == fast &&
      other.boss == boss;
  @override
  int get hashCode => Object.hash(climb, fast, boss);
}
