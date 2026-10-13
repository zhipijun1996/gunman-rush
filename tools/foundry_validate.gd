extends SceneTree
## Real Motor input traces, swept hazards, deterministic input replay and bounded repair.
signal fixture_created(ok: bool)
const PLAYER := preload("res://scenes/player/player.tscn")
const DT := 1.0 / 60.0
var world: Node2D
var stage: FoundryWorld
var motor: PlayerMotor
var controller: PlayerController
var frames: Array = []
var errors: Array[String] = []
var previous := Vector2.ZERO
var previous_hazards: Dictionary = {}
var safe := true
var shots := 0
var total_ticks := 0
var max_ticks := 5400
var assertions := 0
var failures := 0
var count := 24
var profile_id := "base"
var output := "res://build/foundry/batch.json"
var filter_id := ""

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		errors.append(message)
		safe = false

func fixture(manifest: Dictionary) -> bool:
	# Uniform idle creation + one complete environment frame. AnimatableBody
	# velocity must settle identically in the validator and actual consumer.
	_create_fixture.call_deferred(manifest)
	var ok: bool = await fixture_created
	if not ok: return false
	await physics_frame
	await process_frame
	return true

func _create_fixture(manifest: Dictionary) -> void:
	if is_instance_valid(world): world.free()
	world = Node2D.new()
	root.add_child(world)
	stage = FoundryWorld.new()
	world.add_child(stage)
	if not stage.build(manifest): fixture_created.emit(false); return
	motor = PLAYER.instantiate() as PlayerMotor
	motor.position = stage.entry() # Only initial spawn. Never reset during a route.
	world.add_child(motor)
	controller = motor.get_node("Controller") as PlayerController
	if not FoundryCatalog.apply_profile(controller, manifest.capability_profile): fixture_created.emit(false); return
	controller.set_physics_process(false)
	motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	controller.shoot_ability.shot_fired.connect(func(_direction: Vector2, _id: int) -> void: shots += 1)
	frames.clear()
	errors.clear()
	safe = true
	shots = 0
	total_ticks = 0
	previous = motor.global_position
	previous_hazards.clear()
	for m: PlatformingModule in stage.modules:
		for h: ModuleSawHazard in m.hazards: previous_hazards[h.get_instance_id()] = h.global_position
	fixture_created.emit(true)

func tick(n: int = 1) -> void:
	for unused: int in n:
		await physics_frame
		if total_ticks >= max_ticks:
			check(false, "bounded_trace_budget_exhausted")
			return
		var actions: Array = []
		for action: Dictionary in controller.router._queue:
			actions.append({"type": str(action.type), "direction": [action.direction.x, action.direction.y]})
		var axis := controller.router.axis
		controller.physics_tick(DT)
		total_ticks += 1
		var pos := motor.global_position
		if pos.distance_to(previous) > 30.0: check(false, "unexpected_discontinuity")
		var body := Rect2(pos - Vector2(12, 18), Vector2(24, 36))
		var sweep := body.merge(Rect2(previous - Vector2(12, 18), Vector2(24, 36)))
		for danger: Rect2 in stage.static_dangers():
			if sweep.intersects(danger, true):
				if safe: errors.append("static_hazard@%d" % total_ticks)
				safe = false
		for m: PlatformingModule in stage.modules:
			for h: ModuleSawHazard in m.hazards:
				var old: Vector2 = previous_hazards.get(h.get_instance_id(), h.global_position)
				if SawHazard.swept_contact(previous - old, pos - h.global_position, Vector2(12, 18), h.definition.radius):
					if safe: errors.append("moving_hazard@%d/%s" % [total_ticks, h.definition.source_id])
					safe = false
				previous_hazards[h.get_instance_id()] = h.global_position
		if not stage.bounds.grow(24).has_point(pos): safe = false
		previous = pos
		frames.append({"axis": axis, "actions": actions, "position": [pos.x, pos.y], "shots": controller.action_resources.shot_charges})

func trace(manifest: Dictionary) -> Dictionary:
	if not await fixture(manifest): return {"ok": false, "errors": ["invalid_definition_or_profile"]}
	await tick(4)
	for module: PlatformingModule in stage.modules:
		var driver = load("res://tests/branch_module_driver.gd").new()
		var id := str(module.definition.module_id)
		var reached := false
		check(module.port_accepts(module.definition.entry_port, motor), "actual_entry_contract/" + id)
		if id in ["plains_thorn_cells", "plains_thorn_wall"]:
			driver.module = module
			driver.motor = motor
			driver.controller = controller
			driver.tick_callback = tick
			driver.check = check
			reached = await load("res://tests/plains_interactive_motion.gd").traverse(driver, module, null)
		else:
			reached = await driver.traverse(module, motor, tick, check)
		check(reached and module.port_accepts(module.definition.exit_port, motor), "actual_exit_contract/" + id)
		if not reached or not safe: break
	var ok := safe and errors.is_empty() and motor.is_on_floor() and motor.global_position.distance_to(stage.exit_point()) < 1.0
	var recording := {"schema": 1, "basis": FoundryCatalog.basis(), "manifest_hash": manifest.hash, "capability_profile": manifest.capability_profile, "frames": frames.duplicate(true)}
	return {"ok": ok, "ticks": total_ticks, "shots": shots, "errors": errors.duplicate(), "recording": recording}

