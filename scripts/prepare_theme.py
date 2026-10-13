"""Master recordings into the game's stereo PCM WAV arrangements.

Requires NumPy and SoundFile (with MP3 decoding support). Download the source
listed in assets/audio/CREDITS.md, then pass its local path as the argument.
No MIDI, oscillator instruments, or runtime synthesis are used for the music.
"""
import argparse
import hashlib
import json
from pathlib import Path
import wave

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parent.parent
RATE = 44100
SOURCES = {
    "infinite": {
        "sha256": "81eeea1f99cb0f25b417cfa69b9268f040e46bb67a955247fe80a769ee426bd7",
        "title": "Furious Freak",
        "asset": "theme_infinite.wav",
        # 127 BPM is embedded in the original recording's ID3 tempo tag and
        # confirmed by its drum onsets. Infinite plays at 1.06–1.30x.
        "bpm": 127,
        "phase": .025,
        # Full-groove sections, melody variations, then a final return.
        # The sparse opening, quiet breakdown and fade-out are excluded.
        "sections": [(24, 32), (64, 28), (36, 20), (68, 24), (24, 32), (64, 28)],
        "join_seconds": .12,
        "rms": .16,
    },
    "merge": {
        "sha256": "e1275490a4d0ee25f635fec21b2c4a641966f08c87c070cc646dc51962d5b947",
        "title": "Dirt Rhodes",
        "asset": "theme_dark.wav",
        "bpm": 82,
        "start": 13.92,
        "bars": 24,
        "join_seconds": .18,
        "rms": .14,
    },
}


def pcm(path, audio):
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(np.round(audio * 32767).astype("<i2").tobytes())


def full_groove(source, config):
    join = round(config["join_seconds"] * RATE)
    period = 4 * 60 / config["bpm"]
    clips = []
    for bar, bars in config["sections"]:
        start = round((config["phase"] + bar * period) * RATE)
        count = round(bars * period * RATE)
        # Filter with surrounding source context, so neither the electric
        # piano nor the drums acquire a transient at an edit boundary.
        pad = round(.25 * RATE)
        raw = source[start - pad:start + count + join + pad]
        frequencies = np.fft.rfftfreq(len(raw), 1 / RATE)
        bass_db = 1.5 / (1 + (frequencies / 110) ** 4)
        equalizer = 10 ** (bass_db / 20)
        equalizer *= frequencies ** 2 / (frequencies ** 2 + 22 ** 2)
        filtered = np.fft.irfft(
            np.fft.rfft(raw, axis=0) * equalizer[:, None], n=len(raw), axis=0,
        ).astype("float32")
        clips.append(filtered[pad:pad + count + join].copy())
    weight = (.5 - .5 * np.cos(np.linspace(0, np.pi, join)))[:, None]
    pieces = []
    for i, clip in enumerate(clips):
        piece = clip[:-join].copy()
        # Every splice, including the loop wrap, continues the outgoing audio
        # before crossfading onto the incoming section on the same beat phase.
        piece[:join] = clips[i - 1][-join:] * (1 - weight) + piece[:join] * weight
        pieces.append(piece)
    return np.concatenate(pieces)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Original credited MP3 recording")
    parser.add_argument("--mode", choices=SOURCES, default="infinite")
    args = parser.parse_args()
    config = SOURCES[args.mode]
    digest = hashlib.sha256(args.source.read_bytes()).hexdigest()
    if digest != config["sha256"]:
        raise ValueError(f"Source differs from the credited {config['title']} recording.")
    source, rate = sf.read(args.source, dtype="float32", always_2d=True)
    if rate != RATE or source.shape[1] != 2:
        raise ValueError("Expected the original 44.1 kHz stereo recording.")

    if args.mode == "infinite":
        music = full_groove(source, config)
        start = round((config["phase"] + config["sections"][0][0] * 4 * 60 / config["bpm"]) * RATE)
        count = len(music)
        bars = sum(bars for _, bars in config["sections"])
    else:
        music, start, count = merge_groove(source, config)
        bars = config["bars"]
    gain = min(config["rms"] / float(np.sqrt(np.mean(music ** 2))), .82 / float(np.max(np.abs(music))))
    music *= gain
    output = ROOT / "assets" / "audio" / config["asset"]
    pcm(output, music)
    artifacts = ROOT / "artifacts"
    artifacts.mkdir(exist_ok=True)
    pcm(artifacts / f"{args.mode}-music-loop-join.wav", np.concatenate([music[-RATE * 5:], music[:RATE * 5]]))
    pcm(artifacts / f"{args.mode}-music-preview.wav", music[:RATE * 24])
    report = {
        "title": config["title"],
        "artist": "Kevin MacLeod",
        "license": "CC BY 4.0",
        "source_sha256": digest,
        "source_start_seconds": round(start / RATE, 6),
        "bars": bars,
        "bpm": config["bpm"],
        "seconds": round(count / RATE, 6),
        "sample_rate": RATE,
        "channels": 2,
        "bits": 16,
        "peak": round(float(np.max(np.abs(music))), 6),
        "rms": round(float(np.sqrt(np.mean(music ** 2))), 6),
        "wrap_step": round(float(np.max(np.abs(music[0] - music[-1]))), 6),
        "bytes": output.stat().st_size,
    }
    (artifacts / f"{args.mode}-music-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


def merge_groove(source, config):
    start = round(config["start"] * RATE)
    count = round(config["bars"] * 4 * 60 / config["bpm"] * RATE)
    join = round(config["join_seconds"] * RATE)
    if start + count + join > len(source):
        raise ValueError("Source is too short for the selected musical phrase.")
    music = source[start:start + count].copy()
    # Preserve the exact phrase length. The last sample is followed by its
    # original continuation, then a complementary crossfade returns to the
    # start of the phrase. Both channels use the same weights.
    weight = (.5 - .5 * np.cos(np.linspace(0, np.pi, join)))[:, None]
    music[:join] = source[start + count:start + count + join] * (1 - weight) + music[:join] * weight

    # A broad bass shelf adds weight to the groove. A gentle low-mid cut keeps
    # the Rhodes clear, while the drum transients retain their upper mids.
    # Filtering the circular loop avoids adding a discontinuity at its wrap.
    frequencies = np.fft.rfftfreq(count, 1 / RATE)
    bass_db = 2.5 / (1 + (frequencies / 115) ** 4)
    low_mid_db = -1.4 * np.exp(-.5 * (np.log2(np.maximum(frequencies, 1) / 330) / .7) ** 2)
    equalizer = 10 ** ((bass_db + low_mid_db) / 20)
    equalizer *= frequencies ** 2 / (frequencies ** 2 + 22 ** 2)
    equalizer *= 1 / np.sqrt(1 + (frequencies / 16000) ** 8)
    music = np.fft.irfft(np.fft.rfft(music, axis=0) * equalizer[:, None], n=count, axis=0)

    # Keep acoustic dynamics and give effects headroom above the backing track.
    return music, start, count


if __name__ == "__main__":
    main()
