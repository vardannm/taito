# Validation record

## Interactive onboarding, goals, friend codes and backups — 2026-09-16

- Replaced the illustrated tutorial with three real touch exercises using the shared PivotBoard and AnalogControls: lift/release, tilt, and target capture. Each control mode is selectable. The simulation is isolated from profile rewards. Compact screens scroll outside the active controls; control gestures do not scroll the lesson.
- Added the arcade club via the home NEXT goal and Settings. Goals select incomplete Classic levels for the chosen control mode, then clean/time objectives and Daily play. Cabinet progress remains based on earned stars.
- Added bounded local Daily friend-code import/share. Codes pin date, control mode and rules version; they are explicitly friend-reported personal scores. Added versioned manual progress export/restore with size/type/range checks, a replacement preview, and isolated test-economy validation.
- Added an opt-in, local playtest event recorder, a five-participant session protocol, store-copy draft, Android signing template/configuration, and a read-only release preflight. Human sessions and physical-device tests remain NOT RUN.
- Removed the temporary unconditional wallet=99999 override after the regression suite exposed five persistence failures. Normal wallets persist again; the existing GILT_UNLIMITED_COINS test flag still permits free test purchases in a separate economy.
- Full automated suite: **211 tests passed**. Final static analysis: **No issues found**. Touch tests complete all three lessons in all control modes on 320×568; 390×844 gestures also passed earlier. The club is covered at 320×568 with 1.6× text. Ten actual Flutter phone renders were generated, with representative compact/home/tutorial/club renders inspected.
- Web release build succeeded. Android playtest APK built and package metadata verified as version 0.11.0, build 15; development signing remains active because no upload key is configured. No Android device was attached during the final device inventory. Native iOS build/signing and battery/frame-time measurements require external hardware and remain unverified.
- Online leaderboards and automatic cloud synchronization are **not implemented or deployed**; backend selection/account setup is pending. Local friend codes and manual backups are functional and described accurately in the UI. See release/ONLINE_SCOPE.md for outstanding service requirements.
- Logs: artifacts/growth-tests-final.log, growth-analysis-final.log, growth-renders-final.log, growth-android-final.log. Screenshots: artifacts/growth-*.png. No store upload, player recruitment, or fabricated retention data.


## Right-angled Laser Maze routes and endless climb - 2026-09-10

- Replaced the single-valued `centerAt(y)` corridor with `LaserMazeCorridor`: a list of axis-aligned legs whose union is the road, and whose lasers are the exact boundary of that union (each leg edge minus the spans covered by another leg). Sideways legs are ordinary legs in this model, so every route now climbs a column, crosses sideways and climbs again through real right angles. All ten routes were rebuilt from a per-level half-width (40 down to 26) and a lane fraction per crossing (two crossings on route 1, six on routes 8-10). Progress follows the whole centerline by arc length instead of height.
- Added an endless Laser Maze: `EndlessMaze` generates the same right-angled legs above the ball forever, narrows from 40 to 26 half-width and shortens its legs over the first 2,400 units of climb, prunes legs left more than 360 units below the ball, and keeps the centerline and arc lengths aligned with the live geometry. The camera follows the climb, the score is metres climbed, there is no finish line, and the best height and attempt count persist separately from the per-route best times. Reached from a new card at the top of the route picker.
- Winning now requires crossing the finish line inside the final column; crossing that height in another lane is a wall. One-finger control keeps its 14-unit/second automatic climb but the climb now waits while a sideways ceiling is overhead, holding 16 units clear of the beam until tilt carries the ball into the next column.
- **This change was not compiled or tested.** The project-local SDK at `.tools/flutter` is absent on this machine and no other Flutter/Dart installation is present, so `flutter analyze`, the regression suite and the render fixtures could not be run. The Dart sources, the rewritten `test/laser_maze_test.dart` and the updated `tool/render_maze.dart` are on disk unexecuted.
- Verification was done instead against a line-by-line Python port of the new geometry, with the port's constants checked automatically against the Dart source (widths, lane patterns, route heights, endless ramp and generation bounds all matched):
  - Outline exactness, all ten routes and twelve endless seeds: every wall segment has road on exactly one side (no interior beams), and every road/outside transition on a 1-unit grid has a wall within one unit (no gaps). A few duplicate collinear wall segments exist at turns; they are harmless for collision and drawing.
  - Ball clearance: walking the full centerline with a 7-unit swept circle never contacts a wall on any of the ten routes, and never over 120 legs on each of 40 endless seeds while the corridor grows and prunes.
  - Route bounds stay inside x 30-330 and y 24-548; sideways legs stay separated by more than the corridor width, so legs never merge into one open room.
  - Playability under the real platform physics, driven by a rate-limited controller: two-finger play finishes every route in 7-25 seconds and climbs over 4,000 units on eight endless seeds; one-finger play, with the new waiting climb and a controller that feathers tilt to its available headroom, finishes all ten routes in 32-43 seconds and climbs 2,000 units in endless. A crude one-finger controller that slams the tilt dies on route 10, so the tightest routes demand gentle tilt near the rails in that mode.
  - A straight lift out of the launch column ends on a wall on all ten routes, which is the structural check that no route is a purely vertical climb.
