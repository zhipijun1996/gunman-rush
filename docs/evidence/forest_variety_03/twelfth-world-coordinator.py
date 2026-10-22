from pathlib import Path
import sys,json,time,contextlib,subprocess,hashlib,zipfile
ROOT=Path('/workspace/gunman-rush');sys.path.insert(0,str(ROOT/'tools'))
from run_tests import run_engine
from forest_bible_world_sources import inventory
out=Path('/tmp/gunman-forest-variety-03/round12');out.mkdir(parents=True,exist_ok=False)
link=ROOT/'build/region_bible_v2/forest-variety-03-round12';link.symlink_to(out,target_is_directory=True)
r={'scope':'strict_real_contour_guard_expected_to_reject_current_fixed_annex','import_cap':90,'native_cap':240,'exit_code':1};start=time.monotonic();before=None
try:
 with (out/'prepare-import.log').open('w') as log,contextlib.redirect_stdout(log):run_engine(['--headless','--path','.','--editor','--quit'],90)
 before=inventory();(out/'source-before.json').write_text(json.dumps(before,sort_keys=True));r['source_paths']=len(before)
 blobs={}
 for row in subprocess.check_output(['git','ls-tree','-r','-z','HEAD'],cwd=ROOT).split(b'\0'):
  if row:
   meta,path=row.split(b'\t',1);blobs[path.decode()]=meta.split()[2].decode()
 changed=[]
 with zipfile.ZipFile(out/'changed-source.zip','x',zipfile.ZIP_DEFLATED) as z:
  for path,sha in before.items():
   data=(ROOT/path).read_bytes();assert hashlib.sha256(data).hexdigest()==sha
   if blobs.get(path)!=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest():z.writestr(path,data);changed.append(path)
 (out/'source-closure.json').write_text(json.dumps({'baseline_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_paths':len(before),'changed_paths':changed,'complete_inventory':'source-before.json','changed_bytes':'changed-source.zip','unchanged':'exact baseline Git blob equality'},indent=2))
 git_before=subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all'],cwd=ROOT);r['git_head']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 cases=[('world','tests/forest_varied_world_runner.gd',['--output=res://build/region_bible_v2/forest-variety-03-round12/world.json'])]
 results=[]
 for name,script,args in cases:
  try:
   with (out/(name+'.log')).open('w') as log,contextlib.redirect_stdout(log):text=run_engine(['--headless','--fixed-fps','60','--path','.','--script',script,'--',*args],240)
   results.append({'name':name,'passed':'FOREST VARIED WORLD:' in text and '0 failures' in text if name=='world' else 'FOREST EXPANDED MENU:' in text and '0 failures' in text if name=='menu' else ('FOREST VARIED FIXTURE: PASS' in text or 'FOREST VARIED MOTOR: PASS' in text)})
  except Exception as e:results.append({'name':name,'passed':False,'error':str(e)})
  print(json.dumps(results[-1]),flush=True)
 r['cases']=results;r['source_stable']=inventory()==before;r['git_stable']=git_before==subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all'],cwd=ROOT)
 r['exit_code']=0 if all(x['passed'] for x in results) and r['source_stable'] and r['git_stable'] else 1
except Exception as e:r['error']=str(e)
finally:
 if before is not None:(out/'source-after.json').write_text(json.dumps(inventory(),sort_keys=True))
 r['seconds']=time.monotonic()-start;(out/'receipt.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r),flush=True)

sys.exit(r["exit_code"])
