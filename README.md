# Rollrise: Ball Balance

A Flutter game built around the mechanical ball-and-bar challenge: two independently controlled ends, a rolling steel ball, ten numbered targets, and three chances. The public name is Rollrise: Ball Balance.

For launch requirements and the current Firebase/local-save status, see
[the publishing checklist](release/PUBLISHING_CHECKLIST.md).

## Play on this Windows computer

Open this folder in VS Code, select **GILT â€¢ Browser preview**, and press F5. A project-local Flutter SDK is installed in `.tools/flutter` and selected in `.vscode/settings.json`.

Alternatively:

```powershell
.\scripts\flutter.ps1 run --device-id=chrome
```

Controls: drag the left or right handle up and down. Two-finger handles sit 64 screen pixels below their connected platform ends so your thumbs stay clear of the ball; near the bottom edge, they use the space above instead. Both fingers work independently; release to hold that pivot. In Infinite, release and grab again for another upward swipe. Carousel previews fit the complete board. Phone gameplay keeps its existing full-width scale and vertical framing. From 600 logical pixels wide, the complete board fits the available height; the connected rails and platform span about 74% of the window width. Horizontal positions spread across this arena while balls, targets, platform thickness and text retain their proportions. Input and collisions follow the visible geometry, including after resizing or unfolding. Infinite's actual climbing camera is unchanged. On desktop use **W/S** for the left end, **Up/Down** for the right, and **Esc** to pause.

Wide menus scale their typography and main controls by 1.15–1.5 while retaining accessibility text scaling. Landscape windows at least 1000 pixels wide place the mode preview beside the actions; portrait tablets keep the stacked arrangement. Settings and other menu sheets constrain reading width, and pause/results use a larger centered panel. Phone menu dimensions are unchanged. `tool/render_wide_layout.dart` exports menu, Classic gameplay, pause and Settings previews for phones, closed/expanded Duo, tablets and desktop windows.

During wide-screen play, the equipped world's scenery fills the entire window. Background blur increases smoothly from zero around the sharp playfield to full strength at the outer edges. A darker backdrop, continuous ambient ribbons and restrained gold effects keep gameplay readable. The wide HUD groups lives and progress on the left, with the wallet, distinct run earnings and pause control on the right. This applies to Classic, Infinite, Number Merge, Daily and Practice. The scenery picture is cached by palette and viewport; two blended blur passes affect only background artwork. Phone and carousel artwork retain their original layout and have no extra blur passes. `tool/render_wide_panorama.dart` exports all five modes in phone, Duo, desktop and Nebula-theme samples, plus maximum-combo scenes.

Settings offers illustrated, animated cards for **One-Finger Control** (default for compact windows), **Two-Finger Control**, and **Vertical Analog Control**. Movement response is fixed at 1.0, including older saves and imported backups. Settings closes with its pinned X or a rightward swipe; vertical gestures scroll its content. Vertical analog places two independent joysticks at the bottom inside the safe area. Drag up to raise that platform end, down to lower it; the platform follows directly with about 19% less sensitivity. There is no dead zone. Horizontal movement is ignored. Release centers the knob and holds the final platform position; grab again to continue moving. One finger drags the lower handle left/right to set tilt and up/down to raise or lower both ends. Once held, vertical dragging continues beyond the thumb area and reverses immediately, without a pad-edge movement cap. The visible pad and knob keep the same design; the knob stays drawn within the pad. Holding the handle pauses the control mode’s automatic lift in Classic; release resumes it. Infinite’s continuous board ascent remains active. Classic automatically lifts at 20 world units/second and waits at the current target height, so a target cannot be left behind. All three modes share ball physics. All touch targets are consumed on the next 120 Hz physics tick without smoothing or an added delay. Keyboard motor easing remains. Ball acceleration and its speed cap increased by about 8%.

Swipe to Classic to continue the saved level directly. The small arcade icon → Classic levels opens a winding road with only five levels around the furthest unlocked level. The window moves forward as stars unlock new levels; distant levels and chapter counts stay hidden. Normal builds enforce star requirements; the developer level bypass is off by default and disabled in release builds. Each Classic board has ten targets, three lives and four available stars, with no points score. Level 1 is open initially; level N requires `2 × (N − 1)` total Classic stars (level 2: 2, level 10: 18, level 50: 98). Stars are permanent, not spent, and each distinct objective counts once across control methods. Daily stars do not unlock Classic boards. Locked cards show the earned/required count. Winning offers **NEXT LEVEL** when its requirement is met, or **EARN MORE STARS** and replay options otherwise; the selected level is remembered. Deterministic scattered layouts vary target positions, heights, and numbering so targets no longer follow a single route. Trap layouts develop through wider steering, slaloms, gates and alternate routes, easing when a new hazard appears. Practice retains its original board and unlimited attempts.

Levels 31â€“50 form **The web**: one slow patrolling spider at first, two from level 36, and three from level 43. Dashed circles and background webs mark their territories. Crossing a boundary starts a persistent chase; physical contact instantly ends the run and removes the ball, without an eating animation. Territories and spiders turn red during pursuit. Spider patrols and chases continue while the ball sinks and the platform returns. Only starting or replaying the whole level resets them; pause freezes them. Territory placement keeps target holes clear and checks connected space from the launch area to every target. Human difficulty still needs playtesting.

## Mastery, daily boards and cabinet styles

Classic and Daily award three independent objective stars: finish, finish without a miss, and finish within the active-time target. Classic also has one collectible gold star per level, replacing its coins. Collecting it adds a permanent progression star only when that run is won; losing or abandoning the level leaves it available on retry. It can only be earned once across all controls and disappears on replay after a successful collection. Classic has four stars per level (320 total), target progress and time records, with no score or personal-best points display. Daily retains its score and three objective stars. Earned objectives merge across retries.