- Not verified here: static analysis, the automated suite, actual Flutter renders, device performance, and human difficulty or enjoyment of the new turns. The route and endless difficulty ramps are provisional.

## Mastery, daily boards, finales and cabinet unlocks â€” 2026-09-09

- Added completion/clean/time stars, per-board personal records separated by control mode, optional 250-point coins, a retry of the current board, and four cosmetic cabinet/ball/platform palettes. Records merge earned objectives across runs and persist; duplicate result recording is ignored.
- Added local UTC daily boards using a stable integer generator, date-pinned retries and separate records bounded to 32 days. No online ranking/account service is configured, as requested.
- Infinite now cycles through rush, lighter and encounter sections while retaining its monotonic 60â€“180 ascent curve. Finale levels 10/20/30/40/50 use explicit briefings, warned laser/roaming-hole encounters, and larger spider keepers. Ordinary finale hazards cost one ball; spider contact ends the run.
- All 85 regression tests passed and static analysis reported no issues. New coverage includes a full year of daily seeds, objective merging, persistence, control separation, unlock thresholds, identical cosmetic physics, swept coin collection, coin reuse prevention, lethal-contact ordering, finale warning/pause/reset behavior, UTC boundaries, daily history bounds, small-phone Daily/retry and enlarged-text Cabinet layouts.
- Actual Flutter phone renders reviewed for the grid, goal/result panel, daily card, cabinet palettes, and a live finale with webs, coins and a larger spider. Render fixtures contain staged scores/unlocks; they do not alter the user's profile or establish human completion difficulty.
- Prepared playtest/MASTERY.md and extended the participant template. Time-star budgets are provisional; no human sessions or sustained device performance measurements were performed.
- Version 0.3.0+2 bundled web and ARM64 APK builds succeeded; APK is 16.8 MB. Live browser home and Cabinet were verified. The final live Daily-screen click was blocked by automatic approval review due to the account usage limit; Daily automated tests and actual Flutter renders passed. This APK was built, not installed on a device.

## Scattered Classic boards, level grid and spiders â€” 2026-09-08

- Replaced route-shaped Classic target layouts with deterministic scattered positions and non-monotonic target order across all 50 levels. Added a responsive numbered grid and extended saved selection/next-level progression to 50.
- Added levels 31â€“50 with one to three slow patrolling spiders, marked web territories, swept entry detection, persistent pursuit and instant run loss on physical contact. Capture/retry resets spiders; pause freezes them; Infinite and Practice remain separate.
- All 68 regression tests passed; static analysis reported no issues. New checks cover all 50 layouts, target clearance and connected paths around all 20 spider boards, patrol/chase/contact, swept crossings, replay/pause/capture isolation, and grid selection at widths 320, 430 and 800 with enlarged text.
- Actual Flutter phone renders inspected for scattered targets, the level grid, spider levels 31/50 and alert styling. Geometric clearance and simulated capture checks do not establish human completion difficulty; physical-device playtesting is still needed.
- Bundled web and ARM64 Android releases rebuilt successfully; APK is 16.8 MB. Restarted the local preview server and verified the new grid and spider chapter in the live browser. This build was not installed on a device.

## Scattered Infinite placement â€” 2026-09-08

- Removed left/right section templates and aligned hole rows. Each hole receives independent x/y placement with minimum separation and a narrower, more mobile reserved route. Recent placement history rejects a fourth consecutive placement on the same half.
- Preserved the user's tuning: speed 60â€“180, full difficulty at 900m, density 2â€“4, section spacing 120â€“140 down to 75â€“95, and first section at 300â€“320.
- All 60 tests passed. Updated route checks scan the two-dimensional field at 40 seeds/five difficulty stages; distribution checks cover 60 seeds/four stages, all three horizontal zones, both board halves and minimum separation. Actual phone render reviewed.
- Final static analysis is clean. Web and ARM64 APK releases rebuilt successfully (APK 16.8 MB); no device installation performed.

## Progression, 30 levels and control options â€” 2026-09-08

