import copy,hashlib,importlib.util,json,sys,time
from pathlib import Path
ROOT=Path.cwd();F=ROOT/'build/plains_redesign/reward_entry/identity_repair';sys.path.insert(0,str(ROOT/'tools'))
import level_formal as formal,run_plains_encounter_policy_tests as current
spec=importlib.util.spec_from_file_location('rejected22',F/'rejected22_verifier.py');old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
receipt_path=ROOT/'build/verification/plains-encounter/run_e4mp251i/receipt.json';receipt=json.loads(receipt_path.read_text());before=json.loads((F/'source_before.json').read_text())['formal_runtime'];assert formal.source_files()==before
results=[]
for proof in receipt['reward_entry']['runs']:
 p=ROOT/proof['output'];assert formal.file_hash(p)==proof['sha256'];assert proof['source_before']==proof['source_after']==before
 data=json.loads(p.read_text())
 if proof['expected_physical_failure']:
  try:current.validate_reward_entry(data,proof['source_before'])
  except ValueError as e:accepted=False;reason=str(e)
  else:raise AssertionError('physical negative accepted')
  results.append(dict(case=proof['name'],kind='reused_actual_physical_negative',accepted=accepted,reason=reason,path=proof['output'],sha256=proof['sha256']))
 else:
  assert old.validate_reward_entry(data,proof['source_before']);assert current.validate_reward_entry(data,proof['source_before'])
  row=data['cases'][0];results.append(dict(case=proof['name'],kind='reused_actual_positive',accepted=True,path=proof['output'],sha256=proof['sha256'],guard_id=row['guard_id'],guard_declared=any(e['id']==row['guard_id'] for e in row['manifest']['enemies']),tick_count=len(row['frames'])))
proof=next(p for p in receipt['reward_entry']['runs'] if p['name']=='reward_kill0');data=json.loads((ROOT/proof['output']).read_text())
for mode in ['hide_guard_keep_manifest','invent_absent_guard_identity']:
 bad=copy.deepcopy(data);row=bad['cases'][0];row['state']['entry_guard']=[]
 for f in row['frames']:f['reward_guard']=[]
 row['policy_observations']=[o for o in row['policy_observations'] if not(o.get('kind')=='actual_enemy_transition' and o.get('enemy')==row['guard_id'])]
 if mode=='invent_absent_guard_identity':row['guard_id']='plains/enemy/not_the_declared_high_entrance'
 for label,module in [('rejected22',old),('repaired32',current)]:
  try:module.validate_reward_entry(bad,proof['source_before']);accepted=True;reason='accepted'
  except (ValueError,KeyError,TypeError) as e:accepted=False;reason=str(e)
  assert accepted==(mode=='invent_absent_guard_identity' and label=='rejected22')
  results.append(dict(case=mode,validator=label,accepted=accepted,reason=reason))
refusals=current.reward_entry_identity_checks(data,proof['source_before']);assert len(refusals)==10
assert formal.source_files()==before
out=dict(status='passed',command=['python3',str(Path(__file__).relative_to(ROOT))],scope='New Python validator on unchanged, hash-verified real GD outputs; no claim native rerun',basis=str(receipt_path.relative_to(ROOT)),basis_sha256=formal.file_hash(receipt_path),old_validator_sha256=formal.file_hash(F/'rejected22_verifier.py'),new_validator_sha256=formal.file_hash(ROOT/'tools/run_plains_encounter_policy_tests.py'),formal_source_unchanged=True,results=results,identity_refusals=refusals,finished=time.time())
(F/'drill.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print(json.dumps(out,ensure_ascii=False,indent=2))
