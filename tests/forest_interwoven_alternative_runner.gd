extends SceneTree
## Bounded alternatives after the same real five-leg human-aim prefix.
## Results classify this finite strategy only; success is allowed and is evidence
## against mandatory H. No mid-route transforms, grants, ability disables or Motor steps.
class AlternativeTrace extends "res://tests/forest_player_aim_trace.gd":
	var variant := "noH_twoR"
	var strategy := "apex"
	var launch_side := "left"
	var probe_started := -1
	var probe_age := 0
	var probe_game_seconds := 0.0
	var launch_tick := -1
	var start_packet := -1
	var requested_shots := 0
	var success_stable := 0
	var recovery_stable := 0
	var target_id := "interwoven_inner_bough"
	var lesson_id := "interwoven_lesson_bough"
	var recovery_ids: Array[String] = []
	var goal := Vector2.ZERO
	var lesson := Vector2.ZERO
	var launch_point := Vector2.ZERO
	var outcome := "not_started"
	var recovery_support := ""
	var recovering := false
	var probe_initial: Dictionary = {}
	var alternative_frames: Array[Dictionary] = []

	func _physics_process(delta: float) -> void:
		if not initialized or finished: return
		if leg_index < 5:
			super._physics_process(delta)
			return
		tick += 1
		age += 1
		probe_age += 1
		before_steps = player.motion_steps
		if not app.lifetime.active: fail("alternative_actual_run_ended"); return
		if probe_started < 0:
			probe_started = tick
			var target := platform(target_id)
			var launch := platform(lesson_id)
			if target.is_empty() or launch.is_empty() or not full_support(lesson_id): fail("alternative_manifest_or_actual_lesson_support_missing"); return
			goal = Vector2(float(target.rect[0])+float(target.rect[2])*0.5,float(target.rect[1])-18.0)
			lesson = Vector2(float(launch.rect[0])+float(launch.rect[2])*0.5,float(launch.rect[1])-18.0)
			if float(launch.rect[2]) < 48.0: fail("alternative_launch_support_has_no_24px_margin"); return
			launch_point = Vector2(float(launch.rect[0])+24.0 if launch_side == "left" else float(launch.rect[0])+float(launch.rect[2])-24.0 if launch_side == "right" else lesson.x, lesson.y)
			for id: String in manifest.interwoven_contract.grounded_rest_supports:
				var row := platform(id)
				if not row.is_empty() and float(row.rect[1]) >= float(launch.rect[1]): recovery_ids.append(id)
			if lesson_id not in recovery_ids: recovery_ids.append(lesson_id)
			probe_initial = snapshot()
			event("alternative_real_prefix_complete",{"completed":completed.duplicate(true),"variant":variant,"strategy":strategy,"goal":pair(goal),"launch":pair(launch_point),"launch_side":launch_side,"recovery_center":pair(lesson),"target_platform":target.duplicate(true),"safe_recovery_ids":recovery_ids.duplicate()})
		if probe_age > 1600: fail("alternative_bounded_timeout/"+outcome); return
		if launch_tick < 0:
			phase = "alternative_natural_ground_rest"
			controller.router.set_move_axis(clampf((launch_point.x-player.global_position.x)/12.0,-1.0,1.0))
			jump(false)
			if not full_support(lesson_id): fail("alternative_left_lesson_before_launch"); return
			if controller.air_focus_ability.stamina < controller.air_focus_ability.stamina_state.capacity-0.1 or controller.actor_resources.stamina.current < controller.actor_resources.stamina.capacity-0.1: return
			if absf(player.global_position.x-launch_point.x)>4.0: return
			launch_tick = tick
			start_packet = controller.shoot_ability.packet_id
			jump(true)
			outcome = "attempting"
			event("alternative_actual_jump_started",{"snapshot":snapshot(),"supports":supports()})
			return
		probe_game_seconds += delta
		phase = "alternative_"+variant+"_"+strategy
		var limit := 0 if variant == "no_actions_jump" else 1 if variant == "noH_oneR" else 2
		var fired := controller.shoot_ability.packet_id-start_packet
		var first_ready := (probe_game_seconds >= 0.08 if strategy == "early" else probe_game_seconds >= 0.22 if strategy == "late" else player.velocity.y >= -35.0 and probe_game_seconds >= 0.08)
		if not player.is_on_floor() and requested_shots < limit and _aim_kind.is_empty():
			if (requested_shots == 0 and first_ready) or (requested_shots > 0 and fired >= requested_shots and controller.shoot_ability.cooldown_remaining <= 0.0):
				actual_down_shot()
		# Ascending steers to the current manifest receiver. On a completed
		# descent below that receiver, choose the real lower recovery geometry.
		if player.velocity.y > 0.0 and player.global_position.y > goal.y+40.0 and (requested_shots >= limit or player.is_on_floor()): recovering = true
		var steer := goal.x
		if recovering:
			steer = lesson.x
			var nearest := INF
			for id: String in recovery_ids:
				var row := platform(id)
				if float(row.rect[1]) < player.global_position.y+16.0: continue
				var center := float(row.rect[0])+float(row.rect[2])*0.5
				var distance := absf(center-player.global_position.x)
				if distance < nearest: nearest = distance; steer = center
		controller.router.set_move_axis(clampf((steer-player.global_position.x)/12.0,-1.0,1.0))
		if player.is_on_floor() and tick-launch_tick>2: jump(false)
		success_stable = success_stable+1 if full_support(target_id) else 0
		if success_stable >= 12:
			outcome = "target_reached"
			event("alternative_target_full_body_12_frames",{"supports":supports(),"accepted_shots":fired,"requested_shots":requested_shots,"variant":variant})
			jump(false); controller.router.set_move_axis(0); finish_pending = true
			return
		var current_recovery := ""
		for id: String in recovery_ids:
			if full_support(id): current_recovery = id; break
		if tick-launch_tick > 12 and not current_recovery.is_empty():
			recovery_stable = recovery_stable+1 if recovery_support == current_recovery else 1
			recovery_support = current_recovery
		else: recovery_stable = 0
		if recovery_stable >= 12:
			outcome = "returned_to_safe_support"
			event("alternative_failed_attempt_actual_recovery_12_frames",{"support":recovery_support,"accepted_shots":fired,"requested_shots":requested_shots,"variant":variant,"snapshot":snapshot()})
			jump(false); controller.router.set_move_axis(0); finish_pending = true

	func actual_down_shot() -> void:
		var keyboard := player.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = player.get_canvas_transform() * (player.global_position+Vector2(0,180))
		click.pressed = true
		keyboard._unhandled_input(click)
		click.pressed = false
		keyboard._unhandled_input(click)
		requested_shots += 1
		requests.append({"tick":tick,"leg":leg_index,"kind":"actual_mouse_downward_shot","ordinal":requested_shots,"game_seconds":probe_game_seconds,"cooldown":controller.shoot_ability.cooldown_remaining})

	func observe() -> void:
		var previous := frames.size()
		super.observe()
		if frames.size()>previous and probe_started>=0:
			frames[-1].alternative = {"variant":variant,"strategy":strategy,"outcome":outcome,"game_seconds":probe_game_seconds,"requested_shots":requested_shots,"accepted_shots":controller.shoot_ability.packet_id-start_packet if start_packet>=0 else 0,"full_target":full_support(target_id),"full_lesson":full_support(lesson_id),"target_stable":success_stable,"recovery_stable":recovery_stable,"body":[player.global_position.x-12,player.global_position.y-18,24,36],"abilities":Array(app.campaign.abilities)}
			alternative_frames.append(frames[-1].duplicate(true))
			if int(frames[-1].motor_steps)!=1: fail("alternative_motor_step_count_not_one")

