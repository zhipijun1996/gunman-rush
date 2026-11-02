extends SceneTree
## Strong finite no-H envelope, explicitly from the pre-Motor basin fixture.
## Exact DOWN Router requests are assisted strategies, not blind adapter/player evidence.
class DeepAlternativeTrace extends "res://tests/forest_interwoven_midloop_runner.gd".FixtureTrace:
	var strategy := "apex"
	var phase_age := 0
	var launch_tick := -1
	var airborne_seen := false
	var final_descent_seen := false
	var requested_shots := 0
	var start_packet := -1
	var game_seconds := 0.0
	var last_shot_game := -1.0
	var shot_ticks: Array[int] = []
	var goal := Vector2.ZERO
	var basin := Vector2.ZERO
	var target_support := ""
	var target_stable := 0
	var basin_stable := 0
	var outcome := "not_started"
	var launch_pose := Vector2.ZERO
	var min_center_y := INF
	var min_foot_y := INF
	var strategy_frames: Array[Dictionary] = []

	func _physics_process(delta: float) -> void:
		if not initialized or finished: return
		tick += 1; age += 1; phase_age += 1
		before_steps = player.motion_steps
		if not app.lifetime.active: fail("deep_alternative_actual_run_ended"); return
		if phase_age > 1600: fail("deep_alternative_bounded_timeout/"+outcome); return
		if outcome == "not_started":
			var edge: Dictionary = {}
			for row: Dictionary in manifest.connections:
				if str(row.id) == "interwoven_deep_ascent": edge = row; break
			var basin_row := platform("interwoven_deep_basin")
			if edge.is_empty() or basin_row.is_empty(): fail("deep_alternative_manifest_geometry_missing"); return
			target_support = str(edge.landing_support_id)
			goal = point(edge.landing)
			basin = Vector2(float(basin_row.rect[0])+float(basin_row.rect[2])*0.5,float(basin_row.rect[1])-18.0)
			if platform(target_support).is_empty(): fail("deep_alternative_target_support_missing"); return
			outcome = "grounded_preparation"
			event("deep_alternative_geometry",{"goal":pair(goal),"basin":pair(basin),"target_support":target_support,"target_platform":platform(target_support).duplicate(true),"fixture":fixture_data.duplicate(true),"strategy":strategy})
		if launch_tick < 0:
			phase = "deep_alternative_natural_ground_rest"
			controller.router.set_move_axis(clampf((basin.x-player.global_position.x)/12.0,-1.0,1.0))
			jump(false)
			if not full_support("interwoven_deep_basin"): return
			if absf(player.global_position.x-basin.x)>4.0: return
			if controller.actor_resources.stamina.current < controller.actor_resources.stamina.capacity-0.1: return
			launch_tick = tick; launch_pose = player.global_position
			min_center_y = launch_pose.y; min_foot_y = launch_pose.y+18.0
			start_packet = controller.shoot_ability.packet_id
			jump(true); outcome = "attempting"
			event("deep_alternative_actual_held_jump",{"snapshot":snapshot(),"granted_abilities":Array(app.campaign.abilities),"motion_steps":player.motion_steps})
			return
		phase = "deep_alternative_noH_twoR_"+strategy
		game_seconds += delta
		if not player.is_on_floor(): airborne_seen = true
		var fired := controller.shoot_ability.packet_id-start_packet
		var first_ready := game_seconds >= 0.08 if strategy == "early" else game_seconds >= 0.32 if strategy == "late" else airborne_seen and player.velocity.y >= -35.0 and game_seconds >= 0.08
		if not player.is_on_floor() and requested_shots < 2:
			if requested_shots == 0 and first_ready:
				request_down()
			elif requested_shots == 1 and fired == 1 and controller.shoot_ability.cooldown_remaining <= 0.0 and game_seconds-last_shot_game >= controller.motor.tuning.shot_cooldown:
				request_down()
		# Wait for the real second recoil to finish and a genuine descent. A
		# momentary pre-jump floor sample must never count as failed recovery.
		if fired == 2 and airborne_seen and player.velocity.y > 0.0 and player.recoil_burst_remaining <= 0.0: final_descent_seen = true
		controller.router.set_move_axis(clampf(((basin.x if final_descent_seen else goal.x)-player.global_position.x)/12.0,-1.0,1.0))
		target_stable = target_stable+1 if full_support(target_support) and absf(player.global_position.x-goal.x)<=7.0 else 0
		if target_stable >= 12:
			outcome = "target_reached"
			event("deep_alternative_target_12_full_body_frames",{"accepted_shots":fired,"supports":supports(),"max_center_rise":launch_pose.y-min_center_y,"max_foot_rise":launch_pose.y+18.0-min_foot_y})
			jump(false); controller.router.set_move_axis(0); finish_pending = true; return
		basin_stable = basin_stable+1 if final_descent_seen and full_support("interwoven_deep_basin") else 0
		if basin_stable >= 12:
			outcome = "returned_to_basin"
			event("deep_alternative_two_R_completed_actual_basin_recovery",{"accepted_shots":fired,"requested_shots":requested_shots,"supports":supports(),"snapshot":snapshot(),"max_center_rise":launch_pose.y-min_center_y,"max_foot_rise":launch_pose.y+18.0-min_foot_y})
			jump(false); controller.router.set_move_axis(0); finish_pending = true

	func request_down() -> void:
		var accepted := controller.router.request_action(&"shoot_release",Vector2.DOWN)
		requests.append({"tick":tick,"leg":leg_index,"kind":"assisted_actual_Router_DOWN_shot","ordinal":requested_shots+1,"accepted_input":accepted,"game_seconds":game_seconds,"cooldown_at_request":controller.shoot_ability.cooldown_remaining,"world_scale":Engine.time_scale})
		if not accepted: fail("deep_alternative_DOWN_input_rejected"); return
		requested_shots += 1; last_shot_game = game_seconds; shot_ticks.append(tick)
		event("deep_alternative_DOWN_requested",requests[-1].duplicate(true))

	func observe() -> void:
		var count := frames.size()
		super.observe()
		if frames.size()<=count: return
		if launch_tick >= 0:
			min_center_y = minf(min_center_y,player.global_position.y)
			min_foot_y = minf(min_foot_y,player.global_position.y+18.0)
		frames[-1].deep_alternative = {"strategy":strategy,"outcome":outcome,"game_seconds":game_seconds,"requested_shots":requested_shots,"accepted_shots":controller.shoot_ability.packet_id-start_packet if start_packet>=0 else 0,"final_descent_seen":final_descent_seen,"body":[player.global_position.x-12,player.global_position.y-18,24,36],"max_center_rise":launch_pose.y-min_center_y if launch_tick>=0 else 0.0,"max_foot_rise":launch_pose.y+18.0-min_foot_y if launch_tick>=0 else 0.0,"target_stable":target_stable,"basin_stable":basin_stable,"abilities":Array(app.campaign.abilities)}
		strategy_frames.append(frames[-1].duplicate(true))
		if int(frames[-1].motor_steps)!=1: fail("deep_alternative_motor_once_violated")

