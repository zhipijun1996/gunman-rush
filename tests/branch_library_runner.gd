extends SceneTree
## Actual translated and reflected Motor fixtures; never relocate after spawn.
const PLAYER := preload("res://scenes/player/player.tscn")
const IDS := ["plains_recoil_span", "plains_ferry_gears", "plains_recovery_bridge", "plains_bramble_causeway", "plains_high_perches", "plains_bramble_ridge", "plains_recoil_step", "plains_recoil_double", "plains_recoil_chasm", "plains_recoil_chasm_wide", "plains_ferry_one", "plains_ferry_two", "plains_perch_rise", "plains_perch_double", "plains_skip_stones", "plains_thorn_bridge", "plains_thorn_steps", "plains_gear_brook", "plains_gear_glade", "plains_fork_paths", "plains_fork_rest", "plains_door_landing"]
const DYNAMIC := ["plains_ferry_gears", "plains_ferry_one", "plains_ferry_two", "plains_gear_brook", "plains_gear_glade"]
var assertions := 0
var failures := 0
var world: Node2D
var module: PlatformingModule
var motor: PlayerMotor
var controller: PlayerController
var safe_trace := true
var continuous_trace := true
var old_body := Rect2()
var old_hazards: Dictionary = {}
var trace_ticks := 0
var shots := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("LIBRARY FAIL: " + message)

func fixture(id: String, mirrored: bool, phase: float) -> void:
	if is_instance_valid(world): world.free()
	world = Node2D.new()
	root.add_child(world)
	module = load("res://scenes/generation/modules/%s.tscn" % id).instantiate() as PlatformingModule
	module.definition = ModuleReflection.reflected_definition(module.definition) if mirrored else module.definition.duplicate(true)
	for saw: ModuleSawDefinition in module.definition.saws: saw.initial_phase = phase
	for ferry: ModuleMovingPlatformDefinition in module.definition.ferries: ferry.initial_phase = phase
	module.position = Vector2(73, -41)
	world.add_child(module)
	motor = PLAYER.instantiate() as PlayerMotor
	motor.position = module.world_entry()
	world.add_child(motor)
	if id in ["plains_recoil_chasm", "plains_recoil_chasm_wide"]:
		motor.tuning.max_jumps = 2 # Later ability fixture; excluded from single-jump plains.
		motor.tuning.max_air_shots = 2 # Explicit historical/later 2-shot fixture, not current R3 tuning.
	controller = motor.get_node("Controller") as PlayerController
	controller.set_physics_process(false)
	motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	controller.shoot_ability.shot_fired.connect(func(_direction: Vector2, _id: int): shots += 1)
	safe_trace = true
	continuous_trace = true
	shots = 0
	trace_ticks = 0
	old_body = Rect2(motor.global_position - Vector2(12, 18), Vector2(24, 36))
	old_hazards.clear()
	for h: ModuleSawHazard in module.hazards: old_hazards[h.get_instance_id()] = h.global_position
	await tick(3)
	check(module.definition.is_valid() and module.definition.supports(motor.tuning), id + " reflected/translated authored contract and capability are valid")
	check(module.port_accepts(module.definition.entry_port, motor), id + " fixture stands at real authored entry")

func tick(count := 1) -> void:
	for unused: int in count:
		await physics_frame
		controller.physics_tick(1.0 / 60)
		trace_ticks += 1
		var body := Rect2(motor.global_position - Vector2(12, 18), Vector2(24, 36))
		if body.get_center().distance_to(old_body.get_center()) > 30: continuous_trace = false
		for danger: Rect2 in module.world_static_dangers():
			if body.merge(old_body).intersects(danger, true):
				if safe_trace: print("LIBRARY STATIC CONTACT id=%s tick=%d body=%s danger=%s" % [module.definition.module_id, trace_ticks, body, danger])
				safe_trace = false
		for h: ModuleSawHazard in module.hazards:
			if SawHazard.swept_contact(old_body.get_center() - old_hazards[h.get_instance_id()], body.get_center() - h.global_position, Vector2(12, 18), h.definition.radius):
				if safe_trace: print("LIBRARY GEAR CONTACT id=%s tick=%d body=%s center=%s" % [module.definition.module_id, trace_ticks, body, h.global_position])
				safe_trace = false
			old_hazards[h.get_instance_id()] = h.global_position
		old_body = body

func finish(label: String, endpoint: Vector2, expected_shots: int) -> void:
	controller.router.set_move_axis(0)
	await tick(3)
	check(motor.is_on_floor() and motor.global_position.distance_to(endpoint) < 1, label + " exact exit is grounded with full-body support")
	check(safe_trace, label + " continuous full 24x36 swept body avoids static brambles and moving gears")
	check(continuous_trace, label + " obeys actual Motor displacement bound without any teleport")
	check(shots == expected_shots, label + " emits exact actual projectile count")
	check(controller.action_resources.shot_charges == motor.tuning.max_air_shots and controller.jump_ability.used_jumps == 0, label + " actual landing restores configured jumps and shots")
	check(module.scale == Vector2.ONE, label + " reflection preserves positive physics-node scale")
	print("BRANCH LIBRARY TRACE: %s ticks=%d shots=%d" % [label, trace_ticks, shots])

