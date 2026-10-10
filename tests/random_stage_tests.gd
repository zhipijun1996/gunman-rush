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
	var generator_script: Script = load("res://scripts/generation/random_stage_generator.gd")
	check.call(generator_script != null and generator_script.can_instantiate(), "production generator script must compile before runtime proof")
	if generator_script == null or not generator_script.can_instantiate():
		return
	var generator = generator_script.new()
	contracts(generator)
	plains_contracts(generator)
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
	var action_route: Dictionary = find_route(generator, tuning, true, false, 1)
	check.call(not action_route.is_empty(), "bounded seed search finds a generated route containing micro platforms, spikes, macro challenge and moving saws")
	if not action_route.is_empty():
		await route(action_route, tuning, "one jump/shot generated route")
	var advanced := PlayerTuning.load_default()
	var advanced_route: Dictionary = find_route(generator, advanced, true, true, -1)
	check.call(not advanced_route.is_empty(), "bounded seed search finds complete mixed advanced stage with high recoil climb, long gap and alternating ferries")
	if not advanced_route.is_empty():
		await route(advanced_route, advanced, "mirrored default-capability advanced generated route")
	var plains: Dictionary = generator.generate(3, advanced, 14, "plains_standard")
	check.call(plains.ok and plains.manifest.fallback_id.is_empty(), "new plains profile produces an actual nonfallback complete stage")
	if plains.ok:
		await route(plains.manifest, advanced, "plains standard complete generated route")
	if is_instance_valid(world):
		world.free()

func find_route(generator: RefCounted, tuning: PlayerTuning, require_actions: bool, require_advanced: bool = false, handedness: int = 0) -> Dictionary:
	for seed_value: int in 160:
		var generated: Dictionary = generator.generate(seed_value, tuning, 14 if require_advanced else (10 if require_actions else 8))
		if not generated.get("ok", false):
			continue
		var manifest: Dictionary = generated.manifest
		if handedness != 0 and (-1 if manifest.nodes[0].get("mirrored", false) else 1) != handedness:
			continue
		var ids: Array[String] = []
		for node: Dictionary in manifest.nodes:
			ids.append(str(node.module_id))
		if require_actions and (not ids.has("macro_chain") or not ids.has("spike_gap") or not ids.has("saw_gate") or not ids.has("micro_step")):
			continue
		if require_advanced and (not ids.has("challenge_recoil_climb") or not ids.has("challenge_long_gap") or not ids.has("challenge_ferry_ascent")):
			continue
		return manifest
	return {}

