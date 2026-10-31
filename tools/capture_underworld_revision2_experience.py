#!/usr/bin/env python3
"""Capture final-source ordinary formal/Home inputs; use only in an assigned GPU slot."""
from pathlib import Path
import argparse,contextlib,hashlib,json,os,re,shutil,subprocess,sys,time
from run_tests import run_engine
from run_underworld_home_tests import Tee
ROOT=Path(__file__).resolve().parents[1]
FIXTURE='tests/underworld_plains/capture_revision2_experience.gd'
SELF='tools/capture_underworld_revision2_experience.py'
RUNTIME=['project.godot','scripts','game','experiments','scenes','resources','config','shaders','assets',FIXTURE,SELF,'tools/run_underworld_home_tests.py','tools/run_tests.py','tests/audio_teardown.gd']
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def inventory():
    suffixes={'.gd','.tscn','.tres','.json','.gdshader','.png','.ogg','.wav','.ttf','.otf'}
    paths=[ROOT/'project.godot',ROOT/FIXTURE,Path(__file__).resolve(),ROOT/'tools/godot.sh',ROOT/'tools/run_tests.py',ROOT/'tools/run_underworld_home_tests.py',ROOT/'tests/audio_teardown.gd']
    for folder in ['scripts','game','experiments','scenes','resources','config','shaders','assets']:
        paths.extend(p for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix in suffixes)
    return {str(p.relative_to(ROOT)):sha(p) for p in sorted(set(paths))}
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-commit',required=True);p.add_argument('--output',required=True)
    p.add_argument('--mode',choices=['formal','home','both'],default='both')
    p.add_argument('--seed',default='level-design-v2-baseline/08');p.add_argument('--display',default=':98')
    p.add_argument('--plan',action='store_true');args=p.parse_args()
    target=Path(args.output).resolve()
    if not target.is_relative_to(ROOT/'build') or target.exists():raise RuntimeError('Use a NEW build output directory; retain all earlier evidence')
    commit=subprocess.check_output(['git','rev-parse',args.source_commit+'^{commit}'],cwd=ROOT,text=True).strip()
    if subprocess.check_output(['git','diff','--name-only',commit,'--',*RUNTIME],cwd=ROOT,text=True).strip():raise RuntimeError('Actual runtime/producer differs from requested frozen source')
    untracked=subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',*RUNTIME],cwd=ROOT,text=True).splitlines()
    if untracked:raise RuntimeError('Uncommitted runtime/producer files: '+', '.join(untracked))
    modes=['formal','home'] if args.mode=='both' else [args.mode]
    commands={}
    for mode in modes:
        folder=target/mode
        commands[mode]=['--path','.','--rendering-method','gl_compatibility','--audio-driver','Dummy','--write-movie',str(folder/'raw.avi'),'--fixed-fps','60','--script',FIXTURE,'--','--experience='+mode,'--seed='+args.seed,'--output=res://'+str((folder/'trace.json').relative_to(ROOT))]
    if args.plan:
        print(json.dumps({'source':commit,'commands':commands,'note':'Plan only; actual run requires an exclusive assigned GPU slot'},indent=2));return
    target.mkdir(parents=True)
    os.environ['DISPLAY']=args.display;os.environ['LIBGL_ALWAYS_SOFTWARE']='1';os.environ.setdefault('LP_NUM_THREADS','1')
    before=inventory()
    report={'schema':'underworld-revision2-actual-experience-capture-v1','source_commit':commit,'worktree_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_hashes_before':before,'captures':[],'status':'failed','scope':'ordinary real DemoApp consumers driven by actual KeyboardMouseAdapter InputEvents; normal60fps simulation/playback software recording, not hardware FPS/player/device acceptance','audio_policy':'Dummy engine output, no real hardware audio/listening acceptance. Track presence and RMS are observed separately, not evidence of listening.'}
    try:
        for mode in modes:
            folder=target/mode;folder.mkdir()
            started=time.monotonic();log=folder/'capture.log'
            timeout = 300 if mode == 'home' else 150
            item={'mode':mode,'argv':['bash',str(ROOT/'tools/godot.sh'),*commands[mode]],'timeout_seconds':timeout,'timeout_basis':'Home full east/west real-keyboard tour needs roughly30s playback; G formal movie measured9s playback in55s software recording (~16% realtime), estimating Home190s. Bounded300s Home only; formal150s and original inputTTL/physics unchanged.','status':'failed'}
            report['captures'].append(item)
            with log.open('w') as stream,contextlib.redirect_stdout(Tee(sys.stdout,stream)):
                output=run_engine(commands[mode],timeout)
            item['engine_exit_code']=0;item['wall_seconds']=time.monotonic()-started
            if re.search(r'SCRIPT ERROR:|SHADER ERROR:|ERROR:',output):raise RuntimeError('Capture emitted actual engine error')
            matches=re.findall(r'^REVISION2 EXPERIENCE: '+mode+r' ([1-9]\d*) frames, ([1-9]\d*) assertions, 0 failures$',output,re.M)
            if len(matches)!=1:raise RuntimeError('Missing exact successful experience completion')
            trace=json.loads((folder/'trace.json').read_text())
            if trace['failures'] or len(trace['frames'])!=int(matches[0][0]) or trace['checks']!=int(matches[0][1]):raise RuntimeError('Actual trace does not match completion')
            if not trace['input_events'] or not any(e.get('kind')=='InputEventKey' and e.get('key')=='D' and e.get('pressed') for e in trace['input_events']):raise RuntimeError('No actual D keyboard event recorded')
            if not any(e.get('kind')=='InputEventKey' and e.get('key')=='A' and e.get('pressed') for e in trace['input_events']):raise RuntimeError('No actual A keyboard event recorded')
            if any(row.get('visible_muzzle_matches_authority') is False for row in trace['frames']):raise RuntimeError('Actual muzzle disagrees with authority')
            if mode=='home' and (len(trace['slots'])!=12 or sum(not s['reserved'] for s in trace['slots'])!=4):raise RuntimeError('Actual Home socket visit set incomplete')
            if before!=inventory():raise RuntimeError('Actual runtime/producer changed during movie capture')
            with (folder/'encode.log').open('w') as encoding:
                subprocess.run(['ffmpeg','-y','-i',str(folder/'raw.avi'),'-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-c:a','aac',str(folder/'movie.mp4')],stdout=subprocess.DEVNULL,stderr=encoding,check=True,timeout=150)
            media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(folder/'movie.mp4')],timeout=30))
            video=next(s for s in media['streams'] if s['codec_type']=='video');audio=[s for s in media['streams'] if s['codec_type']=='audio']
            if video['avg_frame_rate']!='60/1' or (video['width'],video['height'])!=(1280,720):raise RuntimeError('Normal-speed1280x720/60fps movie contract failed')
            rms=subprocess.run(['ffmpeg','-i',str(folder/'movie.mp4'),'-vn','-af','astats=metadata=1:reset=0','-f','null','-'],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True,timeout=60)
            (folder/'audio_measurement.log').write_text(rms.stderr)
            images=[]
            # Decode selected frames after the run; never read PNGs during input.
            phases=['formal_run_D_aim_right','formal_run_A_aim_right','formal_ground_shot_release_recoil','formal_space_jump_hold','formal_jump_fall_and_land'] if mode=='formal' else ['home_walk_upgrade','home_service_upgrade','home_walk_relics','home_walk_garden','home_returned_west_idle']
            for phase in phases:
                rows=[r for r in trace['frames'] if r['phase']==phase]
                if not rows:continue
                row=rows[len(rows)//2];frame=max(0,int(row['drawn_frames'])-1);png=folder/(phase+'.png')
                subprocess.run(['ffmpeg','-y','-i',str(folder/'movie.mp4'),'-vf',f'select=eq(n\\,{frame})','-frames:v','1',str(png)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True,timeout=30)
                if not png.exists():raise RuntimeError('Observed-frame decode missing')
                images.append({'path':str(png.relative_to(ROOT)),'sha256':sha(png),'frame':frame,'phase':phase,'mapping':'post_draw Engine.frames_drawn minus1; nearby rendered frame, not an independently calibrated exact physical-tick image'})
            item.update(status='captured',frames=len(trace['frames']),checks=trace['checks'],media=media,audio_streams=audio,audio_rms_db=re.findall(r'RMS level dB: ([^\n]+)',rms.stderr)[-1:] or ['not_measured'],audio_listening='unverified; Dummy engine output; no hardware sound acceptance',images=images,artifacts={p.name:sha(p) for p in folder.iterdir() if p.is_file()})
        after=inventory();report['source_hashes_after']=after
        if before!=after:raise RuntimeError('Source drift after media validation')
        report['status']='captured'
        print('REVISION2 ACTUAL EXPERIENCE: '+','.join(modes)+' source-bound movies captured')
    except Exception as error:
        report['error']=f'{type(error).__name__}: {error}'
        raise
    finally:
        report['source_hashes_after']=inventory()
        (target/'source_binding.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':main()
