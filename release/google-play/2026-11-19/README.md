# Rollrise: Ball Balance — Google Play screenshots

Prepared 19 November 2026 from the launch build source, which has the coin
store hidden. Supersedes `2026-10-23/`. Upload the six PNGs in each matching
device folder, in filename order. Nothing has been uploaded to Play Console.

| Play Console section | Folder | Resolution |
| --- | --- | --- |
| Phone screenshots | `screenshots/phone/` | 1080 × 1920 |
| 7-inch tablet screenshots | `screenshots/tablet-7/` | 1440 × 2560 |
| 10-inch tablet screenshots | `screenshots/tablet-10/` | 1800 × 3200 |

Each set contains the same six scenes. Suggested accessibility descriptions:

1. Boss: Dodge the Chrono Keeper's rewinding clock bolts high above a neon city.
2. Infinite, deep run: Climb past 3,100 m under the aurora with a 9× combo.
3. Shop: Browse ball worlds, platforms and permanent upgrades in the Gear Shop.
4. Classic level 23: Balance the ball toward the glowing hole and grab the bonus star.
5. Classic level 76: Thread a dense field of holes between laser rails.
6. Infinite: Climb the circuit arena, collecting coins and power-ups.

## Capture and review

These are real Flutter app UI renders using the Android target platform and
staged gameplay, not captures from physical Android devices. No marketing
overlays or device frames; each screenshot is byte-identical to its
`source-ui/` image. `previews/` holds review contact sheets, not uploads.

On phones every boss hovers just under the score, as in the real game, so the
phone Boss shot shows the boss behind the HUD; the tablet shots have room.

All 18 images passed PNG integrity, exact dimensions, 9:16 aspect ratio,
24-bit RGB/no alpha and source identity checks (`validation.json`,
`checksums.sha256`).

Reference: [Google Play preview asset requirements](https://support.google.com/googleplay/android-developer/answer/9866151).

## Reproduce from the repository root

```powershell
.\scripts\flutter.ps1 test --no-pub --dart-define=STORE_PLATFORM=android tool/render_app_store.dart
.\scripts\flutter.ps1 test --no-pub --dart-define=STORE_PLATFORM=android tool/render_app_store_overview.dart
node scripts/validate_google_play.cjs
```
