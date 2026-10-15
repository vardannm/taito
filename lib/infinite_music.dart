/// Changes tempo without restarting the recording. Active gameplay time and
/// height-based pace both increase pressure; pauses advance neither input.
abstract final class InfiniteMusic {
  // The Complex keeps its recorded opening and build; use a modest tempo ramp
  // so the synths retain their character while pressure grows with the climb.
  static const bundled = true;
  static const asset = 'audio/theme_infinite_complex.mp3';
  static const sourceBpm = 104.0;
  static const openingRate = 1.0, maximumRate = 1.12;

  static double rateFor({required double seconds, required double pace}) {
    final timeGrowth = (seconds / 180).clamp(0.0, 1.0);
    final paceGrowth = ((pace - 1) / 4).clamp(0.0, 1.0);
    final rate = openingRate + .08 * timeGrowth + .04 * paceGrowth;
    // 1% increments keep the per-frame sync cheap while making small,
    // progressive tempo changes rather than a jump at each pace label.
    return ((rate * 100).round() / 100).clamp(openingRate, maximumRate);
  }
}