func replay(manifest: Dictionary, recording: Dictionary) -> Dictionary:
	if not await fixture(manifest): return {"ok": false, "reason": "fixture_failed"}
	var maximum_error := 0.0
	for frame: Dictionary in recording.frames:
		controller.router.set_move_axis(float(frame.axis))
		for action: Dictionary in frame.actions:
			controller.router.request_action(StringName(action.type), Vector2(action.direction[0], action.direction[1]))
		await tick()
		maximum_error = maxf(maximum_error, motor.global_position.distance_to(Vector2(frame.position[0], frame.position[1])))
		if not safe or maximum_error > 0.05: break
	return {"ok": safe and maximum_error <= 0.05 and motor.is_on_floor() and motor.global_position.distance_to(stage.exit_point()) < 1.0, "max_position_error": maximum_error, "ticks": total_ticks}

func save_json(path: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value) + "\n")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--count="): count = int(arg.trim_prefix("--count="))
		if arg.begins_with("--profile="): profile_id = arg.trim_prefix("--profile=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--template="): filter_id = arg.trim_prefix("--template=")
	if count < 1 or count > 96 or FoundryCatalog.tuning_for(profile_id) == null:
		print("FOUNDRY: invalid bounded request or unimplemented capability")
		quit(2)
		return
	var templates: Array = FoundryCatalog.catalog().templates.filter(func(t: Dictionary) -> bool: return (filter_id.is_empty() or t.id == filter_id) and profile_id in t.get("profiles", ["base", "double_jump", "air_chain"]))
	if templates.is_empty(): quit(2); return
	var report := {"schema": 1, "basis": FoundryCatalog.basis(), "engine": Engine.get_version_info().string, "profile": profile_id, "accepted": [], "rejected": [], "requested": count, "design_status": "awaiting_playtest", "validation_scope": "continuous_input_only_real_motor_full_body_sweeps_and_input_replay"}
	var accepted_ids: Dictionary = {}
	for index: int in count:
		var t: Dictionary = templates[index % templates.size()]
		var variant: int = (index / templates.size()) % t.variants.size()
		var phase: int = ((index / templates.size()) / t.variants.size()) % FoundryCatalog.PHASES.size()
		var seed_value := "foundry-v1/%s/%d" % [profile_id, index]
		var accepted := false
		for attempt: int in 4:
			var manifest := FoundryCatalog.generate(t.id, variant, (phase + attempt) % 4, seed_value, profile_id)
			if manifest.is_empty():
				report.rejected.append({"request": index, "attempt": attempt, "reason": "geometry_or_capability_rejected", "template_id": t.id})
				continue
			if accepted_ids.has(manifest.id): continue
			var result := await trace(manifest)
			var replay_result := await replay(manifest, result.recording) if result.ok else {"ok": false, "reason": "trace_failed"}
			if result.ok and replay_result.ok:
				var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(manifest))
				check(FoundryCatalog.valid(roundtrip), "json_disk_roundtrip_keeps_identity")
				if not FoundryCatalog.valid(roundtrip):
					report.rejected.append({"request": index, "attempt": attempt, "reason": "json_roundtrip_invalid"})
					continue
				var replay_file := output.get_base_dir().path_join("replays/%s.json" % manifest.id)
				save_json(replay_file, result.recording)
				var disk_recording: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(replay_file))
				var disk_replay := await replay(roundtrip, disk_recording)
				if not disk_replay.ok:
					report.rejected.append({"request": index, "attempt": attempt, "reason": "disk_replay_failed", "replay": disk_replay})
					continue
				report.accepted.append({"manifest": manifest, "ticks": result.ticks, "shots": result.shots, "replay": replay_result, "repair_attempt": attempt, "review": "awaiting_playtest"})
				accepted_ids[manifest.id] = true
				accepted = true
				print("FOUNDRY ACCEPT ", manifest.id, " ticks=", result.ticks, " shots=", result.shots, " repair=", attempt)
				break
			report.rejected.append({"request": index, "attempt": attempt, "manifest": manifest, "errors": result.errors, "replay": replay_result})
			print("FOUNDRY REJECT ", manifest.id, " errors=", result.errors)
		if not accepted: failures += 1
	# Complete mixed itineraries get their own continuous proof and input replay.
	report["connection_proofs"] = []
	report["itineraries"] = []
	if report.accepted.size() >= 3:
		for route_index: int in 6:
			var phrases: Array = []
			var used: Array[String] = []
			var rng := RandomNumberGenerator.new()
			rng.seed = ("foundry-route/%s/%d" % [profile_id, route_index]).hash()
			var pool: Array = report.accepted.duplicate()
			while not pool.is_empty() and phrases.size() < 3:
				var index := rng.randi_range(0, pool.size() - 1)
				var item: Dictionary = pool[index]
				pool.remove_at(index)
				if item.manifest.template_id in used: continue
				used.append(item.manifest.template_id)
				phrases.append(item.manifest)
			var route := FoundryCatalog.itinerary(phrases, "foundry-connection-proof/%s/%d" % [profile_id, route_index])
			var result := await trace(route) if not route.is_empty() else {"ok": false}
			var replay_result := await replay(route, result.recording) if result.ok else {"ok": false}
			var proof := {"ok": result.ok and replay_result.ok, "phrase_ids": phrases.map(func(p: Dictionary) -> String: return p.id), "nodes": route.get("nodes", []).size(), "replay": replay_result}
			report.connection_proofs.append(proof)
			if not proof.ok: failures += 1
			if proof.ok:
				save_json(output.get_base_dir().path_join("replays/%s.json" % route.id), result.recording)
				report.itineraries.append(route)
	report["assertions"] = assertions
	report["failures"] = failures
	save_json(output, report)
	if is_instance_valid(world): world.free()
	print("FOUNDRY: accepted=%d rejected_attempts=%d failures=%d" % [report.accepted.size(), report.rejected.size(), failures])
	quit(1 if failures else 0)
