import json,sys,time,subprocess,re,concurrent.futures
from pathlib import Path
sys.path.insert(0,'tools');import level_formal as f
base=Path('build/plains_redesign/reward_entry/final_checks_b');base.mkdir(parents=True,exist_ok=True)
def sources():
 return f.source_files()|{p:f.file_hash(Path(p)) for p in ['tools/run_plains_encounter_policy_tests.py','tools/run_plains_redesign_golden_tests.py','tools/run_plains_redesign_spatial_tests.py','tools/run_plains_experience_golden_tests.py','tools/harness/profiles.json']}
before=sources()
def run(spec):
 name,file=spec;command=['python3',file];start=time.time();log=base/(name+'.log')
 with log.open('w') as stream:r=subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT)
 result={'command':command,'started':start,'ended':time.time(),'exit_code':r.returncode,'source_before':before,'source_after':sources(),'script_error':bool(re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script',log.read_text()))}
 result['status']='passed' if r.returncode==0 and result['source_before']==result['source_after'] and not result['script_error'] else 'failed';(base/(name+'.receipt.json')).write_text(json.dumps(result,indent=2));print(name,result['status'],r.returncode,flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:list(pool.map(run,[('encounter','tools/run_plains_encounter_policy_tests.py'),('region15','tools/run_plains_region_tests.py'),('spatial','tools/run_plains_redesign_spatial_tests.py'),('experience','tools/run_plains_experience_golden_tests.py'),('old64','tools/run_plains_redesign_golden_tests.py'),('formal_receipts','tests/test_level_formal_receipts.py'),('experience_protocol','tests/test_level_experience.py')]))
