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
	if not module.definition.main_route.is_empty():
		await spatial_path(module, module.definition.main_route)
		return
	var pairs: Array[Vector2] = []
	match str(module.definition.module_id):
		"plains_micro_rise": pairs = [Vector2(100, 235)]
		"plains_meadow_gap": pairs = [Vector2(130, 335)]
		"plains_terraces": pairs = [Vector2(165, 350), Vector2(460, 650)]
		"plains_valley": pairs = [Vector2(165, 360), Vector2(460, 650)]
		"plains_micro_stool", "plains_micro_landing", "plains_long_meadow", "plains_split_terrace":
			check.call(await move_to(module.world_exit().x), "open meadow/optional terrace has continuous reachable main floor")
			return
		"plains_thorn_hop", "plains_gear_hop":
			check.call(await move_to(module.position.x + 25), "compact danger module reaches an actual clear takeoff")
			check.call(await jump_to(module.position.x + 140), "compact danger module uses a real jump over thorn or moving gear")
			check.call(await move_to(module.world_exit().x), "compact danger module reaches its clear grounded dock")
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

func spatial_path(module: PlatformingModule, path: Variant) -> void:
	for step: int in range(1, path.size()):
		var previous := module.definition.anchors[path[step - 1]]
		var target := module.definition.anchors[path[step]]
		if absf(previous.y - target.y) < 0.1:
			check.call(await move_to(module.position.x + target.x), "spatial path walks a real continuous grounded segment")
		else:
			var direction := signf(target.x - previous.x)
			var takeoff := previous.x
			for platform: Rect2 in module.definition.platforms:
				if absf(platform.position.y - previous.y - 18.0) < 0.1 and platform.has_point(previous + Vector2(0, 19)):
					takeoff = platform.end.x - 40.0 if direction > 0 else platform.position.x + 40.0
					if platform.size.x > 400.0:
						takeoff = previous.x + direction * 20.0
					break
			check.call(await move_to(module.position.x + takeoff), "spatial jump reaches a safe directional takeoff")
			var landed := await jump_to(module.position.x + target.x)
			check.call(landed, "spatial path jumps with real Motor and held-release input")
			if not landed or absf(motor.global_position.y - module.position.y - target.y) >= 1.0:
				print("SPATIAL TRACE FAILED step=%d from=%s takeoff=%s target=%s actual=%s" % [step, previous, takeoff, target, motor.global_position - module.position])
				check.call(false, "spatial jump must land on authored receiver before continuing")
				return
			check.call(absf(motor.global_position.y - module.position.y - target.y) < 1.0, "spatial jump lands on the authored height, not a lower floor")
