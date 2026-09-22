# GILT â€” Precision Arcade

A Flutter game built around the mechanical ball-and-bar challenge: two independently controlled ends, a rolling steel ball, ten numbered targets, and three chances. GILT is the current working title.

## Play on this Windows computer

Open this folder in VS Code, select **GILT â€¢ Browser preview**, and press F5. A project-local Flutter SDK is installed in `.tools/flutter` and selected in `.vscode/settings.json`.

Alternatively:

```powershell
.\scripts\flutter.ps1 run -d chrome
```

Controls: drag the left or right grip on the platform up and down. Both fingers work independently; release to hold that pivot. In Infinite, release and grab again for another upward swipe. Carousel previews fit the complete board. Gameplay scales uniformly to fill the available safe-area width. On shorter screens, the visible region follows the platform vertically instead of shrinking the board or stretching its artwork; holes and the ball stay circular. Painting, pointer hit testing and heart feedback use the same viewport transform. On desktop use **W/S** for the left end, **Up/Down** for the right, and **Esc** to pause.

Settings offers illustrated, animated cards for **Two-Finger Control** (default), **One-Finger Control**, and **Vertical Analog Control**. Vertical Analog and Two-Finger each have a saved sensitivity slider from 0 to 1: 0 disables touch movement and 1 preserves full response. Scaling is immediate and independent; keyboard movement is unchanged. Vertical analog places two independent joysticks at the bottom inside the safe area. Drag up to raise that platform end, down to lower it; the platform follows directly with about 19% less sensitivity. There is no dead zone. Horizontal movement is ignored. Release centers the knob and holds the final platform position; grab again to continue moving. One finger drags the lower handle left/right to set tilt and up/down to raise or lower both ends. Once held, vertical dragging continues beyond the thumb area and reverses immediately, without a pad-edge movement cap. The visible pad and knob keep the same design; the knob stays drawn within the pad. Holding the handle pauses the control mode’s automatic lift in Classic; release resumes it. Infinite’s continuous board ascent remains active. Classic automatically lifts at 20 world units/second and waits at the current target height, so a target cannot be left behind. All three modes share ball physics. All touch targets are consumed on the next 120 Hz physics tick without smoothing or an added delay. Keyboard motor easing remains. Ball acceleration and its speed cap increased by about 8%.

Swipe to Classic to continue the saved level directly. The small arcade icon → Classic levels opens a responsive grid of 50 named levels. Each board retains ten targets, three lives and the existing scoring. Level 1 is open initially; level N requires `2 × (N − 1)` total Classic stars (level 2: 2, level 10: 18, level 50: 98). Stars are permanent, not spent, and each distinct objective counts once across control methods. Daily stars do not unlock Classic boards. Locked cards show the earned/required count. Winning offers **NEXT LEVEL** when its requirement is met, or **EARN MORE STARS** and replay options otherwise; the selected level is remembered. Deterministic scattered layouts vary target positions, heights, and numbering so targets no longer follow a single route. Trap density increases through the original 30 boards. Practice retains its original board and unlimited attempts.

Levels 31â€“50 form **The web**: one slow patrolling spider at first, two from level 36, and three from level 43. Dashed circles and background webs mark their territories. Crossing a boundary starts a persistent chase; physical contact instantly ends the run and removes the ball, without an eating animation. Territories and spiders turn red during pursuit. Capturing a target or losing a ball to a hole resets the spiders; pause freezes them. Territory placement keeps target holes clear and checks connected space from the launch area to every target. Human difficulty still needs playtesting.

## Mastery, daily boards and cabinet styles

Classic and Daily award three independent stars: finish, finish without a miss, and finish within the displayed active-time target. Earned objectives merge across retries. Each board saves its best score, fastest successful time, and attempt count separately for each of the three control modes. The grid shows these records; the result screen explains each star and offers a retry of the same board alongside next-level progression.

Active time excludes pauses, capture animations, and the bar returning to launch. Initial time targets use board elevation, the control mode's lift speed, trap count and a finale/spider allowance. They are provisional until human playtesting; adjust the `targetTime` calculation in `BalanceGame.start` in `lib/game.dart`.