Active time excludes pauses, capture animations, and the bar returning to launch. Initial time targets use board elevation, the control mode's lift speed, trap count and a finale/spider allowance. They are provisional until human playtesting; adjust the `targetTime` calculation in `BalanceGame.start` in `lib/game.dart`.

Classic's single optional star sits in reachable space, clear of holes and spider territories. Daily retains optional brass coins beside traps: each adds 250 points and can be collected once per run across ball resets. Infinite spawns random coins ahead of the climb, with a separate in-run coin counter. Coins stay clear of holes and beams and disappear after scrolling below the board. Practice has no collectibles or progression rewards.

Milestone Classic boards introduce or combine mechanics; learned hazards also return between milestones. Level 10 introduces a warned laser lane; level 20 a warned roaming hole; level 30 alternates them; level 40 has a larger spider keeper; level 50 combines the keepers with alternating laser lanes and roaming holes. A briefing pauses the simulation until the player starts. Finale lasers/roaming holes cost one ball, while spider contact ends the run. Warnings last at least 2.4 seconds; first introductions allow longer warnings and a six-second opening. Their movement, warning/live phases and wave schedule continue through target captures and ball returns; only a new level run resets them. The hidden ball takes no damage during its return, and an enemy already overlapping the respawn point cannot hit it until they separate.

**Daily** uses a fixed board generated from the UTC date with an explicit integer random generator, consistent across web and native platforms. The date is pinned for an ongoing run and its retry, even across midnight; opening Daily again selects the current day. Records are local and separate from Classic, with 32 days of history retained for all control modes. No online leaderboard or account service is connected.

**Shop → Cabinet Styles** offers Original brass plus Jade garden (3 Classic stars), Porcelain club (12), and Ember forge (30). Each style changes the cabinet finish, ball and platform colors with identical physics and hitboxes. Stars earned with either control count toward each board's four unlock stars; Daily stars do not unlock Classic cosmetics. The equipped style persists. Existing global records and preferences are retained.

**Tilt Only** is the temporary fourth control option in Settings. Drag the bottom slider sideways to set the angle; release to keep it. The lift control is hidden for this trial, so there is no manual lifting.

Classic levels temporarily always use **Tilt Only**, including previews, retries and next-level launches. Other modes retain the saved control preference. The level picker shows Tilt Only records for this trial.

**Board Tilt** is a fifth test option. Drag sideways anywhere on the board to set the angle, with no lift or fixed bottom control. A small guide appears at the contact only while held. Release keeps the angle; re-grab anywhere without a jump. Use the mode arrows/dots or swipe the header to change games before starting.

**Ball worlds:** All 19 balls include a distinct scene, from Coral Lagoon and Neon City to Polar Lights and Event Horizon. Equipping a ball changes the playfield and surrounding colors in every mode, including frozen carousel previews. Infinite combo energy changes the palette while preserving the scenery; losing the combo restores the equipped world. Shop cards preview the actual world before purchase. Cabinet styles still control the frame and trim. World artwork and palettes live in `lib/ball_world.dart`; they do not affect movement, collision, prices, or bonuses.

## What is implemented

- Original ivory, brass, and deep-teal art direction; procedural engraved playfield and original app icons.
- Fixed 120 Hz physics with rolling-sphere acceleration, motor smoothing, inertia, speed limits, and swept hole collision detection.
- Ten targets in sequence. Each capture animates the ball sinking and the bar returning to the launch position.
- Three-ball Classic; an endless Infinite climb; and unlimited-attempt Practice with slower motors and slightly more forgiving target capture.
- Streak multipliers up to 4Ã— and speed bonuses. Time rewards precision without ending slow runs.
- Original synthesized audio, optional haptics, separate persistent Classic/Infinite records and run counts.
- Tutorial, settings, pause, replay, lifecycle pause, input cancellation, and reduced-motion support for board effects.
- iOS project with portrait orientation and GILT branding; web build support with bundled renderer assets.

Daily and Practice scoring: (target number * 100 + max(0, 35 - climb seconds) * 10) * multiplier. Multiplier increases every three consecutive targets; misses reset the streak. Classic has no points score. Infinite and Number Merge retain their own scoring rules.

## First-time onboarding

On first launch without a saved control preference, the app selects **Two-Finger Control** when the app window's shortest side is at least 600 logical pixels, otherwise **One-Finger Control**. Compact layouts, including a closed Duo, offer One-Finger, Two-Finger and Halo Joystick. Expanded Duo and other large layouts hide the original One-Finger pad and offer Two-Finger and Halo. The same rule applies in Settings and the level picker. A saved pad preference temporarily uses Two-Finger while expanded, then returns when compact again; an explicit new choice remains saved. Rotating a compact phone does not make it a large layout. Saves and backups preserve the preferred control, rather than the temporary fallback. Folding only clears held input when the effective control changes, without restarting the run.

New players begin inside Infinite with the selected control. A short, interactive course highlights the controls, one avoidable hole and hearts, a coin, a shield, score, and a combo crystal. Real input and swept contacts advance the lessons; missed pickups return, and an accidental hit costs one heart without resetting the run. Afterward, 45 seconds of active, ordinary Infinite play run without overlays, or a natural run ending finishes that section. Guidance resumes only back at the menu.

The Shop introduces one free ball and platform through actual Equip actions, then allows normal browsing. Levels highlights Level 1, whose gradual target route and three simple hazards form the final gameplay test. Winning Level 1 completes gameplay onboarding. Daily is introduced only on the subsequent menu visit. Number Merge receives no onboarding in this flow.

