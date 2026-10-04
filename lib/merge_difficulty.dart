/// Edit these values, then hot restart and start a fresh 2048 / Merge run.
/// Speeds and distances use board units (the board is 360 units wide).
/// Defaults preserve the current game. See README.md for an easier example.
abstract final class MergeDifficulty {
  // Falling balls: speed = startSpeed + speedPerDoubling for every doubling
  // of the highest ball above 2, capped at maxSpeed.
  // startSpeed > 0; speedPerDoubling >= 0; maxSpeed >= startSpeed.
  static const startSpeed = 30.0;
  static const speedPerDoubling = 5.0;
  static const maxSpeed = 66.0;

  // Distance between new waves (> 0). Larger means more breathing room.
  // Time between waves is waveSpacing / current falling speed.
  static const waveSpacing = 110.0;

  // Opening: three rows starting at y=90. Spacing must be > 0 and <= 140
  // so all three rows start above the player's launch position.
  static const initialRowSpacing = 120.0;

  // Horizontal separation between balls in a wave: 30..60.
  // At most 60 guarantees room for all three balls across the platform.
  static const orbSeparation = 60.0;
  // Random vertical offset within each row, from 0 up to this value (0..30).
  static const rowJitter = 18.0;

  // Probability (0..1) that the third ball in a wave is dangerous.
  // 1 = every wave, 0.5 = roughly half, 0 = no dangerous balls.
  // The first ball always matches the tail; the second is always safe.
  // A dangerous ball is randomly 2x or 4x the head when it spawns.
  static const dangerChance = 1.0;

  // Minimum fresh score between gates. Later gaps grow to the head value.
  static const gateInterval = 1200;
  // Gate speed is falling speed + this nonnegative bonus.
  static const gateSpeedBonus = 12.0;
  // Minimum seconds after clearing a gate before another can spawn (>= 0).
  static const gateCooldownSeconds = 4.0;

  // Integer power-of-two adjustment to gate requirements (-8..8).
  // 0 = half the head value, -1 = quarter, +1 = equal to the head.
  // Requirements never fall below 2. The head must be STRICTLY greater.
  // Each gate also requires at least double the previous gate's value.
  static const gateValueOffset = 0;
}