Optional brass coins sit beside traps in Classic and Daily, clear of hole centers and spider territories. Each adds 250 points, can be collected once per run, and stays collected across ball resets. Collectibles are optional and do not change the three star objectives. Infinite and Laser Endless spawn random coins ahead of the climb, with a separate in-run coin counter so height records remain in metres. Coins stay clear of holes and beams and disappear after scrolling below the board. Practice has no collectibles or progression rewards.

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

The app opens directly onto the Infinite board, including on first launch. The board waits without advancing physics, timers or score. Touch the selected joystick, thumb area or platform grip to begin; the same held gesture immediately controls movement. W/S or the arrow keys also start the run and move the platform. Swipe across the environment, header or free space to select exactly five worlds: Infinite, Classic Continue, Maze Infinite, Maze Continue, and 2048 Merge. Classic and Maze show their saved level (level 1 for a new profile); Classic still respects star locks. All five prepared boards start on their selected controller or movement keys, without a Play button. Page edges, parallax, scale, title fades and a five-position indicator guide navigation. Swipes snap one world at a time and never claim touches in the actual control areas. Once a run begins, swipe recognition is removed. The selected scene expands from an 88%-width carousel viewport into the full gameplay area over 437 ms; neighboring previews fade away. The remaining selector chrome fades out during the final 123 ms. The same board and controllers stay mounted and preserve the starting touch as their layout grows. Returning home freezes the run and reverses this animation before preparing the current world; a normal application opening always selects Infinite. The arcade icon retains level/route pickers, Daily, Practice, Gear Shop, goals and the optional tutorial. Start with three hearts. Holes, live lasers, moving holes, platform gaps and the rising red floor cost one heart. A hit resets combo to x1 and removes combo effects. When hearts remain, the ball and platform stay on their current trajectory with the same tilt, momentum and held controls. A small heart appears above the platform, floats upward and fades out over 0.85 seconds; this independent effect never changes input or life state. They blink gently during 2.5 seconds of protection so the player can steer away; there is no relocation, platform reset or touch reset. The camera, holes, hazards, rising floor and generation progress continue normally. Reduced motion uses a steady protection ring. The third loss ends the run. Pausing freezes all gameplay and power-up timers.

**Pace x1–x5** increases smoothly with peak distance, advancing one level per 150m. New players start at 68 world units/second. A completed best of 150m starts subsequent runs at x2 (77 units/second); 450m starts at x3 (86). The existing difficulty curve remains, with an additional nine units/second per fractional pace level, capped at 216 overall. Pace also increases distance point earnings. Hole density now has a separate point-based curve: sparse one-hole bands with roughly 210–240 units of spacing initially, gradually reaching full density at 20,000 points. Dense bands contain up to four holes with roughly 80–110 units of spacing, adjusted by the current rush/breathing section and pace. A new run resets density even after a high-scoring previous run. The HUD shows points and distance separately; revisiting old height cannot earn distance points again. Existing distance records are retained; the new point record is separate.

Gold diamond **combo crystals** build x1–x5 and award `50 × new combo × pace level × gear multiplier` points, rounded after all multipliers. Further crystals at x5 keep awarding bonuses. Missing a crystal preserves combo; losing a heart breaks it. Some crystals sit near traps with clearance for the ball, offering optional risk for more points. Combo colors transition across the whole playfield and surrounding screen, including the HUD and controls. Mint, blue, violet and warm coral stages have drifting light bands, bounded streaks and collection bursts. At x5, the platform has a soft gold aura, three electric arcs, two traveling surges and eight sparks; gaps remain visibly open. The effect uses gradients and shared paths without per-particle Gaussian blur passes. Background streaks are capped at 12. The HUD rebuilds only when displayed values change; the outer background repaints only as its combo color changes. Effects render underneath hazards and respect reduced motion.

Shield pickup, refresh and expiration preserve active touch ownership, drag position and pending movement. The shield status line reserves its space, so effects do not resize the board or controller. Blue **shield** pickups grant 10 seconds of invincibility against every Infinite hazard, with a countdown and a visible ring around the ball. Invincibility preserves hearts and combo. Pink **heart** pickups rarely appear while a heart is missing. Hearts cap at three; one already on the board grants a point bonus if collected at full health. Pickups and moving hazards resolve in swept contact order, so a shield must be reached before it can prevent a collision.

