import hashlib, json, re, subprocess
from pathlib import Path
R=Path('/workspace/gunman-rush'); BASE='840108da9ae91e412dc9f1d8a38ccdad0229bb11'
checks=[]
def check(label, condition):
 checks.append({'check':label,'passed':bool(condition)})
 if not condition: print('FAIL',label)
def read(p): return (R/p).read_text()
def sha(p): return hashlib.sha256((R/p).read_bytes()).hexdigest()
def body(s,name):
 m=re.search(r'^func '+re.escape(name)+r'\(',s,re.M); assert m,name
 n=re.search(r'^func ',s[m.end():],re.M)
 return s[m.start():m.end()+n.start()] if n else s[m.start():]
e=read('scripts/bosses/bellstrider_encounter.gd'); rig=read('scripts/bosses/bellstrider_rig_pose.gd'); p=read('scripts/bosses/bellstrider_presentation.gd'); a=read('scripts/audio/bellstrider_audio.gd'); app=read('scripts/demo/demo_app.gd'); d=read('scripts/bosses/windkeeper_damageable.gd'); rw=read('scripts/rewards/bellstrider_rewards.gd'); helper=read('tools/run_bellstrider_rework_01_tests.py')
select=body(e,'_select_group'); tick=body(e,'physics_tick'); health=body(e,'_health_changed'); shapes=body(e,'_update_combat_shapes')
check('HEAD is declared pre-iteration main baseline; current review is dirty leaf-bound',subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()==BASE)
check('real hull consumes shared painted polygon', 'PackedVector2Array(BellstriderRigPose.HULL_POINTS)' in e and '_poly(BellstriderRigPose.HULL_POINTS, INK)' in p)
check('eight hull vertices',len(re.findall(r'Vector2\(',rig.split('const HULL_POINTS := [',1)[1].split(']',1)[0]))==8)
check('wheel siblings deferred until parent is ready','motor.add_child.call_deferred(wheel)' in e and 'circle.radius = BellstriderRigPose.WHEEL_RADIUS' in e)
check('hull and contact follow body transform','hull_rig_ready' in shapes and ').transform = pose.body_transform' in shapes and 'pose.body_transform * Transform2D(0, _config().contact_offset)' in shapes)
check('both physical wheels follow rig transforms','pose.left_wheel if index == 0 else pose.right_wheel' in shapes)
check('actual upper core follows rendered bell transform','_core.transform = pose.get("bell_transform"' in shapes and 'draw_set_transform_matrix(pose.bell_transform)' in p)
check('physical geometry is disabled outside admitted combat', '_core.collision_layer = 4 if accepts_combat_damage() else 0' in shapes and 'motor.collision_layer = 4 if accepts_combat_damage() else 0' in shapes)
check('far prelude exits before RNG and group commit', select.index('_enter(&"approach"') < select.index('\n\t\treturn') < select.index('_rng.randf()') < select.index('_group = {'))
check('half health in empty approach immediately enters phase transition','if _phase_pending and mode == &"approach" and _group.is_empty():\n\t\t_start_phase_two()' in tick)
check('phase threshold based only on actual health','health.current <= health.capacity * _config().phase_two_health' in tick)
check('selected plan freezes phase, count and return selection before warning',all(x in select for x in ['"phase": stage_phase','"count": 2 if stage_phase == 2','chosen == &"roll" and stage_phase == 2 and _rng.randf()','_start_group_warning()']))
check('roll speed uses selected group phase','int(_group.get("phase", 1)) == 2' in tick)
check('half threshold never modifies selected attack before its completion', '_start_phase_two()' not in tick.split('&"roll_warning"',1)[1].split('&"phase_transition"',1)[0])
check('metrics not used as action conditions',not any(re.search(r'\b(?:if|elif|while).*'+name,tick+'\n'+select) for name in ['_accepted_hits','_accepted_damage','_groups_started','_groups_completed','pattern_index']))
check('accepted hit callback cannot restart action timers',not any(x in health for x in ['_enter(', 'clock =','clock +=','clock -=','_state_age =','_select_group(']))
check('physics rejects invalid and zero delta','if delta <= 0.0 or not is_finite(delta):' in tick)
check('launcher tracks only aim phase then locks', '_aim_launcher(locked_point)' in tick.split('&"lob_aim":',1)[1].split('&"lob_lock":',1)[0] and '_aim_launcher' not in tick.split('&"lob_lock":',1)[1].split('&"neck":',1)[0])
check('actual launch uses sampled muzzle tip','shot.global_position = motor.to_global(launcher * Vector2(25, -3))' in body(e,'_launch'))
check('terrain lookup uses player foot without Boss-centre clamp','var feet := _target.global_position + Vector2(0, 18)' in body(e,'_landing_for_target') and 'clampf' not in body(e,'_landing_for_target'))
check('lob duration has raised and lower-platform branches','lob_lower_flight_seconds' in body(e,'lob_duration_for') and 'lob_flight_seconds' in body(e,'lob_duration_for'))
check('projectile is bound before scene insertion',body(e,'_configure_projectile').index('shot.call("bind_attack", self, attack_epoch)')<body(e,'_configure_projectile').index('add_child(shot)'))
check('impact closure captures epoch and validates lifetime','var epoch := attack_epoch' in body(e,'_launch') and 'if not active or health.terminal or epoch != attack_epoch:' in body(e,'_lob_impact'))
for path in ['scripts/bosses/bellstrider_bell_projectile.gd','scripts/bosses/bellstrider_ring_projectile.gd']:
 s=read(path)
 check(path+': actual attack ownership includes weakref, active, terminal and epoch', all(x in body(s,'_owned') for x in ['_attack_owner.get_ref()','owner.active','not owner.health.terminal','owner.attack_epoch == _epoch']))
 check(path+': frozen contacts obey epoch', 'if not _owned():' in body(s,'advance_frozen_contact'))
