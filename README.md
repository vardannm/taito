# GILT — Precision Arcade

A Flutter game built around the mechanical ball-and-bar challenge: two independently controlled ends, a rolling steel ball, ten numbered targets, and three chances. GILT is the current working title.

## Play on this Windows computer

Open this folder in VS Code, select **GILT • Browser preview**, and press F5. A project-local Flutter SDK is installed in `.tools/flutter` and selected in `.vscode/settings.json`.

Alternatively:

```powershell
.\scripts\flutter.ps1 run -d chrome
```

Controls: hold the upper half of each bottom rocker to raise that end; slide through the center dead zone to the lower half to lower it. Release to stop the motor. Both thumbs work simultaneously. On desktop use **W/S** for the left end, **Up/Down** for the right, and **Esc** to pause.

## What is implemented

- Original ivory, brass, and deep-teal art direction; procedural engraved playfield and original app icons.
- Fixed 120 Hz physics with rolling-sphere acceleration, motor smoothing, inertia, speed limits, and swept hole collision detection.
- Ten targets in sequence. Each capture animates the ball sinking and the bar returning to the launch position.
- Three-ball Classic; endless Infinite rounds; and unlimited-attempt Practice with slower motors and slightly more forgiving target capture.
- Streak multipliers up to 4× and speed bonuses. Time rewards precision without ending slow runs.
- Original synthesized audio, optional haptics, separate persistent Classic/Infinite records and run counts, plus the furthest Infinite round.
- Tutorial, settings, pause, replay, lifecycle pause, input cancellation, and reduced-motion support for board effects.
- iOS project with portrait orientation and GILT branding; web build support with bundled renderer assets.

Scoring: `(target number × 100 + max(0, 35 − climb seconds) × 10) × multiplier`, rounded to integer points. Multiplier increases every three consecutive targets. Misses reset the streak. Practice scores are excluded from the classic record.

## Infinite mode

Choose **INFINITE** on the home screen. Clear holes 1–10 to start another round. Score, streak, and remaining balls carry over; the run ends only when all three balls are lost. Each completed round adds a bonus of 1,000 × its round number. Routes alternate between the original board and its horizontal mirror. Motor speed and rolling acceleration increase 5% per round, capped at +40% from round 9 onward. Target sizes and life count stay consistent. Infinite records are separate from Classic, and Practice never affects either record.

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
- `lib/board_painter.dart`: procedural board, ball, and capture effects.
- `lib/main.dart`: responsive screens, tutorial, keyboard/touch controls, and lifecycle.
- `lib/profile.dart`: records, settings, sound, and haptics.
- `test/`: progression, physics, reachability, small-screen, and multitouch checks.

