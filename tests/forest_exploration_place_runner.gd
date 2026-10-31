extends "res://tests/forest_varied_module_runner.gd"
## Same real input driver, new finite place consumer. No midroute pose injection.
var place_variant := 0
var route_name := "main"
func _initialize() -> void:
	layout = "seven_bough_reveal"
	output = "res://build/forest-v18/place.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--layout="): layout = arg.trim_prefix("--layout=")
		elif arg.begins_with("--place-variant="): place_variant = int(arg.trim_prefix("--place-variant="))
		elif arg.begins_with("--route="): route_name = arg.trim_prefix("--route=")
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	room = load("res://experiments/generation/forest_exploration_place_lab.gd").new()
	room.layout = layout
	room.place_variant = place_variant
	room.route_name = route_name
	root.add_child(room)
	player = room.player
	controller = room.controller
	player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	controller.traversal.action_changed.connect(action_changed)
	controller.shoot_ability.shot_fired.connect(shot_fired)
	controller.jump_ability.jumped.connect(jumped)
	var driver := Driver.new()
	driver.owner_tree = self
	driver.process_physics_priority = -100
	root.add_child(driver)
	var observer := Observer.new()
	observer.owner_tree = self
	observer.process_physics_priority = 200
	root.add_child(observer)
	while not finished: await process_frame
	driver.set_physics_process(false)
	observer.set_physics_process(false)
	controller.router.clear("place_capture_sealed")
	var clean: bool = await preload("res://tests/audio_teardown.gd").drain_world(room)
	var passed := failure.is_empty() and reached and danger_contacts.is_empty() and clean
	var data := {"scope":"single_place_real_input_not_formal_map_or_FUN","layout":layout,"place_variant":place_variant,"route":route_name,"manifest":room.manifest,"frames":frames,"events":events,"requests":requests,"danger_contacts":danger_contacts,"reached":reached,"failure":failure,"passed":passed,"audio_released":clean,"initial_fixture_spawn_override":true,"midroute_injection":false,"resource_override":false,"manual_motor_step":false}
	driver.free()
	observer.free()
	room.free()
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(data))
	print("FOREST PLACE: "+("PASS" if passed else "FAIL")+" / "+layout+" / "+str(place_variant)+" / "+route_name+" / "+failure)
	quit(0 if passed else 1)
func _ordinary_complete() -> void:
	events.append({"kind":"actual_ordinary_leg_complete","tick":tick,"step":ordinary_index,"position":[player.position.x,player.position.y],"stable_frames":stable})
	ordinary_index += 1
	controller.router.set_move_axis(0.0)
	if ordinary_index >= room.manifest.routes.main.steps.size():
		reached = _ordinary_at(Vector2(float(room.manifest.goal[0]),float(room.manifest.goal[1])),str(room.manifest.goal_support_id))
		if not reached: failure = "place_goal_support_mismatch"
		finished = true
	else: set_phase("ordinary_align")
func drive() -> void:
	if phase == "settle" and room.manifest.routes.main.kind == "ordinary_sequence":
		tick += 1
		age += 1
		steps_before = player.motion_steps
		controller.router.set_move_axis(0.0)
		var route: Dictionary = room.manifest.routes.main
		var port: Dictionary = room.manifest.ports[route.from_port]
		stable = stable+1 if _ordinary_at(Vector2(port.position[0],port.position[1]),str(port.support_id)) else 0
		if stable >= 12: set_phase("ordinary_align")
		elif age > 1200:
			failure = "actual_place_departure_not_stable"
			finished = true
		return
	if phase == "ordinary_drop" and ordinary_index < room.manifest.routes.main.steps.size():
		var step: Dictionary = room.manifest.routes.main.steps[ordinary_index]
		# A vertical two-point path has no intermediate horizontal mouth.
		# Send the same real drop input used after a longer path's mouth.
		if step.kind == "drop_through" and step.path.size() == 2 and on_support(str(step.from_support_id)) and tick-ordinary_last_drop >= 20:
			action(&"drop_through")
			ordinary_last_drop = tick
	super.drive()