- Infinite uses a smooth height-based speed curve (38â€“180 world units/second), sparse early rows, randomized spacing and patterns, and a bounded wandering clear corridor. Special hazards unlock at 180 / 350 / 600 / 900m.
- Classic has 30 distinct authored target routes with increasing trap density, a level picker and next-level action. Scoring and three lives remain per board; Practice retains the original layout.
- Saved one-finger control uses a short vertical handle dragged horizontally. Classic lifts automatically and waits at the current target height. Both control methods use the same ball physics, with approximately 8% higher acceleration/speed cap.
- Touch input consumes the newest target on the next physics tick, preserves quick released swipes, and checks the first swept collision. Pause/control changes clear residual motor velocity.
- Automated checks cover all 30 boards' completion in both controls and geometric target reachability; 40 seeds at five Infinite difficulty stages; actual small-phone Settings and level-30 selection; simultaneous touch, one-finger fast drags, limits, pause, persistence and idle detection.
- Final full regression suite: 59 tests passed.
- Final static analysis: no issues. Bundled web release and ARM64 Android release built successfully; APK is 16.8 MB. This update was built, not installed on a device.
- Phone renders inspected for the level picker and the one-finger platform/handle. Human difficulty balance and physical-device touch latency remain unmeasured.

## Infinite hazards and first-launch tutorial â€” 2026-09-07

- Ascent now accelerates from 80 to 180 world units per second over 15 seconds. Blinking forming holes, moving holes, lasers, and temporary platform gaps unlock at scores 30, 70, 110, and 160, with warning time and one special hazard at a time.
- All 47 regression tests passed; static analysis reported no issues. Checks cover warning/live/expired collision boundaries, swept laser and moving-hole contact, gap lifetime, milestone scheduling, pause/replay isolation, and first-launch tutorial completion/skip persistence and replay.
- Actual Flutter renders verified the three-step tutorial and phone gameplay, including laser warning/live states, a forming-hole warning, and the open platform gap. The render script also exports all four hazard warning/live states. These are staged visual checks, not a human survival playthrough.
- Tutorial and game layout checks include small phones, safe-area insets, and preserved board proportions. Human difficulty and fairness still need playtesting at the new pace.
- Bundled web release and ARM64 Android release built successfully. Updated APK: `build/app/outputs/flutter-apk/app-release.apk` (16.4 MB). No new device installation is claimed.

## Latest: automatic-ascent Infinite

- Infinite now translates the platform and camera together so world holes approach from above while pivot grips hold their screen position. Pace increases from 34 to 62 world units per second over two minutes.
- All 33 regression tests passed. New checks cover automatic hole approach, held-grip alignment, collision without steering, pause, and the speed cap. Static analysis reported no issues.
- Red danger is now triggered by idle steering rather than lack of elevation. Automatic-ascent best scores use separate storage keys.
- Human enjoyment, difficulty, and retention are still unvalidated; the playtest should use this updated behavior.

Environment: Windows; project-local Flutter 3.47.2 / Dart 3.13.2.

- Static analysis: no issues found.
- Automated suite: 22 passing tests covering physics, sequential scoring, capture/return, classic/practice failure rules, completion/replay, pause, frame subdivision, geometric target reachability, three viewport sizes, simultaneous thumb controls, continuous Infinite scrolling, bounded procedural hazards, peak-height scoring, stall detection, fatal red-floor contact, and separate mode records.
- Actual Flutter render review: home, gameplay, and pause at 390 Ã— 844 logical pixels. Original icon assets generated for all iOS and web sizes.
- Release browser build: compiled with the renderer bundled locally.
- Live browser observation: game loaded, Material icons rendered, controls and tilted bar visible.

Not verified here: native iOS compilation/signing, iPhone audio/haptic feel, sustained device frame times, battery use, human completion difficulty, retention, purchases, advertising, or store submission.

## Android installation â€” 2026-09-06

- Final ARM64 release APK built successfully (16.4 MB) after the procedural hazard variation fix.
- Installed on the connected Samsung SM-X520: adb reported Success.
- Launched com.giltarcade.balance_arcade/.MainActivity: Android reported Status: ok, COLD launch, TotalTime 434 ms.
- Optional follow-up process query was blocked by automatic approval review due to the account usage limit; no sustained on-device gameplay verification is claimed.
- Final procedural layout simulation reached 999.5 m, retained bounded hazards, and verified sampled fixed vertical lanes encounter hazards. This check ran after the last generator change; the 22-test suite passed before that variation.
- Updated web release compiled successfully. Live browser review confirmed Infinite height scoring HUD, unnumbered trap holes, and independent bottom controls.
## Direct pivot dragging and expanded gameplay â€” 2026-09-06

