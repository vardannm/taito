# GILT â€” Precision Arcade

A Flutter game built around the mechanical ball-and-bar challenge: two independently controlled ends, a rolling steel ball, ten numbered targets, and three chances. GILT is the current working title.

## Play on this Windows computer

Open this folder in VS Code, select **GILT â€¢ Browser preview**, and press F5. A project-local Flutter SDK is installed in `.tools/flutter` and selected in `.vscode/settings.json`.

Alternatively:

```powershell
.\scripts\flutter.ps1 run -d chrome
```

Controls: drag the left or right grip on the platform up and down. Both fingers work independently; release to hold that pivot. In Infinite, release and grab again for another upward swipe. The playfield scales uniformly to the largest size that fits below the compact HUD inside the device safe area. Extra space surrounds the board when the viewport has a different aspect ratio; holes and the ball remain circular. On desktop use **W/S** for the left end, **Up/Down** for the right, and **Esc** to pause.

Settings offers saved **Two-Finger Control** (default), **One-Finger Control**, and **Vertical Analog Control**. Vertical analog places two independent joysticks at the bottom inside the safe area. Drag up to raise that platform end, down to lower it; the platform follows the vertical drag directly without motor easing or a dead zone. Horizontal movement is ignored. Release centers the knob while holding the platform; grab again to continue moving. One finger drags a short vertical handle horizontally under the platform; its bounded position sets the tilt directly. Classic automatically lifts at 20 world units/second and waits at the current target height, so a target cannot be left behind. All three modes share ball physics. Touch targets are consumed on the next 120 Hz physics tick without a catch-up speed cap; keyboard motor easing remains. Ball acceleration and its speed cap increased by about 8%.

Choose Classic to open a responsive grid of 50 named levels. Each board retains ten targets, three lives and the existing scoring. Winning offers **NEXT LEVEL**; the selected level is remembered. Deterministic scattered layouts vary target positions, heights, and numbering so targets no longer follow a single route. Trap density increases through the original 30 boards. Practice retains its original board and unlimited attempts.

Levels 31â€“50 form **The web**: one slow patrolling spider at first, two from level 36, and three from level 43. Dashed circles and background webs mark their territories. Crossing a boundary starts a persistent chase; physical contact instantly ends the run and removes the ball, without an eating animation. Territories and spiders turn red during pursuit. Capturing a target or losing a ball to a hole resets the spiders; pause freezes them. Territory placement keeps target holes clear and checks connected space from the launch area to every target. Human difficulty still needs playtesting.

## Mastery, daily boards and cabinet styles

Classic and Daily award three independent stars: finish, finish without a miss, and finish within the displayed active-time target. Earned objectives merge across retries. Each board saves its best score, fastest successful time, and attempt count separately for each of the three control modes. The grid shows these records; the result screen explains each star and offers a retry of the same board alongside next-level progression.

Active time excludes pauses, capture animations, and the bar returning to launch. Initial time targets use board elevation, the control mode's lift speed, trap count and a finale/spider allowance. They are provisional until human playtesting; adjust the `targetTime` calculation in `BalanceGame.start` in `lib/game.dart`.

Optional brass coins sit beside traps in Classic and Daily, clear of hole centers and spider territories. Each adds 250 points, can be collected once per run, and stays collected across ball resets. Collectibles are optional and do not change the three star objectives. Infinite still scores height only; Practice has no collectibles or progression rewards.

Every tenth Classic board is a finale. Level 10 introduces a warned laser lane; level 20 a warned roaming hole; level 30 alternates them; level 40 has a larger spider keeper; level 50 combines the keeper with laser lanes. A briefing pauses the simulation until the player starts. Finale lasers/roaming holes cost one ball, while spider contact ends the run. Laser and roaming-hole warnings last 2.4 seconds, and hazards reset between target attempts.

**Daily** uses a fixed board generated from the UTC date with an explicit integer random generator, consistent across web and native platforms. The date is pinned for an ongoing run and its retry, even across midnight; opening Daily again selects the current day. Records are local and separate from Classic, with 32 days of history retained for all three controls. No online leaderboard or account service is connected.