Coins appear more often than crystals; shields and hearts are much rarer. Offscreen pickups are pruned and the extra collectible list is capped at 12. Every 180m cycles through a rush, a lighter stretch and an encounter. Special hazards still unlock at 180m (forming holes), 350m (moving holes), 600m (lasers) and 900m (platform gaps). Only one special hazard runs at once, with harmless warnings before activation. Once a forming hole opens, its world coordinates are fixed and it remains until it scrolls off-screen. Camera movement from manual lifting is included in both rendering and collision. Moving-hole types retain their intended movement. Off-screen pruning happens after swept collisions, so a fast camera lift cannot skip a hole. A winding clear route and hole separation remain. After three seconds without steering the red floor rises; deliberate steering stops its active rise.

**GEAR SHOP** in the Modes menu spends Infinite and Laser Endless coins. It contains **11 balls and 6 platforms**, each with a permanent point bonus displayed before purchase. The active gear multiplier is `1 + ball bonus + platform bonus`, up to x5. Gear multiplies Normal Infinite distance and combo points; other modes retain their scoring rules. Physics, collision size and platform handling stay the same. Existing owned balls automatically receive their new bonus; no repurchase is needed. Coins and gear ownership save locally without an account. The 2048 mode retains its numbered ball for readability. Cabinet styles remain in Settings.

Tune lives, durations, starting speed, pace levels, the 20,000-point density threshold, collectible spacing, coin spacing and visual intensity in `lib/infinite_progress.dart`. Survival integration is in `lib/infinite_gameplay.dart`; visuals are in `lib/infinite_painter.dart`. Economy saves use ordered snapshots to prevent an older coin save from undoing a purchase. This is device-local progress, with no account sync.

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
- `lib/tutorial.dart`: optional illustrated tutorial, opened from Modes → How to play.
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

Matching values combine anywhere in the snake, including across opposite sides. Every intermediate merged value adds to score. Glowing rings mark numbers that match any current segment. The solid middle ball collects numbers; faint segments pass through numbers.

The 320-unit platform still fits 12 balls at 26-unit spacing. The chain takes up space on both sides, reducing the middle ball's available travel range as it grows. A matching pickup can rescue a full snake; longer chains compress their spacing to stay on the platform. Length no longer ends a run. The next gate requirement and matching number stay above the uniformly fitted board.

Each wave contains **two safe numbers and one larger number to dodge**, separated across the board with a reachable matching pickup. The solid middle ball can collect only values equal to or below its current value. Touching a larger value ends the run immediately; a red ring and an exclamation mark identify it. Ghost segments pass through pickups. Danger is evaluated at contact, so an earlier merge can make a later number safe.

Every **400 merge score** earns a horizontal gate descending from above the board. The main ball must be **strictly greater** than the exact number displayed: a 4096 gate requires at least 8192. The first gates require >64 at 400 score, >128 at 800 and >256 at 1200. Requirements scale as the largest power of two no greater than one quarter of the milestone score; a 4096 gate appears at 16,400 score. Large scoring chains queue milestones, with one gate at a time and a short gap between them. Gates replace falling holes. Fast swipes check pickups and gates in contact order, pause freezes both streams, and replay resets the run. Missed numbers have no penalty.

Play continues automatically through 2048 and beyond, without a win screen or confirmation. Number labels use 1024 = **1k**, 2048 = **2k**, 1,048,576 = **1m**, and 2,097,152 = **2m**; underlying values and merge scores remain exact. Records are local and separate from other modes, and the run is recorded when it ends.

Tune number/gate spawning, merge logic and spacing in `lib/merge.dart`. `lib/board_painter.dart` draws the centered snake, warning rings and gates; colors, compact labels, gate status and loss UI are in `lib/merge_widgets.dart`. `tool/render_merge.dart` exports staged Flutter screenshots of the centered example, its merge to 64, active play past 2048, millions, long snakes, and both loss conditions.