- Replaced bottom rockers with independent pointer-owned platform grips. Release/cancel holds the pivot; pause and transitions invalidate active grabs. Fixed-step following retains swept trap collision checks.
- Gameplay fills safe-area width and remaining height below a compact HUD, including tablets.
- 25 regression tests passed, including fast-swipe trap capture, scrolling re-grab, two-pointer release/cancel, three phone sizes, and tablet safe-area bounds. Flutter analysis: no issues.
- Android ARM64 release and bundled web release built successfully. Actual Flutter render inspected at 390 x 844 with 44 top / 34 bottom safe-area insets (artifacts/drag-game.png).
- Android update installation could not proceed: previously connected device was not found. The earlier installed version remains on the tablet.
- Live browser verification was unavailable after a connection error; browser tooling blocked navigation from its generated error page. The updated web build is on disk.
## Proportional board fix â€” 2026-09-06

- Replaced independent axis scaling with a centered uniform fit transform shared by the painter and pivot hit testing. Board, ball, holes and labels retain their proportions in wide and tall windows.
- 29 regression tests passed, including four aspect-ratio cases and two-pointer dragging through the shared coordinate transform.
- Inspected actual Flutter renders for 1130 x 900 desktop and phone safe-area layouts. Proportions are preserved with surrounding space when needed.

## Vertical analog controls — 2026-09-09

- Added persisted third control mode with two bottom vertical-only joysticks, proportional independent motors, dead zone, immediate neutral on release/cancel, and stale-pointer invalidation after input resets.
- Flutter analysis clean; all 88 regression tests pass, including simultaneous analog fingers, ignored horizontal displacement, extra-finger ownership, release/cancel, motor proportionality, and preference migration.
- Actual Flutter renders inspected at 390 x 844 and 320 x 568 with 44 top / 34 bottom safe-area insets. Controls fit below the uniformly scaled board. Images: artifacts/analog-phone.png and artifacts/analog-small-phone.png.
- Release web and Android ARM64 APK 0.3.1+3 built successfully; local preview responds HTTP 200. APK was rebuilt, not installed on a device during this change.

## Analog response — 2026-09-09
- Removed analog motor easing for full next-tick response, including reversals, and reduced joystick dead zone from 8% to 2%. Proportional speed and release stopping remain.
- All 89 tests passed; analysis clean. New regression checks first-tick displacement, reversal and release at 120 Hz. This verifies simulation response, not measured device input-to-display latency.

## Direct analog dragging — 2026-09-09
- Supersedes speed-based analog control: vertical pointer displacement now feeds the existing swept-collision pivot target path directly. No dead zone, easing or held-deflection motor movement. Release holds the platform and resets the knob; re-grabbing continues movement.
- Analog drag sensitivity is 180 world units per joystick travel distance, with horizontal input ignored. Infinite inactivity now depends on movement rather than holding a deflected knob.
- All 88 tests pass; analysis clean. Tests verify one-pixel touch displacement reaches its target in one tick, no drift while held, and release before the next tick preserves the final movement.

## Infinite hard encounters — 2026-09-09
- Added alternating sweeping-laser and descending-zigzag variants in encounter sections from 1,200 points. Existing early hazard schedule and Classic finales retain their original variants.
- All 91 tests pass, including relative moving-laser collision, harmless warning periods, descending/reversing zigzag motion, bounded horizontal movement, and section-gated alternating scheduling.

## 2048 / Merge — 2026-09-09

- Added an independent 2048 mode, descending numbered color orbs, a six-slot stack, chronological swept pickup collision, recursive top merges, accumulated merge score, full-stack rescue/overflow, and a 2048 win with same-run continuation.
- Every spawned row includes a match for the current stack top. The stream remains bounded; missed orbs do not penalize the player. All three controls remain available, with no holes, spiders, lasers, idle death or Classic stars in this mode.
- Local best score, highest number and run count persist independently. Winning then continuing updates the best without counting a second run.
- Full 100-test suite passed. The nine merge tests passed again after correcting chain score feedback. Static analysis clean before that final score-label adjustment.
- Actual Flutter renders inspected at 390 x 844 and 320 x 568 with top/bottom safe-area insets. Intro play button stays fixed; compact win panel exposes Continue; full stack uses red borders; orb labels and useful-match rings are legible. Screens: artifacts/merge-phone.png, merge-small-phone.png, merge-full-stack.png, merge-guide.png, merge-win-small.png.
- Human playtesting is still needed to tune pacing and challenge; no long-session enjoyment or retention claim is established by these automated checks.
- Web release and Android ARM64 APK 0.4.0+4 built successfully. The APK was rebuilt, not installed during this change.

