/// Edit these values, then hot restart and start a fresh Infinite run.
/// Growth multipliers: 0 removes growth, 1 is normal, values above 1 increase it.
/// Spider speeds below are world units per second. Applies to normal Infinite.
abstract final class InfiniteDifficulty {
  // Base speed growth from 68 toward 180 (separate from the pace bonus).
  static const speedGrowth = 1.3;

  // Pace's extra speed and tighter spacing; scoring/pace labels stay the same.
  static const paceGrowth = 1.0;

  // Fixed distance between recurring pickups, in displayed metres (must be > 0).
  // First pickup positions are configured separately in InfiniteTuning.
  static const magnetSpacingMetres = 2000.0;
  static const shieldSpacingMetres = 3500.0;

  // Active duration after collecting a pickup, in seconds (must be > 0).
  // Collecting another pickup refreshes its timer to this duration.
  static const shieldSeconds = 8.0;
  static const magnetSeconds = 9.0;

  // Hearts: minimum spacing plus a random extra distance, in displayed metres.
  // Spacing must be > 0; jitter can be 0 for fixed spacing.
  // Hearts only spawn while below maximum lives. Defaults give 360-540m gaps.
  static const heartSpacingMetres = 760.0;
  static const heartSpacingJitterMetres = 180.0;

  // More holes and shorter row spacing as score and distance increase.
  static const obstacleDensity = 1.2;

  // Shrinks the reserved path half-width from 46 toward 34 world units.
  static const pathNarrowing = 1.0;

  // Unlock rate: 0 disables specials; 0.5 doubles their unlock distances.
  static const hazardUnlocks = 1.1;

  // Shortens special-hazard intervals as distance increases.
  static const hazardFrequency = 1.2;

  // Chance of sweeping lasers, zigzag/orbiting holes after 2,400m in encounters.
  static const hardHazards = 1.0;

  // Growth of encounter sections at the expense of breathing sections.
  static const sectionPressure = 1.0;

  // Spider spawn-frequency, territory-size and chase-speed growth.
  static const spiderGrowth = 1.2;

  // Base chase speed; pace adds its existing bonus. Default: 44.
  static const spiderSpeed = 90.0;

  // Speed of the spider's web projectile. Default: 90.
  static const spiderBulletSpeed = 180.0;
}
