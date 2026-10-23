# Rollrise Android AdMob preparation

Updated 23 October 2026.

## Registered app and rewarded unit

- App: `Rollrise: Ball Balance` — Android, not yet linked to a public store.
- Publisher: `pub-8791729869708798`
- App ID: `ca-app-pub-8791729869708798~4165679478`
- Rewarded unit: `Rollrise_Rewarded_Android`
- Rewarded unit ID: `ca-app-pub-8791729869708798/6338923389`

These are public configuration identifiers, not credentials. Account approval
was confirmed by the owner's AdMob email on 23 October. The app separately
still showed Needs review; a public store link and app approval remain pending.

The Android manifest now uses the real app ID. `GoogleRewardedReviveAds` uses
the real rewarded unit in release builds and Google sample units in debug and
profile builds. `--dart-define=AD_TEST_MODE=true` forces sample rewarded units
in a release QA build. iOS retains its sample unit; this is an Android setup.

## app-ads.txt — published and verified publicly

The exact seller entry was read from this account's AdMob setup dialog:

```text
google.com, pub-8791729869708798, DIRECT, f08c47fec0942fa0
```

Source: `release/privacy-site/app-ads.txt`.
Firebase config: `firebase.privacy.json`, with an explicit plain-text content type.

Deployed successfully to the existing `gilt-ead46` Firebase Hosting site and
verified in the browser at:

<https://gilt-ead46.web.app/app-ads.txt>

When Play Console app creation becomes available, set the developer website
to `https://gilt-ead46.web.app` in the store listing contact details. Keep
the privacy-policy URL as `https://gilt-ead46.web.app/privacy-policy.html`.
Link the public store listing in AdMob when available, then request the
app-ads.txt check. Hosting the file now does not mean AdMob has already
verified store ownership or approved the app for full ad serving.

## Consent messages — published and verified 23 October

Both messages show **Published** with their publication switches enabled in
AdMob and are assigned to `Rollrise: Ball Balance` (Android):

- `Rollrise Android - European consent`: English, EEA/UK/Switzerland.
  Consent, Do not consent (all listed regions), and Manage options are available.
- `Rollrise Android - US privacy choices`: English (US), all current and future
  supported US states; Google's standard sale/sharing opt-out form is enabled.

The app's policy URL was set to the public policy below. The standard message
copy, default style and account advertising-partner settings were retained.
Publication dialogs advise that messages can take up to an hour to appear.
Native-device delivery has not yet been verified.

Console proof: `artifacts/admob-european-consent-published-2026-10-23.png` and
`artifacts/admob-us-privacy-published-2026-10-23.png`.

**Separate account action:** despite the earlier account-approval email, the
console currently displays a payment issue requiring verification of the
AdSense payments account. No identity/payment information was submitted here.
The owner's personal verification and separate app review remain outstanding.

### Published European settings

| Setting | Published value |
| --- | --- |
| Message name | `Rollrise Android - European consent` |
| App | `Rollrise: Ball Balance` / Android app ID above |
| Privacy policy | `https://gilt-ead46.web.app/privacy-policy.html` |
| Default language | English |
| Additional languages | None added; English is the configured default |
| Geography | EEA, UK and Switzerland |
| User choices | Consent, do not consent, manage options; retain access to choices rather than forcing consent |
| Copy | Google's standard consent copy, with the correct app name and policy URL |
| Advertising partners | Review the actual Google-advertising configuration; no extra mediation partners are configured in the app |

### Published US state privacy message

| Setting | Published value |
| --- | --- |
| Message name | `Rollrise Android - US privacy choices` |
| App | The same Android app |
| Privacy policy | The same public policy URL |
| Geography | All current and future supported US states |
| Language | English (US) |
| Choices | Google's standard privacy choices and applicable opt-out controls |

Review the intended target audience before setting child-directed/under-age
flags; those choices were not inferred from the game's artwork or genre.
An iOS ATT message is outside this Android setup and has not been created.

## Game integration — implemented 23 October

- UMP requests fresh consent information once per launch and presents the
  required form. The SDK's `canRequestAds()` is checked before SDK initialization
  and again before showing a loaded rewarded ad. Update failures use only UMP's
  existing eligibility; no app-owned consent strings override it.
- Options shows **Ad privacy choices** whenever UMP requires that entry point.
  Changing choices is rechecked before the next rewarded request.
- Rewards still require the earned-reward callback and dismissal. Load failures,
  denied eligibility and closing early grant no reward.
- Firebase Analytics is separate: collection is off by default. The optional
  **Share gameplay analytics** switch persists the choice. Analytics advertising
  storage, ad-user-data and ad-personalization consent stay disabled.
- The bundled and hosted policy source now describes these controls.

### Test and build commands

```powershell
.\scripts\flutter.ps1 test --no-pub test/ad_consent_test.dart test/rewarded_revive_ads_test.dart test/app_analytics_test.dart
# Safe local-device QA: keep sample rewarded creatives even in release mode.
.\scripts\flutter.ps1 build apk --release --no-pub --dart-define=AD_TEST_MODE=true
# Production ad unit; do not click live ads during QA.
.\scripts\flutter.ps1 build appbundle --release --no-pub
```

Focused suite: 22 passed. Static analysis of `lib` and `test`: no issues.
The full suite reported 749 passed and two Classic-layout failures:
`classic_progression_test.dart` (every hazard wave is assumed to cover all
10 targets; some current authored waves cover only target 1) and
`spiders_test.dart` (minimum target spacing). No level source was changed
for this AdMob integration. Logs are in `artifacts/admob-*-2026-10-23.log`.

### Still required before production sign-off

1. Complete the AdSense payments-account verification shown in the console.
   Both privacy messages are published; actual form delivery still needs QA.
2. Verify the UMP and rewarded flow on a physical Android device: first launch,
   consent/refusal, privacy changes, offline/unavailable ads, earned reward,
   dismissal without reward and retry. A channel test is not native-device QA.
3. Resolve/review the separate Classic-layout test failures.
4. Link the public Play listing and complete AdMob's separate app review and
   app-ads.txt ownership check. Account approval alone is not app approval.

References:

- [AdMob app-ads.txt setup](https://support.google.com/admob/answer/9363762)
- [Flutter UMP integration](https://developers.google.com/admob/flutter/privacy)
- [AdMob privacy and messaging](https://admob.google.com/v2/privacymessaging)

## Built artifacts

- Production AAB: `build/app/outputs/bundle/release/app-release.aab`;
  61,721,753 bytes; SHA-256
  `4b131206f38d6ff62e9644278d4622808affab992e671b2478581349b5ebb4ee`.
  Signature matches the configured upload key; real Android IDs, ZIP integrity
  and native ELF alignment verified. This is not uploaded or signed off.
- Safe test-ad APK: `artifacts/rollrise-admob-test-ads.apk`;
  60,696,373 bytes; SHA-256
  `c51e8d60000c19008dff4b2920fcaa83427a40059d419bd1e6fee53fa78220ce`.
  APK signature verified; sample rewarded unit present and live rewarded unit
  absent from the compiled ARM64 app. Do not upload this QA APK to the store.
- ADB found no connected device. Consent/refusal/privacy changes and actual
  rewarded playback have not been tested on a physical Android device.
- Updated privacy policy deployed and fetched successfully at its public URL.