## 2048 platform snake — 2026-09-09

- Replaced the six-slot tray with a connected snake on the platform. The solid head keeps its number when a different pickup attaches as a 38%-opacity body segment. Collecting the tail number preserves recursive merges and score; 4 + 2 forms [4, 2], then another 2 collapses it to [8]. Ghost segments do not collect falling orbs.
- Snake spacing and ball size determine capacity from the 320-unit platform: currently 12 balls. The whole chain follows the platform tilt and fits within its ends; a longer chain reduces the head's travel range. Matches resolve before measuring overflow, so a full snake can still be rescued. New rows put a tail match in the head's remaining horizontal range.
- Added a compact length/match label, an orange platform warning near capacity, updated instructions, and a Snake too long result. Win/continue and independent saved records retain their behavior.
- All 107 regression tests and the Flutter render test passed (108 total); static analysis found no issues. Checks include the requested 4/2 example, recursive rescue, physical capacity, ghost pickup isolation, reachable match spawning, all three controls, pause, persistence, continuation and small-phone loss UI.
- Actual Flutter renders reviewed at 390 x 844 and 320 x 568 with safe-area insets. Images include artifacts/merge-snake-phone.png, merge-snake-example.png, merge-snake-full.png, merge-snake-small-phone.png and merge-snake-loss.png. Fixtures stage snake values for visual inspection; no human balance or device performance claim is made.
- Release web and Android ARM64 APK 0.4.1+5 built successfully. The local preview serves the updated version at http://127.0.0.1:8080/. APK size is 18.7 MB; this build was not installed on a device. Android packaging completed despite local SDK symbol-stripping warnings.

## Centered endless merge and falling holes — 2026-09-09

- The largest value stays in the middle of the snake, with sorted smaller values on both sides and the smallest at an outer end. The exact layout 2, 16, 32, 8, 4 collapses to 64 when another 2 is collected. Matching values combine anywhere in the snake, including across sides, before checking the unchanged 12-ball platform capacity.
- Added two falling holes per three number balls. Waves keep objects separated and reserve a reachable matching lane through the holes. Only the solid middle ball collects food or falls into a hole; translucent segments remain visual. Both streams pause, resume and reset together, and swept collisions resolve pickups/holes chronologically with hole priority on simultaneous contact.
- Removed the 2048 win state and both continuation button paths. Reaching 2048 and later values never pauses simulation, resets controls, or ends the run. Number labels use binary units: 1024 = 1k, 2048 = 2k, 1,048,576 = 1m, with the exact values retained for merging and scoring. Results and highest-value labels use the same formatter.
- All 111 regression tests and the render test passed (112 total); static analysis found no issues. Coverage includes the exact requested layout/cascade, centered positions for every valid length, unchanged overflow and rescue, merges across sides, three controls, hazard/food ordering, spawn ratio and clear lanes over 40 seeds, continuous input at 2048, compact labels, and local records on final loss.
- Flutter phone renders reviewed at 390 x 844 and 320 x 568. Staged screenshots include merge-centered-phone.png, merge-centered-64.png, merge-2k-running.png, merge-millions.png, merge-centered-small.png, merge-centered-overflow.png and merge-hole-loss.png under artifacts/. These checks do not measure real-device difficulty or performance.
- Web release and Android ARM64 APK 0.4.2+6 built successfully. The preview serves version 0.4.2 at http://127.0.0.1:8080/. APK size is 18.7 MB; it was rebuilt, not installed. Android packaging completed with the existing local SDK symbol-stripping warnings.

## Laser Maze routes — 2026-09-09

- Added a separate Laser Maze mode with ten named, progressively narrower routes, red laser walls, a dark winding road, direction arrows, a safe launch area, a checkered finish and miniature route previews. The home screen opens a route picker; all routes are available.
- Swept circle/capsule collisions include the ball radius, beam thickness and rounded wall corners. Fast swipes cannot jump through the maze, and finish/wall events resolve in contact order. Laser contact ends the one-ball run; reaching the finish wins. Only the ball collides, so the platform may cross the walls.
- Retained two-finger, analog and keyboard handling. One-finger mode supplies a 14-unit/second automatic climb. Pause freezes active time and progress; replay resets the route. Peak progress cannot be farmed by descending. The new mode has no other hazards or Classic rewards.
- Added retry/next/all-routes actions and independent local selected-route, attempt and per-route/per-control best-time records. Classic and Merge records remain separate. Corrected the home subtitle wrapping at enlarged text sizes.
- All 125 regression tests plus the maze render test passed (126 total). New tests cover all ten centerline routes with ball clearance, wall thickness/corners, fast shortcuts, finish ordering, progress, all three controls, pause/replay, persistence and small/enlarged-text picker/finish/retry flows.
- Actual Flutter renders reviewed for routes 1 and 10, the route picker and finish screen at 390 x 844, plus 320 x 568 safe-area views. Outputs are artifacts/maze-picker.png, maze-route-1.png, maze-route-10.png, maze-small-phone.png, maze-finish.png and maze-laser-contact.png. Route clearance checks do not establish comfortable human difficulty or real-device performance.
- Final visual check also freezes both the ball and the platform at the first wall/finish contact during fast swipes. The full 125-test suite and render check passed again after this correction.