## Laser Maze

Choose **LASER MAZE** for twenty distinct routes plus an endless maze. All routes include temporary downward travel. Routes 11–20 are expert towers spanning roughly three to seven screen heights, with progressively tighter corridors, repeated descents and connected shortcuts. Their camera follows both upward climbs and downward detours; each route has its own finish height and saved best time. Layouts include returning U bends, long crossings, multiple descents, winding loops and split/rejoining paths. Gold arrows and **SHORT** labels identify narrow shortcuts; wider detours take substantially longer and reconnect at the same junction. The first layouts have a 26-unit half-width, gradually reducing to 21.5; shortcuts use 15 to 13.2 units. The ball radius is 7 and the beam radius is 2. Only the ball collides with walls. Crossing the final checkered line wins.

Laser Maze uses the player's selected **Two-Finger**, **One-Finger**, or **Vertical Analog** control mode, including endless and retries. Raise/lower both ends to follow the route vertically and tilt to move sideways. Touch movement responds on the next 120 Hz tick, without smoothing or added delay. Keyboard controls remain available. Completion records stay separate for each control mode.

Endless uses randomized self-avoiding routes on a generously spaced graph, with optional narrow chords that form real branches and loops. It shuffles six structural families without consecutive family repetition and rejects recently used exact paths. Entry lanes, exit lanes, horizontal proportions, height, turns and shortcut connections vary. A bounded fallback retains a valid connected route if route search exhausts its budget. Primary road half-width tapers from 26 to 21 over 6,000 units of climb; shortcuts stay at least 13 units wide. Modules shorten gradually and always preserve separation between unrelated corridors.

The endless camera follows both upward and downward travel, while score remains peak height in metres. Whole modules, including their branches, stay loaded for return trips; geometry is pruned well below the player. Finite route progress maps both alternatives between the same junctions, so either path reaches the same progress when they reconnect. Pause freezes motion and timers. Retry, next route, route selection, local attempts and records retain their existing behavior.

Endless coins spawn along the road. Bugs patrol **outside** the road, with small harmless circles while resting. For two seconds, amber circles expand and a ring shows the warning countdown. A red circle then catches the ball only where it overlaps the road; it retracts before another warning cycle. The bug body stays outside throughout. Placement checks the entire patrol segment against all road rectangles and protects a ball-sized route along every primary and shortcut centerline. This leaves a clear route even when multiple zones are active. Bugs and coins are pruned below the camera. Classic spiders retain their original territorial chase behavior.

`lib/laser_maze.dart` owns union geometry, swept laser collision and branch-aware progress. `lib/maze_routes.dart` owns graph generation, finite route definitions, branches and atomic endless modules. `lib/spiders.dart` owns warning/catching cycles and exterior placement. `lib/laser_maze_painter.dart` draws directional arrows and shortcut markers; `lib/spider_painter.dart` highlights the catching area clipped to the road. `tool/render_maze.dart` exports real phone views of structural variants and both warning/active bug states.

Automated tests validate connectivity, ball clearance, protected routes, required downward movement, long-run generation bounds, preference restoration and other-mode regressions. Human playtesting is still needed to assess difficulty and analog feel.

Moving balls now leave a short teal-to-gold wake and a soft glow that responds to speed. The effect is visual only, pauses with gameplay, fades while stationary and clears on restart. Reduced-motion mode omits the wake.

Gear tables are in `lib/ball_cosmetics.dart` and `lib/platforms.dart`; animated control cards and sensitivity sliders are in `lib/control_options.dart`. Regenerate phone renders with `tool/render_refinements.dart`.

### Unlimited-coin testing APK

Build with `--dart-define=GILT_UNLIMITED_COINS=true` to enable unlimited Gear Shop purchases. The shop displays an infinity balance and a TEST BUILD label. The default build keeps the normal economy. Test purchases use `gilt.economy.coinsTest.v1`, separate from the normal wallet and gear ownership; other settings and progression remain shared.


## Interactive onboarding and arcade club (0.11.0)