var output := "res://build/forest_revision03/alternatives/result.json"
var variant := "noH_twoR"
var strategy := "apex"
var launch_side := "left"
var seed_value := "forest-depth-00"
var map_index := 1
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		elif arg.begins_with("--variant="): variant=arg.trim_prefix("--variant=")
		elif arg.begins_with("--strategy="): strategy=arg.trim_prefix("--strategy=")
		elif arg.begins_with("--launch="): launch_side=arg.trim_prefix("--launch=")
		elif arg.begins_with("--seed="): seed_value=arg.trim_prefix("--seed=")
		elif arg.begins_with("--map="): map_index=int(arg.trim_prefix("--map="))
	run.call_deferred()
func source_hashes() -> Dictionary:
	var result := {}
	for path: String in [get_script().resource_path,"res://tests/forest_player_aim_trace.gd","res://tests/forest_depth_region_trace.gd","res://scripts/generation/forest_interwoven_expedition.gd","res://scripts/generation/thorn_forest_region_v2.gd","res://scripts/generation/thorn_forest_region_v2_v13.gd","res://scripts/player/player_controller.gd","res://scripts/player/player_motor.gd","res://scripts/player/traversal_ability.gd","res://scripts/player/air_focus_ability.gd","res://scripts/input/keyboard_mouse_adapter.gd","res://config/player_tuning.json","res://resources/player/traversal.tres"]: result[path]=FileAccess.get_sha256(path)
	return result
