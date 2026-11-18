#!/usr/bin/env python3
"""Generate and install the complete Rollrise effects pack with ElevenLabs.

macOS; Python standard library only. Enter the key at the private prompt.
Completed downloads are cached; no network request is retried automatically.
"""
import argparse
from array import array
import getpass
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
# Existing warning lengths are preserved: gameplay and voice limits use them.
CUES = {
 'target': (.30, 'A delicate warm glass-and-mallet two-note ascending reward, D then A, immediate onset.'),
 'coin': (.18, 'One tiny rounded metallic coin sparkle, bright but soft, a single quick reward.'),
 'merge': (.30, 'Two soft rounded electronic droplets joining into one uplifting resonant tone.'),
 'star': (.50, 'A graceful three-note rising crystalline star reward in D minor, soft shimmering tail.'),
 'miss': (.45, 'One short descending wooden electronic thud, gentle disappointed pitch bend, no explosion.'),
 'complete': (.85, 'A satisfying warm four-note arcade success flourish in D minor resolving upward, elegant and restrained.'),
 'ui_tap': (.10, 'One very short soft tactile ceramic button press, rounded woody pop, no sharp click.'),
 'ui_back': (.12, 'One soft downward airy interface pop, a gentle back-navigation cue.'),
 'ui_toggle': (.12, 'One subtle rounded switch pop with a tiny warm tonal finish.'),
 'ui_select': (.16, 'One short warm glass selection pluck, clear but delicate.'),
 'enemy_insectArrival': (.28, 'A tiny alien insect briefly unfurls its shell with a soft organic flutter.'),
 'enemy_wingArrival': (.40, 'One brief moth-wing flutter and airy soft swoosh, close and delicate.'),
 'enemy_snakeHiss': (.50, 'One restrained dry snake hiss, smooth and organic, no high pitched screech.'),
 'enemy_wardenArrival': (.85, 'A mechanical sky guardian arrives with a rounded turbine swell and descending midrange tone.'),
 'enemy_colossusArrival': (.95, 'A large stone machine arrives, layered midrange metallic resonance and soft thunder, very little sub bass.'),
 'enemy_seraphArrival': (1.05, 'An eclipse guardian materializes with ethereal rising glass harmonics, dark and graceful.'),
 'enemy_prismArrival': (.90, 'A prism guardian arrives with a single refracting glass sweep and rounded resonant crystal shimmer.'),
 'enemy_venomArrival': (.90, 'A venom guardian emerges with a dark organic liquid swell and restrained acidic hiss.'),
 'enemy_novaArrival': (.90, 'A stellar guardian powers up with one rising luminous electronic pulse and soft spatial resonance.'),
 'enemy_bullet': (.14, 'One soft short midrange sci-fi projectile puff, rounded onset and quick downward pitch.'),
 'enemy_ricochet': (.22, 'One small metallic sci-fi projectile deflection with a rounded bending tone.'),
 'enemy_bounce': (.16, 'One tiny elastic glass projectile bounce, soft and distinct.'),
 'enemy_petal': (.28, 'One airy magical petal launched, light flowing whistle with rounded attack.'),
 'enemy_crystal': (.32, 'One crystal shard launches with a short warm glass shimmer, no piercing ringing.'),
 'enemy_laserCharge': (.80, 'A continuous sci-fi laser charging swell, smoothly rising midrange electrical whine with increasing tension, no shot yet.'),
 'enemy_laserFire': (.75, 'One clear sci-fi laser discharge followed by a smooth brief electric beam hum, no harsh crack or heavy bass.'),
 'enemy_bombThrow': (.30, 'One compact mechanical bomb toss, rounded spring launch and a short airy arc.'),
 'enemy_poolLand': (.36, 'One small viscous acid droplet lands with a soft bubbling wet splash.'),
 'enemy_mineCharge': (.85, 'One proximity mine arming warning, a smooth rising tense electronic hum, no repeated ticking.'),
 'enemy_mineFire': (.40, 'One restrained sci-fi mine burst, broad midrange energy puff, no booming low end.'),
 'enemy_cometCharge': (.65, 'One magical comet gathers energy, rising airy luminous swell, no impact yet.'),
 'enemy_cometFire': (.38, 'One comet releases with a flowing bright descending whoosh, smooth rounded attack.'),
 'enemy_web': (.22, 'One sticky spider web strand shoots out, quick soft elastic organic twang.'),
 'enemy_quills': (.25, 'One small fan of quills launches, a brief dry organic brush-like whoosh.'),
}
STYLE = ('Isolated single game sound effect for a polished warm electronic arcade game. '
         'Immediate onset; the audible action must finish within {seconds} seconds, followed by silence. '
         'No music, vocals, speech, background ambience, looping, repeated clicks, harsh highs, or heavy bass. ')


def write(path, samples):
    with wave.open(str(path), 'wb') as output:
        output.setnchannels(1); output.setsampwidth(2); output.setframerate(RATE)
        output.writeframes(samples.tobytes())


