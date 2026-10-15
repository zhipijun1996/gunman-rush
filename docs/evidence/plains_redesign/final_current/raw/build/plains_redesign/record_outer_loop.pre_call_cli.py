# Exact C2 restored only; actual two art failures remain blocked, no quality-completion claim.
import sys,os,json,subprocess,selectors,hashlib,argparse,time
from pathlib import Path
sys.path.insert(0,'tools')
import harness,level_formal
args=argparse.ArgumentParser();args.add_argument('--mode',choices=['outer'],required=True);args.add_argument('--folder',required=True);opts=args.parse_args()
root=Path.cwd();state=json.loads((root/'build/verification/plains-redesign-q6-cliff-asset/state.json').read_text());assert state['status']=='blocked',state['status']
rollback=json.loads((root/'build/plains_redesign/q6_rollback/execution.json').read_text());assert rollback['status'] in {'restored_pending_actual_tests','revalidated'}
for row in rollback['rows']: assert hashlib.sha256((root/row['path']).read_bytes()).hexdigest()==row['restored_sha256']
engines=[s for s in subprocess.check_output(['ps','-eo','pid,args'],text=True).splitlines() if 'Godot_v4.7.2-stable_linux.x86_64' in s and 'ps -eo' not in s];assert not engines,engines
folder=root/opts.folder;folder.mkdir()
producer=Path(__file__).resolve();script=root/'build/plains_redesign/render_outer_loop.gd'
source=level_formal.source_files();env=os.environ.copy();env['LP_NUM_THREADS']='1';env['LIBGL_ALWAYS_SOFTWARE']='1'
handle=(folder/'display.log').open('wb');display=subprocess.Popen(['/workspace/toolchains/xvfb/usr/bin/Xvfb','-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=handle)
report={'status':'failed','source_files':source,'producer_sha256':level_formal.file_hash(producer),'script_sha256':level_formal.file_hash(script),'environment':{'LP_NUM_THREADS':'1','LIBGL_ALWAYS_SOFTWARE':'1'},'scope':'Actual full-prefix new counterclockwise outer circuit with synthetic real Router input, 1280x720/60FPS/stereo48k software movie; no old same route, no human/device/audio listening approval'}
try:
 with selectors.DefaultSelector() as selector:
  selector.register(display.stdout,selectors.EVENT_READ)
  if not selector.select(20):raise RuntimeError('display timeout')
  env['DISPLAY']=':'+display.stdout.readline().decode().strip()
 command=['bash','tools/godot.sh','--rendering-method','gl_compatibility','--fixed-fps','60','--write-movie',str(folder/'gameplay.avi'),'--path','.','--script',str(script),'--','--output='+str(folder/'capture.json'),'--screens-dir='+str(folder/'frames')]
 report['command']=command
 result=harness.run_check({'argv':command,'timeout_seconds':900,'success_pattern':r'^SCENE OUTER RENDER: [1-9]\d* assertions, 0 failures$'},folder/'capture.log',root,env);report['process']=result
 data=json.loads((folder/'capture.json').read_text())
 report['outcome']=data['cases'][0]['outcome'];report['screenshots']=data['screenshots']
 assert result['status']=='passed' and data['failures']==0 and data['cases'][0]['outcome']=='route_target_reached' and data['screenshots']
 case=data['cases'][0];cycle=case['route_comparison'].get('cycle_return',{});assert cycle.get('reached') and len(cycle.get('actual_edges',[]))==2
 report['actual_circuit']=cycle;report['ticks']=case['ticks'];report['damage_scope']='Read actual full-prefix events; successful HP3 return is not a full-route no-hurt claim' 
 assert all(s['error']==0 and s['width']==1280 and s['height']==720 and level_formal.file_hash(Path(s['path']))==s['sha256'] for s in data['screenshots'])
 assert source==level_formal.source_files()
 with (folder/'encode.log').open('w') as log:
  subprocess.run(['ffmpeg','-y','-i',str(folder/'gameplay.avi'),'-c:v','libx264','-crf','21','-pix_fmt','yuv420p','-c:a','aac',str(folder/'gameplay.mp4')],check=True,stdout=subprocess.DEVNULL,stderr=log,timeout=120)
 media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(folder/'gameplay.mp4')]))
 video=next(s for s in media['streams'] if s['codec_type']=='video');audio=next(s for s in media['streams'] if s['codec_type']=='audio')
 assert video['avg_frame_rate']=='60/1' and video['width']==1280 and video['height']==720 and int(audio['sample_rate'])==48000 and audio['channels']==2
 report['media']=media;report['movie_sha256']=level_formal.file_hash(folder/'gameplay.mp4');report['status']='captured';report['source_after']=level_formal.source_files()
 assert source==report['source_after'];(folder/'gameplay.avi').unlink()
finally:
 (folder/'receipt.json').write_text(json.dumps(report,indent=2)+'\n');display.terminate();display.wait(timeout=10);handle.close()
