extends SceneTree
## Full formal departure -> optional new world -> real camp. Never a spawn fixture.
var output := "res://build/region_bible_v2/forest-world-motor/trace.json"
var route := "bible_connection_journey"
var root_seed := "forest-depth-hollow-00"
var map_index := 2
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--route="): route = arg.trim_prefix("--route=")
		elif arg.begins_with("--seed="): root_seed = arg.trim_prefix("--seed=")
		elif arg.begins_with("--map="): map_index = int(arg.trim_prefix("--map="))
	run.call_deferred()
func run() -> void:
	if route not in ["bible_connection_journey","bible_backbranch_journey"] or map_index not in [1,2]: quit(1); return
	var trace := preload("res://tests/forest_bible_world_trace.gd").new()
	trace.seed_value = root_seed; trace.map_index = map_index
	trace.route_name = route; trace.recorded_layout_version = "forest-bible-world-v15"
	trace.stop_after_legs = 10000
	root.add_child(trace)
	while not trace.finished or not trace.setup_done: await process_frame
	trace.set_physics_process(false); trace.set_process(false)
	if is_instance_valid(trace.controller): trace.controller.router.clear("Bible_world_trace_sealed")
	var logical_failures: Array[String] = []
	if trace.completed.size() != trace.itinerary.size(): logical_failures.append("incomplete_actual_itinerary")
	if trace.initial.get("double_enabled",true) or trace.initial.get("wall_enabled",true): logical_failures.append("non_H_capability_present")
	if is_instance_valid(trace.stage) and trace.player.global_position.distance_to(trace.point(trace.manifest.merchant_position)) > 12.0: logical_failures.append("actual_camp_not_reached")
	if route == "bible_backbranch_journey" and is_instance_valid(trace.stage):
		if not trace.stage.region_state.opened.has("bible_backbranch_return"): logical_failures.append("claim_did_not_open_actual_shortcut")
		if not trace.stage.region_state.claimed.has("thorn_forest/map_%s/bible_backbranch_cache" % map_index): logical_failures.append("actual_reward_not_claimed")
		var descending := false
		for event_row: Dictionary in trace.events:
			if event_row.kind == "bible_F05_actual_descending_side_cast" and not event_row.grounded and event_row.outside_body: descending = true
		if not descending: logical_failures.append("actual_descending_outside_cast_missing")
	trace.failures.append_array(logical_failures)
	var data := {"scope":"full_formal_spawn_Bible_world_Motor","route":route,"seed":root_seed,"map_index":map_index,"completed":trace.completed.duplicate(true),"events":trace.events.duplicate(true),"frames":trace.frames.duplicate(true),"failures":trace.failures.duplicate(),"initial":trace.initial.duplicate(true),"final":trace.snapshot(),"manifest":trace.manifest.duplicate(true),"manual_motor_step":false,"position_or_resource_injection":false,"aim_samples":trace.aim_samples.duplicate(true),"itinerary_count":trace.itinerary.size(),"claimed":trace.stage.region_state.claimed.duplicate(true) if is_instance_valid(trace.stage) else {},"opened":trace.stage.region_state.opened.duplicate(true) if is_instance_valid(trace.stage) else {},"source_hashes":{}}
	for path: String in [get_script().resource_path,"res://tests/forest_bible_world_trace.gd","res://tests/forest_bible_world_air_case.gd","res://scripts/generation/forest_bible_v2_layout.gd","res://scripts/generation/forest_bible_backbranch_geometry.gd","res://scripts/generation/thorn_forest_region_v2_v15.gd","res://game/player/player_motor.gd","res://config/player_tuning.json","res://resources/player/traversal.tres"]:
		data.source_hashes[path] = FileAccess.get_sha256(path)
	data["itinerary"] = trace.itinerary.duplicate(true)
	data["requests"] = trace.requests.duplicate(true)
	data["modal_frames"] = trace.modal_frames.duplicate(true)
	data["pointer_events"] = trace.pointer_events.duplicate(true)
	var clean := true
	if is_instance_valid(trace.app): clean = await preload("res://tests/audio_teardown.gd").drain_world(trace.app)
	trace.queue_free()
	for unused: int in 3: await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(data)); file.close()
	var passed: bool = data.failures.is_empty() and not data.completed.is_empty() and clean
	print("FOREST BIBLE WORLD MOTOR: "+("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
