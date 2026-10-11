"""Original enemy sound design: layered synthesis, no external recordings.

Short mono PCM cues are small and decode directly in Android's SoundPool.
Run separately from generate_audio.py to leave the existing music/UI cues intact.
"""
from pathlib import Path
import json
import wave
import numpy as np

RATE = 44100
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)
DURATIONS = {
    "insectArrival": .28, "wingArrival": .4, "snakeHiss": .5,
    "wardenArrival": .85, "colossusArrival": .95, "seraphArrival": 1.05,
    "bullet": .14, "ricochet": .22, "bounce": .16, "petal": .28,
    "crystal": .32, "laserCharge": .8, "laserFire": .75,
    "bombThrow": .3, "poolLand": .36, "mineCharge": .85,
    "mineFire": .4, "cometCharge": .65, "cometFire": .38,
    "web": .22, "quills": .25,
}
RNG = np.random.default_rng(711)


def sweep(t, start, end, seconds, modulation=0):
    phase = 2 * np.pi * (start * t + (end - start) * t * t / (2 * seconds))
    return np.sin(phase + modulation * np.sin(2 * np.pi * 35 * t))


def decay(t, seconds, attack=.004):
    return np.minimum(1, t / attack) * np.exp(-t / seconds)


def synth(name, duration):
    t = np.arange(round(duration * RATE)) / RATE
    noise = RNG.normal(0, 1, len(t))
    soft = np.convolve(noise, np.ones(11) / 11, mode="same")
    air = noise - np.convolve(noise, np.ones(45) / 45, mode="same")
    if name == "bullet":
        signal = .7 * sweep(t, 1100, 240, duration, .4) * decay(t, .028)
        signal += .3 * air * decay(t, .013)
    elif name == "ricochet":
        signal = .55 * sweep(t, 500, 110, duration, 1.4) * decay(t, .07)
        signal += .3 * np.sin(2 * np.pi * 940 * t) * decay(t, .03)
    elif name == "bounce":
        signal = (np.sin(2 * np.pi * 1650 * t) + .4 * np.sin(2 * np.pi * 2310 * t)) * decay(t, .033)
    elif name in ("petal", "crystal"):
        base = 740 if name == "petal" else 1046.5
        signal = sum(np.sin(2 * np.pi * base * ratio * t) / (i + 1)
                     for i, ratio in enumerate([1, 1.5, 2.01])) * decay(t, .075, .009)
        signal += .18 * soft * np.sin(np.pi * t / duration) ** 2
    elif name in ("laserCharge", "mineCharge", "cometCharge"):
        start = 180 if name == "mineCharge" else 330
        end = 1000 if name == "mineCharge" else 1450
        rise = np.sin(np.pi * t / duration) ** .8
        signal = .45 * sweep(t, start, end, duration, .7) * rise
        signal += .25 * sweep(t, start * 1.5, end * 1.5, duration) * rise
        signal += .15 * soft * rise
        if name == "cometCharge":
            signal += .3 * np.sin(2 * np.pi * 1568 * t) * rise
    elif name == "laserFire":
        signal = .65 * sweep(t, 2100, 130, duration, 1.3) * decay(t, .11)
        signal += .35 * sweep(t, 180, 65, duration) * decay(t, .15)
        signal += .18 * air * decay(t, .08)
    elif name in ("mineFire", "colossusArrival"):
        signal = .8 * sweep(t, 150, 38, duration) * decay(t, .17)
        signal += .4 * soft * decay(t, .12)
        signal += sum(.12 * np.sin(2 * np.pi * f * t) * decay(t, .16)
                      for f in [330, 497, 731])
        if name == "colossusArrival":
            signal += .3 * sweep(t, 72, 190, duration, .4) * np.sin(np.pi * t / duration) ** 2
    elif name == "cometFire":
        signal = .5 * sweep(t, 1568, 260, duration) * decay(t, .11)
        signal += .35 * soft * np.sin(np.pi * t / duration) ** 1.5
    elif name == "bombThrow":
        signal = .6 * sweep(t, 150, 450, duration) * decay(t, .085)
        signal += .3 * soft * decay(t, .075)
    elif name == "poolLand":
        signal = .45 * sweep(t, 230, 65, duration, 1.3) * decay(t, .085)
        signal += .5 * soft * decay(t, .08)
    elif name == "web":
        signal = .7 * sweep(t, 420, 110, duration, 2.2) * decay(t, .045)
        signal += .3 * air * decay(t, .02)
    elif name == "quills":
        signal = .5 * air * decay(t, .075)
        signal += .4 * sweep(t, 2200, 850, duration) * decay(t, .04)
    elif name == "snakeHiss":
        signal = .65 * air * np.sin(np.pi * t / duration) ** 1.5
        signal += .12 * np.sin(2 * np.pi * 130 * t) * decay(t, .15)
    elif name == "insectArrival":
        pulses = np.maximum(0, np.sin(2 * np.pi * 22 * t)) ** 5
        signal = (.6 * sweep(t, 1700, 600, duration) + .3 * air) * pulses * decay(t, .1)
    elif name in ("wingArrival", "wardenArrival"):
        flutter = .55 + .45 * np.sin(2 * np.pi * 23 * t)
        signal = .5 * sweep(t, 130, 240, duration, 2) * flutter * np.sin(np.pi * t / duration)
        signal += .2 * soft * flutter * np.sin(np.pi * t / duration)
        if name == "wardenArrival":
            signal += .35 * sweep(t, 440, 220, duration) * decay(t, .24, .015)
    elif name == "seraphArrival":
        signal = np.zeros_like(t)
        for i, f in enumerate([523.25, 783.99, 1046.5, 1568]):
            age = np.maximum(0, t - i * .075)
            signal += .3 * np.sin(2 * np.pi * f * age) * decay(age, .22, .012)
        signal += .13 * soft * np.sin(np.pi * t / duration) ** 2
    else:
        raise ValueError(name)
    # A small filtered echo adds a tail, while a final cosine fade keeps every
    # clip click-free. Peak normalization leaves headroom for mixed effects.
    echo = round(.047 * RATE)
    signal[echo:] += .16 * signal[:-echo].copy()
    fade = np.minimum(1, t / .003) * np.minimum(1, (duration - t) / .025)
    signal *= fade
    signal *= .72 / max(np.max(np.abs(signal)), .001)
    return signal


def write(path, signal):
    with wave.open(str(path), "wb") as clip:
        clip.setnchannels(1)
        clip.setsampwidth(2)
        clip.setframerate(RATE)
        clip.writeframes(np.round(signal * 32767).astype("<i2").tobytes())


def main():
    clips, report = [], {}
    for name, duration in DURATIONS.items():
        signal = synth(name, duration)
        write(OUT / f"enemy_{name}.wav", signal)
        clips.extend([signal, np.zeros(round(.24 * RATE))])
        report[name] = {"seconds": duration,
                        "peak": round(float(np.max(np.abs(signal))), 4),
                        "rms": round(float(np.sqrt(np.mean(signal ** 2))), 4)}
    artifacts = ROOT / "artifacts"
    artifacts.mkdir(exist_ok=True)
    write(artifacts / "enemy-sound-preview.wav", np.concatenate(clips))
    (artifacts / "enemy-sound-report.json").write_text(json.dumps(report, indent=2))
    print(f"Generated {len(report)} original enemy cues; all peaks <= 0.72.")


if __name__ == "__main__":
    main()
