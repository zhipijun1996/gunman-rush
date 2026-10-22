from pathlib import Path
import ast,copy,datetime,hashlib,json,os,re,subprocess,sys,time
ROOT=Path.cwd();OUT=ROOT/'build/region_bible_v2/encounter-ownership-independent-review-first';HEAD='083fbdc4a29a9d26c99b89bd5f2d506b3a88fcdb'
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'tests')]
import run_forest_depth_enemies as enemies
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();oldshow=lambda p:subprocess.check_output(['git','show',HEAD+':'+p])
freeze_path=ROOT/'build/region_bible_v2/v15-specialized-encounter-ownership-first/fix-and-freeze-v2.json';freeze=json.loads(freeze_path.read_text());recipe_path=ROOT/'build/region_bible_v2/v15-formal-ecology-reader-v5-first/freeze-and-offline-replay.json';recipe=json.loads(recipe_path.read_text());combined={**freeze['source_sha256'],**recipe['source_sha256']};paths=list(combined);before={p:sha(ROOT/p) for p in paths};checks=[]
def check(ok,label,details=None):
 checks.append(dict(passed=bool(ok),label=label,details=details))
 if not ok:raise AssertionError(label+': '+str(details))
check(sha(freeze_path)=='72f233ed455ec6e4b301b6503157f958d1af491cc0b190a93b563c551257620f','actual_v2_four_path_freeze_receipt_exact')
check(sha(recipe_path)=='0cb6348ad212fc38535f789a6ecb8f6b43e350008fd1261d04fadf33ead14ef1','latest_recipe_reader_two_path_freeze_exact');check(len(paths)==5 and before==combined,'all_five_current_inputs_match_merged_explicit_freeze')
previous=ROOT/'build/region_bible_v2/default-consumer-independent-inventory-first/consumer14-review/reviewed-source'
ecology=Path('tests/forest_bible_ecology_trace.gd').read_text();support=Path('tests/forest_bible_trace_support.gd').read_text();lift=Path('tests/forest_bible_lift_trace.gd').read_text()
prior_ecology=(previous/'tests/forest_bible_ecology_trace.gd').read_text();check(ecology.startswith(prior_ecology) and ecology[len(prior_ecology):].lstrip().startswith('func owns_strategy_encounter('),'ecology_entire_old_thin_trace_exact_prefix_only_guard_added')
block='\tfunc drive(trace: Node,leg: Dictionary) -> bool:\n\t\t# A specialist owns only its declared comparison encounter. Ordinary\n\t\t# prefix combat and every inherited combat limit remain unchanged.\n\t\tif trace.has_method("owns_strategy_encounter") and trace.owns_strategy_encounter(leg):return false\n\t\treturn super.drive(trace,leg)\n'
check(block in support and support.replace(block,'')==(previous/'tests/forest_bible_trace_support.gd').read_text(),'support_all_prior_pilots_muzzle_UI_admission_exact_after_only_new_Grove_dispatch_reversal')
preflight='\tif initialized and failures.is_empty() and not itinerary.any(func(leg: Dictionary) -> bool: return str(leg.get("edge_id",""))=="outer_to_inner"):\n\t\tfail("requested_lift_strategy_has_no_actual_R_return_edge")\n'
check(preflight in lift and lift.replace(preflight,'')==(previous/'tests/forest_bible_lift_trace.gd').read_text(),'new_Lift_only_exact_actual_itinerary_early_reject_added')
for p in ['tests/forest_depth_region_trace.gd','tests/forest_depth_ecology_trace.gd','tests/forest_depth_lift_trace.gd','tests/forest_depth_grove_combat_case.gd','tests/forest_interwoven_crown_combat_case.gd','config/player_tuning.json','resources/player/traversal.tres','scripts/player/player_motor.gd','scripts/input/keyboard_mouse_adapter.gd']:
 check(Path(p).read_bytes()==oldshow(p),'old_original_byte_exact/'+p)
check('owns_strategy_encounter' not in Path('tests/forest_bible_region_auto_trace.gd').read_text() and 'owns_strategy_encounter' not in lift,'normal_and_Lift_have_no_suppressing_ownership_method')
check('return super.drive(trace,leg)' in block and 'return false' in block,'Grove_always_super_for_unowned_encounters_not_blanket_disabled')
# The tiny source predicate is evaluated as a detached resource-free Boolean, never Godot execution.
body=ecology.split('func owns_strategy_encounter(leg: Dictionary) -> bool:\n',1)[1].replace('var edge: String =','edge =');body=re.sub(r'\btrue\b','True',body);body=re.sub(r'\bfalse\b','False',body)
def owns(mode,edge,finished=-1,enabled=True,formal=False):
 namespace=dict(ecology_strategy=mode,ecology_finished=finished,ecology_enabled=enabled,crossbranch_formal=formal);exec(compile('def owns(leg):\n'+body,'<independent-pure-source-guard>','exec'),namespace);return namespace['owns']({'edge_id':edge})
