# Rollrise Android AdMob preparation

Updated 23 October 2026.

## Registered app and rewarded unit

- App: `Rollrise: Ball Balance` — Android, not yet linked to a public store.
- Publisher: `pub-8791729869708798`
- App ID: `ca-app-pub-8791729869708798~4165679478`
- Rewarded unit: `Rollrise_Rewarded_Android`
- Rewarded unit ID: `ca-app-pub-8791729869708798/6338923389`

These are public configuration identifiers, not credentials. The game still
uses sample ad IDs; this preparation does not enable production ad requests.

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

## Consent-message settings prepared for the console

**Status: prepared below, not yet saved or published in AdMob.** The standard
European-regulations page repeatedly left its embedded editor at `about:blank`.
Opening the observed embedded-editor URL directly displayed its landing page,
but the Create action did not advance outside the AdMob parent container.
A fresh parent tab also remained blank. No working editor or published message
could be verified, so the following settings must not be treated as active.

### European regulations

| Setting | Prepared value |
| --- | --- |
| Message name | `Rollrise Android - European consent` |
| App | `Rollrise: Ball Balance` / Android app ID above |
| Privacy policy | `https://gilt-ead46.web.app/privacy-policy.html` |
| Default language | English |
| Additional languages | Enable supported translations for the final launch regions when available |
| Geography | EEA, UK and Switzerland |
| User choices | Consent, do not consent, manage options; retain access to choices rather than forcing consent |
| Copy | Google's standard consent copy, with the correct app name and policy URL |
| Advertising partners | Review the actual Google-advertising configuration; no extra mediation partners are configured in the app |

### US state privacy message

| Setting | Prepared value |
| --- | --- |
| Message name | `Rollrise Android - US privacy choices` |
| App | The same Android app |
| Privacy policy | The same public policy URL |
| Geography | Applicable supported US states, using AdMob's current regional options |
| Language | English initially; supported translations as appropriate |
| Choices | Google's standard privacy choices and applicable opt-out controls |

Review the intended target audience before setting child-directed/under-age
flags; those choices were not inferred from the game's artwork or genre.
An iOS ATT message is outside this Android setup and has not been created.

## Required game integration after console messages are available

1. Configure the genuine Android application ID in the manifest and use the
   rewarded unit only for intentional production builds; retain test ads for QA.
2. Request updated consent information at every app launch with UMP.
3. Load/show any required form and check `canRequestAds()` before initializing
   or requesting ads as appropriate to the integration.
4. Provide a privacy-options entry point whenever UMP requires it.
5. Treat Firebase Analytics choices separately: the current app enables
   analytics at startup; merely preparing an AdMob message does not gate that.
6. Test eligible, refused, unavailable/offline and privacy-choice-change paths
   on a real Android device with Google's supported test configuration.

These code changes are not included in the signing-only build made today.

References:

- [AdMob app-ads.txt setup](https://support.google.com/admob/answer/9363762)
- [Flutter UMP integration](https://developers.google.com/admob/flutter/privacy)
- [AdMob privacy and messaging](https://admob.google.com/v2/privacymessaging)
