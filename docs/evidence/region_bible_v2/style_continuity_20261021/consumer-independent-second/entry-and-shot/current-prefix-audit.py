from pathlib import Path
import ast,copy,hashlib,json,subprocess,sys,math,re
ROOT=Path.cwd();sys.path[:0]=[str(ROOT/'tools')];import run_forest_depth_enemies as en
out=ROOT/'build/region_bible_v2/entry-shot-roundoff-independent-review-first';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();base='083fbdc4a29a9d26c99b89bd5f2d506b3a88fcdb';paths=['tests/forest_bible_ecology_trace.gd','tests/test_forest_bible_trace_consumers.py','tools/run_forest_depth_region.py','tests/test_forest_bible_shot_provenance.py','tests/forest_depth_grove_combat_case.gd','tests/forest_bible_trace_support.gd'];before={p:sha(p)for p in paths};checks=[]
def ck(ok,label,details=None):
 checks.append(dict(passed=bool(ok),label=label,details=details))
 if not ok:raise AssertionError(label)
s=Path(paths[0]).read_text();body=s.split('func _entry_prefix_owns_leg(leg: Dictionary) -> bool:\n',1)[1].split('\nfunc ',1)[0];filt=s.split('func preserves_strategy_target(enemy_id: String) -> bool:\n',1)[1].split('\nvar ',1)[0];namespace=dict(map_index=1,ecology_finished=-1,ecology_strategy='entry_wait');exec('def owns(leg):\n'+body,namespace);exec('def reserved(enemy_id):\n'+filt,namespace)
leg=dict(edge_id='west_to_belly',kind='jump_gap',from_support_id='west_court',support_id='hollow__belly_entry')
finite=[]
for mode in en.FORMAL_STRATEGIES:
 for mapno in (1,2):
  for finished in (-1,100):
   for edge in ('west_to_belly','belly_borer_access','crown_prep','unrelated'):
    namespace.update(ecology_strategy=mode,map_index=mapno,ecology_finished=finished)
    got=namespace['owns']({**leg,'edge_id':edge});expected=mapno==1 and finished<0 and mode in ('entry_clear','entry_wait','entry_hold') and edge=='west_to_belly'
    if got!=expected:raise AssertionError((mode,mapno,finished,edge))
    finite.append(dict(mode=mode,map=mapno,finished=finished,edge=edge,owned=got))
ck(True,'finite_mode_map_finished_edge_dispatch_exact',len(finite))
for mode in en.FORMAL_STRATEGIES:
 for finished in (-1,100):
  namespace.update(ecology_strategy=mode,ecology_finished=finished)
  for enemy in ('hollow_route__borer_entry_thread','hollow_route__outer_watch','other'):
   ck(namespace['reserved'](enemy)==(finished<0 and mode in ('entry_clear','entry_wait','entry_hold') and enemy=='hollow_route__borer_entry_thread'),'reservation_'+mode+'_'+str(finished)+'_'+enemy)
