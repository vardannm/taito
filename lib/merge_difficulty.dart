/// Edit these values, then hot restart and start a fresh 2048 / Merge run.
/// Speeds and distances use board units (the board is 360 units wide).
/// Defaults preserve the current game. See README.md for an easier example.
abstract final class MergeDifficulty {
  // Falling balls: speed = startSpeed + speedPerDoubling for every doubling
  // of the highest ball above 2, capped at maxSpeed.
  // startSpeed > 0; speedPerDoubling >= 0; maxSpeed >= startSpeed.
  static const startSpeed = 30.0;
  static const speedPerDoubling = 3.0;
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

  // Score earned between gates (positive integer). Larger = fewer gates.
  static const gateInterval = 400;
  // Gate speed is falling speed + this nonnegative bonus.
  static const gateSpeedBonus = 12.0;
  // Minimum seconds between clearing a gate and spawning a queued one (>= 0).
  static const gateCooldownSeconds = 1.2;

  // Integer power-of-two adjustment to gate requirements (-8..8).
  // 0 = current curve, -1 = half the required value, +1 = double.
  // Requirements never fall below 2. The head must be STRICTLY greater.
  // With 0: score 400 -> gate 128; 800 -> 256; 1200 -> 512.
  static const gateValueOffset = 0;
}
