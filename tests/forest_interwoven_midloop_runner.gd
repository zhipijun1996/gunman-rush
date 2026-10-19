extends SceneTree
## Explicit initial-spawn golden fixture, never formal full-route admission.
class FixtureApp extends "res://scripts/demo/demo_app.gd":
	var fixture_data: Dictionary = {}
	var fixture_error := ""
	var fixture_kind := "arch"
	func _load_stage() -> void:
		super._load_stage()
		if player.motion_steps != 0:
			fixture_error="fixture_refused_after_Motor_step";return
		if not is_instance_valid(stage):fixture_error="fixture_actual_stage_missing";return
		var pose := Vector2.ZERO
		for area: Dictionary in stage.generated.manifest.areas:
			if str(area.id)==("interwoven_deep_basin" if fixture_kind=="basin" else "broken_arch_crown"):pose=Vector2(area.position[0],area.position[1])
		if pose==Vector2.ZERO:fixture_error="fixture_actual_area_missing";return
		fixture_data={"initial_fixture_spawn_override":true,"original_formal_spawn":[player.global_position.x,player.global_position.y],"actual_fixture_pose":[pose.x,pose.y],"motion_steps_before_override":player.motion_steps,"production_sha_before_override":FileAccess.get_sha256("res://scripts/generation/forest_interwoven_expedition.gd"),"lifecycle":"after actual synchronous _load_stage assembly before first physics"}
		player.global_position=pose
class FixtureTrace extends "res://tests/forest_player_aim_trace.gd":
	var fixture_data: Dictionary = {}
	var fixture_kind := "arch"
	func begin() -> void:
		var script: Script=load("res://scripts/demo/demo_app.gd")
		if script==null or not script.can_instantiate(): fail("DemoApp_compile_failed");setup_done=true;return
		app=FixtureApp.new();app.fixture_kind=fixture_kind;app.meta_persistence_enabled=false;add_child(app)
		if not app.start_debug_region(&"thorn_forest",map_index,seed_value,ThornForestRegionGenerator.DEPTH_VERSION,recorded_layout_version): fail("formal_debug_entry_rejected");setup_done=true;return
		for unused: int in 8: await get_tree().physics_frame
		fixture_data=app.fixture_data.duplicate(true)
		if not app.fixture_error.is_empty():fail(app.fixture_error);setup_done=true;return
		stage=app.stage
		if not is_instance_valid(stage) or not stage.assembly_ok: fail("formal_v2_assembly_failed");setup_done=true;return
		player=app.player;controller=app.controller
		manifest=stage.generated.manifest.duplicate(true)
		if manifest.get("version")!=ThornForestRegionGenerator.DEPTH_VERSION or manifest.get("map_index")!=map_index or manifest.get("seed")!=ThornForestRegionGenerator.seed_for(seed_value,map_index): fail("actual_stage_identity_mismatch");setup_done=true;return
		player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
		var route_ids: Array=["interwoven_deep_ascent"] if fixture_kind=="basin" else ["interwoven_deep_descent","interwoven_deep_ascent"]
		if route_name=="upper_noH": route_ids=["arrival_reading","upper_out"]
		for id: String in route_ids:
			var edge: Dictionary={}
			for row: Dictionary in manifest.connections:
				if row.id==id: edge=row.duplicate(true)
			if edge.is_empty(): fail("missing_manifest_edge/"+id);break
			if edge.kind=="ordinary_sequence":
				for i: int in edge.steps.size():
					var step: Dictionary=edge.steps[i].duplicate(true);step.edge_id=id;step.step_index=i
					if i==0:
						for key: String in ["claim_before_edge","claim_area","claim_id"]:
							if edge.has(key): step[key]=edge[key]
					itinerary.append(step)
				itinerary.append({"kind":"walk","edge_id":id,"landing":edge.path[-1].duplicate(),"step_index":edge.steps.size()})
				if manifest.get("layout_version") in ["forest-expedition-airborne-v11","forest-woven-trunk-v12","forest-interwoven-canopy-v13"]:itinerary[-1].b=edge.b
			else:
				edge.edge_id=id;edge.landing=edge.get("landing",edge.path[-1]).duplicate();itinerary.append(edge)
				if edge.has("post_landing_steps"):
					for i: int in edge.post_landing_steps.size():
						var step: Dictionary=edge.post_landing_steps[i].duplicate(true);step.edge_id=id;step.step_index=i;step.post_landing=true;itinerary.append(step)
				if edge.kind=="hollow_recovery": itinerary.append({"kind":"walk","edge_id":id,"landing":edge.path[-1].duplicate(),"post_recovery_align":true})
		if itinerary.is_empty(): fail("empty_manifest_itinerary")
		controller.traversal.action_changed.connect(_hook_event)
		controller.jump_ability.jumped.connect(func() -> void: event("jumped"))
		controller.shoot_ability.shot_fired.connect(func(aim: Vector2,serial: int) -> void:
			event("shot_fired",{"aim":pair(aim),"serial":serial})
			observe_actual_projectile(serial))
		controller.energy_recovered.connect(func(amount: float,airborne: bool) -> void:
			event("actual_shot_energy_credit",{"amount":amount,"fired_airborne":airborne,"owner_id":player.get_instance_id(),"session_id":controller.session_id,"hits":controller.shot_energy._hits.duplicate(true),"energy":controller.actor_resources.stamina.current}))
		app.policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
			for result: DamageResult in results: event("committed_damage",{"target":String(result.request.target_id),"source":String(result.request.source_id),"amount":result.request.amount,"lethal":result.lethal,"event_id":String(result.request.event_id),"damage_kind":int(result.request.kind),"health_after":result.health.current if result.health!=null else -1.0}))
		initial=snapshot()
		var observer:=Observer.new();observer.trace=self;observer.process_physics_priority=1100;add_child(observer)
		initialized=true;setup_done=true

