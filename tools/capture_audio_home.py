#!/usr/bin/env python3
"""Record the real Home in three modes and verify its native differential soundtrack."""
from __future__ import annotations
import argparse
from godot_identity import verified_engine
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import stat
import subprocess
import time
from capture_audio_ambience import ROOT, CAPTURE_OVERRIDE, ERROR, sha, read, write, integer, validate_capture_override, frozen_sources as regional_sources

VERSION='audio-home-capture-v1'
FRAMES=1560
MANIFEST=ROOT/'assets/audio/ambience_v1/home/manifest.json'

def finite_number(value):
    return type(value) in [int,float] and math.isfinite(value)

def frozen_sources():
    result=regional_sources()
    for name in ['tools/audio_home_capture.gd','tools/capture_audio_home.py']:
        result[name]=sha(ROOT/name)
    return result

def chapters_from_segments(segments):
    return {'chapters':[{'id':s['mode'],'mode':s['mode'],'start':s['start_frame']/60,'end':s['end_frame']/60} for s in segments]}

def validate_trace(trace,count,manifest,*,movie=True):
    if trace.get('version')!=VERSION or trace.get('fps')!=60 or trace.get('failures')!=[]: raise ValueError('Failed/unexpected Home trace')
    if [(s['mode'],s['frames']) for s in trace['segments']]!=[(m,FRAMES) for m in ['original','bed','life']]: raise ValueError('Missing/reordered Home comparison')
    if movie and abs(integer(trace['movie_clock']['frames_drawn_before_quit'])-integer(count))>2: raise ValueError('Actual Home MovieWriter clock drift')
    # Headless action diagnostics retain the engine's actual 1280x720 root;
    # the MovieMaker target is separately required to render real 960x540.
    # Both run the unchanged 1280x720 logical camera/input composition.
    expected_window=[960,540] if movie else [1280,720]
    expected_kind='movie' if movie else 'actions'
    if trace.get('kind')!=expected_kind or trace['rendering']!={'actual_window':expected_window,'logical_content':[1280,720]}:
        raise ValueError('Unexpected actual/logical Home viewport for '+expected_kind)
    bed_path=manifest['regions']['home']['profiles']['A']['bed']
    points={p['id']:p for p in manifest['point_events']}
    signature=None;last=-1
    for segment in trace['segments']:
        mode=segment['mode'];start=integer(segment['start_frame']);end=integer(segment['end_frame'])
        if movie and (not last<start<end<=count or end-start!=FRAMES): raise ValueError('Invalid actual Home chapter bounds')
        last=end
        if any(r[1]+r[3]>155 for r in segment['caption_rects']): raise ValueError('Home captions obstruct action area')
        rows=[r for r in trace['samples'] if r['mode']==mode]
        if [r['index'] for r in rows]!=list(range(FRAMES)): raise ValueError('Missing/repeated Home physical frame')
        for before,after in zip(rows,rows[1:]):
            if integer(after['physics_tick'])-integer(before['physics_tick'])!=1: raise ValueError('Home physics discontinuity')
            if movie and integer(after['movie_frame'])-integer(before['movie_frame'])!=1: raise ValueError('Home movie frame discontinuity')
        current=[[r['position'],r['grounded'],r['hp'],r['screen'],r['nearest_slot']] for r in rows]
        if signature is not None and current!=signature: raise ValueError('Home sound mode changed actual movement/camera/resources')
        signature=current
        if not 105<=rows[0]['position'][0]<=120 or not any(abs(r['position'][0]-300)<12 for r in rows) or max(r['position'][0] for r in rows)<1200: raise ValueError('Actual default spawn/character/raised workshop ground route missing')
        expected_bed_db=20*math.log10(.7)+float(manifest['regions']['home']['profiles']['A']['gain_db'])
        expected_music_db=20*math.log10(.7*.16)
        for row in rows:
            snapshot=row['snapshot'];audio=snapshot['audition']['audio']
            if snapshot['meta_persistence_enabled'] is not False or snapshot['home_input_blocked'] is not False: raise ValueError('Home audition changed save/input contract')
            if snapshot['music_track']!='home' or snapshot['music_gain']!=.16: raise ValueError('Original Home music track/gain changed')
            music=[v for v in snapshot['music_voices'] if v['playing'] and v['path'].endswith('/the_kindred_hearth.mp3')]
            if len(music)!=1 or music[0]['paused']: raise ValueError('Original Home BGM is not actually playing')
            if not finite_number(snapshot['session_volume']) or abs(snapshot['session_volume']-.7)>1e-8: raise ValueError('Home audition session volume changed')
            if not finite_number(music[0]['volume_db']) or abs(music[0]['volume_db']-expected_music_db)>1e-4: raise ValueError('Actual original Home BGM gain changed after preroll')
            if any(not(0<=row['screen'][0]<=1280 and 180<=row['screen'][1]<=680) for _ in [0]): raise ValueError('Actual Home player is not visible')
            playing=[v for v in audio.get('beds',[]) if v['playing']]
            if mode=='original' and playing: raise ValueError('Original Home played new ambience')
            if mode!='original' and not any(v['path']==bed_path and not v['paused'] for v in playing): raise ValueError('Selected quiet Home bed not actually playing')
            if mode!='original':
                selected=[v for v in playing if v['path']==bed_path]
                if len(selected)!=1 or not finite_number(selected[0]['gain']) or abs(selected[0]['gain']-1.0)>1e-6: raise ValueError('Home bed crossfade did not settle in fixed preroll')
                if not finite_number(selected[0]['volume_db']) or abs(selected[0]['volume_db']-expected_bed_db)>1e-4: raise ValueError('Actual quiet Home bed gain differs from selected file plus authored -2dB')
            if any(not finite_number(v['volume_db']) for v in audio.get('details',[])): raise ValueError('Nonfinite Home detail playback gain')
            if sum(bool(v['playing']) for v in audio.get('details',[]))>1: raise ValueError('Home life cues overlap despite sparse contract')
        events=segment['final']['audition']['events']
        if mode!='life' and events: raise ValueError('Original/bed-only Home played life cues')
        if mode=='life':
            if not events: raise ValueError('No normal near-place Home cue observed')
            anchors={a['slot_id']:a for a in segment['initial']['audition']['source_anchors']}
            if set(anchors)!={'character','upgrade','arms','achievements'}: raise ValueError('Actual four keeper anchors missing')
            previous=-100.0
            for event in events:
                point=points.get(event['event_id']);anchor=anchors.get(event['slot'])
                if not point or not anchor or event['path']!=point['path'] or event['event_id'] not in anchor['event_ids'] or event['world_position']!=anchor['source_position']: raise ValueError('Life cue source/path is not the real keeper anchor')
                if event['clock']-previous<6-1e-8: raise ValueError('Home life global spacing changed')
                previous=event['clock']
                distance=math.dist(event['world_position'],event['listener_position'])
                if abs(distance-event['distance'])>1e-6 or event['voice_index'] not in [0,1]: raise ValueError('Home spatial playback receipt is inconsistent')
    return trace['segments']

