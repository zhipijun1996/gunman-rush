import sys,json,copy,importlib.util,hashlib
from pathlib import Path
sys.path.insert(0,'tools');import run_plains_encounter_policy_tests as current
b=Path('build/plains_redesign/reward_entry');source=json.load(open(b/'first_b_sources.json'))['members'];oldpath=b/'first_b_wrapper.py';assert hashlib.sha256(oldpath.read_bytes()).hexdigest()==source['tools/run_plains_encounter_policy_tests.py']
spec=importlib.util.spec_from_file_location('actual_B21',oldpath);old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
p=Path('build/verification/plains-encounter/run_zsxcavxt/reward_kill0.json');honest=json.load(open(p));sources=json.load(open(p.with_suffix('.receipt.json')))['source_before'];bad=copy.deepcopy(honest);row=bad['cases'][0];row['state']['entry_guard']=[]
for frame in row['frames']:frame['reward_guard']=[]
row['policy_observations']=[o for o in row['policy_observations'] if not(o.get('enemy')==row['guard_id'] and o.get('kind')=='actual_enemy_transition')]
def accepts(module,data):
 try:module.validate_reward_entry(data,sources);return True
 except (ValueError,KeyError,TypeError):return False
result={'scope':'same existing declared-guard erasure finding, additionally exercised on actual kill trajectory; no newcontent or claimed simulation','original_capture':str(p),'original_capture_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'old_checker_sha256':hashlib.sha256(oldpath.read_bytes()).hexdigest(),'new_checker_sha256':hashlib.sha256(Path('tools/run_plains_encounter_policy_tests.py').read_bytes()).hexdigest(),'honest_old':accepts(old,honest),'honest_new':accepts(current,honest),'coherent_body_and_transition_erasure_old':accepts(old,bad),'coherent_body_and_transition_erasure_new':accepts(current,bad),'note':'Earlier transition causality already rejects erasing body frames alone; the coherent gap also removes matching guard transition observations. Damage/projectile/resource receipts stay unchanged.'}
assert result['honest_old'] and result['honest_new'] and result['coherent_body_and_transition_erasure_old'] and not result['coherent_body_and_transition_erasure_new'];(b/'declared_guard_drill.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
