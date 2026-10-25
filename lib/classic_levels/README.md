# Classic levels

Each level has its own file, from `level_01.dart` through `level_80.dart`.
Edit that file's `name`, `holes`, `spiders`, and `hazards` to change the level.

```dart
Hole(120, 450, target: 1), // Numbered target: visit in order from 1 to 10.
Hole(240, 300),            // Trap hole.
```

Coordinates use the game's 360 × 560 board: x increases to the right and y
increases downward. Keep exactly one of each target number, 1 through 10,
and allow space for the ball to reach every target.

`../classic_levels.dart` registers these files in level order. Keep that order
stable to preserve saved progress. `../levels.dart` loads a fresh copy of the
selected layout and supplies shared coin and unlock rules.
Daily mode continues to generate its own seeded layouts independently.

`spiders` contains explicit patrol-center coordinates (`x`, `y`), territory
radius, initial patrol phase, chase speed and body radius. A spider initially
stands 12 units from its center at the given phase, then patrols around it.
An empty list means no spiders. No runtime placement generator is used.

`hazards` contains waves of lasers or moving holes. Moving-hole waves each create
one permanent hole at their target-1 position when the level loads. They move
immediately, including while waiting for the first input, and retain their path
and phase between targets. Pause freezes them; replay resets them. Their warning
and live durations do not apply in Classic mode.

For timed laser waves, each wave lists exact spawn
coordinates tagged with the numbered `target` during which they are used.
Waves repeat in file order; the wave counter selects among that target's listed
positions in order using modulo. With `motion: HazardMotion.legacy`, moving
holes move from their listed spawn point as in the original levels.
For `circle` and `oval`, positions are orbit centers; `radiusX`, `radiusY`,
`period` (seconds per cycle), and `phase` (radians) control their path.
Circles use `radiusX` for both axes. `horizontal` and `vertical` use sinusoidal
movement along one axis; `stationary` stays at its center. Timed laser motion
starts after the warning ends. `orientation: LaserOrientation.horizontal` makes a horizontal
laser beam; the default is vertical. Orientation and movement are independent.
Keep the entire movement envelope inside the board and clear of the active target.
Edit `warningSeconds`, `liveSeconds`, `firstHazardAfter`, and `hazardInterval`
to change timing. The level's hazard clock, moving hazards, and spider patrols
continue while the ball sinks and the platform returns between targets. Only
starting or replaying the whole level resets them. Hidden-ball return animation
does not take damage. An empty list means no hazards. If you move a target hole,
update its hazard positions yourself to
maintain safe clearance. `finaleTitle` and `finaleRule` set the optional briefing.

The October 2026 progression pass keeps level IDs and names stable, reauthors
levels 2–9, and replaces density-only trap growth with slaloms, offset gates,
paired bays and broken central routes. Known hazards return between milestone
introductions and combine again in the final chapters. A later pass rebuilt
levels 26–80 around the moving, breathing and sized holes, moving targets and
dashed beams introduced in 19–25, with one set piece per board. See
`../../CLASSIC_PROGRESSION.md` for the full level-by-level review.

Run the campaign audit with the project-local Dart SDK:

```powershell
.\.tools\flutter\bin\cache\dart-sdk\bin\dart.exe tool/audit_classic_levels.dart
.\scripts\flutter.ps1 test --no-pub test/classic_progression_test.dart
.\scripts\flutter.ps1 test --no-pub tool/render_classic_progression.dart
```

The audit writes `artifacts/classic-levels.json` with real definitions, trap
clearance, route detours and unreachable targets, and exits nonzero if any
target has no buffered route from launch. The test also samples complete
hazard cycles and verifies quiet intervals. These spatial checks do not measure
human completion times or guarantee that a route feels comfortable on a phone.

Mode previews draw the current level data directly; no PNG regeneration is needed.
