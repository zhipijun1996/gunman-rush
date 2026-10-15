import sys,json,copy,hashlib,time
from pathlib import Path
R=Path.cwd();O=R/'build/plains_redesign/review_reward_entry';sys.path.insert(0,str(R/'tools'))
import production_loop as loop,level_formal as formal,run_plains_encounter_policy_tests as test
req=json.loads((R/'build/verification/plains-redesign-reward-entry/PLAINS-REWARD-ENTRY-01/1/review/host_request.json').read_text());assert loop.digest(loop.snapshot())==req['source_hash'];assert loop.digest({k:v for k,v in req.items() if k!='request_hash'})==req['request_hash'];assert time.time()<req['expires_at'];(O/'request.json').write_text(json.dumps(req,ensure_ascii=False,indent=2))
receiptpath=R/'build/verification/plains-encounter/run_e4mp251i/receipt.json';receipt=json.loads(receiptpath.read_text());runs=receipt['reward_entry']['runs'];print('SOURCE',req['source_hash'],'runs',len(runs))
proof=next(r for r in runs if r['name']=='reward_kill0');data=json.loads((R/proof['output']).read_text());test.validate_reward_entry(data,proof['source_before']);results=[{'case':'actual_untouched_kill','accepted':True}]
for mode in ['hide_guard_keep_manifest','invent_absent_guard_identity']:
 bad=copy.deepcopy(data);row=bad['cases'][0];row['state']['entry_guard']=[]
 for f in row['frames']:f['reward_guard']=[]
 row['policy_observations']=[o for o in row['policy_observations'] if not(o.get('kind')=='actual_enemy_transition' and o.get('enemy')==row['guard_id'])]
 if mode=='invent_absent_guard_identity':row['guard_id']='plains/enemy/not_the_declared_high_entrance'
 try:test.validate_reward_entry(bad,proof['source_before']);accepted=True;reason='accepted'
 except (ValueError,KeyError,TypeError) as error:accepted=False;reason=str(error)
 results.append(dict(case=mode,accepted=accepted,reason=reason))
(O/'guard_identity_probe.json').write_text(json.dumps(dict(source=proof['output'],source_sha256=hashlib.sha256((R/proof['output']).read_bytes()).hexdigest(),results=results),indent=2));print(json.dumps(results))
