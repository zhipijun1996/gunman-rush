from pathlib import Path
import json, subprocess, hashlib, importlib.util, copy, re, sys
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'tools')); out=ROOT/'build/forest_revision04/queen-campaign-review'; scenario=ROOT/'build/forest_depth/campaign/queen-driver-T-fix-r1'
sha=lambda b:hashlib.sha256(b).hexdigest()
path='tests/forest_depth_campaign_boss_runner.gd'; old=subprocess.check_output(['git','show','1352f59f1b4761fe0ed806b0c0a165bcc7d54fab:'+path]);new=(ROOT/path).read_bytes()
def calls(text):
 result=[]
 for m in re.finditer(r'(?<![\w.])check\(',text):
  if text[max(0,m.start()-5):m.start()].endswith('func '):continue
  p=m.end();level=1;quote=None;esc=False
  while level:
   ch=text[p]
   if quote:
    if esc:esc=False
    elif ch=='\\':esc=True
    elif ch==quote:quote=None
   elif ch in "\"'":quote=ch
   elif ch=='(':level+=1
   elif ch==')':level-=1
   p+=1
  result.append(text[m.start():p])
 return result
orig=calls(old.decode());cur=calls(new.decode());remaining=cur.copy()
for call in orig:remaining.remove(call)
assert len(remaining)==1 and '4200' in remaining[0]
rc=json.loads((scenario/'receipt.json').read_text());cap=json.loads((scenario/'capture.json').read_text()); assert rc['passed'] is True and rc['source_guard'] is True
assert rc['source_before']==rc['source_after'] and rc['verifier_before']==rc['verifier_after']
assert rc['base_commit']=='1352f59f1b4761fe0ed806b0c0a165bcc7d54fab'
assert rc['native_budget_seconds']==180 and rc['import_budget_seconds']==90
assert rc['source_before'][path]==sha(new)
for p,h in rc['logs'].items():assert sha((scenario/p).read_bytes())==h
for p in ['tests/support/forest_queen_gameplay_fixture.gd','tools/run_forest_depth_campaign_boss.py','resources/bosses/thorn_queen_v2.tres']:
 b=(ROOT/p).read_bytes();assert b==subprocess.check_output(['git','show','1352f59:'+p]);assert sha(b)==rc['source_before'].get(p,rc['verifier_before'].get(p))
assert subprocess.check_output(['git','diff','--name-only'],text=True).splitlines()==[path]
spec=importlib.util.spec_from_file_location('queen_validator',ROOT/'tools/run_forest_depth_campaign_boss.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);mod.validate_queen(cap)
negative=[]
def refuse(name,mut):
 c=copy.deepcopy(cap);mut(c)
 try:mod.validate_queen(c)
 except (AssertionError,ValueError,KeyError,TypeError) as e:negative.append({'name':name,'rejected':True,'reason':str(e)});return
 raise AssertionError('accepted '+name)
refuse('Boss HP remains nonterminal',lambda c:c['queen_combat']['final'].__setitem__('boss_hp',1))
refuse('Live player lost',lambda c:c['queen_combat']['final'].__setitem__('player_hp',0))
refuse('Duplicate defeat',lambda c:c['queen_combat'].__setitem__('defeats',2))
refuse('Skip actual reload',lambda c:c['queen_combat'].__setitem__('reloaded',False))
refuse('Missing real motor frame',lambda c:c['queen_combat']['frames'][400].__setitem__('physics_frame',-1))
refuse('Damage from injected source',lambda c:next(e for e in c['queen_combat']['events'] if e.get('event')=='policy_result' and e.get('target')=='boss').__setitem__('source','injected'))
refuse('Reload heals earned health',lambda c:c['queen_reload']['after_bound'].__setitem__('boss_hp',24))
refuse('Gold granted twice',lambda c:c['after_gold'].__setitem__('count',2))
refuse('Boundary hides unsupported region',lambda c:c.__setitem__('boundary_ui_text',[]))
refuse('Old assertion false',lambda c:c['checks'][5].__setitem__('passed',False))
refuse('Manual motor injected',lambda c:c.__setitem__('manual_motor_step',True))
for log in ['native.log','import.log']:
 text=(scenario/log).read_text()
 for forbidden in ['SCRIPT ERROR','ERROR:','WARNING: ObjectDB','resources still in use','Leaked instance']:
  assert forbidden not in text,(log,forbidden)
f=cap['queen_combat']['frames']; ev=cap['queen_combat']['events']
for i,row in enumerate(f):assert row['tick']==i+1
assert cap['queen_combat']['combat_elapsed_frames']==f[-1]['tick']-cap['queen_combat']['combat_start_tick']==1327
hits=[{'tick':e['tick'],'target':e.get('target'),'hp':e.get('hp'),'source':e.get('source')} for e in ev if e.get('event')=='policy_result']
transitions=[{k:r[k] for k in ['tick','driver_phase','player','grounded','damage_remaining','used_jumps']} for i,r in enumerate(f) if i==0 or r['driver_phase']!=f[i-1]['driver_phase']]
result={'status':'SCOPED_ACCEPT','execution_head':rc['base_commit'],'execution_dirty_path':path,'source_sha256':sha(new),'original_static_check_calls':len(orig),'current_static_check_calls':len(cur),'original_calls_byte_exact_multiset':True,'added_check_call':remaining,'runtime_check_count':len(cap['checks']),'python_original_validator_passed':True,'independent_corrupted_actual_capture_rejections':negative,'source_and_log_bindings_verified':True,'strict_log_scan_clean':True,'native_budget_seconds':180,'import_budget_seconds':90,'wrapper_seconds':rc['elapsed_seconds'],'combat_driver_ticks':1327,'combat_driver_limit':4200,'damage_events':hits,'driver_transitions':transitions,'limits':['4200 counts frames() driver observations; existing direct process-frame waits during pause/reload are not newly counted global Engine frames.','Changed legal timing avoided repeat of old hurt during second jump; observed final growing-weave damage is tick559 during approach, then hurt-free jump585.','Actual one seed recorded v7/schema13 scenario, not current Canopy admission or full matrix/CI.','No native launched by independent reviewer.']}
(out/'r1_independent_audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['damage_events','driver_transitions','independent_corrupted_actual_capture_rejections','added_check_call']},ensure_ascii=False))
