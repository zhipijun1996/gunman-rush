from pathlib import Path
import hashlib,json,subprocess,tarfile
R=Path('/workspace/gunman-rush-design');O=Path(__file__).resolve().parent;OLD='cda8c30ed375a97a53de27d8348a79f137199427'
files=['tools/run_level_design_tests.py','tools/run_tests.py','tests/level_capability_runner.gd','tools/level_capability_snapshot.gd','tests/level_design_trace.gd','tests/plains_region_trace.gd','scripts/builds/build_state.gd','scripts/player/player_tuning.gd','scripts/generation/foundry_catalog.gd','scenes/player/player.tscn']
rows=[]
for p in files:
 a=subprocess.check_output(['git','show',OLD+':'+p],cwd=R);b=(R/p).read_bytes();rows.append({'path':p,'old_sha256':hashlib.sha256(a).hexdigest(),'current_sha256':hashlib.sha256(b).hexdigest(),'byte_identical':a==b})
archive=R/'docs/evidence/forest_playable/final/ci_monitor_cda8c30_failed_remote_evidence.tar.gz'
with tarfile.open(archive) as t:
 m=next(x for x in t if x.name.endswith('/report.json') and x.size>10000000);d=json.load(t.extractfile(m));failure=next(x for x in d['checks'] if x['id']=='level-design-runtime')
 m=t.getmember('ci_monitor_cda8c30/core-full-connector.log');lines=t.extractfile(m).read().decode().splitlines();selected=[]
 for i,line in enumerate(lines):
  if 'run_level_design_tests.py' in line or 'Godot leaked ObjectDB' in line:
   selected.extend(lines[max(0,i-2):i+5])
 (O/'remote-log-excerpt.txt').write_text('\n'.join(selected)+'\n')
with tarfile.open(R/'docs/evidence/forest_playable/final/capability-exit-and-two-lane-failures.tar.gz') as t:
 n='build/forest_playable/ecology/level_capability_exit/ordinary.log';b=t.extractfile(n).read();(O/'old-local-capability.log').write_bytes(b)
receipt={'scope':'Read-only risk audit, no native execution or code edits','current_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),'old_commit':OLD,'old_remote_check':failure,'remote_capability_log_uploaded':False,'local_log_scope':'Historical local same-commit 41/0 plus232ObjectDB/170resources; counts are NOT remote counts','selected_current_source_comparison':rows,'conclusion':'Known strict-exit blocker remains unresolved in this consumer; unrelated Nodehelper fixes do not alter this byte-identical runner or its selected dependencies. Current exact native outcome unverified.'}
(O/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print([(r['path'],r['byte_identical']) for r in rows])
