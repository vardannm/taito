# GILT 0.11.0 (15) — delivery status

## Implemented

- Interactive tutorial for Two-finger, One-finger and Vertical Analog.
- Next-goal guidance and cabinet unlock progress.
- Daily friend challenge codes with local comparisons.
- Manual, validated progress backup/restore across devices.
- Local opt-in playtest recorder and five-player study kit.
- Normal wallet persistence, with separate unlimited-purchase test builds.
- Compact-phone layout fixes and Android signing configuration template.

## Verified

- 211 automated tests passed; static analysis has no issues.
- Actual Flutter phone renders reviewed; all three lessons completed by simulated gestures for every control mode.
- Web release build succeeded in `build/web`.
- Android playtest APK built: `build/app/outputs/flutter-apk/app-release.apk`.
- Package metadata: versionName 0.11.0, versionCode 15.
- APK SHA-256: `8B20A3994702996814AB68202D95725F23D2F38145B4D334CC163173E8C91C92`.
- Development signing; not a Play Store upload candidate.

## External work still needed

- Backend selection and account setup for online rankings and automatic cloud sync. See ONLINE_SCOPE.md. These services are not live.
- Five real-player sessions. Use `playtest/NEXT_SESSION.md`; RESULTS.md remains unfilled.
- Android upload keystore; iOS signing team and Mac/iPhone build.
- Physical Android/iPhone performance, battery, audio and interruption checks. No Android phone was attached here.
- Publisher/support details, final store screenshots and owner review of STORE_COPY.md.

Run `python scripts/release_check.py` before preparing store artifacts. See DEVICE_QA.md for both platforms. The current APK is for playtesting; nothing has been submitted or published.
