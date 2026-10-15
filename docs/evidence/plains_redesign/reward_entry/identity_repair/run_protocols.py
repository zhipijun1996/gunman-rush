import json,subprocess,sys,time
from pathlib import Path
ROOT=Path.cwd();F=ROOT/'build/plains_redesign/reward_entry/identity_repair';sys.path.insert(0,str(ROOT/'tools'));import level_formal as formal
for name,pattern in [('formal_receipts','test_level_formal_receipts.py'),('level_experience','test_level_experience.py')]:
 before=formal.source_files();verifier=formal.file_hash(ROOT/'tools/run_plains_encounter_policy_tests.py');cmd=['python3','-m','unittest','discover','-s','tests','-p',pattern];started=time.time()
 with (F/(name+'.discovery.log')).open('w') as log:p=subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=120)
 result=dict(command=cmd,exit_code=p.returncode,started=started,ended=time.time(),duration_seconds=time.time()-started,source_before=before,source_after=formal.source_files(),verifier_sha256=verifier,log=str((F/(name+'.discovery.log')).relative_to(ROOT)),log_sha256=formal.file_hash(F/(name+'.discovery.log')))
 (F/(name+'.discovery.receipt.json')).write_text(json.dumps(result,indent=2)+'\n');assert p.returncode==0 and result['source_before']==result['source_after'];print(name,p.returncode,flush=True)
