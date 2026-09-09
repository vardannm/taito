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

Choose **2048 / MERGE** from the home screen. Steer the numbered ball into descending colored orbs. The stack starts at 2 and has six slots, shown left-to-right with the current top highlighted. Matching the top number doubles it and can cascade into matching neighbors: [8, 4, 2] + 2 becomes [16]. Each intermediate merged value contributes to score. A nonmatching pickup fills another slot. At six slots, a match still saves you; a nonmatch ends the run. Missed orbs have no penalty.

New rows include the stack's current matching value, with randomized separated positions and other number choices. A bright ring identifies current matches. Reach 2048 for a win screen, then continue toward 4096 and beyond or start fresh. This mode uses the selected control scheme, has its own local best score/highest tile/run count, and awards no Classic stars. Continued play counts as the same run.

Tune spawn speed, spacing, number mix and stack logic in `lib/merge.dart`. Colors, slot tray, orb drawing and result UI are in `lib/merge_widgets.dart`. Phone layouts keep the tray above the uniformly fitted board and controls inside the safe area.
