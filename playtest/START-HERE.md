# GILT first-player test

Status: ready to run; no participant results collected.

## What this test answers

Can a new player discover the two pivot grips, understand the objective, and enjoy enough control to choose another run? This small qualitative test does not estimate revenue or market demand.

Start with five people who have not seen the game. Include some casual mobile players and some who rarely play. Use anonymous IDs P01–P05. Keep each session to about 10 minutes. Use the same build and device setup for this first group; record the device so tablet results are not mistaken for phone results.

## Build and setup

- Android test APK: `../build/app/outputs/flutter-apk/app-release.apk`. This is an ARM64 development-signed release build with direct pivot dragging and the proportional-board fix.
- Browser preview on the development computer: http://127.0.0.1:8080/. This address works only on that computer; it is not a public invitation link.
- iPhone testing still requires a signed native build made with Flutter and Xcode on a Mac. Android and desktop observations do not validate iPhone touch feel.
- Use a phone in portrait where possible. Confirm the current build shows grips on the platform, no bottom control buttons, and circular holes. Keep sound at a comfortable level.
- Open the home screen before each participant. Do not show a demo or explain the grips first. Avoid showing the participant this document.

## Moderator script

Read: “Please try this unfinished game as you normally would. You can stop whenever you want. We are testing the game, so getting stuck is useful feedback. Say what you think is happening when you can.”

### 1. Discover Classic — up to 3 minutes

Say: “Start Classic and see what you can figure out.” Start a timer when the board appears. Let them read or open help on their own.

Record the time to intentionally move either pivot, the time to move both, whether they discover two-finger use, and whether they understand the glowing target. Record the first successful target if they reach it. A ball loss is not necessarily the end of a run: Classic gives three balls.

If they cannot move a pivot after 45 seconds, ask “What are you trying to do?” If still blocked after another 15 seconds, say “Try dragging an end of the platform.” Mark that assistance explicitly; subsequent success is assisted.

After their first ball loss, ask “What do you think happened?” Do not immediately explain the answer.

### 2. Observe replay — up to 2 minutes

At the first completed run, stay quiet for 15 seconds. Record whether they choose another run without a prompt, go home, or stop. If they have not finished a run within the allotted time, mark this observation as not reached, not as a refusal to replay.

Then say: “You can keep playing or stop. Either is useful.” Record the choice separately from the unprompted replay observation. Do not count a replay requested by the moderator as voluntary.

### 3. Try Infinite — up to 3 minutes

Say: “Please try Infinite.” Do not describe the red floor in advance. Observe whether they understand that all holes are traps, notice the holes moving down automatically, use the pivots to dodge, and understand the rising red floor after leaving the controls idle. Record whether the approach speed gives enough time to react and whether they feel any need to repeatedly lift the platform despite automatic ascent.

If red never appears, record not observed. After a loss ask “What ended that run?” Record their explanation and whether they choose to retry. Note any finger obstruction, missed grip, surprising pivot movement, or apparent unfair hit.

### 4. Debrief — 2 minutes

Ask these neutral questions:

1. “What was hardest to understand?”
2. “Tell me about a moment when the game did something you did not expect.”
3. “Which mode would you choose to play again, if either? Why?”
4. “What would you change first?”

Record exact short quotes. Avoid “Was it fun?” or “Would you pay?” as evidence of demand. Optional ratings belong after observation, not before it.

## Interpret the first five sessions

Use `SESSION.md` once per participant and `RESULTS.md` for the group. Leave unknowns blank or mark not observed; never substitute zero.

- Prioritize a usability fix when at least two independent players hit the same obstacle. This is a working triage rule for this small group, not an industry benchmark.
- Separate unassisted success, assisted success, and not reached. Report counts with their denominators, not impressive-looking percentages from five people.
- If control confusion dominates, tune the grips or onboarding before adding progression features.
- If players understand the game but describe losses as unpredictable, inspect collisions, finger obstruction, speed, and difficulty.
- If controls are understood and losses feel fair but people stop, investigate the challenge and reward loop. Cosmetics alone may not solve that.
- If players voluntarily retry, that is encouraging early evidence. It does not establish next-day retention or commercial viability.

Fix the most repeated issue, then test with five new players. Do not change the build halfway through a group without recording the change. Actual next-day return requires a separate test that makes the game available on participants' own devices; asking whether they would return is a different measure.

No analytics, uploads, participant contacts, or invitations are included in this kit. Record observations manually; do not record video or identifying details without the participant's agreement.
