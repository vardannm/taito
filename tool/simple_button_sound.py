"""Use one plain, quiet mechanical click for every UI action (NumPy; no API)."""
from pathlib import Path
import hashlib,json,wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
RATE=44100


def main():
    n=round(.04*RATE);t=np.arange(n)/RATE
    noise=np.random.default_rng(616).normal(size=n)
    f=np.fft.rfftfreq(n,1/RATE)
    response=f**2/(f**2+300**2)/(1+(f/2000)**6)
    a=np.fft.irfft(np.fft.rfft(noise)*response,n=n)
    a*=np.minimum(1,t/.001)*np.exp(-t/.005)
    a*=np.minimum(1,(.04-t)/.004)
    a[0]=a[-1]=0;a*=.30/np.max(np.abs(a))
    pcm=np.round(a*32767).astype('<i2').tobytes()
    manifest_path=ROOT/'assets/audio/SFX_MANIFEST.json'
    manifest=json.loads(manifest_path.read_text())
    for cue in ['tap','back','toggle','select']:
        name='ui_'+cue;path=ROOT/'assets/audio'/(name+'.wav')
        with wave.open(str(path),'wb') as w:
            w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(pcm)
        manifest[name]=dict(seconds=.04,peak=.30,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),source='Plain mechanical click, no pitched tones: tool/simple_button_sound.py')
    manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
    print('All four UI actions now use the same 40 ms plain click.')


if __name__=='__main__':main()
