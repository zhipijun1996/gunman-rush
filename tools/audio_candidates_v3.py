#!/usr/bin/env python3
"""Source-based V3 acquisition, liquid healing, chest, reward and weapon cues."""
from __future__ import annotations
import argparse,array,hashlib,json,math,subprocess,sys,tempfile,wave
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
CONFIG=ROOT/'config/audio_director/v3'
DEST=ROOT/'assets/audio/director_v3'
TOOL=Path(__file__)
RATE=44100
_DECODE_CACHE={}
_LAYER_CACHE={}


def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path):return json.loads(Path(path).read_text())
def write(path,value):Path(path).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
def version():return subprocess.check_output(['ffmpeg','-version'],text=True).splitlines()[0]
def fingerprints():return {'recipe_sha256':digest(CONFIG/'recipes.json'),'sources_sha256':digest(CONFIG/'sources.json'),'pipeline_sha256':digest(TOOL)}
def local(name):
    p=ROOT/name
    if not p.resolve().is_relative_to(ROOT.resolve()):raise ValueError('External source path')
    return p

def ffmpeg(args):
    p=subprocess.run(['ffmpeg','-nostdin','-v','error','-y',*map(str,args)],capture_output=True)
    if p.returncode:raise RuntimeError(p.stderr.decode(errors='replace')[-4000:])
    return p.stdout

def float_data(data):
    a=array.array('f',data)
    if sys.byteorder!='little':a.byteswap()
    return a

def decode(source):
    sha=digest(local(source['path']))
    if sha!=source['sha256']:raise ValueError('Source fingerprint changed')
    if sha not in _DECODE_CACHE:
        _DECODE_CACHE[sha]=float_data(ffmpeg(['-i',local(source['path']),'-ar',RATE,'-ac',1,'-f','f32le','-']))
    return _DECODE_CACHE[sha]

def pcm_metrics(samples):
    peak=max(map(abs,samples),default=0)
    rms=math.sqrt(sum(x*x for x in samples)/max(1,len(samples)))
    active=[i for i,x in enumerate(samples) if abs(x)>10**(-55/20)]
    return {'duration':round(len(samples)/RATE,6),'sample_rate':RATE,'channels':1,'format':'PCM16 WAV','peak_dbfs':round(20*math.log10(max(peak,1e-12)),6),'rms_dbfs':round(20*math.log10(max(rms,1e-12)),6),'non_silent_end_seconds':round((active[-1]+1)/RATE,6) if active else 0}

def measure(path):
    with wave.open(str(path)) as f:
        if f.getnchannels()!=1 or f.getsampwidth()!=2 or f.getframerate()!=RATE:raise ValueError('Expected mono PCM16 44.1kHz')
        a=array.array('h',f.readframes(f.getnframes()))
    if sys.byteorder!='little':a.byteswap()
    return {**pcm_metrics([x/32768 for x in a]),'sha256':digest(path),'bytes':Path(path).stat().st_size}

def inputs(config,sources):
    if config.get('sample_rate')!=RATE:raise ValueError('Unsupported sample rate')
    if set(config['profiles'])!={'A','B','C'} or len(config['events'])!=14:raise ValueError('Expected 14 events and three source designs')
    if len({e['id'] for e in config['events']})!=14:raise ValueError('Duplicate event')
    for sid,s in sources.items():
        if s.get('license')!='CC0-1.0' or not s.get('commercial_use') or s.get('attribution_required') is not False:raise ValueError('Unreviewed source')
        for k in ['author','original_filename','source_url','license_url','download_date','download_url','sha256']:
            if not s.get(k):raise ValueError('Missing source '+k)
        if digest(local(s['path']))!=s['sha256']:raise ValueError('Source fingerprint changed: '+sid)
    candidate_ids=[]
    for e in config['events']:
        if len(e['candidates'])!=3:raise ValueError('Missing design')
        if {c.get('profile') for c in e['candidates']}!={'A','B','C'}:
            raise ValueError('Each event must declare A/B/C exactly once')
        for c in e['candidates']:
            expected_id=e['id']+'_'+c['profile'].lower()
            if c.get('id')!=expected_id:raise ValueError('Candidate ID does not match event/profile runtime route')
            candidate_ids.append(c['id'])
            if not c['layers'] or any(l['source'] not in sources for l in c['layers']):raise ValueError('Missing licensed layer')
            if e['id']=='coin' and any('item_coins' in l['source'] for l in c['layers']):raise ValueError('Coin acquisition cannot reuse money landing')
            if e['id']=='heal' and not any(l['source'].startswith('water/') and l['gain']>=.5 for l in c['layers']):raise ValueError('Healing requires an audible liquid source body')
            for l in c['layers']:
                if l['clip_seconds']<=0 or l['gain']<=0 or l['delay_seconds']<0 or abs(l['pitch_semitones'])>24:raise ValueError('Invalid layer bounds')
    if len(candidate_ids)!=len(set(candidate_ids)):raise ValueError('Candidate IDs must be globally unique')

