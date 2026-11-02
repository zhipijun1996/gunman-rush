#!/usr/bin/env python3
"""Capture real Godot movie audio, encode unchanged soundtrack, preserve per-clip source evidence."""
import argparse
from godot_identity import verified_engine
from collections import Counter
import hashlib
import json
import math
import os
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
REELS = ('coin','heal','chest_open','item_get','ui','enemy_hit','enemy_hurt','hurt','weapons','mix')
ERROR = re.compile(r'(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ObjectDB.*leaked')

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def sources():
    paths = [Path(v) for v in subprocess.check_output(['git','ls-files'],cwd=ROOT,text=True).splitlines()]
    paths += [Path(v) for v in subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=ROOT,text=True).splitlines()]
    return {str(p):sha(ROOT/p) for p in sorted(set(paths)) if str(p).startswith(('scripts/','game/','experiments/','scenes/','resources/','assets/','config/','tools/audio_reels_capture','tools/capture_audio_reels','tests/audio_director_reels')) and (ROOT/p).is_file()} | {p:sha(ROOT/p) for p in ('project.godot','tools/godot.sh','tools/audio_reels_validation.py')}

EXPECTED_EVENTS = {id:[id] for id in REELS}
EXPECTED_EVENTS.update(ui=['click','confirm','denied'], weapons=['shot_pulse','shot_shuriken','shot_bomb','bomb_explode'], mix=['coin','heal','enemy_hit','hurt'])
DIRECTOR_EVENTS = dict(EXPECTED_EVENTS)
DIRECTOR_EVENTS.update(enemy_hit=['shot_pulse','enemy_hit'], enemy_hurt=['shot_pulse','enemy_hurt'], mix=['coin','heal','shot_pulse','enemy_hit','hurt'])
LEGACY_AUDIO = {'coin':['coin'],'heal':['heal'],'chest_open':['confirm'],'item_get':['note'],'ui':['click','confirm','denied'],'enemy_hit':['weapon_pulse','weapon_hit'],'enemy_hurt':['weapon_pulse','hurt'],'hurt':['hurt'],'weapons':['weapon_pulse','weapon_blade','weapon_blast'],'mix':['coin','heal','weapon_pulse','weapon_hit','hurt']}

def frame_integer(value):
    if isinstance(value,bool) or not isinstance(value,(int,float)) or not math.isfinite(value) or int(value)!=value or value<0:
        raise ValueError('Frame index must be a finite nonnegative integer, including integer-valued JSON floats')
    return int(value)

