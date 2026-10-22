extends SceneTree
## ISOLATED FEEDBACK ONLY. Initial App spawn override is explicitly reported.
var output := "res://build/region_bible_v2/forest-world-fixture/trace.json"
var fixture_kind := "connection"
var return_mode := "short"
var root_seed := "forest-depth-hollow-00"
var map_index := 2
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--fixture="): fixture_kind = arg.trim_prefix("--fixture=")
		elif arg.begins_with("--return="): return_mode = arg.trim_prefix("--return=")
		elif arg.begins_with("--seed="): root_seed = arg.trim_prefix("--seed=")
		elif arg.begins_with("--map="): map_index = int(arg.trim_prefix("--map="))
	run.call_deferred()
func run() -> void:
	if fixture_kind not in ["connection","backbranch"] or map_index not in [1,2] or return_mode not in ["long","short"] or (fixture_kind == "connection" and return_mode != "short"): quit(1); return
	var trace := preload("res://tests/forest_bible_world_fixture_trace.gd").new()
	trace.seed_value = root_seed; trace.map_index = map_index
	trace.fixture_kind = fixture_kind; trace.return_mode = return_mode; trace.route_name = "Bible_LOCAL_FIXTURE_"+fixture_kind
	trace.recorded_layout_version = "forest-bible-world-v15"; trace.stop_after_legs = 10000
	root.add_child(trace)
	while not trace.finished or not trace.setup_done: await process_frame
	trace.set_physics_process(false); trace.set_process(false)
	if is_instance_valid(trace.controller): trace.controller.router.clear("Bible_LOCAL_fixture_trace_sealed")
	if trace.completed.size() != trace.itinerary.size(): trace.failures.append("incomplete_fixture_itinerary")
	if trace.fixture_data.get("motion_steps_before_override",-1) != 0: trace.failures.append("initial_spawn_fixture_outside_allowed_lifecycle")
	var return_observation: Dictionary = {}
	if fixture_kind == "backbranch" and is_instance_valid(trace.stage):
		var claim_id := "thorn_forest/map_%s/bible_backbranch_cache" % map_index
		var was_claimed: bool = trace.stage.region_state.claimed.has(claim_id)
		var was_opened: bool = trace.stage.region_state.opened.has("bible_backbranch_return")
		if return_mode == "short" and (not was_claimed or not was_opened): trace.failures.append("short_return_missing_actual_claim_and_opened_gate")
		if return_mode == "long" and (was_claimed or was_opened): trace.failures.append("long_return_did_not_preserve_closed_unclaimed_gate")
		var arrival_tick := -1
		var camp_tick := -1
		var return_edges: Array[String] = []
		for completed: Dictionary in trace.completed:
			if str(completed.edge_id) == "bible_backbranch_flight": arrival_tick = int(completed.tick)
			elif arrival_tick >= 0:
				camp_tick = int(completed.tick)
				if return_edges.is_empty() or return_edges[-1] != str(completed.edge_id): return_edges.append(str(completed.edge_id))
		var return_holds: Array = []
		for sample: Dictionary in trace.aim_samples:
			if int(sample.tick) >= arrival_tick: return_holds.append(sample.duplicate(true))
		if arrival_tick < 0 or camp_tick <= arrival_tick: trace.failures.append("complete_reward_receiver_to_camp_observation_missing")
		if trace.player.global_position.distance_to(trace.point(trace.manifest.merchant_position)) > 12.0: trace.failures.append("actual_return_camp_missing")
		return_observation = {"receiver_tick":arrival_tick,"camp_tick":camp_tick,"physical_frame_difference":camp_tick-arrival_tick,"return_edges":return_edges,"return_aim_holds":return_holds,"modal_process_frames":trace.modal_frames.size(),"claimed":was_claimed,"opened":was_opened,"frame_measure_excludes_paused_modal_physics":true,"measurement_is_not_a_comparison_without_both_complete_runs":true}
	var data := {"scope":"LOCAL_initial_spawn_fixture_not_fullspawn_or_formal_admission","fixture_kind":fixture_kind,"return_mode":return_mode,"return_observation":return_observation,"seed":root_seed,"map_index":map_index,"initial_fixture_spawn_override":true,"resource_or_health_override":false,"fixture":trace.fixture_data.duplicate(true),"completed":trace.completed.duplicate(true),"itinerary_count":trace.itinerary.size(),"events":trace.events.duplicate(true),"frames":trace.frames.duplicate(true),"failures":trace.failures.duplicate(),"initial":trace.initial.duplicate(true),"final":trace.snapshot(),"manifest":trace.manifest.duplicate(true),"source_hashes":{},"aim_samples":trace.aim_samples.duplicate(true),"requests":trace.requests.duplicate(true),"pointer_events":trace.pointer_events.duplicate(true)}
	for path: String in [get_script().resource_path,"res://tests/forest_bible_world_fixture_trace.gd","res://tests/forest_bible_world_fixture_app.gd","res://tests/forest_bible_world_trace.gd","res://scripts/generation/forest_bible_v2_layout.gd","res://scripts/generation/forest_bible_backbranch_geometry.gd","res://scripts/player/player_motor.gd","res://config/player_tuning.json","res://resources/player/traversal.tres"]:
		data.source_hashes[path] = FileAccess.get_sha256(path)
	var clean := true
	if is_instance_valid(trace.app): clean = await preload("res://tests/audio_teardown.gd").drain_world(trace.app)
	trace.queue_free()
	for unused: int in 3: await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(data)); file.close()
	var passed: bool = data.failures.is_empty() and not data.completed.is_empty() and clean
	print("FOREST BIBLE LOCAL FIXTURE: "+("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
