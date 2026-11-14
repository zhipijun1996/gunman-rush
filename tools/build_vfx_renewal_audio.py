#!/usr/bin/env python3
"""Original, deterministic layered Foley/synth cues. No recordings or BGM edits."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/vfx_renewal'
RATE = 48000

def synth(name, duration, design=2):
    t = np.arange(round(duration*RATE))/RATE
    rng = np.random.default_rng(310+sum(name.encode())+design*31)
    white = rng.uniform(-1, 1, len(t))
    def noise(lo, hi):
        return sosfilt(butter(2, [lo, hi], btype='bandpass', fs=RATE, output='sos'), white)
    def env(a, d):
        return (1-np.exp(-t/a))*np.exp(-t/d)
    def tone(f, d, amp=1, start=0):
        u = np.maximum(0,t-start)
        return amp*np.sin(2*np.pi*f*u)*(1-np.exp(-u/.001))*np.exp(-u/d)*(t>=start)
    shade=[.78,1.17,1][design]
    if name.startswith('shot'):
        f=(145+int(name[-1])*8)*shade
        # Dry ignition crack, descending chamber pressure, mechanical breech tick.
        x=noise(1800,12500)*env(.0005,.018)*1.5
        x+=noise(180,2200)*env(.001,.050)*1.3
        x+=np.sin(2*np.pi*(f*t+90*.012*(1-np.exp(-t/.012))))*env(.001,.037)*.75
        x+=tone(2100,.009,.23,.028)+tone(3300,.006,.13,.036)
    elif name=='ice':
        x=noise(3200,14500)*env(.001,.04)*.9+noise(500,2600)*env(.003,.07)*.35
        for i,f in enumerate([1760,2430,3540,5270]):x+=tone(f,.055,.15,i*.012)
    elif name=='hit':
        x=noise(1100,10000)*env(.0007,.025)*1.5+noise(160,950)*env(.001,.04)
        x+=tone(720,.027,.45)+tone(1370,.019,.2,.008)
    elif name=='gather':
        # Breathing air bed and rising inharmonic glass voices. No old UI chirp.
        rise=np.minimum(1,t/.9)
        x=noise(450,4800)*(.06+.14*rise)*(np.sin(np.pi*np.minimum(t,1))**.5)
        for f,a in [(220,.11),(440,.1),(659.25,.07),(1046.5,.045)]:
            x+=np.sin(2*np.pi*f*t+1.7*t*t)*(.3+.7*rise)*a*(1+.18*np.sin(t*18))
        x*=np.minimum(1,t/.04)*np.minimum(1,np.maximum(0,duration-t)/.06)
    elif name=='restore':
        x=tone(164.81,.09,.45)+noise(700,4800)*env(.008,.09)*.25
        for f,a,start in [(659.25,.30,0),(987.77,.22,.06),(1318.51,.13,.10)]:
            x+=tone(f,.20,a,start)+tone(f*2.003,.055,a*.25,start)
    elif name=='boss_air':
        w=np.sin(np.pi*t/duration)**1.5
        x=noise(80,2400)*w*.65+noise(2500,7000)*w*.13
        x+=np.sin(2*np.pi*(110*t-35*t*t))*w*.10
    elif name=='boss_land':
        x=noise(60,750)*env(.001,.16)*1.3+noise(1300,6000)*env(.001,.036)*.55
        x+=np.sin(2*np.pi*(48*t+55*.025*(1-np.exp(-t/.025))))*env(.001,.16)*.7
        for f,a,s in [(310,.18,.012),(740,.13,.026),(1610,.08,.04)]:x+=tone(f,.13,a,s)
        # Short grit/stone afterbeats below the low impact.
        for s in [.09,.16,.24]:x+=noise(800,3600)*np.exp(-np.maximum(0,t-s)/.025)*(t>=s)*.16
    elif name=='gate':
        x=noise(300,2200)*env(.003,.055)*.5+tone(170,.035,.25)+tone(570,.04,.16,.015)
    elif name in ['chest','spill','bounce']:
        x=noise(140,1800)*env(.001,.05)*(.65 if name=='chest' else .13)
        strikes=[0,.043,.09,.155,.22] if name=='chest' else [0,.045,.09] if name=='spill' else [0]
        for i,s in enumerate(strikes):
            f=[1680,2310,1875,2960,2200][i]*shade
            x+=tone(f,.043,.21,s)+tone(f*2.71,.017,.10,s)+tone(f*.61,.021,.12,s)
        if name=='chest':x+=tone(220,.065,.24,.025)+noise(300,2100)*env(.02,.11)*.25
    elif name=='coin':
        x=tone(1568,.067,.35)+tone(3136,.035,.16)+tone(2093,.055,.26,.032)
    else:raise ValueError(name)
    # A tiny asymmetric room reflection binds the layers without a long reverb tail.
    delay=round(.021*RATE);x[delay:]+=x[:-delay].copy()*.09
    x*=np.minimum(1,np.maximum(0,duration-t)/.012)
    x=np.tanh(x*1.3)
    x*=.79/max(.01,np.max(np.abs(x)))
    return np.round(x*32767).astype('<i2')

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    cues={'shot0':.20,'shot1':.20,'shot2':.20,'hit':.21,'gather':1.04,'restore':.60,'boss_air':.62,'boss_land':.85,'chest':.55,'spill':.28,'bounce':.13,'coin':.22,'gate':.27,'ice':.28}
    manifest={'license':'CC0-1.0','source':'tools/build_vfx_renewal_audio.py','sample_rate':RATE,'cues':{}}
    for name,duration in cues.items():
        data=synth(name,duration)
        p=OUT/(name+'.wav')
        with wave.open(str(p),'wb') as w:
            w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(data.tobytes())
        manifest['cues'][name]={'duration':duration,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'peak':float(np.max(np.abs(data.astype(float)))/32768)}
    (OUT/'source.json').write_text(json.dumps(manifest,indent=2)+'\n')
    # Audible alternatives are audition artifacts, never extra runtime assets.
    lab=ROOT/'build/vfx/rework/audio-candidates';lab.mkdir(parents=True,exist_ok=True)
    for design in [0,1,2]:
        rows=[]
        for name,duration in cues.items():rows.extend([synth(name,duration,design),np.zeros(round(.18*RATE),dtype='<i2')])
        with wave.open(str(lab/f'direction-{design}.wav'),'wb') as w:
            w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(np.concatenate(rows).tobytes())
    print(f'{len(cues)} cues rebuilt, three audible direction reels')
if __name__=='__main__':main()