namespace.update(map_index=1,ecology_finished=-1,ecology_strategy='entry_wait')
for key,bad in [('kind','walk'),('from_support_id','bad'),('support_id','bad')]:ck(not namespace['owns']({**leg,key:bad}),'other_'+key+'_uses_inherited_jump')
drive=s.split('func drive_jump(leg: Dictionary) -> void:\n',1)[1]
ck(drive.startswith('\tif not _entry_prefix_owns_leg(leg):\n\t\tsuper.drive_jump(leg);return'),'all_unowned_prefixes_immediately_super')
ck('if _entry_prefix_state!="bank" and age>120:'in drive,'original120_jump_timeout_retained')
ck('subject.attack_behavior.state!=&"recovery" or d.recovery_duration-subject.attack_behavior.state_time<flight_bound' in drive,'wait_for_observed_real_recovery_and_tuning_bound')
ck('subject.health.current!=_entry_prefix_subject_hp'in drive and 'subject.health.terminal'in drive,'live_subject_and_unchanged_actual_health_guard')
ck('not _entry_prefix_drop_requested and player.is_on_floor() and full_support("borer_access_low")'in drive,'single_drop_only_real_grounded_full_low_support')
ck('jump(false);request(&"drop_through");_entry_prefix_drop_requested=true'in drive,'real_ordinary_once_drop_action')
ck(not re.search(r'\bage\s*=|\bleg_started\s*=|player\.global_position\s*=|health\.current\s*=|attack_behavior\.state\s*=',drive),'no_direct_body_health_enemy_or_clock_assignment')
ck('player.global_position.x-half.x>float(low.rect[0])+float(low.rect[2])+.5 and player.global_position.y-half.y>float(low.rect[1])+float(low.rect[3])+1'in drive,'handoff_requires_full_body_right_and_below_actual_low_branch')
ck('request(&"shoot_release",Vector2(-1,1))'in drive,'valid_real_diagonal_retained')
ck('prefix uses legal jump/recoil/one-way recovery before original final landing checks.'in s,'scope_comment_explicitly_acknowledges_new_intermediate_prefix')
for p in ['tests/forest_depth_ecology_trace.gd','tests/forest_depth_lift_trace.gd','tests/forest_depth_region_trace.gd','scripts/player/player_motor.gd','config/player_tuning.json','resources/player/traversal.tres','scripts/input/keyboard_mouse_adapter.gd']:
 ck(Path(p).read_bytes()==subprocess.check_output(['git','show',base+':'+p]),'historical_driver_or_physics_byte_exact/'+p)
# The numerical change is limited to direction comparison: exact causal bind is still present.
reader=Path('tools/run_forest_depth_region.py').read_text();ck("r.get('kind')=='shoot_release' and r.get('tick')==e['tick'] and r.get('queued') is True and same_shot_direction(r.get('aim'),e.get('aim'))"in reader,'same_actual_kind_tick_and_queued_binding')
ck("fail('shot_not_actual_router_request')"in reader,'original_assertion_label_retained')
# Fresh whole-entry native evidence, including actual empty-layout argv.
d=ROOT/'build/forest_depth/ecology/v15-consumer-entry-fifth-unpinned';receipt=json.loads((d/'receipt.json').read_text());cp=d/'00-entry_wait/capture.json';data=json.loads(cp.read_text());en.validate_formal_choice(data)
ck(receipt['source_guard']is True and receipt['passed']is True,'fresh_original_cli_wrapper_and_source_guard_pass')
ck(data['manifest']['layout_version']=='forest-bible-world-v15' and data['manual_motor_step']is False and data['position_or_resource_injection']is False,'actual_v15_and_real_motor_no_injection')
ck(len(data['completed_legs'])==29 and len(data['frames'])==2096 and min(x['health']for x in data['frames'])==5,'actual29_2096_health5')
for p in paths:ck(sha(p)==before[p],'source_stable_during_review/'+p)
for p in paths:
 target=out/'current-reviewed-source'/p;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(Path(p).read_bytes())
result=dict(verdict='ACCEPT_SCOPED_CURRENT_PREFIX_SOURCE_AND_ACTUAL_ENTRY_WAIT_ONLY',checks=checks,finite_dispatch=finite,source_sha256=before,actual_capture=str(cp.relative_to(ROOT)),actual_capture_sha256=sha(cp),actual_receipt_sha256=sha(d/'receipt.json'),actual_receipt_scope={k:receipt[k]for k in ['passed','source_guard']},limitations=['New15 entry prefix explicitly changes intermediate strategy with legal real inputs; it does not apply all old intermediate ceiling/wrong-support assertions before its eventual super handoff','Historical driver checks/budgets/physics preserved; original final twelve-frame landing and full route reader passed on actual current entry_wait','Only entry_wait proven here; entry_clear and entry_hold remain source-only','No engine/source edits by reviewer; no claim for full80 current corpus or art'])
(out/'current-prefix-review.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'checks':len(checks),'finite_dispatch':len(finite),'verdict':result['verdict']}))