## Endless coins, moving territories and merge gates — 2026-09-10

- Infinite and Laser Endless generate random coins ahead in world coordinates, retain a separate run coin count, and prune old collectibles. Spawn checks keep coins clear of static holes, laser beams and spider patrol origins; collecting coins does not inflate metre records.
- Laser Endless adds small spiders with moving circular territories. Patrol and pursuit keep the circle clear of beams, moving-zone contact starts a chase, body contact ends the run, and pause freezes the simulation.
- One-finger handle input supports horizontal tilt and vertical lift/lowering in the same drag. Holding pauses the Classic/Maze automatic lift; release resumes it. Infinite keeps its continuous ascent. Pending input is cleared on pause, mode change and restart.
- Merge removes holes and capacity loss. Each wave includes two safe numbers and one larger number to dodge. Equal or smaller values can be collected; touching a value larger than the current main ball ends the run. Long snakes compress their spacing.
- Every 400 score queues a descending horizontal gate. The main ball must be strictly greater than the gate value. Requirements grow with score (64 at 400, 128 at 800, 256 at 1200, 4096 at 16400); one gate is active at a time. Swept collision resolves pickups and gate checks in chronological order.
- All 148 regression tests passed. Final merge and both render checks passed (26 checks), and static analysis found no issues. Coverage includes random placement, bounded generation, moving zone/beam clearance, strict gate equality, queued milestones, larger-number losses, pause/replay, touch ownership and vertical movement, records, and phone layouts.
- Corrected existing maze test assumptions: each route has its turn count plus two vertical legs, virtualized picker cards must scroll into hit-testable view, and the result label finder must be scoped to the result widget.
- Real Flutter screenshots reviewed: artifacts/merge-centered-phone.png, merge-gate-loss.png, maze-endless-one-finger.png, and infinite-random-coins.png. Enlarged moving circles and the coin counter badge remain legible on the road.
- Web release and universal Android APK 0.5.1+8 built successfully. APK: build/app/outputs/flutter-apk/app-release.apk. No device installation was performed. Human playtesting is still needed to assess gate pacing and spider difficulty.

## Branching Laser Maze and fair bug zones — 2026-09-10

- Rebuilt the ten fixed routes with downward sections, returning bends, long horizontal crossings, loops, and narrow shortcuts that reconnect with longer wide detours. Gold arrows identify shortcuts. Progress agrees at branch junctions; swept ball/wall collision and finish ordering remain active.
- Endless generation combines six structural families with randomized graph routes, entry/exit lanes, spacing and branch connections. A shuffle bag avoids consecutive families; recent exact structures are rejected. Bounded route search has a connected fallback. Corridor widths narrow gradually, and complete modules are pruned together so returning sections remain connected.
- The endless camera follows downward returns while preserving peak-height scoring. Automated checks cover more than 400 generated modules across 24 seeds, every primary/shortcut centerline's ball clearance, valid wall outlines, branch reconnection, required downward movement and bounded retained geometry.
- Bugs now patrol on land outside every road. Their moving zones warn in amber for two seconds before a short red catching phase; the overlapping road area is highlighted. Zone placement reserves a ball-sized safe passage along every road centerline. Idle, warning and retracting zones are harmless; catching requires both an active road overlap and player contact. Checks cover patrol clearance across 16 seeds and active/warning/retraction collisions.
- Every Laser Maze start and retry uses Two-Finger Control. The saved normal-mode preference is retained and restored outside the maze; records use the actual maze control. Normal Infinite starts at 68 instead of 60 world units/second while retaining its rising curve and 180 maximum. Vertical analog has about 19% less drag sensitivity and a 35 ms smoothing response; release settles to the target and pause clears pending movement.
- All 151 regression tests and the maze render test passed; static analysis found no issues. Rendered Flutter screens reviewed at 390 x 844 and 320 x 568 with safe-area insets include artifacts/maze-route-1.png, maze-structure-5.png, maze-structure-6.png, maze-small-phone.png, maze-bug-warning.png and maze-bug-active.png.
- Geometry and simulation checks establish the tested clearance and state behavior; human phone playtesting is still needed to assess comfort, pacing and device performance.
- Release web and universal Android APK 0.6.0+9 built successfully. Android packaging required project-local Android settings after the default directory was inaccessible, and completed with the existing SDK symbol-stripping warnings. APK metadata confirms version code 9; signature verification passed and the certificate matches the preceding APK. APK: build/app/outputs/flutter-apk/app-release.apk (52.3 MB). No device installation was performed.

