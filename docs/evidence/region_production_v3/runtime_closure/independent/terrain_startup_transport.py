import sys,os,json,importlib.util,tempfile,contextlib,io
from pathlib import Path
from unittest.mock import patch
root=Path('/workspace/gunman-rush');sys.path.insert(0,str(root/'tools'));spec=importlib.util.spec_from_file_location('terrain',root/'tools/run_plains_terrain_family_tests.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
results={}
for label,custom in [('default_resolver',None),('explicit_local_wrapper','/synthetic/optional-wrapper')]:
 with tempfile.TemporaryDirectory() as folder:
  tmp=Path(folder);called=[]
  def stop(command,**kwargs):
   called.append({'command':command,'cwd':str(kwargs['cwd']),'GODOT_BIN':kwargs['env'].get('GODOT_BIN'),'LP_NUM_THREADS':kwargs['env'].get('LP_NUM_THREADS')});raise RuntimeError('SYNTHETIC TRANSPORT STOP BEFORE ENGINE')
  env=os.environ.copy();env.pop('GODOT_BIN',None)
  if custom:env['GODOT_BIN']=custom
  with patch.object(m,'ROOT',tmp),patch.dict(os.environ,env,clear=True),patch.object(m.subprocess,'run',side_effect=stop),patch.object(sys,'argv',['runner','--all-maps']),contextlib.redirect_stdout(io.StringIO()):code=m.main()
  assert len(called)==1 and called[0]['command']==['bash','tools/godot.sh','--headless','--editor','--path','.','--import']
  assert called[0]['GODOT_BIN']==custom and called[0]['LP_NUM_THREADS']=='1'
  results[label]={'scope':'SYNTHETIC process transport only; entry observed then intentionally stopped; no native executed','returned':code,'first_call':called[0]}
(root/'build/region_production_v3/independent/runtime_closure_review/terrain_startup_transport.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(results))
