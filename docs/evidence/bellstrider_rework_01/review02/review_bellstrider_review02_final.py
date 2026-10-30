from pathlib import Path
import ast,copy,hashlib,json,re,subprocess
R=Path('/workspace/gunman-rush');BASE='e20dea03b7b54eff1f706ab48e5a6f177851de24';checks=[]
def raw(p):return(R/p).read_bytes()
def obj(p):return json.loads(raw(p))
def sha(b):return hashlib.sha256(b).hexdigest()
def git(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=R)
def ck(n,v):checks.append({'check':n,'passed':bool(v)})
def replace_strings(v,mp):
 if isinstance(v,str):return mp.get(v,v)
 if isinstance(v,list):return[replace_strings(x,mp) for x in v]
 if isinstance(v,dict):return{k:replace_strings(x,mp) for k,x in v.items()}
 return v
meta='docs/evidence/bellstrider_rework_01/review02/';delta=obj(meta+'binding-delta.json');sp='docs/creative_direction/bibles/style-continuity-20261030-v23-bellstrider-rework.json';rp='docs/creative_direction/bibles/registry.json';prof='tools/harness/profiles.json';st=obj(sp);reg=obj(rp)
ck('declared_baseline',delta['baseline']==BASE)
for file in ['style-continuity-20261030-v23-bellstrider-rework.json','registry.json','windchime_plains.json','thorn_forest.json']:
 origin='docs/creative_direction/bibles/'+file if file in ['style-continuity-20261030-v23-bellstrider-rework.json','registry.json'] else'docs/creative_direction/'+file
 ck('backup_exact_original_e20/'+file,raw(meta+'metadata-before/'+file)==git(origin))
oldstyle=json.loads(git(sp));ck('exact96_rolepath_order',len(st['runtime_reference']['references'])==96 and [(r['role'],r['path']) for r in st['runtime_reference']['references']]==[(r['role'],r['path']) for r in oldstyle['runtime_reference']['references']]);changed=[]
for a,b in zip(oldstyle['runtime_reference']['references'],st['runtime_reference']['references']):
 ck('role_metadata_unchanged/'+a['role'],{k:v for k,v in a.items() if k!='sha256'}=={k:v for k,v in b.items() if k!='sha256'})
 ck('actual96_SHA/'+b['role'],b['sha256']==sha(raw(b['path'])))
 if a!=b:changed.append({'path':a['path'],'old_sha256':a['sha256'],'new_sha256':b['sha256']})
ck('four_exact_registered_leaf_rebinds',changed==sorted(delta['changes'],key=lambda x:next(i for i,r in enumerate(oldstyle['runtime_reference']['references']) if r['path']==x['path'])) and len(changed)==4)
mp={r['new_sha256']:r['old_sha256'] for r in changed};ck('style_only4_SHA_values_update',replace_strings(st,mp)==oldstyle)
ck('exact_current_style_and_registry_SHA',sha(raw(sp))==delta['style_sha256']=='d38ece15706e8ac9247faf4d91c22700b0611e06d838d077b081e5ec4a19cd39' and sha(raw(rp))==delta['registry_sha256']=='dbc2592c558f0fa95d03b88d63363786d172d973e6e494e4ea6ff7db11d83bc2')
ck('registry_only_current_style_SHA',replace_strings(reg,{sha(raw(sp)):sha(git(sp))})==json.loads(git(rp)))
for p in ['docs/creative_direction/windchime_plains.json','docs/creative_direction/thorn_forest.json']:
 ck('both_binding_and_authority_sources_rebound_only/'+p,replace_strings(obj(p),{sha(raw(sp)):sha(git(sp)),sha(raw(rp)):sha(git(rp))})==json.loads(git(p)))
