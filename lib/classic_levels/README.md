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

`hazards` contains waves of lasers or moving holes. Each wave lists exact spawn
coordinates tagged with the numbered `target` during which they are used.
Waves repeat in file order; the wave counter selects among that target's listed
positions in order using modulo. With `motion: HazardMotion.legacy`, moving
holes move from their listed spawn point as in the original levels.
For `circle` and `oval`, positions are orbit centers; `radiusX`, `radiusY`,
`period` (seconds per cycle), and `phase` (radians) control their path.
Circles use `radiusX` for both axes. `horizontal` and `vertical` use sinusoidal
movement along one axis; `stationary` stays at its center. Motion starts after
the warning ends. `orientation: LaserOrientation.horizontal` makes a horizontal
laser beam; the default is vertical. Orientation and movement are independent.
Keep the entire movement envelope inside the board and clear of the active target.
Edit `warningSeconds`, `liveSeconds`, `firstHazardAfter`, and `hazardInterval`
to change timing. Timing restarts with each target attempt. An empty list means
no hazards. If you move a target hole, update its hazard positions yourself to
maintain safe clearance. `finaleTitle` and `finaleRule` set the optional briefing.

The initial coordinates preserve the previous generated Classic layouts exactly.
After changing artwork or hole positions, regenerate the mode previews with
`tool/bake_mode_previews.dart` using the instructions in the main README.
