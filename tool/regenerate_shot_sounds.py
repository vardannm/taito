#!/usr/bin/env python3
"""Regenerate only spider/hedgehog shooting effects through ElevenLabs."""
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

CUES = {
    'enemy_web': (.22, 'One spider releases a small strand of silk: a soft, short '
        'elastic thread flick with a gentle airy finish. Understated organic game '
        'effect. No creature voice, insect buzz, squelch or metallic ringing.'),
    'enemy_quills': (.25, 'One hedgehog releases a small fan of quills: a light '
        'brief brush of air, like a few soft bristles flicked forward. Understated '
        'organic game effect. No animal voice, explosive shot, sharp whistle or hiss.'),
}


def payload(description):
    return dict(text=description + ' Single action immediately at the start, '
        'finished within a quarter second, then silence. Quiet, dry, close and '
        'simple. No music, tones, speech, ambience, echo, heavy bass, repeated '
        'clicks, or piercing high frequencies.', duration_seconds=.5,
        prompt_influence=.8, loop=False, model_id='eleven_text_to_sound_v2')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run',action='store_true')
    args=parser.parse_args()
    if args.dry_run:
        print(json.dumps({name:payload(description) for name,(_,description) in CUES.items()},indent=2))
        return 0
    if not shutil.which('afconvert'): parser.error('Requires macOS afconvert.')
    stage=ROOT/'artifacts/shot_sounds_elevenlabs'
    stage.mkdir(parents=True,exist_ok=True)
    key=None; prepared={}; montage=array('h')
    try:
        for name,(seconds,description) in CUES.items():
            source=stage/(name+'.mp3')
            if not source.exists():
                if key is None:
                    key=os.environ.get('ELEVENLABS_API_KEY') or getpass.getpass('ElevenLabs API key (hidden; not saved): ')
                    if not key.strip(): parser.error('An API key is required.')
                print(f'Generating {name} through ElevenLabs; this uses your allowance.',flush=True)
                params=payload(description)
                request=urllib.request.Request(
                    'https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128',
                    data=json.dumps(params).encode(),method='POST',
                    headers={'Content-Type':'application/json','xi-api-key':key.strip()})
                with urllib.request.urlopen(request,timeout=180) as response: audio=response.read()
                if len(audio)<100: raise ValueError('Empty audio response')
                with source.open('xb') as output: output.write(audio)
                source.with_suffix('.request.json').write_text(json.dumps(params,indent=2)+'\n')
            else: print(f'{name}: using cached ElevenLabs audio.')
            decoded=stage/(name+'_decoded.wav')
            if decoded.exists(): decoded.unlink()
            target=stage/(name+'.wav')
            process(source,target,seconds,decoded)
            with wave.open(str(target)) as audio: pcm=array('h',audio.readframes(audio.getnframes()))
            if sys.byteorder!='little': pcm.byteswap()
            pcm=array('h',(round(value*.38/.68) for value in pcm))
            # Preview at current gameplay volume; never normalize it back up.
            montage.extend(round(value*.16) for value in pcm)
            montage.extend([0]*round(.6*44100))
            if sys.byteorder!='little': pcm.byteswap()
            write(target,pcm); prepared[name]=(target,seconds)
        # Replace neither effect until both generations have decoded successfully.
        manifest_path=ROOT/'assets/audio/SFX_MANIFEST.json'
        manifest=json.loads(manifest_path.read_text())
        for name,(target,seconds) in prepared.items():
            destination=ROOT/'assets/audio'/(name+'.wav')
            backup=stage/(name+'_before.wav')
            if not backup.exists(): shutil.copy2(destination,backup)
            shutil.copyfile(target,destination)
            manifest[name]=dict(seconds=seconds,peak=.38,
                sha256=hashlib.sha256(destination.read_bytes()).hexdigest(),
                source='ElevenLabs eleven_text_to_sound_v2: tool/regenerate_shot_sounds.py')
        manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
        if sys.byteorder!='little': montage.byteswap()
        write(stage/'shot_sounds_preview.wav',montage)
        print('Installed both ElevenLabs shooting effects. Appearance sounds remain silent. Restart the game.')
        return 0
    except urllib.error.HTTPError as error:
        print(f'HTTP {error.code}: check Sound Effects permission and allowance. No automatic retry.',file=sys.stderr)
    except (OSError,ValueError,subprocess.CalledProcessError) as error:
        print(f'{type(error).__name__}: stopped; completed downloads are cached. Check usage before retrying.',file=sys.stderr)
    return 1


if __name__=='__main__': sys.exit(main())
