extends RefCounted

const PLAYER := preload("res://scenes/player/player.tscn")
const DT := 1.0 / 60.0
var tree: SceneTree
var check: Callable
var world: Node2D
var motor: PlayerMotor
var controller: PlayerController
var shoot: ShootAbility
var resources: ActionResources

func fixture(location := Vector2(80, 150)) -> void:
	if is_instance_valid(world):
		world.free()
	world = Node2D.new()
	tree.root.add_child(world)
	body(Rect2(0, 200, 500, 40))
	motor = PLAYER.instantiate()
	motor.position = location
	world.add_child(motor)
	controller = motor.get_node("Controller")
	controller.set_physics_process(false)
	shoot = controller.shoot_ability
	resources = controller.action_resources
	await tree.physics_frame

func body(rect: Rect2, faction: StringName = &"") -> StaticBody2D:
	var obstacle := StaticBody2D.new()
	obstacle.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	obstacle.add_child(collision)
	if faction != &"":
		var receiver := Damageable.new()
		receiver.name = "Damageable"
		receiver.faction = faction
		obstacle.add_child(receiver)
	world.add_child(obstacle)
	return obstacle

func ticks(count: int) -> void:
	for index: int in count:
		await tree.physics_frame
		controller.physics_tick(DT)

func fire(direction: Vector2) -> void:
	controller.router.request_action(&"shoot_release", direction)
	await ticks(1)

func manual_bullet(direction := Vector2.RIGHT) -> PlayerProjectile:
	shoot.try_fire(direction, false)
	var bullet: PlayerProjectile = shoot.get_projectiles().back()
	bullet.set_physics_process(false)
	return bullet

