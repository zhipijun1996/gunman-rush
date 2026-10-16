extends SceneTree
## Real accepted traversal states feed the production gate resolver; no state injection.
var assertions := 0
var failures: Array[String] = []
var case_receipts: Array[Dictionary] = []
func _initialize() -> void:
	if "--log-error-probe" in OS.get_cmdline_user_args():
		push_error("Forest strict log guard plain engine error counterexample")
		print("FOREST LOG GUARD PROBE: emitted plain ERROR with exit 0")
		quit(0)
		return
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		print("FAIL: ",label)
func wait_ticks(count: int) -> void:
	for unused: int in count: await physics_frame
func run() -> void:
	var tuning := PlayerTuning.load_default()
	var generator := ThornForestRegionGenerator.new()
	var handed_seeds: Dictionary = {}
	for seed_index: int in 10:
		for map_index: int in [1,2]:
			var generated: Dictionary = generator.generate("forest-playable-%02d/thorn_forest/map_%s" % [seed_index,map_index],tuning,map_index,{"grapple":true})
			check(generated.ok,"fixed matrix seed generates with actual H")
			var manifest: Dictionary = generated.manifest
			handed_seeds[bool(manifest.nodes[0].mirrored)] = str(manifest.seed)
			var floor_bottom := 0.0
			for platform: Dictionary in manifest.platforms:
				if platform.id == "arena_floor": floor_bottom = ThornForestRegionGenerator._rect(platform.rect).end.y
			var gate := ThornForestRegionGenerator._rect(manifest.vine_gate.rect)
			check(is_equal_approx(gate.end.y,floor_bottom),"gate ends at actual arena floor underside")
			check(gate.position.y <= generated.boss_arena.position.y and gate.end.y >= generated.boss_arena.end.y,"gate still seals whole arena vertical approach")
	check(handed_seeds.size()==2,"fixed matrix has both actual reflected geometries")
	for variant: String in ["key","wrong","live","empty","noH"]:
		await actual_case(variant,generator,tuning)
	for seed_value: String in ["forest-playable-01/thorn_forest/map_1","forest-playable-04/thorn_forest/map_1"]:
		await actual_case("key",generator,tuning,seed_value)
		await actual_below_bypass(generator,tuning,seed_value)
	var output := "res://build/forest_playable/traversal/vine-gate-native-%s-%s.json" % [Time.get_datetime_string_from_system().replace(":",""),Time.get_ticks_usec()]
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"cases":case_receipts,"assertions":assertions,"failures":failures,"generator_sha256":FileAccess.get_sha256("res://scripts/generation/thorn_forest_region_generator.gd")}))
		file.close()
	else: check(false,"native regression evidence opens")
	print("FOREST VINE GATE EVIDENCE: ",output)
	print("FOREST VINE GATE: %s assertions, %s failures" % [assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
func actual_case(variant: String, generator: ThornForestRegionGenerator, tuning: PlayerTuning, seed_value := "forest-playable-01/thorn_forest/map_1") -> void:
	var generated: Dictionary = generator.generate(seed_value,tuning,1,{"grapple":true})
	var manifest: Dictionary = generated.manifest
	var step: Dictionary
	for edge: Dictionary in manifest.connections:
		if edge.id == "crown_approach": step = edge.steps[0]
	var world := Node2D.new()
	root.add_child(world)
	var assembler := ThornForestRegionAssembler.new()
	assembler.region_state = PlainsRegionState.new()
	assembler.region_state.bind_map(str(manifest.manifest_hash))
	world.add_child(assembler)
	check(assembler.build(manifest,tuning).ok,"actual production assembler "+variant)
	var player := preload("res://scenes/player/player.tscn").instantiate() as PlayerMotor
	player.position = Vector2(step.takeoff[0],step.takeoff[1])
	world.add_child(player)
	var controller := player.get_node("Controller") as PlayerController
	player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	if variant != "noH": controller.traversal.grant(&"grapple")
	var live_target: EnemyMotor
	if variant == "live":
		live_target = preload("res://scenes/enemies/forest_lantern.tscn").instantiate() as EnemyMotor
		live_target.position = player.position+Vector2(signf(player.position.x)*-105,-132)
		world.add_child(live_target)
	var events: Array[String] = []
	controller.traversal.action_changed.connect(func(action: StringName) -> void:
		events.append(String(action))
		assembler.resolve_hook_action(controller.traversal))
	await wait_ticks(10)
	check(player.is_on_floor(),"real supported entry "+variant)
	check(not assembler.vine_shape.disabled and not assembler.region_state.opened.has("crown_vine"),"starts physically closed "+variant)
	controller.router.set_jump_held(&"vine_test",true)
	await wait_ticks(12)
	controller.router.set_jump_held(&"vine_test",false)
	var target := Vector2(step.anchor[0],step.anchor[1])
	if variant == "wrong": target = assembler.hook_targets["cache_climb_ring_0"].global_position
	if variant == "live": target = live_target.global_position
	var aim := (target-player.position-Vector2(0,-6)).normalized()
	if variant == "empty": aim = Vector2.UP
	check(controller.router.request_action(&"grapple",aim),"actual Router queues H request "+variant)
	await wait_ticks(90)
	if variant == "key":
		check("hook_kick" in events and assembler.vine_shape.disabled and assembler.region_state.opened.has("crown_vine"),"actual key-ring accepted H opens physical gate and saved state")
	else:
		check(not assembler.vine_shape.disabled and not assembler.region_state.opened.has("crown_vine"),"wrong/empty/noH never opens gate "+variant)
		if variant == "wrong": check("hook_kick" in events,"wrong-anchor negative truly completes H contact and kick")
		if variant == "live": check("hook_kick" in events and controller.traversal.hook_target == live_target,"live-anchor negative truly completes actual enemy H contact and kick")
		if variant == "empty": check("hook_miss" in events and "hook_kick" not in events,"empty negative truly misses without accepted contact")
		if variant == "noH": check("hook_cast" not in events,"ungranted H is actually rejected")
	case_receipts.append({"variant":variant,"seed":seed_value,"mirrored":bool(manifest.nodes[0].mirrored),"actual_events":events.duplicate(),"final_position":[player.position.x,player.position.y],"actual_hook_target":String(controller.traversal.hook_target.name) if is_instance_valid(controller.traversal.hook_target) else "","actual_gate_disabled":assembler.vine_shape.disabled,"saved_gate_open":assembler.region_state.opened.has("crown_vine")})
	var saved := JSON.stringify(assembler.region_state.snapshot())
	var expected_open := variant == "key"
	world.free()
	await process_frame
	await process_frame
	var replay := PlainsRegionState.new()
	check(replay.restore(JSON.parse_string(saved),str(manifest.manifest_hash)),"actual gate JSON saved state restores "+variant)
	var reloaded := ThornForestRegionAssembler.new()
	reloaded.region_state = replay
	root.add_child(reloaded)
	check(reloaded.build(manifest,tuning).ok and reloaded.vine_shape.disabled==expected_open,"fresh actual gate collision restores closed/open "+variant)
	reloaded.free()
	await process_frame
	await process_frame

func actual_below_bypass(generator: ThornForestRegionGenerator, tuning: PlayerTuning, seed_value: String) -> void:
	var generated: Dictionary = generator.generate(seed_value,tuning,1,{"grapple":true})
	var manifest: Dictionary = generated.manifest
	var gate := ThornForestRegionGenerator._rect(manifest.vine_gate.rect)
	var arena: Rect2 = generated.boss_arena
	var world := Node2D.new()
	root.add_child(world)
	var assembler := ThornForestRegionAssembler.new()
	assembler.region_state = PlainsRegionState.new()
	world.add_child(assembler)
	check(assembler.build(manifest,tuning).ok,"under-arena test uses actual production geometry")
	var destination := Vector2.ZERO
	var closest := INF
	var direction := signf(arena.get_center().x-gate.get_center().x)
	for edge: Dictionary in manifest.connections:
		if edge.id == "root_route":
			for step: Dictionary in edge.steps:
				var candidate := Vector2(step.landing[0],step.landing[1])
				if candidate.y > gate.end.y+60 and absf(candidate.x-gate.get_center().x)<closest:
					destination = candidate
					closest = absf(candidate.x-gate.get_center().x)
	var player := preload("res://scenes/player/player.tscn").instantiate() as PlayerMotor
	player.position = destination
	world.add_child(player)
	var controller := player.get_node("Controller") as PlayerController
	player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	await wait_ticks(10)
	check(player.is_on_floor() and not controller.traversal.hook_enabled,"below-gate counterexample starts on actual lower branch without H")
	controller.router.set_move_axis(direction)
	controller.router.set_jump_held(&"gate_bypass",true)
	var crossed_below := false
	var entered_arena := false
	var accepted_jumps: Array[Vector2] = []
	var positions: Array[Dictionary] = []
	controller.jump_ability.jumped.connect(func() -> void: accepted_jumps.append(player.position))
	for tick: int in 150:
		await physics_frame
		positions.append({"tick":tick,"position":[player.position.x,player.position.y],"grounded":player.is_on_floor(),"motor_steps":player.motion_steps,"hook_enabled":controller.traversal.hook_enabled})
		if tick == 45: controller.router.set_jump_held(&"gate_bypass",false)
		if tick == 70: controller.router.set_jump_held(&"gate_bypass",true)
		crossed_below = crossed_below or (direction*(player.position.x-gate.get_center().x)>24 and player.position.y-18>gate.end.y)
		entered_arena = entered_arena or (player.position.x>=arena.position.x+12 and player.position.x<=arena.end.x-12 and player.position.y+18<=arena.end.y+1)
	check(not accepted_jumps.is_empty(),"under-arena bypass attempt has actual accepted held jump")
	case_receipts.append({"variant":"below_noH_bypass","seed":seed_value,"mirrored":bool(manifest.nodes[0].mirrored),"positions":positions,"accepted_jumps":accepted_jumps.size(),"crossed_below":crossed_below,"entered_arena":entered_arena,"gate_rect":[gate.position.x,gate.position.y,gate.size.x,gate.size.y]})
	check(crossed_below,"real noH actor crosses the shortened gate from below")
	check(not entered_arena and not assembler.vine_shape.disabled and not assembler.region_state.opened.has("crown_vine"),"real held jumps from below cannot bypass closed arena entrance")
	world.free()
	await process_frame
	await process_frame
