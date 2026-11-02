extends SceneTree
class ShortcutTrace extends "res://tests/forest_depth_region_trace.gd":
	var probe_phase := "depart"
	var probe_age := 0
	var probe_started := -1
	var probe_stable := 0
	var shot := false
	var shortcut_reached := false
	var negative_recovered := false
	var recovery_stable := 0
	func _physics_process(delta: float) -> void:
		if not initialized or finished: return
		if leg_index < 2:
			super._physics_process(delta)
			return
		if probe_started < 0:
			probe_started = tick
			event("shortcut_prefix_complete", {"supports": supports(), "completed": completed.duplicate(true)})
		tick += 1
		probe_age += 1
		before_steps = player.motion_steps
		if not app.lifetime.active: fail("shortcut_actual_run_ended"); return
		if tick - probe_started > 1000: fail("shortcut_bounded_timeout/" + probe_phase); return
		phase = "shortcut_" + probe_phase
		if probe_phase == "depart":
			controller.router.set_move_axis(1)
			if full_support("thorn_mouth__recovery"):
				event("shortcut_catcher_landed", {"supports": supports()})
				probe_phase = "walk_catch"; probe_age = 0
		elif probe_phase == "walk_catch":
			controller.router.set_move_axis(clampf((-1050.0-player.global_position.x)/12.0,-1,1))
			if full_support("thorn_mouth__recovery") and absf(player.global_position.x+1050.0)<5:
				jump(true); probe_phase="jump"; probe_age=0; event("shortcut_jump_takeoff", {"supports":supports()})
		elif probe_phase == "jump":
			controller.router.set_move_axis(clampf((-985.0-player.global_position.x)/12.0,-1,1))
			if not shot and probe_age >= 12 and not player.is_on_floor():
				request(&"shoot_release",Vector2.DOWN); shot=true; event("shortcut_UPR_requested")
			if probe_age >= 28: jump(false)
			probe_stable=probe_stable+1 if full_support("middle_fork__crown") else 0
			recovery_stable=recovery_stable+1 if full_support("thorn_mouth__recovery") else 0
			if probe_age>=90 and recovery_stable>=12 and shot:
				negative_recovered=true; event("shortcut_program_finished_on_real_recovery", {"supports":supports(),"full_body_stable_frames":recovery_stable}); finish_pending=true
			if probe_stable>=12:
				shortcut_reached=true; event("shortcut_full_body_crown_12_frames", {"supports":supports(),"skipped_edges":["lower_fork_flight","thorn_mouth_flight","middle_fork_flight"]}); finish_pending=true
var output := "res://build/forest_grapple02/shortcut_probe/baseline01.json"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	var trace:=ShortcutTrace.new()
	trace.recorded_layout_version="forest-woven-trunk-v12"
	trace.seed_value="forest-depth-00"; trace.map_index=1; trace.route_name="fast"
	root.add_child(trace)
	while not trace.finished or not trace.setup_done: await process_frame
	trace.set_physics_process(false)
	if is_instance_valid(trace.controller): trace.controller.router.clear("shortcut_capture_sealed")
	var data:Dictionary={"scope":"real_Motor_internal_noH_shortcut_after_real_HHRH_prefix","engine":Engine.get_version_info().string,"manifest":trace.manifest.duplicate(true),"itinerary":trace.itinerary.duplicate(true),"completed_legs":trace.completed.duplicate(true),"frames":trace.frames.duplicate(true),"events":trace.events.duplicate(true),"requests":trace.requests.duplicate(true),"failures":trace.failures.duplicate(),"initial_snapshot":trace.initial.duplicate(true),"final_snapshot":trace.snapshot(),"shortcut_reached":trace.shortcut_reached,"negative_recovered":trace.negative_recovered,"probe_started":trace.probe_started,"manual_motor_step":false,"position_or_resource_injection":false,"source_hashes":{}}
	for path:String in ["res://scripts/generation/forest_vertical_expedition.gd","res://scripts/generation/forest_thorn_mouth_geometry.gd","res://scripts/generation/forest_vertical_chain_geometry.gd","res://game/player/actions/traversal_ability.gd","res://game/player/player_motor.gd","res://config/player_tuning.json","res://tests/forest_depth_region_trace.gd",get_script().resource_path]:data.source_hashes[path]=FileAccess.get_sha256(path)
	if is_instance_valid(trace.app):
		trace.app.process_mode=Node.PROCESS_MODE_DISABLED; trace.app._cancel_enemy_attacks()
		data.audio_released=await preload("res://tests/audio_teardown.gd").drain_world(trace.app)
	trace.free(); await process_frame; await process_frame
	var f:=FileAccess.open(output,FileAccess.WRITE); f.store_string(JSON.stringify(data)); f.close()
	print("FOREST SHORTCUT: reached=%s failures=%s frames=%s"%[data.shortcut_reached,data.failures,data.frames.size()]); quit(0 if (data.shortcut_reached or data.negative_recovered) and data.failures.is_empty() else 1)
