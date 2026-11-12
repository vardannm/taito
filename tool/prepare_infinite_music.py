"""Edit the decoded Infinite master into synchronized alternate loop arrangements.

Requires NumPy. Decode the MP3 to 16-bit PCM first with macOS afconvert:
  afconvert -f WAVE -d LEI16 artifacts/music/rollrise_infinite_master.mp3 source.wav
Run this script with source.wav. No generation or network requests are made.
"""

import argparse
import hashlib
import json
from pathlib import Path
import wave

import numpy as np


def write_wav(path, audio, rate):
    with wave.open(str(path), 'wb') as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(np.round(audio * 32767).astype('<i2').tobytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    with wave.open(str(args.source)) as source:
        rate = source.getframerate()
        if source.getnchannels() != 2 or source.getsampwidth() != 2:
            parser.error('Source must be stereo 16-bit PCM WAV.')
        audio = np.frombuffer(source.readframes(source.getnframes()), dtype='<i2')
        audio = audio.reshape(-1, 2).astype(float) / 32768
    if len(audio) < round(116 * rate):
        parser.error('Expected the full two-minute recording.')
    count = round(30 * rate)  # 12 bars at the measured 96 BPM.
    overlap = round(2.5 * rate)  # One full bar at 96 BPM.
    rendered_count = count + overlap + round(.25 * rate)
    assets = root / 'assets/audio'
    artifacts = root / 'artifacts/music'
    artifacts.mkdir(parents=True, exist_ok=True)
    variants = []
    report = dict(bpm=96, loop_seconds=30, overlap_seconds=2.5,
                  file_seconds=32.75, bars=12, sample_rate=rate,
                  source_sha256=hashlib.sha256(args.source.read_bytes()).hexdigest(),
                  arrangements=[])
    # Measured onset phases relative to each section. Starting before a downbeat
    # retains its attack; 5-second handles avoid the generated section changes.
    for name, section, phase in [('climb', 0, .044), ('fast', 40, .054), ('boss', 80, .058)]:
        start = round((section + 5 + phase) * rate)
        # Keep the real recorded continuation beyond the repeating body. The
        # player overlaps this tail with the next copy before either file ends.
        pad = round(.2 * rate)
        raw = audio[start-pad:start+rendered_count+pad].copy()
        frequencies = np.fft.rfftfreq(len(raw), 1 / rate)
        bass_db = -5 / (1 + (frequencies / 180) ** 4)
        treble_db = -3 / (1 + (5500 / np.maximum(frequencies, 1)) ** 6)
        response = 10 ** ((bass_db + treble_db) / 20)
        response *= frequencies ** 2 / (frequencies ** 2 + 35 ** 2)
        loop = np.fft.irfft(np.fft.rfft(raw, axis=0) * response[:, None],
                            n=len(raw), axis=0)[pad:pad+rendered_count]
        # Match perceived backing level: intensity comes from arrangement,
        # rather than making the boss suddenly much louder.
        gain = min(.13 / np.sqrt(np.mean(loop ** 2)), .82 / np.max(np.abs(loop)))
        loop *= gain
        assert loop.shape == (rendered_count, 2) and np.isfinite(loop).all()
        filename = f'theme_infinite_{name}.wav'
        write_wav(assets / filename, loop, rate)
        variants.append(loop)
        report['arrangements'].append(dict(
            asset=filename, source_start_seconds=start / rate,
            rms=float(np.sqrt(np.mean(loop ** 2))), peak=float(np.max(np.abs(loop))),
            overlap_seconds=2.5,
            bytes=(assets / filename).stat().st_size,
        ))
    # Audition the same blends used by runtime: opening, build, boss, return.
    length = 60 * rate
    time = np.arange(length) / rate
    intensity = np.clip((time - 8) / 12, 0, 1)
    boss = np.minimum(np.clip((time - 26) / 2.5, 0, 1),
                      np.clip((47 - time) / 2.5, 0, 1))
    intensity *= np.clip((56 - time) / 8, 0, 1)
    mix = np.column_stack(((1 - intensity) * (1 - boss),
                           intensity * (1 - boss), boss))
    def repeat(variant, frames):
        result = variant[np.arange(frames) % count].copy()
        angle = np.linspace(0, np.pi / 2, overlap)[:, None]
        for boundary in range(count, frames, count):
            amount = min(overlap, frames-boundary)
            result[boundary:boundary+amount] = (
                variant[count:count+amount] * np.cos(angle[:amount]) +
                variant[:amount] * np.sin(angle[:amount]))
        return result
    preview = sum(repeat(variant, length) * mix[:, i, None]
                  for i, variant in enumerate(variants))
    # Two complete wraps of the normal arrangement for judging the repair.
    loop_preview = repeat(variants[0], 65 * rate)
    fade = round(.4 * rate)
    loop_preview[:fade] *= np.linspace(0, 1, fade)[:, None]
    loop_preview[-fade:] *= np.linspace(1, 0, fade)[:, None]
    write_wav(artifacts / 'rollrise_infinite_loop_fixed_preview.wav', loop_preview, rate)
    seam = repeat(variants[0], 40 * rate)[26 * rate:38 * rate].copy()
    seam[:fade] *= np.linspace(0, 1, fade)[:, None]
    seam[-fade:] *= np.linspace(1, 0, fade)[:, None]
    write_wav(artifacts / 'rollrise_infinite_join_preview.wav', seam, rate)
    fade = round(.4 * rate)
    preview[:fade] *= np.linspace(0, 1, fade)[:, None]
    preview[-fade:] *= np.linspace(1, 0, fade)[:, None]
    assert np.max(np.abs(preview)) < 1
    write_wav(artifacts / 'rollrise_infinite_adaptive_preview.wav', preview, rate)
    report['total_asset_bytes'] = sum(a['bytes'] for a in report['arrangements'])
    (artifacts / 'rollrise_infinite_loops.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