The first-run tutorial now uses a real isolated practice game. Pick Two-finger, One-finger or Vertical Analog, lift and release, tilt the ball, and catch the glowing target. NEXT unlocks after doing the action; reset, back and skip remain available. Replay it from How to Play. Tutorial progress does not award coins or game records.

Open the arcade icon or Settings → Goals, friends & backup. Goals follow the selected control scheme: finish the campaign, then earn clean and time stars. The club shows cabinet unlock progress and opens the suggested level directly.

Daily friend challenges use a copied `GILT1` code containing a display name, date, controls and personal best score. Paste a friend's code to play that exact Daily board. Scores are friend-reported and stored locally, not server-verified rankings. Friend challenges are capped at 30 on-device entries.

Manual progress backups include records, wallet, owned/selected gear and settings. COPY BACKUP puts a versioned JSON snapshot on the clipboard; save it outside the app. RESTORE validates the snapshot and previews its progress before replacing local data. Test-economy snapshots cannot restore into normal builds. Friend codes and playtest logs are separate and are not part of a progress backup. No automatic cloud sync or online account is connected.

The optional local playtest recorder is in the same club screen. Start a session, replay the tutorial and observe the player, then stop and copy the report before closing the app. It captures up to 1,000 events without names or uploads. Starting another session replaces the in-memory report. See `playtest/NEXT_SESSION.md`; human sessions are still pending.

Normal builds now respect saved wallets instead of resetting them to 99,999. For free test purchases use the existing `--dart-define=GILT_UNLIMITED_COINS=true` build flag; its economy remains separate.

Release preparation: `python scripts/release_check.py`, `release/DEVICE_QA.md`, and `release/STORE_COPY.md`. Android release signing reads ignored `android/key.properties` when configured; without it the APK remains development-signed. iOS compilation, signing and physical-device tests require the release Mac/iPhone. Review screenshots can be regenerated with `flutter test tool/render_growth.dart`.


## One-finger thumb area (0.11.1)

One-finger controls now sit in a 96-pixel area below the board, keeping the ball above your finger. Touch anywhere in the area and drag sideways to tilt, up/down to move vertically. Release and re-grab wherever comfortable; touching a new point does not jump the platform. Movement stops at the area's edges, so lift and re-touch to continue a long climb. A second pointer is ignored and pause/cancel clears the active touch. This shared control appears in gameplay and the tutorial. Two-finger and Vertical Analog controls are unchanged.

### Lightweight carousel previews

Only the snapped page owns a live `BalanceGame` environment. Inactive pages are pre-baked, softened 180×280 screenshots, including all 50 Classic and 20 built-in Maze levels (73 images total, about 3.7 MB). Swiping partway shows the image without preparing that mode. The live world changes only after the snap finishes; there is one simulation ticker, stopped during selection, pause and return. Maze and Merge resources are created only when needed and released when leaving their mode. No runtime blur, screenshot generation or hidden simulation is used for neighboring pages.

Regenerate preview assets after changing board artwork or built-in routes:

```powershell
.\scripts\flutter.ps1 test --no-pub tool/bake_mode_previews.dart
```

Use `tool/render_mode_transitions.dart` for expansion, full-game, floating-heart and reverse-animation frames. Reduced motion switches layouts immediately and uses a stationary heart fade. The analog control artwork is unchanged.
While a mode waits for its first input, a touch-transparent finger icon demonstrates the selected controls: two vertical drags over the platform grips or analog sticks, or a diagonal tilt/lift drag over the one-finger pad. The hint stops immediately on input, hides during a carousel swipe or return transition, and reappears when selection is ready again. Reduced motion shows a stationary finger. This uses a separate, disposable visual animation; the waiting game simulation remains stopped and analog artwork is unchanged.
## Editing individual Classic levels

The 50 Classic layouts live in `lib/classic_levels/level_01.dart` through
`lib/classic_levels/level_50.dart`. Each file contains the level name, hole coordinates, spider patrol centers,
and laser/moving-hole spawn positions and timing. `lib/classic_levels.dart` registers them in saved-progress order;
`lib/levels.dart` loads them and retains the shared gameplay rules and Daily generator.
See `lib/classic_levels/README.md` for editing instructions. The split preserves
all previous Classic names and hole coordinates exactly.