func contracts(generator: RefCounted) -> void:
	var tuning := PlayerTuning.load_default()
	var zero := PlayerTuning.load_default()
	zero.max_jumps = 0
	zero.max_air_shots = 0
	var layouts: Dictionary = {}
	var fallback_count := 0
	var handednesses: Dictionary = {}
	for seed_value: int in 40:
		for capability: PlayerTuning in [tuning, zero]:
			var generated: Dictionary = generator.generate(seed_value, capability, 14)
			check.call(generated.get("ok", false), "bounded generation succeeds for seed %d and %d/%d capabilities" % [seed_value, capability.max_jumps, capability.max_air_shots])
			if not generated.get("ok", false):
				continue
			var manifest: Dictionary = generated.manifest
			handednesses[manifest.nodes[0].get("mirrored", false)] = true
			check.call(manifest.terminal_exits.size() == (3 if capability.max_jumps > 0 else 1), "terminal metadata exposes only exits compatible with configured jump resources")
			if not str(manifest.fallback_id).is_empty():
				fallback_count += 1
			if capability == tuning:
				var ids: Array = manifest.nodes.map(func(node: Dictionary): return str(node.module_id))
				check.call(str(manifest.fallback_id).is_empty() and ids.has("macro_chain") and ids.has("spike_gap") and ids.has("saw_gate") and ids.has("challenge_recoil_climb") and ids.has("challenge_long_gap") and ids.has("challenge_ferry_ascent"), "default fourteen-module generation preserves macro, spikes, saws and all three advanced challenges")
			var repeat: Dictionary = generator.generate(seed_value, capability, 14)
			check.call(JSON.stringify(manifest) == JSON.stringify(repeat.get("manifest", {})), "same seed and capability exactly reproduce all layout/phase/seam data")
			var replay: Dictionary = JSON.parse_string(JSON.stringify(manifest))
			check.call(generator.validate_manifest(replay, capability).get("ok", false), "JSON manifest survives exact replay without rerolling content")
			for node: Dictionary in manifest.nodes:
				var definition: PlatformingModuleDefinition = load("res://resources/generation/modules/" + str(node.module_id) + ".tres")
				check.call(definition.supports(capability), "generated main route never requires absent jumps/shots/recoil")
			layouts[JSON.stringify(manifest.nodes)] = true
	check.call(handednesses.size() == 2, "seeded layout generation includes both horizontal handednesses")
	check.call(layouts.size() > 20, "seed sample produces genuinely distinct module/offset arrangements")
	print("RANDOM GENERATION SAMPLE: requests=80, modules=14, fallbacks=%d" % fallback_count)
	var original := find_route(generator, tuning, true, false, 1)
	check.call(not original.is_empty(), "negative replay cases use an actual challenge graph")
	if original.is_empty():
		return
	var generated := {"manifest": original.duplicate(true)}
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
	invalid.seams[0]["point"][0] += 8
	invalid["manifest_hash"] = generator._manifest_hash(invalid)
	check.call(not generator.validate_manifest(invalid, tuning).get("ok", false), "validly signed noncoincident docking point rejects replay")
	invalid = original.duplicate(true)
	invalid["manifest_version"] = 1
	invalid["manifest_hash"] = generator._manifest_hash(invalid)
	check.call(not generator.validate_manifest(invalid, tuning).get("ok", false), "old bridge manifest cannot be replayed as seamless geometry")
	invalid = original.duplicate(true)
	invalid["manifest_version"] = 3
	invalid["manifest_hash"] = generator._manifest_hash(invalid)
	check.call(not generator.validate_manifest(invalid, tuning).get("ok", false), "signed pre-reflection v3 manifest cannot replay as typed-port mirrored topology")
	invalid = original.duplicate(true)
	invalid.nodes[1]["mirrored"] = not bool(invalid.nodes[1].get("mirrored", false))
	invalid["manifest_hash"] = generator._manifest_hash(invalid)
	check.call(not generator.validate_manifest(invalid, tuning).get("ok", false), "signed reflected node with original transform cannot silently disconnect the route")
	invalid = original.duplicate(true)
	invalid.nodes[1]["entry_port_id"] = "nonexistent_entry"
	invalid["manifest_hash"] = generator._manifest_hash(invalid)
	check.call(not generator.validate_manifest(invalid, tuning).get("ok", false), "signed unknown selected entry port cannot load a hidden substitute")
	invalid = original.duplicate(true)
	invalid.terminal_exits[0]["position"][0] += 1.0
	invalid["manifest_hash"] = generator._manifest_hash(invalid)
	check.call(not generator.validate_manifest(invalid, tuning).get("ok", false), "signed terminal endpoint drift cannot change branch completion coordinates")
	invalid = original.duplicate(true)
	invalid.seams[0]["rect"] = [0, 0, 400, 32]
	invalid["manifest_hash"] = generator._manifest_hash(invalid)
	check.call(not generator.validate_manifest(invalid, tuning).get("ok", false), "even validly signed seamless recordings reject added connector geometry")
	var board := generator.definition_for("micro_board") as PlatformingModuleDefinition
	var offset := board.exit_port.position - board.entry_port.position
	var dock := Rect2(board.exit_port.position + Vector2(-24, 18), Vector2(48, 64))
	check.call(generator._compatible_geometry(board, Vector2.ZERO, board, offset, dock), "forty-pixel shared docking support is intentional seamless geometry")
	check.call(not generator._compatible_geometry(board, Vector2.ZERO, board, Vector2(80, 0), dock), "arbitrary platform overlap outside docking collar is rejected")
	var hazardous := board.duplicate(true) as PlatformingModuleDefinition
	hazardous.danger_bounds.append(Rect2(board.exit_port.position - Vector2(20, 20), Vector2(40, 40)))
	check.call(not generator._clear_dock(board.exit_port.position, hazardous, Vector2.ZERO), "hazard volume cannot enter shared actor docking clearance")
	var widths: Dictionary = {}
	for id: String in generator.CATALOG:
		widths[generator.definition_for(id).world_bounds.size.x] = true
	check.call(widths.size() >= 4, "authored catalog mixes tiny platforms and large challenges rather than equal screens")
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

