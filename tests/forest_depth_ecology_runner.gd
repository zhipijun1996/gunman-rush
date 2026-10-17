extends SceneTree
const TRACE := preload("res://tests/forest_depth_ecology_trace.gd")
var seed_value := "forest-depth-00"
var map_index := 1
var strategy_name := "wait_phase"
var route_name := "fast"
var output := "res://build/forest_depth/region/capture.json"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_value=arg.trim_prefix("--seed=")
		elif arg.begins_with("--strategy="): strategy_name=arg.trim_prefix("--strategy=")
		elif arg.begins_with("--map="): map_index=int(arg.trim_prefix("--map="))
		elif arg.begins_with("--route="): route_name=arg.trim_prefix("--route=")
		elif arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	var trace:=TRACE.new()
	trace.ecology_strategy=strategy_name
	trace.seed_value=seed_value;trace.map_index=map_index;trace.route_name=route_name
	root.add_child(trace)
	if strategy_name=="crossbranch_lifecycle":
		await run_crossbranch_lifecycle(trace)
	else:
		while not trace.finished or not trace.setup_done: await process_frame
	trace.set_physics_process(false)
	if is_instance_valid(trace.controller):
		trace.controller.router.clear("forest_depth_capture_sealed")
		trace.controller.router.set_jump_held(&"forest_depth_route",false)
	var data: Dictionary={"schema_version":1,"ecology_strategy":strategy_name,"ecology_started":trace.ecology_started,"ecology_finished":trace.ecology_finished,"ecology_entry":trace.ecology_entry.duplicate(true),"ecology_exit":trace.ecology_exit.duplicate(true),"scope":"formal_DemoApp_forest_v2_continuous_route_not_boss_fight","ecology_scope":"actual_DemoApp_M_S_rising_thread_choice_not_full_region_admission" if strategy_name.begins_with("entry_") else "actual_DemoApp_W_M_side_seed_choice_not_full_region_admission" if strategy_name.begins_with("west_") else "actual_DemoApp_seed_recipe_crown_pair_choice_not_full_region_admission","seed":seed_value,"map_index":map_index,"route":route_name,"engine":Engine.get_version_info().string,"manifest":trace.manifest.duplicate(true),"itinerary":trace.itinerary.duplicate(true),"completed_legs":trace.completed.duplicate(true),"frames":trace.frames.duplicate(true),"events":trace.events.duplicate(true),"requests":trace.requests.duplicate(true),"failures":trace.failures.duplicate(),"initial_snapshot":trace.initial.duplicate(true),"final_snapshot":trace.snapshot() if is_instance_valid(trace.player) and is_instance_valid(trace.controller) else {},"modal_frames":trace.modal_frames.duplicate(true),"pointer_events":trace.pointer_events.duplicate(true),"claim_before":trace.claim_before.duplicate(true),"claim_after":trace.claim_after.duplicate(true),"cache_claimed":trace.cache_claimed,"duplicate_checked":trace.duplicate_checked,"duplicate_before":trace.duplicate_before.duplicate(true),"duplicate_after":trace.duplicate_after.duplicate(true),"manual_motor_step":false,"position_or_resource_injection":false,"tick_budget":18000,"edge_tick_budget":1800,"boss_fight_covered":false}
	if strategy_name.begins_with("crossbranch_"):
		data.scope="formal_DemoApp_forest_v2_continuous_route_not_boss_fight" if trace.crossbranch_formal else "candidate_DemoApp_geometry_overlay_not_current_formal_admission"
		data.crossbranch_formal=trace.crossbranch_formal
		data.lifecycle=lifecycle.duplicate(true)
		data.ecology_scope="candidate_NPC_physical_roundtrip_and_actual_camera_only" if strategy_name=="crossbranch_physics" else "candidate_actual_MONSTER_contact_Player_obstruction_and_static_recovery_only" if strategy_name=="crossbranch_contact_recovery" else "candidate_same_reward_crossbranch_exploration_and_actual_return_to_gate"
		if trace.crossbranch_formal:data.ecology_scope="actual_generated_crossbranch_complete_optional_reward_route"
		data.candidate_first_free=trace.crossbranch_first_free
		data.candidate_R_count=trace.crossbranch_R_count
		data.candidate_one_R_failed=trace.crossbranch_one_R_failed
		data.candidate_setup_shots=trace.crossbranch_setup_shots
		data.candidate_overlay=trace.crossbranch_candidate.duplicate(true)
		data.candidate_started=trace.crossbranch_started;data.candidate_finished=trace.crossbranch_finished
		data.candidate_camera=trace.crossbranch_camera.duplicate(true)
		data.candidate_NPC_ledger=trace.crossbranch_actor.attack_behavior.get("ledger").duplicate(true) if is_instance_valid(trace.crossbranch_actor) else []
	if is_instance_valid(trace.stage):
		data["claimed_ids"]=trace.stage.region_state.claimed.keys()
		data["visited_areas"]=trace.stage.region_state.visited.duplicate(true)
		data["gate_saved_open"]=trace.stage.region_state.opened.has("crown_vine")
		data["gate_shape_disabled"]=trace.stage.assembler.vine_shape.disabled
		data["actual_stage_map"]=trace.stage.map_index
		data["actual_stage_version"]=trace.stage.generated.stage_generator_version
	var audio_ok:=true
	if is_instance_valid(trace.app):
		# Payload already detached. Quiesce ordinary gameplay only during teardown.
		trace.app.process_mode=Node.PROCESS_MODE_DISABLED
		trace.app._cancel_enemy_attacks()
		audio_ok=await preload("res://tests/audio_teardown.gd").drain_world(trace.app)
	data["audio_released"]=audio_ok
	if not audio_ok: data.failures.append("actual_audio_teardown_failed")
	trace.free()
	await process_frame;await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null: push_error("forest_v2_capture_write_failed");quit(1);return
	file.store_string(JSON.stringify(data));file.close()
	print("FOREST DEPTH ROUTE: %s map%s %s / %s legs / %s frames / %s failures"%[seed_value,map_index,route_name,data.completed_legs.size(),data.frames.size(),data.failures.size()])
	quit(0 if data.failures.is_empty() else 1)

