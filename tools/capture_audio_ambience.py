#!/usr/bin/env python3
"""Capture six real Godot region comparisons with the native MovieMaker soundtrack."""
from __future__ import annotations
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
VERSION = 'audio-ambience-capture-v1'
SEGMENT_FRAMES = 1560
CAPTURE_OVERRIDE = ('; Ephemeral AUDIO-AMBIENCE-01 MovieMaker renderer override.\n'
                    '[display]\n'
                    'window/size/window_width_override=960\n'
                    'window/size/window_height_override=540\n').encode('utf-8')
ERROR = re.compile(r'(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ObjectDB.*leaked|resources still in use')

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path): return json.loads(Path(path).read_text())
def write(path, data): Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')

def validate_capture_override(report, folder):
    row=report.get('capture_override',{})
    if row.get('path')!='override.cfg' or row.get('content')!=CAPTURE_OVERRIDE.decode() or row.get('sha256')!=hashlib.sha256(CAPTURE_OVERRIDE).hexdigest():
        raise ValueError('Capture did not bind the exact ephemeral renderer override')
    if row.get('created') is not True or row.get('removed') is not True or row.get('drifted') is not False:
        raise ValueError('Capture override lifecycle was not clean')
    if (folder/'capture-override.cfg').read_bytes()!=CAPTURE_OVERRIDE: raise ValueError('Retained renderer override bytes changed')
    if row.get('project_sha256_before')!=row.get('project_sha256_after') or row.get('project_sha256_before')!=report['source_before'].get('project.godot'):
        raise ValueError('Formal project settings changed during capture')

def frozen_sources():
    paths = subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard'], cwd=ROOT, text=True).splitlines()
    prefixes = ('scripts/','scenes/','resources/','assets/','config/','shaders/')
    selected = [p for p in paths if p.startswith(prefixes) or p in ['project.godot','export_presets.cfg','tools/godot.sh','tools/audio_ambience_capture.gd','tools/capture_audio_ambience.py']]
    return {p:sha(ROOT/p) for p in sorted(set(selected)) if (ROOT/p).is_file()}

def integer(value):
    if isinstance(value,bool) or not isinstance(value,(int,float)) or value < 0 or int(value) != value: raise ValueError('Invalid frame integer')
    return int(value)

def validate_trace(trace, count, manifest):
    if trace.get('version') != VERSION or trace.get('fps') != 60 or trace.get('failures') != []: raise ValueError('Failed or unexpected native trace')
    rendering=trace.get('rendering',{})
    if rendering.get('actual_window') != [960,540] or rendering.get('logical_content') != [1280,720] or rendering.get('scale_mode')!='canvas_items': raise ValueError('Unexpected actual/logical capture viewport')
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

