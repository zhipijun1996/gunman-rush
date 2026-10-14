extends SceneTree
## Candidate/formal-spacing technical proof. No enemy/player/device acceptance.
const SEED := "level-design-v2-baseline/02/plains/map_2"
const EDGE := "plains/passage/area_3_1/area_4_1"
var assertions := 0
var failures := 0
var output := ""
var historical_capture := ""
var broken_bank := false
var observations: Array[Dictionary] = []

class RecordedTrace extends "res://tests/plains_region_trace.gd":
	var frames: Array[Dictionary] = []
	var events: Array[Dictionary] = []
	var leg := "initialization"
	func point(value: Vector2) -> Array:
		return [value.x, value.y]
	func state() -> Dictionary:
		return {"tick": trace_ticks, "leg": leg, "position": point(motor.global_position), "normal_velocity": point(motor.normal_velocity), "recoil_velocity": point(motor.recoil_velocity), "grounded": motor.is_on_floor(), "energy": controller.actor_resources.stamina.current, "energy_capacity": controller.actor_resources.stamina.capacity, "shot_charges": controller.action_resources.shot_charges, "used_jumps": controller.jump_ability.used_jumps, "session_id": controller.session_id, "motor_id": motor.get_instance_id(), "safe": safe_trace, "continuous": continuous_trace}
	func fixture_at(manifest: Dictionary, tuning: PlayerTuning, entry: Vector2, low_energy: bool) -> bool:
		world = Node2D.new()
		tree.root.add_child(world)
		stage = PlainsRegionAssembler.new()
		region_state = PlainsRegionState.new()
		region_state.bind_map(str(manifest.manifest_hash))
		stage.region_state = region_state
		world.add_child(stage)
		if not stage.build(manifest, tuning).ok: return false
		motor = PLAYER.instantiate()
		motor.position = entry # One declared fixture spawn, before adding the body.
		world.add_child(motor)
		motor.tuning.max_jumps = tuning.max_jumps
		motor.tuning.max_air_shots = tuning.max_air_shots
		controller = motor.get_node("Controller")
		check.call(controller.enable_shot_energy(), "real shot energy enabled")
		controller.set_physics_process(false)
		motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
		controller.action_resources.reset()
		if low_energy:
			var stamina := controller.actor_resources.stamina
			check.call(stamina.consume_continuous(stamina.current, stamina.epoch).accepted(), "legal initial zero-energy boundary transaction")
		check.call(controller.actor_resources.stamina.current == (0.0 if low_energy else controller.actor_resources.stamina.capacity), "actual initial energy matches declared boundary before any tick")
		previous_body = Rect2(entry - Vector2(12, 18), Vector2(24, 36))
		for module: PlatformingModule in stage.modules:
			for hazard: ModuleSawHazard in module.hazards: previous_hazards[hazard.get_instance_id()] = hazard.global_position
		shot_latch_encounter = GeneratedShotLatchEncounter.new()
		world.add_child(shot_latch_encounter)
		check.call(shot_latch_encounter.setup(manifest, stage, controller, lifetime), "production latch consumer installed")
		controller.jump_ability.jumped.connect(func(): events.append({"tick": trace_ticks + 1, "leg": leg, "kind": "accepted_jump", "position": point(motor.global_position)}))
		controller.landed.connect(func(): events.append({"tick": trace_ticks + 1, "leg": leg, "kind": "accepted_landing", "position": point(motor.global_position)}))
		controller.shoot_ability.shot_fired.connect(func(_direction: Vector2, _id: int): shots += 1)
		frames.append(state())
		await tick(3)
		return true
	func tick(count: int = 1) -> void:
		for unused: int in count:
			# Observe the actual queued requests without consuming/changing them.
			for action: Dictionary in controller.router._queue:
				events.append({"tick": trace_ticks + 1, "leg": leg, "kind": "input_request", "action": str(action.type), "sequence": action.sequence, "direction": point(action.direction), "position": point(motor.global_position)})
			await super.tick(1) # Original strict whole-body/hazard sweep and Motor.
			frames.append(state())

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--historical-capture="): historical_capture = arg.trim_prefix("--historical-capture=")
		elif arg == "--delete-far-bank": broken_bank = true
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func phrase(trace: RecordedTrace, module: PlatformingModule, label: String) -> Dictionary:
	var start := module.position.x
	var finish := start + module.definition.world_bounds.size.x
	var jumps: Array = trace.events.filter(func(e: Dictionary): return e.leg == label and e.kind == "accepted_jump" and e.position[0] >= start and e.position[0] <= finish)
	var result: Dictionary = {"module": str(module.definition.module_id), "leg": label, "jumps": jumps, "hold_ticks": -1, "landing": {}, "release": {}}
	check(jumps.size() == 1, label + " one actual accepted jump in " + str(module.definition.module_id))
	if jumps.size() != 1: return result
	var jump: Dictionary = jumps[0]
	for event: Dictionary in trace.events:
		if event.leg != label or event.tick <= jump.tick: continue
		if event.kind == "input_request" and event.action == "jump_release" and result.release.is_empty():
			result.release = event
			result.hold_ticks = int(event.tick) - int(jump.tick)
		if event.kind == "accepted_landing" and result.landing.is_empty(): result.landing = event
	check(not result.release.is_empty() and not result.landing.is_empty(), label + " real release and landing after accepted jump")
	if not result.landing.is_empty():
		var p: Array = result.landing.position
		check(absf(float(p[1]) - module.world_entry().y) < 1, label + " actual landing at formal floor height")
		if module.definition.module_id == &"plains_thorn_bridge":
			var rightward: bool = float(p[0]) > float(jump.position[0])
			check(float(p[0]) >= start + 230 - 12 if rightward else float(p[0]) <= start + 100 + 12, label + " gap jump really lands on opposite bank")
	return result