Spotlights follow live board and widget coordinates, with short tooltips, pulsing outlines, reduced-motion support, and Skip Tutorial. Settings → Replay Tutorial restarts only onboarding and selects One-Finger; coins, owned gear, records, and stars are retained. Existing saved control preferences are respected on normal launch, and legacy profiles with play history bypass automatic onboarding.

`lib/onboarding.dart` defines the checkpoints and course controller. `gilt.tutorial.v2` saves stages and free-play time separately from records, with ordered writes. An interrupted session recreates the unfinished stage instead of repeating completed lessons. `tool/render_onboarding.dart` exports actual phone layouts to `artifacts/onboarding/`.

## Infinite mode

The app opens directly onto the Infinite board, including on first launch. The board waits without advancing physics, timers or score. Touch the selected joystick, thumb area or platform grip to begin; the same held gesture immediately controls movement. W/S or the arrow keys also start the run and move the platform. Swipe across the environment, header or free space to select three worlds: Infinite, Classic Continue, and Number Merge. Classic shows its saved level (level 1 for a new profile); Classic still respects star locks. All three prepared boards start on their selected controller or movement keys, without a Play button. Page edges, parallax, scale, title fades and a three-position indicator guide navigation. Swipes snap one world at a time and never claim touches in the actual control areas. Once a run begins, swipe recognition is removed. The selected scene expands from an 88%-width carousel viewport into the full gameplay area over 437 ms; neighboring previews fade away. The remaining selector chrome fades out during the final 123 ms. The same board and controllers stay mounted and preserve the starting touch as their layout grows. Returning home freezes the run and reverses this animation before preparing the current world; a normal application opening always selects Infinite. The arcade icon retains level picker, Daily, Practice, Gear Shop, goals and the guide. Settings offers Replay Tutorial. Start with three hearts. Holes, live lasers, moving holes, platform gaps and the rising red floor cost one heart. A hit resets combo to x1 and removes combo effects. When hearts remain, the ball and platform stay on their current trajectory with the same tilt, momentum and held controls. A small heart appears above the platform, floats upward and fades out over 0.85 seconds; this independent effect never changes input or life state. They blink gently during 2.5 seconds of protection so the player can steer away; there is no relocation, platform reset or touch reset. The camera, holes, hazards, rising floor and generation progress continue normally. Reduced motion uses a steady protection ring. The third loss ends the run. Pausing freezes all gameplay and power-up timers.

**Pace x1–x5** advances continuously by one level per 600m. Every run starts at 68 world units/second. Base speed uses a smoothstep curve over 2,400m (previously 900m), with the same 216-unit extreme cap including pace bonuses. Hole density takes the lower of the 60,000-point curve and distance difficulty, so high-tier gear and combos cannot skip the opening. Initial spacing is 210–240 units, tightening toward the existing dense patterns later. Distance points still count only new peak height.

Gold diamond **combo crystals** build x1–x10 and award `50 × new combo × pace level × gear multiplier` points. Further crystals at x10 award a flat +300 points with a visible MAX COMBO notice; missed pickups preserve combo and a lost heart resets it. Early mint, blue, violet and coral colors progress through dark violet, midnight, indigo (8x), electric cyan (9x), and warm gold (10x). The HUD marks the maximum. Particle counts, platform arcs, glow and ball energy rise gradually; sparks use batched paths with no per-particle blur. Reduced motion keeps a quiet static tint/aura. The high-tier render-budget test limits total draw calls and offscreen layers.

Shield pickup, refresh and expiration preserve active touch ownership, drag position and pending movement. The shield status line reserves its space, so effects do not resize the board or controller. Blue **shield** pickups grant 10 seconds of invincibility against every Infinite hazard, with a countdown and a visible ring around the ball. Invincibility preserves hearts and combo. Pink **heart** pickups rarely appear while a heart is missing. Hearts cap at three; one already on the board grants a point bonus if collected at full health. Pickups and moving hazards resolve in swept contact order, so a shield must be reached before it can prevent a collision.

Coins appear more often than crystals; shields and hearts are much rarer. Offscreen pickups are pruned and the extra collectible list is capped at 12. Each 360m cycle has a rush and recovery; encounter time grows gradually after 600m to its full share at 2,400m. Special hazards unlock at 450m (forming holes), 900m (moving holes), 1,500m (lasers), and 2,250m (platform gaps). Warnings begin farther apart, reaching the same minimum spacing late in a run. Complex sweeping/zigzag variants gradually become common from 2,400m to 4,200m. Spider encounters begin later and closer spacing develops with distance. Only one special hazard runs at once, with harmless warnings before activation. Once a forming hole opens, its world coordinates are fixed and it remains until it scrolls off-screen. Camera movement from manual lifting is included in both rendering and collision. Moving-hole types retain their intended movement. Off-screen pruning happens after swept collisions, so a fast camera lift cannot skip a hole. A winding clear route and hole separation remain. After three seconds without steering the red floor rises; deliberate steering stops its active rise.

**GEAR SHOP** in the Modes menu spends Infinite and Laser Endless coins. It contains **11 balls and 6 platforms**, each with a permanent point bonus displayed before purchase. The active gear multiplier is `1 + ball bonus + platform bonus`, up to x5. Gear multiplies Normal Infinite distance and combo points; other modes retain their scoring rules. Physics, collision size and platform handling stay the same. Existing owned balls automatically receive their new bonus; no repurchase is needed. Coins and gear ownership save locally without an account. The Number Merge mode retains its numbered ball for readability. Cabinet styles remain in Settings.

