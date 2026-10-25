# Classic campaign progression review — 2026-10-18

Reviewed all 80 registered boards. Level 1 stays as the onboarding board;
levels 2–80 receive a progression pass. Permanent IDs, names, ten-target
objectives, three lives, star requirements and earned records stay stable.
There is no runtime random generation of Classic levels.

## 2026-10-25: levels 26–80 rebuilt

Levels 19–25 were hand-edited to add breathing holes, sized holes, moving
traps, moving targets, early keepers and dashed sweeping lasers. Levels 26–80
used none of those mechanics. They fell back to 17–28 scattered traps with
wider gaps than 16–25, and most later boards repeated one template: a static
scatter, one orbiting hole and one stationary light gate. Level 26 was easier
than 21–25, and later chapters grew only through keeper and wave counts.

All 55 boards were rebuilt. IDs, names, ten targets, three lives and star rules
are unchanged. Each board has its own set piece built from mechanics the player
has already met, and every board keeps at least one moving or breathing pattern.

| Levels | Chapter | New skills and set pieces |
| --- | --- | --- |
| 26–30 | Clockwork | Breathing gates in opposition, scissor lanes, pendulum targets with pistons, rolling gates whose opening travels; the finale combines them with the eye and the light gate. |
| 31–40 | The web I | Side-rail lasers begin. One, then two keepers guard doors, passes and a courtyard; small-hole dust, brass channels; the first great keeper at 40. |
| 41–50 | The web II | A serpentine with piston doors, labyrinth rooms, orbiting patrols, dashed light gates and a breathing gallery around three keepers; great-keeper finale at 50. |
| 51–60 | Orbits | Circles, then ovals: turnstiles, a roundabout, satellites around brass planets, a clockface, orbiting targets and two eyes at once. |
| 61–70 | Moving light | A sweeping gate alone, then with pistons, dashes and keepers; a rising gate alone at 66, then low, dashed and alternating with the sweep. |
| 71–80 | Synthesis | Eclipse, perihelion, gravity well, solar storm and event horizon set pieces; recovery at 72 and 76; all four motions and three keepers at 80. |

Difficulty rises through narrower gaps, faster and more numerous moving
patterns and more systems at once, not trap count alone. For each target the
widest route from launch was measured as ball-centre clearance beyond the
capture radius, counting static holes, breathing holes at their smallest,
keeper territories and the side rails. The median target's tightest gap falls
from about 19 at 26, through 13–15 in the web chapters, to 10–12 by 70–79.
It never goes below the route test's 7.5. Introductions (31, 36, 43, 51, 56,
61, 66) and recovery boards (72, 76) loosen it again. Eye paths keep at least
20 units, rim to rim, from every target; moving holes never cover a target;
filler holes keep 20 units clear around each target.

Every target on every rebuilt board was also checked with a space-time search
that moves holes, breathing holes and eyes along their real paths. From five
start phases, each target is reachable at 45 units/s or less while staying
4 units clear of every hole (waiting is allowed). Timed light gates keep the
existing rules: at least 2.4 s of warning (2.8 s at introductions), at least
1.2 s of quiet and more than 32 units from the active target. Every vertical
gate now stops above the launch, so a waiting ball is never inside a beam.

The files were exported through the level builder's own `exportDart`, so the
builder reopens and saves them unchanged. Section notes below that describe
26–80 before this pass are kept for history; the tables reflect the rebuild.

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
| 20–25 | Follow a moving threat and choose a bypass | Moving targets, breathing and sized holes, first keepers, a dashed sweeping laser |
| 26–30 | Read moving and breathing patterns | Breathing gates, scissor lanes, pendulum targets, rolling gates; one eye or light gate |
| 31–40 | Read territory before committing | Lethal rails; one keeper, then two, guarding doors, passes and a courtyard |
| 41–50 | Plan around several persistent threats | Three keepers with serpentines, rooms, patrols, dashed gates and galleries |
| 51–60 | Read circles, then stretched orbits | Turnstiles, satellites, a clockface and orbiting targets; one eye, then two |
| 61–70 | Cross moving vertical and horizontal beams | Each orientation starts alone, then gains dashes, keepers and the other orientation |
| 71–80 | Apply the full vocabulary | Set pieces recombine everything; recovery at 72/76; all four motions and three keepers at 80 |

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

