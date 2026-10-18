from pathlib import Path
import hashlib,json,subprocess,re
R=Path.cwd();O=R/'build/forest_depth/independent/v9-integration';S=R/'build/forest_depth/snapshots/forest-v9-golden13';T=R/'build/forest_depth/snapshots/forest-v9-golden14'
paths=['scripts/enemies/forest_crossbranch_behavior.gd','scripts/enemies/forest_crossbranch_behavior.gd.uid','scripts/enemies/forest_crossbranch_presentation.gd','scripts/enemies/forest_crossbranch_presentation.gd.uid','resources/enemies/forest_crossbranch.tres','scenes/enemies/forest_crossbranch.tscn','scripts/demo/demo_app.gd','scripts/demo/thorn_forest_region_stage.gd','scripts/enemies/enemy_actor.gd','scripts/enemies/forest_enemy_definition.gd','scripts/generation/stage_camera_rig.gd','scripts/generation/thorn_forest_region_v2.gd','scripts/bosses/thorn_queen_weave_band.gd']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();start={p:sha(R/p)for p in paths};bindings={p:{'current_sha256':start[p],'snapshot13_sha256':sha(S/p),'snapshot14_sha256':sha(T/p),'identical13':(R/p).read_bytes()==(S/p).read_bytes(),'identical14':(R/p).read_bytes()==(T/p).read_bytes()}for p in paths}
assert all(v['identical13']and v['identical14']for p,v in bindings.items()if p!='scripts/generation/thorn_forest_region_v2.gd')
g=(R/'scripts/generation/thorn_forest_region_v2.gd').read_text();old=(T/'scripts/generation/thorn_forest_region_v2.gd').read_text();a=old.index('func _routes(');b=old.index('func _phrase(',a);x=g[:g.index('func _routes(')]+old[a:b]+g[g.index('func _phrase(',g.index('func _routes(')):];assert x==old
app=(R/'scripts/demo/demo_app.gd').read_text();behavior=(R/'scripts/enemies/forest_crossbranch_behavior.gd').read_text();stage=(R/'scripts/demo/thorn_forest_region_stage.gd').read_text();presentation=(R/'scripts/enemies/forest_crossbranch_presentation.gd').read_text()
assert 'configure_shores(configured_shores,not restoring)'in app and 'not actor.attack_behavior is ForestCrossbranchBehavior'in app
assert 'actor.attack_behavior.call("restore_depth_state",saved.depth_state)'in app
assert 'region_state.actors[enemy_manifest[i].id].depth_state = attack.call("depth_snapshot")'in stage
assert 'actor.motor.global_position ='not in behavior and 'actor.motor.position ='not in behavior
assert 'return actor.motor.move_attack(motion,false,delta)'in behavior
assert behavior.index('obstruction_body=null\n\tstate=StringName(saved.state)')>behavior.index('if saved.state=="grounded_recovery" and support.is_empty():return false')
assert not re.search(r'receive_damage|submit\(|move_attack|global_position\s*=',presentation)
# Existing Player/economy/combat definitions are unchanged in the current dirty delta.
unchanged=subprocess.check_output(['git','diff','--name-only','HEAD','--','scripts/player','scripts/combat','scripts/damage','resources/player'],text=True).splitlines();assert not unchanged
# Preserve the reviewed exact diff and all scoped source bytes for later attribution.
(O/'production-tracked.diff').write_bytes(subprocess.check_output(['git','diff','--',*paths]))
for p in paths:
 q=O/'source'/p;q.parent.mkdir(parents=True,exist_ok=True);q.with_name(q.name+'.txt').write_bytes((R/p).read_bytes())
assert start=={p:sha(R/p)for p in paths}
result={'status':'CONTINUE_BOUNDED_V9_INTEGRATION_SOURCE','reviewer':'/root/forest_runtime_review','observed_HEAD':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'worktree_overlay_not_committed_clean':True,'native_run':False,'source_bindings':bindings,'no_current_Player_economy_damage_production_delta':True,'main_vs14_only_routes_function_delta':True,'scope_files_unchanged_during_audit':True,'historical_proofs':['queen-inactive-save13 exact narrow configure-angle review','sealed13 actual formal NPC save/reload/cancel/death checks26 with16 malformed cases','sealed14 same integration source presentation capture only, no new lifecycle proof claimed'],'unverified':['Latest recommended cache-to-N-to-gate route actual Motor replay','Current v9 full80 matrix and all eligible seeds','Physical route entry root-variant coverage beyond existing explicit case evidence','All adversarial semantically impossible saved phase/position combinations','Boss mechanics/fun, final source CI, browser/device/human playtest'],'authorship_boundary':'Reviewer authored early formal base drivers; no original driver logic or test authoring approved here; new production integration authored by root/ecology.'}
(O/'review.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'status':result['status'],'bound_source_files':len(bindings),'unverified':result['unverified']},indent=2))
