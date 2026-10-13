/// Changes tempo without restarting the recording. Active gameplay time and
/// height-based pace both increase pressure; pauses advance neither input.
abstract final class InfiniteMusic {
  static const asset = 'audio/theme_infinite.wav';
  static const sourceBpm = 127.0;
  static const openingRate = 1.06, maximumRate = 1.30;

  static double rateFor({required double seconds, required double pace}) {
    final timeGrowth = (seconds / 180).clamp(0.0, 1.0);
    final paceGrowth = ((pace - 1) / 4).clamp(0.0, 1.0);
    final rate = openingRate + .14 * timeGrowth + .10 * paceGrowth;
    // 1% increments keep the per-frame sync cheap while making small,
    // progressive tempo changes rather than a jump at each pace label.
    return ((rate * 100).round() / 100).clamp(openingRate, maximumRate);
  }
}
