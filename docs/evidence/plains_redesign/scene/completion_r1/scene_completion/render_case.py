import sys,os,json,subprocess,selectors,hashlib,argparse,time
from pathlib import Path
sys.path.insert(0,'tools')
import harness,level_formal
args=argparse.ArgumentParser();args.add_argument('--mode',choices=['repair','extra','extra_touch'],required=True);args.add_argument('--folder',required=True);opts=args.parse_args()
root=Path.cwd();folder=root/opts.folder;folder.mkdir()
producer=Path(__file__).resolve();script=root/('build/plains_redesign/scene_completion/render_'+opts.mode+'.gd')
source=level_formal.source_files();env=os.environ.copy();env['LP_NUM_THREADS']='1';env['LIBGL_ALWAYS_SOFTWARE']='1'
handle=(folder/'display.log').open('wb');display=subprocess.Popen(['/workspace/toolchains/xvfb/usr/bin/Xvfb','-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=handle)
report={'status':'failed','source_files':source,'producer_sha256':level_formal.file_hash(producer),'script_sha256':level_formal.file_hash(script),'environment':{'LP_NUM_THREADS':'1','LIBGL_ALWAYS_SOFTWARE':'1'},'scope':'actual software-GPU 1280x720 live formal inputs, actual normal-speed 60FPS/stereo48k movie plus exact viewport screenshots; no audio listening/device acceptance'}
try:
 with selectors.DefaultSelector() as selector:
  selector.register(display.stdout,selectors.EVENT_READ)
  if not selector.select(20):raise RuntimeError('display timeout')
  env['DISPLAY']=':'+display.stdout.readline().decode().strip()
 command=['bash','tools/godot.sh','--rendering-method','gl_compatibility','--fixed-fps','60','--write-movie',str(folder/'gameplay.avi'),'--path','.','--script',str(script),'--','--output='+str(folder/'capture.json'),'--screens-dir='+str(folder/'frames')]
 report['command']=command
 result=harness.run_check({'argv':command,'timeout_seconds':300,'success_pattern':r'^SCENE (?:REPAIR|EXTRA|EXTRA_TOUCH) RENDER: [1-9]\d* assertions, 0 failures$'},folder/'capture.log',root,env);report['process']=result
 data=json.loads((folder/'capture.json').read_text())
 report['outcome']=data['cases'][0]['outcome'];report['screenshots']=data['screenshots']
 assert result['status']=='passed' and data['cases'][0]['outcome']=='route_target_reached' and data['screenshots']
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