Tune lives, durations, starting speed, pace levels, the 60,000-point density threshold, collectible spacing, coin spacing and visual intensity in `lib/infinite_progress.dart`. Survival integration is in `lib/infinite_gameplay.dart`; visuals are in `lib/infinite_painter.dart`. Economy saves use ordered snapshots to prevent an older coin save from undoing a purchase. This is device-local progress, with no account sync.

## Android build and installation

The project-local Android SDK is in `.tools/android-sdk`. The Flutter wrapper selects it automatically. Enable USB debugging and authorize the connected computer on the phone, then run:

```powershell
.\scripts\flutter.ps1 build apk --release
.\scripts\flutter.ps1 install -d YOUR_DEVICE_ID
```

The APK is generated at `build/app/outputs/flutter-apk/app-release.apk`. This device-test build uses the generated development signing key, not a Play Store release key. Android has the GILT display name, original vector launcher icon, matching splash colors, and portrait orientation.

## Validate and build

```powershell
.\scripts\flutter.ps1 analyze --no-pub
.\scripts\flutter.ps1 test --no-pub
.\scripts\flutter.ps1 build web --release --no-pub --no-web-resources-cdn
```

The release preview is in `build/web`. Serve it over HTTP, for example:

```powershell
python -m http.server 8080 --bind 127.0.0.1 --directory build/web
```

Then visit http://127.0.0.1:8080. Use a phone-shaped window, or F5 for development with hot reload.

`tool/render_preview.dart` exports real Flutter screen renders to `artifacts/` and generates each native icon directly from vector drawing commands. Run it with `flutter test tool/render_preview.dart`. `scripts/generate_audio.py` regenerates the original sound cues.

## iPhone build

Use a Mac with Flutter and Xcode. The `.tools` SDK in this Windows workspace is Windows-specific; use your Mac's Flutter SDK and update/remove the local SDK selection in `.vscode/settings.json`. Run `flutter pub get`, open `ios/Runner.xcworkspace`, select your signing team and a bundle identifier you own, then run on an iPhone or simulator. The generated identifier is a development placeholder.

Native iOS compilation, signing, real-device haptics/audio, and frame-time profiling require that Mac/iPhone pass. They have not been verified on this Windows machine.

## Commercial status

This is a playable, tested game build, not an App Store submission or a revenue guarantee. Infinite offers one rewarded-ad revive per run on Android/iOS, using Google's sample app IDs and rewarded test units. Earning the reward and dismissing the ad continues the same run with one heart and three seconds of protection; the next game over has no ad offer. Skipped or unavailable ads give no heart. Desktop/web skip the offer. Ad units live in `lib/rewarded_revive_ads.dart`; native app IDs live in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`. Replace test IDs and complete release setup before monetizing. See `PRODUCT.md` for the proposed release and monetization sequence.

## Code map

- `lib/game.dart`: independent simulation and run state.
- `lib/levels.dart`: 50 scattered Classic boards, spider territory placement, and route clearance checks.
- `lib/level_picker.dart`: responsive numbered level grid.
- `lib/spiders.dart` and `lib/spider_painter.dart`: patrol, swept territory/contact detection, pursuit, and web visuals.
- `lib/board_painter.dart`: procedural board, ball, and capture effects.
- `lib/hazards.dart` and `lib/hazard_painter.dart`: timed Infinite traps, swept collision, and warning visuals.
- `lib/tutorial.dart`: optional illustrated tutorial, opened from Modes → How to play.
- `lib/main.dart`: responsive screens, tutorial, keyboard/touch controls, and lifecycle.
- `lib/profile.dart`: persistent per-board/per-control records, daily history, cosmetic unlocks, settings, sound, and haptics.
- `lib/rewards.dart`: star records, stable daily seed, Infinite section tuning, and cosmetic thresholds.
- `lib/mastery_widgets.dart` and `lib/cabinet.dart`: result goals, Daily/Cabinet screens, finale briefing, and cosmetic palettes.
- `test/`: progression, rewards, daily determinism, hazard timing, physics, reachability, small-screen, and multitouch checks.
- `tool/render_mastery.dart`: exports actual Flutter renders for the new reward, daily, finale and cabinet screens.
- `playtest/MASTERY.md`: a 5â€“10 player session plan for this update; no human results have been collected by the build process.


Infinite hard encounters: from 2,400m, encounter sections increasingly alternate sideways sweeping lasers and top-entry zigzag holes. Both warn for two seconds; only one special hazard is present at a time. Lasers sweep 65 units either side of their origin for 3.5 seconds. Moving lasers display blinking direction chevrons before activation; fixed beams have no arrows, and countdown labels identify FIXED or MOVING. Reduced-motion mode keeps direction arrows steady. Spiders in the starting Steel world use a light body and legs against its dark scenery. Zigzag holes cross a 250-unit horizontal range and descend at 1.35 times board speed plus 35 units/second. Tune these in lib/hazards.dart and scheduling in lib/game.dart.

## Number Merge

Each finished run reaching a 2,048 ball or higher banks 30 coins once, including runs that end in a loss. The prize appears on the results screen and can be earned again on another run.

Choose **NUMBER MERGE** from the home screen. Steer the solid head ball into descending numbers. The largest value stays at the head of a translucent snake, with smaller values trailing downward. Values are sorted largest to smallest. Collecting another 2 with **32, 16, 8, 4, 2** combines all five matching powers into **64**.

Matching values combine anywhere in the snake. Every intermediate merged value adds to score. Glowing rings mark numbers that match any current segment. The solid head ball collects numbers; faint segments pass through numbers.

