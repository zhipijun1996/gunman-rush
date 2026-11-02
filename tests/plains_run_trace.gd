extends "res://tests/random_stage_tests.gd"
var shot_latch_encounter: Node

func fixture(manifest: Dictionary, tuning: PlayerTuning) -> bool:
	if is_trace_cancelled(): return false
	shot_latch_encounter = null
	if not await super.fixture(manifest, tuning): return false
	if manifest.nodes.any(func(n: Dictionary): return str(n.module_id).begins_with("plains_windchime_")):
		shot_latch_encounter = load("res://game/world/components/generated_shot_latch_encounter.gd").new()
		world.add_child(shot_latch_encounter)
		var installed: bool = shot_latch_encounter.setup(manifest, stage, controller, DemoLifetime.new())
		check.call(installed, "whole-world trace uses production recorded windchime consumer")
		if not installed: return false
		await tick(2)
		if is_trace_cancelled(): return false
	return true


func traverse(module: PlatformingModule) -> void:
	if is_trace_cancelled(): return
	if str(module.definition.module_id).begins_with("plains_windchime_"):
		var latch: ShotLatch = shot_latch_encounter.for_module(module) if is_instance_valid(shot_latch_encounter) else null
		check.call(latch != null, "recorded windchime module has its real gate consumer")
		if latch != null:
			var _cancel_await_2: bool = await load("res://tests/shot_latch_module_driver.gd").new().traverse(module, motor, tick, check, latch)
			if is_trace_cancelled(): return
			check.call(_cancel_await_2, "complete stage uses actual aimed projectile before passing windchime gate")
		return
	if str(module.definition.module_id) in ["plains_recoil_span", "plains_ferry_gears", "plains_recovery_bridge", "plains_recoil_step", "plains_recoil_double", "plains_recoil_chasm", "plains_recoil_chasm_wide", "plains_ferry_one", "plains_ferry_two", "plains_perch_rise", "plains_perch_double", "plains_skip_stones", "plains_thorn_bridge", "plains_thorn_steps", "plains_gear_brook", "plains_gear_glade", "plains_fork_paths", "plains_fork_rest", "plains_door_landing"]:
		var _cancel_await_3: bool = await load("res://tests/branch_module_driver.gd").new().traverse(module, motor, tick, check)
		if is_trace_cancelled(): return
		check.call(_cancel_await_3, "new branch module has an actual bounded input-only driver")
		return
	if not module.definition.main_route.is_empty():
		await spatial_path(module, module.definition.main_route)
		if is_trace_cancelled(): return
		return
	# Formal local reflections traverse reflected static geometry left-to-right,
	# rather than reusing the legacy whole-stage right-to-left action sequence.
	if module.definition.mirrored_horizontal and module.definition.entry_port.direction.x > 0:
		var platforms: Array[Rect2] = module.definition.platforms.duplicate()
		platforms.sort_custom(func(a: Rect2, b: Rect2): return a.position.x < b.position.x)
		for index: int in platforms.size() - 1:
			var takeoff := module.to_global(Vector2(platforms[index].end.x - 35, 0)).x
			var receiver := module.to_global(Vector2(platforms[index + 1].position.x + minf(80, platforms[index + 1].size.x * 0.5), 0)).x
			var _cancel_await_4: bool = await move_to(takeoff)
			if is_trace_cancelled(): return
			check.call(_cancel_await_4, "local reflection reaches actual takeoff")
			var receiver_driver = load("res://tests/branch_module_driver.gd").new()
			receiver_driver.module = module
			receiver_driver.motor = motor
			receiver_driver.controller = controller
			receiver_driver.tick_callback = tick
			receiver_driver.check = check
			var _cancel_await_5: bool = await receiver_driver.jump_to(Vector2(receiver, module.position.y + platforms[index + 1].position.y - 18))
			if is_trace_cancelled(): return
			check.call(_cancel_await_5, "local reflection reaches correct receiving floor then actual landing target")
		var _cancel_await_6: bool = await move_to(module.world_exit().x)
		if is_trace_cancelled(): return
		check.call(_cancel_await_6, "local reflection returns to grounded forward dock")
		return
	var pairs: Array[Vector2] = []
	match str(module.definition.module_id):
		"plains_micro_rise": pairs = [Vector2(100, 235)]
		"plains_meadow_gap": pairs = [Vector2(130, 335)]
		"plains_terraces": pairs = [Vector2(165, 320), Vector2(460, 620)]
		"plains_valley": pairs = [Vector2(165, 320), Vector2(460, 615)]
		"plains_micro_stool", "plains_micro_landing", "plains_long_meadow", "plains_split_terrace":
			var _cancel_await_7: bool = await move_to(module.world_exit().x)
			if is_trace_cancelled(): return
			check.call(_cancel_await_7, "open meadow/optional terrace has continuous reachable main floor")
			return
		"plains_thorn_hop", "plains_gear_hop":
			var _cancel_await_8: bool = await move_to(module.position.x + 25)
			if is_trace_cancelled(): return
			check.call(_cancel_await_8, "compact danger module reaches an actual clear takeoff")
			var _cancel_await_9: bool = await jump_to(module.position.x + 140)
			if is_trace_cancelled(): return
			check.call(_cancel_await_9, "compact danger module uses a real jump over thorn or moving gear")
			var _cancel_await_10: bool = await move_to(module.world_exit().x)
			if is_trace_cancelled(): return
			check.call(_cancel_await_10, "compact danger module reaches its clear grounded dock")
			return
		"plains_boss_arena":
			var _cancel_await_11: bool = await move_to(module.world_exit().x)
			if is_trace_cancelled(): return
			check.call(_cancel_await_11, "fixed Boss core physically traverses a full-width floor")
			return
		_:
			await super.traverse(module)
			if is_trace_cancelled(): return
			return
	for pair: Vector2 in pairs:
		var _cancel_await_12: bool = await move_to(local_x(module, pair.x))
		if is_trace_cancelled(): return
		check.call(_cancel_await_12, "new plains module reaches authored takeoff using real Motor")
		var _cancel_await_13: bool = await jump_to(local_x(module, pair.y))
		if is_trace_cancelled(): return
		check.call(_cancel_await_13, "new plains module held single jump lands on receiver")
	var _cancel_await_14: bool = await move_to(module.world_exit().x)
	if is_trace_cancelled(): return
	check.call(_cancel_await_14, "new plains module reaches coincident docking floor")

func spatial_path(module: PlatformingModule, path: Variant) -> void:
	if is_trace_cancelled(): return
	var _cancel_await_15: bool = await load("res://tests/branch_module_driver.gd").new().follow_path(module, motor, tick, check, path)
	if is_trace_cancelled(): return
	check.call(_cancel_await_15, "spatial path distinguishes walkable floor from equal-height gaps and uses real jumps")
