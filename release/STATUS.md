# Rollrise: Ball Balance — release status

Updated 19 October 2026. Source version: 0.13.6+24. No app has been submitted.

## Current source

- Public app/store name: Rollrise: Ball Balance; launcher name: Rollrise.
- 80 authored Classic levels, Infinite, Number Merge, Daily and Practice.
- Progress, coins, gear, achievements and settings are stored on the device.
- Manual progress export/import and friend challenge codes exist.
- Firebase Analytics is configured for Android/iOS. Real-device event delivery
  still needs verification. Accounts and cloud saves are not implemented.
- Store copy and Flutter UI screenshots are prepared. Verify them against the
  final native build, including Duo inner landscape orientation support.

## Publishing work

Read [PUBLISHING_CHECKLIST.md](PUBLISHING_CHECKLIST.md) for the current launch
checklist, Firebase explanation, optional cloud-save scope and official sources.

The privacy policy is hosted at https://gilt-ead46.web.app/privacy-policy.html
and its URL is configured in the app source. Verified public HTTP 200 with the
correct title, publisher and contact. Rebuild the app to include this update.
Local preflight still identifies missing Android upload signing and the Apple
signing team. Ads use sample IDs; consent,
final SDK disclosures, real-device testing and store setup also need completion.

Google Play preparation is tracked in [GOOGLE_PLAY.md](GOOGLE_PLAY.md). The public
support/privacy email is vardan.torosyan40@gmail.com. Production rewarded ads
are requested but await AdMob IDs and consent implementation.

This source rename does not rebuild or rename previously generated APKs/web
builds. Existing old playtest binaries are not the new branded release candidate.
Build and sign the final release after completing the checklist.
