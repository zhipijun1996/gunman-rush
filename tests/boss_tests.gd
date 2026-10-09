extends RefCounted

const BOSS := preload("res://scenes/bosses/clockwork_guardian.tscn")

func run(tree: SceneTree, check: Callable) -> void:
	var definition: BossDefinition = load("res://resources/bosses/clockwork_guardian.tres")
	check.call(definition.is_valid(), "boss fixture definition validates health, timings and collision extent")
	var broken: BossDefinition = definition.duplicate(true)
	broken.phase_two_threshold = INF
	check.call(not broken.is_valid(), "boss rejects invalid phase threshold")
	broken = definition.duplicate(true)
	broken.projectile_radius = -1.0
	check.call(not broken.is_valid(), "boss rejects nonpositive attack collision radius")
	var phases := BossPhaseController.new()
	phases.configure(definition)
	check.call(not phases.update(8.0, 8.0) and phases.phase == 1, "boss begins in first phase")
	check.call(phases.update(4.0, 8.0) and phases.phase == 2, "health threshold selects second phase")
	check.call(not phases.update(3.0, 8.0), "phase transition fires once")
	var pattern := BossAttackPattern.new()
	pattern.configure(definition, 1)
	check.call(not pattern.advance(definition.attack_interval) and pattern.telegraphing, "boss telegraph precedes damaging projectile")
	check.call(not pattern.advance(definition.telegraph_duration * 0.5), "warning window produces no early attack")
	check.call(pattern.advance(definition.telegraph_duration) and not pattern.telegraphing, "game clock warning completion emits one attack")
	pattern.advance(definition.attack_interval)
	pattern.cancel()
	check.call(not pattern.telegraphing and not pattern.advance(0.01), "phase cancellation removes old pending attack")
	var arena := BossArena.new()
	check.call(not arena.configure(10, 20, 10), "arena rejects space smaller than boss collision body")
	check.call(arena.configure(0, 800, 36) and arena.travel_limit(700, 1) == 64, "arena bounds account for complete boss body")

	var world := Node2D.new()
	tree.root.add_child(world)
	var target := CharacterBody2D.new()
	target.position = Vector2(80, 120)
	var target_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(24, 36)
	target_shape.shape = rectangle
	target.add_child(target_shape)
	world.add_child(target)
	var motor: BossMotor = BOSS.instantiate()
	motor.position = Vector2(400, 120)
	world.add_child(motor)
	var encounter: BossEncounter = motor.get_node("Encounter")
	encounter.set_physics_process(false)
	check.call(encounter.health.current == 8 and encounter.damageable.health == 8, "actual Boss scene has one bound health owner")
	check.call(encounter.configure_arena(200, 650, target) and encounter.activate(), "fixed arena and local target activate encounter")
	var projectiles: Array[BossProjectile] = []
	var hits: Array[StringName] = []
	encounter.projectile_created.connect(func(projectile: BossProjectile) -> void:
		projectile.hit.connect(func(_body: Node2D, id: StringName, _amount: float) -> void: hits.append(id))
		projectiles.append(projectile)
	)
	await tree.physics_frame
	encounter.physics_tick(definition.attack_interval)
	check.call(projectiles.is_empty() and encounter.pattern.telegraphing, "active encounter presents warning before firing")
	encounter.physics_tick(definition.telegraph_duration + 0.01)
	check.call(projectiles.size() == 1, "first phase emits one real damaging projectile")
	var projectile := projectiles[0]
	projectile.set_physics_process(false)
	await tree.physics_frame
	projectile.advance(2.0)
	check.call(hits.size() == 1 and projectile.spent, "swept enemy projectile has collision volume and hits configured player body")
	projectile.advance(1.0)
	check.call(hits.size() == 1, "spent attack cannot submit duplicate contact")
	encounter.health.apply_damage(ActorResourceRequest.new(&"phase-hit", encounter.health.epoch, 4.0, encounter.health.get_instance_id()))
	encounter.physics_tick(0.01)
	check.call(encounter.phases.phase == 2 and not encounter.pattern.telegraphing, "actual health transition cancels old phase pattern")
	encounter.physics_tick(definition.attack_interval)
	encounter.physics_tick(definition.telegraph_duration + 0.01)
	check.call(projectiles.size() == 4, "second phase generates a configurable three-shot fan")
	var defeated: Array[BossEncounter] = []
	encounter.defeated.connect(func(value: BossEncounter) -> void: defeated.append(value))
	encounter.health.apply_damage(ActorResourceRequest.new(&"lethal", encounter.health.epoch, 9.0, encounter.health.get_instance_id()))
	check.call(defeated.size() == 1 and not encounter.active and motor.collision_layer == 0, "Boss defeat records once and disables actor without awarding anything")
	var cancelled := true
	for index: int in range(1, projectiles.size()):
		cancelled = cancelled and projectiles[index].spent
	check.call(cancelled, "Boss defeat cancels owned pending projectiles")
	encounter.physics_tick(10.0)
	check.call(projectiles.size() == 4 and defeated.size() == 1, "dead encounter cannot attack or defeat again")
	# Real physics bodies, not a manual signal call: the projectile circle must
	# detect a grazing target, stop at terrain, and sweep a high-speed shot.
	var fast: BossDefinition = definition.duplicate(true)
	fast.projectile_speed = 10000.0
	var fast_hits: Array[StringName] = []
	var fast_bullet := BossProjectile.new()
	fast_bullet.configure(fast, &"fast-hit", Vector2.LEFT, target, motor)
	fast_bullet.set_physics_process(false)
	fast_bullet.hit.connect(func(_body: Node2D, id: StringName, _amount: float) -> void: fast_hits.append(id))
	world.add_child(fast_bullet)
	fast_bullet.set_physics_process(false)
	fast_bullet.global_position = Vector2(600, 120)
	await tree.physics_frame
	fast_bullet.advance(0.1)
	check.call(fast_hits.size() == 1 and fast_bullet.spent and fast_bullet.global_position.x > target.global_position.x, "high-speed swept enemy projectile cannot tunnel through player collision")
	fast_bullet.advance(0.1)
	check.call(fast_hits.size() == 1, "high-speed spent projectile cannot hit twice")
	var graze := BossProjectile.new()
	graze.configure(fast, &"volume-graze", Vector2.LEFT, target, motor)
	graze.set_physics_process(false)
	graze.hit.connect(func(_body: Node2D, id: StringName, _amount: float) -> void: fast_hits.append(id))
	world.add_child(graze)
	graze.set_physics_process(false)
	graze.global_position = Vector2(600, 144)
	await tree.physics_frame
	graze.advance(0.1)
	check.call(fast_hits.size() == 2 and graze.spent, "enemy projectile circle hits at its edge when center ray misses the target body")
	var wall := StaticBody2D.new()
	wall.position = Vector2(250, 120)
	var wall_shape := CollisionShape2D.new()
	var wall_rectangle := RectangleShape2D.new()
	wall_rectangle.size = Vector2(20, 100)
	wall_shape.shape = wall_rectangle
	wall.add_child(wall_shape)
	world.add_child(wall)
	var blocked := BossProjectile.new()
	blocked.configure(fast, &"wall-blocked", Vector2.LEFT, target, motor)
	blocked.set_physics_process(false)
	blocked.hit.connect(func(_body: Node2D, id: StringName, _amount: float) -> void: fast_hits.append(id))
	world.add_child(blocked)
	blocked.set_physics_process(false)
	blocked.global_position = Vector2(600, 120)
	await tree.physics_frame
	blocked.advance(0.1)
	check.call(blocked.spent and blocked.global_position.x >= 266.0 and fast_hits.size() == 2, "real terrain blocks a high-speed enemy projectile before player and submits no player hit")
	world.free()
	print("PASS GROUP: Boss definition/arena/phase/telegraph/swept projectile/defeat ownership")
