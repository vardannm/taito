"""Generate Eclipse Seraph's crystal volley cue and update its asset record."""

from array import array
from hashlib import sha256
import json
from math import exp, sin, tau
from pathlib import Path
from sys import byteorder
import wave


RATE = 44_100
DURATION = .32
PEAK = .48
CUE = "enemy_crystal"
AUDIO = Path(__file__).resolve().parents[1] / "assets" / "audio"


def synthesize():
    frame_count = round(DURATION * RATE)
    samples = []
    for frame in range(frame_count):
        t = frame / RATE
        # A single note with a faint octave that falls away before the body.
        phase = tau * 587.33 * t
        body = sin(phase) * exp(-t / .083)
        overtone = .13 * sin(2 * phase) * exp(-t / .047)
        attack = sin(tau / 4 * min(1, t / .024)) ** 2
        remaining = (frame_count - 1 - frame) / RATE
        release = sin(tau / 4 * min(1, remaining / .06)) ** 2
        samples.append((body + overtone) * attack * release)

    gain = PEAK * 32_767 / max(map(abs, samples))
    pcm = array("h", (round(sample * gain) for sample in samples))
    if byteorder != "little":
        pcm.byteswap()
    return pcm.tobytes()


def main():
    asset = AUDIO / f"{CUE}.wav"
    with wave.open(str(asset), "wb") as clip:
        clip.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        clip.writeframes(synthesize())

    manifest_path = AUDIO / "SFX_MANIFEST.json"
    manifest = json.loads(manifest_path.read_text())
    manifest[CUE] = {
        "seconds": DURATION,
        "peak": PEAK,
        "sha256": sha256(asset.read_bytes()).hexdigest(),
        "source": "Original procedural design: tool/refine_seraph_shot.py",
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