def decode_native(path,rate=48000):
    import numpy as np
    return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-vn','-f','f32le','-ac','1','-ar',str(rate),'pipe:1'],timeout=90),dtype='<f4').astype('float64')

def differential(reference,test):
    """Align the unchanged BGM at native PCM rate, then subtract; no new dub."""
    import numpy as np
    from scipy.signal import correlate,correlation_lags,resample_poly
    n=min(len(reference),len(test),6*48000);r=reference[:n];t=test[:n]
    correlation=correlate(t,r,mode='full',method='fft');lags=correlation_lags(len(t),len(r))
    allowed=(lags>=-2048)&(lags<=2048);selected=np.flatnonzero(allowed)[int(np.argmax(correlation[allowed]))];lag=int(lags[selected])
    indexes=np.arange(len(test))-lag;valid=(indexes>=0)&(indexes<len(reference));aligned=np.zeros_like(test);aligned[valid]=reference[indexes[valid]]
    check=(np.arange(len(test))>=48000)&(np.arange(len(test))<min(5*48000,len(test)))&valid
    denom=float(np.linalg.norm(test[check])*np.linalg.norm(aligned[check]));score=float(np.dot(test[check],aligned[check])/denom) if denom else 0
    if not .80<=score<=1.000001: raise ValueError('Unchanged native BGM did not align across Home modes')
    residual=test-aligned;residual[~valid]=0
    return resample_poly(residual,1,6),{'native_lag_samples':lag,'native_rate':48000,'common_track_normalized_dot':score,'difference_rate':8000,'method':'integer PCM alignment on unchanged original Home BGM, direct subtraction; no soundtrack replacement'}

