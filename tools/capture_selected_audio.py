#!/usr/bin/env python3
"""Record the user's chosen SFX in actual Godot, preserving its native soundtrack."""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
from capture_audio_reels import ROOT, REELS, EXPECTED_EVENTS, DIRECTOR_EVENTS, LEGACY_AUDIO, ERROR, sources, sha, frame_integer
from audio_reels_validation import validate_audio_windows
from audio_reel_choices import normalize, read_json

def verified_selection():
    folder=ROOT/'config/audio_director/selected'
    selected=json.loads((folder/'selected.json').read_text())
    raw=folder/'user-20261028.json';reels=folder/'reels-user-20261028.json';manifest=ROOT/'assets/audio/director_v3/manifest.json'
    expected=normalize(read_json(raw.read_bytes()),read_json(reels.read_bytes()),read_json(manifest.read_bytes()),root=ROOT)
    if {k:v for k,v in selected.items() if k!='provenance'}!=expected:raise ValueError('Normalized selection differs from retained user choices')
    provenance=selected.get('provenance',{})
    for key,path in [('input',raw),('reels',reels),('candidate_manifest',manifest)]:
        if provenance.get(key,{}).get('sha256')!=sha(path):raise ValueError('Selection input fingerprint mismatch')
    if provenance.get('importer_sha256')!=sha(ROOT/'tools/audio_reel_choices.py'):raise ValueError('Selection importer changed; re-import required')
    return selected

