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

## Store listing

Updated 19 November 2026 against the launch source (coin store hidden,
Practice and the Halo Joystick no longer offered). Paste each field as is.

App name (30 max):

Rollrise: Ball Balance

Short description (80 max):

Tilt and lift the platform. 80 levels, endless climbs, bosses and Number Merge.

Full description (4000 max):

One ball. A moving platform. One more try.

Rollrise turns a simple balancing act into an arcade challenge. Lift and tilt the platform, control the ball's momentum and find your opening. Every small movement matters.

Master 80 Classic levels
Roll the ball into ten numbered holes in order. Read moving holes, laser rails and spider territories as the campaign mixes familiar skills into new challenges. Earn stars for finishing, playing clean and beating the time goal, and hunt for the bonus star in every level.

Climb forever in Infinite
Keep climbing through a course that never ends. Collect coins, build your combo, grab magnets and power-ups, and dodge incoming hazards. Face eight bosses, each with its own attack patterns, from the Storm Colossus to the Chrono Keeper.

Match and merge in Number Merge
Steer a numbered chain into equal or smaller numbers, combine matching values, avoid bigger ones and clear the gates. Build a longer chain with every run.

Make it yours
- Play with one finger, or control both ends of the platform with two.
- Unlock balls, platforms and visual worlds with coins earned in play.
- Upgrade your magnet, shield and hearts for Infinite runs.
- Come back for a fresh Daily challenge and daily prizes.
- Track achievements and personal records.
- Send a challenge code to a friend and see who scores higher.

No account needed. Your progress stays on your device, with a backup you can copy and restore. Optional rewarded ads can give you an extra heart or double your coins after an Infinite run.

Learn the feel. Read the pattern. Take one more shot.

Do not add: real-money coin packs, cloud saves, online rankings or Practice
mode. None of these are in the launch build.

## Official references

- Play personal-account testing: https://support.google.com/googleplay/android-developer/answer/14151465
- Store listing assets: https://support.google.com/googleplay/android-developer/answer/9866151
- Target API requirements: https://support.google.com/googleplay/android-developer/answer/11926878
- AdMob Flutter consent: https://developers.google.com/admob/flutter/privacy
- Native page-size support: https://developer.android.com/guide/practices/page-sizes