expected_edges={'crown_prep','belly_borer_access','west_to_belly','cavity_prep'};actual_edges=set(re.findall(r'edge=="([^"]+)"',ecology))
check(actual_edges==expected_edges,'finite_exact_four_owned_edge_names_no_prefix_or_wildcard')
# Each old specialized driver actually owns this complete comparison span.
original=Path('tests/forest_depth_ecology_trace.gd').read_text()
check('str(current.get("edge_id",""))=="west_to_belly"' in original and 'str(itinerary[leg_index+1].get("edge_id",""))!="west_to_belly"' in original,'west_scope_ends_only_at_original_last_M_arrival')
check('str(leg.get("edge_id",""))=="belly_borer_access" and str(leg.get("support_id",""))=="hollow__cavity_observe"' in original,'entry_scope_includes_full_edge_until_original_cavity_S_arrival')
check('if crossbranch_formal and leg_index<itinerary.size() and str(itinerary[leg_index].get("edge_id",""))=="cavity_prep"' in original,'crossbranch_guard_matches_original_entire_formal_cavity_prep_driver')
for mode in enemies.FORMAL_STRATEGIES:
 for edge in ('root_spiral_approach','lower_fork_approach','canopy_fork_approach','woven_descent','middle_fork_approach','outer_to_inner','bible_backbranch_flight'):
  check(not owns(mode,edge),'unrelated_prefix_edge_stays_common/'+mode+'/'+edge)
 for edge in ('crown_prep','belly_borer_access','west_to_belly'):
  check(not owns(mode,edge,finished=123),'completed_comparison_releases_common_pilot/'+mode+'/'+edge)
for mode in ('entry_clear','entry_wait','entry_hold'):
 check(owns(mode,'belly_borer_access') and not owns(mode,'west_to_belly'),'only_finite_entry_modes_own_whole_entry_edge/'+mode)
for mode in ('west_clear','west_wait','west_jump'):
 check(owns(mode,'west_to_belly') and not owns(mode,'belly_borer_access'),'only_finite_west_modes_own_whole_west_edge/'+mode)
check(owns('crossbranch_physics','cavity_prep',enabled=False,formal=True) and not owns('crossbranch_physics','cavity_prep',enabled=False,formal=False),'formal_crossbranch_only_guard_independent_of_unrelated_ecology_state')
check(not owns('wait_phase','crown_prep',enabled=False) and owns('wait_phase','crown_prep'),'inactive_ecology_has_no_crown_exemption')
# Existing failed actual evidence is retained and used only to assess the proposed interception.
failed_path=ROOT/'build/forest_depth/ecology/v15-consumer-formal-first/00-wait_phase/capture.json';failed=json.loads(failed_path.read_text());diagnosis=json.loads((freeze_path.parent/'diagnosis.json').read_text())
check(sha(failed_path)==diagnosis['capture_sha256'] and failed['failures']==['edge_tick_budget/26/ecology_start'] and len(failed['completed_legs'])==26 and len(failed['frames'])==3707,'actual_failure_bytes_and_original_budget_failure_retained')
check(min(f['health'] for f in failed['frames'])==5 and failed['itinerary'][26]['edge_id']=='crown_prep','actual_failure_is_live_stalled_owned_crown_encounter')
starts=[e for e in failed['events'] if e.get('kind')=='forest_encounter_start'];observed=[]
for e in starts:
 leg=failed['itinerary'][e['leg']];ownership=owns(failed['ecology_strategy'],leg['edge_id']);observed.append(dict(tick=e['tick'],enemy_id=e['enemy_id'],leg=e['leg'],edge=leg['edge_id'],ownership=ownership))
