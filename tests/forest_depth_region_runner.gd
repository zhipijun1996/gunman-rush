extends SceneTree
const TRACE := preload("res://tests/forest_depth_region_trace.gd")
var seed_value := "forest-depth-00"
var map_index := 1
var route_name := "fast"
var layout_version := ""
var output := "res://build/forest_depth/region/capture.json"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_value=arg.trim_prefix("--seed=")
		elif arg.begins_with("--map="): map_index=int(arg.trim_prefix("--map="))
		elif arg.begins_with("--route="): route_name=arg.trim_prefix("--route=")
		elif arg.begins_with("--layout="): layout_version=arg.trim_prefix("--layout=")
		elif arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	var trace: Node=preload("res://tests/forest_depth_trace_strategy.gd").create(layout_version)
	trace.seed_value=seed_value;trace.map_index=map_index;trace.route_name=route_name
	root.add_child(trace)
	while not trace.finished or not trace.setup_done: await process_frame
	trace.set_physics_process(false)
	if is_instance_valid(trace.controller):
		trace.controller.router.clear("forest_depth_capture_sealed")
		trace.controller.router.set_jump_held(&"forest_depth_route",false)
	var data: Dictionary={"schema_version":1,"scope":"formal_DemoApp_forest_v2_continuous_route_not_boss_fight","seed":seed_value,"map_index":map_index,"route":route_name,"engine":Engine.get_version_info().string,"manifest":trace.manifest.duplicate(true),"itinerary":trace.itinerary.duplicate(true),"completed_legs":trace.completed.duplicate(true),"frames":trace.frames.duplicate(true),"events":trace.events.duplicate(true),"requests":trace.requests.duplicate(true),"failures":trace.failures.duplicate(),"initial_snapshot":trace.initial.duplicate(true),"final_snapshot":trace.snapshot(),"modal_frames":trace.modal_frames.duplicate(true),"pointer_events":trace.pointer_events.duplicate(true),"claim_before":trace.claim_before.duplicate(true),"claim_after":trace.claim_after.duplicate(true),"cache_claimed":trace.cache_claimed,"duplicate_checked":trace.duplicate_checked,"duplicate_before":trace.duplicate_before.duplicate(true),"duplicate_after":trace.duplicate_after.duplicate(true),"manual_motor_step":false,"position_or_resource_injection":false,"tick_budget":18000,"edge_tick_budget":1800,"boss_fight_covered":false}
	if is_instance_valid(trace.stage):
		data["claimed_ids"]=trace.stage.region_state.claimed.keys()
		data["visited_areas"]=trace.stage.region_state.visited.duplicate(true)
		data["gate_saved_open"]=trace.stage.region_state.opened.has("crown_vine")
		data["gate_shape_disabled"]=trace.stage.assembler.vine_shape.disabled
		data["actual_stage_map"]=trace.stage.map_index
		data["actual_stage_version"]=trace.stage.generated.stage_generator_version
	var admission: Dictionary=trace.admission_evidence()
	if not admission.is_empty(): data["bible_admission"]=admission
	var audio_ok:=true
	if is_instance_valid(trace.app):
		# Payload already detached. Quiesce ordinary gameplay only during teardown.
		trace.app.process_mode=Node.PROCESS_MODE_DISABLED
		trace.app._cancel_enemy_attacks()
		audio_ok=await preload("res://tests/audio_teardown.gd").drain_world(trace.app)
	data["audio_released"]=audio_ok
	if not audio_ok: data.failures.append("actual_audio_teardown_failed")
	trace.free()
	await process_frame;await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null: push_error("forest_v2_capture_write_failed");quit(1);return
	file.store_string(JSON.stringify(data));file.close()
	print("FOREST DEPTH ROUTE: %s map%s %s / %s legs / %s frames / %s failures"%[seed_value,map_index,route_name,data.completed_legs.size(),data.frames.size(),data.failures.size()])
	quit(0 if data.failures.is_empty() else 1)