func run(p_tree: SceneTree, p_check: Callable) -> void:
	tree = p_tree
	check = p_check
	for maximum: int in [0, 1, 2, 3, 5]:
		await fixture(Vector2(80, 20))
		resources.tuning.max_air_shots = maximum
		resources.reset()
		for index: int in maximum:
			shoot.cooldown_remaining = 0.0
			check.call(shoot.try_fire(Vector2.RIGHT, false), "configured %d shot accepts %d" % [maximum, index + 1])
		shoot.cooldown_remaining = 0.0
		check.call(not shoot.try_fire(Vector2.RIGHT, false) and resources.shot_charges == 0, "configured %d shots exhaust" % maximum)
		shoot.reset()
	await fixture()
	await ticks(30)
	await fire(Vector2.DOWN)
	check.call(not motor.is_on_floor() and resources.shot_charges == 1 and resources.pending_ground_shots == 0, "ground downward shot leaves floor and charges exactly once")
	var recoil_before := motor.recoil_velocity
	var remaining := resources.shot_charges
	check.call(not shoot.try_fire(Vector2.LEFT, false) and resources.shot_charges == remaining and motor.recoil_velocity == recoil_before and shoot.get_projectiles().size() == 1, "cooldown rejection has no resource, recoil or projectile effects")
	await ticks(1)
	check.call(is_equal_approx(motor.recoil_velocity.y, recoil_before.y * exp(-DT / motor.tuning.recoil_tau)), "recoil exponential decay survives gravity")
	await ticks(13)
	check.call(shoot.cooldown_remaining > 0.0, "cooldown remains before exact boundary")
	await ticks(1)
	check.call(is_zero_approx(shoot.cooldown_remaining), "cooldown expires at exact boundary without queued retry")
	resources.tuning.max_air_shots = 3
	resources.advance(false)
	check.call(resources.shot_charges == 1, "airborne increased cap gifts no charges")
	check.call(resources.grant_shot(9) == 1 and resources.shot_charges == 2, "grant respects current-flight cap")
	resources.tuning.max_air_shots = 1
	resources.advance(false)
	check.call(resources.shot_charges == 1, "airborne decrease clamps immediately")
	resources.reset()
	check.call(resources.shot_charges == 1, "landing adopts new cap")
	await fixture()
	await ticks(30)
	await fire(Vector2.UP)
	check.call(motor.is_on_floor() and resources.shot_charges == 2 and resources.pending_ground_shots == 0, "grounded blocked recoil preserves full resources")
	await fixture()
	await ticks(30)
	controller.router.request_action(&"shoot_release", Vector2.DOWN)
	controller.router.request_action(&"jump")
	await ticks(1)
	check.call(controller.jump_ability.used_jumps == 1 and resources.shot_charges == 1, "same-frame jump executes before shot regardless input order")
	shoot.enabled = false
	var velocity_before := motor.recoil_velocity
	check.call(not shoot.try_fire(Vector2.RIGHT, false) and velocity_before == motor.recoil_velocity, "shoot disable independent of jump")
	shoot.enabled = true
	controller.recoil_ability.enabled = false
	shoot.cooldown_remaining = 0.0
	check.call(shoot.try_fire(Vector2.RIGHT, false) and motor.recoil_velocity == Vector2.ZERO, "recoil disabled weapon still fires")
	await fixture(Vector2(80, 80))
	body(Rect2(105, 0, 1, 200))
	motor.apply_impulse(Vector2(2000, 0))
	await ticks(2)
	check.call(motor.position.x <= 93.1 and is_zero_approx(motor.recoil_velocity.x), "wall projects recoil independently and prevents recurrence")
	await fixture(Vector2(80, 80))
	body(Rect2(0, 40, 200, 1))
	motor.apply_impulse(Vector2(0, -2000))
	await ticks(2)
	check.call(motor.position.y >= 58.9 and is_zero_approx(motor.recoil_velocity.y), "ceiling projects upward recoil")
	await fixture(Vector2(80, 80))
	resources.shot_charges = 0
	var resolutions: Array[int] = []
	controller.queue_grant(1, controller.session_id, func(actual: int) -> void: resolutions.append(actual))
	check.call(resources.shot_charges == 0, "resource grants remain unavailable until next tick")
	await ticks(1)
	check.call(resources.shot_charges == 1 and resolutions == [1], "next-tick grant reports actual awarded amount")
	var cooldown_before := shoot.cooldown_remaining
	controller.queue_grant(10, controller.session_id, func(actual: int) -> void: resolutions.append(actual))
	await ticks(1)
	check.call(resources.shot_charges == 2 and resolutions == [1, 1] and shoot.cooldown_remaining == cooldown_before, "grant cap and cooldown remain independent")
	resources.shot_charges = 0
	shoot.cooldown_remaining = 0.2
	controller.queue_grant(1, controller.session_id, func(actual: int) -> void: resolutions.append(actual), func() -> bool: return false)
	await ticks(1)
	check.call(resources.shot_charges == 0 and resolutions.back() == 0 and is_equal_approx(shoot.cooldown_remaining, 0.2 - DT), "false source guard refuses grant without resetting cooldown")
	var discarded_source := Node.new()
	var invalid_guard := Callable(discarded_source, "is_inside_tree")
	discarded_source.free()
	controller.queue_grant(1, controller.session_id, func(actual: int) -> void: resolutions.append(actual), invalid_guard)
	await ticks(1)
	check.call(resources.shot_charges == 0 and resolutions.back() == 0 and is_equal_approx(shoot.cooldown_remaining, 0.2 - DT * 2), "freed source guard refuses grant without resetting cooldown")
	controller.queue_grant(1, controller.session_id - 1, func(actual: int) -> void: resolutions.append(actual))
	await ticks(1)
	check.call(resolutions.back() == 0, "old-session reward rejected")
	controller.queue_grant(1, controller.session_id, func(actual: int) -> void: resolutions.append(actual))
	controller.die()
	check.call(resolutions.back() == 0 and resources.shot_charges == 0 and resources.pending_ground_shots == 0, "death cancels ungranted rewards and clears ledger")
	controller.reset_at(Vector2(80, 80))
	controller.router.request_action(&"shoot_release", Vector2.RIGHT)
	shoot.enabled = false
	shoot.enabled = true
	await ticks(1)
	check.call(shoot.get_projectiles().is_empty(), "disable and reenable cannot execute old queued shot")
	check.call(not shoot.try_fire(Vector2(INF, 0), false) and not shoot.try_fire(Vector2.ZERO, false), "invalid directions refuse entire firing transaction")
	print("PASS GROUP: combat charges, transaction, recoil and collisions")

	for target_rect: Rect2 in [Rect2(90, 75, 1, 10), Rect2(90, 82, 1, 2), Rect2(78, 78, 4, 4)]:
		await fixture(Vector2(80, 80))
		var target := body(target_rect, &"target")
		await tree.physics_frame
		var bullet := manual_bullet()
		bullet.advance(DT)
		check.call((target.get_node("Damageable") as Damageable).health == 2.0 and bullet.spent, "volume sweep damages once: thin wall / radius graze / spawn overlap %s" % target_rect)
		bullet.advance(DT)
		check.call((target.get_node("Damageable") as Damageable).health == 2.0, "spent bullet never double damages")
	await fixture(Vector2(80, 80))
	body(Rect2(89, 75, 1, 10))
	var behind := body(Rect2(95, 75, 1, 10), &"target")
	await tree.physics_frame
	manual_bullet().advance(DT)
	check.call((behind.get_node("Damageable") as Damageable).health == 3.0, "nearest terrain blocks target behind wall")
	await fixture(Vector2(80, 80))
	var sensor := Area2D.new()
	sensor.position = Vector2(89, 80)
	var sensor_collision := CollisionShape2D.new()
	var sensor_shape := RectangleShape2D.new()
	sensor_shape.size = Vector2(1, 10)
	sensor_collision.shape = sensor_shape
	sensor.add_child(sensor_collision)
	world.add_child(sensor)
	var sensor_target := body(Rect2(95, 75, 1, 10), &"target")
	await tree.physics_frame
	manual_bullet().advance(DT)
	check.call((sensor_target.get_node("Damageable") as Damageable).health == 2.0, "non-damageable trigger Area does not block attack sweep")
	await fixture(Vector2(80, 80))
	var friendly := body(Rect2(89, 75, 1, 10), &"player")
	var enemy := body(Rect2(95, 75, 1, 10), &"target")
	await tree.physics_frame
	manual_bullet().advance(DT)
	check.call((friendly.get_node("Damageable") as Damageable).health == 3.0 and (enemy.get_node("Damageable") as Damageable).health == 2.0, "friendly collider ignored while enemy behind it damaged")
	await fixture(Vector2(80, 80))
	var owner_target := body(Rect2(89, 75, 1, 10), &"target")
	(owner_target.get_node("Damageable") as Damageable).actor_id = motor.get_instance_id()
	await tree.physics_frame
	var owner_bullet := manual_bullet()
	owner_bullet.advance(DT)
	check.call((owner_target.get_node("Damageable") as Damageable).health == 3.0 and not owner_bullet.spent, "owner ID filtered independently of faction")
	owner_bullet.lifetime = DT * 2
	owner_bullet.advance(DT)
	check.call(owner_bullet.spent, "lifetime invalidates bullet before later attacks")
	await fixture(Vector2(80, 80))
	var old_bullet := manual_bullet()
	var old_session := controller.session_id
	controller.die()
	check.call(old_bullet.spent and shoot.get_projectiles().is_empty() and controller.session_id > old_session and motor.recoil_velocity == Vector2.ZERO and shoot.cooldown_remaining == 0.0, "death cancels all projectiles, cooldown and recoil")
	controller.reset_at(Vector2(80, 80))
	check.call(resources.shot_charges == motor.tuning.max_air_shots, "respawn restores default resource budget")
	old_bullet = manual_bullet()
	controller.session_id += 1
	old_bullet.advance(DT)
	check.call(old_bullet.spent, "stale session cannot attack")
	var receiver := Damageable.new()
	world.add_child(receiver)
	var context := {"event_id": "duplicate", "amount": 1.0, "source_faction": &"player"}
	check.call(receiver.receive_damage(context) and not receiver.receive_damage(context) and receiver.health == 2.0, "Damageable rejects duplicate attack event")
	receiver.receive_damage({"event_id": "kill", "amount": 9.0, "source_faction": &"player"})
	check.call(not receiver.active and not receiver.receive_damage({"event_id": "after", "amount": 1.0}), "dead Damageable rejects later attacks")
	print("PASS GROUP: swept attack volume, blockers, ownership, lifetime and session")
	await fixture(Vector2(80, 80))
	world.process_mode = Node.PROCESS_MODE_ALWAYS
	motor.process_mode = Node.PROCESS_MODE_PAUSABLE
	var paused_bullet := manual_bullet()
	paused_bullet.set_physics_process(true)
	var paused_position := paused_bullet.global_position
	var paused_age := paused_bullet._age
	tree.paused = true
	for frame in range(3):
		await tree.physics_frame
	check.call(paused_bullet.global_position == paused_position and paused_bullet._age == paused_age, "actual SceneTree pause freezes projectile motion and lifetime under ALWAYS scene")
	tree.paused = false
	for frame in range(2):
		await tree.physics_frame
	check.call(paused_bullet.global_position.x > paused_position.x and paused_bullet._age > paused_age, "projectile resumes after unpause")
	world.free()
