extends "res://tests/random_stage_tests.gd"

func traverse(module: PlatformingModule) -> void:
	# Formal local reflections traverse reflected static geometry left-to-right,
	# rather than reusing the legacy whole-stage right-to-left action sequence.
	if module.definition.mirrored_horizontal and module.definition.entry_port.direction.x > 0:
		var platforms: Array[Rect2] = module.definition.platforms.duplicate()
		platforms.sort_custom(func(a: Rect2, b: Rect2): return a.position.x < b.position.x)
		for index: int in platforms.size() - 1:
			var takeoff := module.to_global(Vector2(platforms[index].end.x - 35, 0)).x
			var receiver := module.to_global(Vector2(platforms[index + 1].position.x + minf(80, platforms[index + 1].size.x * 0.5), 0)).x
			check.call(await move_to(takeoff), "local reflection reaches actual takeoff")
			check.call(await jump_to(receiver), "local reflection traverses reflected geometry with real Motor")
		check.call(await move_to(module.world_exit().x), "local reflection returns to grounded forward dock")
		return
	var pairs: Array[Vector2] = []
	match str(module.definition.module_id):
		"plains_micro_rise": pairs = [Vector2(100, 235)]
		"plains_meadow_gap": pairs = [Vector2(130, 335)]
		"plains_terraces": pairs = [Vector2(165, 350), Vector2(460, 650)]
		"plains_valley": pairs = [Vector2(165, 360), Vector2(460, 650)]
		"plains_long_meadow", "plains_split_terrace":
			check.call(await move_to(module.world_exit().x), "open meadow/optional terrace has continuous reachable main floor")
			return
		"plains_boss_arena":
			check.call(await move_to(module.world_exit().x), "fixed Boss core physically traverses a full-width floor")
			return
		_:
			await super.traverse(module)
			return
	for pair: Vector2 in pairs:
		check.call(await move_to(local_x(module, pair.x)), "new plains module reaches authored takeoff using real Motor")
		check.call(await jump_to(local_x(module, pair.y)), "new plains module held single jump lands on receiver")
	check.call(await move_to(module.world_exit().x), "new plains module reaches coincident docking floor")
