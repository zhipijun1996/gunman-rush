#!/usr/bin/env python3
"""Capture six real Godot region comparisons with the native MovieMaker soundtrack."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
VERSION = 'audio-ambience-capture-v1'
SEGMENT_FRAMES = 1560
ERROR = re.compile(r'(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ObjectDB.*leaked|resources still in use')

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path): return json.loads(Path(path).read_text())
def write(path, data): Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')

def frozen_sources():
    paths = subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard'], cwd=ROOT, text=True).splitlines()
    prefixes = ('scripts/','scenes/','resources/','assets/','config/')
    selected = [p for p in paths if p.startswith(prefixes) or p in ['project.godot','tools/godot.sh','tools/audio_ambience_capture.gd','tools/capture_audio_ambience.py']]
    return {p:sha(ROOT/p) for p in sorted(set(selected)) if (ROOT/p).is_file()}

def integer(value):
    if isinstance(value,bool) or not isinstance(value,(int,float)) or value < 0 or int(value) != value: raise ValueError('Invalid frame integer')
    return int(value)

def validate_trace(trace, count, manifest):
    if trace.get('version') != VERSION or trace.get('fps') != 60 or trace.get('failures') != []: raise ValueError('Failed or unexpected native trace')
    count = integer(count)
    if abs(integer(trace['movie_clock']['frames_drawn_before_quit'])-count) > 2: raise ValueError('MovieWriter clock differs from media')
    expected = [(region,profile) for region in ['plains','forest'] for profile in ['original','A','B']]
    segments = trace['segments']
    if [(s['region'],s['profile']) for s in segments] != expected: raise ValueError('Missing/reordered comparisons')
    prior = -1
    signatures = {}
    for segment in segments:
        region, profile = segment['region'], segment['profile']
        start, end = integer(segment['start_frame']), integer(segment['end_frame'])
        if not prior < start < end <= count or end-start != SEGMENT_FRAMES or segment['frames'] != SEGMENT_FRAMES: raise ValueError('Invalid actual 26-second chapter')
        prior = end
        rows = [r for r in trace['trace'] if r['region']==region and r['profile']==profile]
        if len(rows)!=SEGMENT_FRAMES or [integer(r['index']) for r in rows] != list(range(SEGMENT_FRAMES)): raise ValueError('Missing/repeated actual physics samples')
        for a,b in zip(rows,rows[1:]):
            if integer(b['physics_tick'])-integer(a['physics_tick']) != 1 or integer(b['movie_frame'])-integer(a['movie_frame']) != 1: raise ValueError('Discontinuous physics/MovieWriter frames')
        if any(not start <= integer(r['movie_frame']) <= end for r in rows): raise ValueError('Sample lies outside chapter')
        if any(not (0 <= r['screen'][0] <= 1280 and 180 <= r['screen'][1] <= 680) for r in rows): raise ValueError('Player invisible or hidden under lab toolbar')
        ids = [e['id'] for e in segment['events']]
        if ids.count('jump') < 2 or ids.count('land') < 2 or ids.count('shot') != 1: raise ValueError('Accepted jump/land/shot feedback missing')
        if any(not start <= integer(e['movie_frame']) < end for e in segment['events']): raise ValueError('Accepted event outside movie chapter')
        if not segment.get('manifest_hash'): raise ValueError('Formal generated manifest missing')
        signature = (segment['manifest_hash'], [[r['position'],r['hp'],r['grounded']] for r in rows], [[e['id'],e['movie_frame']-start] for e in segment['events']])
        if region in signatures and signature != signatures[region]: raise ValueError('Audio changed actual seeded physics/HP/event timing: '+region)
        signatures[region] = signature
        if any(r['music_track'] != region for r in rows[60:900]) or any(r['music_track'] for r in rows[960:]): raise ValueError('Actual original BGM context incorrect')
        bed = manifest['regions'][region]['profiles'].get(profile)
        playback_positions=[]
        for row in rows[60:]:
            snapshot = row['ambience']
            if profile == 'original':
                if any(v.get('playing') for v in snapshot.get('beds',[])): raise ValueError('Original chapter played new bed')
            elif not any(v.get('playing') and v.get('path') == bed['bed'] for v in snapshot.get('beds',[])):
                raise ValueError('Actual new bed playback missing: '+region+'/'+profile)
            elif profile != 'original':
                playback_positions.append(next(v['playback_position'] for v in snapshot['beds'] if v.get('playing') and v.get('path')==bed['bed']))
        if profile != 'original' and not any(after < before-1 for before,after in zip(playback_positions,playback_positions[1:])):
            raise ValueError('No actual native 24-second loop wrap observed: '+region+'/'+profile)
    return segments

def chapters_from_segments(segments):
    chapters=[]
    for s in segments:
        for context,first,last in [('mix',s['start_frame'],s['bgm_mix_end_frame']),('environment',s['environment_only_start_frame'],s['end_frame'])]:
            chapters.append({'id':s['region']+'_'+s['profile']+'_'+context,'region':s['region'],'profile':s['profile'],'context':context,'start':first/60,'end':last/60})
    return {'chapters':chapters}

def decode(path):
    import numpy as np
    return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-vn','-f','f32le','-ac','1','-ar','8000','pipe:1'], timeout=60), dtype='<f4').astype('float64')

def validate_native_audio(native, segments, manifest):
    """Bounded direct-dot correlation on final BGM-off window, with local energy."""
    import numpy as np
    from scipy.signal import fftconvolve
    audio = decode(native)
    results=[]
    for segment in segments:
        start = segment['end_frame']/60-2.5
        clip = audio[round(start*8000):round((start+2)*8000)]
        if clip.size != 16000 or not np.isfinite(clip).all(): raise ValueError('Missing/nonfinite captured audio samples')
        rms = float(np.sqrt(np.mean(clip*clip)))
        if segment['profile']=='original':
            results.append({'region':segment['region'],'profile':'original','window_start':start,'rms':rms,'scope':'Existing scene sound remains; no silence claim'})
            continue
        path = manifest['regions'][segment['region']]['profiles'][segment['profile']]['bed']
        source = decode(ROOT/path.removeprefix('res://'))
        source = np.tile(source, 2)
        n = len(clip)
        dots = fftconvolve(source,clip[::-1],mode='valid')
        power = fftconvolve(source*source,np.ones(n),mode='valid')
        norms = np.sqrt(np.maximum(power,0)*float(np.dot(clip,clip)))
        correlations = np.divide(dots,norms,out=np.zeros_like(dots),where=norms>1e-15)
        peak = int(np.argmax(correlations))
        aligned = source[peak:peak+n]
        denom=float(np.linalg.norm(aligned)*np.linalg.norm(clip))
        direct=float(np.dot(aligned,clip)/denom) if denom else 0
        if not .45 <= direct <= 1.000001 or rms < 1e-5: raise ValueError('Native soundtrack does not prove audible candidate: '+path+' correlation='+str(direct))
        results.append({'region':segment['region'],'profile':segment['profile'],'path':path,'window_start':start,'seconds':2,'rms':rms,'direct_normalized_dot':direct,'aligned_source_seconds':peak/8000,'scope':'Native BGM-off movie samples match actual decoded candidate; not aesthetic approval'})
    return results

def capture(output):
    if output.exists(): raise ValueError('Use fresh output; retain original failures')
    output.mkdir(parents=True)
    report={'status':'failed','task':'AUDIO-AMBIENCE-01','version':VERSION,'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()}
    started=time.monotonic(); display=None; env=os.environ.copy(); env.update(LIBGL_ALWAYS_SOFTWARE='1',LP_NUM_THREADS='2')
    try:
        if not env.get('DISPLAY'):
            binary=shutil.which('Xvfb') or str(ROOT.parent/'toolchains/xvfb/usr/bin/Xvfb')
            display=subprocess.Popen([binary,'-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=(output/'display.log').open('w'),text=True)
            env['DISPLAY']=':'+display.stdout.readline().strip()
        engine=Path(env.get('GODOT_BIN',str(ROOT.parent/'toolchains/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64')))
        report['engine']={'version':subprocess.check_output(['bash','tools/godot.sh','--version'],cwd=ROOT,text=True).strip(),'sha256':sha(engine)}
        before=frozen_sources(); report['source_before']=before
        native=output/'native.avi'; movie=output/'ambience.mp4'
        command=['bash','tools/godot.sh','--path','.', '--audio-driver','Dummy','--rendering-method','gl_compatibility','--write-movie',str(native),'--fixed-fps','60','--resolution','1280x720','--script','res://tools/audio_ambience_capture.gd','--','--output='+str(output)]
        report['command']=command
        with (output/'native.log').open('w') as log: result=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=900)
        report['exit_code']=result.returncode
        log=(output/'native.log').read_text()
        if result.returncode or ERROR.search(log) or 'AUDIO_AMBIENCE_CAPTURE segments=6 failures=0' not in log: raise ValueError('Native capture failed; inspect retained native.log')
        subprocess.run(['ffmpeg','-y','-i',str(native),'-c:v','libx264','-preset','fast','-crf','23','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',str(movie)],stdout=subprocess.DEVNULL,stderr=(output/'encode.log').open('w'),timeout=180,check=True)
        media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(movie)]))
        video=next(s for s in media['streams'] if s['codec_type']=='video'); sound=next(s for s in media['streams'] if s['codec_type']=='audio')
        if video['avg_frame_rate']!='60/1' or int(sound['sample_rate'])!=48000 or sound['channels']!=2: raise ValueError('Unexpected encoded media format')
        manifest=read(ROOT/'assets/audio/ambience_v1/manifest.json'); trace=read(output/'trace.json')
        segments=validate_trace(trace,integer(int(video['nb_frames'])),manifest)
        report['native_audio_validation']=validate_native_audio(native,segments,manifest)
        after=frozen_sources();report.update(source_after=after,source_stable=before==after,media=media,frame_count=int(video['nb_frames']),movie_sha256=sha(movie),movie_bytes=movie.stat().st_size,native_sha256=sha(native),trace_sha256=sha(output/'trace.json'))
        if before!=after: raise ValueError('Frozen sources changed during capture')
        write(output/'chapters.json',chapters_from_segments(segments))
        report['chapters_sha256']=sha(output/'chapters.json')
        report['status']='passed'
    except Exception as error:
        report['error']=str(error)
        raise
    finally:
        report['seconds']=time.monotonic()-started;write(output/'report.json',report)
        if display:
            display.terminate()
            try:display.wait(timeout=5)
            except subprocess.TimeoutExpired:display.kill();display.wait()
    print(json.dumps({'status':'passed','movie':str(movie),'frames':report['frame_count'],'bytes':report['movie_bytes']}))

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True)
    capture(parser.parse_args().output.resolve())
if __name__=='__main__':main()
