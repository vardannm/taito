# Classic campaign progression review — 2026-10-18

Reviewed all 80 registered boards. Level 1 stays as the onboarding board;
levels 2–80 receive a progression pass. Permanent IDs, names, ten-target
objectives, three lives, star requirements and earned records stay stable.
There is no runtime random generation of Classic levels.

## What needed work

- Level 2 began at x=307 after level 1's centered opening, with twice as many
  traps. Level 6 sent the player almost to the top on its second target.
- Levels 2–30 mostly added one random trap per level, reaching 34 traps.
  Lasers appeared at 10 and vanished until 30; roaming holes appeared at 20
  and vanished until 30. Familiar skills received little reinforcement.
- The web chapter combined 26–32 traps with one, two and then three spiders.
  Level 51 abruptly dropped to 10 traps and no spiders. The later chapters
  repeated single patterns for five levels, then jumped to mixed waves.
- Moving-hole centers were frequently above or far across from the active
  target, giving little reason to read the motion on the way up from launch.

## Revised rhythm

Difficulty rises across chapters, with deliberate recovery boards when a new
skill appears. Every individual level need not be harder than its predecessor.
The structure is introduce, practice, vary, combine, then test mastery.

| Levels | Main purpose | Difficulty develops through |
| --- | --- | --- |
| 1–9 | Steering, braking, lifting, target selection | Centered openings, progressively wider routes and 3–11 traps |
| 10–19 | Read light gates while maintaining control | A generous laser introduction, recurring gates, varied static routes |
| 20–30 | Follow a moving threat and choose a bypass | A slower roaming-hole introduction, reinforcement, then alternating light/hole waves |
| 31–40 | Read territory before committing | One spider, then two; fewer traps at introductions; familiar light gates return |
| 41–50 | Plan around several persistent threats | Three spiders, roaming holes and light gates in separate, readable waves |
| 51–60 | Read circles, then stretched orbits | More substantial static boards, changing orbit phase, light gates and returning keepers |
| 61–70 | Cross moving vertical and horizontal beams | Each orientation starts alone, then combines with previously learned paths |
| 71–80 | Apply the full vocabulary | Changing wave orders, recovery at 72/76, returning territories, final four-pattern/three-keeper board |

Trap placement uses recognizable slaloms, staggered gates, paired bays and
broken spines, with safe gaps around numbered targets. Traps stay out of
spider artwork and the launch area. The early boards give more room than later
ones. Trap counts ease when a new pattern or spider count appears.

Lasers recur at 12, 15, 18 and 24. Roaming holes recur at 22 and 26; 28 and 30
alternate the two. The web returns to light gates at 38/46, moving holes at 42,
and mixed waves at 48/50. Later keepers return at 55/59/60, 64/65, 69/70 and
through the final chapter. Wave order and phase vary between neighboring boards.

First introductions at 10/20/51/56/61/66 give six seconds before the first
warning and at least 2.8 seconds of warning. Every wave has at least 2.4 seconds
of warning, a complete movement envelope within the board, more than 32 units
of clearance from its assigned target, and at least 1.2 seconds between its
expiration and the next warning. The existing simulation permits one active
Classic wave at a time. Briefings introduce the first, second and third keepers.

## Validation and limits

All 651 regression tests pass. Static analysis of `lib`, `test` and the new
review tools reports no issues. The preview bake and full campaign renderer
also pass. Two existing timing checks now read the authored delay/warning
instead of assuming the previous three-second laser start.

The audit checks all 800 targets from the actual launch point, because each
capture returns the bar to launch. Other numbered holes count as obstacles.
The search uses a four-unit grid with 16-unit clearance from hole centers and
12 units beyond drawn spider territories. Route segments are also checked using
the actual swept collision function. Motion checks sample complete cycles,
including spawn phase.

Four contact sheets show every actual rendered board, and individual captures
show representative warnings and live hazards. Reproduce these with
`tool/render_classic_progression.dart`. Export current definitions and spatial
metrics with `tool/audit_classic_levels.dart`.

Automated reachability and staged captures are not human playthroughs. Actual
fun, touch comfort, difficulty, and time-star budgets still need real phone
sessions. In the next playtest, compare attempts, losses and voluntary retries
at 1–3, 5–7, 9–12, 19–22, 29–32, 35–38, 42–44, 49–52, 55–57, 60–62,
65–67 and 74–80. Record which hazard caused a miss and whether the player could
explain it. Tune repeated sticking points rather than restoring trap count as
the sole difficulty measure.

