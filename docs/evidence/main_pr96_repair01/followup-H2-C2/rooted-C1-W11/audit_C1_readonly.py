from pathlib import Path
import sys,json,copy,subprocess,hashlib,re
sys.path.insert(0,str(Path.cwd()/'tools'));import run_root_bell_tests as g1;import run_root_bell_ecology as ecology
R=Path.cwd();O=R/'build/forest_revision04/rooted-fix-review'
C='220fe7dec48e46ad52b8a83302f6c46e8352bac8';H='cea407025bb3a31be745c440efb85920307679a3';ACT='scripts/enemies/enemy_actor.gd'
def load(p):return json.loads(Path(p).read_text())
def sha(b):return hashlib.sha256(b).hexdigest()
def git(ref,p):return subprocess.check_output(['git','show',ref+':'+p])
assert subprocess.check_output(['git','rev-parse',C+'^'],text=True).strip()==H
assert subprocess.check_output(['git','diff',H,C,'--name-only'],text=True).splitlines()==[ACT]
a=git(C,ACT).decode();old=git(H,ACT).decode();assert sha(a.encode())=='fd0472ed114bbe1dfccc8b3bcd569fecd54ad3473a14b3a31ac8af71cc2186d8'
restore=a.replace('\t\t# Root Bell owns a fixed rooted body; hurt pauses its phase, not its roots.\n\t\tif definition.behavior_id != &"root_bell":\n\t\t\tmotor.step(EnemyIntent.new(),delta)','\t\tmotor.step(EnemyIntent.new(),delta)').replace('\tif definition.behavior_id == &"root_bell": return\n','');assert restore==old
D=R/'build/verification/harness/20261020T073450.354937Z';h=load(D/'report.json');assert h['status']=='passed' and h['commit']==H and h['git_status']=='M scripts/enemies/enemy_actor.gd' and h['working_files']=={ACT:sha(a.encode())}
outer=load(R/'build/forest_revision04/rooted-fix-H2/outer-receipt.json');assert outer['exit_code']==0 and outer['actor_sha256']==outer['actor_sha256_after']==sha(a.encode())
expected=['root-bell-tests','root-bell-ecology','underworld-damage-feedback'];assert [c['id'] for c in h['checks']]==expected and [c['timeout_seconds'] for c in h['checks']]==[360,420,180]
for c in h['checks']:assert c['status']=='passed' and c['exit_code']==0 and not c['reused']
N=R/'build/root_bell/formal_v2/1792481713118958419/native165';nr=load(N/'report.json');cb=(N/'capture.json').read_bytes();rb=(N/'runtime.log').read_bytes();src={p:sha(git(C,p)) for p in g1.SOURCES}
stats=g1.validate_evidence(cb,nr,rb,src,H);content=g1.tamper_checks(json.loads(cb));receipt=g1.provenance_tamper_checks(cb,nr,rb,src,H);assert (len(content),len(receipt))==(55,11)
B=R/'build/production_repair/ecology/formal_1792481240261501741';A=R/'build/production_repair/ecology/formal_1792481851996734819';bad=load(B/'capture.json');good=load(A/'capture.json');br=load(B/'report.json');ar=load(A/'report.json')
assert br['status']=='failed' and br['error']=='ValueError: Rooted body moved' and br['exit_code']==0
assert br['source_before'][ACT]==sha(old.encode()) and ar['source_before'][ACT]==ar['source_after'][ACT]==sha(a.encode()) and ar['source_before']==ar['source_after']
assert ar['status']=='passed' and ar['exit_code']==0 and '--root-bell-default' in ar['command'] and '--max-ticks=18000' in ar['command']
# Only actual actor source changes; test code and definition resources retain original bytes.
code_paths=[p for p in ar['source_before'] if p.startswith(('scripts/','tests/','tools/','config/')) and p.endswith(('.gd','.py','.json')) and ('root_bell' in p or p in [ACT,'scripts/enemies/enemy_motor.gd','scripts/enemies/enemy_definition.gd','scripts/damage/damage_feedback_definition.gd'])]
for p in code_paths:assert sha(git(C,p))==ar['source_before'][p]
try:ecology.validate(bad)
except ValueError as e:bad_refusal=str(e);assert bad_refusal=='Rooted body moved'
else:raise AssertionError('original failure accepted')
observed=ecology.validate(good);ecology_negatives=ecology.tamper(good);assert len(ecology_negatives)==27
home=bad['manifest']['root_bell_admission']['physical_facts']['home'];first=next(f for f in bad['frames'] if f['root_bell']['position']!=home);hit=next(e for e in bad['events'] if e['kind']=='damage_committed' and e['tick']==first['tick']-1 and e.get('target')==bad['root_bell_identity'])
assert first['tick']==4119 and hit['tick']==4118 and bad['frames'][4117]['root_bell']['hp']==2 and bad['frames'][4116]['root_bell']['hp']==3
assert first['root_bell']['position'][0]-home[0]==135/60 and all(f['root_bell']['position']==good['manifest']['root_bell_admission']['physical_facts']['home'] for f in good['frames'])
mutations=[]
for name,fn in [('actual_first_hit_displacement',lambda d:d['frames'][4118]['root_bell'].update(position=first['root_bell']['position'])),('tiny_root_displacement',lambda d:d['frames'][10]['root_bell'].update(position=[home[0]+.001,home[1]]))]:
 b=copy.deepcopy(good);fn(b)
 try:ecology.validate(b)
 except ValueError as e:mutations.append({'case':name,'reason':str(e)})
 else:raise AssertionError('bad rooted movement accepted')
