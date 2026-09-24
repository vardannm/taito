/// Edit these values, then hot restart and start a fresh Infinite run.
/// Growth multipliers: 0 removes growth, 1 is normal, values above 1 increase it.
/// Spider speeds below are world units per second. Applies to normal Infinite.
abstract final class InfiniteDifficulty {
  // Base speed growth from 68 toward 180 (separate from the pace bonus).
  static const speedGrowth = 1.3;

  // Pace's extra speed and tighter spacing; scoring/pace labels stay the same.
  static const paceGrowth = 1.0;

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
  static const spiderSpeed = 44.0;

  // Speed of the spider's web projectile. Default: 90.
  static const spiderBulletSpeed = 90.0;
}
