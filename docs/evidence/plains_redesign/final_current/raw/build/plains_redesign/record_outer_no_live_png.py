"""ONE isolated observation control: original route/assertions, no live PNG readback.
All screenshot images are explicitly post-extracted VIDEO FRAMES, not native/tick screenshots.
"""
from pathlib import Path
import json,subprocess,os,sys,hashlib,selectors,time
R=Path('/workspace/gunman-rush');B=R/'build/plains_redesign';F=B/'outer_no_live_png_movie';assert not F.exists(),'One attempt only, preserve any failure'
closure=json.loads((B/'observation_closure_v2.json').read_text());assert closure['status']=='observations_collected_with_failed_outer_route'
sys.path.insert(0,str(R/'tools'));import harness,level_formal
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
source=level_formal.source_files();script=B/'render_outer_loop.gd';F.mkdir()
d={'status':'running','scope':'Single no-live-PNG diagnostic control, original same SceneRunner route/cycle and all game checks; no driver/core/physics/input timestamps/seed/phase/resource changes. Omit only --screens-dir so frame_dir is empty. Original failed7/1 movie stays failed. Even success does not diagnose TTL.','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),'source_files':source,'producer_sha256':sha(Path(__file__)),'script_sha256':sha(script),'script_path':str(script.relative_to(R)),'environment':{'LP_NUM_THREADS':'1','LIBGL_ALWAYS_SOFTWARE':'1'},'original_failure_receipt_sha256':sha(B/'final_outer_movie/receipt.json'),'original_failure_review_sha256':sha(B/'final_regression_review/c4/outer_render_failure_review.md'),'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
def save(): (F/'receipt.json').write_text(json.dumps(d,indent=2)+'\n')
save();env=os.environ.copy();env.update(d['environment']);handle=(F/'display.log').open('wb');display=subprocess.Popen(['/workspace/toolchains/xvfb/usr/bin/Xvfb','-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=handle)
try:
 with selectors.DefaultSelector() as selector:
  selector.register(display.stdout,selectors.EVENT_READ);assert selector.select(20),'Xvfb timeout';env['DISPLAY']=':'+display.stdout.readline().decode().strip()
 command=['bash','tools/godot.sh','--rendering-method','gl_compatibility','--fixed-fps','60','--write-movie',str(F/'gameplay.avi'),'--path','.', '--script',str(script),'--','--output='+str(F/'capture.json')]
 d['command']=command;save()
 result=harness.run_check({'argv':command,'timeout_seconds':900,'success_pattern':r'^SCENE OUTER RENDER: [1-9]\d* assertions, 0 failures$'},F/'capture.log',R,env);d['process']=result;save()
 raw=json.loads((F/'capture.json').read_text());case=raw['cases'][0];assert case['finished'] is True and raw['screenshots']==[]
 assert source==level_formal.source_files(),'Source drift';d.update(source_after=level_formal.source_files(),outcome=case['outcome'],ticks=case['ticks'],assertions=raw['assertions'],failures=raw['failures'],raw_sha256=sha(F/'capture.json'),log_sha256=sha(F/'capture.log'))
 with (F/'encode.log').open('w') as log:
  subprocess.run(['ffmpeg','-i',str(F/'gameplay.avi'),'-c:v','libx264','-crf','21','-pix_fmt','yuv420p','-c:a','aac',str(F/'gameplay.mp4')],check=True,stdout=log,stderr=subprocess.STDOUT,timeout=180)
 media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(F/'gameplay.mp4')],timeout=30));video=next(s for s in media['streams'] if s['codec_type']=='video');audio=next(s for s in media['streams'] if s['codec_type']=='audio')
 assert video['width']==1280 and video['height']==720 and video['avg_frame_rate']=='60/1' and int(audio['sample_rate'])==48000 and audio['channels']==2
 frames=int(video['nb_frames']);numbers=sorted(set([0,frames-1]+list(range(600,frames,600))+[n for n in [3000,3240,4080,4200,4560,4800,5040,5280,5400,6000,6480] if n<frames]));images=F/'video_frames';images.mkdir();selection='select='+ '+'.join('eq(n\\,'+str(n)+')' for n in numbers)
 with (F/'extract_video_frames.log').open('w') as log:
  subprocess.run(['ffmpeg','-i',str(F/'gameplay.mp4'),'-vf',selection,'-vsync','0',str(images/'extracted_%06d.png')],check=True,stdout=log,stderr=subprocess.STDOUT,timeout=120)
 outputs=sorted(images.glob('extracted_*.png'));assert len(outputs)==len(numbers),(len(outputs),len(numbers));pngs=[]
 for p,n in zip(outputs,numbers):
  target=images/f'video_frame_{n:06d}.png';p.rename(target);pngs.append({'path':str(target.relative_to(R)),'sha256':sha(target),'video_frame_index_zero_based':n,'video_time_seconds':n/60,'scope':'Post-extracted actual MP4 frame; not an exact physical tick or native screenshot receipt.'})
 cycle=case.get('route_comparison',{}).get('cycle_return',{});passed=(result['status']=='passed' and result['exit_code']==0 and raw['failures']==0 and case['outcome']=='route_target_reached' and cycle.get('reached') is True and len(cycle.get('actual_edges',[]))==2 and not case['issues'])
 d.update(status='captured_route_passed' if passed else 'captured_route_failed',route_reached=passed,actual_circuit=cycle,media=media,movie_sha256=sha(F/'gameplay.mp4'),video_frames=pngs,finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()));save()
 # Successful temporary AVI is rebuildable from retained complete MP4/trace; failed original AVI remains intact elsewhere.
 if passed:(F/'gameplay.avi').unlink()
finally:
 if d['status']=='running':d['status']='blocked';save()
 display.terminate();display.wait(timeout=10);handle.close()
raise SystemExit(0 if d['status']=='captured_route_passed' else 1)
