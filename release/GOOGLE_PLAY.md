# Rollrise: Ball Balance — Google Play preparation

Updated 19 October 2026. Nothing has been uploaded or published.

Publisher: Vardan Torosyan
Account status reported by publisher: Apple individual enrollment paid and pending;
Google Play registration fee not yet paid; AdMob not yet created.

Public support/privacy email: vardan.torosyan40@gmail.com
Android application ID: com.giltarcade.balance_arcade
Current source version: 0.13.6+24

## Account setup

Firebase Console manages Firebase services; it does not register a Play developer account. Open https://play.google.com/console and finish developer verification if requested. Confirm the public developer name before completing the listing and privacy policy.

Create the Android app in AdMob, using the Android application ID above. Supply its public App ID (ca-app-pub-…~…) and rewarded ad unit ID (ca-app-pub-…/…). Never share account passwords or signing secrets in chat. The current app still uses Google sample ad IDs.

## Release gates

- Configure production rewarded ads, UMP consent and a privacy-options entry point where required; verify analytics choices separately. Configure the associated messages in AdMob.
- Privacy policy hosted and verified: https://gilt-ead46.web.app/privacy-policy.html. URL configured in assets/privacy/policy.json. Rebuild the app and enter the URL in Play Console. Update policy wording when production ads/consent behavior changes.
- Configure an upload keystore locally through android/key.properties, keep it and its passwords out of Git, and retain a secure backup. Enable Play App Signing in Play Console. Release bundles are intentionally blocked until signing is configured.
- Build a signed Android App Bundle from the final source. Verify its version, package ID, API target, native-library page-size support and release configuration.
- Test on physical Android phones and a tablet: controls, pause/resume, progress restoration, all game modes, rewarded-ad earned/dismissed/unavailable flows, consent and network failures.
- Prepare Android-native screenshots, a 512×512 store icon and a 1024×500 feature graphic. Existing Apple screenshots require Android-specific capture and validation.
- Complete Play Console App content: contains ads, target audience, content rating, app access and Data safety based on the final SDKs and actual behavior. Review unfinished shop offers before release.
- Upload first to internal testing. If this is a personal account created after 13 November 2023, complete a closed test with at least 12 opted-in testers continuously for 14 days, then apply for production access.

Cloud saves are not implemented. Progress is local with manual backup/import. Do not advertise automatic Firebase cloud saves or online rankings.

## Store listing draft

Title: Rollrise: Ball Balance

Short description: Tilt, lift and balance your ball through clever challenges and endless runs.

Full description:

Find your balance in Rollrise: Ball Balance. Tilt and lift the rail to guide your ball through precise challenges, collect coins and keep each run alive.

Take on 80 Classic levels, chase your best run in Infinite, or combine numbered pickups in Number Merge. Return for Daily challenges and sharpen your control in Practice.

Choose the control style that feels right: One-Finger, Two-Finger or the floating Halo Joystick. The Halo appears where you touch, giving you a subtle guide while you play.

Unlock different balls, build your collection and share challenge codes with friends. Progress stays on your device, with manual backup and import available in the game.

Optional rewarded ads let you choose an extra chance or a coin reward in eligible Infinite runs. No account is required to play.

Draft only: validate every statement against the final Android release candidate.

## Official references

- Play personal-account testing: https://support.google.com/googleplay/android-developer/answer/14151465
- Store listing assets: https://support.google.com/googleplay/android-developer/answer/9866151
- Target API requirements: https://support.google.com/googleplay/android-developer/answer/11926878
- AdMob Flutter consent: https://developers.google.com/admob/flutter/privacy
- Native page-size support: https://developer.android.com/guide/practices/page-sizes
