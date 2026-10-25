# Rollrise: Ball Balance — Google Play screenshots

Prepared 23 October 2026. Upload the six PNGs in each matching device folder,
in filename order. Nothing has been uploaded to Play Console.

| Play Console section | Folder | Resolution |
| --- | --- | --- |
| Phone screenshots | `screenshots/phone/` | 1080 × 1920 |
| 7-inch tablet screenshots | `screenshots/tablet-7/` | 1440 × 2560 |
| 10-inch tablet screenshots | `screenshots/tablet-10/` | 1800 × 3200 |

Each set contains the same six scenes. Suggested accessibility descriptions:

1. Precision: Balance the ball on a tilting platform and collect a star in Classic level 8.
2. Infinite: Climb through the circuit arena, collecting coins and power-ups.
3. Classic: Navigate moving holes and hazards in Classic level 60.
4. Boss: Face the Prism Reaver boss in a neon arena.
5. Merge: Merge matching numbered balls while avoiding larger numbers and clearing gates.
6. Gear: Browse collectible ball styles and their coin prices in the Gear Shop.

## Capture and review

These are real Flutter app UI renders using the Android target platform and
staged gameplay. They are not captures from physical Android devices. The
screenshots contain no added marketing overlays or device frames; each is
byte-identical to its corresponding `source-ui/` image. Compare these layouts
with the final native release on devices before store submission.

All 18 images passed PNG integrity, exact dimensions, 9:16 aspect ratio,
24-bit RGB/no alpha, and source identity checks. All three contact sheets
were visually reviewed; the capture test reported no framework exceptions.
See `validation.json` and `checksums.sha256` for image metadata and hashes.
The `previews/` images are contact sheets for review, not store uploads.

Reference: [Google Play preview asset requirements](https://support.google.com/googleplay/android-developer/answer/9866151).

## Reproduce from the repository root

```powershell
.\scripts\flutter.ps1 test --no-pub --dart-define=STORE_PLATFORM=android tool/render_app_store.dart
.\scripts\flutter.ps1 test --no-pub --dart-define=STORE_PLATFORM=android tool/render_app_store_overview.dart
node scripts/validate_google_play.cjs
```