## Direct controls without added delay — 2026-09-11

- Removed the 35 ms vertical-joystick smoothing and release settling. All touch controls now consume their full target movement on the next 120 Hz physics tick through the existing swept collision path. Regular Two-Finger grips already used direct targets; reduced joystick sensitivity remains.
- All 152 regression tests passed and static analysis found no issues. Tests explicitly verify both grips/joysticks, movement on the first tick, direction reversal, release before a tick, no subsequent drift and pause cancellation.
- Investigated Infinite coins: coinsCollected resets on each new run, and PlayerProfile has no stored coin balance. This is a per-run counter, unrelated to account connectivity. Coin storage and account behavior were left unchanged.
- Release web and universal Android APK 0.6.1+10 built successfully. Android settings now use only ANDROID_USER_HOME for this build, resolving conflicting preferences paths. Existing SDK symbol-stripping and metrics warnings were nonfatal. APK version code 10 and its unchanged signing certificate were verified. No device installation or device latency measurement was performed.

## Expert towers and moving-ball glow — 2026-09-11

- Added routes 11–20, bringing Laser Maze to 20 levels. Expert routes combine three to seven connected maze sections with repeated descents, long crossings and split/rejoining shortcuts. Main corridor half-widths decrease from 19 to 14.5; shortcut half-widths decrease from 13 to 11.65. The ball radius remains 7 and the laser radius 2. The original ten layouts remain intact.
- Tall routes use world coordinates and their own finish line. The camera follows upward movement and downward returns, then stops at the summit with the finish near the top of the board. Level selection, next-route progression and saved completion times support all 20 routes. Expert preview diagrams show the full route with consistent line widths. Offscreen road and wall drawing is culled.
- Added a bounded 0.2-second ball wake and a soft teal-to-gold glow based on movement. Visual brightness decays briefly between display frames; it never drives physics or control targets. The wake freezes on pause, fades after stopping and clears on restart. Reduced-motion mode omits the wake.
- Full 156-test regression suite passed, including swept centerline completion of all 20 levels, expert shortcut clearance, camera returns, true finish height, expert profile persistence and no accidental endless coins or enemies in fixed towers. The final nine focused control, motion and render checks passed after refining visual decay. Static analysis found no issues.
- Reviewed actual Flutter renders of expert starts, mid-climb views, summit finish lines and the expert picker. Examples: artifacts/maze-expert-20-climb.png, maze-expert-20-summit.png and maze-expert-picker.png. Human phone playtesting remains necessary to tune expert difficulty and assess device performance.
- The final render check also enters route 20 through the actual picker at 320 x 568; the level starts correctly without a stale result overlay. Screenshot: artifacts/maze-expert-small-phone.png. The render test passed again after correcting its direct-start fixture.
- Release web and universal Android APK 0.7.0+11 built successfully. APK metadata and signature were verified, with the same certificate as the preceding release. APK: build/app/outputs/flutter-apk/app-release.apk (52.4 MB). The existing SDK symbol-stripping and metrics warnings remained nonfatal. No device installation was performed.

## Infinite progression and maze editor — 2026-09-14

