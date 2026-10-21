extends SceneTree
## Exactly one F08 journey; explicit LOCAL mode is never fullspawn evidence.
var output := "res://build/region_bible_v2/spiral-motor/trace.json"
var mode := "full"
var root_seed := "forest-depth-hollow-00"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--seed="): root_seed = arg.trim_prefix("--seed=")
	run.call_deferred()
func run() -> void:
	if mode not in ["full","local"]: quit(1); return
	var trace := preload("res://tests/forest_bible_spiral_trace.gd").new()
	trace.seed_value = root_seed; trace.map_index = 2
	trace.route_name = "bible_spiral_journey"; trace.recorded_layout_version = "forest-bible-world-v15"
	trace.local_fixture = mode == "local"; trace.stop_after_legs = 10000
	root.add_child(trace)
	while not trace.finished or not trace.setup_done: await process_frame
	trace.set_physics_process(false); trace.set_process(false)
	if is_instance_valid(trace.controller): trace.controller.router.clear("Bible_spiral_trace_sealed")
	if trace.completed.size() != trace.itinerary.size(): trace.failures.append("incomplete_spiral_itinerary")
	if trace.core_evidence.is_empty() or not is_instance_valid(trace.stage): trace.failures.append("actual_spiral_reader_claim_missing")
	elif not trace.stage.region_state.claimed.get("forest_spiral_core",false): trace.failures.append("actual_spiral_reader_claim_missing")
	if not is_instance_valid(trace.player) or trace.manifest.is_empty(): trace.failures.append("actual_spiral_return_camp_missing")
	elif trace.player.global_position.distance_to(trace.point(trace.manifest.merchant_position)) > 12.0: trace.failures.append("actual_spiral_return_camp_missing")
	var ascent := false
	var other_exit := false
	for row: Dictionary in trace.completed:
		if str(row.edge_id) == "interwoven_deep_ascent": ascent = true
		if str(row.edge_id) == "bible_spiral_other_exit": other_exit = true
	if not ascent or not other_exit: trace.failures.append("actual_ascent_and_other_exit_required")
	if mode == "local" and trace.fixture_data.get("motion_steps_before_override",-1) != 0: trace.failures.append("spiral_fixture_outside_first_Motor_lifecycle")
	var actor_epochs: Dictionary = {}
	for frame: Dictionary in trace.frames:
		actor_epochs[int(frame.actor_epoch)] = true
		if int(frame.motor_steps) != 1: trace.failures.append("spiral_frame_Motor_not_exactly_once"); break
	if actor_epochs.size() != 1: trace.failures.append("spiral_actor_respawn_or_missing_frames")
	for row: Dictionary in trace.events:
		if row.kind == "committed_damage" and row.get("target") == "player": trace.failures.append("spiral_player_damage_cost"); break
	var final_snapshot: Dictionary = trace.snapshot() if is_instance_valid(trace.player) and is_instance_valid(trace.controller) else {}
	var data := {"scope":"LOCAL_initial_basin_fixture_F08_not_fullspawn" if mode == "local" else "full_formal_spawn_F08_reader_and_other_exit","mode":mode,"route":trace.route_name,"seed":root_seed,"map_index":2,"initial_fixture_spawn_override":mode == "local","resource_or_health_override":false,"manual_motor_step":false,"direct_claim_or_grant":false,"fixture":trace.fixture_data.duplicate(true),"core_evidence":trace.core_evidence.duplicate(true),"completed":trace.completed.duplicate(true),"itinerary_count":trace.itinerary.size(),"events":trace.events.duplicate(true),"frames":trace.frames.duplicate(true),"failures":trace.failures.duplicate(),"initial":trace.initial.duplicate(true),"final":final_snapshot,"manifest":trace.manifest.duplicate(true),"aim_samples":trace.aim_samples.duplicate(true),"pointer_events":trace.pointer_events.duplicate(true),"reader_modal_frames":trace.core_modal_frames.duplicate(true),"no_H_only_exclusivity_claim":true}
	var clean := true
	if is_instance_valid(trace.app): clean = await preload("res://tests/audio_teardown.gd").drain_world(trace.app)
	trace.queue_free()
	for unused: int in 3: await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(data)); file.close()
	var passed: bool = data.failures.is_empty() and not data.completed.is_empty() and clean
	print("FOREST BIBLE F08 MOTOR: "+("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
