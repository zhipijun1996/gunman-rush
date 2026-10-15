import sys,json,time
from pathlib import Path
sys.path.insert(0,'tools');import harness,level_formal as f
base=Path('build/plains_redesign/reward_entry');profile=json.load(open('tools/harness/profiles.json'))['checks']['plains-encounter-policy'] if 'checks' in json.load(open('tools/harness/profiles.json')) else None
if profile is None:raise ValueError('unknown original profile')
before=f.source_files()|{p:f.file_hash(Path(p)) for p in ['tools/run_plains_encounter_policy_tests.py','tools/level_experience.py','tools/harness/profiles.json']};start=time.time()
r=harness.run_check(profile,(base/'final_checks_b/encounter_final.log').resolve(),f.ROOT)
after=f.source_files()|{p:f.file_hash(Path(p)) for p in ['tools/run_plains_encounter_policy_tests.py','tools/level_experience.py','tools/harness/profiles.json']};r.update(source_before=before,source_after=after,start_epoch=start,end_epoch=time.time());assert before==after
(base/'final_checks_b/encounter_final.receipt.json').write_text(json.dumps(r,indent=2));print(json.dumps({k:v for k,v in r.items() if k not in ['source_before','source_after']},indent=2));raise SystemExit(0 if r['status']=='passed' else 1)