def validate_trace(trace, reel, frame_count, manifest=None):
    """Validate the actual MovieMaker receipt; raises ValueError on missing or extra work."""
    if manifest is None: manifest=json.loads((ROOT/'assets/audio/director_v3/manifest.json').read_text())
    if reel not in REELS or trace.get('version')!='audio-director-v3-reels-1' or trace.get('reel')!=reel or trace.get('fps')!=60: raise ValueError('Wrong reel/version/FPS receipt')
    frame_count=frame_integer(frame_count)
    clock=trace.get('movie_clock',{})
    if clock.get('index_base')!=0 or abs(frame_integer(clock.get('frames_drawn_before_quit'))-frame_count)>2: raise ValueError('Missing actual movie clock or movie frame count drift')
    segments=trace.get('segments',[])
    if [s.get('profile') for s in segments]!=['original','A','B','C']: raise ValueError('Missing or reordered profile segments')
    candidates={c['id']:c for e in manifest['events'] for c in e['candidates']}
    previous_end=-1
    for segment in segments:
        profile=segment['profile']; start=frame_integer(segment.get('start_frame')); end=frame_integer(segment.get('end_frame'))
        if not 0<=start<end<=frame_count or not 60<=end-start<=900 or start<=previous_end: raise ValueError('Invalid/overlapping/empty profile movie interval')
        previous_end=end
        events=segment.get('events',[])
        if [e.get('event_id') for e in events]!=EXPECTED_EVENTS[reel]: raise ValueError(f'{reel}/{profile}: missing, repeated or extra accepted target event')
        for event in events:
            if not start<=frame_integer(event.get('movie_frame'))<end: raise ValueError('Event outside actual movie segment')
            expected='original' if profile=='original' else event['event_id']+'_'+profile.lower()
            if event.get('profile')!=profile or event.get('candidate_id')!=expected: raise ValueError('Wrong accepted candidate/profile provenance')
            detail=event.get('details',{})
            if event['event_id'] in ['coin','heal','item_get'] and not detail.get('contact'): raise ValueError('Pickup lacks actual contact')
            if event['event_id']=='coin' and detail.get('wallet')!=1: raise ValueError('Coin contact lacks wallet receipt')
            if event['event_id']=='heal' and detail.get('health')!=5: raise ValueError('Healing contact lacks HP receipt')
            if event['event_id']=='chest_open' and detail.get('opened') is not True: raise ValueError('Chest opening was not accepted')
            weapons={'shot_pulse':'pulse_gun','shot_shuriken':'shadow_shuriken','shot_bomb':'recoil_bomb'}
            if event['event_id'] in weapons and (detail.get('scope')!='original_shot_fired_signal' or detail.get('weapon')!=weapons[event['event_id']]): raise ValueError('Weapon phase lacks original accepted shot signal')
            if event['event_id']=='bomb_explode' and detail.get('scope')!='original_weapon_runtime_blast_fired': raise ValueError('Explosion lacks original runtime signal')
            if event['event_id']=='hurt' and detail.get('scope')!='actual_enemy_projectile_damage': raise ValueError('Player hurt lacks actual enemy projectile provenance')
            if event['event_id'] in ['enemy_hit','enemy_hurt'] and (detail.get('scope')!='actual_enemy_damage_receipt' or detail.get('health')!=2): raise ValueError('Enemy damage lacks actual accepted HP change')
            if event['event_id'] in ['chest_open','item_get'] and detail.get('build_count')!=1: raise ValueError('RewardService did not accept an actual item')
        state=segment.get('state',{})
        if reel=='coin' and (state.get('wallet')!=1 or state.get('health')!=5): raise ValueError('Coin result missing')
        if reel=='heal' and state.get('health')!=5: raise ValueError('Heal result missing')
        if reel in ['chest_open','item_get'] and state.get('build_count')!=1: raise ValueError('Actual reward build missing')
        if reel=='chest_open' and state.get('chest_open') is not True: raise ValueError('Chest did not open')
        if reel=='ui' and (state.get('wallet')!=2 or state.get('build_count')!=1): raise ValueError('Actual shop commit/rejection state missing')
        if reel in ['hurt','mix'] and state.get('health')!=4: raise ValueError('Enemy projectile did not damage player')
        if reel in ['enemy_hit','enemy_hurt','mix'] and state.get('enemy_health')!=2: raise ValueError('Player projectile did not damage enemy')
        if segment.get('music_track')!=('home' if reel=='mix' else ''): raise ValueError('Unexpected live BGM setting')
        played=segment.get('played_delta',{})
        actual=segment.get('director_events',[])
        if profile=='original':
            if actual or any(v for k,v in played.items() if k.startswith('director_')): raise ValueError('Original profile used candidate audio')
            if any(played.get(k)!=1 for k in LEGACY_AUDIO[reel]): raise ValueError('Original profile actual target playback missing/repeated')
        else:
            if [str(e.get('id')) for e in actual]!=DIRECTOR_EVENTS[reel]: raise ValueError('Actual candidate playback missing, repeated or extra')
            if {k[9:]:v for k,v in played.items() if k.startswith('director_') and v}!=dict(Counter(DIRECTOR_EVENTS[reel])): raise ValueError('Played counter does not match actual expected candidate audio')
            for event in actual:
                if not start<=frame_integer(event.get('movie_frame'))<end: raise ValueError('Actual playback outside movie segment')
                candidate_id=str(event['id'])+'_'+profile.lower(); candidate=candidates.get(candidate_id)
                if not candidate or event.get('candidate')!=candidate_id or event.get('path') not in candidate.get('variants',[candidate.get('path')]): raise ValueError('Actual audio path/candidate disagrees with frozen manifest')
    if any(not (16<=r.get('player_screen',[-99,-99])[0]<=1264 and 155<=r.get('player_screen',[-99,-99])[1]<=560) for r in trace.get('trace',[])): raise ValueError('Actual player is outside visible action area')
    sequences=[[ [r.get('position'),r.get('hp'),r.get('enemy_hp')] for r in trace.get('trace',[]) if r.get('profile')==s['profile']] for s in segments]
    if not sequences[0] or any(seq!=sequences[0] for seq in sequences): raise ValueError('Four movie profiles have different actual physics/HP sequences')
    return segments

