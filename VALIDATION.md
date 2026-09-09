# Validation record

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
