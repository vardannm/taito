# Rollrise launch audit — 22 October 2026

**Follow-up, 23 October:** the nine regression failures below were resolved by
updating stale fixtures and expectations. The full suite now passes all 743
tests, and source/test analysis is clean. See `../VALIDATION.md`. The report
below records the original audit state; signing, app-ads.txt and AdMob setup
have also progressed since then, as recorded in `ANDROID_SIGNING.md` and
`ADMOB_SETUP.md`.

Audited source: `5b5c26f`, version `0.13.6+24`. Checked the signed-in Firebase,
AdMob and Google Play consoles, the public privacy site, native configuration,
release preflight, static analysis and the full Flutter test suite.

**Verdict: not ready for a public store release.** Google Play developer
verification is incomplete, there is no Play app listing, monetization is not
configured, release signing is missing, and regression checks are failing.
Nothing was uploaded, submitted, purchased or changed in the remote accounts.

## Live account findings

| Area | Verified state | Required next step |
| --- | --- | --- |
| Google Play | Personal account, public developer name **VHT Games**. Identity verification, physical Android-device verification and contact-phone verification all require action. The dashboard says to create the first app. | Complete identity verification; verify a real Android device through the Play Console app; verify the phone when identity approval allows it. Create the Rollrise app and finish its setup. |
| AdMob | Account exists, but its welcome checklist shows **0 of 4** complete. A banner says payment-profile setup is incomplete and apps cannot be reviewed until payment details are supplied. No first app or rewarded ad unit is configured. | Complete the publisher/payment profile, add separate Android/iOS apps as applicable, and create production rewarded units. These details must come from the publisher. |
| Firebase | Project **gilt-ead46**, display name **Rollrise - Ball Balance**, Spark plan. Android and iOS app registrations exist and match local native configuration. Google Analytics integration is enabled. | Retain the existing project; there is no evidence that a Firebase upgrade is necessary for the current Analytics/Hosting launch. |
| Firebase analytics | Refreshed dashboard contains iOS usage: iOS DAU **5**, Android DAU **0**, in the displayed reporting period through 21 October. | Verify the final Android build sends the intended events. Existing iOS usage proves some delivery, but does not verify every custom event or today's exact release build. |
| Firebase integrations | Analytics enabled; Google Play integration reports **No matching Play apps found**. | Complete Play app setup first. AdMob/Play linking can follow; linking is distinct from having working SDK configuration. |
| Privacy hosting | The public policy loads at `https://gilt-ead46.web.app/privacy-policy.html`, with publisher Vardan Torosyan, the configured contact email and update date 19 October. Firebase Hosting shows its last deployment on 19 October. | Update and redeploy the policy when production ads and consent behavior are finalized. |
| AdMob verification file | `https://gilt-ead46.web.app/app-ads.txt` displays **Page Not Found**. No file exists in the local privacy-hosting source either. | If this is the developer-site domain used in the store listing, publish the genuine AdMob-provided publisher entry at its root and verify it in AdMob. Do not use Google's sample publisher ID. |
| Apple account | App Store Connect redirected to its login page; no authenticated Apple account was available to inspect. | Sign in and check enrollment, agreements, app record, App Privacy and build status. Apple membership approval is **unverified**, not confirmed missing. |

Console links:

