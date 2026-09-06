# Validation record

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
