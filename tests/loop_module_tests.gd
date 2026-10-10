extends RefCounted

const PLAYER := preload("res://scenes/player/player.tscn")
const DT := 1.0 / 60.0
var tree: SceneTree
var check: Callable
var world: Node2D
var module: PlatformingModule
var motor: PlayerMotor
var controller: PlayerController
var respawn: SegmentRespawn
var previous_body := Rect2()
var safe_trace := true
var jump_requests := 0
var shot_count := 0

func fixture(id: String, jumps: int) -> void:
	if is_instance_valid(world):
		world.free()
	world = Node2D.new()
	tree.root.add_child(world)
	module = load("res://scenes/generation/modules/" + id + ".tscn").instantiate()
	world.add_child(module)
	motor = PLAYER.instantiate()
	motor.position = module.world_entry()
	world.add_child(motor)
	controller = motor.get_node("Controller")
	controller.set_physics_process(false)
	motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	motor.tuning.max_jumps = jumps
	motor.tuning.max_air_shots = 0
	controller.action_resources.reset()
	controller.shoot_ability.shot_fired.connect(func(_direction: Vector2, _id: int) -> void: shot_count += 1)
	respawn = SegmentRespawn.new()
	respawn.configure(controller, DemoLifetime.new())
	respawn.danger_bounds.assign(module.world_dangers())
	previous_body = Rect2(motor.global_position - Vector2(12, 18), Vector2(24, 36))
	safe_trace = true
	jump_requests = 0
	shot_count = 0
	await tick(3)
	check.call(module.definition.is_valid() and module.definition.supports(motor.tuning), id + " valid authored entry supports configured resources")
	check.call(module.port_accepts(module.definition.entry_port, motor), id + " real standing motor satisfies entry port")
	for anchor: Vector2 in module.world_anchors():
		check.call(respawn.is_safe(anchor), id + " full-body segment anchor and three floor rays are safe at " + str(anchor))

func tick(count: int = 1) -> void:
	for unused: int in count:
		await tree.physics_frame
		controller.physics_tick(DT)
		var body := Rect2(motor.global_position - Vector2(12, 18), Vector2(24, 36))
		for danger: Rect2 in module.world_dangers():
			if previous_body.merge(body).intersects(danger, true):
				safe_trace = false
		previous_body = body

func move_to(x: float, budget: int = 240) -> bool:
	for unused: int in budget:
		controller.router.set_move_axis(clampf((x - motor.global_position.x) / 5.5, -1.0, 1.0))
		await tick()
		if absf(x - motor.global_position.x) < 0.6:
			controller.router.set_move_axis(0.0)
			await tick()
			return true
	return false

func jump_to(point: Vector2, label: String) -> void:
	check.call(motor.is_on_floor() and controller.jump_ability.used_jumps == 0, label + " preceding real landing replenishes the single configurable jump")
	controller.router.request_action(&"jump")
	jump_requests += 1
	var landed := false
	for index: int in 90:
		controller.router.set_move_axis(clampf((point.x - motor.global_position.x) / 5.5, -1.0, 1.0))
		await tick()
		if index > 3 and motor.is_on_floor():
			landed = true
			break
	controller.router.request_action(&"jump_release")
	controller.router.set_move_axis(0.0)
	await tick(2)
	check.call(landed and motor.global_position.distance_to(point) < 1.0, label + " one held jump lands on the authored upper platform")

func finish(label: String, expected_jumps: int) -> void:
	controller.router.set_move_axis(0.0)
	for unused: int in 55:
		await tick()
		if motor.is_on_floor():
			break
	await tick(2)
	check.call(motor.is_on_floor() and motor.global_position.distance_to(module.world_exit()) < 1.0, label + " reaches shared exit by continuous real Motor motion")
	check.call(module.port_accepts(module.definition.exit_port, motor), label + " accepted stationary exit retains required action resources")
	check.call(safe_trace, label + " full 24x36 body sweep avoids hazards throughout the path")
	check.call(jump_requests == expected_jumps and shot_count == 0, label + " uses only the recorded jump count and no shots or slow time")
	check.call(controller.jump_ability.used_jumps == 0 and controller.action_resources.shot_charges == 0, label + " final physical landing restores configurable jump budget without granting shots")
	check.call(respawn.is_safe(module.world_exit()), label + " shared exit has full collision clearance and supporting floor")

