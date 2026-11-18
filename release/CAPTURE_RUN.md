# Temporary App Store capture build

This is a separate Flutter entrypoint, not another shipped player mode. Normal
`flutter run` still launches `lib/main.dart`. Capture runs do not bank progress,
coins, stars or scores, request ads, or send analytics. It reads the equipped
ball, platform, cabinet and survival upgrades from the local profile.

**Shop · Change ball** opens the normal shop and provides a temporary minimum
wallet of 300,000 coins. Purchases and equipped choices are saved normally.
After returning from the shop, **Use shop appearance in replay** is enabled:
the selected ball/world and platform replace only the rendered appearance.
The recording's original equipment bonuses, magnet radius, score and physics
remain unchanged, so its checkpoints still verify. Turn the switch off to use
the original recorded appearance. A new recording uses the selected equipment
normally, including its bonuses.

## Record a Classic level on iPhone

The optional level entrypoint opens a separate level-recording menu:

```sh
flutter run -t lib/level_capture_main.dart -d YOUR_PHONE_UUID
```

When installing with Xcode, first select this Flutter entrypoint:

```sh
flutter build ios --release --config-only --no-pub -t lib/level_capture_main.dart
```

Then run Runner on the phone in Xcode. Xcode uses the most recently generated
`FLUTTER_TARGET`; building the normal app previously leaves it on `lib/main.dart`,
which does not show **Choose level to record**. A full build with
`flutter build ios --release --no-pub -t lib/level_capture_main.dart` also sets the
target and produces an installable signed app.

Choose **Choose level to record**, select any of the 80 unlocked Classic
levels, and play using two-finger control. The selected ball and platform are
used normally. The level holds its initial state until the first touch, then
records accepted inputs at 120 Hz with the same pause/autosave behavior as
Infinite. A level capture does not bank coins, stars or completion progress.

After a win or failed attempt, choose **Export JSON file**, then **Save to Files**.
**Record level again** starts a fresh attempt on that same level. Returning to
the level-capture menu allows choosing another level or exporting/replaying
the saved take. Only the latest level take is autosaved, so export takes you
want to keep before recording another. Level autosaves use a separate key
(`rollrise.appStoreLevelCapture.v2`), preserving the saved Infinite take.

Send the JSON to this chat. The same `capture_replay.dart verify/prepare`
commands validate and bundle it for the simulators. Classic files use format
version 2 with a validated level number and checkpoints for target progression,
timing, hazards, bonus star and final outcome. Existing version-1 Infinite files
remain compatible. The replay restores the recorded physics geometry while
rendering in each destination viewport, including iPad and expanded Duo.

Build `lib/main.dart` to return to the normal app. Neither capture entrypoint is
enabled by a normal Flutter launch; keep both for later filming until final
release cleanup.

## Record on a physical iPhone

Find the phone ID with `flutter devices`, then run:

```sh
flutter run -t lib/capture_main.dart -d YOUR_PHONE_UUID
```

You can also build this target for your signed physical-device installation:

```sh
flutter build ios --release -t lib/capture_main.dart
```

Choose **Record fixed Infinite run** and play with two fingers. Recording starts
at the first touch, not while waiting on the start screen. Each new take has a
fresh game with seed `7112026`, Venom Crown as its first boss, normal opening
speed, and no tutorial. Existing files retain their recorded boss configuration. Two-finger
inputs are stored as accepted game commands at 120 simulation ticks/second.
The recorder captures both simultaneous fingers, moves, releases and clearing
input on pause. The actual simulation uses the first touch's viewport geometry
for the remainder of this take, including if the display later resizes.

There are no recording labels in the live gameplay image. Pause at the desired
end (double-tap the top-right corner on wide screens), choose **Finish & save**,
then **Export JSON file**. In the iOS share sheet
choose **Save to Files**, then send the resulting `rollrise-capture.json` to this
chat. This manual export is the only sharing step; nothing uploads automatically.

The latest take autosaves locally every two simulation seconds and on pause or
backgrounding. Return to the capture menu after reopening the app to export the
saved take. A new recording replaces the local take once it starts saving, so
export takes you want to keep before starting another. An abrupt kill can lose
up to the most recent two seconds. Takes are limited to ten simulation minutes.

## Validate and prepare the returned file

```sh
dart run tool/capture_replay.dart verify /absolute/path/rollrise-capture.json
dart run tool/capture_replay.dart prepare /absolute/path/rollrise-capture.json
```

Both commands run the complete simulation and verify every recorded checkpoint.
`prepare` only writes `lib/capture_replay_data.dart` after successful validation.
It embeds validated JSON as base64, not executable code. Keep the physics rules
and equipped art unchanged between recording and filming. Bump `captureRules`
in `lib/capture_run.dart` if game physics or procedural generation changes.

To make a new first-boss variant from an existing take, use:

```sh
dart run tool/capture_boss_variant.dart original.json variant.json venomCrown
dart run tool/capture_replay.dart prepare variant.json
```

This validates the original first, resimulates its inputs with the new encounter,
requires that they survive the complete boss, and generates and verifies fresh
checkpoints. Outcomes after the boss can differ; this is a new take. The original
file is left intact. The current bundled Venom take clears its first boss from
2:13 to 2:41 and ends at about 2:53.

## Film the replay on simulators

After preparing a new take, rebuild the capture app at least once so the new
recording is embedded in the installed app. Hot restart changes the live session
only; reopening an older installed binary can restore its previous recording.
Reuse `--use-application-binary` only after rebuilding that binary for the new
take. The capture menu shows the bundled take's duration and final score.

Run each in a separate terminal, selecting the current simulator UUID:

```sh
flutter run -t lib/capture_main.dart -d DC9FB5F2-82A3-4CAB-AE7D-046AFEA4EC7D
flutter run -t lib/capture_main.dart -d 7AC349F9-3CFF-4D61-827F-0F7CA72232F8
flutter run -t lib/capture_main.dart -d B1C18170-EF39-4379-95FB-08127FB3C6FC
```

These are the 13-inch iPad, iPhone 18 Pro, and Duo currently used for this project.
On Duo, the collapsed display stays portrait and the expanded game supports both portrait and landscape.
Hold the expanded device horizontally (Rotate Right in Device Hub) for filming.
Wide landscape boards use a 46% rail span with full-width scenery; portrait boards retain their previous width.
Device detection and native rotation changes require a rebuilt app, not hot restart.
Choose **Play bundled replay**. Start Device Hub recording before the three-second
countdown; trim the countdown and completion panel from the exported video. Live
gameplay controls are ignored and the pause button is hidden during replay.
Backgrounding still pauses playback without changing inputs. Replay timing,
collisions, generation and outcomes use
the recording's simulation geometry, while the board renders in the destination
viewport. This is a recorded take, not a new wide-screen physics run.

A mismatched checkpoint stops with **Replay stopped** instead of silently
continuing a different scenario. Send that error and the recording for review.
After each complete take, return to the capture menu to replay from the start.

## Return to the normal app

Stop the capture process and rebuild with the normal target:

```sh
flutter run -t lib/main.dart -d DEVICE_UUID
```

This disables the recorder/replay UI without deleting the capture tools, saved
takes, or bundled recording. To use fixed capture again, rebuild explicitly with
`-t lib/capture_main.dart`. Normal Flutter launches use `lib/main.dart`.

Do not upload an archive built with `capture_main.dart` as the normal App Store
release. Restore the empty `capture_replay_data.dart` stub after filming so a
temporary recording is not kept in source control.
