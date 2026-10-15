from pathlib import Path
import json,sys,time
r=Path('/workspace/gunman-rush');b=r/'build/plains_redesign/reward_entry';p=b/'candidate_a';proof=p/'build/reward_entry_toolchain_corrected'
for policy in ['kill_from_bank_v1','bait_then_bypass_v1']:
 for phase in [0,100]:
  d=json.loads((proof/(policy+'_'+str(phase))/'capture.json').read_text());assert d['route_reached'] and not d['capture_errors']
  assert any(o['kind']=='actual_cache_claim' and o['chest'].endswith('/high') and o['claimed'] for o in d['policy_observations'])
  assert min(f['health'] for f in d['frames'])==5
  if policy.startswith('bait'):
   guard=next(e for e in d['final_runtime']['enemies'] if e['id']=='plains/enemy/area_0_0');assert guard['health']==3 and not guard['terminal']
source=p/'scripts/generation/plains_region_generator.gd';target=r/'scripts/generation/plains_region_generator.gd';target.write_bytes(source.read_bytes())
(b/'promotion.json').write_text(json.dumps({'time':time.time(),'candidate':'A','golden_before_default':True,'cases':4,'scope':'same normal-spawn formal driver and exact candidate generator bytes; not art/fun/device admission','generator_sha256':__import__('hashlib').sha256(source.read_bytes()).hexdigest()},indent=2))