def match_template(signal,template):
    import numpy as np
    from scipy.signal import fftconvolve
    if len(template)>len(signal) or len(template)<800: raise ValueError('Invalid actual waveform proof window')
    dots=fftconvolve(signal,template[::-1],mode='valid');power=fftconvolve(signal*signal,np.ones(len(template)),mode='valid')
    norm=np.sqrt(np.maximum(power,0)*float(np.dot(template,template)));scores=np.divide(dots,norm,out=np.zeros_like(dots),where=norm>1e-18)
    index=int(np.argmax(scores));actual=signal[index:index+len(template)];denom=float(np.linalg.norm(actual)*np.linalg.norm(template));direct=float(np.dot(actual,template)/denom) if denom else 0
    if not .45<=direct<=1.000001: raise ValueError('Native differential soundtrack does not prove the actual cue, correlation='+str(direct))
    return {'direct_normalized_dot':direct,'offset_samples':index,'samples':len(template),'sample_rate':8000}

def validate_native_audio(native,trace,manifest):
    import numpy as np
    raw=decode_native(native);segments={s['mode']:s for s in trace['segments']}
    clips={mode:raw[round(s['start_frame']/60*48000):round(s['end_frame']/60*48000)] for mode,s in segments.items()}
    bed_delta,bed_alignment=differential(clips['original'],clips['bed'])
    life_delta,life_alignment=differential(clips['bed'],clips['life'])
    bed=manifest['regions']['home']['profiles']['A']['bed'];source=decode_native(ROOT/bed.removeprefix('res://'),8000)
    window=bed_delta[3*8000:5*8000]
    # Search the known 24-second loop for this actual two-second difference.
    bed_proof=match_template(np.tile(source,2),window)
    points={p['id']:p for p in manifest['point_events']};life_proofs=[];segment=segments['life']
    for event in segment['final']['audition']['events']:
        point=points[event['event_id']];template=decode_native(ROOT/point['path'].removeprefix('res://'),8000)[:8000]
        offset=(event['physics_tick']-segment['first_physics_tick'])/60
        start=max(0,round((offset-.15)*8000));end=min(len(life_delta),round((offset+.20)*8000)+len(template))
        proof=match_template(life_delta[start:end],template)
        life_proofs.append({'event_id':event['event_id'],'path':event['path'],'slot':event['slot'],'event_clock':event['clock'],'expected_segment_seconds':offset,'search_start_seconds':start/8000,**proof})
    if not life_proofs: raise ValueError('No actual native Home life cue proof')
    return {'bed_minus_original':{'alignment':bed_alignment,'path':bed,**bed_proof},'life_minus_bed':{'alignment':life_alignment,'events':life_proofs},'scope':'Differences of original native PCM recordings isolate added sounds beneath unchanged Home BGM. Automatic waveform identity/technical proof only; user listening/device approval pending.'}

