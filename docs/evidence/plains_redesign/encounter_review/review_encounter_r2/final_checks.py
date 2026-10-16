import sys,json,copy,hashlib,subprocess,time
from pathlib import Path
R=Path.cwd();O=R/'build/plains_redesign/review_encounter_r2';sys.path.insert(0,str(R/'tools'))
import level_experience as e,production_loop as loop
H=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
# Actual fresh capture causal adjacency corruption, not native-physics evidence.
c=json.loads((R/'build/verification/plains-encounter/run_j8vy1m2q/after/case_2/capture.json').read_text());results=[]
consume=next(i for i,r in enumerate(c['resource_receipts']) if r['operation']=='consume');refund=next(i for i,r in enumerate(c['resource_receipts']) if r['event_id'].startswith('hit/'))
for name,index,key,value in [('shot_tick',consume,'tick',c['resource_receipts'][consume]['tick']+1),('shot_session',consume,'session_id',999),('shot_epoch',consume,'epoch',999),('shot_status',consume,'status',1),('refund_tick',refund,'tick',c['resource_receipts'][refund]['tick']-1),('refund_session',refund,'session_id',999),('refund_epoch',refund,'epoch',999),('refund_status',refund,'status',1)]:
 bad=copy.deepcopy(c);bad['resource_receipts'][index][key]=value
 try:e.validate_capture(bad)
 except ValueError as error:results.append(dict(case=name,rejected=True,reason=str(error)))
 else:raise AssertionError(name)
(O/'causal_neighbors.json').write_text(json.dumps(results,indent=2))
# Real wall removal falsifies the native occlusion assertion on current source.
argv=['bash','tools/godot.sh','--headless','--fixed-fps','60','--path','.','--script','build/plains_redesign/review_encounter_r2/physical_wall_probe.gd'];p=subprocess.run(argv,cwd=R,capture_output=True,text=True);(O/'physical_wall_probe_measured.log').write_text(p.stdout+p.stderr);assert p.returncode==1
wall=json.loads((O/'physical_wall_probe.json').read_text());assert wall['failures']==1 and wall['enemy_health']==2 and any(x.get('kind')=='committed' for x in wall['events'])
commands=json.loads((O/'commands.json').read_text());commands.extend([dict(argv=['python3','build/plains_redesign/review_encounter_r2/verify_neighbors.py'],exit_code=0,log='neighbors_final.log',notes='Two earlier reviewer-script assumptions corrected, original logs retained: capability position/scope naturally change; pre-protocol diagnostic reports are preserved failures, only final run_ypk8st18 reports are claimed compatible.'),dict(argv=['python3','build/plains_redesign/review_encounter_r2/final_checks.py'],exit_code=0,log='final_checks.log'),dict(argv=argv,exit_code=p.returncode,expected_exit_code=1,log='physical_wall_probe_measured.log')]);(O/'commands.json').write_text(json.dumps(commands,indent=2))
checks=[]
folder=R/'build/verification/plains-redesign-encounter/PLAINS-REDESIGN-ENCOUNTER-01/2'
for name in ['docs','quality','plains-encounter-policy','level-formal-receipts','level-experience','level-formal-runtime']:
 p=folder/(name+'.log');checks.append(dict(id=name,path=str(p.relative_to(R)),sha256=H(p),log=p.read_text()))
(O/'fresh_checks.json').write_text(json.dumps(checks,indent=2))
request=json.loads((O/'request.json').read_text());assert loop.digest({k:v for k,v in request.items() if k!='request_hash'})==request['request_hash'];assert time.time()<request['expires_at'];assert loop.digest(loop.snapshot())==request['source_hash']
readfiles=['AGENTS.md','.agents/skills/gameplay-reviewer/SKILL.md','.agents/skills/encounter-director/SKILL.md','.agents/skills/game-quality-gate/SKILL.md','tools/production_loop.py','tools/level_experience.py','tools/level_formal.py','tools/run_plains_encounter_policy_tests.py','tests/level_formal_trace.gd','tests/plains_encounter_policy_runner.gd','tests/test_level_formal_receipts.py','tests/test_level_experience.py','tools/level_formal_capture.gd','docs/quality/plains_redesign_encounter.md','build/plains_redesign/encounter_preparation/current_content_api.md','docs/evidence/plains_redesign/encounter/index.json','docs/evidence/plains_redesign/encounter/r2_repair/index.json']
(O/'read_inventory.json').write_text(json.dumps([dict(path=p,sha256=H(R/p)) for p in readfiles],indent=2));print('FINAL CHECKS PASS source',request['source_hash'],'causal',len(results),'wall expected',p.returncode if hasattr(p,'returncode') else 1)