dp=D/'artifacts/underworld-damage-feedback/build/underworld_r3/damage/runtime.json';dr=load(dp);assert dr['checks']==317 and dr['failures']==[];assert dp.read_bytes()==(R/'build/underworld_r3/damage/runtime.json').read_bytes()
def xy(s):return [float(x) for x in s.strip('()').split(',')]
rows={x['case']['name']:x for x in dr['enemy_edge_cases']};assert set(rows)=={'right_ground_edge','left_ground_edge','wide_ground','right_aerial_edge'}
wide=rows['wide_ground'];air=rows['right_aerial_edge'];assert xy(wide['final_position'])[0]-xy(wide['hits'][0]['position'])[0]>12 and wide['final_supported'];assert xy(air['final_position'])[0]>600 and any(f['knockback_remaining']>0 and xy(f['knockback'])[0]>100 for f in air['frames'])
for name in ['right_ground_edge','left_ground_edge']:assert rows[name]['final_supported'] and abs(xy(rows[name]['final_position'])[1]-372)<.1
for name in expected:
 log=(D/(name+'.log')).read_text();assert not any(x in log for x in ['SCRIPT ERROR:','Parse Error:','SHADER ERROR:','Shader compilation failed','ObjectDB instances leaked','resources still in use','ERROR:'])
files=[D/'report.json',R/'build/forest_revision04/rooted-fix-H2/outer-receipt.json',N/'capture.json',N/'report.json',N/'runtime.log',B/'capture.json',B/'report.json',B/'runtime.log',A/'capture.json',A/'report.json',A/'runtime.log',dp]
result={'status':'PASS','reviewed_commit':C,'actual_execution_head':H,'actual_actor_dirty_before_after_sha':sha(a.encode()),'only_changed_path_C1_parent_to_C1':ACT,'old_actor_byte_exact_after_removing_two_guards':True,'harness_checks':h['checks'],'outer_seconds':outer['elapsed'],'g1':{'stats':stats,'current_content_refusals':len(content),'current_receipt_refusals':len(receipt)},'ecology':{'before_error':bad_refusal,'before_home':home,'accepted_hit':hit,'first_bad_body_tick':first['tick'],'first_bad_body_position':first['root_bell']['position'],'per_tick_force_x':135/60,'actual_default_after':observed,'all_actual_root_body_positions_equal_home':True,'original_scope_and_budgets_unchanged':True,'original_mutation_refusals':len(ecology_negatives),'independent_body_displacement_refusals':mutations,'original_source_code_blobs_verified_against_C1':code_paths,'source_before_after_equal_entries':len(ar['source_before'])},'moving_enemy_damage':{'checks':317,'failures':[],'wide_ground':{'hit_position':wide['hits'][0]['position'],'final_position':wide['final_position'],'supported':wide['final_supported']},'aerial':{'hit_position':air['hits'][0]['position'],'final_position':air['final_position']},'two_ground_edges_supported':True,'artifact_equals_current_runtime_bytes':True},'raw_bindings':[{'path':str(p.relative_to(R)),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in files],'native_run_by_reviewer':False}
(O/'C1_independent_audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'status':'PASS','native_assertions':165,'g1_content_receipt':[55,11],'default_ecology':observed,'damage_checks':317}))
