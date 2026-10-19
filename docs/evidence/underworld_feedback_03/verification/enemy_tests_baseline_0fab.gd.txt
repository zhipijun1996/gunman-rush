extends RefCounted

const ENEMY := preload("res://scenes/enemies/patrol_drone.tscn")
const DT := 1.0 / 60.0

func spawn(world: Node, location: Vector2) -> EnemyActor:
	var motor: EnemyMotor = ENEMY.instantiate()
	motor.position = location
	world.add_child(motor)
	var actor: EnemyActor = motor.get_node("Actor")
	actor.set_physics_process(false)
	return actor

func hit(actor: EnemyActor, id: String, amount := 1.0, faction: StringName = &"player") -> Dictionary:
	return {"event_id": id, "amount": amount, "source_faction": faction, "source_actor_id": 999, "target_actor_id": actor.damageable.actor_id, "target_epoch": actor.damageable.damage_epoch}

func run(tree: SceneTree, check: Callable) -> void:
	var fixture := preload("res://tests/combat_tests.gd").new()
	fixture.tree = tree
	await fixture.fixture(Vector2(80, 100))
	var actor := spawn(fixture.world, Vector2(250, 100))
	var other := spawn(fixture.world, Vector2(250, 50))
	check.call(actor.health.current == 3.0 and actor.damageable.health == actor.health.current, "enemy scene binds a single HealthState owner")
	check.call(actor.health != other.health and actor.brain != other.brain and actor.motor != other.motor, "separate enemy instances share no runtime state")
	check.call(actor.damageable.actor_id != other.damageable.actor_id and actor.damageable.faction == &"enemy", "each enemy has its own identity and explicit faction")
	var origin := actor.motor.global_position
	var stayed_bounded := true
	var reversed := false
	for index: int in 160:
		await tree.physics_frame
		actor.physics_tick(DT)
		stayed_bounded = stayed_bounded and absf(actor.motor.global_position.x - origin.x) <= 100.01
		reversed = reversed or actor.brain.direction < 0
	check.call(stayed_bounded and reversed and actor.motor.global_position != origin, "real patrol moves and turns within configured bounds")
	check.call(actor.motor.global_position.y == origin.y, "hovering fixture keeps its configured height")
	actor.brain.enabled = false
	var disabled_position := actor.motor.global_position
	actor.physics_tick(DT)
	check.call(actor.motor.global_position == disabled_position and actor.motor.velocity == Vector2.ZERO, "disabled AI emits idle intent without movement")
	actor.brain.enabled = true
	actor.physics_tick(DT)
	check.call(actor.motor.global_position != disabled_position, "AI re-enable accepts fresh patrol intent")
	actor.reset()
	check.call(actor.motor.global_position == origin and actor.brain.direction == 1, "explicit historical/new-stage restart resets patrol anchor and phase")
	var definition: EnemyDefinition = actor.definition.duplicate(true)
	definition.patrol_speed = 30.0
	definition.patrol_half_width = 0.0
	definition.initial_direction = -1
	check.call(definition.is_valid(), "stationary and alternate-direction enemy policy is configurable")
	actor.definition = definition
	actor.reset()
	actor.physics_tick(DT)
	check.call(actor.motor.global_position == origin, "zero patrol range is stationary without boundary flicker")
	definition.patrol_half_width = 100.0
	actor.reset()
	actor.physics_tick(DT)
	check.call(is_equal_approx(actor.motor.global_position.x, origin.x - 0.5), "configured speed and starting direction reach the actual motor")
	definition.patrol_speed = NAN
	check.call(not definition.is_valid(), "nonfinite enemy speed rejected")
	definition.patrol_speed = 90.0
	definition.collision_size = Vector2(-1, 32)
	check.call(not definition.is_valid(), "invalid hurtbox size rejected")
	definition.collision_size = Vector2(28, 32)
	definition.initial_direction = 0
	check.call(not definition.is_valid(), "invalid initial patrol direction rejected")
	definition.initial_direction = 1
	actor.reset()
	fixture.body(Rect2(285, 60, 10, 80))
	await tree.physics_frame
	actor.physics_tick(1.0)
	check.call(actor.motor.global_position.x < 272.0 and actor.brain.direction == -1, "swept motor collision blocks a large-step wall and turns AI")
	var wall_position := actor.motor.global_position
	actor.physics_tick(DT)
	check.call(actor.motor.global_position.x < wall_position.x, "wall collision recovery moves away rather than sticking")
	var stable := actor.motor.global_position
	actor.physics_tick(INF)
	actor.physics_tick(-1.0)
	check.call(actor.motor.global_position == stable, "invalid simulation delta cannot move an enemy")
	fixture.world.free()

	await fixture.fixture(Vector2(80, 100))
	actor = spawn(fixture.world, Vector2(250, 100))
	other = spawn(fixture.world, Vector2(250, 50))
	var notifications: Array[ActorResourceResult] = []
	var defeats: Array[EnemyActor] = []
	actor.health.changed.connect(func(result: ActorResourceResult) -> void: notifications.append(result))
	actor.defeated.connect(func(enemy: EnemyActor) -> void: defeats.append(enemy))
	await tree.physics_frame
	var bullet := fixture.manual_bullet(Vector2.RIGHT)
	bullet.advance(0.3)
	check.call(bullet.spent and actor.health.current == 2.0 and actor.damageable.health == 2.0, "existing swept attack projectile damages actual moving-enemy hurtbox")
	check.call(notifications.size() == 1 and other.health.current == 3.0, "projectile commits typed health result once without changing another enemy")
	bullet.advance(0.3)
	check.call(actor.health.current == 2.0, "spent projectile cannot deal repeated damage")
	var friendly := hit(actor, "friendly", 1.0, &"enemy")
	check.call(not actor.damageable.receive_damage(friendly) and actor.health.current == 2.0, "friendly damage rejected")
	var self_hit := hit(actor, "self")
	self_hit.source_actor_id = actor.damageable.actor_id
	check.call(not actor.damageable.receive_damage(self_hit), "self damage rejected")
	var wrong_actor := hit(actor, "wrong-actor")
	wrong_actor.target_actor_id = other.damageable.actor_id
	check.call(not actor.damageable.receive_damage(wrong_actor), "wrong target identity rejected")
	var wrong_epoch := hit(actor, "wrong-epoch")
	wrong_epoch.target_epoch -= 1
	check.call(not actor.damageable.receive_damage(wrong_epoch), "old enemy lifetime damage rejected")
	check.call(not actor.damageable.receive_damage({"event_id": "missing-token", "amount": 1.0, "source_faction": &"player"}), "new health-bound actor rejects incomplete legacy target token")
	for amount: float in [0.0, -1.0, NAN, INF]:
		check.call(not actor.damageable.receive_damage(hit(actor, "invalid-%s" % amount, amount)) and actor.health.current == 2.0, "invalid enemy damage rejected: %s" % amount)
	var valid := hit(actor, "one-hit")
	check.call(actor.damageable.receive_damage(valid) and actor.health.current == 1.0, "valid targeted attack accepted")
	check.call(not actor.damageable.receive_damage(valid) and actor.health.current == 1.0, "duplicate target attack cannot decrement twice")
	var old_lifetime_hit := hit(actor, "delayed-before-restart")
	check.call(actor.damageable.receive_damage(hit(actor, "lethal", 9.0)) and actor.health.terminal and defeats.size() == 1, "enemy defeat emitted exactly once on lethal damage")
	check.call(not actor.damageable.active and actor.motor.collision_layer == 0 and actor.motor.velocity == Vector2.ZERO and not actor.is_physics_processing(), "defeated enemy disables AI motion and hurtbox collision")
	var dead_position := actor.motor.global_position
	actor.physics_tick(DT)
	check.call(actor.motor.global_position == dead_position and not actor.damageable.receive_damage(hit(actor, "after-death")) and defeats.size() == 1, "dead actor cannot move or emit repeated defeat")
	actor.reset()
	actor.set_physics_process(false)
	check.call(actor.health.current == 3.0 and actor.damageable.active and actor.motor.collision_layer == 4, "explicit restart restores independent actor and collision")
	check.call(not actor.damageable.receive_damage(old_lifetime_hit) and actor.health.current == 3.0, "restart invalidates deferred damage for previous epoch")
	actor.damageable.reset()
	check.call(actor.damageable.health == actor.health.current, "legacy receiver reset cannot create a second health owner")
	check.call(actor.damageable.receive_damage(hit(actor, "fresh-after-restart")) and actor.health.current == 2.0, "new-lifetime attack accepted after old callback rejected")
	fixture.world.process_mode = Node.PROCESS_MODE_ALWAYS
	actor.set_physics_process(true)
	await tree.physics_frame
	var before_pause := actor.motor.global_position
	tree.paused = true
	for index: int in 3:
		await tree.physics_frame
	check.call(actor.motor.global_position == before_pause, "actual SceneTree pause stops AI even under ALWAYS graybox")
	tree.paused = false
	for index: int in 3:
		await tree.physics_frame
	check.call(actor.motor.global_position != before_pause, "unpause resumes enemy simulation")
	actor.reset()
	await tree.physics_frame
	var before_normal := actor.motor.global_position.x
	for index: int in 12:
		await tree.physics_frame
	var normal_distance := actor.motor.global_position.x - before_normal
	actor.reset()
	Engine.time_scale = 0.25
	await tree.physics_frame
	var before_slow := actor.motor.global_position.x
	for index: int in 12:
		await tree.physics_frame
	var slow_distance := actor.motor.global_position.x - before_slow
	Engine.time_scale = 1.0
	check.call(normal_distance > 0.0 and absf(slow_distance / normal_distance - 0.25) < 0.02, "enemy motion follows the shared slow-time game clock")
	fixture.world.free()
	check.call(Engine.time_scale == 1.0, "enemy fixture teardown leaves no global time effect")
	print("PASS GROUP: independent enemy AI/motor/health, real collisions and swept projectile defeat")
