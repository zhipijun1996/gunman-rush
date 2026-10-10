extends RefCounted

const PLAYER := preload("res://scenes/player/player.tscn")
const MODULE_ROOT := "res://scenes/generation/modules/"
const DT := 1.0 / 60.0
var tree: SceneTree
var check: Callable
var world: Node2D
var motor: PlayerMotor
var controller: PlayerController
var module: Node2D
var respawn: SegmentRespawn
var safe_trace := true
var peak_y := INF
var shot_count := 0

func fixture(id: String, jumps: int = 2, shots: int = 2) -> void:
	if is_instance_valid(world):
		world.free()
	world = Node2D.new()
	tree.root.add_child(world)
	module = load(MODULE_ROOT + id + ".tscn").instantiate()
	world.add_child(module)
	motor = PLAYER.instantiate()
	motor.position = module.world_entry()
	world.add_child(motor)
	controller = motor.get_node("Controller")
	controller.set_physics_process(false)
	motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	motor.tuning.max_jumps = jumps
	motor.tuning.max_air_shots = shots
	controller.action_resources.reset()
	controller.shoot_ability.shot_fired.connect(func(_direction: Vector2, _id: int) -> void: shot_count += 1)
	respawn = SegmentRespawn.new()
	respawn.configure(controller, DemoLifetime.new())
	respawn.danger_bounds.assign(module.world_dangers())
	safe_trace = true
	peak_y = motor.position.y
	shot_count = 0
	await tick(3)

func tick(count: int = 1) -> void:
	for index: int in count:
		await tree.physics_frame
		controller.physics_tick(DT)
		peak_y = minf(peak_y, motor.global_position.y)
		var bounds := Rect2(motor.global_position - Vector2(12, 18), Vector2(24, 36))
		for danger: Rect2 in respawn.danger_bounds:
			if bounds.intersects(danger, true):
				safe_trace = false

func move_to(x: float, limit: int = 280) -> bool:
	for index: int in limit:
		var remaining := x - motor.global_position.x
		controller.router.set_move_axis(clampf(remaining / 5.5, -1.0, 1.0))
		await tick()
		if absf(x - motor.global_position.x) < 0.5:
			controller.router.set_move_axis(0.0)
			await tick()
			return true
	return false

func jump_to(x: float, limit: int = 110) -> bool:
	controller.router.request_action(&"jump")
	for index: int in limit:
		controller.router.set_move_axis(clampf((x - motor.global_position.x) / 5.5, -1.0, 1.0))
		await tick()
		if index > 3 and motor.is_on_floor():
			controller.router.request_action(&"jump_release")
			controller.router.set_move_axis(0.0)
			await tick()
			# Landing position varies with configured speed; finish the safe receiver
			# approach through real input while the full-body hazard monitor remains active.
			return await move_to(x)
	return false

func check_ports(label: String) -> void:
	check.call(motor.is_on_floor() and respawn.is_safe(module.world_entry()), label + " actual entry shape and supporting floor are safe")
	check.call(module.port_accepts(module.definition.entry_port, motor), label + " standing input-free entry accepts real motor")
	for anchor: Vector2 in module.world_anchors():
		check.call(respawn.is_safe(anchor), label + " segment anchor " + str(anchor) + " has full-shape clearance and three-ray floor")

func finish(label: String) -> void:
	controller.router.set_move_axis(0.0)
	await tick(3)
	check.call(motor.is_on_floor() and motor.global_position.distance_to(module.world_exit()) < 1.0, label + " reaches and lands at actual exit using actions only")
	check.call(safe_trace, label + " entire 24x36 collision volume avoids hazards on every physics tick")
	check.call(respawn.is_safe(module.world_exit()), label + " exit has actual shape clearance and supporting floor")
	check.call(module.port_accepts(module.definition.exit_port, motor), label + " exit satisfies velocity, action resources and standing contract")

func crossing() -> void:
	var offset := module.global_position.x
	for pair: Vector2 in [Vector2(260, 475), Vector2(560, 775), Vector2(860, 1075)]:
		check.call(await move_to(pair.x + offset), "crossing walks to authored takeoff")
		check.call(await jump_to(pair.y + offset), "crossing held single jump lands on next physical platform")
	check.call(await move_to(module.world_exit().x), "crossing walks across final landing")

