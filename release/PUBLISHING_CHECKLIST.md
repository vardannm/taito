# Rollrise: Ball Balance — publishing checklist

Source audit: 18 October 2026, version 0.13.6+24. Nothing has been submitted.

## What Firebase does today

| Data or feature | Current implementation |
| --- | --- |
| Gameplay analytics | Firebase Analytics configured for Android/iOS; mode selections, run starts/finishes and shop opens are sent when available. Real-device delivery is not yet verified. |
| Stars, levels, scores, coins, owned gear, achievements, settings | Saved locally using SharedPreferences. Not uploaded as a restorable player profile. |
| Accounts and sign-in | Not implemented. |
| Automatic cloud backup / cross-device restore | Not implemented. Manual copied-text backup/import exists. |
| Online leaderboards / online friends | Not implemented. Challenge codes and friend comparisons are local/manual. |
| Firestore / Realtime Database | No client integration or player database implementation in this source. Remote Firebase console state was not audited. |

Analytics answers questions like "which modes are played?" It is not a save-game
backup. Reinstalling, clearing storage or changing devices can lose progress
unless an applicable OS backup restores it or the player retains a manual export.

Cloud saves are optional for a local/offline launch. Do not advertise automatic
restore, online rankings or cloud sync as available.

## Required work before a store release

- [ ] Supply the legal publisher name, monitored support/privacy email, and public
  HTTPS privacy-policy URL. These are blank in assets/privacy/policy.json.
  Regenerate and host the policy, then verify the URL without signing in.
- [ ] Complete App Store privacy disclosures against the final Firebase/ads
  configuration and native SDK privacy reports. Include third-party collection.
  Configure consent where required; ATT is required if the final setup tracks
  users under Apple's definition. The app currently has no UMP or ATT flow.
- [ ] Choose the ads launch configuration: configure real AdMob app and rewarded
  unit IDs plus the appropriate consent/privacy-options flow, or disable the ad
  feature and SDK collection for an ad-free launch. Current IDs are Google's
  samples, not a completed monetization setup. Verify actual rewards on device.
- [ ] Hide unfinished premium purchase offers, or implement and test the store
  billing, purchase restoration and product configuration before selling them.
  Current purchase-only balls show "Coming soon" and have no live billing.
- [ ] Configure the Apple Developer signing team on a Mac. Resolve native
  dependencies, archive the release build, inspect its Privacy Report, validate
  it and test through TestFlight. Android release additionally needs its upload
  keystore; local Android signing is currently development signing.
- [ ] Test real iPhone and iPad controls, safe areas, performance, sound,
  interruptions, saved progress, backup/import and ad outcomes. Test the final
  build offline and after restarting the app. See DEVICE_QA.md.
- [ ] Reconcile Duo inner landscape support with the native build: the screenshot
  target is landscape, but main() currently requests portrait orientation. The
  widget renderer does not exercise native orientation handling. Implement and
  verify the intended orientation/layout before using those screenshots.
- [ ] Set the store name to Rollrise: Ball Balance and confirm its availability
  in App Store Connect. Complete support URL, age rating, distribution regions,
  pricing, screenshots and review information. Compare Flutter-rendered store
  images with the native release build. The source rename is not a published
  listing change or name reservation.

The local preflight reports missing policy owner/contact/URL, Android upload
signing and the iOS signing team. Its passing result would not verify the manual
steps above. Evidence: artifacts/rollrise-release-preflight.log.

## If automatic cloud saves are wanted

1. Choose a recoverable player identity/sign-in. An anonymous ID alone does not
   provide reliable recovery after reinstalling or moving to a new device.
2. Add Authentication and Firestore (or another chosen backend), per-player save
   documents, migrations, ownership rules and rule tests. Avoid public databases.
3. Implement local-first sync, version/conflict resolution, offline retry and
   clear restore behaviour for coins, purchases and progress. Competitive scores
   and paid entitlements need appropriate server-side validation.
4. Add account/data deletion and update the policy and disclosures. Test account
   linking, reinstall/restore, two devices, interrupted writes and deletion.

This is a separate feature project, not enabled by the existing Analytics SDK.

## Official references

- [Firebase products for Flutter](https://firebase.google.com/docs/flutter)
- [Firebase Authentication](https://firebase.google.com/docs/auth/flutter/start)
- [Apple submission preparation](https://developer.apple.com/app-store/submitting/)
- [Apple privacy and tracking](https://developer.apple.com/app-store/user-privacy-and-data-use/)
- [Google ads consent setup](https://developers.google.com/admob/flutter/privacy)