projectile='scripts/bosses/bellstrider_bell_projectile.gd';ck('projectile_comment_only_no_behavior_delta',git(projectile).decode().replace('# At 120Hz segment size, curvature error stays below .01 world units.','# At configured gravity,120Hz slices keep chord error below .02world units.')==raw(projectile).decode())
pre=json.loads(Path('/tmp/bellstrider-review02-source-review.json').read_bytes());ck('prior_source_model41passed',pre['passed']==41 and pre['failed']==0)
for p,h in pre['source_SHA'].items():ck('final4_production_same_source_preflight/'+p,sha(raw(p))==h)
oldmanifest=json.loads(git(prof));current=obj(prof);expected=copy.deepcopy(oldmanifest);expected['checks']['bellstrider-rework-01']['success_pattern']=expected['checks']['bellstrider-rework-01']['success_pattern'].replace('seven','eight');ck('manifest_only_exact_completion_marker',current==expected)
ck('original169_full_order_300budget',current['profiles']==oldmanifest['profiles'] and len(current['profiles']['full'])==169 and current['checks']['bellstrider-rework-01']['timeout_seconds']==300)
helper='tools/run_bellstrider_rework_01_tests.py';oldhelper=git(helper).decode();h=raw(helper).decode();parse=lambda s:next(ast.literal_eval(n.value) for n in ast.parse(s).body if isinstance(n,ast.Assign) and any(isinstance(v,ast.Name) and v.id=='CASES' for v in n.targets));a,b=parse(oldhelper),parse(h);ck('original7_cases_verbatim_order_new8th',len(a)==7 and len(b)==8 and b[:7]==a and b[-1][1]=='tests/bellstrider_rework_01/contact_edges.gd')
expectedhelper=oldhelper.replace('\n)\n\n\ndef main()', '\n    ("contact", "tests/bellstrider_rework_01/contact_edges.gd", r"BELLSTRIDER_CONTACT_EDGES assertions=\\d+ failures=0"),\n)\n\n\ndef main()').replace('REGRESSION: seven native','REGRESSION: eight native');ck('helper_only_append_and_finishmarker',h==expectedhelper)
ck('strict_error_and_percase90_retained','r"(?m)^ERROR:|RID allocations.*leaked"' in h and 'run_engine(["--headless", "--path", ".", "--script", script], 90)' in h)
for p in ['tests/test_region_bible.py','tests/test_region_creative_direction.py','tests/test_production_plan.py','tools/harness.py','scripts/damage/frame_damage_policy.gd','scripts/bosses/windkeeper_damageable.gd','scripts/items/v5/item_runtime.gd','scripts/player/traversal_ability.gd']:
 ck('original_guard_or_policy_bytes_exact/'+p,raw(p)==git(p))
# Mechanically retain original GDScript check-call label argument order.
def check_args(text):
 result=[]
 for m in re.finditer(r'\bcheck\(',text):
  if text[text.rfind('\n',0,m.start())+1:m.start()].strip()=='func':continue
  i=m.end();start=i;depth=0;quote=None;escape=False;args=[]
  while i<len(text):
   ch=text[i]
   if quote:
    if escape:escape=False
    elif ch=='\\':escape=True
    elif ch==quote:quote=None
   else:
    if ch in '\"\'':quote=ch
    elif ch in '([{':depth+=1
    elif ch in ')]}':
     if ch==')' and depth==0:args.append(text[start:i].strip());break
     depth-=1
    elif ch==',' and depth==0:args.append(text[start:i].strip());start=i+1
   i+=1
  if len(args)==2:result.append(args[-1])
 return result
