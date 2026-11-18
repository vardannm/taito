"""Install approved Classic music and refine specific effects (NumPy, no API)."""
from pathlib import Path
import wave,json,hashlib,shutil
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/audio'
ART=ROOT/'artifacts/sound_refinements'
RATE=44100


def write(path,a):
    with wave.open(str(path),'wb') as w:
        w.setnchannels(1 if a.ndim==1 else a.shape[1]);w.setsampwidth(2);w.setframerate(RATE)
        w.writeframes(np.round(np.clip(a,-1,1)*32767).astype('<i2').tobytes())


def main():
    ART.mkdir(parents=True,exist_ok=True)
    for source,name in [('rollrise_levels_loop.wav','theme_classic_1_40.wav'),('rollrise_levels_41_80_no_ticks_loop.wav','theme_classic_41_80.wav')]:
        with wave.open(str(ROOT/'artifacts/music'/source)) as w:
            assert w.getframerate()==RATE and w.getnchannels()==2
            a=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,2)/32768
        # Identical circular continuation; complementary fades avoid +3 dB gain.
        write(OUT/name,np.concatenate([a,a[:round(1.25*RATE)]]))
    rng=np.random.default_rng(20261106)
    manifest=json.loads((OUT/'SFX_MANIFEST.json').read_text())
    montage=[]
    for name,duration,peak,volume in [('miss',.45,.42,.28),('merge',.30,.38,.16),('enemy_web',.22,.38,.16),('enemy_quills',.25,.38,.16)]:
        t=np.arange(round(duration*RATE))/RATE
        noise=rng.normal(size=len(t))
        f=np.fft.rfftfreq(len(t),1/RATE)
        noise=np.fft.irfft(np.fft.rfft(noise)*(f*f/(f*f+300**2))/(1+(f/1800)**6),n=len(t))
        noise/=max(np.std(noise),.001)
        if name=='miss':
            # Low, hollow impact followed by a soft airy release; no sad jingle.
            phase=2*np.pi*(250*t-120*t*t)
            a=(np.sin(phase)+.17*np.sin(phase*1.6))*np.exp(-t/.055)
            a+=.07*noise*np.exp(-t/.075)
        elif name=='merge':
            # Liquid droplet: resonant gliding partials, short bubble and damped tail.
            frequency=520+650*np.exp(-t/.018)
            phase=2*np.pi*np.cumsum(frequency)/RATE
            a=(np.sin(phase)+.18*np.sin(phase*1.48))*np.exp(-t/.040)
            a+=.045*noise*np.exp(-t/.012)
        elif name=='enemy_web':
            phase=2*np.pi*(410*t-500*t*t)
            a=.65*np.sin(phase)*np.exp(-t/.035)+.09*noise*np.exp(-t/.03)
        else:
            # Short brush of air, rather than a piercing metallic quill whistle.
            a=noise*np.exp(-t/.045)+.12*np.sin(2*np.pi*650*t)*np.exp(-t/.025)
        a*=np.sin(np.minimum(t/.006,1)*np.pi/2)**2
        a*=np.sin(np.minimum((duration-t)/.035,1)*np.pi/2)**2
        a[0]=a[-1]=0;a*=peak/np.max(np.abs(a))
        path=OUT/(name+'.wav'); backup=ART/(name+'_before.wav')
        if not backup.exists():shutil.copy2(path,backup)
        write(path,a)
        manifest[name]=dict(seconds=duration,peak=peak,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),source='Original sound refinement: tool/refine_audio.py')
        montage.extend([a*volume,np.zeros(round(.4*RATE))])
    (OUT/'SFX_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for name,vol in [('enemy_laserCharge',.13),('enemy_laserFire',.18)]:
        with wave.open(str(OUT/(name+'.wav'))) as w:a=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2')/32768
        montage.extend([a*vol,np.zeros(round(.4*RATE))])
    write(ART/'updated_effects_preview.wav',np.concatenate(montage))
    print('Installed both Classic tracks and four refined effects; no API calls.')


if __name__=='__main__': main()