func current_one_shot_admission() -> void:
	var tuning_hash := FileAccess.get_sha256("res://config/player_tuning.json")
	var current := PlayerTuning.load_default()
	check(current != null and current.max_air_shots == 1, "current R3 config retains the authorized one airborne shot")
	var profile := RunProfile.formal()
	check(profile.is_valid(true), "current admission uses the actual formal RunProfile")
	var catalog := RandomStageGenerator.new()
	for id: String in ["plains_recoil_chasm", "plains_recoil_chasm_wide"]:
		var definition := catalog.definition_for(id)
		check(definition != null and definition.is_valid(), id + " actual authored module remains valid")
		check(not definition.supports(current), id + " is excluded by current one-shot module capability")
		check(not definition.entry_port.supports(current), id + " entry rejects current one-shot capability")
		var two_jump_one_shot := PlayerTuning.load_default()
		two_jump_one_shot.max_jumps = definition.min_jumps
		check(two_jump_one_shot.max_air_shots == current.max_air_shots and not definition.supports(two_jump_one_shot), id + " even authored jump capability cannot bypass the one-shot exclusion")
		check(not definition.entry_port.supports(two_jump_one_shot), id + " two-jump one-shot entry is independently rejected")
	# Actual current formal generator/manifests, using the real profile's map count.
	# These are admission checks, not a claim that configuration proves traversal.
	var generator := PlainsRegionGenerator.new()
	for map_index: int in range(1, profile.stages_per_biome + 1):
		var seed_value := PlainsRegionCampaign.seed_for("branch-library-current-one-shot", map_index)
		var generated := generator.generate(seed_value, current, false, "", "intro" if map_index == 1 else "advanced")
		check(generated.ok, "current one-shot formal map %s produces an actual Manifest" % map_index)
		if not generated.ok: continue
		var manifest: Dictionary = generated.manifest
		check(not manifest.nodes.is_empty() and generator.validate(manifest, current), "current one-shot formal map %s passes original Manifest validation" % map_index)
		var incompatible: Array[String] = []
		for node: Dictionary in manifest.nodes:
			if str(node.module_id) in ["plains_recoil_chasm", "plains_recoil_chasm_wide"]: incompatible.append(str(node.module_id))
		check(incompatible.is_empty(), "current one-shot actual formal map %s excludes both two-shot chasm modules" % map_index)
		print("BRANCH CURRENT ADMISSION: map=", map_index, " seed=", seed_value, " hash=", manifest.manifest_hash, " forbidden=", incompatible.size(), " max_air_shots=", current.max_air_shots)
	check(FileAccess.get_sha256("res://config/player_tuning.json") == tuning_hash and PlayerTuning.load_default().max_air_shots == current.max_air_shots, "historical capability checks never rewrite current one-shot configuration")

func _run() -> void:
	if "--verify-failure-exit" in OS.get_cmdline_user_args():
		check(false, "intentional nonzero exit proof")
		print("BRANCH LIBRARY: %d assertions, %d failures" % [assertions, failures])
		quit(1)
		return
	current_one_shot_admission()
	for id: String in IDS:
		for mirrored: bool in [false, true]:
			var phases: Array = [0.0, 0.25, 0.5, 0.75] if id in DYNAMIC else [0.0]
			for phase: float in phases:
				await fixture(id, mirrored, phase)
				var driver = load("res://tests/branch_module_driver.gd").new()
				var label := "%s mirrored=%s phase=%.2f" % [id, mirrored, phase]
				check(await driver.traverse(module, motor, tick, check), label + " bounded actual-input traversal completes")
				var expected_shots := 1 if id in ["plains_recoil_step", "plains_recoil_span"] else (2 if id in ["plains_recoil_double", "plains_recoil_chasm", "plains_recoil_chasm_wide"] else 0)
				await finish(label, module.world_exit(), expected_shots)
				check(module.port_accepts(module.definition.exit_port, motor), label + " grounded velocity/resource contract accepts actual player")
	for mirrored: bool in [false, true]:
		await fixture("plains_recoil_span", mirrored, 0)
		var no_shot_driver = load("res://tests/branch_module_driver.gd").new()
		no_shot_driver.module = module
		no_shot_driver.motor = motor
		no_shot_driver.controller = controller
		no_shot_driver.tick_callback = tick
		check(not await no_shot_driver.recoil_span(false), "long span cannot be crossed by the same normal one-jump trace")
		check(shots == 0 and continuous_trace and motor.global_position.y > module.world_exit().y + 100, "negative proof uses no shots or relocation and misses the far bank")
	# Both fork exit paths are physical, not just terminal metadata.
	for id: String in ["plains_fork_paths", "plains_fork_rest"]:
		for mirrored: bool in [false, true]:
			await fixture(id, mirrored, 0)
			var route: Array[int] = [0]
			route.append_array(Array(module.definition.branch_routes[0]))
			var driver = load("res://tests/branch_module_driver.gd").new()
			check(await driver.follow_path(module, motor, tick, check, route), id + " upper fork uses real jumps and landings")
			var upper: PlatformingModulePort
			for port: PlatformingModulePort in module.definition.get_exit_ports():
				if port.port_id == &"fork_up": upper = port
			await finish(id + " upper mirrored=%s" % mirrored, module.to_global(upper.position), 0)
			check(module.port_accepts(upper, motor), id + " upper fork satisfies actual exit contract")
	# Default normal two jumps, with no shot requests, still cannot span either
	# wide bank: recoil is mechanically required, not merely used by the driver.
	for id: String in ["plains_recoil_chasm", "plains_recoil_chasm_wide"]:
		for mirrored: bool in [false, true]:
			await fixture(id, mirrored, 0)
			var driver = load("res://tests/branch_module_driver.gd").new()
			check(await driver.no_recoil_chasm_falls(module, motor, tick, check), id + " unchanged normal double jump falls before far bank")
			check(shots == 0 and continuous_trace, id + " negative proof uses normal inputs and no projectile or relocation")
	if is_instance_valid(world): world.free()
	print("BRANCH LIBRARY: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