## Every level

The table below records the intended focus and current authored threat counts.
Different waves alternate; the wave count does not mean simultaneous hazards.

| Level | Name | Traps | Keepers | Waves | Intended focus |
| --- | --- | ---: | ---: | ---: | --- |
| 1 | First steps | 3 | 0 | 0 | Centered onboarding; keep the original route. |
| 2 | Gentle bend | 4 | 0 | 0 | Small bends and a centered first catch. |
| 3 | Wide valley | 5 | 0 | 0 | Wider steering with generous trap clearance. |
| 4 | Little wave | 6 | 0 | 0 | Change turn rhythm without adding a new mechanic. |
| 5 | Open crossing | 7 | 0 | 0 | Introduce a mixed-height route after three lower catches. |
| 6 | Left bank | 8 | 0 | 0 | Left-biased approach; avoid an immediate climb to the top. |
| 7 | Right bank | 9 | 0 | 0 | Mirror the steering lesson toward the right. |
| 8 | Switchback | 10 | 0 | 0 | Revisit heights while braking around offset traps. |
| 9 | Twin bays | 11 | 0 | 0 | Rehearse route choices before the first light gate. |
| 10 | Long sweep | 11 | 0 | 1 | Introduce a short stationary laser with a long warning. |
| 11 | Slalom | 13 | 0 | 0 | Quiet slalom to consolidate control. |
| 12 | Crescent | 13 | 0 | 1 | Bring back the light gate on a new route. |
| 13 | Hourglass | 14 | 0 | 0 | Read staggered static gates. |
| 14 | Stairway | 14 | 0 | 0 | A quiet precision climb before the next timed crossing. |
| 15 | Crosswind | 14 | 0 | 1 | Mix light-gate timing with a broken central route. |
| 16 | Narrow river | 16 | 0 | 0 | Read an offset channel at greater static density. |
| 17 | Double switch | 16 | 0 | 0 | Switch between paired bays. |
| 18 | Broken rhythm | 16 | 0 | 1 | Recover the light-gate skill on a different approach. |
| 19 | Inside line | 18 | 0 | 0 | Static precision test with a fresh route. |
| 20 | Outward bound | 16 | 0 | 1 | Introduce a slow sweeping hole with fewer static traps. |
| 21 | Needlework | 18 | 0 | 0 | Quiet needlework after the new moving threat. |
| 22 | Tidal turn | 18 | 0 | 1 | Practice passing behind a roaming hole. |
| 23 | Chicane | 20 | 0 | 0 | Choose gaps through denser static gates. |
| 24 | Off balance | 19 | 0 | 1 | Recall light-gate timing after moving-hole practice. |
| 25 | Brass passage | 21 | 0 | 0 | Static route-choice board with an extra opening. |
| 26 | Razor bend | 21 | 0 | 1 | Repeat the moving-hole skill with a faster sweep. |
| 27 | Three turns | 22 | 0 | 0 | Practice three changes of route without a timed wave. |
| 28 | Pendulum | 21 | 0 | 2 | First alternation of light gates and roaming holes. |
| 29 | Final ascent | 24 | 0 | 0 | Static route-planning test before the chapter finale. |
| 30 | Masterwork | 22 | 0 | 2 | Alternate both learned hazards with fewer static traps. |
| 31 | Silken threshold | 17 | 1 | 0 | Introduce one marked keeper and explain persistent pursuit. |
| 32 | Quiet legs | 18 | 1 | 0 | Practice leaving the keeper undisturbed. |
| 33 | The watchful corner | 19 | 1 | 0 | Choose an alternate route around a corner territory. |
| 34 | Thread crossing | 20 | 1 | 0 | Read the gap between a gate and a territory. |
| 35 | First bite | 21 | 1 | 0 | One-keeper precision test. |
| 36 | Two keepers | 19 | 2 | 0 | Introduce two keepers with less static clutter. |
| 37 | Dust and silk | 20 | 2 | 0 | Practice the gap between two territories. |
| 38 | Hidden courtyard | 20 | 2 | 1 | Recall light-gate timing while respecting two keepers. |
| 39 | Tangled brass | 22 | 2 | 0 | Quiet two-keeper route planning. |
| 40 | Patient hunters | 22 | 2 | 0 | Larger keeper and expanded territory; no new timed attack. |
| 41 | The long web | 23 | 2 | 0 | Extend the two-keeper route challenge. |
| 42 | Narrow escape | 22 | 2 | 1 | Return to roaming holes with two territories. |
| 43 | Three sentinels | 21 | 3 | 0 | Introduce three keepers with fewer static traps. |
| 44 | Silk labyrinth | 22 | 3 | 0 | Practice three-territory route selection. |
| 45 | Midnight patrol | 23 | 3 | 0 | Quiet patrol-reading challenge. |
| 46 | Crossed territories | 23 | 3 | 1 | Bring back light gates around three keepers. |
| 47 | The gathering | 24 | 3 | 0 | Static precision between three territories. |
| 48 | Last safe passage | 24 | 3 | 2 | Alternate moving holes and light gates around the keepers. |
| 49 | Widow gallery | 25 | 3 | 0 | Quiet route-planning test before the web finale. |
| 50 | Heart of the web | 25 | 3 | 2 | Three keepers and alternating light/hole waves. |
| 51 | First orbit | 18 | 0 | 1 | Introduce circular motion with a long warning and quiet interval. |
| 52 | Roundabout | 19 | 0 | 2 | Circle and familiar fixed light gate alternate. |
| 53 | Satellite pass | 20 | 0 | 1 | A larger orbit with a different entry phase. |
| 54 | Twin moons | 21 | 0 | 2 | Alternate two orbit starting phases. |
| 55 | Clockface | 21 | 1 | 2 | Recombine circle, light gate and one returning keeper. |
| 56 | Elliptic drift | 20 | 0 | 1 | Introduce the stretched oval alone with breathing room. |
| 57 | Long orbit | 21 | 0 | 2 | Switch between oval and circular paths. |
| 58 | Oval crossing | 22 | 0 | 2 | Recall light-gate timing between oval passes. |
| 59 | Slingshot | 22 | 1 | 2 | Circle and oval paths around one keeper. |
| 60 | Planetary rings | 23 | 1 | 3 | Circle, oval and light gate alternate around a keeper. |
| 61 | Scanning light | 22 | 0 | 1 | Introduce a sideways-moving vertical beam alone. |
| 62 | Shifting columns | 23 | 0 | 2 | Moving vertical beam alternates with a circular hole. |
| 63 | Lighthouse | 24 | 0 | 2 | Moving vertical beam alternates with an oval. |
| 64 | Narrow beam | 24 | 1 | 1 | Moving vertical beam around a returning keeper. |
| 65 | Vertical dance | 24 | 1 | 3 | Three familiar patterns and one keeper. |
| 66 | Rising light | 23 | 0 | 1 | Introduce a rising/falling horizontal beam alone. |
| 67 | Low horizon | 24 | 0 | 2 | Horizontal beam alternates with a circular hole. |
| 68 | Elevator beams | 25 | 0 | 2 | Switch between both beam orientations. |
| 69 | Moving horizon | 25 | 1 | 2 | Horizontal beam and oval around a keeper. |
| 70 | Horizontal dance | 25 | 1 | 3 | Both beam orientations and a circle around a keeper. |
| 71 | Orbital crossing | 25 | 1 | 3 | Circle, moving vertical beam and oval around a keeper. |
| 72 | Light and shadow | 24 | 0 | 3 | Territory-free recovery using horizontal beam and both orbits. |
| 73 | Eclipse | 25 | 1 | 3 | Change wave order around a keeper. |
| 74 | Perihelion | 26 | 1 | 3 | Lead with the oval, then horizontal beam and circle. |
| 75 | Gravity well | 26 | 2 | 3 | Two keepers with three alternating hazard patterns. |
| 76 | Crossed signals | 25 | 1 | 4 | Four-pattern introduction with one keeper and fewer traps. |
| 77 | Celestial weave | 26 | 2 | 4 | Reorder all four patterns around two keepers. |
| 78 | Solar storm | 27 | 2 | 4 | Lead with the horizontal beam around two keepers. |
| 79 | Event horizon | 27 | 2 | 4 | Circle-led four-pattern test around two keepers. |
| 80 | Grand alignment | 28 | 3 | 4 | Final synthesis: all four motion types and three keepers. |
