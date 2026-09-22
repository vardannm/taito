# Firebase Analytics setup

The app includes Firebase Analytics, but reporting is inactive until a real
Firebase project is configured. No Apple or Google Play store account is needed.
Unconfigured builds and analytics failures do not prevent gameplay.

## Connect your project

1. Open https://console.firebase.google.com/ with your Google account, create a
   project for GILT, and enable Google Analytics during project creation.
2. Install the Firebase CLI and sign in with `firebase login`. Install FlutterFire
   with `dart pub global activate flutterfire_cli`.
3. From this repository, run
   `flutterfire configure --project=YOUR_PROJECT_ID --platforms=android,ios`.
   This replaces the placeholder
   `lib/firebase_options.dart` and generates/registers the native configuration.
   Use these existing application identifiers:
   - Android: `com.giltarcade.balance_arcade`
   - iOS: `com.giltarcade.balanceArcade`
4. Rebuild the app. Firebase initialization enables analytics collection. Merely
   hot reloading is insufficient after adding native Firebase configuration.
   Build and validate iOS on a Mac with Xcode.

Keep the generated Firebase options and native configuration with the app source.
They identify the project; do not add service-account private keys to the app.
For web, configure an additional web app with FlutterFire before testing reporting.

Official setup: https://firebase.google.com/docs/flutter/setup

## Events

| Event | Trigger | Parameters |
| --- | --- | --- |
| `mode_selected` | Initial mode shown, or selection changes | `mode` |
| `run_started` | First control input on a preview, or a direct level launch | `mode`, `control`, `level`, `practice` |
| `run_finished` | A started run reaches its end | Above plus `won`, `score`, `active_seconds` |
| `shop_opened` | Gear Shop is opened | `mode` |

Boolean parameters use 0/1. Refreshing the same mode (for example after closing
the shop) does not record another selection. Starts and finishes are deduplicated
per run. Leaving an unfinished run is not reported as a completed run. Practice
runs are marked so they can be filtered. The SDK also collects its standard
automatic events. Custom events include no names, emails, or custom user IDs.

## Verify live reporting

On an Android test device, enable DebugView events:

```powershell
adb shell setprop debug.firebase.analytics.app com.giltarcade.balance_arcade
```

Launch the app, swipe to another mode, open the shop, start a game, and finish it.
Check Analytics > DebugView in Firebase for the four events and their parameters.
Disable Android debug mode afterwards:

```powershell
adb shell setprop debug.firebase.analytics.app .none.
```

On iOS, launch through Xcode with the `-FIRDebugEnabled` argument to verify events.
Use `-FIRDebugDisabled` afterwards. Standard dashboard reports are delayed;
DebugView is the appropriate integration check. Register event parameters such as
`mode` and `control` as custom dimensions if you want to use them in GA reports.

Official DebugView guide: https://firebase.google.com/docs/analytics/debugview

Before store release, reflect the configured Firebase data collection in the
app's privacy policy and store privacy disclosures.
