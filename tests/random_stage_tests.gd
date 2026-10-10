extends RefCounted

const PLAYER := preload("res://scenes/player/player.tscn")
const DT := 1.0 / 60.0
var tree: SceneTree
var check: Callable
var world: Node2D
var stage: Node2D
var motor: PlayerMotor
var controller: PlayerController
var safe_trace := true
var continuous_trace := true
var previous_body := Rect2()
var shots := 0
var trace_ticks := 0
var previous_hazards: Dictionary = {}

func run(p_tree: SceneTree, p_check: Callable) -> void:
	tree = p_tree
	check = p_check
	var generator = load("res://scripts/generation/random_stage_generator.gd").new()
	contracts(generator)
	var zero := PlayerTuning.load_default()
	zero.max_jumps = 0
	zero.max_air_shots = 0
	var easy: Dictionary = find_route(generator, zero, false)
	check.call(not easy.is_empty(), "bounded seed search finds a genuinely generated zero-action complete route")
	if not easy.is_empty():
		await route(easy, zero, "zero jump/shot generated route")
	var tuning := PlayerTuning.load_default()
	tuning.max_jumps = 1
	tuning.max_air_shots = 1
	var action_route: Dictionary = find_route(generator, tuning, true)
	check.call(not action_route.is_empty(), "bounded seed search finds a generated route containing both precise jump and shooting recoil modules")
	if not action_route.is_empty():
		await route(action_route, tuning, "one jump/shot generated route")
	if is_instance_valid(world):
		world.free()

func find_route(generator: RefCounted, tuning: PlayerTuning, require_actions: bool) -> Dictionary:
	for seed_value: int in 160:
		var generated: Dictionary = generator.generate(seed_value, tuning, 6)
		if not generated.get("ok", false):
			continue
		var manifest: Dictionary = generated.manifest
		var ids: Array[String] = []
		for node: Dictionary in manifest.nodes:
			ids.append(str(node.module_id))
		if ids.has("moving_transfer") or (require_actions and ids.has("timed_gallery")):
			continue
		if require_actions and (not ids.has("stepped_crossing") or not ids.has("recoil_shaft")):
			continue
		return manifest
	return {}

