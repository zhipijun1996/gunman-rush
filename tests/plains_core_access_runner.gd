extends "res://tests/windkeeper_runner.gd"
## Explicit shooting-position fixtures, not claims of full route traversal.
func run() -> void:
	for at: Vector2 in [Vector2(350, 582), Vector2(790, 582)]:
		await fixture(at)
		encounter.direction = -1 if at.x < boss.position.x else 1
		encounter._enter(&"neck", 3.8)
		await frames(2)
		check((encounter._core.get_child(0) as CollisionShape2D).shape.radius == 18, "core remains the real 18px weak point")
		print("CORE FIXTURE phase=%d spawn=%s player=%s core=%s" % [encounter.stage_phase, at, player.global_position, boss.global_position + encounter.core_offset()])
		await shoot_core()
	for at: Vector2 in [Vector2(350, 452), Vector2(870, 452)]:
		await fixture(at)
		encounter.health.apply_damage(ActorResourceRequest.new(&"phase_two_position_fixture", encounter.health.epoch, 4, encounter.health.get_instance_id()))
		await frames(100)
		encounter._enter(&"back", 3.8)
		await frames(2)
		print("CORE FIXTURE phase=%d spawn=%s player=%s core=%s" % [encounter.stage_phase, at, player.global_position, boss.global_position + encounter.core_offset()])
		await shoot_core()
	await fixture()
	encounter._enter(&"stomp_warning", 2)
	await frames(2)
	var before := encounter.health.current
	var armour_events: Array[Vector2] = []
	encounter.armour_hit.connect(func(point: Vector2) -> void: armour_events.append(point))
	check(controller.shoot_ability.try_fire(boss.global_position - player.global_position, player.is_on_floor()), "real closed-armour shot emits")
	await frames(25)
	check(encounter.health.current == before and armour_events.size() == 1, "armour blocks without HP loss and emits one explanation")
	world.free()
	await process_frame
	print("PLAINS CORE ACCESS: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
