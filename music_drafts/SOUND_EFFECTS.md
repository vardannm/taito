# Complete effects refresh

UI revision: tap, back, toggle and select now all use the same plain 40 ms
mechanical click at 0.18 playback volume, without pitched notes or flourishes.
Reproduce with `tool/simple_button_sound.py` (NumPy, no API).

The game now has separate assets for all six gameplay events (target, coin,
merge, star, miss, complete), four UI actions (tap, back, toggle, selection),
and 24 enemy effects including distinct arrivals for all six bosses.

Run from the game folder:

```sh
python3 tool/refresh_sound_effects.py
```

Use the existing ElevenLabs key with **Sound Effects** generation enabled.
The key is entered at a hidden prompt and never saved. The command makes one
request for each missing raw effect, using the account's allowance. An HTTP
failure stops the batch without retrying. Rerunning skips completed downloads.

All 34 effects share a warm, rounded electronic/organic sound direction, light
bass and restrained highs. Hazard charges and shots retain distinct identities.
The script decodes to compact mono PCM, trims leading silence, preserves the
gameplay cue durations, normalizes peaks and fades both ends. It installs the
pack only after every effect decodes successfully. Existing files are backed up
to `artifacts/audio_refresh/previous`. The montage and report are written to
`artifacts/audio_refresh/sound_pack_preview.wav` and `report.json`.

Current status: all 34 ElevenLabs effects generated and installed on November 5,
2026. The initial WAV hashes and timings matched the batch report. All temporary
fallbacks and previous synthesized effects have been replaced. The installed
pack is 1,402,994 bytes (about 1.4 MB); the preview and backups are not bundled.
The checked-in `assets/audio/SFX_MANIFEST.json` records processed asset hashes
and durations. The original downloads and generation prompts stay in the local
`artifacts/audio_refresh/raw` folder. Restart the game after replacing audio
because native players can cache earlier versions by filename.

### Quiet laser and pickup revision

The pickup (`coin.wav`, also used for hearts/combo crystals) and both laser cues
were subsequently replaced with subdued original procedural designs using
`tool/quiet_effects.py` (NumPy, no API credits). Pickups are a short muted droplet
at 0.025 playback volume, limited to one audible cue per 500 ms, with no queued
replay. Laser charge/fire are soft electrical hums at 0.08/0.11 playback volume.
Spider and porcupine appearances are silent; attack cues are retained. Other
effects keep their existing sound and levels. `assets/audio/SFX_MANIFEST.json`
records the current hashes and distinguishes the three original designs from
the ElevenLabs effects. The initial batch report remains a historical record.
Audition at in-game relative levels: `artifacts/quiet_effects/quiet_lasers_and_pickups.wav`.
November 6 refinement: life loss, merge, web shots and quill shots were replaced
with original softer designs from `tool/refine_audio.py`. Merge uses a subdued
water-droplet sound at 0.16, life loss a muted impact at 0.28, and web/quills are
0.16. Laser charge/fire are now 0.13/0.18, slightly more audible. Pickups remain
at 0.025 and retain their rate limit. Preview:
`artifacts/sound_refinements/updated_effects_preview.wav` (life loss, merge, web,
quills, laser charge, laser fire). No API credits were used for these edits.
Rerunning the full ElevenLabs refresh overwrites these edits; reapply
`tool/quiet_effects.py` and `tool/refine_audio.py` afterward when recreating the pack.

UI audio is attached to enabled action callbacks, not pointer-down events, so
disabled controls, scrolling and cancelled taps stay silent. Keyboard activation
uses the same callbacks. Shared menu controls and direct controls in shops,
rewards, level selection, settings, tutorials, dialogs and result screens are
covered. UI effects follow Sound Effects, have a two-voice cap and a brief
duplicate-tap guard, and cancel pending playback on mute/background/disposal.
Gameplay sound and music keep separate controls.

Legacy `scripts/generate_audio.py` and `scripts/generate_enemy_audio.py` recreate
the old synthesized pack; do not run them over an accepted ElevenLabs pack.
