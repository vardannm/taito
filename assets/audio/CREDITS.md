# Audio sources

## Classic and Daily

`theme_classic_1_40.wav` and `theme_classic_41_80.wav` derive from the approved
ElevenLabs Music recordings for Rollrise. The second uses the bass-restored,
percussion-suppressed revision. Classic switches at level 41; Daily uses the
opening theme. Each has an 18.461542-second circular body plus an identical
one-second continuation and 250 ms scheduling margin. Complementary overlapping
playback avoids a gap or volume boost. Reproduction: `tool/refine_audio.py`.
Combined asset size: 6,954,320 bytes; original drafts remain outside the bundle.

## Infinite

`theme_infinite_climb.wav`, `theme_infinite_fast.wav`, and
`theme_infinite_boss.wav` are alternate arrangements of a soundtrack generated
for **Rollrise: Ball Balance** with ElevenLabs Music (`music_v2`).

- Generated master: `artifacts/music/rollrise_infinite_master.mp3` (not bundled).
- Generation parameters: adjacent `.request.json` sidecar; contains no credentials.
- Three 40-second source sections: normal climb, fast climb, boss encounter.
- Adaptations: measured 96 BPM; matching 12-bar (30-second) repeating bodies,
  natural continuation for a 2.5-second equal-power overlapping handoff, 250 ms
  scheduling headroom, -5 dB low shelf, gentle treble shaping, matched RMS.
- Runtime: continuous alternate arrangements crossfaded according to active play
  time, height-based pace and boss warnings/encounters, without a tempo/pitch shift.
- Format: 44.1 kHz stereo, 16-bit PCM WAV; 32.75 seconds and 5,777,144 bytes per arrangement.
- Reproduction: decode the master to 16-bit stereo WAV with macOS `afconvert`,
  then run `tool/prepare_infinite_music.py source.wav` (NumPy).
- Editing measurements and decoded-source SHA-256:
  `artifacts/music/rollrise_infinite_loops.json`.
- Generated through the owner's ElevenLabs account; usage follows that account's
  applicable ElevenLabs Music terms. These files are not the CC BY recordings below.

## Archived Infinite soundtrack: The Complex (not bundled)

`theme_infinite_complex.mp3` is **The Complex** by
**Kevin MacLeod (incompetech.com)**, used as the original recording with its
opening and gradual build intact. Synths and percussion, 104 BPM, about 4:28.

- Source and license declaration: https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1300025
- Original recording: https://incompetech.com/music/royalty-free/mp3-royaltyfree/The%20Complex.mp3
- License: Creative Commons Attribution 4.0,
  https://creativecommons.org/licenses/by/4.0/
- In-game attribution: Settings > Music credits.
- Archived source credit only; this recording is not used in the current build.
- Playback changes: reduced playback level for effects headroom; tempo gradually
  rises from 1.00 to 1.12x with active gameplay time and height-based pace
  (104 to about 116 BPM). Pausing holds the position; a new run restarts the opening.
- Format: original stereo MP3, 10,712,421 bytes. No edits or transcoding.
- SHA-256: `c270fb44a69828f6cae7412e077a38b92d55015d30ced549d0d477f864e7e41e`
- Reproduction: download the original recording to
  `assets/audio/theme_infinite_complex.mp3` and verify the SHA-256 above.

## Archived Infinite soundtrack (not bundled)

`theme_infinite.wav` is a 164-bar gameplay arrangement adapted from
**Furious Freak** by **Kevin MacLeod (incompetech.com)**. It starts on the full
groove and combines drum, electric-piano and bass/synth sections, with the
sparse opening, quiet breakdown and ending fade omitted.

- Source: https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1600021
- Original recording: https://incompetech.com/music/royalty-free/mp3-royaltyfree/Furious%20Freak.mp3
- License: Creative Commons Attribution 4.0,
  https://creativecommons.org/licenses/by/4.0/
- Archived source credit only; this recording is not used in the current build.
- Adaptation: extended section arrangement, beat-aligned crossfades, bass EQ,
  gain adjustment and variable playback tempo during Infinite.
- Format: 44.1 kHz stereo, 16-bit PCM WAV, decoded from the artist's MP3.
- Length: 5:10 at the source tempo (127 BPM, verified against the recording's
  ID3 tempo tag and drum onsets). Runtime speed grows from 1.06 to 1.30x
  (about 135–165 BPM), using active gameplay seconds and height-based pace.
- Reproduction: `python scripts/prepare_theme.py path/to/furious-freak.mp3`
  (NumPy and SoundFile).

## Archived 2048 soundtrack (not bundled)

`theme_dark.wav` is a 24-bar dark groove adapted from **Dirt Rhodes** by
**Kevin MacLeod (incompetech.com)**. The source recording features an actual
Mark I Stage Piano, electric piano, piano, and drum kit, at 82 BPM.

- Source and license declaration: https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100542
- Original recording: https://incompetech.com/music/royalty-free/mp3-royaltyfree/Dirt%20Rhodes.mp3
- License: Creative Commons Attribution 4.0,
  https://creativecommons.org/licenses/by/4.0/
- Archived source credit only; this recording is not used in the current build.
- Adaptation: musical excerpt, short loop crossfade, bass/low-mid EQ, and
  gain adjustment for effects headroom. Delivered as 44.1 kHz stereo,
  16-bit PCM WAV, decoded from
  the artist's MP3 recording.
- Reproduction: `python scripts/prepare_theme.py path/to/dirt-rhodes.mp3 --mode merge`
  (NumPy and SoundFile).

## Sound effects

The sound pack was initially generated for Rollrise through the owner's
ElevenLabs account with `eleven_text_to_sound_v2` on November 5, 2026:

- Six gameplay cues: target, coin, merge, star, miss, complete.
- Four UI cues: tap, back, toggle, selection.
- Twenty-four enemy cues, including separate arrivals for all six bosses.
- Processed to 44.1 kHz mono, 16-bit PCM with leading-silence trimming,
  bounded peaks, short fades and the gameplay's existing cue durations.
- Total: 1,402,994 bytes. Processed hashes and durations: `SFX_MANIFEST.json`.
- Generator: `tool/refresh_sound_effects.py`. Local source MP3s and prompt records:
  `artifacts/audio_refresh/raw`; earlier effects: `artifacts/audio_refresh/previous`.
- Usage follows the applicable ElevenLabs terms for the owner's account. These
  effects are not the CC BY recordings credited above.

The older synthesized sound pack from `scripts/generate_audio.py` and
`scripts/generate_enemy_audio.py` has been replaced; those scripts are retained
for historical reproduction and should not overwrite the new pack.

Subsequent revision: `coin.wav`, `enemy_laserCharge.wav` and
`enemy_laserFire.wav` are original subdued procedural designs from
`tool/quiet_effects.py`, replacing the generated versions. The pickup is a short
muted droplet and lasers use soft electrical hums without zaps or rising whines.
Their current provenance, hashes and levels are recorded in `SFX_MANIFEST.json`.
Further refinement on November 6: `miss.wav`, `merge.wav`, `enemy_web.wav` and
`enemy_quills.wav` are original designs from `tool/refine_audio.py`: a subdued
life-loss impact, water-droplet merge cue, soft web twang and brushed-air quill
shot. The other 27 effects retain the ElevenLabs provenance above. Laser playback
was raised slightly to 0.13/0.18; the pickup level remains 0.025.