func run_case(manifest: Dictionary, edge: Dictionary, forward: bool, low: bool) -> void:
	var trace := RecordedTrace.new()
	trace.tree = self
	trace.check = check
	var generator := PlainsRegionGenerator.new()
	var area: Dictionary = generator._area(manifest, str(edge.a if forward else edge.b))
	var tuning := PlayerTuning.load_default()
	var entry := Vector2(area.position[0], area.position[1])
	check(await trace.fixture_at(manifest, tuning, entry, low), "actual valid whole-region assembler at declared entry")
	if not is_instance_valid(trace.motor): return
	var bridge: PlatformingModule = trace.stage.modules[int(edge.modules[0])]
	var arch: PlatformingModule = trace.stage.modules[int(edge.modules[1])]
	if broken_bank:
		# Delete a real installed collider, retaining signed metadata unchanged.
		var far_floor := bridge.definition.platforms[1]
		var removed := 0
		for child: Node in bridge.get_children():
			if child is StaticBody2D and child.position.is_equal_approx(far_floor.get_center()):
				bridge.remove_child(child)
				child.free()
				removed += 1
		check(removed == 1, "negative deletes exactly one real receiving-bank collider")
	var body_id := trace.motor.get_instance_id()
	var session := trace.controller.session_id
	var legs: Array[Dictionary] = []
	for outward: bool in [true, false]:
		var direction := forward if outward else not forward
		trace.leg = "outbound" if outward else "return"
		var before := trace.state()
		var reached: bool = await trace.walk_edge(edge, direction)
		check(reached, trace.leg + " endpoint reached by continuous Motor")
		check(trace.safe_trace and trace.continuous_trace, trace.leg + " strict original complete-body sweep remains safe and continuous")
		check(trace.motor.get_instance_id() == body_id and trace.controller.session_id == session, "one body and life across modules and return")
		var phrases: Array[Dictionary] = []
		if reached:
			phrases = [phrase(trace, bridge, trace.leg), phrase(trace, arch, trace.leg)]
			check(int(phrases[0].hold_ticks) > int(phrases[1].hold_ticks) and int(phrases[1].hold_ticks) == 7, "gap held input differs from low-ceiling seven-tick tap/release")
			if phrases.all(func(p: Dictionary): return p.jumps.size() == 1 and not p.landing.is_empty()):
				phrases.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.jumps[0].tick) < int(b.jumps[0].tick))
				check(phrases[0].module == ("plains_thorn_bridge" if direction else "plains_low_arch"), "recorded phrase order follows actual traversal direction")
				check(int(phrases[0].landing.tick) < int(phrases[1].jumps[0].tick), "actual first landing precedes second jump without a body reset")
		legs.append({"direction": direction, "reached": reached, "before": before, "after": trace.state(), "phrases": phrases})
		if not reached: break
	check(trace.shots == 0, "short chain requires zero emitted shots or enemy-hit recovery")
	observations.append({"forward_entry": forward, "low_initial_energy": low, "entry": [entry.x, entry.y], "initial": trace.frames[0], "final": trace.state(), "legs": legs, "events": trace.events, "frames": trace.frames, "shots": trace.shots, "enemy_scope": "no enemy fixture; live formal tests separate", "manual_controller_fixture": true, "resource_initialization_only": true})
	trace.world.free()
