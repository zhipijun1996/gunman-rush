from pathlib import Path
import sys,json,hashlib,subprocess,copy,re,zipfile,importlib.util
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'tools'))
import run_root_bell_tests as v
O=ROOT/'build/forest_revision04/fix-F2-review';P=ROOT/'build/forest_revision04/ci-final-H/root-bell-fix';N=ROOT/'build/root_bell/fix_H_damage_stun03/native165'
def sha(b):return hashlib.sha256(b).hexdigest()
def load(p):return json.loads(Path(p).read_text())
def git(ref,p):return subprocess.check_output(['git','show',ref+':'+p])
K='8f803e2f04b17db3ed725df9071669fe78cadeea';R='169ef171fee3f70911847fb2c2890351ee3468bb'
assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==K
cap=(N/'capture.json').read_bytes();data=json.loads(cap);report=load(N/'report.json');runtime=(N/'runtime.log').read_bytes();expected=v.sources()
stats=v.validate_evidence(cap,report,runtime,expected,report['source_commit'])
assert report['source_commit']=='5182ace20c66b36aa9d6ec6fa38da9791adf2280'
content=v.tamper_checks(data);receipts=v.provenance_tamper_checks(cap,report,runtime,expected,report['source_commit'])
assert len(content)==55 and len(receipts)==11
outer=load(P/'original-g1-full03-receipt.json');assert outer['returncode']==0 and outer['elapsed']<outer['outer_cap']==360
assert outer['actual_candidate_source_before']==outer['actual_candidate_source_after']
for p,h in outer['actual_candidate_source_after'].items():assert sha(git(K,p))==h
cases={c['id']:c for c in data['cases']};target='real_projectile_interrupt';f=cases[target]['frames'];hit=next(e for e in cases[target]['events'] if e['kind']=='damage' and e['target']=='root_fixture');hi=hit['tick']-1
frozen=[i for i in range(hi+1,len(f)) if f[i-1]['damage_stun_remaining']>0 and f[i-1]['enemy_hp']>0];resume=next(i for i in range(hi+1,len(f)) if f[i-1]['damage_stun_remaining']==0)
def C(d,name=target):return next(c for c in d['cases'] if c['id']==name)
mutations={
 'hit_cause_wrong_target':lambda d:next(e for e in C(d)['events'] if e['kind']=='damage' and e['target']=='root_fixture').update(target='player'),
 'hit_cause_wrong_projectile_identity':lambda d:next(e for e in C(d)['events'] if e['kind']=='damage' and e['target']=='root_fixture').update(id='foreign:shot:999999'),
 'hit_cause_shifted_tick':lambda d:next(e for e in C(d)['events'] if e['kind']=='damage' and e['target']=='root_fixture').update(tick=hit['tick']+1),
 'hit_cause_wrong_amount':lambda d:next(e for e in C(d)['events'] if e['kind']=='damage' and e['target']=='root_fixture').update(amount=0.5),
 'wrong_feedback_resource':lambda d:C(d)['damage_feedback'].update(resource_path='res://unbound.tres'),
 'initial_epsilon_stun':lambda d:C(d)['frames'][0].update(damage_stun_remaining=1e-6),
 'epsilon_after_exact_zero':lambda d:C(d)['frames'][resume].update(damage_stun_remaining=1e-6),
 'frozen_tick_advances_clock':lambda d:C(d)['frames'][frozen[0]].update(time=f[frozen[0]]['time']+1/60),
 'frozen_tick_changes_goal':lambda d:C(d)['frames'][frozen[0]].update(goal=[999,999]),
 'frozen_tick_changes_serial':lambda d:C(d)['frames'][frozen[0]].update(serial=f[frozen[0]]['serial']+1),
 'resume_tick_keeps_frozen_clock':lambda d:C(d)['frames'][resume].update(time=f[resume-1]['time']),
 'stun_missing_cannot_select_history_implicitly':lambda d:[x.pop('damage_stun_remaining',None) for c in d['cases'] for x in c['frames']],
}
neg=[]
for name,mutate in mutations.items():
 d=copy.deepcopy(data);mutate(d)
 try:v.validate_capture(d)
 except ValueError as e:neg.append({'name':name,'rejected':True,'reason':str(e)})
 else:raise AssertionError('ACCEPTED '+name)
