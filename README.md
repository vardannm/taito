# GILT — Precision Arcade

A Flutter game built around the mechanical ball-and-bar challenge: two independently controlled ends, a rolling steel ball, ten numbered targets, and three chances. GILT is the current working title.

## Play on this Windows computer

Open this folder in VS Code, select **GILT • Browser preview**, and press F5. A project-local Flutter SDK is installed in `.tools/flutter` and selected in `.vscode/settings.json`.

Alternatively:

```powershell
.\scripts\flutter.ps1 run -d chrome
```

Controls: drag the left or right grip on the platform up and down. Both fingers work independently; release to hold that pivot. In Infinite, release and grab again for another upward swipe. The playfield scales uniformly to the largest size that fits below the compact HUD inside the device safe area. Extra space surrounds the board when the viewport has a different aspect ratio; holes and the ball remain circular. On desktop use **W/S** for the left end, **Up/Down** for the right, and **Esc** to pause.

Settings offers saved **Two-Finger Control** (default) and **One-Finger Control**. One finger drags a short vertical handle horizontally under the platform; its bounded position sets the tilt directly. Classic automatically lifts at 20 world units/second and waits at the current target height, so a target cannot be left behind. Both modes share ball physics. Touch targets are consumed on the next 120 Hz physics tick without a catch-up speed cap; keyboard motor easing remains. Ball acceleration and its speed cap increased by about 8%.

Choose Classic to open 30 named levels, in six groups from Beginner to Expert. Each board retains ten targets, three lives and the existing scoring. Winning offers **NEXT LEVEL**; the selected level is remembered. The levels use distinct authored routes with progressively denser trap placement and a reserved route. Practice retains its original board and unlimited attempts.

## What is implemented

- Original ivory, brass, and deep-teal art direction; procedural engraved playfield and original app icons.
- Fixed 120 Hz physics with rolling-sphere acceleration, motor smoothing, inertia, speed limits, and swept hole collision detection.
- Ten targets in sequence. Each capture animates the ball sinking and the bar returning to the launch position.
- Three-ball Classic; an endless Infinite climb; and unlimited-attempt Practice with slower motors and slightly more forgiving target capture.
- Streak multipliers up to 4× and speed bonuses. Time rewards precision without ending slow runs.
- Original synthesized audio, optional haptics, separate persistent Classic/Infinite records and run counts.
- Tutorial, settings, pause, replay, lifecycle pause, input cancellation, and reduced-motion support for board effects.
- iOS project with portrait orientation and GILT branding; web build support with bundled renderer assets.

Scoring: `(target number × 100 + max(0, 35 − climb seconds) × 10) × multiplier`, rounded to integer points. Multiplier increases every three consecutive targets. Misses reset the streak. Practice scores are excluded from the classic record.

## Infinite mode

Choose **INFINITE** on the home screen. The platform automatically ascends while holes move down toward it. There are no numbered targets or resets: every hole is a trap. Current tuning starts ascent at 60 world units/second and reaches 180 at 900m. The density budget grows from two to four holes per generation section, with section spacing of 120–140 units initially and 75–95 later. Holes are scattered independently across both axes rather than aligned into rows or left/right pairs. Minimum separation prevents overlap, a winding clear route preserves space to steer, and recent placement history breaks long one-sided streaks. Offscreen holes are discarded.

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
- `lib/levels.dart`: 30 Classic route profiles and constrained trap placement.
- `lib/board_painter.dart`: procedural board, ball, and capture effects.
- `lib/hazards.dart` and `lib/hazard_painter.dart`: timed Infinite traps, swept collision, and warning visuals.
- `lib/tutorial.dart`: first-launch illustrated tutorial.
- `lib/main.dart`: responsive screens, tutorial, keyboard/touch controls, and lifecycle.
- `lib/profile.dart`: records, settings, sound, and haptics.
- `test/`: progression, physics, reachability, small-screen, and multitouch checks.