func contracts(generator: RefCounted) -> void:
	var tuning := PlayerTuning.load_default()
	var zero := PlayerTuning.load_default()
	zero.max_jumps = 0
	zero.max_air_shots = 0
	var layouts: Dictionary = {}
	for seed_value: int in 40:
		for capability: PlayerTuning in [tuning, zero]:
			var generated: Dictionary = generator.generate(seed_value, capability, 6)
			check.call(generated.get("ok", false), "bounded generation succeeds for seed %d and %d/%d capabilities" % [seed_value, capability.max_jumps, capability.max_air_shots])
			if not generated.get("ok", false):
				continue
			var manifest: Dictionary = generated.manifest
			var repeat: Dictionary = generator.generate(seed_value, capability, 6)
			check.call(JSON.stringify(manifest) == JSON.stringify(repeat.get("manifest", {})), "same seed and capability exactly reproduce all layout/phase/seam data")
			var replay: Dictionary = JSON.parse_string(JSON.stringify(manifest))
			check.call(generator.validate_manifest(replay, capability).get("ok", false), "JSON manifest survives exact replay without rerolling content")
			for node: Dictionary in manifest.nodes:
				var definition: PlatformingModuleDefinition = load("res://resources/generation/modules/" + str(node.module_id) + ".tres")
				check.call(definition.supports(capability), "generated main route never requires absent jumps/shots/recoil")
			layouts[JSON.stringify(manifest.nodes)] = true
	check.call(layouts.size() > 20, "seed sample produces genuinely distinct module/offset arrangements")
	var generated: Dictionary = generator.generate(17, tuning, 6)
	if not generated.get("ok", false):
		return
	var original: Dictionary = generated.manifest
	var invalid: Dictionary = original.duplicate(true)
	invalid["generator_version"] = -1
	check.call(not generator.validate_manifest(invalid, tuning).get("ok", false), "unknown generator version cannot silently replay with current rules")
	invalid = original.duplicate(true)
	invalid.nodes[0]["version"] = -1
	invalid["manifest_hash"] = generator._manifest_hash(invalid)
	check.call(not generator.validate_manifest(invalid, tuning).get("ok", false), "unknown authored module version is rejected")
	invalid = original.duplicate(true)
	invalid.nodes[1]["offset"] = [0, 0]
	invalid["manifest_hash"] = generator._manifest_hash(invalid)
	check.call(not generator.validate_manifest(invalid, tuning).get("ok", false), "overlapping disconnected placement cannot pass replay validation")
	invalid = original.duplicate(true)
	invalid.nodes[1]["module_id"] = "missing_module"
	invalid["manifest_hash"] = generator._manifest_hash(invalid)
	check.call(not generator.validate_manifest(invalid, tuning).get("ok", false), "missing authored module rejects replay rather than substituting a hidden reroll")
	invalid = original.duplicate(true)
	invalid.seams[0]["rect"][2] = 8
	invalid["manifest_hash"] = generator._manifest_hash(invalid)
	check.call(not generator.validate_manifest(invalid, tuning).get("ok", false), "validly signed but physically missing seam collision rejects replay")
	var changed_physics := tuning.duplicate(true) as PlayerTuning
	changed_physics.gravity += 1.0
	check.call(not generator.validate_manifest(original, changed_physics).get("ok", false), "recorded trajectory physics cannot silently replay with changed gravity")
	for field: String in ["camera_profile_id", "camera_profile_version", "engine_version"]:
		invalid = original.duplicate(true)
		invalid[field] = "incompatible"
		invalid["manifest_hash"] = generator._manifest_hash(invalid)
		check.call(not generator.validate_manifest(invalid, tuning).get("ok", false), "unknown recorded " + field + " is rejected rather than silently substituting current presentation/engine")
	invalid = original.duplicate(true)
	invalid["attempt_index"] = 4
	invalid["fallback_id"] = "safe_walk_preview"
	invalid["fallback_reason"] = "bounded_geometry_attempts_exhausted"
	invalid["manifest_hash"] = generator._manifest_hash(invalid)
	check.call(not generator.validate_manifest(invalid, tuning).get("ok", false), "challenge graph cannot claim validated all-safe fallback metadata")
	check.call(not generator.generate(17, tuning, 1000).get("ok", false), "unbounded module count is rejected before generation")
	check.call(JSON.stringify(original) == JSON.stringify(generated.manifest), "negative replay validation never mutates original manifest")

func fixture(manifest: Dictionary, tuning: PlayerTuning) -> void:
	if is_instance_valid(world):
		world.free()
	world = Node2D.new()
	tree.root.add_child(world)
	stage = load("res://scripts/generation/random_stage_assembler.gd").new()
	world.add_child(stage)
	# Materialize the serialized recording, not a fresh call to generation.
	var replay: Dictionary = JSON.parse_string(JSON.stringify(manifest))
	var built: Dictionary = stage.build(replay, tuning)
	check.call(built.get("ok", false), "production assembler materializes recorded nodes and seam collision bodies")
	for index: int in stage.modules.size():
		var recorded: Dictionary = replay.nodes[index]
		var module: PlatformingModule = stage.modules[index]
		check.call(module.position == Vector2(recorded.offset[0], recorded.offset[1]) and str(module.definition.module_id) == recorded.module_id, "JSON replay materializes exact recorded node transform and authored identity")
		for phase: Dictionary in recorded.initial_phases:
			for saw: ModuleSawDefinition in module.definition.saws:
				if str(saw.source_id) == str(phase.id):
					check.call(saw.initial_phase == phase.phase, "JSON replay materializes recorded saw phase without rerolling")
			for ferry: ModuleMovingPlatformDefinition in module.definition.ferries:
				if str(ferry.platform_id) == str(phase.id):
					check.call(ferry.initial_phase == phase.phase, "JSON replay materializes recorded moving platform phase without rerolling")
	motor = PLAYER.instantiate()
	motor.position = stage.world_entry()
	world.add_child(motor)
	controller = motor.get_node("Controller")
	controller.set_physics_process(false)
	motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	motor.tuning.max_jumps = tuning.max_jumps
	motor.tuning.max_air_shots = tuning.max_air_shots
	controller.action_resources.reset()
	controller.shoot_ability.shot_fired.connect(func(_direction: Vector2, _id: int) -> void: shots += 1)
	shots = 0
	trace_ticks = 0
	safe_trace = true
	continuous_trace = true
	previous_body = Rect2(motor.global_position - Vector2(12, 18), Vector2(24, 36))
	previous_hazards.clear()
	for module: PlatformingModule in stage.modules:
		for hazard: ModuleSawHazard in module.hazards:
			previous_hazards[hazard.get_instance_id()] = hazard.global_position
	await tick(3)

