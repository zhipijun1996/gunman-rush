from pathlib import Path
import json,time,hashlib
r=Path('/workspace/gunman-rush');b=r/'build/plains_redesign/reward_entry';p=b/'candidate_b_return'
for name in ['canonical_kill','canonical_bypass','worst_return_charger']:
 d=json.load(open(p/'build/candidate_b'/name/'capture.json'));assert d['route_reached'] and min(f['health'] for f in d['frames'])==5 and any(o['kind']=='actual_cache_claim' and o['claimed'] for o in d['policy_observations'])
path=r/'scripts/generation/plains_region_generator.gd';path.write_bytes((p/'scripts/generation/plains_region_generator.gd').read_bytes())
(b/'promotion_b.json').write_text(json.dumps({'time':time.time(),'candidate':2,'name':'shared_entry_and_real_return_observation_banks','golden_before_default':True,'cases':3,'generator_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'preserved_failure':'behavior_entries/charger/capture.json; firstA fullsource andbothactualstrongregressions preserved','scope':'same-budget positional authoring using actualreturnpolyline, notDriverfix orfunapproval'},indent=2))