ring=read('scripts/bosses/bellstrider_ring_projectile.gd'); bell=read('scripts/bosses/bellstrider_bell_projectile.gd')
check('local shock actual and visible extents both14 high','Vector2(width * 2.0, 14.0)' in ring and 'Rect2(-radius, -7, radius * 2.0, 14)' in ring)
check('lob physical first contact and one impact','space.cast_motion(query)' in bell and 'not _impact_emitted and _owned()' in bell and 'impacted.emit(point, normal)' in bell)
check('death immediately clears attacks/contact/movement',all(x in body(e,'_on_defeat') for x in ['_clear_attacks()','active = false','motor.stop()','motor.collision_layer = 0','motor.collision_mask = 0']))
check('three bounded death layers emitted once',all(x in body(e,'_advance_death') for x in ['not _death_jammed','not _death_impacted','not _death_finished','minf(_config().death_seconds']))
check('restore clears old attack epoch, restores group and no attack closures', '_clear_attacks()' in body(e,'restore_combat_state') and '_restored_group' in body(e,'restore_combat_state'))
check('presentation restores old motion + audio current epoch without cue replay',all(x in body(p,'synchronize_presentation') for x in ['motion.synchronize(encounter)','_objective_changed("")','service.bind(encounter, null, encounter.health.terminal)']))
check('audio restored terminal keeps future death layers only','_dying = restored_terminal' in a and '(_dying and cue not in DEATH)' in a)
check('terminal restore disables encounter before Health rebuild',all(x in body(e,'prepare_terminal_restore') for x in ['active = false','mode = &"dead"','motor.stop()','motor.collision_layer = 0']))
check('armour root refuses damage; core delegates canonical sink','if primary == null:\n\t\t\tencounter.armour_hit.emit' in d and 'return (primary as WindkeeperDamageable).receive_core(context)' in d)
check('live Bell packet proof requires actual actor faction session',all(x in app for x in ['admitted_packet = admitted_packet and int(context.get("source_actor_id",0)) == player.get_instance_id()','context.get("source_faction",&"") == &"player"','int(context.get("session_id",-1)) == controller.session_id']))
check('hook proof requires actual pull target + canonical ownership',all(x in body(app,'_bellstrider_hook_admitted') for x in ['traversal.state != &"hook_pull"','spatial.can_receive_effects()','spatial.damage_policy_owner() == receiver','traversal._serial','receiver.damage_epoch']))
check('reward lifecycle owns terminal priority and impact gate',all(x in body(app,'_settle_bellstrider_rewards') for x in ['director.stage_complete','controller.actor_resources.health.terminal','encounter.reward_impact_ready()']))
check('physical rewards idempotent and body-centred',all(x in rw for x in ['stage.region_state.drops.has(identity)','body * Vector2(0, 10)','PlainsLootMotion.units(output','stage.region_state.drops[identity] = output.duplicate(true)']))
check('portal cannot double-grant old12 coins for Bell','elif not wallet.grant(12,id): return false' in body(app,'_advance_region_map') and 'physical_coins := encounter is BellstriderEncounter' in body(app,'_advance_region_map'))
check('new native helper rejects all anchored engine errors', 'r"(?m)^ERROR:|RID allocations.*leaked"' in helper)
check('strict parent run_engine rejects script shader errors','SCRIPT ERROR:|Parse Error:|SHADER ERROR:' in read('tools/run_tests.py'))
unchanged=['scripts/player/player_motor.gd','scripts/player/jump_ability.gd','scripts/player/player_controller.gd','scripts/player/player_tuning.gd','resources/player/plains_shot_energy.tres','resources/player/combat_energy.tres','resources/player/traversal.tres','assets/underworld_plains/actors/bellstrider.png','assets/underworld_plains/actors/bell.png']
for path in unchanged:
 check('original bytes preserved: '+path,subprocess.check_output(['git','show',BASE+':'+path],cwd=R)==(R/path).read_bytes())
