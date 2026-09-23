/// Edit these nine numbers, then hot restart and start a fresh Infinite run.
/// Range: 0.0–1.0. All defaults are 1.0, preserving the existing difficulty.
/// 0.0 removes that growth; 0.5 reduces it; 1.0 is the original full strength.
/// Base obstacles/speed remain. These controls apply to normal Infinite.
abstract final class InfiniteDifficulty {
  // Base speed growth from 68 toward 180 (separate from the pace bonus).
  static const speedGrowth = 1.0;

  // Pace's extra speed and tighter spacing; scoring/pace labels stay the same.
  static const paceGrowth = 1.0;

  // More holes and shorter row spacing as score and distance increase.
  static const obstacleDensity = 1.0;

  // Shrinks the reserved path half-width from 46 toward 34 world units.
  static const pathNarrowing = 1.0;

  // Unlock rate: 0 disables specials; 0.5 doubles their unlock distances.
  static const hazardUnlocks = 1.0;

  // Shortens special-hazard intervals as distance increases.
  static const hazardFrequency = 1.0;

  // Probability of hard variants after 2,400m, subject to encounter rules.
  static const hardHazards = 1.0;

  // Growth of encounter sections at the expense of breathing sections.
  static const sectionPressure = 1.0;

  // Spider spawn-frequency, territory-size and chase-speed growth.
  static const spiderGrowth = 1.0;
}