# Independently recreate the previously accepted coherent epsilon attack.
d=copy.deepcopy(data);c=C(d,'solid_occlusion_negative')
for x in c['frames']:x['damage_stun_remaining']=1e-6;x['time']=c['frames'][0]['time']
try:v.validate_capture(d)
except ValueError as e:neg.append({'name':'coherent_no_hit_epsilon_and_frozen_clock','rejected':True,'reason':str(e)})
else:raise AssertionError('epsilon accepted')
# Exact original source text after removing only two observational additions.
old=git(R,'tests/root_bell_tests.gd').decode();current=git(K,'tests/root_bell_tests.gd').decode()
stripped=current.replace(', "damage_stun_remaining": actor._damage_stun_remaining','').replace(', "damage_feedback": {"resource_path": actor.damage_feedback.resource_path, "enemy_knockback_seconds": actor.damage_feedback.enemy_knockback_seconds}','')
assert stripped==old
assert len(re.findall(r'\bcheck\.call\(',old))==58
admission=load(ROOT/'build/root_bell/fix_H_damage_stun03/admission_audit.json');assert len(admission['rows'])==40 and admission['failures']==[]
# Only four executable source paths differ from reviewed R, including tools elsewhere.
paths=subprocess.check_output(['git','diff',R,K,'--name-only'],text=True).splitlines();non_docs=[p for p in paths if not p.startswith('docs/')]
wanted=['scripts/art/avatar_presentation.gd','tests/root_bell_tests.gd','tests/underworld_plains/test_underworld_identity_population.gd','tools/run_root_bell_tests.py'];assert sorted(non_docs)==wanted
bound={p:sha(git(K,p)) for p in wanted}
# The actual declared 203 basis inputs, not a recursive preload graph.
b=load(ROOT/'build/foundry_final_W10/basis_R169_inputs.json');bc=load(ROOT/'build/foundry_final_W10/basis_current_inputs.json');assert b==bc and len(b['entries'])==203
for row in b['entries']:assert sha(git(R,row['path']))==sha(git(K,row['path']))==row['sha256']
text='\n'.join([b['engine_string_from_recorded_actual_stamp']]+[x['res_path']+':'+x['sha256'] for x in b['entries']]);basis=sha(text.encode());assert basis==b['basis']=='f3e060598385696137aa40910811fcbfed931853fe7f4c9992b11cf1af0263cb'
res=load(ROOT/'build/foundry_final_W10/source-equivalence-report.json')['resource_paths'];assert len(res)==56
for p in res:assert git(R,p)==git(K,p)
# Verify compact selected originals; do not reread all repeated 390 MB synthetic captures while Web runs.
zp=P/'selected-evidence-compact.zip';assert sha(zp.read_bytes())=='c50208b4214b98b2dbba2c6f968027830bef8ff25ce36c5905e4a5f1d017e216'
ix={r['path']:r for r in load(P/'final-file-index.json')}
with zipfile.ZipFile(zp) as z:
 assert len(z.namelist())==62 and z.testzip() is None
 verified=0
 for name in z.namelist():
  if name in ix:
   raw=z.read(name);assert sha(raw)==ix[name]['sha256'] and len(raw)==ix[name]['bytes'];verified+=1
result={'status':'PASS','reviewed_final_runtime_commit':K,'execution_commit_preserved':report['source_commit'],'stats':stats,'source_map':bound,'root_bell':{'content_refusals_reexecuted':content,'receipt_refusals_reexecuted':receipts,'independent_extra_mutations':neg,'original_gd_text_exact_after_only_observational_fields_removed':True,'original_check_calls':58,'admission_actual_maps':len(admission['rows']),'admission_failures':admission['failures'],'outer_elapsed':outer['elapsed'],'outer_cap':outer['outer_cap'],'hit_tick':hit['tick'],'observed_stun_and_clock':[{k:x[k] for k in ('tick','enemy_hp','damage_stun_remaining','time')} for x in f[hi-1:resume+1]]},'source_closure':{'non_docs_paths_R_to_K':non_docs,'basis_inputs':203,'basis':basis,'resources_R_to_K_byte_equal':56,'W10_native_executed':False},'selected_zip':{'path':str(zp.relative_to(ROOT)),'sha256':sha(zp.read_bytes()),'members':62,'index_members_verified':verified},'scope':'Pure read-only validation; no Godot/browser. No new Web/fullCI/full80/movie/device claim.'}
(O/'K_independent_pure_audit.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'status':'PASS','extra_mutations':len(neg),'content':len(content),'receipt':len(receipts),'basis':203,'resources':56,'zip_index_verified':verified}))
