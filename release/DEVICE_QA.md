# Android + iPhone release pass

Status: physical-device sessions and iOS build NOT RUN in this Windows workspace.

## Build and distribution

- Android: copy `android/key.properties.example` to ignored `android/key.properties`, supply an existing upload keystore, and confirm the application ID. Do not commit signing secrets. Gradle selects the real key when supplied; otherwise APKs remain development-signed playtest builds.
- Run `python scripts/release_check.py`. Fix every release blocker before producing a store candidate.
- Run `.\scripts\flutter.ps1 analyze --no-pub`, `.\scripts\flutter.ps1 test --no-pub`, and `.\scripts\flutter.ps1 build appbundle --release --no-pub` after the gate passes.
- iPhone: on a Mac, use Flutter/Xcode, `flutter pub get`, open `ios/Runner.xcworkspace`, set the registered bundle ID and signing team, then `flutter build ipa --release`. Install through the team's test distribution process and repeat the device checks below.
- Keep developer keys and profile exports out of screenshots and source control.

## Device matrix

Record build version, OS, model, control scheme and result. Include a small iPhone, a current iPhone, an older supported Android, and a current Android. One person can cover hardware checks; five first-time players cover usability.

| Check | Small iPhone | Current iPhone | Older Android | Current Android |
| --- | --- | --- | --- | --- |
| Cold launch / all tutorial controls | Not run | Not run | Not run | Not run |
| Classic / Infinite / Merge / Maze | Not run | Not run | Not run | Not run |
| Safe area / keyboard / enlarged text | Not run | Not run | Not run | Not run |
| Multitouch / rapid release / switch controls | Not run | Not run | Not run | Not run |
| Background / lock / call interruption | Not run | Not run | Not run | Not run |
| Sound / silent mode / Bluetooth / haptics | Not run | Not run | Not run | Not run |
| Restart / purchases with earned coins / backup restore | Not run | Not run | Not run | Not run |
| Offline Daily / friend codes / bad imports | Not run | Not run | Not run | Not run |
| 15-minute performance / battery / temperature | Not run | Not run | Not run | Not run |

## Performance protocol

Use profile mode on physical hardware and Flutter DevTools' Performance view. Capture the same 15-minute route across Classic, busy Infinite and long Maze runs. Record display refresh rate, UI/raster frame timings, long frames, battery percentage before/after, temperature warning and input response. At 60 Hz a frame has about 16.7 ms; at 120 Hz about 8.3 ms. Do not interpret widget-test timing or a desktop screenshot as mobile frame-rate evidence.

## Exit criteria

No blocked controls, unreadable critical information, missing progress after a normal restart, crashes, or unexplained unavoidable deaths. Investigate any repeated stutter or thermal throttling. Keep a screenshot/log and reproduction steps for every failed row. Human difficulty thresholds remain provisional until playtest findings are recorded.

## Official build references

- [Flutter Android release guide](https://docs.flutter.dev/deployment/android)
- [Flutter iOS release guide](https://docs.flutter.dev/deployment/ios)
- [Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)