- Version 0.9.0+13 combines the editor and Infinite expansion. All 183 regression tests pass after the final control changes; Flutter analysis reports no issues.
- Infinite checks cover three separate life losses, same-run safe recovery, cleared controls and landing space, recovery protection, final game over and retry. Shields block holes, all four special-hazard types and the rising floor; active timers freeze during pause. Swept contacts verify shields collected before and after static and moving hazards, preventing retroactive protection.
- Combo tests cover increasing awards, the x5 cap, one-time collection, missed items, life-loss resets, full-health heart bonuses, smooth/capped pace, experienced starting levels and separation of hazard milestones from bonus points. Sampled long runs verify bounded pickup storage, hole clearance, rarity and conditional heart spawning.
- Economy tests cover idempotent coin deposits, consecutive runs, permanent ownership, equip without charging twice, rejected unaffordable items, persistence across profile reload, malformed saves and invariant physics across all seven ball designs. Local wallet transactions are serialized; no account or server is connected.
- Laser Maze now uses the selected control mode. Immediate upward motion, downward reversal and release holding are checked for Vertical Analog in both normal and endless mazes. Authored-level playtests also use the saved controls; the small-phone workflow checks actual analog controls in the isolated editor run.
- Editor checks cover JSON round trips, unfinished drafts, invalid topology/width/finish rejection, swept completion of short and tall branched maps, undo/redo, command handling, drawing, draft saving, export and playtest without recording a score. Exported Dart was compiled in a copied registry, appeared as route 21 and completed with swept collision enabled.
- Actual Flutter renders were inspected at 320×568 and 390×844: Infinite x5 with shield and pickups, the Ball Shop, editor canvas, export sheet and playtest. The editor playtest action row was changed to wrap on small screens. Renders and logs are in `artifacts/`; regenerate with `tool/render_expansion.dart`.
- Visual effects are bounded (24 procedural background marks, ten short collection sparks, 24 motion samples and a capped pickup list). Reduced motion disables moving streaks and bursts. Real-device sustained frame timing, battery, audio/haptics and human difficulty balancing have not been measured in this pass.
- Final Android universal APK and bundled web release both built successfully after the editor control adjustment. APK metadata verifies `com.giltarcade.balance_arcade`, version `0.9.0`, build `13`, with ARM64, ARMv7 and x86-64 libraries. Signature verification passed and matches the existing development certificate. Nonfatal Android SDK strip/objcopy and metrics warnings remain; no device installation is claimed.
- Release artifact: `artifacts/gilt-0.9.0-infinite-editor.apk` (61,203,540 bytes), SHA-256 `6e45ee55103271acc4033019249b43a9680a357075cf10f2f731b480b46b4ee5`. Web output is `build/web` with version metadata 0.9.0+13.

## Course continuity, gear and control refinements — 2026-09-14

- Version 0.10.0+14: all 202 regression tests pass after the final changes. Existing Classic, 2048, Laser Maze, Infinite, economy and editor coverage remains in the suite.
- Recovery now preserves generated hole identities, world positions and order, active warning objects, camera progression and generator state. A nearby safe landing is searched without deleting the course. Recovery protection remains 2.5 seconds.
- Forming holes retain fixed world coordinates after opening, including large camera changes caused by manually lifting the platform. They remain until they scroll off-screen. Static holes, newly opened holes and pickups are pruned only after swept contact resolution; dedicated fast-camera-lift tests prevent collision tunneling.
- Density increases smoothly with displayed points and reaches its dense setting at 20,000. Forty-seed comparisons verify the sparse opening, denser middle and late layouts, and sparse restart after a high score. Existing clearance and scattered-layout tests also pass with point-based density.
- Eleven balls and six platforms have displayed additive gear bonuses. Gear multiplies Normal Infinite distance and combo points; tests verify rewards, unchanged motion, permanent platform purchases, rejected unaffordable purchases, and migration of existing ball ownership without a second charge.
- Both Vertical Analog and Two-Finger controls have independently saved 0–1 sensitivity. Tests cover zero movement, quarter/half/full movement, next-tick response, release holding and preference persistence. Maze editor playtests inherit sensitivity as well as control mode. Keyboard handling is unchanged.
- Settings now use selectable illustrated cards with looping movement demonstrations. Actual Flutter renders at 320×568 and 390×844 cover the cards, sensitivity controls, shop tabs, sparse Infinite opening, full-screen x3/x5 background colors and successive flame frames. Reduced motion keeps static colors/glow without moving bands, flames or particles.
- Visual effects remain bounded: three broad animated light bands, up to 24 background streaks, 20 paired flame tongues and ten procedural embers. No particle objects accumulate. Sustained performance and gameplay balance still need human testing on a physical phone.

- Final static analysis reports no issues. Android universal APK and bundled web release both built successfully as 0.10.0+14. APK metadata and signing verification passed; the signing certificate matches the preceding release. Existing Android SDK symbol-stripping and metrics warnings were nonfatal. No device installation was performed.
- Main APK: `build/app/outputs/flutter-apk/app-release.apk`; identical archive: `artifacts/gilt-0.10.0-gear-controls.apk` (61,449,808 bytes). SHA-256: `2c03cd89ead5d33afd0243f36a2dd54d202758de40dfaf62ee25e0aa71fb261f`. Web output is `build/web`, with verified version metadata 0.10.0+14.
