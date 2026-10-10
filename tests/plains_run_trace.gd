extends "res://tests/random_stage_tests.gd"

func traverse(module: PlatformingModule) -> void:
	var pairs: Array[Vector2] = []
	match str(module.definition.module_id):
		"plains_micro_rise": pairs = [Vector2(100, 235)]
		"plains_meadow_gap": pairs = [Vector2(130, 335)]
		"plains_terraces": pairs = [Vector2(165, 350), Vector2(460, 650)]
		"plains_valley": pairs = [Vector2(165, 360), Vector2(460, 650)]
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