func run(p_tree: SceneTree, p_check: Callable) -> void:
	tree = p_tree
	check = p_check
	await fixture("square_loop", 0)
	check.call(await move_to(module.world_exit().x), "loop lower route remains traversable with zero jumps and zero shots")
	await finish("loop lower 0/0", 0)
	await fixture("square_loop", 1)
	var upper: Array[Vector2] = [Vector2(250, 512), Vector2(420, 462), Vector2(590, 412), Vector2(760, 362), Vector2(930, 412), Vector2(1100, 462)]
	for index: int in upper.size():
		await jump_to(upper[index], "loop upper landing %d" % index)
	check.call(await move_to(1200.0), "upper route walks beyond final platform to descend")
	await tick(30)
	check.call(await move_to(module.world_exit().x), "upper route approaches common exit after descent")
	await finish("loop upper 1/0", upper.size())
	await fixture("square_loop", 1)
	await jump_to(upper[0], "rejoin first upper landing")
	await jump_to(upper[1], "rejoin second upper landing")
	check.call(await move_to(510.0), "optional upper route can walk off platform toward lower lane")
	await tick(40)
	check.call(motor.is_on_floor() and absf(motor.position.y - 582.0) < 0.2, "upper route returns safely to lower lane without teleporting")
	check.call(await move_to(module.world_exit().x), "rejoined lower lane reaches the same shared exit")
	await finish("loop upper-to-lower rejoin", 2)
	await fixture("boss_approach", 0)
	check.call(await move_to(module.world_exit().x), "boss approach reaches explicit staging gate with zero jumps and zero shots")
	await finish("boss approach 0/0", 0)
	await contracts()
	world.free()

func contracts() -> void:
	for id: String in ["square_loop", "boss_approach"]:
		var definition: PlatformingModuleDefinition = load("res://resources/generation/modules/" + id + ".tres")
		for jumps: int in [0, 1, 3]:
			for shots: int in [0, 1, 3]:
				var tuning := PlayerTuning.load_default()
				tuning.max_jumps = jumps
				tuning.max_air_shots = shots
				check.call(definition.supports(tuning), id + " independent capability screen accepts %d jumps/%d shots via optional-free baseline" % [jumps, shots])
		var first: PlatformingModule = load("res://scenes/generation/modules/" + id + ".tscn").instantiate()
		var second: PlatformingModule = load("res://scenes/generation/modules/" + id + ".tscn").instantiate()
		world.add_child(first)
		world.add_child(second)
		check.call(first.definition != second.definition and first.definition.entry_port != second.definition.entry_port, id + " sibling instances isolate definition and port state")
		var prior: Vector2 = second.definition.anchors[0]
		first.definition.anchors[0] += Vector2(1, 0)
		check.call(second.definition.anchors[0] == prior, id + " mutating one anchor cannot change another instance")
		first.free()
		second.free()
	# Compare physical geometry clipped to the fixed combat core, rather than
	# legacy offscreen floor extents. No Boss combat is inferred from this test.
	var fixed := DemoStage.new()
	fixed.configure(10, &"boss", [])
	fixed.position = Vector2(1400, 0)
	world.add_child(fixed)
	var core := Rect2(890, 300, 350, 380)
	var actual: Array[Rect2] = []
	for rect: Rect2 in module.definition.platforms:
		var clipped := rect.intersection(core)
		if clipped.has_area():
			actual.append(clipped)
	var original: Array[Rect2] = []
	for child: Node in fixed.get_children():
		if not child is StaticBody2D:
			continue
		var shape: CollisionShape2D
		for component: Node in child.get_children():
			if component is CollisionShape2D:
				shape = component
		if shape != null and shape.shape is RectangleShape2D:
			var rect := Rect2(child.position - shape.shape.size / 2.0, shape.shape.size)
			var clipped := rect.intersection(core)
			if clipped.has_area():
				original.append(clipped)
	check.call(actual.size() == original.size(), "Boss approach fixed combat core retains exact legacy collision body count")
	for rect: Rect2 in original:
		check.call(actual.has(rect), "Boss approach fixed combat core preserves actual DemoStage clipped collision " + str(rect))
	check.call(module.definition.platforms.has(Rect2(1000, 500, 220, 18)), "Boss receiving platform matches the existing fixed Boss attack space exactly")
	fixed.free()
