import sys,os,pathlib,json,subprocess,hashlib,time
root=pathlib.Path('/workspace/clock-style-lab');sys.path.insert(0,str(root/'tools'));from run_tests import run_engine
import contextlib
out=root/'build/style_exploration/motion';records=[]
for style in ['underworld','cavern']:
 for biome in ['plains','forest','gear']:
  stem=style+'_'+biome;avi=out/(stem+'.avi');report=out/(stem+'.json');log=out/(stem+'.log');start=time.time()
  argv=['--audio-driver','Dummy','--path','.', '--resolution','1280x720','--fixed-fps','60','--write-movie',str(avi),'--script','tools/capture_style_motion.gd','--','--style='+style,'--biome='+biome,'--motion-report='+str(report)]
  try:
   with log.open('w') as stream,contextlib.redirect_stdout(stream),contextlib.redirect_stderr(stream):text=run_engine(argv,180)
   if 'valid=true' not in text:raise RuntimeError('Missing valid motion completion')
   mp4=out/(stem+'.mp4');subprocess.run(['ffmpeg','-y','-v','error','-i',str(avi),'-an','-c:v','libx264','-preset','fast','-crf','24','-pix_fmt','yuv420p','-movflags','+faststart',str(mp4)],check=True)
   probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(mp4)],text=True));(out/(stem+'_ffprobe.json')).write_text(json.dumps(probe,indent=2)+'\n')
   rec={'style':style,'biome':biome,'command':['bash','tools/godot.sh',*argv],'exit_code':0,'source_commit':'32200d04fe233bda16cf50f678aabee51a9715e5','sha256':hashlib.sha256(mp4.read_bytes()).hexdigest(),'bytes':mp4.stat().st_size,'seconds_elapsed':round(time.time()-start,3),'report':str(report),'movie':str(mp4),'audio':'removed silent Dummy-driver track; audio not reviewed'}
   records.append(rec);print('PASS',stem,rec['bytes'],flush=True)
  except Exception as e:
   records.append({'style':style,'biome':biome,'error':str(e),'exit_code':1});(out/'index.json').write_text(json.dumps(records,indent=2)+'\n');raise
  (out/'index.json').write_text(json.dumps(records,indent=2)+'\n')