def layer_pcm(layer,sources,config):
    s=sources[layer['source']];samples=decode(s);threshold=10**(config['silence_threshold_dbfs']/20)
    active=[i for i,x in enumerate(samples) if abs(x)>threshold]
    if not active:raise ValueError('Silent layer source')
    start=max(0,active[0]-88)+round(layer['start_seconds']*RATE)
    end=min(len(samples),active[-1]+89,start+round(layer['clip_seconds']*RATE))
    if start>=end:raise ValueError('Empty layer crop')
    semitones=layer['pitch_semitones'];pitch=2**(semitones/12)
    filter_=f'asetrate={round(RATE*pitch)},aresample={RATE},highpass=f={layer["highpass_hz"]},lowpass=f={layer["lowpass_hz"]}'
    cache_key=(s['sha256'],start,end,filter_,layer['attack_seconds'],layer['release_seconds'])
    if cache_key not in _LAYER_CACHE:
        with tempfile.TemporaryDirectory(prefix='v3-layer-') as d:
            p=Path(d)/'source.f32';kept=array.array('f',samples[start:end]);
            if sys.byteorder!='little':kept.byteswap()
            p.write_bytes(kept.tobytes())
            shaped=float_data(ffmpeg(['-f','f32le','-ar',RATE,'-ac',1,'-i',p,'-af',filter_,'-f','f32le','-']))
        attack=min(round(layer['attack_seconds']*RATE),len(shaped)//4)
        release=min(round(layer['release_seconds']*RATE),len(shaped)//3)
        for i in range(attack):shaped[i]*=i/max(1,attack)
        for i in range(release):shaped[len(shaped)-1-i]*=i/max(1,release)
        _LAYER_CACHE[cache_key]=(shaped,attack,release)
    shaped,attack,release=_LAYER_CACHE[cache_key]
    trace={**layer,'input_path':s['path'],'input_sha256':s['sha256'],'source_frames':len(samples),'start_frame':start,'end_frame':end,'pitch_ratio':pitch,'ffmpeg_filter':filter_,'attack_frames':attack,'release_frames':release,'processed_frames':len(shaped),'delay_frames':round(layer['delay_seconds']*RATE)}
    return shaped,trace

def render(event,candidate,sources,config,path):
    layers=[layer_pcm(l,sources,config) for l in candidate['layers']]
    frames=min(round(event['max_seconds']*RATE),max(len(a)+t['delay_frames'] for a,t in layers))
    mixed=[0.0]*frames
    for samples,trace in layers:
        offset=trace['delay_frames'];gain=trace['gain']
        for i,x in enumerate(samples[:max(0,frames-offset)]):mixed[offset+i]+=x*gain
    measured=pcm_metrics(mixed)
    if measured['rms_dbfs']<-70 or frames<RATE*.015:raise ValueError('Silent/empty cue')
    gain=min(event['target_rms_dbfs']-measured['rms_dbfs'],config['peak_ceiling_dbfs']-measured['peak_dbfs'])
    multiplier=10**(gain/20)
    quantized=array.array('h',(max(-32768,min(32767,round(x*multiplier*32767))) for x in mixed))
    if sys.byteorder!='little':quantized.byteswap()
    with wave.open(str(path),'wb') as f:f.setparams((1,2,RATE,0,'NONE','not compressed'));f.writeframes(quantized.tobytes())
    return {'path':'res://'+path.relative_to(ROOT).as_posix(),'variant':1,'processing':'CC0 sampled layers; explicit crop/pitch/filter/envelope/timing; floating-point mix and bounded final gain; no generated oscillator/noise','layers':[t for a,t in layers],'normalization_gain_db':gain,'mixed_frames':frames,'pre_normalization_metrics':measured,**measure(path)}

def metadata_matches(manifest,config,sources):
    for k,v in fingerprints().items():
        if manifest.get(k)!=v:raise ValueError('Manifest '+k+' drift; full rebuild required')
    if manifest.get('sources')!=sources:raise ValueError('Source snapshot changed')
    for k in ['version','task','profiles','sample_rate','peak_ceiling_dbfs','reference_policy','preserve_original_events']:
        if manifest.get(k)!=config[k]:raise ValueError('Manifest metadata changed: '+k)
    if manifest.get('ffmpeg_version')!=version():raise ValueError('FFmpeg changed')
    if manifest.get('subjective_status')!='awaiting-user' or manifest.get('runtime_default')!='original':raise ValueError('Manifest cannot approve its own design')

def build():
    config=read(CONFIG/'recipes.json');sources=read(CONFIG/'sources.json')['sources'];inputs(config,sources);before=fingerprints()
    DEST.mkdir(parents=True,exist_ok=True);events=[]
    for e in config['events']:
        out={k:v for k,v in e.items() if k!='candidates'};out['candidates']=[]
        for c in e['candidates']:
            path=DEST/(c['id']+'.wav');r=render(e,c,sources,config,path)
            ids=list(dict.fromkeys(l['source'] for l in c['layers']))
            out['candidates'].append({'id':c['id'],'profile':c['profile'],'label':c['label'],'design':c['design'],'version':config['version'],'path':r['path'],'variants':[r['path']],'source_ids':ids,'raw_sources':[sources[s]['path'] for s in ids],'subjective_status':'awaiting-user','variant_policy':'one complete designed cue per profile for rapid audition; not claiming multiple takes','renders':[r],**{k:r[k] for k in ['duration','peak_dbfs','rms_dbfs','sha256']}})
        events.append(out)
    if fingerprints()!=before:raise ValueError('Source changed during render')
    m={k:config[k] for k in ['schema_version','version','task','profiles','sample_rate','peak_ceiling_dbfs','reference_policy','preserve_original_events']};m.update(runtime_default='original',subjective_status='awaiting-user',ffmpeg_version=version(),sources=sources,events=events,**before)
    write(DEST/'manifest.json',m);validate()

def validate():
    config=read(CONFIG/'recipes.json');sources=read(CONFIG/'sources.json')['sources'];m=read(DEST/'manifest.json');metadata_matches(m,config,sources);inputs(config,sources)
    if [e['id'] for e in m['events']]!=[e['id'] for e in config['events']]:raise ValueError('Event catalog changed')
    hashes=[]
    for e,recipe in zip(m['events'],config['events']):
        for k,v in recipe.items():
            if k!='candidates' and e.get(k)!=v:raise ValueError('Event metadata differs from recipe')
        if [c['id'] for c in e['candidates']]!=[c['id'] for c in recipe['candidates']]:raise ValueError('Candidate catalog changed')
        for c,rc in zip(e['candidates'],recipe['candidates']):
            for k in ['id','profile','label','design']:
                if c.get(k)!=rc[k]:raise ValueError('Candidate metadata changed')
            ids=list(dict.fromkeys(l['source'] for l in rc['layers']));expected='res://'+(DEST/(c['id']+'.wav')).relative_to(ROOT).as_posix()
            if c.get('path')!=expected or c.get('variants')!=[expected] or len(c.get('renders',[]))!=1:raise ValueError('Playback path/variants changed')
            if c.get('source_ids')!=ids or c.get('raw_sources')!=[sources[s]['path'] for s in ids]:raise ValueError('Candidate sources changed')
            if c.get('version')!=config['version'] or c.get('subjective_status')!='awaiting-user':raise ValueError('Candidate version/approval changed')
            if c.get('variant_policy')!='one complete designed cue per profile for rapid audition; not claiming multiple takes':raise ValueError('Candidate take policy changed')
            r=c['renders'][0]
            if r.get('path')!=expected:raise ValueError('Render path changed')
            for k in ['duration','peak_dbfs','rms_dbfs','sha256']:
                if c.get(k)!=r[k]:raise ValueError('Candidate summary changed')
            actual=measure(local(expected.removeprefix('res://')))
            if any(r.get(k)!=v for k,v in actual.items()):raise ValueError('Runtime output fingerprint changed')
            if actual['peak_dbfs']>config['peak_ceiling_dbfs']+.002 or actual['rms_dbfs']<-60:raise ValueError('Invalid output level')
            if actual['duration']>e['max_seconds']+.001:raise ValueError('Cue exceeds event timing')
            if e['id']=='item_get' and not 1.5<=actual['non_silent_end_seconds']<=3:raise ValueError('Item reward must contain an audible long phrase, not silent padding')
            if e['id']=='chest_open' and not .4<=actual['duration']<=1:raise ValueError('Chest cue timing invalid')
            root=ROOT/'build/audio-v3-validation';root.mkdir(parents=True,exist_ok=True)
            with tempfile.TemporaryDirectory(prefix='derive-',dir=root) as d:derived=render(recipe,rc,sources,config,Path(d)/'cue.wav')
            if {k:v for k,v in derived.items() if k!='path'}!={k:v for k,v in r.items() if k!='path'}:raise ValueError('DSP trace differs from recomputed sampled recipe')
            hashes.append(actual['sha256'])
    if len(hashes)!=42 or len(set(hashes))!=42:raise ValueError('Expected 42 distinct complete cues')
    print('AUDIO_CANDIDATES_V3_OK events=14 profiles=3 rendered_files=42')

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('command',choices=['build','validate']);a=p.parse_args()
    if a.command=='build':build()
    else:validate()
if __name__=='__main__':main()