**Cabinet** offers Original brass plus Jade garden (3 Classic stars), Porcelain club (12), and Ember forge (30). Each style changes the cabinet finish, ball and platform colors with identical physics and hitboxes. Stars earned with either control count toward each board's three unlock stars; Daily stars do not unlock Classic cosmetics. The equipped style persists. Existing global records and preferences are retained.

## What is implemented

- Original ivory, brass, and deep-teal art direction; procedural engraved playfield and original app icons.
- Fixed 120 Hz physics with rolling-sphere acceleration, motor smoothing, inertia, speed limits, and swept hole collision detection.
- Ten targets in sequence. Each capture animates the ball sinking and the bar returning to the launch position.
- Three-ball Classic; an endless Infinite climb; and unlimited-attempt Practice with slower motors and slightly more forgiving target capture.
- Streak multipliers up to 4Ã— and speed bonuses. Time rewards precision without ending slow runs.
- Original synthesized audio, optional haptics, separate persistent Classic/Infinite records and run counts.
- Tutorial, settings, pause, replay, lifecycle pause, input cancellation, and reduced-motion support for board effects.
- iOS project with portrait orientation and GILT branding; web build support with bundled renderer assets.

Scoring: `(target number Ã— 100 + max(0, 35 âˆ’ climb seconds) Ã— 10) Ã— multiplier`, rounded to integer points. Multiplier increases every three consecutive targets. Misses reset the streak. Practice scores are excluded from the classic record.

## Infinite mode

Choose **INFINITE** on the home screen. The platform automatically ascends while holes move down toward it. There are no numbered targets or resets: every hole is a trap. Current tuning starts ascent at 60 world units/second and reaches 180 at 900m. The base density grows from two to four holes per generation section, with base spacing of 120â€“140 units initially and 75â€“95 later. Each 180m cycle has a 90m rush (1.15Ã— density, capped at four), a 30m breathing stretch (.55Ã— density, 1.3Ã— spacing), and a 60m encounter stretch (.85Ã— density with shorter special-hazard intervals). New special hazards are suppressed during breathing stretches; an already-warned hazard finishes normally. Speed always follows the existing rising curve. Holes are scattered independently across both axes rather than aligned into rows or left/right pairs. Minimum separation prevents overlap, a winding clear route preserves space to steer, and recent placement history breaks long one-sided streaks. Offscreen holes are discarded.

Special hazards unlock later: forming holes at 180m, moving holes at 350m, lasers at 600m, and platform gaps at 900m. Their positions and selection vary, with at most one special hazard at once and gradually shorter recovery intervals. Red warnings last two seconds (2.4 for cuts); warnings are harmless. Lasers fire for 1.4 seconds, gaps repair after 2.5 seconds, and special holes live long enough to approach the platform at the current pace. Reduced-motion mode keeps warnings steady.

First launch shows a short three-step animated tutorial covering the grips, Classic targets, and Infinite survival. Completing or skipping it is remembered on the device; it can be replayed from How to Play.

Score is your highest elevation (one point per ten world units, displayed as meters), including automatic ascent. Going down and back up cannot earn the same height twice. After three seconds without steering, the red floor starts rising. Moving the pivot targets by eight accumulated world units or using keyboard steering stops its active rise; the floor never retreats on screen. A trap or contact with red ends the run. Pausing freezes ascent, simulation, scoring and the danger timer.

Infinite height records are separate from Classic scores. The automatic-ascent variant uses its own record keys so scores from previous manual-climb and round-based versions are not mixed with this different challenge.

## Android build and installation

The project-local Android SDK is in `.tools/android-sdk`. The Flutter wrapper selects it automatically. Enable USB debugging and authorize the connected computer on the phone, then run:

```powershell
.\scripts\flutter.ps1 build apk --release
.\scripts\flutter.ps1 install -d YOUR_DEVICE_ID
```

The APK is generated at `build/app/outputs/flutter-apk/app-release.apk`. This device-test build uses the generated development signing key, not a Play Store release key. Android has the GILT display name, original vector launcher icon, matching splash colors, and portrait orientation.