func shaft() -> void:
	check.call(await move_to(590.0), "shaft reaches takeoff on lower platform")
	controller.router.set_move_axis(1.0)
	controller.router.request_action(&"jump")
	await tick(18)
	controller.router.request_action(&"shoot_release", Vector2.DOWN)
	await tick()
	check.call(shot_count == 1 and motor.recoil_burst_remaining > 0.0 and controller.action_resources.shot_charges == motor.tuning.max_air_shots - 1, "shaft downward release spawns a real shot, starts upward burst and consumes one independent air shot")
	controller.router.request_action(&"jump_release")
	check.call(await move_to(module.world_exit().x, 110), "shaft moves to receiver while burst and ballistic motion evolve")
	for index: int in 100:
		if motor.is_on_floor():
			break
		await tick()
	check.call(peak_y < 325.0, "shaft actual recoil raises whole player above 360px receiving floor")

func run(p_tree: SceneTree, p_check: Callable) -> void:
	tree = p_tree
	check = p_check
	for id: String in ["safe_hub", "stepped_crossing", "descending_switchback", "recoil_shaft"]:
		await fixture(id)
		check.call(module.definition.is_valid(), id + " authored definition is valid")
		check_ports(id)
		match id:
			"safe_hub": check.call(await move_to(module.world_exit().x), "hub ground traversal")
			"stepped_crossing": await crossing()
			"descending_switchback": await descend()
			"recoil_shaft": await shaft()
		await finish(id)
	await fixture("safe_hub", 0, 0)
	check.call(await move_to(module.world_exit().x), "zero-jump zero-shot hub remains physically reachable")
	await finish("hub 0/0")
	await fixture("stepped_crossing", 1, 0)
	await crossing()
	await finish("crossing 1/0")
	await fixture("recoil_shaft", 1, 1)
	await shaft()
	await finish("shaft 1/1")
	await fixture("descending_switchback", 0, 0)
	await descend()
	await finish("descending 0/0")
	await _contracts()
	await _seam()
	world.free()