var fixture_kind := "arch"
var strategy := "purpose"
var output := "res://build/forest_revision03/midloop-native01/trace.json"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--strategy="):strategy=arg.trim_prefix("--strategy=")
		elif arg.begins_with("--fixture="):fixture_kind=arg.trim_prefix("--fixture=")
		elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	if strategy != "purpose" or fixture_kind not in ["arch","basin"]:push_error("unknown_midloop_strategy");quit(1);return
	var trace := FixtureTrace.new()
	trace.fixture_kind=fixture_kind;trace.recorded_layout_version="forest-interwoven-canopy-v13"
	trace.route_name="growth";trace.aim_seconds=.35;trace.stop_after_legs=1000
	root.add_child(trace)
	while not trace.finished or not trace.setup_done:await process_frame
	trace.set_physics_process(false);trace.set_process(false)
	if is_instance_valid(trace.controller):trace.controller.router.clear("midloop_contrast_capture_sealed")
	var data := {"scope":"candidate_deep_root_initial_spawn_fixture_no_formal_prefix_not_admission","strategy":strategy,"fixture_kind":fixture_kind,"completed":trace.completed.duplicate(true),"events":trace.events.duplicate(true),"frames":trace.frames.duplicate(true),"manifest":trace.manifest.duplicate(true),"failures":trace.failures.duplicate(),"aim_samples":trace.aim_samples.duplicate(true),"initial_snapshot":trace.initial.duplicate(true),"final_snapshot":trace.snapshot(),"manual_motor_step":false,"midroute_position_or_resource_injection":false,"initial_fixture_spawn_override":true,"fixture":trace.fixture_data.duplicate(true),"source_hashes":{}}
	for path: String in [get_script().resource_path,"res://scripts/generation/forest_interwoven_expedition.gd","res://scripts/generation/thorn_forest_region_v2_v13.gd","res://tests/forest_player_aim_trace.gd","res://tests/forest_depth_region_trace.gd","res://tests/forest_depth_air_chain_case.gd","res://scripts/player/player_motor.gd","res://scripts/player/traversal_ability.gd","res://resources/player/traversal.tres","res://config/player_tuning.json"]:
		data.source_hashes[path]=FileAccess.get_sha256(path)
	var clean := true
	if is_instance_valid(trace.app):
		trace.app.process_mode=Node.PROCESS_MODE_DISABLED;trace.app._cancel_enemy_attacks()
		clean=await preload("res://tests/audio_teardown.gd").drain_world(trace.app)
	data.audio_released=clean
	trace.free();await process_frame;await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file==null:push_error("midloop_capture_write_failed");quit(1);return
	file.store_string(JSON.stringify(data));file.close()
	var reached: bool = not data.completed.is_empty() and str(data.completed[-1].edge_id)=="interwoven_deep_ascent"
	var ok: bool = data.failures.is_empty() and clean and reached
	print("MIDLOOP CONTRAST: %s / %s / %s legs / %s failures" % ["PASS" if ok else "FAIL",strategy,data.completed.size(),data.failures.size()])
	quit(0 if ok else 1)
