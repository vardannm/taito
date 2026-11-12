"""Make a beat-aligned circular WAV loop from a decoded PCM WAV (requires NumPy).

Decode MP3 first with: afconvert -f WAVE -d LEI16 source.mp3 source.wav
The audition repeats the loop twice, with fades only at the audition's outer edges.
"""

import argparse
import json
from pathlib import Path
import wave

import numpy as np


def save(path, audio, rate):
    with wave.open(str(path), "wb") as output:
        output.setnchannels(audio.shape[1])
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(np.round(np.clip(audio, -1, 1) * 32767).astype('<i2').tobytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--bpm', type=float, default=104)
    parser.add_argument('--bars', type=int, default=8)
    parser.add_argument('--start-bar', type=int, default=2)
    parser.add_argument('--crossfade', type=float, default=.16)
    parser.add_argument('--output-dir', type=Path, default=Path('artifacts/music'))
    parser.add_argument('--name', default='rollrise_levels_loop',
                        help='Filename stem for the loop, preview and report')
    args = parser.parse_args()
    if not args.name or Path(args.name).name != args.name or args.name in ('.', '..'):
        parser.error('Name must be a plain filename stem.')
    if args.bpm <= 0 or args.bars < 1 or args.start_bar < 1 or args.crossfade <= 0:
        parser.error('Tempo, bars, start bar and crossfade must be positive.')
    with wave.open(str(args.source)) as source:
        if source.getsampwidth() != 2:
            parser.error('Input must be 16-bit PCM WAV.')
        rate = source.getframerate()
        audio = np.frombuffer(source.readframes(source.getnframes()), dtype='<i2')
        audio = audio.reshape(-1, source.getnchannels()).astype(float) / 32768
    bar = 4 * 60 / args.bpm
    join = round(args.crossfade * rate)
    # Start just before the downbeat so the crossfade preserves the drum attack.
    start = round(args.start_bar * bar * rate) - join
    count = round(args.bars * bar * rate)
    if start < 0 or join >= count or start + count + join > len(audio):
        parser.error('Selected phrase and crossfade do not fit in the source.')
    music = audio[start:start + count].copy()
    weight = (.5 - .5 * np.cos(np.linspace(0, np.pi, join)))[:, None]
    # The outgoing audio continues naturally across the file boundary, then
    # blends into the beginning. Length stays an exact whole number of bars.
    music[:join] = audio[start + count:start + count + join] * (1 - weight) + music[:join] * weight
    args.output_dir.mkdir(parents=True, exist_ok=True)
    paths = [args.output_dir / f'{args.name}{suffix}'
             for suffix in ('.wav', '_preview.wav', '.json')]
    if any(path.exists() for path in paths):
        parser.error('Output already exists; choose a different --name.')
    save(paths[0], music, rate)
    preview = np.concatenate([music, music])
    fade = min(round(.4 * rate), count)
    ramp = np.linspace(0, 1, fade)[:, None]
    preview[:fade] *= ramp
    preview[-fade:] *= ramp[::-1]
    save(paths[1], preview, rate)
    report = dict(bpm=args.bpm, bars=args.bars, seconds=count / rate,
                  source_start_seconds=start / rate, crossfade_seconds=join / rate,
                  peak=float(np.max(np.abs(music))),
                  boundary_step=float(np.max(np.abs(music[0] - music[-1]))))
    paths[2].write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