combat='tests/bellstrider_rework_01/combat_runner.gd';oc=git(combat).decode();nc=raw(combat).decode();la,lb=check_args(oc),check_args(nc);oldlabel='"low contact fits chassis without upper bell"';newlabel='"low contact bounds cover the actual chassis and wheels without the upper bell"';timing=['"actual aim and locked warning launch within .75seconds"','"actual thrown bell reaches its support within1.35seconds"'];normalized=[oldlabel if x==newlabel else x for x in lb if x not in timing];ck('all_old_combat_literal_labels_order_one_authorized_shape_change',normalized==la and oldlabel in la and newlabel in lb and all(x in lb for x in timing))
ck('all_old_combat_methods_order_preserved',re.findall(r'^func (\w+)\(',oc,re.M)==re.findall(r'^func (\w+)\(',nc,re.M))
contact='tests/bellstrider_rework_01/contact_edges.gd';s=raw(contact).decode();ck('newcontact_scope_discloses_stationary_epoch_phase_notnatural',all(x in s for x in ['This is not a natural fight.','encounter.set_physics_process(false)','app.lifetime.invalidate_actor()','"phase_fixture": phase']))
ck('actual_App_Router_and_batch_receipts',all(x in s for x in ['app.start_plains("level-design-v2-baseline/08")','app.policy.batch_resolved.connect(record_batch)','app.controller.router.set_source_axis','result.request.source_id != &"boss_contact"','result.hp_lost <= 0']))
ck('four_positive_contacts_require_realHP_and_oldrectnegative',all(x in s for x in ['contacts.size() == 1 and app.controller.actor_resources.health.current == hp - 1.0','not actor_rect().intersects(legacy)','"roof fall"','await ground_side(-1, true)']))
ck('intro_negative_not_just_spawn_iframe','encounter.mode == &"intro" and app.policy.player_clock() >= app.policy._protected_until' in s)
ck('bevel_actual_AABB_positive_and_providernegative_and_Routerescape',all(x in s for x in ['actor_rect().intersects(encounter.body_contact_rect())','not encounter.body_contact_sweep','"actual Router retreat through bevel air never submits contact damage"']))
ck('genuine_hook_target_and_unrelated_negative',all(x in s for x in ['router.request_action(&"grapple", direction)','app.controller.traversal.hook_target == encounter._core','not app.controller.traversal.protects_contact(unrelated)']))
ck('terminal_fixture40realshots_noHPdebit',all(x in s for x in ['for shot: int in 40','router.request_action(&"shoot_release", direction)','encounter.health.current == hp - 1.0','fired[0] == 40','"actual terminal carriage remains harmless to physical contact"']) and not re.search(r'health\.(?:configure|apply|restore)|policy\.submit\(|receive_damage\(',s))
ck('test_never_manually_ticks_contact_provider_positive', '_boss_contact._physics_process' not in s and 'notify_physical_contact(' not in s)
result194=obj('build/bellstrider_rework_01/contact_edges.json');ck('actual194_native_receipt_passed',result194['assertions']==194 and result194['failures']==[])
obs=[x for x in result194['observations'] if x.get('contacts')];rows=[y for x in obs for y in x['contacts']];ck('actualfour_recorded_contacts_outside_old_rect',len(rows)==4 and all(x['HP_lost']==1 and x['outside_legacy'] and x['source']=='boss_contact' for x in rows) and {x['mode'] for x in rows}=={'observe','phase_transition'})
logs=[]
for p in ['build/bellstrider_review_02/contact-01.log','build/bellstrider_review_02/regression-01.log']:
 b=raw(p);ck('native_original_log_no_errors/'+p,not re.search(rb'(?m)^ERROR:|SCRIPT ERROR:|RID allocations.*leaked|ObjectDB instances.*leaked',b));logs.append({'path':p,'sha256':sha(b),'executed_by_reviewer':False})
regraw=raw('build/bellstrider_review_02/regression-01.log');numbers=[int(x) for x in re.findall(rb'assertions=(\d+) failures=0|(?!)',b'')] if False else[]
for label,count in [('BELLSTRIDER_REWORK_COMBAT assertions=',276),('BELLSTRIDER_EFFECT_TARGETS assertions=',35),('BELLSTRIDER DAMAGE POLICY: ',86),('BELLSTRIDER WEAPON ROUTES: ',88),('BELLSTRIDER_INTRO_POSE assertions=',65),('BELLSTRIDER_REWARDS checks=',37),('BELLSTRIDER_AUDIO_POOL assertions=',110),('BELLSTRIDER_CONTACT_EDGES assertions=',194)]:ck('original8_markers/'+label,(label+str(count)).encode() in regraw);numbers.append(count)
ck('actual891_all8_finish',sum(numbers)==891 and b'BELLSTRIDER REWORK REGRESSION: eight native consumers, 0 failures' in regraw)
folder=R/'build/verification/harness/20261030T130657.437539Z';r=json.loads((folder/'report.json').read_bytes());ck('latest_four03_allfresh_passed',r['status']=='passed' and len(r['checks'])==4 and all(x['status']=='passed' and x['exit_code']==0 and x['reused'] is False for x in r['checks']));ck('latest_four03_manifest_current',r['manifest_sha256']==sha(raw(prof)))
for row in r['checks']:
 c=current['checks'][row['id']];b=(folder/row['log']).read_bytes();ck('four03_original_contract/'+row['id'],row['argv']==c['argv'] and row['timeout_seconds']==c['timeout_seconds'] and re.search(c['success_pattern'],b.decode(),re.M)!=None and b==(Path(row['artifact_directory'])/'check.log').read_bytes())
 if row['id'].endswith('-tests'):ck('four03_actual43_18/'+row['id'],('Ran %s tests'%(43 if row['id']=='region-bible-tests' else 18)).encode() in b)