func run() -> void:
	var tuning := PlayerTuning.load_default()
	var historical: Variant = JSON.parse_string(FileAccess.get_file_as_string(historical_capture))
	check(historical is Dictionary and historical.get("manifest", {}).get("version") == "plains-region-v8", "original live v8 capture retained for actual compatibility rejection")
	if historical is Dictionary:
		check(not PlainsRegionGenerator.new().validate(historical.manifest, tuning), "real recorded v8 manifest rejected by current v9 generator")
		check(RunManifest.from_snapshot(historical.formal_run_manifest_initial) == null, "real recorded v8 RunManifest rejected by current version contract")
	var app := DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_plains("level-design-v2-baseline/02"), "current real formal DemoApp entry starts")
	for unused: int in 3: await physics_frame
	var current: Dictionary = JSON.parse_string(app.director.manifest.canonical_json())
	check(current.versions.generated_layout == "plains-region-v9" and RunManifest.from_snapshot(current) != null, "current v9 real RunManifest roundtrips without changing save services")
	app.free()
	var generated := PlainsRegionGenerator.new().generate(SEED, tuning, false, "", "advanced")
	check(generated.get("ok", false), "real generation succeeds without fallback substitution")
	if not generated.get("ok", false):
		finish({})
		return
	var manifest: Dictionary = generated.manifest
	check(manifest.attempt == 0 and historical.manifest.attempt == 0, "exact baseline attempt zero preserved")
	var old_edges: Array = historical.manifest.connections.map(func(e: Dictionary): return [e.id, e.a, e.b, e.kind, e.condition])
	var new_edges: Array = manifest.connections.map(func(e: Dictionary): return [e.id, e.a, e.b, e.kind, e.condition])
	var same_topology: bool = old_edges.size() == new_edges.size() and manifest.areas.size() == historical.manifest.areas.size()
	for index: int in old_edges.size():
		for key: int in old_edges[index].size():
			same_topology = same_topology and old_edges[index][key] == new_edges[index][key]
	for index: int in manifest.areas.size():
		var old_area: Dictionary = historical.manifest.areas[index]
		var new_area: Dictionary = manifest.areas[index]
		for key: String in ["id", "role"]:
			same_topology = same_topology and old_area[key] == new_area[key]
		for axis: int in 2:
			same_topology = same_topology and float(old_area.position[axis]) == float(new_area.position[axis])
	check(same_topology, "baseline topology and area placement preserved without resampling")
	var old_observed: Array = historical.edges.filter(func(e: Dictionary): return e.get("edge_id", e.get("id", "")) == EDGE)
	check(old_observed.size() == 1 and old_observed[0].reached, "golden edge has actual historical reached route observation")
	var matches: Array = manifest.connections.filter(func(e: Dictionary): return e.id == EDGE)
	check(matches.size() == 1, "baseline reached semantic edge exists")
	if matches.size() != 1:
		finish(manifest)
		return
	var edge: Dictionary = matches[0]
	check(edge.recipe == "thorn_gap" and edge.modules.size() == 2, "same reached recipe and two-module lane")
	var first: Dictionary = manifest.nodes[int(edge.modules[0])]
	var second: Dictionary = manifest.nodes[int(edge.modules[1])]
	check(first.module_id == "plains_thorn_bridge" and second.module_id == "plains_low_arch", "actual candidate uses certified thorn gap then arch")
	if first.module_id != "plains_thorn_bridge" or second.module_id != "plains_low_arch":
		finish(manifest)
		return
	check(first.offset == [4400.0, -282.0] and second.offset == [4740.0, -282.0], "formal width-based placement, no Foundry forty-unit overlap")
	var join: Array = manifest.nodes.filter(func(n: Dictionary): return n.id == EDGE + "_join")
	check(join.size() == 1 and join[0].offset == [5380.0, 0.0] and join[0].geometry.platforms[0] == [-20.0, 18.0, 40.0, 32.0], "exact forty-unit join with twenty-unit left solid overlap only, total lane remains one thousand")
	var join_definition := PlainsRegionGenerator.definition(join[0])
	check(join[0].geometry.get("standing_margin", 20) == 16 and join_definition.entry_port.position == Vector2(-4,0) and join_definition.exit_port.position == Vector2(4,0) and join_definition.is_valid(), "serialized distinct forty-unit join ports pass unchanged whole-body support")
	var destination: Dictionary = manifest.nodes.filter(func(n: Dictionary): return n.id == edge.b)[0]
	var old_destination: Dictionary = historical.manifest.nodes.filter(func(n: Dictionary): return n.id == edge.b)[0]
	var same_destination: bool = destination.geometry.one_way.size() == old_destination.geometry.one_way.size() and destination.geometry.one_way.has(0)
	for index: int in destination.geometry.one_way.size():
		same_destination = same_destination and int(destination.geometry.one_way[index]) == int(old_destination.geometry.one_way[index])
	for axis: int in 4:
		same_destination = same_destination and float(destination.geometry.platforms[0][axis]) == float(old_destination.geometry.platforms[0][axis])
	check(same_destination, "destination one-way floor remains unchanged")
	check(float(join[0].offset[0]) + float(join[0].geometry.platforms[0][0]) == float(second.offset[0]) + 620.0 and float(join[0].offset[0]) + 20.0 == float(destination.offset[0]) - 200.0, "collar overlaps only last twenty solid arch units and ends before one-way destination")
	for forward: bool in [true, false]:
		for low: bool in [false, true]:
			await run_case(manifest, edge, forward, low)
			if broken_bank: break
		if broken_bank: break
	finish(manifest)
func finish(manifest: Dictionary) -> void:
	if output.is_empty() or FileAccess.file_exists(output):
		printerr("Unique --output required; evidence cannot be overwritten")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "seed": SEED, "edge": EDGE, "manifest": manifest, "observations": observations, "broken_bank": broken_bank, "assertions": assertions, "failures": failures, "scope": "formal geometry and actual continuous Motor technical fixture; visual, live-enemy, fun and device evidence separate"}) + "\n")
	file.close()
	print("PLAINS ACTION GOLDEN: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