The snake trails downward from the main ball, which retains its full horizontal travel range. Growing or merging the tail never lifts the platform or shifts the camera; at the bottom of the board, the tail can extend off-screen. A matching pickup can collapse the chain into a larger number, and longer chains compress their spacing. Length does not end a run. The next gate requirement and matching number stay above the board.

Opening waves contain only safe numbers. Dangerous third pickups begin at a 4 head with a one-third chance, rise to two-thirds at 8, and appear every wave from 16. From head 64, the second pickup can also be dangerous: 15% at 64, 30% at 128 and 45% from 256. Every wave retains one reachable tail match; safe second pickups explicitly target an existing segment 40% of the time, with other values filling gaps. Pickups stay separated across the board. The solid middle ball can collect only values equal to or below its current value. Touching a larger value ends the run immediately; a red ring and an exclamation mark identify it. Ghost segments pass through pickups. Danger is evaluated at contact, so an earlier merge can make a later number safe.

The first horizontal gate arrives at **900 merge score**. After each clear, the next gate needs fresh score equal to the greater of **900 or the current main-ball value**, plus a **3-second minimum cooldown**. Score earned while a gate approaches does not queue old gates. Each new gate displays at least the current main-ball value and at least double the previous gate, fixed when it spawns. An 8,192 head therefore receives at least an 8,192 gate and must grow to pass. The main ball must be **strictly greater** than the displayed number. Only one gate appears at a time. Fast swipes resolve pickups and gates in contact order; pause freezes both streams and replay resets the run.

Play continues automatically through 2048 and beyond, without a win screen or confirmation. Number labels use 1024 = **1k**, 2048 = **2k**, 1,048,576 = **1m**, and 2,097,152 = **2m**; underlying values and merge scores remain exact. Records are local and separate from other modes, and the run is recorded when it ends.

Tune number/gate spawning, merge logic and spacing in `lib/merge.dart`. `lib/board_painter.dart` draws the centered snake, warning rings and gates; colors, compact labels, gate status and loss UI are in `lib/merge_widgets.dart`. `tool/render_merge.dart` exports staged Flutter screenshots of the centered example, its merge to 64, active play past 2048, millions, long snakes, and both loss conditions.

Moving balls now leave a short teal-to-gold wake and a soft glow that responds to speed. The effect is visual only, pauses with gameplay, fades while stationary and clears on restart. Reduced-motion mode omits the wake.

Gear tables are in `lib/ball_cosmetics.dart` and `lib/platforms.dart`; animated control cards are in `lib/control_options.dart`, and Settings dismissal is in `lib/settings_sheet.dart`. Regenerate phone renders with `tool/render_refinements.dart`.

The revive screen shows a coin summary above the heart: total wallet in gold,
and the exact coins collected this run in mint. The wallet already includes the
run's banked coins. The floating gameplay badge is hidden during the revive
offer. Run `tool/render_settings_and_coins.dart` for phone previews of Settings
and this summary. Daily Prizes no longer displays the reset-time footer.

### Coin economy

New app profiles start with zero coins. Automatic testing credits and the `GILT_UNLIMITED_COINS` build flag have been removed. Automated shop fixtures can still explicitly construct an unlimited profile, using an economy separate from saved player wallets.


## Interactive onboarding and arcade club (0.11.0)

The first-run tutorial now uses a real isolated practice game. Pick Two-finger, One-finger or Vertical Analog, lift and release, tilt the ball, and catch the glowing target. NEXT unlocks after doing the action; reset, back and skip remain available. Replay it from How to Play. Tutorial progress does not award coins or game records.

Open the arcade icon or Settings → Goals, friends & backup. Goals follow the selected control scheme: finish the campaign, then earn clean and time stars. The club shows cabinet unlock progress and opens the suggested level directly.

Daily friend challenges use a copied `GILT1` code containing a display name, date, controls and personal best score. Paste a friend's code to play that exact Daily board. Scores are friend-reported and stored locally, not server-verified rankings. Friend challenges are capped at 30 on-device entries.

Manual progress backups include records, wallet, owned/selected gear and settings. COPY BACKUP puts a versioned JSON snapshot on the clipboard; save it outside the app. RESTORE validates the snapshot and previews its progress before replacing local data. Test-economy snapshots cannot restore into normal builds. Friend codes and playtest logs are separate and are not part of a progress backup. No automatic cloud sync or online account is connected.

The optional local playtest recorder is in the same club screen. Start a session, replay the tutorial and observe the player, then stop and copy the report before closing the app. It captures up to 1,000 events without names or uploads. Starting another session replaces the in-memory report. See `playtest/NEXT_SESSION.md`; human sessions are still pending.

Normal builds respect saved wallets. Launching or restarting the game does not grant testing coins.

Release preparation: `python scripts/release_check.py`, `release/DEVICE_QA.md`, and `release/STORE_COPY.md`. Android release signing reads ignored `android/key.properties` when configured; without it the APK remains development-signed. iOS compilation, signing and physical-device tests require the release Mac/iPhone. Review screenshots can be regenerated with `flutter test tool/render_growth.dart`.

Privacy preparation: Settings > Privacy Policy reads `assets/privacy/policy.json` offline. Run `python scripts/privacy_policy.py` to generate `release/privacy-policy.html` from the same text. Publisher, contact email, and hosting URL are pending; the release check flags these fields. `release/APP_PRIVACY.md` contains the data inventory, App Store disclosure worksheet, and final iOS archive verification steps.

