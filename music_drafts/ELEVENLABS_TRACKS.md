# Rollrise level soundtrack

- Levels 1–40: approved first ElevenLabs track, edited into an eight-bar loop.
  Source: `artifacts/music/rollrise_preview.mp3`.
  Game loop: `artifacts/music/rollrise_levels_loop.wav`.
- Levels 41–80: companion track with the same warm electronic palette and
  104 BPM target, a new melody, stronger bass pulse and slightly more tension.
  Generated and edited into an eight-bar, 104 BPM loop; listening approval pending.
  Source: `artifacts/music/rollrise_levels_41_80_preview.mp3`.
  Game loop: `artifacts/music/rollrise_levels_41_80_loop.wav`.
  Two-repeat audition: `artifacts/music/rollrise_levels_41_80_loop_preview.wav`.
  The first track is not an audio reference in this request,
  so stylistic similarity is guided by the text prompt.

Generate the second 30-second draft from the project folder:

```sh
python3 tool/generate_music.py --chapter 41-80
```

Enter the API key at the hidden Terminal prompt. It is not saved.
Output: `artifacts/music/rollrise_levels_41_80_preview.mp3`.
Each generation uses the account's allowance. The tool never retries automatically.
Audition the new draft before choosing beat-aligned loop boundaries; the original
loop's timing should not be assumed to fit a newly generated recording.

The approved level tracks are now bundled as `theme_classic_1_40.wav` and
`theme_classic_41_80.wav`. The later track uses the bass-restored, de-ticked
revision. Classic switches at level 41 and keeps the later track for subsequent
levels; Daily uses the opening theme. Both include a one-second identical
overlap and scheduling headroom for seamless complementary crossfades. Playback
starts on first input, respects Music mute/pause and resets for a new run.
Reproduce the level asset copies with `tool/refine_audio.py` (NumPy).

## Infinite adaptive soundtrack

Generate one two-minute master with three related arrangements:

```sh
python3 tool/generate_music.py --chapter infinite
```

The Music v2 composition plan specifies 40 seconds each of normal climbing,
fast climbing and boss music. At the requested 96 BPM, each section is 16 bars
in 4/4. All sections request the same key, chord cycle and motif. Bass stays
light; ticking, hi-hats, shakers, sharp percussion and clicky synths are excluded.
The boss arrangement gets intensity from harmony, melody and broad tom accents.

Output: `artifacts/music/rollrise_infinite_master.mp3`, with a `.request.json`
sidecar containing musical parameters only. One paid generation is made, with
no automatic retries. Keys are entered privately and not saved.

The three sections are complete alternate arrangements, **not isolated stems**;
they should be crossfaded, not stacked at full volume. The 40/80-second markers
are editing boundaries in the master, not time-triggered events in gameplay.
After generation, confirm actual tempo, downbeats, section boundaries and sound,
then cut circular loops and match their loudness before bundling them.

Runtime integration uses active gameplay time and `game.pace` for the climb
blend; boss warning/arrival overrides that mix and boss departure returns to
the current climb intensity. Audio must stay paused during pause/countdown,
wait for the first touch, stop on exit/mute, and reset for a new run. Existing
code exposes these inputs in `lib/main.dart:syncMusic` and `lib/game.dart`.
Avoid a large playback-rate ramp: intensity should come from the arrangements.
All three arrangements run on the same timeline and fades preserve the shared
pulse. A silent incoming arrangement re-aligns before fading in. Verify on
iOS/Android for native loop timing and audio-focus interruptions.

Status: master generated; 96 BPM confirmed in all three sections; three 30-second
loops edited, level-matched and bundled. Adaptive Infinite playback is enabled.
Loop playback was revised to use two prepared copies per arrangement, with a
2.5-second equal-power overlap before file end. Assets retain natural outgoing
audio through the crossfade, plus 250 ms of scheduling headroom (32.75-second
files with a 30-second repeating body). This avoids iOS's seek/resume at EOF.
Assets total 17,331,432 bytes. No additional API generation was needed for editing.
Join audition: `artifacts/music/rollrise_infinite_join_preview.wav` (join at 4s).
Audition: `artifacts/music/rollrise_infinite_adaptive_preview.wav` (60 seconds:
opening, build, boss, return). The preview is outside the game bundle.
