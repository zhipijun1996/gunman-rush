extends SceneTree
## Same live DemoApp prefix and Motor as the proved shortcut, followed only by
## real input. No target/player movement, grants, enemy reset or borrowed saves.
class RetryTrace extends "res://tests/forest_depth_region_trace.gd":
	var retry_phase := "depart"
	var retry_age := 0
	var retry_held := 0
	var probe_started := -1
	var recovery_reached := false
	var ordinary_last_hop := false
	func transition(next: String) -> void:
		retry_phase=next;retry_age=0;retry_held=0
		event("retry_phase",{"state":next})
	func _physics_process(delta: float) -> void:
		if not initialized or finished:return
		if leg_index<2:
			super._physics_process(delta);return
		if probe_started<0:
			probe_started=tick
			event("retry_prefix_complete",{"supports":supports(),"completed":completed.duplicate(true)})
		tick+=1;retry_age+=1;before_steps=player.motion_steps
		phase="retry_"+retry_phase
		if not app.lifetime.active:fail("retry_actual_run_ended");return
		if tick-probe_started>1200:fail("retry_bounded_input_program/"+retry_phase);return
		if controller.traversal.state in [&"hook_miss",&"hook_retract"]:
			fail("retry_actual_H_failed/"+retry_phase);return
		match retry_phase:
			"depart":
				controller.router.set_move_axis(1)
				if full_support("thorn_mouth__recovery"):transition("align")
			"align":
				controller.router.set_move_axis(clampf((-1800-player.global_position.x)/12,-1,1))
				retry_held=retry_held+1 if at_destination(Vector2(-1800,1982),"thorn_mouth__recovery") and absf(player.velocity.x)<1 else 0
				if retry_held>=13:
					controller.router.set_move_axis(0);jump(true)
					event("retry_actual_departure",{"support":"thorn_mouth__recovery","shots":controller.action_resources.shot_charges})
					transition("launch")
			"launch":
				if retry_age==24:hook("thorn_retry_low_ring");transition("low_hang")
			"low_hang":
				if _held_at("thorn_retry_low_ring"):
					jump(false);hook("thorn_retry_high_ring");transition("high_hang")
			"high_hang":
				if _held_at("thorn_retry_high_ring"):
					hook("thorn_retry_exit_ring");transition("exit_hang")
			"upward_recoil":
				if retry_age>=9 and player.recoil_burst_remaining<=0:
					transition("mouth_receive")
			"exit_hang":
				if _held_at("thorn_retry_exit_ring"):
					request(&"shoot_release",Vector2.DOWN);transition("upward_recoil")
			"mouth_receive":
				controller.router.set_move_axis(clampf((-1695-player.global_position.x)/16,-1,1))
				if retry_age==12:jump(false)
				if not ordinary_last_hop and retry_age>20 and full_support("root_spiral__crown") and controller.traversal.state==&"free":
					jump(true);ordinary_last_hop=true
					event("retry_actual_root_to_mouth_jump",{"supports":supports()})
				if ordinary_last_hop and retry_age>45:jump(false)
				retry_held=retry_held+1 if at_destination(Vector2(-1695,1280),"thorn_mouth__entry") else 0
				if retry_held>=12:
					recovery_reached=true
					event("retry_actual_mouth_arrival",{"support":"thorn_mouth__entry","stable_frames":retry_held})
					finish_pending=true
	func _held_at(id: String) -> bool:
		if controller.traversal.state==&"hook_hang" and is_instance_valid(controller.traversal.hook_target) and str(controller.traversal.hook_target.name)==id:
			if retry_held==0:event("retry_actual_hanging_observation",{"target":id,"grounded":player.is_on_floor(),"shots":controller.action_resources.shot_charges})
			retry_held+=1
			return retry_held>=12
		return false
	func observe() -> void:
		super.observe()
		if not frames.is_empty():
			frames[-1].merge({"body":[player.global_position.x-12,player.global_position.y-18,24,36],"hook_start":pair(controller.traversal.hook_start),"hook_tip":pair(controller.traversal.hook_tip),"shot_energy_delay":controller.shot_energy._delay,"burst_remaining":player.recoil_burst_remaining,"burst_velocity":pair(player.recoil_velocity),"retry_phase":retry_phase})
			frames[-1].pending_air_grants=controller.received_resource_grants.map(func(grant: Dictionary) -> Dictionary:return {"amount":int(grant.amount),"session_id":int(grant.session_id)})
	func _hook_event(state: StringName) -> void:
		super._hook_event(state)
		if not events.is_empty():events[-1].merge({"hook_tip":pair(controller.traversal.hook_tip),"hook_used_at_event":controller.traversal.hook_used})

var output := "res://build/forest_grapple02/root_retry01/capture.json"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	var trace:=RetryTrace.new()
	trace.recorded_layout_version="forest-woven-trunk-v12"
	trace.seed_value="forest-depth-00";trace.map_index=1;trace.route_name="fast"
	root.add_child(trace)
	while not trace.finished or not trace.setup_done:await process_frame
	trace.set_physics_process(false)
	if is_instance_valid(trace.controller):trace.controller.router.clear("retry_capture_sealed")
	var data: Dictionary={"scope":"real_Motor_deep_H_recovery_after_real_prefix","engine":Engine.get_version_info().string,"manifest":trace.manifest.duplicate(true),"itinerary":trace.itinerary.duplicate(true),"completed_legs":trace.completed.duplicate(true),"frames":trace.frames.duplicate(true),"events":trace.events.duplicate(true),"requests":trace.requests.duplicate(true),"failures":trace.failures.duplicate(),"initial_snapshot":trace.initial.duplicate(true),"final_snapshot":trace.snapshot(),"recovery_reached":trace.recovery_reached,"probe_started":trace.probe_started,"manual_motor_step":false,"position_or_resource_injection":false,"source_hashes":{}}
	for path: String in ["res://scripts/generation/forest_vertical_expedition.gd","res://scripts/generation/forest_thorn_mouth_geometry.gd","res://scripts/generation/forest_vertical_chain_geometry.gd","res://scripts/player/traversal_ability.gd","res://scripts/player/player_motor.gd","res://config/player_tuning.json","res://tests/forest_depth_region_trace.gd",get_script().resource_path]:data.source_hashes[path]=FileAccess.get_sha256(path)
	if is_instance_valid(trace.app):
		trace.app.process_mode=Node.PROCESS_MODE_DISABLED;trace.app._cancel_enemy_attacks()
		data.audio_released=await preload("res://tests/audio_teardown.gd").drain_world(trace.app)
	trace.free();await process_frame;await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
	print("FOREST ROOT RETRY: reached=%s failures=%s frames=%s"%[data.recovery_reached,data.failures,data.frames.size()])
	quit(0 if data.recovery_reached and data.failures.is_empty() else 1)