Firebase project `gilt-ead46` is registered for the existing Android and iOS identifiers. Both native configuration files and shared Dart options are included; Android uses the Google Services plugin and iOS includes its plist in Runner Resources. Analytics initialization enables gameplay reporting. See `ANALYTICS.md` for device DebugView verification. Web/desktop analytics are not configured; live event delivery and the iOS build still require device/Mac checks.

Infinite coin bonus: after losing with more than 10 collected coins, supported mobile devices offer a rewarded ad to double that run's coins once. Choosing this offer ends the run instead of reviving it. The bonus equals the run's collected coins; the existing wallet balance and collection ledger are unchanged. Skipped/unavailable ads keep the original coins and allow a retry. A revived run can double its final coin total at its last game over. This uses the current Google test rewarded-ad adapter until production ad setup is completed.


## One-finger thumb area (0.11.1)

### Floating Halo joystick trial

Options > Choose your controls now includes **Halo Joystick** as the third choice,
alongside the original One-Finger and Two-Finger controls. Tap Play, then touch
anywhere on the board and drag sideways to tilt or vertically to lift/lower.
The Halo appears at that touch point at 42% opacity and disappears on release,
cancel or pause. It has no fixed bottom pad. Re-grabbing starts at the new touch
point without jumping the platform; holding still does not create extra lift.
The original one-finger option remains the default and can be selected again.
The trial preference saves locally and travels with progress backups; it shares
the original one-finger physics, stars and score records.

### Original thumb pad

One-finger controls sit in a 96-pixel area below the board, keeping the ball above your finger. Touch anywhere in the area and drag sideways to tilt, up/down to move vertically. Release and re-grab wherever comfortable; touching a new point does not jump the platform. Vertical dragging can continue beyond the visible pad. A second pointer is ignored and pause/cancel clears the active touch. This shared control appears in gameplay and the tutorial. Two-finger controls are unchanged.

### Lightweight carousel previews

Only the snapped page owns a live `BalanceGame` environment. Inactive pages use frozen previews with the selected ball’s world. The live world changes only after the snap finishes; there is one simulation ticker, stopped during selection, pause and return. Merge resources are created only when needed and released when leaving the mode.

Previews are drawn from the current level data and equipped ball. No per-level
PNG assets or preview-generation step are required.

Use `tool/render_mode_transitions.dart` for expansion, full-game, floating-heart and reverse-animation frames. Reduced motion switches layouts immediately and uses a stationary heart fade. The analog control artwork is unchanged.
While a mode waits for its first input, a touch-transparent finger icon demonstrates the selected controls: two vertical drags over the platform grips or analog sticks, or a diagonal tilt/lift drag over the one-finger pad. The hint stops immediately on input, hides during a carousel swipe or return transition, and reappears when selection is ready again. Reduced motion shows a stationary finger. This uses a separate, disposable visual animation; the waiting game simulation remains stopped and analog artwork is unchanged.
## Editing individual Classic levels

The 80-level campaign follows an introduction, practice, variation and mastery
rhythm. Levels 2–9 widen steering and mix target heights gradually. Light gates
introduced at 10 and roaming holes introduced at 20 return between milestones.
The web introduces one, two and three keepers with breathing room, then recalls
the learned hazards. Levels 51–55 introduce circles, 56–60 ovals, 61–65 moving
vertical lasers and 66–70 moving horizontal lasers, recombining earlier skills
between introductions. Levels 71–80 change wave order and return to territories;
80 combines all four motion types with three keepers. See
[the complete level review](CLASSIC_PROGRESSION.md) for each board's intent,
threat counts, safety checks and playtest checkpoints. Every movement center,
radius, period, orientation and target assignment remains editable in its file
or the developer builder.

The 80 Classic layouts live in `lib/classic_levels/level_01.dart` through
`lib/classic_levels/level_80.dart`. Each file contains the level name, hole coordinates, spider patrol centers,
and laser/moving-hole spawn positions and timing. `lib/classic_levels.dart` registers them in saved-progress order;
`lib/levels.dart` loads them and retains the shared gameplay rules and Daily generator.
See `lib/classic_levels/README.md` for editing and audit instructions. Level IDs
and names stay stable so earned progress remains attached to the same boards.

## Developer-only level builder

Run `.\scripts\level_builder.ps1`, then open `http://127.0.0.1:8765`.
The visual builder runs separately from the game and is not shipped to players.
It supports holes, spiders, lasers, moving holes, undo/redo, JSON drafts and Dart export.
Save an exported `level_81.dart` in `lib/classic_levels/`, then run
`.\scripts\register_levels.ps1` to update the registry and bake previews before rebuilding.
See `tool/level_builder/README.md` for the complete workflow.


## Gameplay presentation and customization

Gameplay has no header above the board. A translucent on-board HUD carries score,
distance/time, combo/lives and Pause. Portrait boards extend upward into the
available height using the same uniform scale and hit-test transform. Infinite
spawns holes and pickups ahead of this larger visible region. Classic
previews have a centered Choose Level button with the current number and name.

Settings has independent Sound Effects and Music switches, saved as `gilt.sound`
and `gilt.music`. Existing muted profiles remain muted when migrating; either
switch can then be changed independently.

Enemy audio uses 21 original synthesized cues: insect/wing entrances, snake
hisses, distinct boss arrivals, bullet volleys, ricochets and rail rebounds,
crystal/petal shots, laser charge/fire, throws and pool landings, mine bursts,
comet warnings/rain, webs and quills. `lib/enemy_sounds.dart` observes physics
transitions at 120 Hz, groups volleys and suppresses nearly simultaneous repeats.
`lib/enemy_audio.dart` preloads short PCM assets into low-latency pools, mixes
without stealing music focus, and caps playback at four enemy voices. Pause,
mute, background, home and disposal cancel active/pending effects. Hit/coin
feedback retains its separate player. Regenerate cues with
`scripts/generate_enemy_audio.py` (NumPy); the script also writes
`artifacts/enemy-sound-preview.wav`. Laser charge/fire use transformer buzz,
corona hiss and irregular electrical arcs; rebuild just those two with
`scripts/generate_enemy_audio.py --only laserCharge laserFire`.

