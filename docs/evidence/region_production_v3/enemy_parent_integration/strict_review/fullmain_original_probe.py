"""ROOT final repair independently exercised; explicit synthetic subprocess transport, no native."""
import contextlib,copy,io,json,pathlib,sys,time,types
from unittest.mock import patch
ROOT=pathlib.Path('/workspace/gunman-rush');CHILD=pathlib.Path('/workspace/gunman-v3-enemy');sys.path.insert(0,str(ROOT/'tools'));import run_root_bell_formal as rf
out=ROOT/'build/region_production_v3/independent/enemy_evidence_repair_root_r2';candidate=json.loads((CHILD/'build/region_production_v3/independent/enemy_evidence_repair/missing_real_hit_grant_coherent_replay.json').read_text());folder=ROOT/'build/root_bell/INDEPENDENT_FINAL_REPAIR_MISSING_HIT_NOT_NATIVE';old_run=rf.subprocess.run
assert not folder.exists()
def fake_run(command,*args,**kwargs):
 if command[:2]==['bash','tools/godot.sh']:
  path=ROOT/next(a for a in command if a.startswith('--output=res://')).removeprefix('--output=res://');path.write_text(json.dumps(candidate)+'\n');kwargs['stdout'].write('INDEPENDENT SYNTHETIC PROCESS TRANSPORT ONLY — NOT NATIVE\nLEVEL FORMAL CAPTURE: 5145 frames, 6 edges, outcome=route_target_reached, capture_errors=0\n');kwargs['stdout'].flush();return types.SimpleNamespace(returncode=0)
 return old_run(command,*args,**kwargs)
try:
 with patch.object(sys,'argv',['run_root_bell_formal.py','--output-dir',str(folder.relative_to(ROOT))]),patch.object(rf.subprocess,'run',side_effect=fake_run),contextlib.redirect_stdout(io.StringIO()):rf.main()
 r={'accepted':True}
except Exception as e:r={'accepted':False,'error':str(e)}
if (folder/'report.json').exists():
 report=json.loads((folder/'report.json').read_text());report.update(scope='INDEPENDENT SYNTHETIC PROCESS TRANSPORT ONLY — NOT NATIVE',independent_simulation=True);(folder/'report.json').write_text(json.dumps(report,indent=2)+'\n')
r.update(consumer_sha256=rf.sha(pathlib.Path(rf.__file__)),original_bad_capture_sha256=rf.sha(CHILD/'build/region_production_v3/independent/enemy_evidence_repair/missing_real_hit_grant_coherent_replay.json'),scope='Full actual Python main; explicitly synthetic process transport, not engine evidence');(out/'fullmain_original_missing_hit_results.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
