extends SceneTree
## Deliberately remove one test-only target before the first route tick.
## The actual App, input driver, player and remaining world stay unchanged.
class AblationTrace extends "res://tests/forest_depth_region_trace.gd":
	var omitted_anchor := "none"
	var ablation: Dictionary = {}
	func begin() -> void:
		await super.begin()
		if not initialized or not setup_done:
			return
		ablation = {"omitted_anchor": omitted_anchor, "test_only_world_target_removal": omitted_anchor != "none", "route_ticks_before_removal": tick, "motion_steps_before_removal": player.motion_steps, "manifest_unchanged": true}
		if omitted_anchor == "none":
			ablation.control = true
			return
		var target: Node2D = stage.assembler.hook_targets.get(omitted_anchor)
		if not is_instance_valid(target):
			fail("ablation_candidate_missing_before_removal")
			return
		ablation.original_target_position = [target.position.x, target.position.y]
		ablation.original_hang_enabled = target.get("hang_enabled")
		stage.assembler.hook_targets.erase(omitted_anchor)
		target.free()
		ablation.actual_target_absent = not is_instance_valid(stage.assembler.get_node_or_null(omitted_anchor)) and not stage.assembler.hook_targets.has(omitted_anchor)
		if tick != 0 or not ablation.actual_target_absent:
			fail("ablation_not_removed_before_first_route_tick")

var seed_value := "forest-depth-00"
var map_index := 1
var route_name := "high_return"
var omitted_anchor := "none"
var output := "res://build/forest_fruit/ablation/capture.json"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_value = arg.trim_prefix("--seed=")
		elif arg.begins_with("--map="): map_index = int(arg.trim_prefix("--map="))
		elif arg.begins_with("--route="): route_name = arg.trim_prefix("--route=")
		elif arg.begins_with("--omit="): omitted_anchor = arg.trim_prefix("--omit=")
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()

func run() -> void:
	var trace := AblationTrace.new()
	trace.recorded_layout_version = "forest-interwoven-canopy-v13"
	trace.omitted_anchor = omitted_anchor
	trace.seed_value = seed_value; trace.map_index = map_index; trace.route_name = route_name
	root.add_child(trace)
	while not trace.finished or not trace.setup_done: await process_frame
	trace.set_physics_process(false)
	if is_instance_valid(trace.controller):
		trace.controller.router.clear("forest_fruit_ablation_capture_sealed")
		trace.controller.router.set_jump_held(&"forest_depth_route", false)
	var data: Dictionary = {"schema_version": 1, "scope": "formal_DemoApp_forest_v2_continuous_route_not_boss_fight", "seed": seed_value, "map_index": map_index, "route": route_name, "engine": Engine.get_version_info().string, "manifest": trace.manifest.duplicate(true), "itinerary": trace.itinerary.duplicate(true), "completed_legs": trace.completed.duplicate(true), "frames": trace.frames.duplicate(true), "events": trace.events.duplicate(true), "requests": trace.requests.duplicate(true), "failures": trace.failures.duplicate(), "initial_snapshot": trace.initial.duplicate(true), "final_snapshot": trace.snapshot(), "modal_frames": trace.modal_frames.duplicate(true), "pointer_events": trace.pointer_events.duplicate(true), "claim_before": trace.claim_before.duplicate(true), "claim_after": trace.claim_after.duplicate(true), "cache_claimed": trace.cache_claimed, "duplicate_checked": trace.duplicate_checked, "duplicate_before": trace.duplicate_before.duplicate(true), "duplicate_after": trace.duplicate_after.duplicate(true), "manual_motor_step": false, "position_or_resource_injection": false, "tick_budget": 18000, "edge_tick_budget": 1800, "boss_fight_covered": false, "actual_target_ablation": trace.ablation.duplicate(true)}
	if is_instance_valid(trace.stage):
		data.claimed_ids = trace.stage.region_state.claimed.keys()
		data.visited_areas = trace.stage.region_state.visited.duplicate(true)
		data.gate_saved_open = trace.stage.region_state.opened.has("crown_vine")
		data.gate_shape_disabled = trace.stage.assembler.vine_shape.disabled
		data.actual_stage_map = trace.stage.map_index
		data.actual_stage_version = trace.stage.generated.stage_generator_version
	var audio_ok := true
	if is_instance_valid(trace.app):
		trace.app.process_mode = Node.PROCESS_MODE_DISABLED
		trace.app._cancel_enemy_attacks()
		audio_ok = await preload("res://tests/audio_teardown.gd").drain_world(trace.app)
	data.audio_released = audio_ok
	if not audio_ok: data.failures.append("actual_audio_teardown_failed")
	trace.free()
	await process_frame; await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(data)); file.close()
	print("FOREST FRUIT ABLATION: %s map%s %s omit=%s / %s legs / %s failures" % [seed_value, map_index, route_name, omitted_anchor, data.completed_legs.size(), data.failures.size()])
	quit(0 if data.failures.is_empty() else 1)
