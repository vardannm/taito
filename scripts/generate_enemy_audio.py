"""Original enemy sound design: layered synthesis, no external recordings.

Short mono PCM cues are small and decode directly in Android's SoundPool.
Run separately from generate_audio.py to leave the existing music/UI cues intact.
"""
from pathlib import Path
import argparse
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


def electrical_noise(rng, count, low, high):
    """Band-limited corona hiss, without harsh ultrasonic white noise."""
    frequencies = np.fft.rfftfreq(count, 1 / RATE)
    spectrum = np.fft.rfft(rng.normal(0, 1, count))
    shape = np.minimum(1, (frequencies / low) ** 2)
    shape *= 1 / (1 + (frequencies / high) ** 4)
    signal = np.fft.irfft(spectrum * shape, n=count)
    return signal / max(np.sqrt(np.mean(signal ** 2)), .001)


def band_limited_saw(phase, frequency, ceiling=12000):
    """Sawtooth from harmonics below [ceiling], so pitch sweeps never alias."""
    signal = np.zeros_like(phase)
    for k in range(1, 40):
        audible = (k * frequency) < ceiling
        signal += np.where(audible, np.sin(k * phase) / k, 0)
    return signal * (2 / np.pi)


def lowpass(signal, cutoff):
    """Gentle fixed low-pass: a second-order roll-off applied in frequency."""
    frequencies = np.fft.rfftfreq(len(signal), 1 / RATE)
    shape = 1 / np.sqrt(1 + (frequencies / cutoff) ** 4)
    return np.fft.irfft(np.fft.rfft(signal) * shape, n=len(signal))


def laser(t, firing):
    """Classic sci-fi beam: a rising whine that charges, then a zap and a
    humming, shimmering beam that holds and fades."""
    rng = np.random.default_rng(901 if firing else 900)
    duration = len(t) / RATE
    progress = t / duration
    sizzle = electrical_noise(rng, len(t), 2200, 7500)

    if not firing:
        # Pitch climbs faster near the end while its tremolo speeds up, so the
        # warning tightens into the shot.
        frequency = 220 * 6.5 ** (progress ** 1.6)
        phase = 2 * np.pi * np.cumsum(frequency) / RATE
        tone = (.6 * np.sin(phase) + .25 * np.sin(2 * phase)
                + .12 * np.sin(3 * phase))
        tone += .35 * np.sin(phase * 1.006)  # A second voice for chorus.
        rate = 6 + 26 * progress
        tremolo = .7 + .3 * np.sin(2 * np.pi * np.cumsum(rate) / RATE)
        level = (.25 + .75 * progress ** 1.3) * np.minimum(1, t / .02)
        return np.tanh(1.2 * level * (tremolo * tone + .1 * progress * sizzle))

    # The zap: a fast, dispersive downward chirp at the moment of firing.
    zap_frequency = 300 + 3900 * np.exp(-t / .018)
    zap_phase = 2 * np.pi * np.cumsum(zap_frequency) / RATE
    zap = np.sin(zap_phase) * decay(t, .05, .0005)

    # The beam: two detuned saws beat against each other under a pulsing
    # electric hum, with a high whine riding on top.
    base = 165 - 15 * progress
    beam_phase = 2 * np.pi * np.cumsum(base) / RATE
    beam = band_limited_saw(beam_phase, base)
    beam += band_limited_saw(beam_phase * 1.012, base * 1.012)
    beam = lowpass(beam, 2500)
    beam += .35 * np.sin(beam_phase / 2)
    beam *= .75 + .25 * np.sin(2 * np.pi * 48 * t)
    whine_phase = 2 * np.pi * np.cumsum(
        2350 * (1 + .015 * np.sin(2 * np.pi * 9 * t))) / RATE
    beam += .5 * np.sin(whine_phase)
    beam += .25 * sizzle
    hold = np.where(t < .4, 1, np.exp(-np.maximum(t - .4, 0) / .12))
    envelope = np.minimum(1, t / .008) * hold
    return np.tanh(1.4 * (.55 * zap + .45 * beam * envelope))


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
    elif name == "laserCharge":
        signal = laser(t, firing=False)
    elif name in ("mineCharge", "cometCharge"):
        start = 180 if name == "mineCharge" else 330
        end = 1000 if name == "mineCharge" else 1450
        rise = np.sin(np.pi * t / duration) ** .8
        signal = .45 * sweep(t, start, end, duration, .7) * rise
        signal += .25 * sweep(t, start * 1.5, end * 1.5, duration) * rise
        signal += .15 * soft * rise
        if name == "cometCharge":
            signal += .3 * np.sin(2 * np.pi * 1568 * t) * rise
    elif name == "laserFire":
        signal = laser(t, firing=True)
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", nargs="+", choices=DURATIONS,
                        help="Rebuild only the named cues and their preview.")
    args = parser.parse_args()
    clips, report = [], {}
    for name, duration in DURATIONS.items():
        signal = synth(name, duration)
        if args.only and name not in args.only:
            continue
        write(OUT / f"enemy_{name}.wav", signal)
        clips.extend([signal, np.zeros(round(.24 * RATE))])
        report[name] = {"seconds": duration,
                        "peak": round(float(np.max(np.abs(signal))), 4),
                        "rms": round(float(np.sqrt(np.mean(signal ** 2))), 4)}
    artifacts = ROOT / "artifacts"
    artifacts.mkdir(exist_ok=True)
    lasers_only = args.only and set(args.only) <= {"laserCharge", "laserFire"}
    stem = "laser-sound" if lasers_only else "enemy-sound"
    write(artifacts / f"{stem}-preview.wav", np.concatenate(clips))
    (artifacts / f"{stem}-report.json").write_text(json.dumps(report, indent=2))
    print(f"Generated {len(report)} original enemy cues; all peaks <= 0.72.")


if __name__ == "__main__":
    main()
