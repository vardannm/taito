"""Replace only noisy pickup/laser effects with subdued original sound designs.

Requires NumPy; no external API or credits. Preserves game cue durations.
"""
from pathlib import Path
import hashlib
import json
import shutil
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RATE = 44100


def write(path, audio):
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(np.round(audio * 32767).astype('<i2').tobytes())


def main():
    assets = ROOT / 'assets/audio'
    artifacts = ROOT / 'artifacts/quiet_effects'
    artifacts.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(20261105)
    manifest_path = assets / 'SFX_MANIFEST.json'
    manifest = json.loads(manifest_path.read_text())
    clips = {}
    for name, duration in [('coin', .18), ('enemy_laserCharge', .8), ('enemy_laserFire', .75)]:
        t = np.arange(round(duration * RATE)) / RATE
        if name == 'coin':
            # A single muted tactile droplet, not a bell, melody or metallic sparkle.
            phase = 2 * np.pi * (420 * t - 420 * t * t)
            signal = (np.sin(phase) + .1 * np.sin(2 * phase)) * np.exp(-t / .015)
            attack, release, peak = .006, .025, .28
        else:
            # Soft low-voltage transformer texture; no chirp, zap or high whine.
            noise = rng.normal(size=len(t))
            frequencies = np.fft.rfftfreq(len(t), 1 / RATE)
            shape = (frequencies / 400)**2 / (1 + (frequencies / 400)**2)
            shape *= 1 / (1 + (frequencies / 1000)**6)
            noise = np.fft.irfft(np.fft.rfft(noise) * shape, n=len(t))
            noise /= max(np.std(noise), .001)
            hum = np.sin(2 * np.pi * 180 * t) + .3 * np.sin(2 * np.pi * 360 * t)
            signal = .7 * hum + .035 * noise
            signal *= .94 + .06 * np.sin(2 * np.pi * 24 * t)
            if name.endswith('Charge'):
                signal *= .15 + .85 * (t / duration)**1.5
            else:
                signal *= np.exp(-t / .32)
            attack, release, peak = .04, .10, .30
        envelope = np.sin(np.minimum(t / attack, 1) * np.pi / 2)**2
        envelope *= np.sin(np.minimum((duration - t) / release, 1) * np.pi / 2)**2
        signal *= envelope
        signal[0] = signal[-1] = 0
        signal *= peak / max(np.max(np.abs(signal)), .001)
        file = assets / (name + '.wav')
        backup = artifacts / (name + '_before.wav')
        if not backup.exists(): shutil.copy2(file, backup)
        write(file, signal)
        manifest[name] = dict(seconds=duration, peak=peak,
                             sha256=hashlib.sha256(file.read_bytes()).hexdigest(),
                             source='Original subdued procedural design: tool/quiet_effects.py')
        clips[name] = signal
    manifest_path.write_text(json.dumps(manifest, indent=2)+'\n')
    # Preview at actual relative in-game volumes. Repeat pickups with the new
    # 500ms spacing so magnet collection can be judged in context.
    demo = np.zeros(RATE * 8)
    def place(at, name, volume):
        a=clips[name]*volume; i=round(at*RATE); demo[i:i+len(a)] += a
    place(.4,'enemy_laserCharge',.13)
    place(1.2,'enemy_laserFire',.18)
    for i in range(8): place(3+i*.5,'coin',.025)
    write(artifacts / 'quiet_lasers_and_pickups.wav', demo)
    print('Installed quiet electrical lasers and subtle pickup cue. No credits used.')


if __name__ == '__main__':
    main()