def validate_selected_trace(trace, frame_count, selection):
    frame_count=frame_integer(frame_count)
    if trace.get('version')!='audio-director-selected-20261028' or trace.get('fps')!=60:raise ValueError('Wrong selected trace version/FPS')
    clock=trace.get('movie_clock',{})
    if clock.get('index_base')!=0 or abs(frame_integer(clock.get('frames_drawn_before_quit'))-frame_count)>2:raise ValueError('Actual MovieWriter frame clock drift')
    manifest=json.loads((ROOT/'assets/audio/director_v3/manifest.json').read_text())
    candidates={c['id']:c for e in manifest['events'] for c in e['candidates']}
    segments=trace['segments'];profiles=selection['event_profiles']
    if [(s.get('reel'),s.get('profile')) for s in segments]!=[(r,p) for r in REELS for p in ['original','selected']]:raise ValueError('Missing/reordered original-selected chapter')
    if trace.get('selection')!=selection:raise ValueError('Selection receipt drift')
    last=-1
    for s in segments:
        reel=s['reel'];profile=s['profile'];start=frame_integer(s['start_frame']);end=frame_integer(s['end_frame'])
        if not last<start<end<=frame_count or not 60<=end-start<=900:raise ValueError('Invalid chapter frame bounds')
        last=end
        if [e['event_id'] for e in s['events']]!=EXPECTED_EVENTS[reel]:raise ValueError('Actual accepted event missing/repeated: '+reel)
        for e in s['events']:
            ep=profiles.get(e['event_id'],'original') if profile=='selected' else 'original'
            cid='original' if ep=='original' else e['event_id']+'_'+ep.lower()
            if e['candidate_id']!=cid or not start<=frame_integer(e['movie_frame'])<end:raise ValueError('Accepted event selection/frame mismatch')
            if profile=='selected' and e.get('event_profile')!=ep:raise ValueError('Accepted event actual profile differs from user selection')
            d=e['details'];eid=e['event_id']
            if eid in ['coin','heal','item_get'] and d.get('contact') is not True:raise ValueError('No real pickup contact')
            if eid=='coin' and d.get('wallet')!=1:raise ValueError('No wallet receipt')
            if eid=='heal' and d.get('health')!=5:raise ValueError('No heal receipt')
            if eid in ['chest_open','item_get'] and d.get('build_count')!=1:raise ValueError('No real reward build receipt')
            if eid=='chest_open' and d.get('opened') is not True:raise ValueError('No actual opening')
            if eid in ['enemy_hit','enemy_hurt'] and (d.get('scope')!='actual_enemy_damage_receipt' or d.get('health')!=2):raise ValueError('No actual enemy damage')
            if eid=='hurt' and d.get('scope')!='actual_enemy_projectile_damage':raise ValueError('No actual enemy projectile damage')
            weapons={'shot_pulse':'pulse_gun','shot_shuriken':'shadow_shuriken','shot_bomb':'recoil_bomb'}
            if eid in weapons and (d.get('scope')!='original_shot_fired_signal' or d.get('weapon')!=weapons[eid]):raise ValueError('No exact weapon identity')
            if eid=='bomb_explode' and d.get('scope')!='original_weapon_runtime_blast_fired':raise ValueError('No original blast signal')
        state=s['state']
        if reel=='ui' and (state['wallet']!=2 or state['build_count']!=1):raise ValueError('Shop commit/denial missing')
        if reel in ['hurt','mix'] and state['health']!=4:raise ValueError('Actual player HP result missing')
        if reel in ['enemy_hit','enemy_hurt','mix'] and state['enemy_health']!=2:raise ValueError('Actual enemy HP result missing')
        expected=[] if profile=='original' else [eid for eid in DIRECTOR_EVENTS[reel] if profiles.get(eid,'original')!='original']
        if [e['id'] for e in s['director_events']]!=expected:raise ValueError('Unexpected/missing actual candidate plays')
        played={k[9:]:v for k,v in s['played_delta'].items() if k.startswith('director_') and v}
        if played!=dict(Counter(expected)):raise ValueError('Actual played counters disagree')
        for e in s['director_events']:
            cid=e['id']+'_'+profiles[e['id']].lower();c=candidates[cid]
            if e['candidate']!=cid or e['path'] not in c.get('variants',[c.get('path')]) or not start<=frame_integer(e['movie_frame'])<end:raise ValueError('Wrong actual WAV/frame')
        if profile=='original' and any(s['played_delta'].get(k)!=1 for k in LEGACY_AUDIO[reel]):raise ValueError('Original actual cue missing')
        if reel=='weapons' and profile=='selected' and any(s['played_delta'].get(k)!=1 for k in ['weapon_blade','weapon_blast']):raise ValueError('Selected original weapon fallback missing')
        if s['music_track']!=('home' if reel=='mix' else ''):raise ValueError('Wrong actual BGM')
        action_start=frame_integer(s['action_start_frame']);action_end=frame_integer(s['action_end_frame'])
        rows=[r for r in trace['trace'] if r.get('reel')==reel and r['profile']==profile and action_start<frame_integer(r['action_frame'])<=action_end]
        if [r['action_frame'] for r in rows]!=list(range(action_start+1,action_end+1)):raise ValueError('Actual action samples missing/repeated/reordered')
        if not rows or any(not start<=frame_integer(r['movie_frame'])<=end for r in rows):raise ValueError('Actual action sample outside movie chapter')
        for before,after in zip(rows,rows[1:]):
            if frame_integer(after['physics_tick'])!=frame_integer(before['physics_tick'])+1:raise ValueError('Actual physics tick discontinuity')
            # Context reconstruction is explicitly paused in mix. Rendering
            # may advance while sampling is suspended, but cannot go backward.
            if frame_integer(after['movie_frame'])<=frame_integer(before['movie_frame']):raise ValueError('Actual MovieWriter action frame order invalid')
    for reel in REELS:
        sequences=[[[r['position'],r['hp'],r['enemy_hp']] for r in trace['trace'] if r.get('reel')==reel and r['profile']==p] for p in ['original','selected']]
        if not sequences[0] or sequences[0]!=sequences[1]:raise ValueError('Original-selected actual physics/HP differs: '+reel)
    if any(not(16<=r['player_screen'][0]<=1264 and 155<=r['player_screen'][1]<=560) for r in trace['trace']):raise ValueError('Actor out of actual visible action area')
    return segments