var strategy := "apex"
var output := "res://build/forest_revision03/deep-alternatives/result.json"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--strategy="): strategy=arg.trim_prefix("--strategy=")
		elif arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	run.call_deferred()
func source_hashes() -> Dictionary:
	var result := {}
	for path: String in [get_script().resource_path,"res://tests/forest_interwoven_midloop_runner.gd","res://tests/forest_player_aim_trace.gd","res://tests/forest_depth_region_trace.gd","res://scripts/generation/forest_interwoven_expedition.gd","res://scripts/generation/thorn_forest_region_v2_v13.gd","res://game/player/player_controller.gd","res://game/player/player_motor.gd","res://game/player/actions/traversal_ability.gd","res://game/combat/weapons/shoot_ability.gd","res://game/combat/resources/shot_energy_policy.gd","res://config/player_tuning.json","res://game/player/resources/plains_shot_energy.tres"]: result[path]=FileAccess.get_sha256(path)
	return result
func run() -> void:
	if strategy not in ["early","apex","late"]: printerr("unknown_finite_deep_alternative_strategy"); quit(1); return
	var before := source_hashes()
	var trace := DeepAlternativeTrace.new()
	trace.fixture_kind="basin"; trace.recorded_layout_version="forest-interwoven-canopy-v13"
	trace.route_name="growth"; trace.stop_after_legs=1000; trace.strategy=strategy
	root.add_child(trace)
	var started := Time.get_ticks_msec()
	while not (trace.finished and trace.setup_done):
		await process_frame
		if Time.get_ticks_msec()-started>90000: trace.fail("deep_alternative_real_time_timeout"); trace.setup_done=true; break
	trace.set_physics_process(false); trace.set_process(false)
	var data := {"scope":"finite_strong_noH_twoR_from_explicit_motion0_basin_fixture_not_formal_prefix_or_global_impossibility","strategy":strategy,"initial_fixture_spawn_override":true,"fixture":trace.fixture_data.duplicate(true),"manifest":trace.manifest.duplicate(true),"frames":trace.frames.duplicate(true),"strategy_frames":trace.strategy_frames.duplicate(true),"events":trace.events.duplicate(true),"requests":trace.requests.duplicate(true),"initial_snapshot":trace.initial.duplicate(true),"final_snapshot":trace.snapshot() if is_instance_valid(trace.player) else {},"failures":trace.failures.duplicate(),"outcome":trace.outcome,"max_center_rise":trace.launch_pose.y-trace.min_center_y if trace.launch_tick>=0 else 0.0,"max_foot_rise":trace.launch_pose.y+18.0-trace.min_foot_y if trace.launch_tick>=0 else 0.0,"target_rise":trace.launch_pose.y-trace.goal.y if trace.launch_tick>=0 else 0.0,"manual_motor_steps":false,"midroute_position_or_resource_injection":false,"H_disabled":false,"assisted_exact_DOWN_Router_strategy":true,"source_before":before,"source_after":source_hashes()}
	data.source_guard=data.source_before==data.source_after
	if is_instance_valid(trace.controller): trace.controller.router.clear("deep_alternative_capture_sealed")
	var clean := true
	if is_instance_valid(trace.app):
		trace.app.process_mode=Node.PROCESS_MODE_DISABLED; trace.app._cancel_enemy_attacks()
		clean=await preload("res://tests/audio_teardown.gd").drain_world(trace.app)
	data.audio_released=clean
	trace.free(); await process_frame; await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file==null: printerr("deep_alternative_capture_write_failed"); quit(1); return
	file.store_string(JSON.stringify(data)); file.close()
	var ok: bool=data.source_guard and clean and data.failures.is_empty() and data.outcome in ["target_reached","returned_to_basin"]
	print("FOREST DEEP ALTERNATIVE: %s strategy=%s outcome=%s rise=%s/%s frames=%s failures=%s" % ["PASS" if ok else "FAIL",strategy,data.outcome,data.max_center_rise,data.target_rise,data.frames.size(),data.failures.size()])
	quit(0 if ok else 1)