func tick(count: int = 1) -> void:
	for unused: int in count:
		await tree.physics_frame
		controller.physics_tick(DT)
		trace_ticks += 1
		var body := Rect2(motor.global_position - Vector2(12, 18), Vector2(24, 36))
		# Player speed/burst limits allow at most 30px per 60Hz tick here.
		if previous_body.get_center().distance_to(body.get_center()) > 30.0:
			continuous_trace = false
		for danger: Rect2 in stage.world_static_dangers():
			if previous_body.merge(body).intersects(danger, true):
				safe_trace = false
		for module: PlatformingModule in stage.modules:
			for hazard: ModuleSawHazard in module.hazards:
				var old_saw: Vector2 = previous_hazards[hazard.get_instance_id()]
				if SawHazard.swept_contact(previous_body.get_center() - old_saw, body.get_center() - hazard.global_position, Vector2(12, 18), hazard.definition.radius):
					safe_trace = false
				previous_hazards[hazard.get_instance_id()] = hazard.global_position
		previous_body = body

func move_to(x: float, budget: int = 310) -> bool:
	for unused: int in budget:
		controller.router.set_move_axis(clampf((x - motor.global_position.x) / 5.5, -1.0, 1.0))
		await tick()
		if absf(x - motor.global_position.x) < 0.6:
			controller.router.set_move_axis(0.0)
			await tick()
			return true
	return false

func jump_to(x: float) -> bool:
	controller.router.request_action(&"jump")
	for frame: int in 110:
		controller.router.set_move_axis(clampf((x - motor.global_position.x) / 5.5, -1.0, 1.0))
		await tick()
		if frame > 3 and motor.is_on_floor():
			controller.router.request_action(&"jump_release")
			controller.router.set_move_axis(0.0)
			await tick(2)
			return absf(x - motor.global_position.x) < 25.0
	return false