## Validate and build

```powershell
.\scripts\flutter.ps1 analyze --no-pub
.\scripts\flutter.ps1 test --no-pub
.\scripts\flutter.ps1 build web --release --no-pub --no-web-resources-cdn
```

The release preview is in `build/web`. Serve it over HTTP, for example:

```powershell
python -m http.server 8080 --bind 127.0.0.1 --directory build/web
```

Then visit http://127.0.0.1:8080. Use a phone-shaped window, or F5 for development with hot reload.

`tool/render_preview.dart` exports real Flutter screen renders to `artifacts/` and generates each native icon directly from vector drawing commands. Run it with `flutter test tool/render_preview.dart`. `scripts/generate_audio.py` regenerates the original sound cues.

## iPhone build

Use a Mac with Flutter and Xcode. The `.tools` SDK in this Windows workspace is Windows-specific; use your Mac's Flutter SDK and update/remove the local SDK selection in `.vscode/settings.json`. Run `flutter pub get`, open `ios/Runner.xcworkspace`, select your signing team and a bundle identifier you own, then run on an iPhone or simulator. The generated identifier is a development placeholder.

Native iOS compilation, signing, real-device haptics/audio, and frame-time profiling require that Mac/iPhone pass. They have not been verified on this Windows machine.

## Commercial status

This is a playable, tested game build, not an App Store submission or a revenue guarantee. No ads, purchases, tracking SDKs, servers, or paid services are connected. See `PRODUCT.md` for the proposed release and monetization sequence. No Taito artwork, branding, recordings, or game code is used.

## Code map

- `lib/game.dart`: independent simulation and run state.
- `lib/levels.dart`: 50 scattered Classic boards, spider territory placement, and route clearance checks.
- `lib/level_picker.dart`: responsive numbered level grid.
- `lib/spiders.dart` and `lib/spider_painter.dart`: patrol, swept territory/contact detection, pursuit, and web visuals.
- `lib/board_painter.dart`: procedural board, ball, and capture effects.
- `lib/hazards.dart` and `lib/hazard_painter.dart`: timed Infinite traps, swept collision, and warning visuals.
- `lib/tutorial.dart`: first-launch illustrated tutorial.
- `lib/main.dart`: responsive screens, tutorial, keyboard/touch controls, and lifecycle.
- `lib/profile.dart`: persistent per-board/per-control records, daily history, cosmetic unlocks, settings, sound, and haptics.
- `lib/rewards.dart`: star records, stable daily seed, Infinite section tuning, and cosmetic thresholds.
- `lib/mastery_widgets.dart` and `lib/cabinet.dart`: result goals, Daily/Cabinet screens, finale briefing, and cosmetic palettes.
- `test/`: progression, rewards, daily determinism, hazard timing, physics, reachability, small-screen, and multitouch checks.
- `tool/render_mastery.dart`: exports actual Flutter renders for the new reward, daily, finale and cabinet screens.
- `playtest/MASTERY.md`: a 5â€“10 player session plan for this update; no human results have been collected by the build process.


Infinite hard encounters: from 1,200 points, encounter sections alternate sideways sweeping lasers and top-entry zigzag holes. Both warn for two seconds; only one special hazard is present at a time. Lasers sweep 65 units either side of their origin for 3.5 seconds. Zigzag holes cross a 250-unit horizontal range and descend at 1.35 times board speed plus 35 units/second. Tune these in lib/hazards.dart and scheduling in lib/game.dart.

## 2048 / Merge

Choose **2048 / MERGE** from the home screen. Steer the solid middle ball into descending numbers. The largest value stays in the middle of a translucent snake, with smaller values arranged on both sides and the smallest at an outer end. The snake moves along the platform and follows its tilt. Values are sorted largest to smallest internally, and each pair of outer positions fills on opposite sides. This produces the layout **2, 16, 32, 8, 4**. Collecting another 2 combines all five matching powers into **64**.

Matching values combine anywhere in the snake, including across opposite sides. Every intermediate merged value adds to score. Glowing rings mark numbers that match any current segment. The solid middle ball collects numbers; faint segments pass through numbers and holes.