def process(source, output, seconds, decoded):
    subprocess.run(['afconvert', '-f', 'WAVE', '-d', 'LEI16@44100', '-c', '1',
                    str(source), str(decoded)], check=True, capture_output=True)
    with wave.open(str(decoded)) as audio:
        if (audio.getframerate(), audio.getnchannels(), audio.getsampwidth()) != (RATE, 1, 2):
            raise ValueError('Unexpected decoded audio format')
        samples = array('h', audio.readframes(audio.getnframes()))
    if sys.byteorder != 'little': samples.byteswap()
    peak = max(abs(v) for v in samples)
    if peak < 100: raise ValueError('Generated effect is effectively silent')
    # Find the onset with a small pre-roll; preserve the existing gameplay timing.
    onset = next(i for i, v in enumerate(samples) if abs(v) >= peak * .05)
    start = max(0, onset - round(.003 * RATE))
    count = round(seconds * RATE)
    clipped = list(samples[start:start+count])
    clipped += [0] * (count - len(clipped))
    mean = sum(clipped) / count
    floats = [v - mean for v in clipped]
    attack = round(.003 * RATE); release = min(round(.025 * RATE), count // 4)
    for i in range(attack): floats[i] *= .5 - .5 * math.cos(math.pi * i / attack)
    for i in range(release): floats[-1-i] *= .5 - .5 * math.cos(math.pi * i / release)
    gain = .68 * 32767 / max(abs(v) for v in floats)
    pcm = array('h', (round(v * gain) for v in floats))
    if sys.byteorder != 'little': pcm.byteswap()
    write(output, pcm)
    return dict(seconds=seconds, peak=.68, sha256=hashlib.sha256(output.read_bytes()).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true', help='List the plan without using credits')
    args = parser.parse_args()
    if args.dry_run:
        print(json.dumps(CUES, indent=2)); return 0
    if not shutil.which('afconvert'):
        parser.error('This command needs the macOS afconvert audio converter.')
    stage = ROOT / 'artifacts/audio_refresh'
    raw = stage / 'raw'; processed = stage / 'processed'; backup = stage / 'previous'
    for path in [raw, processed, backup]: path.mkdir(parents=True, exist_ok=True)
    key = os.environ.get('ELEVENLABS_API_KEY') or getpass.getpass('ElevenLabs API key (hidden; not saved): ')
    if not key.strip(): parser.error('An API key is required.')
    print(f'Refreshing {len(CUES)} effects. Each missing generation uses your allowance.', flush=True)
    report = {}; montage = array('h')
    for index, (name, (seconds, description)) in enumerate(CUES.items(), 1):
        source = raw / (name + '.mp3'); target = processed / (name + '.wav')
        payload = dict(text=STYLE.format(seconds=seconds) + description,
                       duration_seconds=max(.5, seconds+.10), prompt_influence=.6,
                       model_id='eleven_text_to_sound_v2', loop=False)
        print(f'[{index}/{len(CUES)}] {name}' + (' (cached)' if source.exists() else ''), flush=True)
        try:
            if not source.exists():
                request = urllib.request.Request(
                    'https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128',
                    data=json.dumps(payload).encode(), method='POST',
                    headers={'Content-Type': 'application/json', 'xi-api-key': key.strip()})
                with urllib.request.urlopen(request, timeout=180) as response: audio = response.read()
                if len(audio) < 100: raise ValueError('Empty audio response')
                with source.open('xb') as output: output.write(audio)
                source.with_suffix('.request.json').write_text(json.dumps(payload, indent=2)+'\n')
            decoded = stage / (name + '_decoded.wav')
            if decoded.exists(): decoded.unlink()
            report[name] = process(source, target, seconds, decoded)
            decoded.unlink()
            with wave.open(str(target)) as audio:
                montage.frombytes(audio.readframes(audio.getnframes()))
            montage.extend([0]*round(.30*RATE))
        except urllib.error.HTTPError as error:
            print(f'HTTP {error.code}: check Sound Effects permission and allowance. '
                  'Stopped without retrying; rerun to resume from cached downloads.', file=sys.stderr)
            return 1
        except (OSError, ValueError, subprocess.CalledProcessError) as error:
            print(f'{name}: {type(error).__name__}. Stopped; completed downloads are cached. '
                  'Check usage before retrying a request that may have reached the server.', file=sys.stderr)
            return 1
    # Install only after the entire pack has decoded and passed PCM checks.
    assets = ROOT / 'assets/audio'
    for name in CUES:
        destination = assets / (name + '.wav')
        if destination.exists() and not (backup / destination.name).exists():
            shutil.copy2(destination, backup / destination.name)
        temp = destination.with_suffix('.wav.tmp')
        shutil.copyfile(processed / destination.name, temp)
        temp.replace(destination)
    write(stage / 'sound_pack_preview.wav', montage)
    (stage / 'report.json').write_text(json.dumps(report, indent=2)+'\n')
    (assets / 'SFX_MANIFEST.json').write_text(json.dumps(report, indent=2)+'\n')
    print('Installed all 34 effects. Preview: artifacts/audio_refresh/sound_pack_preview.wav')
    print('Original files backed up in artifacts/audio_refresh/previous. Restart the game.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
