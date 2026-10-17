extends SceneTree
## Same actual generated map and normal route. Only the error control tilts one real recoil shot.
const TRACE := preload("res://tests/forest_depth_thorn_trace.gd")
const AUDIO := preload("res://tests/audio_teardown.gd")
var output := "res://build/forest_depth/thorn/native/capture.json"
var failures: Array[String]=[]
var cases: Array[Dictionary]=[]
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	await one_case(false)
	await one_case(true)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"actual_DemoApp_upper_thorn_window_purpose_and_recoil_direction_control","cases":cases,"failures":failures,"engine":Engine.get_version_info().string}));file.close()
	print("FOREST DEPTH THORN: %s cases, %s failures" % [cases.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)
func one_case(omit_jump: bool) -> void:
	var trace:=TRACE.new()
	trace.seed_value="forest-depth-hollow-00";trace.map_index=1;trace.route_name="fast";trace.error_control=omit_jump
	root.add_child(trace)
	while not trace.finished or not trace.setup_done: await process_frame
	trace.set_physics_process(false)
	var row: Dictionary={"id":"wrong_recoil" if omit_jump else "purpose_horizontal","seed":trace.seed_value,"map_index":1,"route":"fast","manifest":trace.manifest.duplicate(true),"itinerary":trace.itinerary.duplicate(true),"frames":trace.frames.duplicate(true),"events":trace.events.duplicate(true),"requests":trace.requests.duplicate(true),"completed_legs":trace.completed.duplicate(true),"failures":trace.failures.duplicate(),"initial":trace.initial.duplicate(true),"final":trace.snapshot(),"changed_shot":trace.changed_shot,"manual_motor_step":false,"position_or_resource_injection":false}
	if not trace.failures.is_empty(): failures.append(str(row.id)+"/"+str(trace.failures))
	if is_instance_valid(trace.app):
		trace.app.process_mode=Node.PROCESS_MODE_DISABLED
		trace.app._cancel_enemy_attacks()
		row.audio_released=await AUDIO.drain_world(trace.app)
		if not row.audio_released:failures.append(str(row.id)+"/audio_release")
	cases.append(row)
	trace.free()
	await process_frame;await process_frame