def frozen_sources():
    return sources()|{str(p.relative_to(ROOT)):sha(p) for p in [Path(__file__).resolve(),ROOT/'tools/audio_reel_choices.py']}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);args=p.parse_args();folder=args.output.resolve()
    if folder.exists():raise ValueError('Use fresh output; preserve prior attempts')
    folder.mkdir(parents=True);env=os.environ.copy();env['LIBGL_ALWAYS_SOFTWARE']='1';display=None;report={'status':'failed','commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'scope':'Actual native Godot soundtrack; development fixtures; user selected individual sounds, full combination/device approval pending'};started=time.monotonic()
    try:
        if not env.get('DISPLAY'):
            binary=shutil.which('Xvfb') or str(ROOT.parent/'toolchains/xvfb/usr/bin/Xvfb')
            display=subprocess.Popen([binary,'-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=(folder/'display.log').open('wb'),text=True);env['DISPLAY']=':'+display.stdout.readline().strip()
        selection=verified_selection()
        engine_path=Path(os.environ.get('GODOT_BIN',str(ROOT.parent/'toolchains/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64'))).resolve()
        report['engine']={'version':subprocess.check_output(['bash','tools/godot.sh','--version'],cwd=ROOT,text=True).strip(),'path':str(engine_path),'sha256':sha(engine_path)}
        frozen=frozen_sources();report['source_before']=frozen
        avi=folder/'native.avi';movie=folder/'selected.mp4'
        command=['bash','tools/godot.sh','--path','.', '--audio-driver','Dummy','--rendering-method','gl_compatibility','--write-movie',str(avi),'--fixed-fps','60','--resolution','1280x720','--script','res://tools/audio_reels_capture.gd','--','--selected','--output='+str(folder)]
        report['command']=command
        with (folder/'native.log').open('w') as log:result=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=420)
        native=(folder/'native.log').read_text()
        if result.returncode or ERROR.search(native) or 'AUDIO_REELS_CAPTURE reel=coin complete=true' not in native:raise ValueError('Godot capture failed; original log retained')
        subprocess.run(['ffmpeg','-y','-i',str(avi),'-c:v','libx264','-preset','fast','-crf','22','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',str(movie)],stdout=subprocess.DEVNULL,stderr=(folder/'encode.log').open('wb'),check=True,timeout=180)
        media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(movie)]));video=next(s for s in media['streams'] if s['codec_type']=='video');audio=next(s for s in media['streams'] if s['codec_type']=='audio')
        if video['avg_frame_rate']!='60/1' or int(audio['sample_rate'])!=48000 or audio['channels']!=2:raise ValueError('Wrong actual encoding')
        trace=json.loads((folder/'trace.json').read_text());segments=validate_selected_trace(trace,int(video['nb_frames']),selection)
        windows=validate_audio_windows(movie,trace,'selected-user-20261028')
        chapters={'chapters':[{'id':s['reel'],'title':s['reel'],'profile':s['profile'],'start':s['start_frame']/60,'end':s['end_frame']/60} for s in segments]};(folder/'chapters.json').write_text(json.dumps(chapters,indent=2)+'\n')
        stable=frozen==frozen_sources();report.update(source_after=frozen_sources(),source_stable=stable,media=media,audio_windows=windows,movie_sha256=sha(movie),native_avi_sha256=sha(avi),trace_sha256=sha(folder/'trace.json'),frame_count=int(video['nb_frames']),movie_bytes=movie.stat().st_size)
        if not stable:raise ValueError('Sources changed while capturing')
        report['status']='passed'
    except Exception as error:report['error']=str(error);raise
    finally:
        report['seconds']=time.monotonic()-started;(folder/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        if display:
            display.terminate()
            try:display.wait(timeout=5)
            except subprocess.TimeoutExpired:display.kill();display.wait()
    print(json.dumps({'status':report['status'],'movie':str(movie),'bytes':movie.stat().st_size,'frames':report['frame_count']}))

if __name__=='__main__':main()