def capture(output,smoke=False,scene_smoke=False):
    if output.exists(): raise ValueError('Use fresh output; retain original failures')
    output.mkdir(parents=True)
    report={'status':'failed','task':'AUDIO-AMBIENCE-01','version':VERSION,'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(), 'mix_revision':read(ROOT/'assets/audio/ambience_v1/manifest.json').get('mix_revision','initial-01')}
    started=time.monotonic(); display=None; override_owned=False; override=ROOT/'override.cfg'; lock=None; cleanup_error=None
    env=os.environ.copy(); env.update(LIBGL_ALWAYS_SOFTWARE='1',LP_NUM_THREADS='4')
    try:
        # The caller also owns the project's engine lease. This lock prevents
        # another invocation of this wrapper from creating an overlapping
        # temporary ProjectSettings override; pre-existing files are refused.
        lock=(ROOT/'build/.audio_ambience_capture.lock').open('a')
        fcntl.flock(lock.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB)
        fd=os.open(override,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
        override_owned=True
        with os.fdopen(fd,'wb') as stream:
            stream.write(CAPTURE_OVERRIDE);stream.flush();os.fsync(stream.fileno())
        (output/'capture-override.cfg').write_bytes(CAPTURE_OVERRIDE)
        report['capture_override']={'path':'override.cfg','content':CAPTURE_OVERRIDE.decode(),'sha256':hashlib.sha256(CAPTURE_OVERRIDE).hexdigest(),'created':True,'removed':False,'drifted':False,'project_sha256_before':sha(ROOT/'project.godot'),'scope':'Ephemeral MovieMaker physical renderer dimensions only; formal project.godot is byte-unchanged; caller owns project engine lease'}
        if not env.get('DISPLAY'):
            binary=shutil.which('Xvfb') or str(ROOT.parent/'toolchains/xvfb/usr/bin/Xvfb')
            display=subprocess.Popen([binary,'-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=(output/'display.log').open('w'),text=True)
            env['DISPLAY']=':'+display.stdout.readline().strip()
        engine=Path(env.get('GODOT_BIN',str(ROOT.parent/'toolchains/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64')))
        report['engine']={'version':subprocess.check_output(['bash','tools/godot.sh','--version'],cwd=ROOT,text=True).strip(),'sha256':sha(engine)}
        before=frozen_sources(); report['source_before']=before
        native=output/'native.avi'; movie=output/'ambience.mp4'
        command=['bash','tools/godot.sh','--path','.', '--audio-driver','Dummy','--rendering-method','gl_compatibility','--write-movie',str(native),'--fixed-fps','60','--resolution','960x540','--script','res://tools/audio_ambience_capture.gd','--','--output='+str(output)]
        if smoke: command.append('--smoke')
        if scene_smoke: command.append('--scene-smoke')
        report['command']=command;report['scope']='Actual renderer/MovieMaker viewport smoke only' if smoke else 'Actual formal two-region startup/visible-player smoke only' if scene_smoke else 'Six actual formal region comparisons; automatic router inputs; no natural full-route/device or aesthetic approval'
        with (output/'native.log').open('w') as log: result=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=900)
        report['exit_code']=result.returncode
        log=(output/'native.log').read_text()
        marker='AUDIO_AMBIENCE_SMOKE frames=120' if smoke else 'AUDIO_AMBIENCE_SCENE_SMOKE segments=2 failures=0' if scene_smoke else 'AUDIO_AMBIENCE_CAPTURE segments=6 failures=0'
        if result.returncode or ERROR.search(log) or marker not in log: raise ValueError('Native capture failed; inspect retained native.log')
        subprocess.run(['ffmpeg','-y','-i',str(native),'-c:v','libx264','-preset','fast','-crf','23','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',str(movie)],stdout=subprocess.DEVNULL,stderr=(output/'encode.log').open('w'),timeout=180,check=True)
        media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(movie)]))
        video=next(s for s in media['streams'] if s['codec_type']=='video'); sound=next(s for s in media['streams'] if s['codec_type']=='audio')
        if video['avg_frame_rate']!='60/1' or int(video['width'])!=960 or int(video['height'])!=540 or int(sound['sample_rate'])!=48000 or sound['channels']!=2: raise ValueError('Unexpected encoded media format')
        if smoke or scene_smoke:
            after=frozen_sources();report.update(source_after=after,source_stable=before==after,media=media,frame_count=int(video['nb_frames']),movie_sha256=sha(movie),movie_bytes=movie.stat().st_size,native_sha256=sha(native),smoke=read(output/('scene-smoke.json' if scene_smoke else 'smoke.json')))
            if scene_smoke:
                report['smoke']=read(output/'scene-smoke.json')
                scene=report['smoke']
                if scene.get('failures')!=[] or [s['region'] for s in scene['segments']]!=['plains','forest']: raise ValueError('Formal scene smoke startup failed')
                for segment in scene['segments']:
                    if segment['interactive_panel_present'] is not False or len(segment['samples'])!=120: raise ValueError('Capture unexpectedly includes interactive panel or lacks real samples')
                    if any(r[1]+r[3]>155 for r in segment['caption_rects']): raise ValueError('Observer captions cover action area')
            if before!=after: raise ValueError('Frozen smoke source changed')
            report['status']='passed'
            return
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
        if display:
            display.terminate()
            try:display.wait(timeout=5)
            except subprocess.TimeoutExpired:display.kill();display.wait()
        if override_owned:
            row=report.get('capture_override',{})
            row['project_sha256_after']=sha(ROOT/'project.godot')
            if override.is_symlink() or not override.exists() or not stat.S_ISREG(override.lstat().st_mode) or override.read_bytes()!=CAPTURE_OVERRIDE:
                row['drifted']=True;cleanup_error='Temporary override drifted; preserved foreign/missing file state'
            else:
                override.unlink();row['removed']=True
            report['capture_override']=row
        if lock:
            fcntl.flock(lock.fileno(),fcntl.LOCK_UN);lock.close()
        if cleanup_error:
            report['status']='failed';report['cleanup_error']=cleanup_error
        report['seconds']=time.monotonic()-started;write(output/'report.json',report)
        if cleanup_error: raise ValueError(cleanup_error)
    print(json.dumps({'status':'passed','movie':str(movie),'frames':report['frame_count'],'bytes':report['movie_bytes']}))

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);modes=parser.add_mutually_exclusive_group();modes.add_argument('--smoke',action='store_true');modes.add_argument('--scene-smoke',action='store_true')
    args=parser.parse_args();capture(args.output.resolve(),args.smoke,args.scene_smoke)
if __name__=='__main__':main()
