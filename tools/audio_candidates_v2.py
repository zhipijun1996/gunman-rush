#!/usr/bin/env python3
"""Build three source-led SFX sets. Single recorded take per cue, no synthesis."""
from __future__ import annotations
import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / 'config/audio_director/v2'
DEST = ROOT / 'assets/audio/director_v2'
TOOL = Path(__file__)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text())


def write(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n')


def fingerprints():
    return {'recipe_sha256':digest(CONFIG/'recipes.json'), 'sources_sha256':digest(CONFIG/'sources.json'), 'pipeline_sha256':digest(TOOL)}


def source_path(value):
    path=ROOT/value
    if not path.resolve().is_relative_to(ROOT.resolve()):
        raise ValueError('Source path leaves repository')
    return path


def metrics(path):
    import wave
    with wave.open(str(path),'rb') as f:
        width=f.getsampwidth()
        if f.getnchannels()!=1 or width not in (2,4):raise ValueError('Expected mono PCM16/32')
        rate=f.getframerate();frames=f.getnframes();samples=array.array('h' if width==2 else 'i', f.readframes(frames))
    if sys.byteorder!='little':samples.byteswap()
    scale=2**(width*8-1)
    rms=math.sqrt(sum((x/scale)**2 for x in samples)/max(1,len(samples)))
    peak=max((abs(x)/scale for x in samples),default=0)
    return {'duration':round(frames/rate,6),'sample_rate':rate,'channels':1,'format':f'PCM{width*8} WAV','rms_dbfs':round(20*math.log10(max(rms,1e-12)),5),'peak_dbfs':round(20*math.log10(max(peak,1e-12)),5),'sha256':digest(path),'bytes':Path(path).stat().st_size}


def ffmpeg_version():
    return subprocess.check_output(['ffmpeg','-version'],text=True).splitlines()[0]


def run(*args):
    p=subprocess.run(['ffmpeg','-nostdin','-hide_banner','-loglevel','error','-y',*map(str,args)],capture_output=True,text=True)
    if p.returncode:raise RuntimeError(p.stderr[-5000:])


def validate_inputs(config,sources):
    if set(config['profiles'])!={'A','B','C'}:raise ValueError('Expected three explicit source sets')
    event_ids=[x['id'] for x in config['events']]
    if len(event_ids)!=len(set(event_ids)):raise ValueError('Duplicate event')
    for source_id,s in sources.items():
        if s.get('license')!='CC0-1.0' or not s.get('commercial_use') or s.get('attribution_required') is not False:
            raise ValueError('Unreviewed source license: '+source_id)
        for field in ['author','original_filename','source_url','download_url','download_date','license_url','sha256','archive_sha256','source_page_sha256']:
            if not s.get(field):raise ValueError('Missing source fact '+field)
        if digest(source_path(s['path']))!=s['sha256']:raise ValueError('Source fingerprint changed: '+source_id)
    seen=[]
    for e in config['events']:
        if len(e['candidates'])!=3:raise ValueError('Expected three candidates per event')
        for c in e['candidates']:
            if len(c['sources'])!=2 or c['sources'][0]==c['sources'][1]:raise ValueError('Variants must use two actual takes')
            if any(s not in sources for s in c['sources']):raise ValueError('Unknown source')
            seen+=c['sources']
    if len(seen)!=len(set(seen)):raise ValueError('Source takes cannot masquerade as distinct event alternatives')


def render(event,candidate,variant,source_id,sources,config,path):
    s=sources[source_id];source=source_path(s['path'])
    if digest(source)!=s['sha256']:raise ValueError('Source changed before render')
    import wave
    threshold=config['silence_threshold_dbfs'];rate=config['sample_rate']
    # Detect only leading/trailing sample silence. A sustained silenceremove gate
    # can erase isolated button transients or truncate quiet gaps inside a take.
    with tempfile.TemporaryDirectory(prefix='audio-v2-') as temp:
        decoded=Path(temp)/'decoded.wav';raw=Path(temp)/'trim.wav';shaped=Path(temp)/'edges.wav'
        run('-i',source,'-ar',rate,'-ac',1,'-c:a','pcm_s32le',decoded)
        with wave.open(str(decoded)) as f:
            samples=array.array('i',f.readframes(f.getnframes()))
        if sys.byteorder!='little':samples.byteswap()
        limit=2**31*10**(threshold/20)
        active=[i for i,value in enumerate(samples) if abs(value)>limit]
        if not active:raise ValueError('Silent source: '+source_id)
        padding=round(.002*rate)
        start=max(0,active[0]-padding);end=min(len(samples),active[-1]+1+padding)
        end=min(end,start+round(event['max_seconds']*rate))
        kept=samples[start:end]
        if sys.byteorder!='little':kept.byteswap()
        with wave.open(str(raw),'wb') as f:
            f.setparams((1,4,rate,0,'NONE','not compressed'));f.writeframes(kept.tobytes())
        trim={'method':'first/last sample above threshold with 2ms padding; cap only long source tail','threshold_dbfs':threshold,'input_frames':len(samples),'start_frame':start,'end_frame':end,'sample_rate':rate,'max_seconds':event['max_seconds']}
        measured=metrics(raw);duration=measured['duration']
        if duration<.008 or measured['rms_dbfs']<-70:raise ValueError('Empty/inaudible source: '+source_id)
        attack=min(config['fade_in_seconds'],duration/8)
        release=min(config['fade_out_seconds'],duration/5)
        edges=f'afade=t=in:d={attack:.9f},afade=t=out:st={duration-release:.9f}:d={release:.9f}'
        run('-i',raw,'-af',edges,'-c:a','pcm_s32le',shaped)
        shaped_metrics=metrics(shaped)
        gain=min(event['target_rms_dbfs']-shaped_metrics['rms_dbfs'],config['peak_ceiling_dbfs']-shaped_metrics['peak_dbfs'])
        run('-i',shaped,'-af',f'volume={gain:.9f}dB','-ar',rate,'-ac',1,'-c:a','pcm_s16le','-fflags','+bitexact','-flags:a','+bitexact',path)
    if digest(source)!=s['sha256']:raise ValueError('Source changed during render')
    return {'path':'res://'+path.relative_to(ROOT).as_posix(),'variant':variant+1,'source_id':source_id,'input_path':s['path'],'input_sha256':s['sha256'],'processing':'single recorded take; trim silence, cap long tail, endpoint fades and bounded gain; original pitch preserved','trim_filter':trim,'edge_filter':edges,'normalization_gain_db':gain,'original_pitch':True,'source_layers':1,**metrics(path)}


def validate_fingerprints(manifest):
    for key,value in fingerprints().items():
        if manifest.get(key)!=value:raise ValueError('Manifest '+key+' changed; full rebuild required')
    if manifest.get('sources')!=read(CONFIG/'sources.json')['sources']:raise ValueError('Source snapshot changed')


def build(event_filter=None):
    config=read(CONFIG/'recipes.json');sources=read(CONFIG/'sources.json')['sources'];validate_inputs(config,sources)
    before=fingerprints();engine=ffmpeg_version();manifest_path=DEST/'manifest.json'
    prior=read(manifest_path) if event_filter and manifest_path.exists() else None
    if event_filter and event_filter not in {e['id'] for e in config['events']}:raise ValueError('Unknown event')
    if prior:
        validate_fingerprints(prior)
        if prior.get('ffmpeg_version')!=engine:raise ValueError('FFmpeg changed; full rebuild required')
    if event_filter and not prior:raise ValueError('Full build required before partial rebuild')
    DEST.mkdir(parents=True,exist_ok=True);events=[]
    for event in config['events']:
        if event_filter and event['id']!=event_filter:
            events.append(next(e for e in prior['events'] if e['id']==event['id']));continue
        entry={k:v for k,v in event.items() if k!='candidates'};entry['candidates']=[]
        for candidate in event['candidates']:
            rendered=[]
            for i,sid in enumerate(candidate['sources']):
                path=DEST/(candidate['id']+('_v2' if i else '')+'.wav')
                rendered.append(render(event,candidate,i,sid,sources,config,path))
            first=rendered[0]
            entry['candidates'].append({'id':candidate['id'],'profile':candidate['profile'],'label':candidate['label'],'design':candidate['design'],'version':config['version'],'path':first['path'],'variants':[x['path'] for x in rendered],'raw_sources':[sources[s]['path'] for s in candidate['sources']],'source_ids':candidate['sources'],'subjective_status':'awaiting-user','renders':rendered,**{k:first[k] for k in ['duration','peak_dbfs','rms_dbfs','sha256']}})
        events.append(entry)
    if fingerprints()!=before:raise ValueError('Source changed while rendering')
    manifest={'schema_version':1,'version':config['version'],'task':config['task'],'profiles':config['profiles'],'sample_rate':config['sample_rate'],'peak_ceiling_dbfs':config['peak_ceiling_dbfs'],'subjective_status':'awaiting-user','previous_version_status':'audio-director-v1 A/B rejected by user','runtime_default':'original','preserve_original_events':config['preserve_original_events'],'loudness_method':'whole-cue RMS target bounded by sample peak; no LUFS claim','source_design':'single original recording per cue; actual second take; no pitch shift or layers','ffmpeg_version':engine,**before,'sources':sources,'events':events}
    write(manifest_path,manifest);validate()


def validate():
    manifest=read(DEST/'manifest.json');validate_fingerprints(manifest)
    config=read(CONFIG/'recipes.json');sources=read(CONFIG/'sources.json')['sources'];validate_inputs(config,sources)
    if manifest.get('ffmpeg_version')!=ffmpeg_version():raise ValueError('FFmpeg changed')
    for key in ['version','task','profiles','sample_rate','peak_ceiling_dbfs']:
        if manifest.get(key)!=config[key]:raise ValueError('Manifest metadata differs from recipe: '+key)
    if manifest.get('preserve_original_events')!=config['preserve_original_events']:
        raise ValueError('Preserved original event policy differs from recipe')
    if manifest.get('runtime_default')!='original' or manifest.get('subjective_status')!='awaiting-user':
        raise ValueError('Manifest cannot self-approve or change the default profile')
    if [e.get('id') for e in manifest['events']]!=[e['id'] for e in config['events']]:
        raise ValueError('Event catalog/order incomplete or changed')
    hashes=[]
    for e,recipe_event in zip(manifest['events'],config['events']):
        for key,value in recipe_event.items():
            if key!='candidates' and e.get(key)!=value:raise ValueError('Event differs from recipe: '+key)
        if [c.get('id') for c in e['candidates']]!=[c['id'] for c in recipe_event['candidates']]:
            raise ValueError('Candidate ID/order differs from recipe')
        for c,recipe_candidate in zip(e['candidates'],recipe_event['candidates']):
            for key in ['id','profile','label','design']:
                if c.get(key)!=recipe_candidate[key]:raise ValueError('Candidate differs from recipe: '+key)
            if c.get('version')!=config['version'] or c.get('subjective_status')!='awaiting-user':
                raise ValueError('Candidate version/acceptance differs from recipe')
            if c.get('source_ids')!=recipe_candidate['sources']:
                raise ValueError('Candidate source IDs differ from recipe')
            if c.get('raw_sources')!=[sources[s]['path'] for s in recipe_candidate['sources']]:
                raise ValueError('Candidate raw playback paths differ from source registry')
            if len(c['renders'])!=len(recipe_candidate['sources']):raise ValueError('Missing independent takes')
            expected_paths=['res://'+(DEST/(c['id']+('_v2' if i else '')+'.wav')).relative_to(ROOT).as_posix() for i in range(len(recipe_candidate['sources']))]
            if [r.get('path') for r in c['renders']]!=expected_paths:
                raise ValueError('Rendered paths differ from recipe output paths')
            if c.get('path')!=expected_paths[0] or c.get('variants')!=expected_paths:
                raise ValueError('Candidate playback path/variants differ from renders')
            first=c['renders'][0]
            for key in ['sha256','duration','peak_dbfs','rms_dbfs']:
                if c.get(key)!=first[key]:raise ValueError('Candidate summary differs from first render: '+key)
            for i,render_ in enumerate(c['renders']):
                p=source_path(render_['path'].removeprefix('res://'));actual=metrics(p)
                if actual!= {k:render_[k] for k in actual}:raise ValueError('Output fingerprint/metrics changed: '+str(p))
                if actual['format']!='PCM16 WAV' or actual['sample_rate']!=44100 or actual['channels']!=1:raise ValueError('Unsupported format')
                if actual['peak_dbfs']>manifest['peak_ceiling_dbfs']+.002 or actual['rms_dbfs']<-60:raise ValueError('Invalid level')
                if actual['duration']>e['max_seconds']+.001 or actual['duration']<.008:raise ValueError('Invalid duration')
                expected_source=recipe_candidate['sources'][i]
                if render_.get('source_id')!=expected_source:raise ValueError('Render source differs from recipe')
                source=sources[expected_source]
                if render_.get('variant')!=i+1 or render_.get('input_path')!=source['path'] or render_['input_sha256']!=source['sha256'] or render_.get('source_layers')!=1 or not render_.get('original_pitch'):
                    raise ValueError('False source/processing provenance')
                hashes.append(actual['sha256'])
    if len(hashes)!=54 or len(set(hashes))!=54:raise ValueError('Expected 54 distinct recorded outputs')
    print('AUDIO_CANDIDATES_V2_OK events=9 sets=3 rendered_files=54')


def main():
    p=argparse.ArgumentParser(description=__doc__);s=p.add_subparsers(dest='cmd',required=True);b=s.add_parser('build');b.add_argument('--event');s.add_parser('validate');a=p.parse_args()
    if a.cmd=='build':build(a.event)
    else:validate()
if __name__=='__main__':main()
