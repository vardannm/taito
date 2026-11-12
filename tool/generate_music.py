#!/usr/bin/env python3
"""Generate a Rollrise music draft using ElevenLabs (Python standard library)."""

import argparse
import getpass
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request


PROMPT = """Instrumental background music for Rollrise: Ball Balance, a mobile
arcade game where the player tilts a bar to balance a rolling steel ball,
collect numbered targets and climb past insect hazards. Focused, playful and
slightly mysterious electronic soundtrack. Warm rounded synth bass, delicate
plucked synth motifs, airy pads and restrained crisp percussion, around 104 BPM.
Leave space for collection and collision sound effects. Steady moderate energy,
no harsh leads, no vocals or spoken words, no dramatic cinematic impacts.
Begin directly with the groove, keep a consistent texture and finish in a way
suited to editing into a repeating gameplay loop; avoid a long intro or fadeout.
"""

LATER_LEVELS_PROMPT = """Instrumental background music for levels 41-80 of
Rollrise: Ball Balance, a mobile arcade game about balancing a steel ball on a
tilting bar, collecting numbered targets and avoiding insect hazards.
A companion to the earlier levels' focused, playful, slightly mysterious
electronic soundtrack: warm rounded synth bass, delicate plucked synth motifs,
airy pads, restrained crisp percussion, around 104 BPM. Keep that same intimate,
polished electronic palette, but introduce a new memorable melodic motif,
a deeper moving bass pulse, subtle syncopated percussion and gently darker
harmonies. Moderately more energetic and tense to reflect harder levels, while
remaining playful, focused and comfortable over repeated gameplay.
Leave room for game sound effects. No vocals, speech, harsh leads, heavy drops,
or cinematic impacts. Start directly in a stable groove and maintain a steady
104 BPM in 4/4 with clear repeating four- and eight-bar phrases. No long intro,
tempo changes, final flourish or fadeout. Suitable for editing into a loop.
"""