func run() -> void:
	if variant not in ["noH_twoR","noH_oneR","no_actions_jump"] or strategy not in ["early","apex","late"] or launch_side not in ["left","center","right"] or map_index not in [1,2]:
		printerr("Invalid finite alternative probe parameters"); quit(1); return
	var source_before := source_hashes()
	var trace := AlternativeTrace.new()
	trace.recorded_layout_version="forest-interwoven-canopy-v13"
	trace.seed_value=seed_value; trace.map_index=map_index; trace.route_name="fast"
	trace.aim_seconds=0.35; trace.stop_after_legs=40
	trace.variant=variant; trace.strategy=strategy; trace.launch_side=launch_side
	root.add_child(trace)
	var started := Time.get_ticks_msec()
	while not (trace.finished and trace.setup_done):
		await process_frame
		if Time.get_ticks_msec()-started > 90000:
			trace.fail("alternative_real_time_collector_timeout"); trace.setup_done=true; break
	trace.set_physics_process(false); trace.set_process(false)
	var data := {"scope":"finite_noH_strategy_after_real_five_leg_human_aim_prefix_not_proof_all_alternatives_fail","variant":variant,"strategy":strategy,"launch_side":launch_side,"seed":seed_value,"map_index":map_index,"manifest":trace.manifest.duplicate(true),"completed_prefix":trace.completed.duplicate(true),"itinerary":trace.itinerary.duplicate(true),"frames":trace.frames.duplicate(true),"alternative_frames":trace.alternative_frames.duplicate(true),"events":trace.events.duplicate(true),"requests":trace.requests.duplicate(true),"failures":trace.failures.duplicate(),"outcome":trace.outcome,"initial":trace.initial.duplicate(true),"probe_initial":trace.probe_initial.duplicate(true),"final_snapshot":trace.snapshot() if is_instance_valid(trace.player) else {},"source_before":source_before,"source_after":source_hashes(),"manual_motor_step":false,"midroute_position_resource_injection":false,"abilities_disabled":false}
	data.source_guard=data.source_before==data.source_after
	var clean := true
	if is_instance_valid(trace.controller): trace.controller.router.clear("alternative_capture_sealed")
	if is_instance_valid(trace.app):
		trace.app.process_mode=Node.PROCESS_MODE_DISABLED; trace.app._cancel_enemy_attacks()
		clean=await preload("res://tests/audio_teardown.gd").drain_world(trace.app)
	data.audio_released=clean
	trace.free(); await process_frame; await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null: printerr("Alternative probe output failed"); quit(1); return
	file.store_string(JSON.stringify(data)); file.close()
	var ok: bool=clean and data.source_guard and data.failures.is_empty() and data.completed_prefix.size()==5 and data.outcome in ["target_reached","returned_to_safe_support"]
	print("FOREST INTERWOVEN ALTERNATIVE: %s variant=%s strategy=%s outcome=%s frames=%s failures=%s" % ["PASS" if ok else "FAIL",variant,strategy,data.outcome,data.frames.size(),data.failures.size()])
	quit(0 if ok else 1)