def capture(output,smoke=False):
    if output.exists(): raise ValueError('Use fresh Home output; retain earlier failures')
    output.mkdir(parents=True)
    report={'status':'failed','task':'AUDIO-HOME-01','version':VERSION,'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'scope':'Actual DemoApp/HomeScene original/bed/life comparison; original Home BGM throughout; automatic ground inputs; no natural NPC interaction or animation synchronization claim'}
    started=time.monotonic();display=None;lock=None;owned=False;cleanup_error=None;override=ROOT/'override.cfg';env=os.environ.copy();env.update(LIBGL_ALWAYS_SOFTWARE='1',LP_NUM_THREADS='4')
    try:
        lock=(ROOT/'build/.audio_ambience_capture.lock').open('a');fcntl.flock(lock.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB)
        fd=os.open(override,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600);owned=True
        with os.fdopen(fd,'wb') as stream:stream.write(CAPTURE_OVERRIDE);stream.flush();os.fsync(stream.fileno())
        (output/'capture-override.cfg').write_bytes(CAPTURE_OVERRIDE)
        report['capture_override']={'path':'override.cfg','content':CAPTURE_OVERRIDE.decode(),'sha256':hashlib.sha256(CAPTURE_OVERRIDE).hexdigest(),'created':True,'removed':False,'drifted':False,'project_sha256_before':sha(ROOT/'project.godot'),'scope':'Reused physical MovieMaker 960x540 override only; caller owns engine lease; formal project unchanged'}
        if not env.get('DISPLAY'):
            binary=shutil.which('Xvfb') or str(ROOT.parent/'toolchains/xvfb/usr/bin/Xvfb')
            display=subprocess.Popen([binary,'-displayfd','1','-screen','0','960x540x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=(output/'display.log').open('w'),text=True);env['DISPLAY']=':'+display.stdout.readline().strip()
        engine_identity = verified_engine(repo=ROOT)
        report['engine'] = {'version': engine_identity['version'], 'sha256': engine_identity['binary_sha256']}
        before=frozen_sources();report['source_before']=before
        native=output/'native.avi';movie=output/'home.mp4'
        command=['bash','tools/godot.sh','--path','.', '--audio-driver','Dummy','--rendering-method','gl_compatibility','--write-movie',str(native),'--fixed-fps','60','--resolution','960x540','--script','res://tools/audio_home_capture.gd','--','--output='+str(output)]
        if smoke:command.append('--scene-smoke');report['scope']='Actual Home startup/visible player smoke only; no 26-second or full soundtrack claim'
        report['command']=command
        with (output/'native.log').open('w') as log:result=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=900)
        report['exit_code']=result.returncode;text=(output/'native.log').read_text();marker='AUDIO_HOME_SCENE_SMOKE segments=1 failures=0' if smoke else 'AUDIO_HOME_CAPTURE segments=3 failures=0'
        if result.returncode or ERROR.search(text) or marker not in text:raise ValueError('Home native capture failed; retained original native.log')
        subprocess.run(['ffmpeg','-y','-i',str(native),'-c:v','libx264','-preset','fast','-crf','23','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',str(movie)],stdout=subprocess.DEVNULL,stderr=(output/'encode.log').open('w'),check=True,timeout=180)
        media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(movie)]));video=next(s for s in media['streams'] if s['codec_type']=='video');sound=next(s for s in media['streams'] if s['codec_type']=='audio')
        if (int(video['width']),int(video['height']),video['avg_frame_rate'],int(sound['sample_rate']),sound['channels'])!=(960,540,'60/1',48000,2):raise ValueError('Unexpected actual Home encoding')
        trace=read(output/'trace.json');manifest=read(MANIFEST);count=int(video['nb_frames'])
        if smoke:
            if trace['kind']!='scene-smoke' or len(trace['samples'])!=120 or any(r[1]+r[3]>155 for r in trace['segments'][0]['caption_rects']):raise ValueError('Home scene smoke/captions invalid')
        else:
            segments=validate_trace(trace,count,manifest);report['native_audio_validation']=validate_native_audio(native,trace,manifest)
            write(output/'chapters.json',chapters_from_segments(segments));report['chapters_sha256']=sha(output/'chapters.json')
        after=frozen_sources();report.update(source_after=after,source_stable=before==after,media=media,frame_count=count,movie_sha256=sha(movie),movie_bytes=movie.stat().st_size,native_sha256=sha(native),trace_sha256=sha(output/'trace.json'),manifest_sha256=sha(MANIFEST),content_version=manifest['content_version'],mix_revision=manifest['mix_revision'])
        if before!=after:raise ValueError('Home source changed during capture')
        report['status']='passed'
    except Exception as error:report['error']=str(error);raise
    finally:
        if display:
            display.terminate()
            try:display.wait(timeout=5)
            except subprocess.TimeoutExpired:display.kill();display.wait()
        if owned:
            row=report.get('capture_override',{});row['project_sha256_after']=sha(ROOT/'project.godot')
            if override.is_symlink() or not override.exists() or not stat.S_ISREG(override.lstat().st_mode) or override.read_bytes()!=CAPTURE_OVERRIDE:
                row['drifted']=True;cleanup_error='Home capture override drifted; foreign/missing state preserved'
            else:override.unlink();row['removed']=True
            report['capture_override']=row
        if lock:fcntl.flock(lock.fileno(),fcntl.LOCK_UN);lock.close()
        if cleanup_error:report['status']='failed';report['cleanup_error']=cleanup_error
        report['seconds']=time.monotonic()-started;write(output/'report.json',report)
        if cleanup_error:raise ValueError(cleanup_error)
    print(json.dumps({'status':report['status'],'movie':str(movie),'bytes':report['movie_bytes'],'frames':report['frame_count']}))

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--scene-smoke',action='store_true');a=p.parse_args();capture(a.output.resolve(),a.scene_smoke)
if __name__=='__main__':main()