func plains_contracts(generator: RefCounted) -> void:
	var tuning := PlayerTuning.load_default()
	var envelope := MovementCapabilityEnvelope.snapshot(tuning)
	check.call(float(envelope.held_jump_height) > float(envelope.tap_jump_height) and float(envelope.held_jump_height) > 150.0 and float(envelope.held_jump_height) < 180.0, "screening envelope separates tap/hold and uses fixed-step current tuning")
	check.call(envelope.scope == "collision_free_single_jump_screening_not_reachability", "estimates explicitly do not claim collision or actual route proof")
	var arrangements: Dictionary = {}
	for profile: String in ["plains_intro", "plains_standard"]:
		for seed_value: int in 20:
			var generated: Dictionary = generator.generate(seed_value, tuning, 14, profile)
			check.call(generated.ok, "bounded plains profile generation succeeds")
			if not generated.ok:
				continue
			var manifest: Dictionary = generated.manifest
			check.call(manifest.fallback_id.is_empty() and manifest.profile_id == profile, "compatible plains seeds retain requested profile and do not silently flatten fallback")
			check.call(generator.validate_manifest(JSON.parse_string(JSON.stringify(manifest)), tuning).ok, "recorded plains profile/envelope/budgets survive JSON replay")
			check.call(JSON.stringify(generator.generate(seed_value, tuning, 14, profile).manifest) == JSON.stringify(manifest), "same plains seed exactly replays pressure, selected content and phase")
			var advanced_count := 0
			var pressure_chain := 0
			for index: int in manifest.nodes.size():
				var node: Dictionary = manifest.nodes[index]
				advanced_count += 1 if str(node.module_id).begins_with("challenge_") else 0
				pressure_chain = pressure_chain + 1 if int(node.pressure.p) >= 2 or int(node.pressure.t) >= 2 else 0
				check.call(pressure_chain <= int(manifest.profile_budget.max_pressure_chain), "plains selected schedule respects consecutive pressure budget")
				check.call(index >= 2 or node.module_id == "micro_board", "plains has an existing seamless safe landing start")
			check.call(advanced_count <= (1 if profile == "plains_standard" else 0), "plains does not force all three expert challenges into every map")
			arrangements[JSON.stringify(manifest.nodes)] = true
	check.call(arrangements.size() > 20, "plains maps vary module sizes, vertical offsets, phases and handedness across seeds")
	for weakness: String in ["jump", "gravity", "speed", "burst", "cooldown"]:
		var weak := PlayerTuning.load_default()
		match weakness:
			"jump": weak.jump_speeds = [-80.0, -80.0]
			"gravity": weak.gravity = 12000.0
			"speed": weak.ground_speed = 60.0
			"burst": weak.shot_burst_speed = 100.0
			"cooldown": weak.shot_cooldown = 2.0
		check.call(not generator.definition_for("challenge_recoil_climb").supports(weak) and not generator.definition_for("challenge_long_gap").supports(weak), "advanced screening rejects inadequate " + weakness + " while retaining configured action counts")
		var generated: Dictionary = generator.generate(9, weak, 14, "plains_standard")
		check.call(generated.ok, "weak tuning gets bounded compatible same-profile preview")
		if generated.ok:
			for node: Dictionary in generated.manifest.nodes:
				check.call(generator.definition_for(node.module_id).supports(weak), "weak configuration only uses explicitly supported authored modules")
			if weakness in ["jump", "gravity", "speed"]:
				check.call(generated.manifest.terminal_exits.size() == 1 and generated.manifest.terminal_exits[0].id == "exit_lower_right", "weak physical ability excludes authored unreachable upper terminal choices")
			check.call(not generator.validate_manifest(generated.manifest, tuning).ok, "manifest cannot replay against different physical abilities")
	var invalid_tuning := PlayerTuning.load_default()
	invalid_tuning.jump_hold_duration = 1000.0
	check.call(MovementCapabilityEnvelope.snapshot(invalid_tuning).is_empty() and not generator.generate(3, invalid_tuning, 14, "plains_standard").ok, "bounded envelope exhaustion fails instead of fabricating a huge range")
	invalid_tuning = PlayerTuning.load_default()
	invalid_tuning.gravity = NAN
	check.call(MovementCapabilityEnvelope.snapshot(invalid_tuning).is_empty(), "nonfinite physical inputs are rejected")
	var original: Dictionary = generator.generate(3, tuning, 14, "plains_standard").manifest
	for field: String in ["profile_id", "profile_budget", "movement_envelope"]:
		var invalid := original.duplicate(true)
		invalid[field] = "forged"
		invalid.manifest_hash = generator._manifest_hash(invalid)
		check.call(not generator.validate_manifest(invalid, tuning).ok, "rehashed tampered " + field + " is rejected independently of checksum")
	var invalid := original.duplicate(true)
	invalid.nodes[2].pressure.p = 0
	invalid.manifest_hash = generator._manifest_hash(invalid)
	check.call(not generator.validate_manifest(invalid, tuning).ok, "authored spike pressure cannot be understated in a rehashed recording")
	check.call(not generator.generate(3, tuning, 14, "unavailable_biome").ok, "unknown content profile fails instead of opening an unimplemented biome")