func _contracts() -> void:
	await fixture("recoil_shaft", 3, 3)
	await shaft()
	await finish("shaft 3/3")
	# Fresh valid entry for rejection checks; the prior trace stays action-driven.
	await fixture("recoil_shaft", 3, 3)
	var definition: PlatformingModuleDefinition = module.definition
	for jumps: int in [0, 1, 3]:
		for shots: int in [0, 1, 3]:
			var tuning := PlayerTuning.load_default()
			tuning.max_jumps = jumps
			tuning.max_air_shots = shots
			check.call(definition.supports(tuning) == (jumps >= 1 and shots >= 1), "shaft screens configurable %d jumps/%d shots without hardcoded two-charge rule" % [jumps, shots])
	var tuning := PlayerTuning.load_default()
	tuning.recoil_mode = "legacy_impulse"
	check.call(not definition.supports(tuning), "shaft rejects unsupported impulse-only movement")
	tuning.recoil_mode = "shot_burst"
	tuning.shot_burst_duration = 0.01
	check.call(not definition.supports(tuning), "shaft rejects insufficient configured burst distance")
	controller.jump_ability.enabled = false
	check.call(not module.port_accepts(definition.entry_port, motor), "entry rejects disabled required jump capability")
	controller.jump_ability.enabled = true
	controller.shoot_ability.enabled = false
	check.call(not module.port_accepts(definition.entry_port, motor), "entry rejects disabled required shooting capability")
	controller.shoot_ability.enabled = true
	controller.action_resources.shot_charges = 0
	check.call(not module.port_accepts(definition.entry_port, motor), "entry rejects insufficient real remaining shot resource")
	controller.action_resources.reset()
	motor.normal_velocity = Vector2(400, 0)
	check.call(not module.port_accepts(definition.entry_port, motor), "entry rejects excessive incoming speed")
	motor.reset_motion()
	motor.recoil_velocity = Vector2(0, -30)
	check.call(not module.port_accepts(definition.entry_port, motor), "entry rejects unresolved recoil")
	motor.reset_motion()
	motor.recoil_burst_remaining = 0.02
	check.call(not module.port_accepts(definition.entry_port, motor), "entry rejects unresolved burst phase even with zero recoil vector")
	motor.recoil_burst_remaining = NAN
	check.call(not module.port_accepts(definition.entry_port, motor), "entry rejects nonfinite burst phase")
	motor.reset_motion()
	controller.router.request_action(&"shoot_release", Vector2.UP)
	await tick()
	motor.reset_motion()
	check.call(controller.shoot_ability.cooldown_remaining > 0.0 and not module.port_accepts(definition.entry_port, motor), "entry rejects remaining cooldown from an actual released shot")
	controller.shoot_ability.cooldown_remaining = NAN
	check.call(not module.port_accepts(definition.entry_port, motor), "entry rejects nonfinite shot cooldown")
	controller.shoot_ability.cooldown_remaining = 5.0e-10
	check.call(module.port_accepts(definition.entry_port, motor), "entry accepts cooldown floating-point tolerance without granting shots")
	controller.shoot_ability.cooldown_remaining = 0.0
	check.call(module.port_accepts(definition.entry_port, motor), "entry accepts recovered real shot cooldown")
	check.call(not module.port_accepts(definition.exit_port, motor), "standing at entry does not satisfy a distant exit")
	var invalid := definition.duplicate(true) as PlatformingModuleDefinition
	invalid.entry_port.position = Vector2(300, 200)
	check.call(not invalid.is_valid(), "definition rejects unsupported floating entry")
	invalid = definition.duplicate(true)
	invalid.danger_bounds.append(Rect2(280, 560, 40, 40))
	check.call(not invalid.is_valid(), "definition rejects dangerous entry anchor")
	invalid = definition.duplicate(true)
	invalid.platforms.append(Rect2(2000, 500, 80, 30))
	check.call(not invalid.is_valid(), "definition rejects geometry outside module bounds")
	invalid = definition.duplicate(true)
	invalid.definition_version = 0
	check.call(not invalid.is_valid(), "definition rejects unversioned content")
	invalid = definition.duplicate(true)
	invalid.exit_port.port_id = invalid.entry_port.port_id
	check.call(not invalid.is_valid(), "definition rejects ambiguous duplicate entry and exit port IDs")
	var sibling: PlatformingModule = load(MODULE_ROOT + "recoil_shaft.tscn").instantiate()
	world.add_child(sibling)
	check.call(sibling.definition != definition and sibling.definition.entry_port != definition.entry_port, "independent module instances own separate definition and port state")
	var previous: Vector2 = sibling.definition.entry_port.position
	definition.entry_port.position += Vector2(1, 0)
	check.call(sibling.definition.entry_port.position == previous, "mutating one instance cannot alter sibling entry")

func _seam() -> void:
	await fixture("safe_hub", 1, 0)
	var hub := module
	var next: PlatformingModule = load(MODULE_ROOT + "stepped_crossing.tscn").instantiate()
	next.position = hub.world_exit() - next.definition.entry_port.position
	world.add_child(next)
	await tick(2)
	check.call(next.rotation == 0.0 and next.world_entry() == hub.world_exit(), "hub-to-crossing joins by translation without rotating gravity")
	check.call(await move_to(hub.world_exit().x), "seam reaches first exit via continuous ground traversal")
	check.call(hub.port_accepts(hub.definition.exit_port, motor) and next.port_accepts(next.definition.entry_port, motor), "one real motor satisfies both joined ports at the same location")
	module = next
	respawn.danger_bounds.assign(next.world_dangers())
	await crossing()
	await finish("hub-to-crossing physical seam")

func descend() -> void:
	check.call(await move_to(760.0), "descending first drop arrives at upper-right platform")
	await tick(25)
	check.call(motor.is_on_floor() and absf(motor.position.y - 372.0) < 0.2, "descending lands upper-right intermediate platform")
	check.call(await move_to(380.0), "descending returns left into middle landing")
	await tick(25)
	check.call(motor.is_on_floor() and absf(motor.position.y - 502.0) < 0.2, "descending lands middle-left intermediate platform")
	check.call(await move_to(module.world_exit().x), "descending takes final drop and reaches lower exit")
	await tick(25)
