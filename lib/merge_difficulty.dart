/// Edit these values, then hot restart and start a fresh Number Merge run.
/// Speeds and distances use board units (the board is 360 units wide).
/// See README.md for an easier example.
abstract final class MergeDifficulty {
  // Falling balls: speed = startSpeed + speedPerDoubling for every doubling
  // of the highest ball above 2, capped at maxSpeed.
  // startSpeed > 0; speedPerDoubling >= 0; maxSpeed >= startSpeed.
  // Lowered 15% (from 42, 8 and 112) to make Merge a little gentler.
  static const startSpeed = 35.7;
  static const speedPerDoubling = 6.8;
  static const maxSpeed = 95.2;

  // Distance between new waves (> 0). Larger means more breathing room.
  // Time between waves is waveSpacing / current falling speed.
  static const waveSpacing = 96.0;

  // Opening: three rows starting at y=90. Spacing must be > 0 and <= 140
  // so all three rows start above the player's launch position.
  static const initialRowSpacing = 120.0;

  // Horizontal separation between balls in a wave: 30..60.
  // At most 60 guarantees room for all three balls across the platform.
  static const orbSeparation = 60.0;
  // Random vertical offset within each row, from 0 up to this value (0..30).
  static const rowJitter = 18.0;

  // Maximum probability (0..1) that the third ball in a wave is dangerous.
  // 1 = every wave, 0.5 = roughly half, 0 = no dangerous balls.
  // The third ball becomes dangerous from a 4 head, reaching the maximum at 16.
  // The first ball always matches the tail. A second danger joins from 64.
  // A dangerous ball is randomly 2x or 4x the head when it spawns.
  static const dangerChance = 1.0;
  // Second-ball danger reaches this maximum at 256; one safe match always remains.
  static const secondaryDangerChance = .45;

  // Chance the second safe ball matches an existing segment (0..1).
  // Otherwise it can fill a missing power, setting up a later chain.
  static const matchingChance = .4;

  // Minimum fresh score between gates. Later gaps grow to the head value.
  // Raised from 900 so the first gate and later ones arrive less often.
  static const gateInterval = 1400;
  // Gate speed is falling speed + this nonnegative bonus (15% lower than 22).
  static const gateSpeedBonus = 18.7;
  // Minimum seconds after clearing a gate before another can spawn (>= 0).
  static const gateCooldownSeconds = 5.0;

  // Integer power-of-two adjustment to gate requirements (-8..8).
  // 0 = half the head value, -1 = quarter, +1 = equal to the head.
  // Requirements never fall below 2. The head must be STRICTLY greater.
  // Each gate also requires at least double the previous gate's value.
  static const gateValueOffset = 1;
}
