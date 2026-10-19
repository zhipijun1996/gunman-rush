"""Read-only terminal S2 failure + bounded driver candidate custody. Excludes live80."""
from pathlib import Path
import json,hashlib,zipfile,subprocess,re
R=Path.cwd();B=R/'build/forest_grapple02/ci_s2';O=B/'release02_skeleton';S=lambda raw:hashlib.sha256(raw).hexdigest();data={};provenance=[]
def add(p,name=None):
 raw=p.read_bytes();name=name or str(p.relative_to(R));assert not p.is_symlink()
 if re.search(rb'[?&](?:sig|X-Amz-Signature)=|gh[pousr]_[A-Za-z0-9]{20}|(?i:authorization)["\s:]+(?i:bearer)\s+[A-Za-z0-9]',raw):raise ValueError('Signed/token original needs explicit derivative: '+name)
 data[name]=raw;provenance.append({'member':name,'source_path':str(p),'bytes':len(raw),'sha256':S(raw)})
for p in sorted((B/'failure02').glob('*.json')):add(p)
for folder in ['reproduce_seed04_growth01','reproduce_seed04_growth_highlaunch01','high_launch_candidate01']:
 base=B/folder
 for p in sorted(base.rglob('*')):
  if any(s in {'cache','user-data','import-user','import-cache','import-config','.godot'} for s in p.relative_to(base).parts):continue
  if p.is_file() and p.suffix in {'.json','.log','.gd','.txt','.sha256'}:add(p)
old=json.loads((B/'reproduce_seed04_growth01/receipt.json').read_text());new=json.loads((B/'reproduce_seed04_growth_highlaunch01/receipt.json').read_text());assert old['status']=='failed' and new['status']=='passed' and old['source_stable'] and new['source_stable']
trace='tests/forest_depth_region_trace.gd';current=(R/trace).read_bytes();assert S(current)==new['source_before'][trace]
data['candidate-source/forest_depth_region_trace.gd']=current
s2raw=subprocess.check_output(['git','show','6adc5ff30515d7adaf598d5bbba0268d42af44f4:'+trace]);assert S(s2raw)==old['source_before'][trace] and s2raw==(B/'high_launch_candidate01/before_trace.gd.txt').read_bytes()
data['S2-committed-source/forest_depth_region_trace.gd']=s2raw
for folder in ['reproduce_seed04_growth01','reproduce_seed04_growth_highlaunch01']:
 receipt=json.loads((B/folder/'receipt.json').read_text());case=receipt['runs'][0];p=Path(next(x.split('=',1)[1] for x in case['argv'] if x.startswith('--output=')));assert S(p.read_bytes())==case['capture_sha256'] and S((p.parent/'native.log').read_bytes())==case['log_sha256']
noR=json.loads((B/'high_launch_candidate01/noR_receipt.json').read_text());assert noR['source_stable'] and noR['native_exit']==0 and S((B/'high_launch_candidate01/noR_runner.gd').read_bytes())==noR['runner_sha'];nr=json.loads((B/'high_launch_candidate01/noR_capture.json').read_text());assert nr['reached'] and not nr['position_or_resource_injection'] and not nr['manual_motor_step']
cp=R/'build/verification/publish-playtest/6adc5ff30515d7adaf598d5bbba0268d42af44f4/checkpoint.json';raw=cp.read_bytes();p=json.loads(raw);assert p['phase']=='ci_failed' and p['ci_conclusion']=='failure' and not p['live_verified']
safe={k:p.get(k) for k in ['schema','repo','ref','commit','run_id','attempt','phase','ci_status','ci_conclusion','live_verified','deployment_jobs']};safe['custody']={'original_private_path':str(cp.relative_to(R)),'original_sha256':S(raw),'original_bytes':len(raw),'derivation':'Allowlisted terminal identity/state fields only; no signed redirects, credentials, event payloads or last_error contents retained'}
data['derived/publisher-terminal-identity-redacted.json']=json.dumps(safe,indent=2).encode()
scopes=['scripts','scenes','resources','config','assets','project.godot','export_presets.cfg'];diff=subprocess.check_output(['git','diff','--name-only','6adc5ff30515d7adaf598d5bbba0268d42af44f4','--',*scopes]);assert not diff
notes={'scope':'Actual terminal S2CI failure and two bounded local driver comparisons, not S3/full80 approval','source_S2':'6adc5ff30515d7adaf598d5bbba0268d42af44f4','selected_run':39200142616,'parallel_job':117891990565,'CI_failure':'forest-depth-region original80 case33 root04/map1/growth; APIannotation only, remote phase artifact403/no downloaded raw','original_driver_sha256':S(s2raw),'candidate_driver_sha256':S(current),'candidate_native_scope':'one root04/map1/growth strictPASS with changed test driver; old clean replay FAIL retained','noR_counterfactual':'actual fullJ->H reaches same crown without R; RH cannot be called R-required. R may be quicker optional. Not whole80/corpus proof.','production_scopes_unchanged_S2':True,'ordinary_download':'one normal gh artifact attempt403, sanitized receipt retained; no retry/bypass','future_full80':'ongoing or not evaluated by this archive; no live80 output collected','publisher':'ci_failed/live_verifiedfalse, deploy/publicskipped, no new release','provenance':provenance};data['derived/failure-candidate-custody.json']=json.dumps(notes,indent=2).encode();(O/'s2-failure-candidate-custody.json').write_bytes(data['derived/failure-candidate-custody.json'])
rows=[{'member':n,'sha256':S(raw),'bytes':len(raw)} for n,raw in sorted(data.items())];inside=json.dumps({'scope':notes['scope'],'members':rows},indent=2).encode();zp=O/'s2-failure-candidates02.zip'
with zipfile.ZipFile(zp,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for n,raw in sorted(data.items()):z.writestr(n,raw)
 z.writestr('ARCHIVE-INVENTORY.json',inside)
with zipfile.ZipFile(zp) as z:
 assert len(z.namelist())==len(set(z.namelist()))==len(rows)+1
 for row in rows:assert S(z.read(row['member']))==row['sha256']
inv={'scope':notes['scope'],'archive_sha256':S(zp.read_bytes()),'archive_bytes':zp.stat().st_size,'archive_member_count':len(rows)+1,'members':rows,'inside_inventory_sha256':S(inside),'full_readback_verified':True};(O/'s2-failure-candidates-index02.json').write_text(json.dumps(inv,indent=2)+'\n');print(json.dumps({k:v for k,v in inv.items() if k!='members'}))
