import json,sys,subprocess,time,hashlib
from pathlib import Path
ROOT=Path.cwd();F=ROOT/'build/plains_redesign/reward_entry/identity_repair';sys.path.insert(0,str(ROOT/'tools'));import level_formal as formal
checks=[('encounter',['python3','tools/run_plains_encounter_policy_tests.py'],600),('formal_receipts',['python3','tools/test_level_formal_receipts.py'],180),('level_experience',['python3','tools/test_level_experience.py'],180)]
for name,cmd,timeout in checks:
 before=formal.source_files();verifier=formal.file_hash(ROOT/'tools/run_plains_encounter_policy_tests.py');started=time.time()
 with (F/(name+'.log')).open('w') as log:p=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=timeout,cwd=ROOT)
 after=formal.source_files();entry=dict(command=cmd,exit_code=p.returncode,started=started,ended=time.time(),duration_seconds=time.time()-started,source_before=before,source_after=after,verifier_sha256=verifier,log=str((F/(name+'.log')).relative_to(ROOT)),log_sha256=formal.file_hash(F/(name+'.log')),scope='Fresh affected Python specialty/protocol. Unchanged native gameplay source remains same as R1; no rerun claim for unrelated15/20/64.')
 (F/(name+'.receipt.json')).write_text(json.dumps(entry,ensure_ascii=False,indent=2)+'\n');print(name,p.returncode,round(entry['duration_seconds'],2),flush=True)
 assert p.returncode==0 and before==after and formal.file_hash(ROOT/'tools/run_plains_encounter_policy_tests.py')==verifier,name
