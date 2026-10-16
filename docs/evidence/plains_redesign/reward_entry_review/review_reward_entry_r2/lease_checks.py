"""Final exact-lease verification; reuses independently executed preparation."""
import sys,json,re,time,hashlib
from pathlib import Path
R=Path.cwd();O=R/'build/plains_redesign/review_reward_entry_r2';sys.path.insert(0,str(R/'tools'))
import production_loop as loop,level_formal as f
req=json.loads((O/'request.json').read_text());prep=json.loads((O/'preparation_provenance.json').read_text());assert time.time()<req['expires_at'];assert loop.digest(loop.snapshot())==req['source_hash'];assert prep['verifier_sha256']==f.file_hash(R/'tools/run_plains_encounter_policy_tests.py');assert prep['portable_index_sha256']==f.file_hash(R/'docs/evidence/plains_redesign/reward_entry/index.json');assert prep['receipt_sha256']==f.file_hash(R/prep['receipt'])
folder=R/'build/verification/plains-redesign-reward-entry/PLAINS-REWARD-ENTRY-01/2';logs=[]
feedback=json.loads(req['feedback']);assert len(feedback['checks'])==9 and all(x['status']=='passed' and x['exit_code']==0 for x in feedback['checks'])
for check in feedback['checks']:
 p=folder/(check['id']+'.log');logs.append(dict(id=check['id'],status=check['status'],exit_code=check['exit_code'],path=str(p.relative_to(R)),sha256=f.file_hash(p),log=p.read_text()))
freshpath=R/'build/verification/plains-encounter/run_cr_0wy4_/receipt.json';fresh=json.loads(freshpath.read_text());assert fresh['source_before']==fresh['source_after']==f.source_files();assert len(fresh['reward_entry']['validator_refusals'])==32
for p,h in fresh['verifier_sources'].items():assert f.file_hash(R/p)==h
native=[]
for p in fresh['reward_entry']['runs']:
 assert f.file_hash(R/p['output'])==p['sha256'] and f.file_hash(R/p['log'])==p['log_sha256'];assert p['source_before']==p['source_after']==fresh['source_before'];d=json.loads((R/p['output']).read_text());row=d['cases'][0];neg=p['expected_physical_failure'];assert p['exit_code']==(1 if neg else 0);assert (d['failures']>0)==bool(neg)
 if not neg:assert row['claimed'] and row['state']['camp'] and min(x['health'] for x in row['frames'])==5
 else:assert min(x['health'] for x in row['frames'])==4 and row['claimed']==(neg=='return')
 native.append(dict(name=p['name'],output=p['output'],sha256=p['sha256'],log_sha256=p['log_sha256'],exit_code=p['exit_code'],negative=neg,frames=len(row['frames']),claimed=row['claimed']))
assert sum(not x['negative'] for x in native)==11 and sum(bool(x['negative']) for x in native)==3
for run in fresh['runs']:
 assert f.file_hash(R/run['output'])==run['sha256'] and f.file_hash(R/run['log'])==run['log_sha256'];assert run['process']['exit_code']==0
# Other original fresh specialty receipts bind current content/GD inventory.
others=[]
for p in ['build/plains_redesign/golden/run_cm6fsjbo/receipt.json','build/plains_redesign/experience/run_iahvte9a/receipt.json','build/plains_redesign/spatial/run_ecf7v0j4/receipt.json']:
 d=json.loads((R/p).read_text());row=dict(path=p,sha256=f.file_hash(R/p),keys=list(d))
 if 'source_before' in d:assert d['source_before']==d['source_after'];row['source_before_after_equal']=True
 others.append(row)
(O/'fresh_checks.json').write_text(json.dumps(logs,indent=2));(O/'fresh_native_binding.json').write_text(json.dumps(dict(receipt=str(freshpath.relative_to(R)),sha256=f.file_hash(freshpath),source_count=len(fresh['source_before']),verifier_sources=fresh['verifier_sources'],reward_runs=native,causal_refusals=fresh['reward_entry']['validator_refusals'],other_specialties=others,scope='Actual controller fresh processes source/hash verified and explicitly reused; reviewer did not rerun Godot.'),indent=2))
print('LEASE CHECKS PASS source',req['source_hash'],'fresh9 passed; native11/3/32 source684 same; preparation bytes same')