- [Firebase project](https://console.firebase.google.com/project/gilt-ead46/overview)
- [AdMob](https://admob.google.com/v2/home)
- [Google Play Console](https://play.google.com/console/u/0/developers/8664861708187020761/home)
- [App Store Connect](https://appstoreconnect.apple.com/)

## Store-release blockers in the app/build setup

1. **Production ads are not configured.** Android/iOS application IDs and
   rewarded-unit IDs are still Google's samples. `main()` instantiates
   `GoogleTestReviveAds`. Relevant files: `lib/rewarded_revive_ads.dart`,
   `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist` and
   `lib/main.dart`.
2. **Consent/privacy-choice handling is absent.** The rewarded-ad implementation
   initializes Google Mobile Ads and requests ads without a UMP consent flow or
   privacy-options entry point. AdMob's privacy page presents message-creation
   options; a working app consent integration is not present. Configure the
   required messages and check `canRequestAds()` before requesting ads.
   Determine the intended audience/regions and complete matching disclosures.
3. **Analytics consent needs a separate review.** Native configuration defaults
   collection to false, but `lib/app_analytics.dart:27` explicitly turns it on
   during startup. There is no user consent/preference gate in that path.
   Native defaults therefore do not establish an opt-out or consent flow.
   ATT is conditional on Apple's tracking definition; it is not automatically
   mandatory merely because the app contains ads.
4. **Android upload signing is missing.** `android/key.properties` does not
   exist. Local release APK builds fall back to debug signing, while
   `bundleRelease` is deliberately blocked without upload-key configuration.
   Configure and back up the upload key, then build a signed AAB and use Play
   App Signing. Android's ignore rules already exclude signing properties and
   keystores; do not commit them.
5. **There is no current store bundle.** No AAB was found under build outputs.
   The newest existing ARM64 release APK is from 19 October, predating today's
   changes. It is not today's release candidate. Validate the final signed
   package, version, manifest, native-library compatibility and install/update
   behavior before submission.
6. **iOS signing/archive validation is incomplete locally.** No development
   team is configured in the Xcode project. A Mac with appropriate Xcode,
   signing/provisioning and a final archive is needed. The app-owned privacy
   manifest is present, but the final native SDK privacy report, archive
   validation and TestFlight results were not available.
7. **Store content and physical-device evidence remain incomplete.** Play has
   no app record, so its listing, audience, content rating, contains-ads, app
   access and Data safety setup are unfinished. App Store copy/screenshots
   exist locally, but are dated 18 October and require comparison with the
   final native build. `release/DEVICE_QA.md` still records physical-device
   checks as not run; that means no recorded sign-off, not proof that nobody
   has ever played the app on a device.
8. **Unfinished premium offers need a release decision.** Purchase-only shop
   items show disabled **Coming soon** actions and no live billing exists.
   These are not working purchases. Hide unfinished offers for launch or
   explicitly review their presentation; do not claim premium purchases work.

Android's current Flutter SDK configuration targets **API 36**, matching the
current published Play submission requirement. This is a source-level check;
the final signed AAB still needs inspection. The iOS deployment target of 15.0
is distinct from the SDK used to build the archive.

Cloud saves, accounts and online leaderboards are not implemented in this app.
Progress is local, with manual backup/import. These features are optional for
this launch and should not be advertised as available. Crashlytics is also not
integrated; it is a useful improvement rather than a store requirement.

## Automated results

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub lib test` | **Passed**, no issues. |
| Whole-workspace analysis | One warning in the archived `artifacts/reaver-baseline/pubspec.yaml`: a missing preview asset directory. This is not a production-source analyzer warning. |
| `scripts/release_check.py` | **Blocked**: missing Android upload signing and iOS signing team. Policy owner/contact/URL and the app-owned privacy-manifest checks passed. The script does not validate account readiness, consent implementation or store approvals. |
| Full `flutter test --no-pub --reporter expanded` | **733 passed, 9 failed**. |
| Focused sequential rerun of the failing scenarios | The same **9 failures reproduced**; 4 neighboring/parameterized cases passed. Parallel test execution does not explain these failures. |

Failure inventory:

| Test | Finding |
| --- | --- |
| `test/ascent_test.dart` — repeated analog lifts | Expected platform screen height 300; actual 321. Requires behavior/expectation review. |
| `test/classic_placements_test.dart` — authored hazard coordinates | Expected one spawned hazard; found none. Requires investigation of spawn timing and test setup. |
| `test/infinite_systems_test.dart` — shield after hole during fast swipe | Expected protection result differs from actual. |
| `test/infinite_test.dart` — long-running camera/course generation | Expected 500 metres; actual 498. Could be a changed pacing expectation; not classified as a confirmed gameplay defect yet. |
| `test/late_enemies_test.dart` — shot/shield contact order | Expected shield time remaining; actual zero. |
| `test/porcupines_test.dart` — quill/shield contact order | Expected shield time remaining; actual zero. |
| `test/snakes_test.dart` — snake/shield contact order | Expected shield time remaining; actual zero. |
| `test/spider_web_test.dart` — web/shield contact order | Expected shield time remaining; actual zero. |
| `test/widget_test.dart:164` — screen/safe-area test | **Outdated locator**: tries tapping the removed level name `First steps`. Update it to the level key before it can exercise layout. This failure does not itself prove a safe-area defect. |

Logs are in `artifacts/publishing-audit-tests-2026-10-22.log` and
`artifacts/publishing-audit-recheck-2026-10-22.log`. They are local audit evidence
in an ignored artifacts folder. No gameplay code was changed during this audit.

## Recommended order of work

1. **Publisher/account work first:** complete Play verification and AdMob's
   publisher/payment profile. Check Apple enrollment in an authenticated session.
2. **Code/release work:** triage the eight behavior failures and stale widget
   locator; implement consent handling; configure genuine ad IDs; decide whether
   unfinished premium cards stay visible. Reconcile policy and SDK disclosures.
3. **Build:** configure signing and produce fresh release candidates. Verify
   Android API/native-page-size compatibility and inspect the iOS archive's
   SDK privacy manifests and report. Record physical-device QA results.
4. **Store setup/testing:** create the Play listing, finish its content forms,
   prepare final assets, upload to testing and start the required closed test.
   Complete Apple listing/TestFlight/review steps if launching on iOS too.
5. **Production access and monetization review:** apply for Play production
   access after the qualifying test; link the public store listing in AdMob,
   verify app-ads.txt and complete app readiness review. Full ad serving can
   remain limited until that review finishes.

An ad-free first release is possible in principle, but requires hiding ad
offers and preventing unwanted ad-SDK collection. It does not remove account,
testing, signing, disclosure or gameplay-validation requirements. A public
Google Play launch today is not available from the verified account state.

## Current official requirements checked

- [Google Play personal-account testing](https://support.google.com/googleplay/android-developer/answer/14151465): eligible new personal accounts require at least 12 testers continuously opted in for 14 days before applying for production access. The console currently has no app to have completed that test.
- [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878): new mobile submissions currently require API 36 or later.
- [AdMob Flutter UMP integration](https://developers.google.com/admob/flutter/privacy): consent-information updates, required forms, privacy options and ad-request eligibility.
- [AdMob app-ads.txt verification](https://support.google.com/admob/answer/14538460): new apps need verification and readiness approval for full ad serving.
- [AdMob app readiness](https://support.google.com/admob/answer/10564477): payment/account verification and a supported public store listing are part of readiness.
- [Apple SDK requirements](https://developer.apple.com/news/?id=ueeok6yw): since 28 April 2026, iOS/iPadOS uploads require the iOS/iPadOS 26 SDK or later; verify the release Mac's toolchain.
- [Android native page-size compatibility](https://developer.android.com/guide/practices/page-sizes): verify final native libraries and packaging, rather than inferring compatibility from a Flutter widget test.
