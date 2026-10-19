"""One-shot recorded host of existing strict engine/lock, actual preview only."""
import sys, os, json, re, time, hashlib, subprocess, selectors, fcntl
from pathlib import Path
ROOT=Path('/workspace/art-direction-exploration');sys.path.insert(0,str(ROOT/'tools'))
from level_formal import source_files
from run_plains_joint_recoil_tests import logged_engine
from run_root_bell_ecology import godot_lock_path, xvfb_binary, native_runtime_failed
folder=Path('/tmp/plains_art_language/render_02');folder.mkdir(exist_ok=False)
extra=('tools/plains_art_language_preview.gd','tools/plains_regional_art_preview.gd','tools/spatial_golden_preview.gd','tools/observed_audio_teardown.gd','tools/run_tests.py','tools/run_plains_joint_recoil_tests.py','tools/run_root_bell_ecology.py')
report={'status':'failed','scope':'Actual new-profile DemoApp startup, normal spawn PNG and changed-camera debug world overview; no actual route, new family artwork, hearing, device or art admission','producer_path':__file__,'producer_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'runs':[]}
started=time.monotonic();display=None;display_log=None
os.environ.update(LP_NUM_THREADS='1',LIBGL_ALWAYS_SOFTWARE='1',REGIONAL_SOURCE_COMMIT=report['source_commit'])
try:
 with godot_lock_path(ROOT).open('a') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX);report['source_before']=source_files(extra)
  command=['--headless','--audio-driver','Dummy','--path','.','--script','tools/plains_art_language_preview.gd','--','--seed=joint-recoil-01','--smoke-close']
  t=time.monotonic();out=logged_engine(command,120,folder/'smoke.log')
  if native_runtime_failed(0,out) or 'PLAINS REGIONAL ART REVIEW READY:' not in out or 'PLAINS REGIONAL ART AVATAR READY:' not in out:raise RuntimeError('Strict actual preview startup failed')
  report['smoke']={'command':['bash','tools/godot.sh',*command],'seconds':time.monotonic()-t,'status':'passed','audio_driver':'Dummy; not heard'}
  display_log=(folder/'display.log').open('wb');display=subprocess.Popen([xvfb_binary(ROOT),'-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=display_log)
  with selectors.DefaultSelector() as ready:
   ready.register(display.stdout,selectors.EVENT_READ)
   if not ready.select(20):raise RuntimeError('Xvfb readiness timeout')
   number=display.stdout.readline().decode().strip()
   if not number.isdigit():raise RuntimeError('Invalid Xvfb display')
   os.environ['DISPLAY']=':'+number
  report['render_environment']={k:os.environ[k] for k in ['LP_NUM_THREADS','LIBGL_ALWAYS_SOFTWARE','DISPLAY']}
  for seed in ['joint-recoil-01','joint-recoil-07']:
   images=folder/seed
   command=['--rendering-method','gl_compatibility','--audio-driver','Dummy','--path','.','--script','tools/plains_art_language_preview.gd','--','--seed='+seed,'--capture-output='+str(images)]
   t=time.monotonic();out=logged_engine(command,180,folder/(seed+'.log'))
   if native_runtime_failed(0,out) or 'PLAINS ART LANGUAGE RENDER: 0 0' not in out:raise RuntimeError('Actual rendered preview failed for '+seed)
   receipt=json.loads((images/'receipt.json').read_text())
   for field in ['normal_start','overview']:
    p=Path(receipt[field]['path'])
    if receipt[field]['error']!=0 or hashlib.sha256(p.read_bytes()).hexdigest()!=receipt[field]['sha256']:raise RuntimeError('Missing or changed PNG')
   report['runs'].append({'seed':seed,'command':['bash','tools/godot.sh',*command],'status':'passed','seconds':time.monotonic()-t,'receipt':str(images/'receipt.json')})
  report['source_after']=source_files(extra)
  if report['source_before']!=report['source_after']:raise RuntimeError('Source drift during actual preview')
  report['status']='passed'
except Exception as exc:
 report['error']=str(exc);raise
finally:
 if display is not None:display.terminate();display.wait(timeout=10);display.stdout.close()
 if display_log is not None:display_log.close()
 report['source_after']=source_files(extra);report['elapsed_seconds']=time.monotonic()-started
 (folder/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(folder/'report.json')
