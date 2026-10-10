extends "res://tests/platforming_module_tests.gd"

func spawn(entry_id: StringName, exit_id: StringName, jump_count: int) -> void:
	if is_instance_valid(world):
		world.free()
	world = Node2D.new()
	tree.root.add_child(world)
	module = preload("res://scenes/generation/modules/route_junction.tscn").instantiate()
	module.definition = module.definition.duplicate(true)
	for port: PlatformingModulePort in module.definition.get_entry_ports():
		if port.port_id == entry_id:
			module.definition.entry_port = port
	for port: PlatformingModulePort in module.definition.get_exit_ports():
		if port.port_id == exit_id:
			module.definition.exit_port = port
	world.add_child(module)
	motor = PLAYER.instantiate()
	motor.position = module.world_entry()
	world.add_child(motor)
	controller = motor.get_node("Controller")
	controller.set_physics_process(false)
	motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	motor.tuning.max_jumps = jump_count
	motor.tuning.max_air_shots = 0
	controller.action_resources.reset()
	respawn = SegmentRespawn.new()
	respawn.configure(controller, DemoLifetime.new())
	respawn.danger_bounds.assign(module.world_dangers())
	safe_trace = true
	peak_y = motor.position.y
	shot_count = 0
	await tick(3)

func contracts() -> void:
	var definition: PlatformingModuleDefinition = preload("res://resources/generation/modules/route_junction.tres")
	check.call(definition.is_valid(), "junction's two entrances and three exits all have safe standing support")
	check.call(definition.get_entry_ports().size() == 2 and definition.get_exit_ports().size() == 3, "typed arrays expose genuine multiple authored ports")
	var legacy: PlatformingModuleDefinition = preload("res://resources/generation/modules/micro_board.tres")
	check.call(legacy.get_entry_ports().size() == 1 and legacy.get_exit_ports().size() == 1 and legacy.is_valid(), "existing single-port assets retain canonical fallback and validity")
	var zero := PlayerTuning.load_default()
	zero.max_jumps = 0
	zero.max_air_shots = 0
	check.call(definition.supports(zero), "optional jumping exits do not invalidate the zero-action canonical path")
	var invalid := definition.duplicate(true) as PlatformingModuleDefinition
	invalid.entry_ports[1] = null
	check.call(not invalid.is_valid(), "null alternate entrance is rejected without script errors")
	invalid = definition.duplicate(true)
	invalid.exit_ports[1].port_id = invalid.entry_ports[1].port_id
	check.call(not invalid.is_valid(), "port IDs are unique across both entrance and exit sets")
	invalid = definition.duplicate(true)
	invalid.exit_ports[1].position = Vector2(160, 400)
	check.call(not invalid.is_valid(), "unsupported optional exit is rejected")
	invalid = definition.duplicate(true)
	invalid.exit_ports[1].position = Vector2(-20, 462)
	check.call(not invalid.is_valid(), "optional exit outside authored bounds is rejected")
	invalid = definition.duplicate(true)
	invalid.entry_port = invalid.entry_port.duplicate(true)
	invalid.entry_port.position = Vector2(40, 582)
	check.call(not invalid.is_valid(), "canonical port must match the corresponding array contract")
	invalid = definition.duplicate(true)
	invalid.exit_ports[1].direction = Vector2(2, 0)
	check.call(not invalid.is_valid(), "alternate port direction must be normalized")
	invalid = definition.duplicate(true)
	invalid.danger_bounds.append(Rect2(140, 440, 40, 30))
	check.call(not invalid.is_valid(), "hazardous optional port is rejected")
	invalid = definition.duplicate(true)
	invalid.entry_port = invalid.entry_ports[1]
	check.call(not invalid.is_valid(), "a selected traversal cannot enter and exit at the same standing point")

func run(p_tree: SceneTree, p_check: Callable) -> void:
	tree = p_tree
	check = p_check
	contracts()
	for exit_id: StringName in [&"exit_lower_right", &"exit_upper_left", &"exit_upper_right"]:
		var jump_count := 0 if exit_id == &"exit_lower_right" else 1
		await spawn(&"entry_left", exit_id, jump_count)
		check_ports(str(exit_id))
		if jump_count == 0:
			check.call(await move_to(module.world_exit().x), "lower exit has a real zero-jump zero-shot floor path")
		else:
			check.call(await move_to(490), "optional route approaches first step from the open right-side gap")
			check.call(await jump_to(350), "one held jump lands on first raised step")
			if exit_id == &"exit_upper_left":
				check.call(await move_to(270), "upper-left route approaches raised left takeoff")
				check.call(await jump_to(160), "second jump after grounded recharge reaches upper left route")
			else:
				check.call(await move_to(410), "upper-right route walks to raised takeoff")
				check.call(await jump_to(560), "second jump after recharge reaches upper right route")
				check.call(await move_to(680), "upper-right route walks to its real terminal port")
		check.call(await move_to(module.world_exit().x), "selected exit is reached precisely by remaining platform movement")
		await finish(str(exit_id))
	await spawn(&"entry_right", &"exit_upper_left", 1)
	check_ports("alternate right entrance")
	check.call(await move_to(490), "right-side entrance starts a genuinely leftward input trajectory")
	check.call(await jump_to(350), "leftward jump boards middle step from the right")
	check.call(await move_to(270), "reverse route approaches raised left takeoff")
	check.call(await jump_to(160), "leftward traversal continues to upper-left terminal route")
	check.call(await move_to(module.world_exit().x), "alternate entrance completes at precise terminal position")
	await finish("right entrance to upper-left exit")
	world.free()
