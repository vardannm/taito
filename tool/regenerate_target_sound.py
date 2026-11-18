#!/usr/bin/env python3
"""Generate a soft wooden tok for a correct highlighted-hole landing through ElevenLabs."""
import argparse
from array import array
import getpass
import hashlib
import json
import os
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
import wave
from refresh_sound_effects import ROOT, process, write

PAYLOAD = dict(
    text='One small steel ball settling into a wooden cup. A single soft, rounded '
         'wooden tok with a tiny hollow resonance and a quick natural decay. '
         'Quiet and understated, suitable for a frequently repeated game action. '
         'Immediate onset, main impact under 0.2 seconds, then the tail fades '
         'naturally to silence. No metallic clang, musical notes, sparkle, bounce '
         'sequence, echo, voice, or background sound.',
    duration_seconds=.5, prompt_influence=.8, loop=False,
    model_id='eleven_text_to_sound_v2')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run',action='store_true')
    args=parser.parse_args()
    if args.dry_run: print(json.dumps(PAYLOAD,indent=2));return 0
    if not shutil.which('afconvert'): parser.error('Requires macOS afconvert.')
    stage=ROOT/'artifacts/target_sound_elevenlabs'
    stage.mkdir(parents=True,exist_ok=True)
    source=stage/'target.mp3'
    try:
        if not source.exists():
            key=os.environ.get('ELEVENLABS_API_KEY') or getpass.getpass('ElevenLabs API key (hidden; not saved): ')
            if not key.strip(): parser.error('An API key is required.')
            print('Generating one soft wooden target tok with ElevenLabs; this uses your allowance.',flush=True)
            request=urllib.request.Request(
                'https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128',
                data=json.dumps(PAYLOAD).encode(),method='POST',
                headers={'Content-Type':'application/json','xi-api-key':key.strip()})
            with urllib.request.urlopen(request,timeout=180) as response: audio=response.read()
            if len(audio)<100: raise ValueError('Empty audio response')
            with source.open('xb') as output: output.write(audio)
            (stage/'request.json').write_text(json.dumps(PAYLOAD,indent=2)+'\n')
        else: print('Using the saved ElevenLabs generation; no new API request.')
        decoded=stage/'decoded.wav'
        if decoded.exists(): decoded.unlink()
        target=stage/'target.wav'
        process(source,target,.5,decoded)
        with wave.open(str(target)) as audio: pcm=array('h',audio.readframes(audio.getnframes()))
        if sys.byteorder!='little': pcm.byteswap()
        # Keep the complete natural decay and a restrained peak.
        pcm=array('h',(round(v*.30/.68) for v in pcm))
        if sys.byteorder!='little': pcm.byteswap()
        write(target,pcm)
        manifest_path=ROOT/'assets/audio/SFX_MANIFEST.json'
        manifest=json.loads(manifest_path.read_text())
        for name in ['target']:
            destination=ROOT/'assets/audio'/(name+'.wav')
            backup=stage/(name+'_before.wav')
            if not backup.exists():shutil.copy2(destination,backup)
            shutil.copyfile(target,destination)
            manifest[name]=dict(seconds=.5,peak=.30,
                sha256=hashlib.sha256(destination.read_bytes()).hexdigest(),
                source='ElevenLabs eleven_text_to_sound_v2: tool/regenerate_target_sound.py')
        manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
        print('Installed the new ElevenLabs wooden target tok. Restart the game.')
        return 0
    except urllib.error.HTTPError as error:
        print(f'HTTP {error.code}: check Sound Effects permission and allowance. No automatic retry.',file=sys.stderr)
    except (OSError,ValueError,subprocess.CalledProcessError) as error:
        print(f'{type(error).__name__}: stopped. Check usage before retrying; any completed download is cached.',file=sys.stderr)
    return 1


if __name__=='__main__': sys.exit(main())
