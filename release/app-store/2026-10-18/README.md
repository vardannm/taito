# Rollrise — App Store screenshot and copy package

Prepared 18 October 2026 from the current 0.13.6+24 Flutter source, including the
revised 80-level Classic campaign. English (US). Nothing has been uploaded.

## Files to upload

Use the PNGs in `screenshots/`, in filename order. Each display has six images:

1. Precision controls and Classic gameplay.
2. Infinite, combo crystals and power-ups.
3. The 80-level campaign, orbiting holes and keepers.
4. A Prism Reaver boss encounter.
5. Number Merge gameplay.
6. Ball worlds and the gear shop, scrolled to Nebula and the later designs.

| Folder | Pixels (width × height) | App Store Connect slot |
| --- | --- | --- |
| iphone-6-3 | 1206 × 2622 | iPhone with Dynamic Island, medium display |
| iphone-6-9 | 1320 × 2868 | iPhone with Dynamic Island, large display |
| ipad-13 | 2064 × 2752 | iPad, 13-inch display |
| duo-outer | 1398 × 2034 | iPhone Duo, outer display |
| duo-inner | 2853 × 2007 (landscape) | iPhone Duo, inner display |

Sizes were checked against [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
on 18 October 2026. Files are true 8-bit RGB PNGs: no alpha channel, transparent
pixels or transparency chunks. Apple permits up to ten screenshots per set.

## Copy and paste

`copy/en-US/` contains a separate text file for each App Store field: name,
subtitle, promotional text, description, keywords, and optional update notes.
`metadata.json` contains the same text and character counts. The owner-facing
copy is also in `release/STORE_COPY.md` at the project root.
Field limits follow [Apple's platform version reference](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/);
keywords are also checked in UTF-8 bytes.

## Capture provenance

These are actual Flutter app widgets rendered at each listed display's native
pixel dimensions with the iOS target platform. Gameplay states are staged
representative scenes using real level, hazard, boss, pickup and Merge objects.
The shop uses a finite normal wallet; no unlimited-coins build or development
unlock badge is shown. Marketing captions sit outside the unaltered UI image.

`source-ui/` includes all 30 plain UI renders without marketing captions.
`manifest.json`, `validation.json` and `checksums.sha256` identify and verify
the deliverables. The ZIP contains the final full-size images and plain UI
renders. Earlier contact sheets and intermediate manifests are excluded.

This Windows workspace cannot capture an iOS Simulator or physical Apple
device. The assets are Flutter UI renders, not native iOS device captures.
Compare the final signed iOS build on iPhone, iPad and both Duo layouts before
submission, especially safe areas, controls and font rendering. The assets do
not by themselves establish iPhone Duo optimization or store approval.

## Reproduce

From the project root:

```powershell
.\scripts\flutter.ps1 test --no-pub tool/render_app_store.dart
.\scripts\flutter.ps1 test --no-pub tool/render_app_store_overview.dart
node scripts/validate_app_store.cjs
```

The main capture tool supports `--dart-define=STORE_DEVICE=iphone-6-9` for a
single display and `--dart-define=STORE_SHOTS=02-infinite,04-boss` for selected
frames (quote the complete define argument in PowerShell when it contains a
comma). A full run writes the complete manifest. No application code, player
save, release binary or live store listing is changed by the capture tools.
