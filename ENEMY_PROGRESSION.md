# Infinite enemy progression

Snakes, Bombardier Beetles, Ricochet Crickets, Moths, Scorpions and Seed Spitters now share one encounter director. Spiders and porcupines retain their terrain placement and attack rules. Classic levels are unchanged.

## A different introduction plan every run

At the beginning of a run, the director shuffles all six enemy types. The first gets an unlock between 800 and 1,000 metres. Each following type unlocks 400–650 metres after the previous one. Every type can occupy every position, including the first. All six become eligible by about 4,250 metres at the latest.

These are unlock distances, not promises to attack immediately. A breathing section, a maze, recovery after damage, an active attack or an unsafe beetle landing can delay the actual appearance. A blocked enemy stays unintroduced and is considered again later; it does not stop other eligible enemies.

Examples from the simulation:

| Position | Run with seed 12 | Run with seed 21 |
|---|---|---|
| 1 | Seed Spitter, 854 m | Moth, 919 m |
| 2 | Moth, 1,329 m | Scorpion, 1,457 m |
| 3 | Scorpion, 1,764 m | Cricket, 1,937 m |
| 4 | Beetle, 2,185 m | Snake, 2,453 m |
| 5 | Cricket, 2,605 m | Beetle, 2,925 m |
| 6 | Snake, 3,126 m | Seed Spitter, 3,330 m |

The same seed reproduces the same plan for testing. A fresh run gets a new plan. Pausing, damage and a rewarded revive preserve the existing plan. Points, combo bonuses and shop equipment never advance enemy unlocks.

## Choosing the next encounter

Before choosing, gameplay excludes attacks that cannot start safely. The director then prioritizes the oldest unlocked enemy that has not appeared yet. An enemy counts as introduced only after it actually spawns.

Once eligible new types have appeared, repeats use weighted randomness:

- The previous enemy is excluded if another ready enemy exists.
- A type cannot return within 28 seconds of its last spawn.
- The last three enemy types get less selection weight.
- Switching attack style is favored: moving-body/rebound attacks, area attacks, curved/splitting streams, and straight aimed bursts.
- Enemies that have appeared less often or have waited longer get more weight.
- Each run adds a small random preference to each type, so two runs need not settle into the same repeating pattern.

This preserves randomness while discouraging repetitive sequences. The repeat restriction may leave quiet time when only one enemy has unlocked.

## Keeping attacks readable

Snakes and visitors share a quiet interval after departure. The minimum is 14 seconds, plus up to 5 seconds of variation. Early in a run, an additional rest bonus gives more breathing room; it fades from 6 seconds at the start to zero at 2,400 metres.

New encounters wait for special hazards, web shots, quills, charging porcupines, snakes and active visitors to clear. They also wait during recovery after damage. Shields do not change the encounter plan. Existing visitors finish their warnings and attacks when the run enters a breathing section, and an approaching maze waits for a visitor to finish. Snakes retain their existing cleanup during breathing sections and mazes.

Snakes can now appear in Rush or Encounter sections once their randomized distance unlock is reached. All existing warning times, projectile speeds, collision rules and beetle escape checks are retained.

## Configuration

Edit `lib/infinite_difficulty.dart`, hot restart, and start a fresh run:

| Setting | Current value | Effect |
|---|---:|---|
| `enemyFirstUnlockMetres` | 800 | Earliest first unlock |
| `enemyFirstUnlockJitter` | 200 | Random extra distance for the first unlock |
| `enemyUnlockGapMetres` | 400 | Minimum gap between later unlocks |
| `enemyUnlockGapJitter` | 250 | Random extra distance per gap |
| `enemyRepeatCooldownSeconds` | 28 | Minimum time before the same type may return |
| `enemyOpeningRestBonus` | 6 | Extra rest early in the run |
| `lateEnemyRestSeconds` | 14 | Minimum shared rest after an encounter leaves |

The plan and weighted selection live in `lib/encounter_director.dart`. Eligibility, spawning, warnings and cleanup connect to it in `lib/infinite_gameplay.dart` and `lib/game.dart`.