func fixture(manifest: Dictionary, tuning: PlayerTuning) -> bool:
	if is_instance_valid(world):
		world.free()
	world = Node2D.new()
	tree.root.add_child(world)
	var assembler_script: Script = load("res://scripts/generation/random_stage_assembler.gd")
	check.call(assembler_script != null and assembler_script.can_instantiate(), "production assembler must compile; missing runtime cannot count as successful route")
	if assembler_script == null or not assembler_script.can_instantiate():
		return false
	stage = assembler_script.new()
	world.add_child(stage)
	# Materialize the serialized recording, not a fresh call to generation.
	var replay: Dictionary = JSON.parse_string(JSON.stringify(manifest))
	var built: Dictionary = stage.build(replay, tuning)
	check.call(built.get("ok", false), "production assembler materializes recorded nodes with no artificial connecting platforms")
	if not built.get("ok", false):
		return false
	for index: int in stage.modules.size():
		var recorded: Dictionary = replay.nodes[index]
		var module: PlatformingModule = stage.modules[index]
		check.call(not module.authoring_debug, "assembled gameplay hides authoring ports and module labels")
		check.call(module.definition.mirrored_horizontal == recorded.mirrored, "JSON replay materializes recorded handedness as actual reflected geometry")
		check.call(str(module.definition.entry_port.port_id) == recorded.entry_port_id and str(module.definition.exit_port.port_id) == recorded.exit_port_id, "JSON replay materializes the selected typed docking ports")
		check.call(module.position == Vector2(recorded.offset[0], recorded.offset[1]) and str(module.definition.module_id) == recorded.module_id, "JSON replay materializes exact recorded node transform and authored identity")
		for phase: Dictionary in recorded.initial_phases:
			for saw: ModuleSawDefinition in module.definition.saws:
				if str(saw.source_id) == str(phase.id):
					check.call(saw.initial_phase == phase.phase, "JSON replay materializes recorded saw phase without rerolling")
			for ferry: ModuleMovingPlatformDefinition in module.definition.ferries:
				if str(ferry.platform_id) == str(phase.id):
					check.call(ferry.initial_phase == phase.phase, "JSON replay materializes recorded moving platform phase without rerolling")
	var last: PlatformingModule = stage.modules.back()
	var exits: Array = stage.world_exits()
	check.call(last.definition.module_id == &"route_junction" and exits.size() == manifest.terminal_exits.size(), "assembled stage terminates at an actual multi-exit module")
	var terminal_ids: Dictionary = {}
	for choice: Dictionary in exits:
		var port: PlatformingModulePort = choice.port
		check.call(str(choice.id) == str(port.port_id) and choice.position == last.to_global(port.position), "terminal service exposes each authored port identity and reflected world coordinate")
		terminal_ids[choice.id] = true
	check.call(terminal_ids.size() == manifest.terminal_exits.size(), "capability-compatible terminal exits remain distinct after reflection and JSON replay")
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
	return true

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
				if safe_trace:
					print("TRACE STATIC CONTACT tick=%d body=%s danger=%s" % [trace_ticks, body, danger])
				safe_trace = false
		for module: PlatformingModule in stage.modules:
			for hazard: ModuleSawHazard in module.hazards:
				var old_saw: Vector2 = previous_hazards[hazard.get_instance_id()]
				if SawHazard.swept_contact(previous_body.get_center() - old_saw, body.get_center() - hazard.global_position, Vector2(12, 18), hazard.definition.radius):
					if safe_trace:
						print("TRACE SAW CONTACT tick=%d module=%s saw=%s body=%s center=%s" % [trace_ticks, module.definition.module_id, hazard.definition.source_id, body, hazard.global_position])
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
	if not await fixture(manifest, tuning):
		return
	var respawn := SegmentRespawn.new()
	respawn.configure(controller, DemoLifetime.new())
	respawn.danger_bounds.assign(stage.world_dangers())
	for index: int in stage.modules.size():
		var module: PlatformingModule = stage.modules[index]
		check.call(module.port_accepts(module.definition.entry_port, motor), label + " real resource/velocity contract at module entry %d" % index)
		print("RANDOM TRACE MODULE: index=%d id=%s clock=%.3f entry=%s" % [index, module.definition.module_id, module.clock, motor.global_position])
		await traverse(module)
		controller.router.set_move_axis(0.0)
		await tick(3)
		check.call(motor.is_on_floor() and motor.global_position.distance_to(module.world_exit()) < 1.0, label + " physically reaches module exit %d" % index)
		check.call(module.port_accepts(module.definition.exit_port, motor), label + " real exit resource/velocity contract %d" % index)
		check.call(controller.action_resources.shot_charges == tuning.max_air_shots and controller.jump_ability.used_jumps == 0, label + " real grounded exit resets configurable action resources %d" % index)
		if motor.global_position.distance_to(module.world_exit()) >= 1.0:
			break # Fail above, then stop an unreachable trace within a bounded budget.
		if index + 1 < stage.modules.size():
			var next: PlatformingModule = stage.modules[index + 1]
			check.call(module.world_exit().distance_to(next.world_entry()) < 0.00001, label + " coincident docking needs no intermediate connector %d" % index)
			check.call(stage.get_child_count() == stage.modules.size(), label + " assembler adds no green connector body")
			check.call(motor.is_on_floor() and absf(motor.global_position.y - next.world_entry().y) < 0.2, label + " seam preserves grounding and world height")
			check.call(respawn.is_safe(next.world_entry()), label + " seam arrival has body clearance and actual supporting collision")
	check.call(stage.modules.size() == manifest.nodes.size() and stage.modules.size() >= 8 and trace_ticks > 200, label + " proves a complete recorded mixed stage rather than isolated module fixtures")
	check.call(safe_trace and continuous_trace, label + " complete full-body sweep avoids hazards and never teleports between modules")
	check.call(motor.global_position.distance_to(stage.world_exit()) < 1.0, label + " reaches complete stage finish")
	var expected_shots := 3 * count_modules(manifest, "challenge_recoil_climb") + 2 * count_modules(manifest, "challenge_long_gap")
	check.call(shots == expected_shots, label + " emits the exact real released projectiles required by each authored recoil challenge")
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
		"micro_board", "safe_hub", "square_loop", "boss_approach", "route_junction":
			check.call(await move_to(module.world_exit().x), "generated module ground route")
		"challenge_recoil_climb", "challenge_long_gap":
			var driver = load("res://tests/challenge_recoil_tests.gd").new()
			check.call(await driver.traverse(module, motor, tick, check), "generated recoil challenge uses reusable actual-input physical driver")
		"challenge_ferry_ascent":
			var driver = load("res://tests/challenge_ferry_tests.gd").new()
			check.call(await driver.traverse(module, motor, tick, check), "generated ferry ascent uses engine carry and actual action input")
		"micro_drop":
			check.call(await move_to(module.world_exit().x), "micro drop traverses natural fall without extra actions")
			await tick(30)
		"micro_step":
			check.call(await move_to(local_x(module, 140.0)), "micro step reaches takeoff on the small platform")
			check.call(await jump_to(local_x(module, 260.0)), "micro step crosses actual gap and rises to receiver")
			check.call(await move_to(module.world_exit().x), "micro step reaches shared docking floor")
		"spike_gap":
			check.call(await move_to(local_x(module, 165.0)), "spike gap reaches first takeoff")
			check.call(await jump_to(local_x(module, 380.0)), "spike gap clears the hole and lands before spikes")
			check.call(await move_to(local_x(module, 395.0)), "spike strip reaches safe takeoff")
			check.call(await jump_to(local_x(module, 560.0)), "actual jump clears raised spike strip with full actor body")
			check.call(await move_to(module.world_exit().x), "spike gap reaches seam without damage")
		"macro_chain":
			for pair: Vector2 in [Vector2(185, 385), Vector2(465, 655), Vector2(735, 890)]:
				check.call(await move_to(local_x(module, pair.x)), "macro chain reaches authored takeoff")
				check.call(await jump_to(local_x(module, pair.y)), "macro chain lands on authored receiver with held jump")
			var vertical: ModuleSawHazard = module.hazards[0]
			var last_y := vertical.global_position.y
			var opened := false
			for unused: int in 600:
				if vertical.global_position.y < offset.y + 410.0 and vertical.global_position.y < last_y:
					opened = true
					break
				last_y = vertical.global_position.y
				await tick()
			check.call(opened, "macro chain observes actual vertical saw phase before crossing")
			check.call(await move_to(local_x(module, 1045.0)), "macro chain crosses timed vertical saw on platform")
			check.call(await jump_to(local_x(module, 1180.0)), "macro chain lands before horizontal gear travel envelope")
			var horizontal: ModuleSawHazard = module.hazards[1]
			var last_x := horizontal.global_position.x
			var horizontal_window := false
			for unused: int in 600:
				if route_sign(module) * (horizontal.global_position.x - local_x(module, 1280.0)) > 0.0 and route_sign(module) * (horizontal.global_position.x - last_x) > 0.0:
					horizontal_window = true
					break
				last_x = horizontal.global_position.x
				await tick()
			check.call(horizontal_window, "macro waits until horizontal gear moves away before taking off")
			check.call(await jump_to(local_x(module, 1410.0)), "macro chain jumps above small horizontally moving gear")
			check.call(await move_to(module.world_exit().x), "large continuous macro challenge reaches its final docking floor")
		"saw_gate":
			for hazard: ModuleSawHazard in module.hazards:
				var center_x := offset.x + hazard.definition.origin.x
				var hold_x := center_x - route_sign(module) * (hazard.definition.radius + 60.0)
				check.call(await move_to(hold_x), "moving saw gate reaches its safe observation platform")
				var prior_y := hazard.global_position.y
				var window := false
				for unused: int in 600:
					if hazard.global_position.y < module.world_entry().y - hazard.definition.radius - 95.0 and hazard.global_position.y < prior_y:
						window = true
						break
					prior_y = hazard.global_position.y
					await tick()
				check.call(window, "moving saw gate opens a bounded rising safe window at actual arrival phase")
				check.call(await move_to(center_x + route_sign(module) * (hazard.definition.radius + 48.0)), "moving saw gate crosses moving teeth with actual action input")
			check.call(await move_to(module.world_exit().x), "varied moving saw gate reaches seamless next module")
		"stepped_crossing":
			for pair: Vector2 in [Vector2(260, 475), Vector2(560, 775), Vector2(860, 1075)]:
				check.call(await move_to(local_x(module, pair.x)), "generated stepped takeoff")
				check.call(await jump_to(local_x(module, pair.y)), "generated actual held jump lands on next platform")
			check.call(await move_to(module.world_exit().x), "generated stepped module exit")
		"descending_switchback":
			check.call(await move_to(local_x(module, 760.0)), "generated descending right intermediate landing")
			await tick(25)
			check.call(motor.is_on_floor() and absf(motor.global_position.y - (372.0 + offset.y)) < 0.2, "translated descending upper landing")
			check.call(await move_to(local_x(module, 380.0)), "generated descending left intermediate landing")
			await tick(25)
			check.call(motor.is_on_floor() and absf(motor.global_position.y - (502.0 + offset.y)) < 0.2, "translated descending middle landing")
			check.call(await move_to(module.world_exit().x), "generated descending bottom exit")
			await tick(25)
		"recoil_shaft":
			check.call(await move_to(local_x(module, 590.0)), "generated recoil takeoff")
			controller.router.set_move_axis(route_sign(module))
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
			check.call(await move_to(local_x(module, 420.0)), "generated timed gallery reaches safe observation point")
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

func route_sign(module: PlatformingModule) -> float:
	return -1.0 if module.definition.mirrored_horizontal else 1.0

func local_x(module: PlatformingModule, canonical_x: float) -> float:
	var x := canonical_x
	if module.definition.mirrored_horizontal:
		x = module.definition.world_bounds.position.x + module.definition.world_bounds.end.x - canonical_x
	return module.to_global(Vector2(x, 0)).x
