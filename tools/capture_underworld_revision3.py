#!/usr/bin/env python3
"""Strict frozen-source R3 native MovieMaker samples; reserve an exclusive GPU slot."""
from pathlib import Path
import argparse,contextlib,json,os,re,shutil,subprocess,time
from capture_underworld_revision2_experience import inventory as runtime_inventory,sha
from run_tests import run_engine
from run_underworld_home_tests import Tee
ROOT=Path(__file__).resolve().parents[1]
FIXTURES=['tests/underworld_plains/capture_underworld_r3_boss_fight.gd','tests/underworld_plains/capture_revision3_environment.gd','tests/underworld_plains/capture_revision3_projectile_windows.gd','tests/underworld_plains/test_underworld_home_terraces.gd','tests/underworld_plains/home_terrace_driver.gd','tools/capture_underworld_revision3.py']
SCOPES=['scripts','scenes','resources','config','shaders','assets','project.godot','export_presets.cfg',*FIXTURES]
def inventory():
    values=runtime_inventory()
    for name in FIXTURES+['export_presets.cfg']:values[name]=sha(ROOT/name)
    return values

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-commit',required=True);p.add_argument('--output',required=True)
    p.add_argument('--case',choices=['boss1','boss2','surface','gear','enemy','home'],required=True)
    p.add_argument('--display',default=':98');p.add_argument('--timeout',type=int,default=300)
    args=p.parse_args();target=Path(args.output).resolve()
    if not target.is_relative_to(ROOT/'build') or target.exists():raise RuntimeError('Use a NEW build folder; earlier failures must remain')
    commit=subprocess.check_output(['git','rev-parse',args.source_commit+'^{commit}'],text=True,cwd=ROOT).strip()
    if subprocess.check_output(['git','diff','--name-only',commit,'--',*SCOPES],text=True,cwd=ROOT).strip():raise RuntimeError('Runtime/producer changed from requested source')
    if subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',*SCOPES],text=True,cwd=ROOT).strip():raise RuntimeError('Untracked runtime/producer source')
    target.mkdir(parents=True);before=inventory()
    os.environ['DISPLAY']=args.display;os.environ['LIBGL_ALWAYS_SOFTWARE']='1';os.environ.setdefault('LP_NUM_THREADS','1')
    if args.case.startswith('boss'):
        number=int(args.case[-1]);fixture=FIXTURES[0];extra=['--map='+str(number)];receipt=ROOT/f'build/underworld_r3/boss/full_fight_map{number}.json';pattern=rf'^UNDERWORLD R3 FULL BOSS MAP{number}: [1-9]\d* frames, 0 failures$'
    elif args.case in ['surface','gear']:
        fixture=FIXTURES[1];extra=['--kind='+args.case,'--capture','--output=res://'+str((target/'trace.json').relative_to(ROOT))];receipt=target/'trace.json';pattern=rf'^REVISION3 ENVIRONMENT kind={args.case} frames=[1-9]\d* checks=[1-9]\d* failures=0$'
    elif args.case=='enemy':
        fixture=FIXTURES[2];extra=['--focus=enemy','--frames=540','--output=res://'+str((target/'trace.json').relative_to(ROOT))];receipt=target/'trace.json';pattern=r'^R3 FORMAL PROJECTILE WINDOW: enemy .*failures=0$'
    else:
        fixture=FIXTURES[3];extra=[];receipt=ROOT/'build/underworld_r3/home/receipt.json';pattern=r'^UNDERWORLD HOME TERRACES: 180 assertions, 0 failures$'
    engine=['--path','.','--rendering-method','gl_compatibility','--audio-driver','Dummy','--fixed-fps','60','--write-movie',str(target/'raw.avi'),'--script',fixture,'--',*extra]
    report={'schema':'underworld-r3-frozen-native-capture-v1','source_commit':commit,'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'case':args.case,'command':['bash','tools/godot.sh',*engine],'timeout_seconds':args.timeout,'status':'failed','source_before':before,'scope':'Actual formal App consumers; Boss/environment/enemy windows explicitly initialize room/anchor position once, no midfight HP/AI/resource injection; Home is real native input tour. Not natural whole-map traversal or device/player acceptance.','audio_scope':'Dummy MovieMaker mix; track/RMS alone is not listening or physical output evidence'}
    error=None;start=time.monotonic();fresh=time.time_ns()
    try:
        with (target/'capture.log').open('w') as stream,contextlib.redirect_stdout(Tee(__import__('sys').stdout,stream)):
            output=run_engine(engine,args.timeout)
        if not re.search(pattern,output,re.M):raise RuntimeError('Missing exact successful native completion')
        if not receipt.exists() or receipt.stat().st_mtime_ns<fresh:raise RuntimeError('No fresh native trace')
        value=json.loads(receipt.read_text())
        if value.get('failures') not in [0,[]]:raise RuntimeError('Native receipt contains failures')
        if args.case.startswith('boss') and (value.get('boss_hp')!=0 or value.get('player_hp',0)<=0 or not value.get('no_midfight_injection')):raise RuntimeError('Actual full fight did not settle alive')
        if args.case=='home' and (value.get('checks')!=180 or len(value.get('visits',[]))!=12):raise RuntimeError('Actual Home tour incomplete')
        if receipt.resolve()!=(target/'trace.json').resolve():shutil.copy2(receipt,target/'trace.json')
        with (target/'encode.log').open('w') as stream:subprocess.run(['ffmpeg','-y','-i',str(target/'raw.avi'),'-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-c:a','aac',str(target/'movie.mp4')],stdout=subprocess.DEVNULL,stderr=stream,check=True,timeout=180)
        media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(target/'movie.mp4')],timeout=30))
        video=next(x for x in media['streams'] if x['codec_type']=='video')
        if video['avg_frame_rate']!='60/1' or (video['width'],video['height'])!=(1280,720):raise RuntimeError('Wrong movie dimensions/playback rate')
        subprocess.run(['ffmpeg','-v','error','-i',str(target/'movie.mp4'),'-f','null','-'],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,check=True,timeout=120)
        sound=subprocess.run(['ffmpeg','-i',str(target/'movie.mp4'),'-vn','-af','astats=metadata=1:reset=0','-f','null','-'],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True,check=True,timeout=60)
        (target/'audio_measurement.log').write_text(sound.stderr)
        report.update(status='passed',engine_exit_code=0,media=media,audio_rms_db=re.findall(r'RMS level dB: ([^\n]+)',sound.stderr)[-1:] or ['not_measured'])
    except Exception as e:error=e;report['error']=type(e).__name__+': '+str(e)
    finally:
        report['source_after']=inventory();report['source_unchanged']=before==report['source_after'];report['wall_seconds']=time.monotonic()-start
        if not report['source_unchanged']:report['status']='failed';error=error or RuntimeError('Runtime/producer source changed during capture')
        report['artifacts']=[{'path':str(f.relative_to(ROOT)),'bytes':f.stat().st_size,'sha256':sha(f)} for f in sorted(target.glob('*')) if f.is_file() and f.suffix not in ['.avi']]
        (target/'source_binding.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    if error:raise error
    print('PASS: frozen R3 native movie '+args.case)
if __name__=='__main__':main()