var lifecycle: Array[Dictionary]=[]
func life_check(ok: bool, name: String, facts: Dictionary={}) -> void:
	lifecycle.append({"check":name,"passed":ok,"facts":facts.duplicate(true)})
	if not ok:push_error("crossbranch lifecycle: "+name)

func run_crossbranch_lifecycle(trace: Node) -> void:
	while not trace.setup_done or (trace.leg_index<2 and not trace.finished):await process_frame
	trace.set_physics_process(false);trace.initialized=false
	if not trace.failures.is_empty() or not trace.crossbranch_formal:
		trace.fail("lifecycle_requires_actual_generated_actor");return
	trace.controller.router.clear("crossbranch_lifecycle")
	var app: DemoApp=trace.app
	var actor: EnemyActor=trace.crossbranch_actor
	var behavior: ForestCrossbranchBehavior=actor.attack_behavior
	for i: int in 1200:
		if behavior.state==&"flight" and behavior.state_time>=.1:break
		await process_frame
	life_check(behavior.state==&"flight","real_flight_save_entry")
	if behavior.state!=&"flight":trace.fail("lifecycle_no_actual_flight");return
	app._pause_for_menu()
	app.stage.capture_state()
	var id: String=trace.manifest.crossbranch_contract.enemy_id
	var saved: Dictionary=app.region_state.actors[id].duplicate(true)
	var before: Dictionary=behavior.depth_snapshot()
	var position: Vector2=actor.motor.global_position
	var hp: float=actor.health.current
	for i: int in 4:await process_frame
	life_check(behavior.depth_snapshot()==before and actor.motor.global_position==position,"real_menu_pause_freezes_actor")
	var malformed: Array[Dictionary]=[{"version":true},{"time":"bad"},{"time":-1},{"shore":true},{"shore":2},{"committed":3},{"velocity":null},{"velocity":[INF,0]},{"motor_velocity":[0]},{"serial":.5},{"supported_frames":-1},{"recovery_budget_failed":1},{"obstruction":[]},{"recovery_support":[]},{"state":"hover_forever"},{"shores":[]}]
	for patch: Dictionary in malformed:
		var bad:=before.duplicate(true)
		bad.merge(patch,true)
		life_check(not behavior.restore_depth_state(bad) and behavior.depth_snapshot()==before and actor.health.current==hp and actor.motor.global_position==position,"atomic_reject_"+str(patch.keys()[0]),patch)
	var old_stage: int=app.stage.get_instance_id()
	var old_epoch: int=app.lifetime.actor_epoch
	# Preserve the actual complete pre-reload state even if another world's
	# actor rejects its own restore and the strict native runner aborts early.
	var diagnostic: Dictionary={"lifecycle":lifecycle.duplicate(true),"actor_saved":saved.duplicate(true),"region_state":app.region_state.snapshot(),"paused":paused}
	var queen: Node=app.stage.boss.get_node("Encounter")
	diagnostic.boss_valid_before_reload=queen.call("valid_duel_snapshot",app.region_state.boss_state) if queen.has_method("valid_duel_snapshot") else null
	var checkpoint:=FileAccess.open(output.get_basename()+"-before-reload.json",FileAccess.WRITE)
	if checkpoint!=null:checkpoint.store_string(JSON.stringify(diagnostic));checkpoint.close()
	# The existing actual App unload/capture/regenerate/configure/restore path.
	await app._load_stage()
	if not is_instance_valid(app.stage) or not is_instance_valid(app.player) or not app.lifetime.active:
		trace.fail("lifecycle_actual_App_reload_rejected");return
	trace.stage=app.stage;trace.player=app.player;trace.controller=app.controller
	trace.crossbranch_formal=false
	life_check(trace._bind_recorded_crossbranch(),"real_App_rebinds_recorded_actor")
	actor=trace.crossbranch_actor;behavior=actor.attack_behavior
	life_check(app.stage.get_instance_id()!=old_stage and app.lifetime.actor_epoch>old_epoch and actor.health.current==hp and actor.motor.global_position==position and behavior.depth_snapshot()==saved.depth_state,"actual_App_reload_preserves_midair_phase_velocity_HP",{"saved":saved,"actual":behavior.depth_snapshot(),"position":trace.pair(actor.motor.global_position)})
	app._resume_from_menu()
	var previous: Vector2=actor.motor.global_position
	for i: int in 2:await process_frame
	life_check(actor.motor.global_position!=previous and behavior.state==&"flight","restored_actor_resumes_real_motion")
	var cancel_velocity: Vector2=behavior.flight_velocity
	app._cancel_enemy_attacks()
	life_check(behavior.state==&"cancelled_fall" and behavior.flight_velocity==cancel_velocity,"real_App_cancel_retains_physical_velocity")
	for i: int in 1500:
		if behavior.current_shore==0 and behavior.state==&"rest" and behavior._on_shore(0):break
		if behavior.recovery_budget_failed:break
		await process_frame
	life_check(not behavior.recovery_budget_failed and behavior.current_shore==0 and behavior.state==&"rest" and behavior._on_shore(0),"cancel_lands_on_real_support_and_resumes_cycle",{"depth":behavior.depth_snapshot(),"ledger":behavior.ledger.duplicate(true)})
	# Reload resets the player's stage entrance through the real App. Traverse
	# the original W→N edge again using its existing Router driver before firing.
	trace.leg_index=1;trace.leg_started=trace.tick+1;trace.set_phase("align")
	trace.initialized=true;trace.set_physics_process(true)
	while trace.leg_index<2 and not trace.finished:await process_frame
	trace.set_physics_process(false);trace.initialized=false;trace.controller.router.clear("crossbranch_lifecycle_shoot")
	var accepted_damage: Array[Dictionary]=[]
	app.policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
		for result: DamageResult in results:
			if String(result.request.target_id)==id:accepted_damage.append({"source":String(result.request.source_id),"amount":result.request.amount,"lethal":result.lethal,"health":result.health.current}))
	var last_shot := -1000
	var shots := 0
	for i: int in 1500:
		trace.controller.router.set_move_axis(clampf((112-trace.player.global_position.x)/12,-1,1))
		if actor.health.terminal:break
		if behavior.state==&"rest" and behavior.current_shore==0 and trace.full_support("north_court") and absf(trace.player.global_position.x-112)<7 and trace.controller.shoot_ability.cooldown_remaining<=0 and i-last_shot>=30:
			trace.request(&"shoot_release",trace._crossbranch_predict_aim(trace.player.tuning.projectile_speed));last_shot=i;shots+=1
		await process_frame
	life_check(actor.health.terminal and accepted_damage.size()==3 and shots>=3 and accepted_damage.all(func(row: Dictionary) -> bool:return row.source.begins_with("player_projectile:") and row.amount==1),"actual_ordinary_projectile_death",{"damage":accepted_damage,"requested_shots":shots})
	app._pause_for_menu();app.stage.capture_state()
	var dead_at: Vector2=actor.motor.global_position
	await app._load_stage()
	if not is_instance_valid(app.stage) or not is_instance_valid(app.player) or not app.lifetime.active:
		trace.fail("lifecycle_actual_App_dead_reload_rejected");return
	trace.stage=app.stage;trace.player=app.player;trace.controller=app.controller;trace.crossbranch_formal=false
	life_check(trace._bind_recorded_crossbranch(),"dead_App_actor_rebind")
	actor=trace.crossbranch_actor;behavior=actor.attack_behavior
	life_check(actor.health.terminal and actor.motor.global_position==dead_at and not actor.is_physics_processing() and actor.motor.collision_layer==0 and behavior.state==&"blocked","dead_Actor_reload_never_restarts_migration")
	app._resume_from_menu()
	for row: Dictionary in lifecycle:
		if not row.passed:trace.fail("lifecycle/"+row.check)
	trace.finished=true