check(any(e['enemy_id']=='hollow_route__outer_watch' and e['ownership'] for e in observed),'new_guard_prevents_exact_observed_outer_watch_pilot_takeover')
check(any(e['enemy_id']=='hollow_route__borer_entry_thread' and not e['ownership'] for e in observed),'actual_unrelated_prefix_borer_combat_not_disabled')
check(any(e.get('kind')=='committed_damage' and e.get('target')=='hollow_route__outer_watch' and e.get('lethal') is True and str(e.get('source','')).startswith('player_projectile:') for e in failed['events']),'observed_wrong_owner_really_killed_comparison_target')
# Actual ordinary Lift negative/eligibility is not a generic lift-code failure.
lf=ROOT/freeze['lift_counterexample'];ld=json.loads(lf.read_text());check(ld['lift_started']==-1 and all(l.get('edge_id')!='outer_to_inner' for l in ld['itinerary']),'actual_ineligible_Lift_case_has_no_required_R_D_edge')
try:enemies.validate_lift_choice(ld)
except ValueError as e:lift_error=str(e)
else:lift_error=''
check(bool(lift_error),'original_strict_Lift_reader_rejects_native_terminal_without_actual_strategy',lift_error)
positive=ROOT/'build/region_bible_v2/ci-v15-matrix-first/14-map2-high_return/capture.json';pd=json.loads(positive.read_text());check(any(l.get('edge_id')=='outer_to_inner' for l in pd['itinerary']),'prior_actual_map2_hollow02_has_required_edge_for_new_preflight_only')
# The two newly added reader tests preserve the previous eight source controls.
test_source=Path('tests/test_forest_bible_trace_consumers.py').read_text();tree=ast.parse(test_source);ranges=[]
for cls in tree.body:
 if isinstance(cls,ast.ClassDef):
  for node in cls.body:
   if isinstance(node,ast.FunctionDef) and node.name in ('test_finite_v15_recipe_controls_keep_strict_reference_and_selected_mix','test_formal_recipe_gate_always_keeps_full_route_reader_first'):ranges.append((node.lineno,node.end_lineno))
lines=test_source.splitlines(keepends=True)
for start,end in sorted(ranges,reverse=True):
 del lines[start-1:end]
 while start-1<len(lines) and not lines[start-1].strip():del lines[start-1]
check(len(ranges)==2 and hashlib.sha256(''.join(lines).encode()).hexdigest()==freeze['source_sha256']['tests/test_forest_bible_trace_consumers.py'],'two_new_recipe_tests_only_previous8_source_bytes_exact')
# Restore only the finite version/ref branch and the whole old reader AST returns.
oldreader=(previous/'tools/run_forest_depth_enemies.py').read_text();newreader=Path('tools/run_forest_depth_enemies.py').read_text()
def functions(s):return {n.name:n for n in ast.parse(s).body if isinstance(n,ast.FunctionDef)}
a=functions(oldreader);b=functions(newreader);dump=lambda n:ast.dump(n,include_attributes=False)
check(set(a)==set(b) and len(a)==19 and [n for n in a if dump(a[n])!=dump(b[n])]==['validate_formal_choice'],'old19_reader_functions18_exact_only_finite_formal_recipe_branch_changes')
node=copy.deepcopy(b['validate_formal_choice']);start=next(i for i,n in enumerate(node.body) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='expected_ecology' for t in n.targets))
check(isinstance(node.body[start+1],ast.If) and 'forest-bible-world-v15' in ast.unparse(node.body[start+1]),'new_recipe_branch_limited_to_exact_actual15')
node.body[start:start+2]=[]
class Restore(ast.NodeTransformer):
 def visit_Name(self,n):return ast.Constant(value='compact-authored-ecology-v3') if n.id=='expected_ecology' else n