As of the 2026-10-25 rebuild, 773 of 778 tests pass. The five failures stop
on hand-edited levels before 26: wave positions only for target 1 (12, 13),
a spider at the level-20 introduction, Level 23 without traps, Level 25's
star route, and Level 16 listing target 4 after target 5. Each of those
assertions was rerun on 26–80 alone and passes there, as does a full
ten-target run of every rebuilt level in every control mode without losing a
heart. The campaign renderer still draws all four contact sheets, then stops
at Level 20's representative capture, which now starts with a persistent
moving hole. The earlier note follows.

All 651 regression tests passed on 2026-10-18. Static analysis of `lib`,
`test` and the new review tools reported no issues. The preview bake and full
campaign renderer also passed. Two existing timing checks now read the
authored delay/warning instead of assuming the previous three-second laser
start.

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
| 26 | Razor bend | 35 | 0 | 1 | Two breathing gate rows in opposition, with the wandering eye between them. |
| 27 | Three turns | 37 | 0 | 0 | Scissor lanes: neighbouring shuttles close and reopen gaps; three short walls turn the climb. |
| 28 | Pendulum | 38 | 0 | 1 | Swinging targets, pistons inside the low wall's gaps, and the light gate. |
| 29 | Final ascent | 34 | 1 | 0 | Four rolling gates whose opening travels in alternating directions; a small keeper. |
| 30 | Masterwork | 32 | 0 | 2 | Chapter test: scissor lane, breathing gate, swinging targets, eye and light gate. |
| 31 | Silken threshold | 33 | 1 | 0 | Side-rail lasers begin. A wall with a breathing door and a keeper-guarded door. |
| 32 | Quiet legs | 39 | 1 | 0 | Central keeper with swinging targets on both sides. |
| 33 | The watchful corner | 38 | 1 | 0 | Corner keeper; targets close to the lethal rails; two shuttles. |
| 34 | Thread crossing | 32 | 1 | 1 | Breathing gate half-watched by a keeper; the eye sweeps the floor below. |
| 35 | First bite | 40 | 1 | 1 | A fast keeper, shuttle and piston around the light gate. |
| 36 | Two keepers | 30 | 2 | 0 | Recovery density: two territories with breathing posts between them. |
| 37 | Dust and silk | 53 | 2 | 0 | A field of small holes between two keepers. |
| 38 | Hidden courtyard | 32 | 2 | 1 | Ring courtyard with two doors and two inner targets; keepers flank it; light gate. |
| 39 | Tangled brass | 27 | 2 | 0 | Large and small brass holes form channels; two keepers; shuttles. |
| 40 | Patient hunters | 28 | 2 | 0 | First large keeper; swinging targets; a breathing gate across the floor. |
| 41 | The long web | 36 | 2 | 0 | Serpentine walls with doors on alternating rails, a piston in every door, keepers in the floors. |
| 42 | Narrow escape | 48 | 2 | 1 | The eye between two keepers, above a scissor lane. |
| 43 | Three sentinels | 36 | 3 | 0 | Three keepers at recovery density. |
| 44 | Silk labyrinth | 27 | 3 | 0 | Rooms and partitions with a breathing door; three keepers. |
| 45 | Midnight patrol | 39 | 3 | 0 | Patrol holes circle their posts (orbit preview); three keepers. |
| 46 | Crossed territories | 44 | 3 | 1 | Dashed light gate among three keepers. |
| 47 | The gathering | 36 | 3 | 0 | Keepers gather in the middle; targets line the rails; rolling gate at the floor. |
| 48 | Last safe passage | 44 | 3 | 2 | Three keepers, eye, light gate and shuttles. |
| 49 | Widow gallery | 20 | 3 | 0 | Three breathing columns a beat apart; the fastest keepers so far. |
| 50 | Heart of the web | 26 | 3 | 2 | Chapter test: great keeper and two keepers, scissor lane, eye, light gate, swinging targets. |
| 51 | First orbit | 31 | 0 | 1 | Circle-eye introduction alone; a turnstile and one orbiting target. |
| 52 | Roundabout | 40 | 0 | 2 | Roundabout ring with side doors around a turning bar; circle eye; light gate. |
| 53 | Satellite pass | 34 | 0 | 1 | Satellites around brass planets; two orbiting targets; circle eye. |
| 54 | Twin moons | 43 | 0 | 2 | Two orbiting eyes half a turn apart; two turnstiles. |
| 55 | Clockface | 42 | 1 | 1 | Clock ring with three doors and a sweeping hand; keeper; light gate. |
| 56 | Elliptic drift | 32 | 0 | 1 | Oval-eye introduction alone; oval traps and one oval target. |
| 57 | Long orbit | 37 | 0 | 2 | Oval and circle eyes keeping different time; oval traps; oval target. |
| 58 | Oval crossing | 41 | 0 | 2 | Three ovals cross the middle; light gate. |
| 59 | Slingshot | 38 | 1 | 1 | Three fast orbiting targets; a satellite planet; keeper; oval eye. |
| 60 | Planetary rings | 40 | 1 | 3 | Chapter test: three planets with turning rings, two eyes, keeper and light gate. |
| 61 | Scanning light | 49 | 0 | 1 | Sweeping vertical gate introduction alone; shuttle and breathing posts. |
| 62 | Shifting columns | 47 | 0 | 2 | Two columns of pistons; sweeping gate; circle eye. |
| 63 | Lighthouse | 42 | 0 | 2 | Dashed sweeping gate around a brass lighthouse; oval eye. |
| 64 | Narrow beam | 39 | 1 | 1 | Three narrow columns, a narrow sweep and a keeper. |
| 65 | Vertical dance | 50 | 1 | 3 | Sweeping gate with circle and oval eyes and a keeper. |
| 66 | Rising light | 53 | 0 | 1 | Rising horizontal gate introduction alone. |
| 67 | Low horizon | 41 | 0 | 2 | Rising gate low on the board; circle eye; shuttle and breathing posts at the floor. |
| 68 | Elevator beams | 43 | 0 | 2 | Both gate orientations in turn; three bobbing targets; pistons. |
| 69 | Moving horizon | 49 | 1 | 2 | Dashed rising gate with sliding dashes; oval eye; keeper. |
| 70 | Horizontal dance | 58 | 1 | 3 | Chapter test: both gates, circle eye, keeper, shuttles. |
| 71 | Orbital crossing | 52 | 1 | 3 | Two eyes, a turnstile, a keeper and the sweeping gate. |
| 72 | Light and shadow | 43 | 0 | 3 | Recovery: no keepers, one rolling row, rising gate and two eyes. |
| 73 | Eclipse | 54 | 1 | 3 | An eye orbiting a great planet; both gates take turns; keeper. |
| 74 | Perihelion | 45 | 1 | 3 | A long, fast oval through the middle; circle eye; rising gate; oval target. |
| 75 | Gravity well | 56 | 2 | 3 | A breathing ring around a brass well; two keepers; both gates. |
| 76 | Crossed signals | 48 | 1 | 4 | Recovery: lighter board with all four motions and one keeper. |
| 77 | Celestial weave | 49 | 2 | 4 | Scissor lane and turnstile with two keepers, two eyes and both gates. |
| 78 | Solar storm | 46 | 2 | 2 | Two rolling rows in opposite directions; dashed gates; two keepers. |
| 79 | Event horizon | 51 | 2 | 4 | Four holes orbit a great centre; two keepers; two eyes; both gates. |
| 80 | Grand alignment | 47 | 3 | 4 | Final test: three keepers, circle and oval eyes, both gates, a rolling row, moving targets. |