def validate_audio_windows(movie, trace, reel):
    # Capture evidence must use the stable, bounded post-validator. The older
    # cumulative-denominator implementation is retained only in historical Git.
    from audio_reels_validation import validate_audio_windows as stable_validate
    return stable_validate(movie, trace, reel)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT/'build/audio_director_v3/reels')
    parser.add_argument('--reel', choices=REELS, action='append')
    parser.add_argument('--smoke', action='store_true')
    args = parser.parse_args()
    folder = args.output.resolve(); folder.mkdir(parents=True,exist_ok=True)
    env = os.environ.copy(); env['LIBGL_ALWAYS_SOFTWARE']='1'
    display = None
    try:
        if not env.get('DISPLAY'):
            fallback = ROOT.parent/'toolchains/xvfb/usr/bin/Xvfb'
            binary = shutil.which('Xvfb') or (str(fallback) if fallback.is_file() else None)
            if not binary: raise RuntimeError('Xvfb required; native movie capture cannot use headless renderer')
            display = subprocess.Popen([binary,'-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=(folder/'display.log').open('wb'))
            with selectors.DefaultSelector() as selector:
                selector.register(display.stdout,selectors.EVENT_READ)
                if not selector.select(30): raise RuntimeError('Xvfb readiness timeout')
                number=display.stdout.readline().decode().strip()
            if not number.isdigit(): raise RuntimeError('Invalid Xvfb display')
            env['DISPLAY']=':'+number
        for reel in ['smoke'] if args.smoke else args.reel or REELS:
            clip=folder/reel; clip.mkdir(parents=True,exist_ok=True)
            avi=clip/'native.avi'; movie=clip/(reel+'.mp4')
            if avi.exists() or movie.exists(): raise RuntimeError(f'Refusing to overwrite prior capture {clip}; choose fresh --output')
            frozen=sources(); started=time.monotonic()
            command=['bash','tools/godot.sh','--path','.', '--rendering-method','gl_compatibility','--write-movie',str(avi),'--fixed-fps','60','--script','tools/audio_reels_capture.gd','--','--output='+str(clip),'--reel='+reel]
            if args.smoke: command.append('--smoke')
            engine_identity = verified_engine(repo=ROOT)
            engine = {'version': engine_identity['version'], 'sha256': engine_identity['binary_sha256'], 'path': engine_identity['binary']}
            report={'engine':engine,'version':'audio-director-v3-reels-1','reel':reel,'command':command,'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_before':frozen,'status':'failed','scope':'Real Godot write-movie, normal 60Hz tick, software GPU; original captured audio encoded AAC without replacement; explicit development fixtures, not natural progression or device/player approval.'}
            try:
                with (clip/'native.log').open('w') as log:
                    result=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=420)
                native=(clip/'native.log').read_text()
                marker='AUDIO_REELS_SMOKE frames=120' if args.smoke else f'AUDIO_REELS_CAPTURE reel={reel} complete=true'
                if result.returncode or ERROR.search(native) or marker not in native: raise RuntimeError('Godot capture failed; inspect retained native.log')
                subprocess.run(['ffmpeg','-y','-i',str(avi),'-c:v','libx264','-preset','fast','-crf','22','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',str(movie)],check=True,stdout=subprocess.DEVNULL,stderr=(clip/'encode.log').open('wb'),timeout=180)
                media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(movie)]))
                video=next(s for s in media['streams'] if s['codec_type']=='video'); audio=next(s for s in media['streams'] if s['codec_type']=='audio')
                if video['avg_frame_rate']!='60/1' or int(audio['sample_rate'])!=48000 or audio['channels']!=2: raise RuntimeError('Unexpected captured media format')
                if movie.stat().st_size>25*1024*1024: raise RuntimeError('Clip exceeds 25MiB')
                energy=subprocess.check_output(['ffmpeg','-i',str(movie),'-af','volumedetect','-vn','-sn','-dn','-f','null','-'],stderr=subprocess.STDOUT,text=True)
                mean=re.search(r'mean_volume: ([\-\d.]+|\-inf) dB',energy)
                if not mean or mean[1]=='-inf': raise RuntimeError('Native captured soundtrack is silent')
                if not args.smoke:
                    trace_path=clip/'trace.json'; trace=json.loads(trace_path.read_text())
                    frame_count=int(video['nb_frames'])
                    validate_trace(trace,reel,frame_count)
                    windows=validate_audio_windows(movie,trace,reel)
                    report.update(frame_count=frame_count,trace_sha256=sha(trace_path),audio_windows=windows)
                stable=frozen==sources()
                report.update(status='passed' if stable else 'failed',source_stable=stable,source_after=sources(),seconds=time.monotonic()-started,media=media,movie_sha256=sha(movie),mean_db=float(mean[1]),native_avi_sha256=sha(avi))
                if not stable: raise RuntimeError('Capture source changed; retained media is not frozen evidence')
            except Exception as error:
                report['error']=str(error)
                raise
            finally:
                (clip/'report.json').write_text(json.dumps(report,indent=2)+'\n')
            print(json.dumps({'reel':reel,'status':report['status'],'seconds':report['seconds'],'bytes':movie.stat().st_size,'path':str(movie)}),flush=True)
    finally:
        if display:
            display.terminate()
            try:display.wait(timeout=5)
            except subprocess.TimeoutExpired:display.kill();display.wait()

if __name__=='__main__': main()
