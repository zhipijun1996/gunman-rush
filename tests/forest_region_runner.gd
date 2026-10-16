extends SceneTree
const TRACE := preload("res://tests/forest_region_trace.gd")
var variant := "positive"
var mode := "golden"
var seed_value := "forest-playable-00"
var map_index := 1
var route_name := "fast"
var output := "res://build/forest_playable/traversal/capture.json"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): variant = arg.trim_prefix("--case=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--seed="): seed_value = arg.trim_prefix("--seed=")
		if arg.begins_with("--map="): map_index = int(arg.trim_prefix("--map="))
		if arg.begins_with("--route="): route_name = arg.trim_prefix("--route=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	if mode == "region":
		await run_region()
		return
	if variant == "load-only":
		print("FOREST LOAD ONLY: no actor instantiated")
		quit(0)
		return
	var trace := TRACE.new()
	trace.variant = variant
	root.add_child(trace)
	while not trace.finished: await process_frame
	var failures: Array[String] = []
	if not trace.branch_landed: failures.append("full_body_stable_branch_landing")
	if not trace.returned: failures.append("continuous_safe_return")
	if trace.frames.any(func(f: Dictionary) -> bool: return f.motor_steps_this_tick != 1): failures.append("single_normal_motor_tick")
	var kinds: Array = trace.events.map(func(e: Dictionary) -> String: return e.kind)
	for kind: String in ["hook_cast", "hook_fly", "hook_pull", "hook_contact_kick", "hook_kick"]:
		if kind not in kinds: failures.append("accepted_" + kind)
	var data := {"schema_version": 1, "scope": "real_short_H_golden_not_whole_region", "case": variant,
		"engine": Engine.get_version_info().string, "initial_snapshot": trace.initial_snapshot,
		"final_snapshot": trace.snapshot(),
		"frames": trace.frames, "events": trace.events, "requests": trace.requests,
		"branch_landed": trace.branch_landed, "returned": trace.returned, "failures": failures,
		"geometry": {"anchor": TRACE.SNAPSHOT.pair(trace.anchor_point), "spawn": TRACE.SNAPSHOT.pair(trace.spawn),
			"branch": [trace.branch_rect.position.x, trace.branch_rect.position.y, trace.branch_rect.size.x, trace.branch_rect.size.y],
			"root": [trace.root_rect.position.x, trace.root_rect.position.y, trace.root_rect.size.x, trace.root_rect.size.y]},
		"midroute_position_or_resource_injection": false, "manual_motor_step": false}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("capture_write_failed")
		quit(1)
		return
	file.store_string(JSON.stringify(data))
	file.close()
	trace.free()
	await process_frame
	print("FOREST REGION: %d frames, %d failures" % [data.frames.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)

func run_region() -> void:
	var trace := TRACE.new()
	trace.mode = "region"
	trace.seed_value = seed_value
	trace.map_index = map_index
	trace.route_name = route_name
	root.add_child(trace)
	while not trace.finished: await process_frame
	var failures: Array[String] = trace.route_errors.duplicate()
	if trace.completed_legs.size() != trace.itinerary.size() or trace.itinerary.is_empty(): failures.append("incomplete_actual_route_legs")
	if not trace.safe_trace: failures.append("full_body_static_danger_sweep")
	if trace.frames.any(func(f: Dictionary) -> bool: return f.motor_steps_this_tick != 1): failures.append("single_normal_motor_tick")
	var data := {"schema_version":1,"scope":"formal_DemoApp_continuous_route","seed":seed_value,"map_index":map_index,"route":route_name,"engine":Engine.get_version_info().string,"manifest":trace.manifest,"itinerary":trace.itinerary,"completed_legs":trace.completed_legs,"frames":trace.frames,"events":trace.events,"requests":trace.requests,"initial_snapshot":trace.initial_snapshot,"final_snapshot":trace.snapshot() if trace.controller != null else {},"safe_trace":trace.safe_trace,"modal_frames":trace.modal_frames,"reward_input_events":trace.reward_input_events,"cache_interacted":trace.cache_interacted,"cache_claimed":trace.cache_claimed,"claimed_ids":trace.stage.region_state.claimed.keys() if is_instance_valid(trace.stage) else [],"gate_saved_open":trace.stage.region_state.opened.has("crown_vine") if is_instance_valid(trace.stage) else false,"gate_shape_disabled":trace.stage.assembler.vine_shape.disabled if is_instance_valid(trace.stage) else false,"failures":failures,"midroute_position_or_resource_injection":false,"manual_motor_step":false}
	var saved_json := ""
	var generated: Dictionary = {}
	var tuning: PlayerTuning
	if is_instance_valid(trace.stage):
		trace.stage.capture_state()
		saved_json = JSON.stringify(trace.stage.region_state.snapshot())
		generated = trace.stage.generated.duplicate(true)
		tuning = trace.controller.motor.tuning
	if is_instance_valid(trace.app):
		var drained: bool = await preload("res://tests/audio_teardown.gd").drain_world(trace.app)
		if not drained: failures.append("actual_audio_backend_release_failed")
	trace.free()
	await process_frame
	await process_frame
	if not saved_json.is_empty():
		var restored_state := PlainsRegionState.new()
		var bound := restored_state.restore(JSON.parse_string(saved_json),str(generated.manifest.manifest_hash))
		var restored_stage: Node2D = load("res://scripts/demo/thorn_forest_region_stage.gd").new()
		restored_stage.region_state = restored_state
		restored_stage.map_index = map_index
		restored_stage.configure_generated(generated,tuning)
		root.add_child(restored_stage)
		await process_frame
		var expected_cache := "thorn_forest/map_%s/crown_cache" % map_index
		var actual_chest := false
		for chest: Dictionary in restored_stage.chests:
			if chest.id == expected_cache: actual_chest = bool(chest.claimed)
		var saved_gate: bool = restored_state.opened.has("crown_vine")
		var actual_gate: bool = restored_stage.assembler.vine_shape.disabled
		var replay_ok: bool = bound and restored_stage.assembly_ok and saved_gate == actual_gate and (route_name != "high_return" or actual_chest)
		data["state_reload"] = {"json_snapshot":JSON.parse_string(saved_json),"restored":bound,"fresh_stage_assembled":restored_stage.assembly_ok,"actual_chest_claimed":actual_chest,"actual_gate_shape_disabled":actual_gate,"saved_gate_open":saved_gate,"passed":replay_ok}
		if not replay_ok: failures.append("actual_unload_JSON_restore_stage_persistence")
		restored_stage.free()
		await process_frame
		await process_frame
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		push_error("capture_write_failed")
		quit(1)
		return
	file.store_string(JSON.stringify(data))
	file.close()
	print("FOREST ROUTE: %s map%s %s / %s legs / %s frames / %s failures" % [seed_value,map_index,route_name,data.completed_legs.size(),data.frames.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)