def infinite_plan():
    """Three related arrangements, not three stems intended to play together.

    At 96 BPM, 16 bars of 4/4 last exactly 40 seconds. Matching tempo,
    harmony and phrase lengths let us edit loops and crossfade arrangements.
    The generated beat placement still needs checking before game integration.
    """
    shared = [
        "Instrumental electronic arcade soundtrack for Rollrise: Ball Balance",
        "Steady 96 BPM, 4/4, D minor throughout, no tempo or key changes",
        "Sixteen bars per section, four repeats of the same four-bar harmony",
        "Harmonic progression D minor, B-flat major, F major, C major, one chord per bar",
        "Warm airy synth pads, soft rounded mallets, flowing legato synth melodies",
        "Memorable mysterious adventurous motif, focused precision gameplay",
        "Light restrained bass quietly supporting the melody, no heavy low end",
        "Soft broad drum sounds with rounded attacks, space for game warning sounds",
        "Start each section directly on the downbeat; keep the same musical motif",
        "Stable loopable phrases, no introduction, no ending flourish, no fadeout",
        "Polished spacious production, consistent perceived loudness across sections",
        "Only instruments, no vocals, no spoken words",
    ]
    excluded = [
        "vocals", "lyrics", "speech", "hi-hats", "ticking", "clicks",
        "metronome", "clock sounds", "shakers", "rattles", "cymbal patterns",
        "sharp repetitive percussion", "clicky arpeggios", "staccato ticking notes",
        "sub-bass", "booming bass", "bass-heavy mix", "distorted bass",
        "heavy kick drum", "EDM drops", "loud impacts", "harsh leads",
    ]
    sections = [
        ("Normal climb", [
            "Low-to-moderate energy, inviting hypnotic opening gameplay groove",
            "Sparse soft percussion, relaxed melody, gentle floating atmosphere",
        ]),
        ("Fast climb", [
            "Develop the preceding climb motif into a more urgent variation",
            "Moderately higher intensity through flowing melodic movement and richer harmony",
            "More rounded midrange drum rhythm, light bass, no extra high ticking percussion",
            "Keep the exact tempo and four-bar chord cycle of the normal climb",
        ]),
        ("Boss encounter", [
            "Recognizable boss variation of the same climb theme and chord cycle",
            "Highest intensity, dark suspended synth harmonies and bold rising melodic phrases",
            "Broader soft tom accents and layered midrange synths, urgency without heavy bass",
            "Sustain the boss groove throughout, no victory ending or dramatic final hit",
        ]),
    ]
    return {"chunks": [
        {"text": f"[{name}]\n{{Instrumental}}", "duration_ms": 40000,
         "positive_styles": shared + local, "negative_styles": excluded}
        for name, local in sections
    ]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=int,
                        help="Defaults to 30; Infinite uses a fixed 120-second plan")
    parser.add_argument("--chapter", choices=["1-40", "41-80", "infinite"], default="1-40",
                        help="Select the soundtrack's level range")
    parser.add_argument("--model", choices=["music_v1", "music_v2", "music_v2_5"],
                        default="music_v2")
    parser.add_argument("--output", type=Path,
                        help="Optional output path; otherwise chosen by chapter")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show the request without contacting ElevenLabs")
    args = parser.parse_args()
    if args.seconds is None:
        args.seconds = 120 if args.chapter == "infinite" else 30
    if args.chapter == "infinite":
        if args.seconds != 120:
            parser.error("Infinite has three fixed 40-second sections; use 120 seconds.")
        if args.model == "music_v1":
            parser.error("The Infinite composition plan requires music_v2 or music_v2_5.")
    if args.output is None:
        filename = {"1-40": "rollrise_preview.mp3",
                    "41-80": "rollrise_levels_41_80_preview.mp3",
                    "infinite": "rollrise_infinite_master.mp3"}[args.chapter]
        args.output = Path(__file__).resolve().parents[1] / "artifacts/music" / filename
    if not 3 <= args.seconds <= 300:
        parser.error("Use a duration between 3 and 300 seconds.")
    if args.output.exists():
        parser.error("Output already exists; choose another --output path.")
    metadata = args.output.with_suffix('.request.json')
    if metadata.exists():
        parser.error("Request record already exists; choose another --output path.")
    prompt = PROMPT if args.chapter == "1-40" else LATER_LEVELS_PROMPT
    payload = dict(prompt=prompt, music_length_ms=args.seconds * 1000,
                   force_instrumental=True, model_id=args.model)
    if args.chapter == "infinite":
        # The API does not accept prompt/force_instrumental with a plan.
        payload = dict(composition_plan=infinite_plan(), model_id=args.model,
                       respect_sections_durations=True)
    if args.dry_run:
        print(json.dumps(payload, indent=2))
        return 0
    key = os.environ.get("ELEVENLABS_API_KEY") or getpass.getpass(
        "ElevenLabs API key (hidden; not saved): ")
    if not key.strip():
        parser.error("An API key is required.")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(
        "https://api.elevenlabs.io/v1/music?output_format=mp3_44100_128",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "xi-api-key": key.strip()},
        method="POST")
    print(f"Generating {args.seconds} seconds. This uses your ElevenLabs allowance.")
    try:
        with urllib.request.urlopen(request, timeout=600) as response:
            audio = response.read()
            if not audio:
                raise ValueError("ElevenLabs returned empty audio.")
        with args.output.open("xb") as output:
            output.write(audio)
    except urllib.error.HTTPError as error:
        print(f"ElevenLabs returned HTTP {error.code}. Check your key's Music "
              "permission, Music API access and remaining allowance. "
              "No automatic retry was made.", file=sys.stderr)
        return 1
    except (urllib.error.URLError, TimeoutError, ValueError, OSError) as error:
        print(f"Generation could not finish ({type(error).__name__}). "
              "Check ElevenLabs usage before retrying: a request may already "
              "have been charged.", file=sys.stderr)
        return 1
    print(f"Saved: {args.output}")
    # Save only musical parameters, never credentials, for later loop editing.
    try:
        with metadata.open('x') as record:
            json.dump(payload, record, indent=2)
            record.write('\n')
    except OSError:
        print("Audio saved, but its request record could not be written.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
