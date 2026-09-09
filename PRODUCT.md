# GILT product direction

## The promise

A beautiful pocket machine you can understand in seconds and keep trying to master. Two thumbs give direct control; the ball keeps its momentum. Every miss should be explainable and every success should feel earned.

## The first release

Classic is the central challenge: clear ten holes with three balls. Practice teaches the mechanics without punishing experimentation. Infinite is a continuous upward survival climb: avoid all holes, score new height, and stay ahead of a red floor that rises when progress stalls. It has one ball and a separate height record. The current version includes all three modes. Before adding content, watch first-time players on real phones: can they move both ends, understand the lit target, and explain why they lost a ball?

Tune motor speed, inertia, target capture radius, and trap spacing from those sessions. Geometric path tests prove routes exist; they do not prove a comfortable human difficulty curve. Prefer a repeatable, legible challenge over excessive random failures.

## Current mastery update

The build now includes per-board stars and personal records, optional risk–reward coins, five chapter finales, Infinite pressure sections, a deterministic UTC daily board with local records, and four cabinet palettes unlocked through Classic stars. The daily board has no online rankings; platform account setup is pending. Existing mechanics have automated checks, but time-star thresholds and human difficulty still need real-phone playtesting. Use `playtest/MASTERY.md` for the next 5–10 participants.

## A commercial path to test

1. Validate the game with a small external iPhone playtest. Track tutorial completion, first-target completion, voluntary retries, session length, and next-day return only after a deliberate analytics/privacy implementation.
2. Tune the existing 50 boards, finale timings and star thresholds from playtest observations. Cabinet finishes are implemented; check target contrast and controls on physical phones.
3. Test a paid full-game unlock or cosmetic pack after players demonstrate replay interest. The current build contains neither purchases nor paywalls.
4. If testing advertising, prefer an optional placement between finished runs. Do not interrupt steering or require an ad to practice. A revived run would need a separate score category to keep records comparable.
5. Connect platform leaderboards to the implemented daily board after account setup and core tuning. Server-backed competitive integrity and account services remain separate work.

Price, acquisition spend, and revenue projections should come from observed conversion and retention, not guesses. A polished game gives us something credible to test; it does not establish demand by itself.

## Still needed before store submission

- Native iPhone build/signing and device playtests, including small displays and interrupted audio.
- Frame-time and battery profiling on older supported phones; render capture alone cannot validate 60 fps.
- Final brand/name availability, store icon review, screenshots, support contact, description, and age rating.
- Any selected purchase/ad/analytics integration, with restore and failure paths and the corresponding store disclosures.
- A final accessibility and release QA pass. Reduced motion, safe-area layout, and 48+ point control halves are already addressed; the game remains a visual dexterity challenge.


2048 / Merge adds an endless puzzle mode alongside Classic and Infinite. The largest ball stays in the middle of a translucent snake, matching values combine across both sides, and the player must avoid growing beyond the platform or falling into a hole. Waves contain three number balls and two holes. Play continues past 2048 without interruption, with k/m labels for large numbers. Records stay local, and every control scheme uses the same simulation.

Laser Maze adds ten finish-based routes: keep the ball inside a winding red laser corridor and climb to the checkered line. Touching a wall ends the run. The routes grow narrower and more winding, with local best times per route and control scheme. All existing controls remain available, with automatic ascent for one-finger play.