node=Restore().visit(node)
check(dump(node)==dump(a['validate_formal_choice']),'all_old_full_route_router_recipe_mix_event_assertions_AST_exact_after_branch_reversal')
check("contract != data['bible_admission']['reference_manifest'].get('encounter_plan_contract')" in newreader,'actual15_recipe_requires_full_exact_independently_validated_v14_reference')
# Independent short unit execution after the genuinely changed reader/test source.
argv=[sys.executable,'-m','unittest','test_forest_bible_trace_consumers'];started=time.monotonic()
with (OUT/'consumer10.log').open('w') as log:r=subprocess.run(argv,stdout=log,stderr=subprocess.STDOUT,timeout=15,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1','PYTHONPATH':str(ROOT/'tools')+':'+str(ROOT/'tests')})
text=(OUT/'consumer10.log').read_text();unit_seconds=time.monotonic()-started
check(r.returncode==0 and 'Ran 10 tests' in text and re.search('^OK$',text,re.M),'independent10_consumer_and_recipe_units')
# Complete actual native capture, no mocks, no rewritten flags/events/receipts.
fresh_path=ROOT/recipe['actual_capture'];fresh=json.loads(fresh_path.read_text());check(sha(fresh_path)==recipe['capture_sha256'],'complete_fresh_actual_capture_exact_original_bytes')
start=time.monotonic();enemies.validate_formal_choice(fresh);replay_seconds=time.monotonic()-start
check(len(fresh['frames'])==2293 and len(fresh['completed_legs'])==28 and fresh['ecology_started']==1907 and fresh['ecology_finished']==2229,'independent_full_actual_formal_reader_positive_without_mocks')
mutants=[]
def refuse(name,change):
 d=copy.deepcopy(fresh);change(d)
 try:enemies.validate_formal_choice(d)
 except (ValueError,KeyError,TypeError) as e:errors=str(e)
 else:errors=''
 check(bool(errors),'complete_actual_capture_negative/'+name,errors);mutants.append(dict(name=name,error=errors))
def coherent(key,value):
 def change(d):
  for m in (d['manifest'],d['bible_admission']['reference_manifest']):m['encounter_plan_contract'][key]=value
 return change
refuse('coherent_v3_masquerade_on_actual15',coherent('version','compact-authored-ecology-v3'))
refuse('coherent_unknown_future_recipe_version',coherent('version','compact-authored-ecology-v999'))
refuse('coherent_unconsumed_mix',coherent('mix_consumed',False))
refuse('coherent_integer1_cannot_pose_as_consumed_true',coherent('mix_consumed',1))
refuse('coherent_foreign_selected_mix',coherent('selected_mix',999))
refuse('actual_foreign_recipe_against_real_reference',lambda d:d['manifest']['encounter_plan_contract'].update(recipe='foreign_recipe'))
refuse('missing_actual_independent_reference',lambda d:d.pop('bible_admission'))
refuse('erase_actual_preview_keeps_route_completion',lambda d:d.update(events=[e for e in d['events'] if e.get('kind')!='ecology_actual_preview']))
refuse('erase_unsuppressed_landed_seed_zone_keeps_warning',lambda d:d.update(events=[e for e in d['events'] if e.get('kind')!='ecology_actual_seed_zone']))
refuse('erase_specialized_completion_keeps_native_terminal',lambda d:d.update(ecology_finished=-1))
receipts=[]
for name in ['v15-consumer-formal-first','v15-consumer-formal-second','v15-consumer-lift-first']:
 path=ROOT/'build/forest_depth/ecology'/name/'receipt.json';data=json.loads(path.read_text());check(data['source_guard'] is True and data['passed'] is False,'original_failed_native_receipt_no_source_drift_or_status_rewrite/'+name)
 receipts.append(dict(path=str(path.relative_to(ROOT)),sha256=sha(path),source_guard=data['source_guard'],passed=data['passed'],elapsed_seconds=data['elapsed_seconds'],failure_rows=[{k:r[k] for k in ('error','passed') if k in r} for r in data.get('formal_runs',data.get('lift_runs',[]))]))
check(sha(fresh_path)==recipe['capture_sha256'],'actual_capture_unchanged_after_positive_and_ten_mutations')
external=dict(status='RESOLVED_AND_INCLUDED_IN_LATEST5FILE_REVIEW',path='tools/run_forest_depth_enemies.py',initial_actual_recipe='compact-authored-ecology-v5',initial_previous_gate='compact-authored-ecology-v3',fix='Exact15 selectsv5 plus full reference equality; legacyv3 and all downstream assertions preserved',complete_actual_capture_independent_replay='PASS_no_mocks',actual_mutants_rejected=len(mutants))
after={p:sha(ROOT/p) for p in paths};check(before==after==combined,'all_five_reviewed_sources_remained_frozen')
for p in paths:
 target=OUT/'reviewed-source'/p;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((ROOT/p).read_bytes())
report=dict(verdict='ACCEPT_SCOPED_5PATH_SOURCE_AND_OFFLINE_ACTUAL_ECOLOGY',reviewer='/root/bible_test_workflow_independent_review',at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),scope='Finite v15 specialized encounter ownership and actual-edge-only Lift early rejection',engine_run=False,production_edits=False,source_before=before,source_after=after,freeze_receipt_sha256=sha(freeze_path),recipe_receipt_sha256=sha(recipe_path),checks=checks,actual_failed_capture=dict(path=str(failed_path.relative_to(ROOT)),sha256=sha(failed_path),ordinary_encounter_starts=observed),actual_Lift_negative=dict(path=str(lf.relative_to(ROOT)),sha256=sha(lf),errors=lift_error),actual_prior_Lift_eligible_capture=dict(path=str(positive.relative_to(ROOT)),sha256=sha(positive),scope='Recorded actual itinerary eligibility only, not new specialized strategy success'),independent_units=dict(count=10,argv=argv,exit_code=r.returncode,seconds=unit_seconds,log_sha256=sha(OUT/'consumer10.log')),independent_complete_actual_ecology=dict(path=str(fresh_path.relative_to(ROOT)),sha256=sha(fresh_path),seconds=replay_seconds,mutants=mutants),original_failed_native_receipts=receipts,offline_attempt_history_sha256=sha(OUT/'attempt-history.json'),external_finding=external,limitations=['No current native engine or specialized route executed by reviewer.','Only root fresh native+strict reader can prove each new specialized mode completes; whole-edge source controls do not prove physical success.','Prior 14path support pilot-body exact extraction claim is superseded solely by this new finite Grove drive override; its existing aim/UI/admission code remains exact.'])
(OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(dict(verdict=report['verdict'],checks=len(checks),unit_tests=10,external_finding=external)))
