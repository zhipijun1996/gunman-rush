from pathlib import Path
import subprocess,sys,types,runpy,hashlib,json,contextlib
from unittest.mock import patch
R=Path('/workspace/gunman-rush-design');O=Path(__file__).resolve().parent
C='5e61afa6233018125ef0fb1d23129d7bc9522f9c'
source=subprocess.check_output(['git','show',C+':tools/harness.py']).decode();(O/'original-C-harness.py.txt').write_text(source)
old=types.ModuleType('old_harness_C');old.__file__=str(R/'tools/harness.py');exec(compile(source,old.__file__,'exec'),old.__dict__)
tests=runpy.run_path(str(R/'tests/test_harness.py'));case=tests['HarnessLaneTests']('test_real_phases_and_merge_cover_complete_dirty_prepared_source');case.setUp();new=tests['h']
try:
 with (O/'negative-actual.log').open('w') as log,contextlib.redirect_stdout(log):paths=case.phases()
 metadata=new.git_metadata();inventory=new.source_inventory();proof_sha=hashlib.sha256(paths[0].read_bytes()).hexdigest();saved=case.root/'build/outside-proof-dir';paths[0].parent.rename(saved);paths[0].parent.symlink_to(saved,target_is_directory=True)
 with patch.object(old,'ROOT',case.root),patch.object(old,'MANIFEST',case.manifest):
  previous=old.verify_lane_reports(case.data,['gameplay','art'],paths,metadata,inventory)
 try:new.verify_lane_reports(case.data,['gameplay','art'],paths,metadata,inventory)
 except ValueError as error:rejected=True;message=str(error)
 else:rejected=False;message=None
 result={'scope':'Exact original ancestor-directory symlink attack, actual tiny Python phase checks; no engine/browser.','old_commit':C,'old_validator_sha256':hashlib.sha256(source.encode()).hexdigest(),'new_validator_sha256':hashlib.sha256((R/'tools/harness.py').read_bytes()).hexdigest(),'old_accepted':len(previous['checks'])==2,'new_rejected':rejected,'new_error':message,'report_path':str(paths[0]),'realpath':str(paths[0].resolve()),'original_report_sha256':proof_sha,'unchanged_report_bytes':proof_sha==hashlib.sha256(paths[0].read_bytes()).hexdigest(),'unchanged_git_metadata':metadata==new.git_metadata(),'unchanged_full_source_inventory':inventory==new.source_inventory(),'original_independent_negative':json.loads((R/'build/forest_depth/review/ci_lanes01/negative-probe.json').read_text())}
 assert result['old_accepted'] and result['new_rejected'] and result['unchanged_report_bytes'] and result['unchanged_git_metadata'] and result['unchanged_full_source_inventory']
 (O/'original-negative-replay.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
finally:case.doCleanups()