observed=[]
for path,marker in [('build/bellstrider_rework_01/native-combat-final-01.log','BELLSTRIDER_REWORK_COMBAT assertions=263 failures=0'),('build/bellstrider_rework_01/native-audio-pool-07.log','BELLSTRIDER_AUDIO_POOL assertions=110 failures=0')]:
 s=read(path); ok=marker in s and not re.search(r'(?m)^ERROR:|SCRIPT ERROR:|RID allocations.*leaked|ObjectDB instances.*leaked',s)
 check('observed clean prior native log: '+path,ok); observed.append({'path':path,'sha256':sha(path),'marker':marker,'executed_by_reviewer':False,'exact_current_source_inventory_binding':False})
old='build/bellstrider_rework_01/native-combat-current-01.log'; check('failed parent-busy/leak run retained without reclassification','ERROR: Parent node is busy' in read(old) and 'failures=1' in read(old))
paths=['docs/worklines/bellstrider_rework_01/spec.md','scripts/bosses/bellstrider_encounter.gd','scripts/bosses/bellstrider_definition.gd','scripts/bosses/bellstrider_rig_pose.gd','scripts/bosses/bellstrider_presentation.gd','scripts/bosses/bellstrider_bell_projectile.gd','scripts/bosses/bellstrider_ring_projectile.gd','scripts/bosses/windkeeper_damageable.gd','scripts/bosses/windkeeper_encounter.gd','scripts/combat/damageable.gd','scripts/combat/weapon_action_runtime.gd','scripts/items/v5/item_runtime.gd','scripts/items/v5/item_active_effects.gd','scripts/items/v5/item_combat_effects.gd','scripts/items/v5/item_companion_effects.gd','scripts/player/traversal_ability.gd','scripts/audio/game_audio.gd','scripts/audio/bellstrider_audio.gd','scripts/demo/demo_app.gd','scripts/demo/plains_region_stage.gd','scripts/rewards/bellstrider_rewards.gd','scripts/ui/windkeeper_hud.gd','scripts/art/plains_stage_visual.gd','resources/bosses/bellstrider.tres','resources/bosses/bellstrider_health.tres','tools/run_bellstrider_rework_01_tests.py']
result={'reviewer':'/root/guard_review_recovery','implementers':['/root','/root/bellstrider_combat','/root/boss_motion','audio/binding implementation agents'],'independence':'No reviewed production authored by reviewer. Reviewer-authored damage_policy.gd and86/0 explicitly excluded.','baseline_commit':BASE,'source_state':'Uncommitted working tree; leaf SHA bound, not Git-clean/native-current receipt.','verdict':'BOUNDED_SOURCE_PREFLIGHT_ACCEPT' if all(c['passed'] for c in checks) else 'REWORK','checks':checks,'passed':sum(c['passed'] for c in checks),'failed':sum(not c['passed'] for c in checks),'reviewed_files':[{'path':x,'sha256':sha(x)} for x in paths],'observed_native_evidence':observed,'preserved_failure':{'path':old,'sha256':sha(old)},'limits':['No engine/Godot run by reviewer.','No current full-seven or latest R3-full native result signed.','New3 half-health chase assertions pending execution.','No final GUI/audio film, natural20group/third-shot fairness, subjective art/listening/device/user or G1-G5 acceptance.','Metadata96 binding handled separately; prior94 review not silently extended.'],'actual_command':'python3 /tmp/review_bellstrider_production_final_preflight.py','script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
Path('/tmp/bellstrider-production-final-preflight.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'verdict':result['verdict'],'passed':result['passed'],'failed':result['failed'],'files':len(paths)}))