for p,hv in r['working_files'].items():ck('four03_current21_dirty_leaf/'+p,sha(raw(p))==hv)
failures=[]
for p in ['build/verification/harness/20261030T130428.679666Z/report.json','build/verification/harness/20261030T130456.229093Z/report.json']:
 x=obj(p);wrapper='build/bellstrider_review_02/binding-final-01.log' if '130428' in p else 'build/bellstrider_review_02/binding-final-02.log';ck('prior_failed_or_interrupted_design_check_retained/'+p,x['status']!='passed' and ('Harness failed: Validation lane source differs from frozen snapshot' in raw(wrapper).decode() if '130428' in p else x['status']=='failed'));failures.append({'path':p,'sha256':sha(raw(p)),'raw_report_status':x['status'],'wrapper':wrapper,'wrapper_sha256':sha(raw(wrapper)),'interpretation':'first sourceguard abort retains original interrupted/incomplete report, wrapper explicitly fails; second report failed3 stale authority hashes. Neither is passed.'})
planner=Path('/tmp/bellstrider-review02-final-planner.log').read_bytes();ck('reviewer_actual_pureplanner22passed',b'Ran 22 tests' in planner and b'\nOK\n' in planner)
paths=['scripts/bosses/bellstrider_definition.gd','scripts/bosses/bellstrider_encounter.gd','scripts/bosses/bellstrider_bell_projectile.gd','scripts/damage/demo_contact_emitter.gd','scripts/demo/demo_app.gd',contact,combat,helper,prof,sp,rp,'tests/bellstrider_rework_01/contact_edges.gd.uid'];result={'verdict':'ACCEPT_SCOPED_FROZEN_SOURCE_TEST_GUARD_BINDING' if all(x['passed'] for x in checks) else'REWORK','reviewer':'/root/guard_review_recovery','independence':'No current production/contact194/test-migration authored by reviewer; own prior damage_policy86 excluded from independent acceptance.','baseline_commit':BASE,'source_state':'Owner-frozen dirty development candidate; exact12 leafSHA, not a clean commit execution.','passed':sum(x['passed'] for x in checks),'failed':sum(not x['passed'] for x in checks),'checks':checks,'source_SHA':{p:sha(raw(p)) for p in paths},'native_observed':{'checks':891,'own_test_excluded':86,'contact_independently_reviewed':194,'executed_by_reviewer':False,'logs':logs,'receipt_contact':{'path':'build/bellstrider_rework_01/contact_edges.json','sha256':sha(raw('build/bellstrider_rework_01/contact_edges.json'))},'scope':'Controlled actualApp/Router/Motor/policy fixtures; stationary AI, explicit initial actor epochs/positions and phase state;40 real shots for death. Not natural battle or exact complete old->new angular sweep proof.'},'four_pure_receipt':{'path':str(folder/'report.json'),'sha256':sha((folder/'report.json').read_bytes()),'working_files':len(r['working_files']),'executed_by_reviewer':False,'bounds':'Classic Harness internal source guard passed; current21 dirty leaf hashes match, no unstored fulltoolchain/globaldigest reconstructed.'},'retained_failed_design_receipts':failures,'actual_reviewer_commands':['python3 tests/test_production_plan.py > /tmp/bellstrider-review02-final-planner.log 2>&1','python3 /tmp/review_bellstrider_review02_final.py > /tmp/bellstrider-review02-final-proof.log'],'planner_log_sha256':sha(planner),'audit_script_sha256':sha(Path(__file__).read_bytes()),'not_accepted':['Own86 as independent test','New natural battle/faster lob audiovisual movie','Human fairness/user/art/audio/device/G1-G5','Current-pose sweep as full continuous articulated angular CCD']};Path('/tmp/bellstrider-review02-final-review.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('CHECKS',result['passed'],result['failed']);print('FAILURES',[x for x in checks if not x['passed']]);print(result['verdict'])
