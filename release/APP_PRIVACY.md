# Rollrise privacy release preparation

Status: policy draft and app manifest prepared locally. Public publishing, App Store Connect answers, and the final iOS archive Privacy Report are NOT completed.

## Policy and app access

`assets/privacy/policy.json` is the source for both the offline Settings > Privacy Policy screen and the public HTML page. Publisher, privacy-contact email, and public URL are deliberately empty until the owner supplies them. Do not invent these details or submit the current draft as final.

Once supplied:

1. Fill `publisher`, `contactEmail`, and `publicUrl` with the actual publisher, monitored email, and intended HTTPS policy URL.
2. Confirm the policy describes the final ads and analytics configuration. Firebase is now configured for Android and iOS in `gilt-ead46`; live collection and final SDK manifests still require device verification.
3. Run `python scripts/privacy_policy.py` to regenerate `release/privacy-policy.html`. Upload that file to the chosen public host. It has no scripts, trackers, fonts from external servers, or cookies of its own. The hosting provider's access logs still need to be considered separately.
4. Open the URL without signing in and verify its content on mobile. Enter the same URL in App Store Connect > App Privacy > Privacy Policy.
5. Run `python scripts/privacy_policy.py --check` and rebuild the app to bundle the updated policy. A passing local check does not verify hosting or App Store submission.

The bundled policy is readable offline. Google policy addresses are selectable and have explicit Copy link buttons; there is no new browser/URL SDK dependency.

## Data inventory and App Store Connect worksheet

Apple's labels include third-party SDK practices. A local save file alone is not off-device collection. Do not select **Data Not Collected**: Firebase analytics is now configured, and rewarded ads can process data even with test units.

| Feature | Current behavior | Disclosure action |
| --- | --- | --- |
| Progress, records, coins, equipment, achievements and settings | SharedPreferences storage on device | No off-device collection by the game's own save feature; account for device backups separately |
| Friend challenges | Name and result in a manually copied code; imports and friend list local | No automatic upload; reassess if online sharing/rankings are added |
| Progress backups | Explicit clipboard copy and pasted import | No automatic upload; recipients and clipboard/device sync may retain exported copies |
| Optional playtest recording | In memory, max 1,000 events, explicitly copied report | No automatic upload; if collected from testers by support, review the support data flow |
| Google Mobile Ads | Initialized/requested for an optional rewarded revive or run-coin doubling; sample app/ad IDs currently | Include the SDK's collection even when no game account exists. Final configuration determines purposes, linkage and tracking |
| Firebase Analytics | Configured for Android/iOS; initialization enables collection and logs gameplay events; live reporting not yet verified | Include SDK collection and gameplay usage in App Store privacy and Google Play Data Safety disclosures; verify final configuration, linkage, tracking, and consent |

For an ads-enabled candidate, start with **Yes, data is collected from this app**, then review these categories against the exact native SDK's manifests and Xcode's aggregate Privacy Report:

| App Store category | Why it needs review | Purposes to verify |
| --- | --- | --- |
| Coarse Location | Google can infer approximate location from IP | Third-Party Advertising, Analytics |
| Device ID | Advertising/app/device identifiers | Third-Party Advertising, Analytics |
| Advertising Data | Ads seen and ad events | Third-Party Advertising, Analytics |
| Product Interaction | Views, taps, launches and SDK interactions | Third-Party Advertising, Analytics |
| Crash Data | Ad SDK crash diagnostics | App Functionality, Analytics; advertising use where applicable |
| Performance Data | Ad SDK performance measurements | App Functionality, Analytics, Third-Party Advertising where applicable |
| Other Diagnostic Data | Include if identified in the final SDK report | Match its declared uses |

These are candidate answers, not submitted or verified final labels. For **each** selected category, answer purposes, **linked to the user**, and **used for tracking** using the final SDK configuration/report. No login and no IDFA permission do not by themselves establish that data is unlinked or that tracking is absent. If identifiers/data are joined across companies for ads or measurement, apply Apple's tracking definition and ATT requirements. The current project has no ATT or UMP consent flow; those are separate ads-release work and are not implemented by this privacy screen.

Firebase Analytics is now configured. Review its automatically collected device/app data, identifiers, and logged gameplay events (`mode_selected`, `run_started`, `run_finished`, `shop_opened`, including mode/control/level/practice, score, outcome and duration). Evaluate Product Interaction and Gameplay Content, and the SDK's identifiers and other collection, against Google's guidance. Final labels and Google Play Data Safety answers must include this data flow.

## App and dependency manifests

`ios/Runner/PrivacyInfo.xcprivacy` is included in the Runner Resources build phase. It declares UserDefaults reason **CA92.1**, for Rollrise's app-owned records/settings. It deliberately does not assert an app-wide `NSPrivacyTracking=false` or replace Google/Firebase collection declarations with empty arrays. A required-reason declaration is not a privacy label or consent mechanism.

The cached `shared_preferences_foundation` 2.5.7 package includes its own manifest and Swift Package resource declaration. Google Mobile Ads and Firebase use native packages resolved on the Mac; their complete built manifests cannot be verified from this Windows source tree. Flutter/framework manifests and transitive SDKs must also remain in the final app.

On the release Mac:

1. Resolve native dependencies and archive the exact release build with Xcode/Flutter.
2. In Xcode Organizer, use **Generate Privacy Report** for that archive and save the report with release evidence.
3. Inspect the archive's Runner.app and embedded bundles/frameworks for `PrivacyInfo.xcprivacy`; confirm the app manifest and manifests for all SDKs Apple requires are packaged. Verify plist validity with `plutil -lint`.
4. Reconcile SDK data types, tracking domains, and API reasons with the intended configuration and worksheet. Fix missing/invalid SDK manifests by updating the dependency or its packaging; do not delete vendor manifests or blindly copy unrelated reason codes.
5. Validate/upload the archive and resolve Apple's privacy validation messages. Complete the App Privacy answers in App Store Connect and verify the resulting product-page labels.

The public contact, hosted policy, final SDK collection/linkage/tracking answers, consent setup, and archive verification remain release prerequisites.

## Official references

- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple privacy-policy review requirement](https://developer.apple.com/app-store/review/guidelines/#privacy)
- [Apple required reason API categories and reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
- [Apple third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
- [Google Mobile Ads disclosure guide](https://developers.google.com/admob/ios/privacy/data-disclosure)
- [Firebase App Store disclosure guide](https://firebase.google.com/docs/ios/app-store-data-collection)
