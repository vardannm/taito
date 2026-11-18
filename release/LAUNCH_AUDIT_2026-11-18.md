# Publishing audit — 18 November 2026

## Current status after follow-up changes

The findings below preserve the initial audit. Since that audit:

- Removed the normal-startup 300,000-coin refill and explicit all-level unlock.
- Release preflight now passes; normal economy/progression checks passed (14 tests).
- Analytics now defaults on when no saved choice exists, with opt-out retained.
  Its six tests passed. Real-device event delivery remains unverified.
- Android release AAB was rebuilt with production ads explicitly selected;
  production app/unit IDs, absence of the Android sample rewarded unit, ZIP
  integrity and JAR signature were checked.
- Created the iOS AdMob app and rewarded unit in Chrome, connected their real
  IDs to the native plist and release selector; all 16 ad/consent tests passed.
  Native iOS compilation/playback and consent-message delivery remain unverified.
- Static analysis passes. Local policy and website copies reflect the changes;
  the revised public policy has not been deployed during these follow-ups.

Remaining: visible placeholder coin purchases/Restore; triage of the initial
91 failing tests (the full suite has not been rerun after the follow-ups);
physical-device QA; current analytics/ad delivery; iOS consent setup; public
policy deployment and final store disclosures; accurate screenshots/listing;
store account/production access and app review. The AdMob console shows Android
requiring review with limited serving until a store listing is linked; the new
iOS app also awaits store linking/review. See `ADMOB_SETUP.md` for current IDs.

## Initial audit

Verdict: do not submit this source unchanged. This audit reviews commit d87ea5d and runs local checks; it does not verify signed-in store or advertising consoles. No gameplay source was changed.

## Confirmed source blockers

1. **Capture settings are active in the normal entry point.** `lib/main.dart:80–88` explicitly constructs `PlayerProfile(temporaryLevelAccess: true)` and raises any wallet below 300,000 to 300,000 on every launch, saving to the normal economy. The explicit constructor argument bypasses the profile's release-safe default. Remove the capture setup from normal startup before making a candidate. The actual release preflight exits with a blocker for the wallet credit. Its checks do not catch this explicit level-unlock override.
2. **Unimplemented purchases are publicly reachable.** `lib/coin_store.dart:12` enables the store; its wallet opens it at lines 415–425. Five USD-priced packs only show an upcoming-update notice at lines 170–180. Restore is also a notice at lines 190–200. There is no billing dependency in pubspec.yaml. Hide this entry point for launch or implement and verify real store purchases. This is an unfinished purchase experience and a review risk, not evidence that players are charged.
3. **The automated suite is not green.** See `artifacts/publish-audit-tests.log`. There are both likely stale navigation expectations and substantive checks requiring investigation. For example, `classic_star_test.dart:63` fails the safe-route check for the level-25 star; `adaptive_control_options_test.dart:71` reports a 0.522-pixel bottom overflow at 844×390. Do not interpret every failed test as a separately confirmed player-facing defect. Reconcile intended behavior and rerun affected checks before sign-off.

## Release evidence still needed

- **Fresh final artifacts:** the pre-existing Android AAB was dated 23 October, while source changed through 18 November. This audit successfully rebuilt the current source (see results below), replacing that local AAB. It contains the identified blockers and is not approved for upload. Build again after corrections; verify the final package, signing, target API and version code. Source remains 0.13.6+24; increment build 24 if already consumed by a previous store upload.
- **Physical-device QA:** `release/DEVICE_QA.md` records no physical-device sessions. Obtain current results for onboarding, all modes, multitouch, pause/background/resume, saves after restart, offline play, ads and consent, and sustained performance. This audit does not establish that testing outside this repository never happened.
- **Google Play access:** current account verification, app setup, Data safety, audience/rating, contains-ads declaration, testing track and production access were not inspected. For a personal account created after 13 November 2023, Google requires at least 12 continuously opted-in closed testers for 14 days, followed by an application for production access. If incomplete, a public launch today is blocked independently of code readiness.
- **Advertising:** Android production IDs and UMP integration exist. The 23 October AdMob notes leave payments verification, app review, store linking and app-ads.txt ownership verification outstanding. Recheck current console state and device reward/consent behavior; these notes are historical evidence, not today's account status.
- **iOS:** a release signing team is configured, contrary to older checklist text. However, iOS still uses Google's sample app and rewarded-unit IDs (`ios/Runner/Info.plist:7`, `lib/rewarded_revive_ads.dart:32–43`). Configure the iOS ad release or disable those offers. A current signed archive, native SDK privacy report, TestFlight/device results and store setup remain unverified here. Apple's current submission requirements call for Xcode 26+ and iOS 26 SDK+.
- **Listing and images:** existing images date from October; `release/app-store/README.md` explicitly flags outdated captures. Google Play draft copy still advertises standalone Practice, which the current README says was removed. Reconcile screenshots, controls, progression and mode claims with the final native candidate.
- **Privacy:** the publisher, contact and HTTPS URL are populated locally; missing policy identity is no longer a source blocker. Today's public URL availability and final console privacy disclosures remain unverified. Web retrieval of the policy failed in this audit, which does not by itself prove the site is down.

## Verified positives and limits

- `flutter analyze --no-pub`: passed, no issues.
- Full test suite completed: **849 passed, 91 failed** (exit code 1; 2 minutes 36 seconds). Full output: `artifacts/publish-audit-tests.log`.
- Fresh `flutter build appbundle --release --no-pub`: **passed**, 174.3 seconds, reported size 83.6 MB; output `build/app/outputs/bundle/release/app-release.aab`. Compilation succeeded with Kotlin-plugin future-compatibility and SDK XML tooling warnings. This is build evidence, not store acceptance, fresh signature/ELF validation, or device QA. Log: `artifacts/publish-audit-build.log`.
- Actual `scripts/release_check.py`: fails on the testing wallet credit; does not report absent Android signing, iOS release team or policy identity.
- Android production rewarded ID, UMP gating/privacy options and separate opt-in analytics exist in source. Older checklists describing them as absent are stale.
- The October AAB validation records target SDK 36 and 16 KB-or-greater native load alignment. Revalidate a final rebuilt artifact. Google currently requires API 36 for new ordinary Android apps.
- Cloud saves/accounts/online rankings are absent but are optional for the documented local-save release; avoid advertising them.
- Initial test/build attempts hit sandbox filesystem and localhost restrictions. Tests and build were rerun outside that sandbox; environment-only errors are excluded from the product findings.

## Official requirements checked

- Google Play personal account testing: https://support.google.com/googleplay/android-developer/answer/14151465
- Google Play target API: https://support.google.com/googleplay/android-developer/answer/11926878
- Apple submission SDK requirements: https://developer.apple.com/news/upcoming-requirements/

## Recommended release order

Remove the capture wallet/level override; hide unfinished billing; triage and resolve the test failures; produce a fresh signed candidate; complete device/ad/save QA; reconcile listing assets and disclosures; then submit through the available store track. Store review and production-access approval control public availability.
