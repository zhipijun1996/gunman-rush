extends SceneTree
var output := "res://build/region_bible_v2/forest-v18-motor/capture.json"
var route := "places_normal_journey"
var root_seed := "forest-variety-00"
var map_index := 1
var reward_choice_index := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--route="): route = arg.trim_prefix("--route=")
		elif arg.begins_with("--seed="): root_seed = arg.trim_prefix("--seed=")
		elif arg.begins_with("--reward-index="): reward_choice_index = int(arg.trim_prefix("--reward-index="))
		elif arg.begins_with("--map="): map_index = int(arg.trim_prefix("--map="))
	run.call_deferred()

func run() -> void:
	var trace := preload("res://tests/forest_places_region_trace.gd").new()
	trace.reward_choice_index = reward_choice_index
	trace.seed_value = root_seed
	trace.map_index = map_index
	trace.route_name = route
	trace.recorded_layout_version = "forest-exploration-places-v18"
	root.add_child(trace)
	while not trace.finished or not trace.setup_done: await process_frame
	trace.set_physics_process(false)
	trace.set_process(false)
	if is_instance_valid(trace.controller): trace.controller.router.clear("places_formal_sealed")
	if trace.completed.size()!=trace.itinerary.size(): trace.failures.append("incomplete_actual_itinerary")
	var goal_id := str(trace.manifest.get("route_goals",{}).get(route,""))
	if not goal_id.is_empty():
		var reached := false
		for area: Dictionary in trace.manifest.areas:
			if str(area.id) == goal_id: reached = trace.at_destination(trace.point(area.position))
		if not reached: trace.failures.append("actual_final_goal_not_reached/"+goal_id)
	if trace.initial.get("double_enabled",true) or trace.initial.get("wall_enabled",true): trace.failures.append("non_H_ability_present")
	var data := {"scope":"formal_spawn_actual_App_Router_Motor_no_position_or_resource_injection","layout":"forest-exploration-places-v18",
		"seed":root_seed,"map_index":map_index,"route":route,"manifest":trace.manifest.duplicate(true),
		"frames":trace.frames.duplicate(true),"events":trace.events.duplicate(true),"requests":trace.requests.duplicate(true),
		"completed":trace.completed.duplicate(true),"itinerary":trace.itinerary.duplicate(true),
		"reward_transactions":trace.reward_transactions.duplicate(true),"initial":trace.initial.duplicate(true),"final":trace.snapshot(),"failures":trace.failures.duplicate(),
		"modal_frames":trace.modal_frames.duplicate(true),"pointer_events":trace.pointer_events.duplicate(true),
		"manual_motor_step":false,"midroute_injection":false,"resource_override":false}
	var clean := true
	if is_instance_valid(trace.app): clean = await preload("res://tests/audio_teardown.gd").drain_world(trace.app)
	data.audio_released = clean
	data.passed = data.failures.is_empty() and not data.completed.is_empty() and clean
	trace.queue_free()
	for unused: int in 3: await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	print("FOREST PLACES MOTOR: "+("PASS" if data.passed else "FAIL")+" / "+route+" / "+str(data.failures))
	quit(0 if data.passed else 1)