Infinite uses `assets/audio/theme_infinite_complex.mp3`, **The Complex** by
Kevin MacLeod: futuristic synths and percussion with its recorded opening and
gradual build intact. The original stereo MP3 loops continuously, with playback
level reduced to leave effects headroom. `lib/infinite_music.dart` gently raises
playback from 104 to about 116 BPM as active time and height-based pace increase.
Music starts with the first playing input. A new run restarts the opening;
pause and resume preserve its position. Tempo updates retain the track's position
and are coalesced during loading. Other modes are quiet. Previous WAV soundtracks
remain archived outside the asset bundle. Attribution is available in Settings >
Music credits. Source, CC BY 4.0 license and the original recording checksum are in
`assets/audio/CREDITS.md`; music and effect switches remain independent.

The main Shop contains Balls (23), Platforms (16), and Cabinet Styles. New gear
includes pearl, malachite, titanium, opal, plasma, comet, quasar and singularity
balls, plus carbon, pearl, aurora, plasma, celestial and sovereign platforms.
Premium gear uses bounded orbit sparks, light channels and short trails; physics
and collision sizes stay shared. Owned items and equipment continue to save by
their stable names. Cabinet unlocks still use Classic stars.

Coin ball prices rise gradually from Coral at 60 coins to Singularity (Black
Hole) at 13,500 coins. The 21 October balance pass raises later tiers more
strongly after a player reached Black Hole in about three hours at its old
2,400-coin price. This is a provisional economy curve, not a measured unlock-time
target. Existing ownership, wallets, coin rewards, platform prices and the
daily gift system are retained.

After Singularity (Black Hole), the reserved store-purchase tier adds Aether,
Phoenix, Chronosphere and Genesis, with four matching platforms after Sovereign.
Each has distinct procedural artwork; every ball also includes its own world.
Ball bonuses rise from +4x to +6.5x with permanent magnet radii of 78, 90, 105 and
120; platform bonuses rise from +3.5x to +5x, for a maximum combined x12.5.
These eight items show Coming soon until store billing is connected. Coins,
unlimited-coin mode and daily gifts cannot unlock them. Existing owned store
entitlements can equip and persist, ready for later billing integration.
`tool/render_premium_gear.dart` renders the actual artwork and shop screenshots
to `artifacts/premium-gear-gallery.png`, `artifacts/premium-gear-shop.png` and
`artifacts/premium-platform-shop.png`.


Infinite tuning: `lib/infinite_difficulty.dart` includes `spiderSpeed` (base chase speed) and `spiderBulletSpeed` (web flight speed), in world units per second. Magnet fields pull rewards toward the ball; their bonuses activate only on physical collection. The Infinite HUD centers the score and combo without a distance readout.

Late Infinite enemies unlock by distance: Bombardier Beetle at 2,600m (marked
acid lob), Ricochet Cricket at 3,100m (one wall rebound), Moth at 3,600m (paired
curving dust streams), Scorpion at 4,100m (a charged continuous laser), and Seed
Spitter at 4,600m (a slow seed splits into three). Introductions wait for a clear
attack slot; milestones do not spawn an enemy on top of an existing warning.
Each visitor locks its aim and warns for 1.2s. Only one visitor is active, with
at most twelve projectiles for the Moth's six paired volleys; other ranged attacks, snakes, and special hazards wait
their turn. Breathing sections block new visitors while active attacks finish;
laser-maze sections wait for the current visitor's attack and exit to complete.
Beetles require a clear side-step route through the existing terrain; their acid
lasts 2s and scrolls with the floor. Flying shots and enemy perches stay in screen
space. All attacks respect shields, recovery, pause, restart, and rewarded revive.
Tune `lateEnemyMilestones` and `lateEnemyRestSeconds` in
`lib/infinite_difficulty.dart`; projectile tuning is in `lib/infinite_progress.dart`.
The simulation is in `lib/late_enemies.dart` and vector art in
`lib/late_enemy_painter.dart`. Render the warning/attack gallery with
`scripts/flutter.ps1 test tool/render_late_enemies.dart`.

Infinite shuffles all five second-tier bosses once per run, with no repeats.
The five encounter score windows remain 90,000–120,000, 270,000–330,000,
550,000–650,000, 850,000–950,000 and 1,200,000–1,350,000 points; any boss can
occupy any slot. Pause and revive preserve the chosen order.
Sky Warden waits for committed attacks and laser mazes to
finish, then replaces the course with a clear arena: no holes, other enemies,
ordinary lasers, or rising red floor. The boss stays above the player as the
board climbs. Over 28 active seconds it fires five bullet fans, three warned
lasers, and three throws of two amber pools. Landing circles warn for 0.9s;
the pools cost a heart on contact, respect shields and recovery, and scroll
with the floor. The boss leaves automatically and normal generation resumes
ahead of the viewport, preserving the run and score. Pause freezes the whole
encounter; restarting resets its milestone. Tune and preview it in
`lib/infinite_boss.dart`, `lib/infinite_boss_painter.dart`, and
`scripts/flutter.ps1 test tool/render_infinite_boss.dart`.