The 320-unit platform still fits 12 balls at 26-unit spacing. The chain takes up space on both sides, reducing the middle ball's available travel range as it grows. A matching pickup can rescue a full snake; a pickup that leaves it longer than the platform ends the run. The platform turns orange as space runs low. The length/match label stays above the uniformly fitted board.

Each new wave contains **three number balls and two falling holes**. Their positions are separated, with one reachable matching number and a clear lane through that wave's holes. The solid middle ball falls when its center enters a hole, ending the run. Missed numbers have no penalty. Pause freezes both streams, and replay resets them together.

Play continues automatically through 2048 and beyond, without a win screen or confirmation. Number labels use 1024 = **1k**, 2048 = **2k**, 1,048,576 = **1m**, and 2,097,152 = **2m**; underlying values and merge scores remain exact. Records are local and separate from other modes, and the run is recorded when it ends.

Tune number/hole spawning, merge logic, spacing and capacity in `lib/merge.dart`. `lib/board_painter.dart` draws the centered snake and holes; colors, compact labels, length status and loss UI are in `lib/merge_widgets.dart`. `tool/render_merge.dart` exports staged Flutter screenshots of the centered example, its merge to 64, active play past 2048, millions, length warning, and both loss conditions.

## Laser Maze

Choose **LASER MAZE** on the home screen for ten named routes plus an endless climb. A dark road runs upward between bright red laser walls, and every route is built from right-angled legs: climb a column, cross sideways, climb the next column, cross back, and so on to the checkered finish. A straight lift out of the launch column always ends on a wall. Early routes are wider with two or three crossings; later routes are narrow six-crossing switchbacks. Only the ball touches the walls; the platform can cross them. Contact with either laser ends the run immediately, and crossing the finish inside the final column wins.

The **ENDLESS** card at the top of the picker plays the same corridor with no finish: legs are generated above the ball forever, the corridor narrows from 40 to 26 units of half-width and its legs shorten over the first 2,400 units of climb, the camera follows the climb, and legs left far below are dropped so the live geometry stays small. The score is the height climbed in metres, kept as a separate local best.

Two-finger dragging, vertical analog controls, and desktop keyboard steering use the existing ball/platform physics. Lift both ends to climb, then tilt to roll across each sideways leg and brake before its far wall. One-finger mode adds the slow 14-unit/second automatic climb while the lower handle controls tilt; because that climb cannot be stopped by hand, it now waits whenever a sideways ceiling is overhead, holding height (16 units clear of the beam) until the tilt carries the ball into the next column. There are no holes, spiders, number pickups, idle floor or Classic rewards in this mode.

The HUD shows peak route progress and active time; endless shows metres climbed. Route progress follows the whole winding centerline, so the sideways legs count towards it and it cannot be farmed by descending. Pause freezes the run and clears held input. Results offer retry, next route, all routes, and home; the last route returns to route selection, and endless offers Climb again. All ten routes are available from the picker. The selected route, attempt count, fastest finish per route/control mode, and the endless best height and attempt count are saved locally in a separate record.

`lib/laser_maze.dart` models a corridor as a list of axis-aligned legs whose union is the road (`LaserMazeCorridor`). The lasers are the exact boundary of that union: each leg edge minus the parts covered by another leg, so right-angle turns produce no interior walls and no gaps. `LaserMazeRoute` builds the ten fixed routes from a per-level width and a list of lane fractions, one per crossing; `EndlessMaze` grows and prunes the same legs at run time. Wall collision is a swept circle against every wall segment and includes the ball radius, beam thickness and corners, so fast pivot swipes cannot jump a turn. `lib/laser_maze_painter.dart` draws the road, red walls, centerline arrows, finish, camera scroll and both picker previews. `lib/laser_maze_widgets.dart` supplies the picker (including the endless card) and result screens. Tune `LaserMazeRoute.widths` and `LaserMazeRoute.patterns`, or the endless ramp in `EndlessMaze`; actual human difficulty still needs playtesting.
