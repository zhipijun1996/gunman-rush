extends SceneTree
## Formal regional prefix with held mouse aim. No Motor stepping or mid-route grants.
var output := "res://build/forest_revision03/aim/route.json"
var layout := "forest-fruit-routes-v14"
var seed_value := "forest-depth-00"
var map_index := 1
var route := "fast"
var aim_seconds := 0.35
var prefix_legs := 2

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--layout="): layout = arg.trim_prefix("--layout=")
		elif arg.begins_with("--aim-seconds="): aim_seconds = float(arg.trim_prefix("--aim-seconds="))
		elif arg.begins_with("--legs="): prefix_legs = int(arg.trim_prefix("--legs="))
		elif arg.begins_with("--seed="): seed_value = arg.trim_prefix("--seed=")
		elif arg.begins_with("--map="): map_index = int(arg.trim_prefix("--map="))
		elif arg.begins_with("--route="): route = arg.trim_prefix("--route=")
	run.call_deferred()

func run() -> void:
	if not is_finite(aim_seconds) or aim_seconds < 0.2 or aim_seconds > 0.8 or prefix_legs < 2 or prefix_legs > 40:
		push_error("Invalid finite human-aim probe parameters"); quit(1); return
	var trace := preload("res://tests/forest_player_aim_trace.gd").new()
	trace.recorded_layout_version = layout
	trace.seed_value = seed_value
	trace.map_index = map_index
	trace.route_name = route
	trace.aim_seconds = aim_seconds
	trace.stop_after_legs = prefix_legs
	root.add_child(trace)
	while not trace.finished or not trace.setup_done: await process_frame
	trace.set_physics_process(false)
	trace.set_process(false)
	if is_instance_valid(trace.controller): trace.controller.router.clear("human_aim_capture_sealed")
	var data := {"scope":"formal_regional_prefix_assisted_target_selection_real_adapter_hold_not_player_approval",
		"seed":seed_value,"map_index":map_index,"route":route,"requested_prefix_legs":prefix_legs,
		"aim_seconds":aim_seconds,"manifest":trace.manifest.duplicate(true),"completed":trace.completed.duplicate(true),
		"frames":trace.frames.duplicate(true),"events":trace.events.duplicate(true),"aim_samples":trace.aim_samples.duplicate(true),
		"failures":trace.failures.duplicate(),"manual_motor_step":false,"midroute_position_or_resource_injection":false,
		"initial_snapshot":trace.initial.duplicate(true),"final_snapshot":trace.snapshot(),"source_hashes":{}}
	for path: String in [get_script().resource_path,"res://tests/forest_player_aim_trace.gd","res://tests/forest_depth_region_trace.gd","res://game/player/actions/traversal_ability.gd","res://game/player/actions/air_focus_ability.gd","res://game/platform/input/keyboard_mouse_adapter.gd","res://config/player_tuning.json"]:
		data.source_hashes[path] = FileAccess.get_sha256(path)
	var clean := true
	if is_instance_valid(trace.app):
		trace.app.process_mode = Node.PROCESS_MODE_DISABLED
		trace.app._cancel_enemy_attacks()
		clean = await preload("res://tests/audio_teardown.gd").drain_world(trace.app)
	data.audio_released = clean
	trace.free()
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null: push_error("human_aim_capture_write_failed"); quit(1); return
	file.store_string(JSON.stringify(data)); file.close()
	var ok: bool = data.failures.is_empty() and data.completed.size() == prefix_legs and clean and not data.aim_samples.is_empty()
	print("FOREST PLAYER AIM: %s / %s legs / %s aim holds / %s failures" % ["PASS" if ok else "FAIL",data.completed.size(),data.aim_samples.size(),data.failures.size()])
	quit(0 if ok else 1)