Storm Colossus appears once per run in its shuffled encounter slot.
Its cyan and violet armored body has floating gauntlets instead of wings;
its fired orbs and crescent blades use toxic dark violet with vivid pink cores
or edges.
Across its 28-second encounter it fires eight energy orbs that each rebound
once from a rail, eight crescent blades in alternating wide/narrow curved
pairs, then six stationary laser mines with black discs and red laser streaks.
Mines mark their entire blast circle
for 1.35 seconds before a 0.65-second damaging burst. The arena stays clear of
ordinary holes, enemies, lasers and the rising red floor. All boss milestones
survive a rewarded revive and reset on a new run; if a score jump crosses several,
the shuffled order is preserved. Thresholds are sampled once per run using a
seeded random stream. At least 60 seconds of ordinary active gameplay separate
encounters. Boss entry waits for committed attacks, mazes, recovery and five
seconds after damage, then gives a three-second warning; pausing freezes the
warning. Preview: `artifacts/infinite-colossus.png`.

Eclipse Seraph appears in its shuffled slot with the same pacing and
clear-arena rules. Its six layered
gold-and-rose feathers unfold on arrival, a segmented halo rotates behind its
crown, ribbons sway, and its crystal core pulses and charges with its attacks.
The 28-second encounter sends 16 curving crystal petals, six warned laser
curtains with wide escape lanes, and nine comets with marked, locked trails.
All attacks finish before departure. Preview: `artifacts/infinite-seraph.png`.
Sky Warden now has iridescent wing beats, a swaying body, charging accents and
firing pulses. Colossus has independently floating/recoiling gauntlets,
spinning turbines, thruster flames and a charging reactor. Visual motion uses
the encounter clock, freezes on pause, and respects reduced motion without
changing attack geometry. All three stay within 65 drawing calls per frame
without blur or offscreen layers. Render animation frames with
`scripts/flutter.ps1 test tool/render_boss_animation.dart`.

Prism Reaver appears once per run in its shuffled slot after the usual rest interval. Its mint
and pink prism body keeps moving while firing: two single sweeping lasers,
then two volleys of paired moving lasers, then twelve independently spinning
rotors. Lasers charge harmlessly for 1.1 seconds and sweep for 1.65 seconds;
warnings show the sweep extent, and twin beams retain a wide escape lane.
Rotors mark their curved paths for 0.8 seconds, then follow three varied motion
patterns with randomized spread, phase, amplitude and spin. Patterns are seeded
per run and never home on the ball. Rendering and swept collision share moving
beam endpoints; pause, shields and recovery retain their existing behavior.
All attacks end before departure, and the boss stays within the existing
65-call drawing budget. Preview: `artifacts/infinite-reaver.png`.

Venom Crown appears once per run in its shuffled slot. Its attack forms a moving poison maze: 17 dense walls with
24 toxic lime bullets each, acid-yellow cores and magenta rims. Five slalom
walls lead into five walls that pulse their travel speed, then seven faster
accelerating walls with a narrower opening. Each formation warns for 0.9s;
the preview traces the actual moving gap. Every overlapping wall shares the
same continuous escape corridor, which never becomes narrower than 64 units.
Its direction is seeded and its first opening uses the player's position;
subsequent shots never track the player. All 408 bullets clear before the
boss departs. The real rolling-physics survival test crosses the full encounter
from left, center and right starts, in both seeded directions, without shields
or lost hearts. Rendering batches the bullets within the existing drawing
budget. Preview: `artifacts/infinite-venom-crown.png`.

The beetle steps and opens its shell, the cricket crouches and kicks on firing,
the moth beats its patterned wings, the scorpion curls its tail and claws, and
the seed spitter sways its leaves and recoils. Poses follow the encounter clock,
with fixed aim and collision geometry. Reduced motion keeps a steady pose.
Warning dashes and insect legs use batched paths with no blur or extra layers.
`tool/render_late_enemy_motion.dart` generates an enlarged animation preview.

Debug and release launches both use the normal saved wallet with no automatic testing credits. Existing balances are preserved; old test grants are not subtracted from wallets that may also include earned coins.

### Number Merge difficulty configuration

Edit `lib/merge_difficulty.dart`, just like `lib/infinite_difficulty.dart`, then hot restart and begin a fresh Merge run. The 22 October harder defaults start at 42 units/second, add 8 per doubling, cap at 112, and space waves 96 units apart.

- `startSpeed`, `speedPerDoubling`, `maxSpeed`: falling-ball speed and its growth.
- `waveSpacing`: distance between waves; higher values give more time to react.
- `initialRowSpacing`, `orbSeparation`, `rowJitter`: opening layout and spacing within waves.
- `dangerChance`: maximum chance the third ball is larger than the head (0 to 1), reached at a 16 head.
- `secondaryDangerChance`: maximum second-ball danger chance, ramping from head 64 to the maximum at 256.
- `matchingChance`: chance the second safe pickup targets an existing segment (0 to 1).
- `gateInterval`: minimum fresh score between gates; the actual gap grows with the main ball.
- `gateSpeedBonus`, `gateCooldownSeconds`: gate travel speed and minimum pause after a gate clear.
- `gateValueOffset`: power-of-two adjustment to the head-based requirement; 0 uses half the head, 1 uses the head (the current default), and 2 doubles it. Each gate still at least doubles the previous gate. The head still needs to be strictly greater than the gate.

For an easier starting point, try `startSpeed = 24.0`, `speedPerDoubling = 2.0`, `maxSpeed = 50.0`, `waveSpacing = 140.0`, `dangerChance = 0.5`, and `gateValueOffset = -1`. Increasing `gateInterval` raises the minimum score gap; gate numbers follow the main ball independently. Supported ranges are documented beside each setting and checked by assertions in debug/test builds.
