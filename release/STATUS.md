# Rollrise: Ball Balance — release status

Updated 18 October 2026. Source version: 0.13.6+24. Nothing has been submitted.

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

Local preflight currently identifies missing policy publisher/contact/URL,
Android upload signing and the Apple signing team. Ads use sample IDs; consent,
final SDK disclosures, real-device testing and store setup also need completion.

This source rename does not rebuild or rename previously generated APKs/web
builds. Existing old playtest binaries are not the new branded release candidate.
Build and sign the final release after completing the checklist.
