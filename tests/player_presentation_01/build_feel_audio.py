"""Deterministic, task-only derivatives of the existing licensed Kenney sources."""
import array, hashlib, json, math, subprocess, sys, wave
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/player_presentation_01/feel_audio_v1'

def decode(name):
    path = ROOT / ('assets/audio/kenney/' + name + '.ogg')
    source = json.loads((ROOT / 'assets/audio/kenney/sources.json').read_text())[name]
    assert hashlib.sha256(path.read_bytes()).hexdigest() == source['sha256']
    raw = subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-ar','48000','-ac','1','-f','f32le','-'])
    values = array.array('f'); values.frombytes(raw)
    # Remove leading silence for accepted-event alignment; preserve originals.
    first = next((i for i,v in enumerate(values) if abs(v) > 10 ** (-45/20)),0)
    return list(values[first:]), dict(path=str(path.relative_to(ROOT)), **source, trimmed_leading_samples=first)

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    sources = {}; provenance = []
    for name in ('jump','land','step','enemy_defeat'):
        sources[name], record = decode(name); provenance.append(record)
    entries = []
    recipes = {'jump':(.17,[('step',.25),('jump',.65)]),
               'land':(.21,[('land',.80),('jump',.12)]),
               'heavy':(.25,[('land',.72),('enemy_defeat',.45),('jump',.10)])}
    for cue,(duration,layers) in recipes.items():
        for variant,rate in enumerate((.985,1.0,1.015)):
            samples = []
            for i in range(int(duration*48000)):
                t=i/48000; value=0.0
                for name,gain in layers:
                    data=sources[name]; x=i*rate; index=int(x); frac=x-index
                    if index+1 < len(data): value += gain*(data[index]*(1-frac)+data[index+1]*frac)
                envelope=min(1.0,t/.002)*min(1.0,(duration-t)/.045)
                samples.append(value*envelope)
            peak=max(abs(v) for v in samples) or 1.0
            gain=(.72 if cue!='heavy' else .82)/peak * (1.0,.95,1.03)[variant]
            pcm=array.array('h',[round(max(-.98,min(.98,v*gain))*32767) for v in samples])
            path=OUT/(cue+'_'+str(variant)+'.wav')
            with wave.open(str(path),'wb') as w:
                w.setnchannels(1);w.setsampwidth(2);w.setframerate(48000);w.writeframes(pcm.tobytes())
            entries.append(dict(path=str(path.relative_to(ROOT)),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),cue=cue,variant=variant,source_rate=rate,duration_seconds=duration,peak_linear=max(abs(v) for v in pcm)/32767,frames=len(pcm)))
    record=dict(task='PLAYER-PRESENTATION-01',content_version='feel-audio-v1',tool='ffmpeg decode + Python stdlib deterministic interpolation/mix/envelopes',sources=provenance,recipes=recipes,processing='48k mono16;leading threshold-45dB;2ms attack,45ms tail;three offline +/-1.5% pitch variants,no runtime RNG,no original edits',license='Existing Kenney source CC0-1.0, retained source manifest/licenses;derivatives',user_listening='unverified',files=entries)
    (ROOT/'docs/worklines/PLAYER-PRESENTATION-01/feel-audio-provenance.json').write_text(json.dumps(record,indent=2)+'\n')
    print('FEEL AUDIO:',len(entries),'bounded variants generated; originals unchanged')

if __name__ == '__main__': main()