func route(manifest: Dictionary, tuning: PlayerTuning, label: String) -> void:
	await fixture(manifest, tuning)
	var respawn := SegmentRespawn.new()
	respawn.configure(controller, DemoLifetime.new())
	respawn.danger_bounds.assign(stage.world_dangers())
	for index: int in stage.modules.size():
		var module: PlatformingModule = stage.modules[index]
		check.call(module.port_accepts(module.definition.entry_port, motor), label + " real resource/velocity contract at module entry %d" % index)
		await traverse(module)
		controller.router.set_move_axis(0.0)
		await tick(3)
		check.call(motor.is_on_floor() and motor.global_position.distance_to(module.world_exit()) < 1.0, label + " physically reaches module exit %d" % index)
		check.call(module.port_accepts(module.definition.exit_port, motor), label + " real exit resource/velocity contract %d" % index)
		if index + 1 < stage.modules.size():
			var next: PlatformingModule = stage.modules[index + 1]
			check.call(await move_to(next.world_entry().x), label + " continuous action input crosses real seam collision %d" % index)
			check.call(motor.is_on_floor() and absf(motor.global_position.y - next.world_entry().y) < 0.2, label + " seam preserves grounding and world height")
			check.call(respawn.is_safe(next.world_entry()), label + " seam arrival has body clearance and actual supporting collision")
	check.call(stage.modules.size() == 6 and trace_ticks > 500, label + " proves a complete six-module stage rather than isolated module fixtures")
	check.call(safe_trace and continuous_trace, label + " complete full-body sweep avoids hazards and never teleports between modules")
	check.call(motor.global_position.distance_to(stage.world_exit()) < 1.0, label + " reaches complete stage finish")
	check.call(shots == (1 if tuning.max_air_shots > 0 else 0) * count_modules(manifest, "recoil_shaft"), label + " uses real release shots only for authored recoil shafts")
	print("RANDOM ROUTE: seed=%s, ids=%s, ticks=%d, shots=%d" % [manifest.seed, str(manifest.nodes.map(func(node: Dictionary): return node.module_id)), trace_ticks, shots])

func count_modules(manifest: Dictionary, id: String) -> int:
	var count := 0
	for node: Dictionary in manifest.nodes:
		if str(node.module_id) == id:
			count += 1
	return count

func traverse(module: PlatformingModule) -> void:
	var offset := module.global_position
	match str(module.definition.module_id):
		"safe_hub", "square_loop", "boss_approach":
			check.call(await move_to(module.world_exit().x), "generated module ground route")
		"stepped_crossing":
			for pair: Vector2 in [Vector2(260, 475), Vector2(560, 775), Vector2(860, 1075)]:
				check.call(await move_to(pair.x + offset.x), "generated stepped takeoff")
				check.call(await jump_to(pair.y + offset.x), "generated actual held jump lands on next platform")
			check.call(await move_to(module.world_exit().x), "generated stepped module exit")
		"descending_switchback":
			check.call(await move_to(760.0 + offset.x), "generated descending right intermediate landing")
			await tick(25)
			check.call(motor.is_on_floor() and absf(motor.global_position.y - (372.0 + offset.y)) < 0.2, "translated descending upper landing")
			check.call(await move_to(380.0 + offset.x), "generated descending left intermediate landing")
			await tick(25)
			check.call(motor.is_on_floor() and absf(motor.global_position.y - (502.0 + offset.y)) < 0.2, "translated descending middle landing")
			check.call(await move_to(module.world_exit().x), "generated descending bottom exit")
			await tick(25)
		"recoil_shaft":
			check.call(await move_to(590.0 + offset.x), "generated recoil takeoff")
			controller.router.set_move_axis(1.0)
			controller.router.request_action(&"jump")
			await tick(18)
			var before_shots := shots
			controller.router.request_action(&"shoot_release", Vector2.DOWN)
			await tick()
			check.call(shots == before_shots + 1 and motor.recoil_burst_remaining > 0.0, "generated translated shaft uses actual projectile and recoil burst")
			controller.router.request_action(&"jump_release")
			check.call(await move_to(module.world_exit().x, 110), "generated recoil receiver reached with input while ballistic motion evolves")
			for unused: int in 100:
				if motor.is_on_floor():
					break
				await tick()
		"timed_gallery":
			check.call(await move_to(420.0 + offset.x), "generated timed gallery reaches safe observation point")
			var saw: ModuleSawHazard = module.hazards[0]
			var previous_y := saw.global_position.y
			var found_window := false
			for unused: int in 250:
				if saw.global_position.y < offset.y + 450.0 and saw.global_position.y < previous_y:
					found_window = true
					break
				previous_y = saw.global_position.y
				await tick()
			check.call(found_window, "generated gallery finds bounded visible safe window at actual arrival phase")
			check.call(await move_to(module.world_exit().x), "generated gallery safely crosses moving saw without jumping or firing")
		_:
			check.call(false, "action trace requires a documented driver for " + str(module.definition.module_id))
