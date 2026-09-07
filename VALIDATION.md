# Validation record

## Scattered Infinite placement — 2026-09-08

- Removed left/right section templates and aligned hole rows. Each hole receives independent x/y placement with minimum separation and a narrower, more mobile reserved route. Recent placement history rejects a fourth consecutive placement on the same half.
- Preserved the user's tuning: speed 60–180, full difficulty at 900m, density 2–4, section spacing 120–140 down to 75–95, and first section at 300–320.
- All 60 tests passed. Updated route checks scan the two-dimensional field at 40 seeds/five difficulty stages; distribution checks cover 60 seeds/four stages, all three horizontal zones, both board halves and minimum separation. Actual phone render reviewed.
- Final static analysis is clean. Web and ARM64 APK releases rebuilt successfully (APK 16.8 MB); no device installation performed.

## Progression, 30 levels and control options — 2026-09-08

- Infinite uses a smooth height-based speed curve (38–180 world units/second), sparse early rows, randomized spacing and patterns, and a bounded wandering clear corridor. Special hazards unlock at 180 / 350 / 600 / 900m.
- Classic has 30 distinct authored target routes with increasing trap density, a level picker and next-level action. Scoring and three lives remain per board; Practice retains the original layout.
- Saved one-finger control uses a short vertical handle dragged horizontally. Classic lifts automatically and waits at the current target height. Both control methods use the same ball physics, with approximately 8% higher acceleration/speed cap.
- Touch input consumes the newest target on the next physics tick, preserves quick released swipes, and checks the first swept collision. Pause/control changes clear residual motor velocity.
- Automated checks cover all 30 boards' completion in both controls and geometric target reachability; 40 seeds at five Infinite difficulty stages; actual small-phone Settings and level-30 selection; simultaneous touch, one-finger fast drags, limits, pause, persistence and idle detection.
- Final full regression suite: 59 tests passed.
- Final static analysis: no issues. Bundled web release and ARM64 Android release built successfully; APK is 16.8 MB. This update was built, not installed on a device.
- Phone renders inspected for the level picker and the one-finger platform/handle. Human difficulty balance and physical-device touch latency remain unmeasured.

## Infinite hazards and first-launch tutorial — 2026-09-07

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
- Actual Flutter render review: home, gameplay, and pause at 390 × 844 logical pixels. Original icon assets generated for all iOS and web sizes.
- Release browser build: compiled with the renderer bundled locally.
- Live browser observation: game loaded, Material icons rendered, controls and tilted bar visible.

Not verified here: native iOS compilation/signing, iPhone audio/haptic feel, sustained device frame times, battery use, human completion difficulty, retention, purchases, advertising, or store submission.

## Android installation — 2026-09-06

- Final ARM64 release APK built successfully (16.4 MB) after the procedural hazard variation fix.
- Installed on the connected Samsung SM-X520: adb reported Success.
- Launched com.giltarcade.balance_arcade/.MainActivity: Android reported Status: ok, COLD launch, TotalTime 434 ms.
- Optional follow-up process query was blocked by automatic approval review due to the account usage limit; no sustained on-device gameplay verification is claimed.
- Final procedural layout simulation reached 999.5 m, retained bounded hazards, and verified sampled fixed vertical lanes encounter hazards. This check ran after the last generator change; the 22-test suite passed before that variation.
- Updated web release compiled successfully. Live browser review confirmed Infinite height scoring HUD, unnumbered trap holes, and independent bottom controls.
## Direct pivot dragging and expanded gameplay — 2026-09-06

- Replaced bottom rockers with independent pointer-owned platform grips. Release/cancel holds the pivot; pause and transitions invalidate active grabs. Fixed-step following retains swept trap collision checks.
- Gameplay fills safe-area width and remaining height below a compact HUD, including tablets.
- 25 regression tests passed, including fast-swipe trap capture, scrolling re-grab, two-pointer release/cancel, three phone sizes, and tablet safe-area bounds. Flutter analysis: no issues.
- Android ARM64 release and bundled web release built successfully. Actual Flutter render inspected at 390 x 844 with 44 top / 34 bottom safe-area insets (artifacts/drag-game.png).
- Android update installation could not proceed: previously connected device was not found. The earlier installed version remains on the tablet.
- Live browser verification was unavailable after a connection error; browser tooling blocked navigation from its generated error page. The updated web build is on disk.
## Proportional board fix — 2026-09-06

- Replaced independent axis scaling with a centered uniform fit transform shared by the painter and pivot hit testing. Board, ball, holes and labels retain their proportions in wide and tall windows.
- 29 regression tests passed, including four aspect-ratio cases and two-pointer dragging through the shared coordinate transform.
- Inspected actual Flutter renders for 1130 x 900 desktop and phone safe-area layouts. Proportions are preserved with surrounding space when needed.
