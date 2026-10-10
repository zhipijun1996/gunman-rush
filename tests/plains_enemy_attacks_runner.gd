extends SceneTree
var assertions := 0
var failures := 0
var world: Node2D
var player: PlayerMotor
var controller: PlayerController
var actor: EnemyActor
var behavior: EnemyAttackBehavior
var life: DemoLifetime
var policy: FrameDamagePolicy
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for index: int in count: await physics_frame
func fixture(id: String, dodge: bool = false) -> void:
	if is_instance_valid(world): world.free()
	world = Node2D.new()
	root.add_child(world)
	floor_rect(Rect2(0, 400, 900, 40))
	player = preload("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(455 if id == "charger" else 420 if id == "diver" else 480, 382)
	world.add_child(player)
	controller = player.get_node("Controller")
	life = DemoLifetime.new()
	policy = FrameDamagePolicy.new()
	policy.lifetime = life
	world.add_child(policy)
	policy.register_target(&"player", controller.actor_resources.health, true)
	var enemy := preload("res://scenes/enemies/patrol_drone.tscn").instantiate() as EnemyMotor
	enemy.position = Vector2(400, 308 if id == "diver" else 382)
	actor = enemy.get_node("Actor")
	actor.definition = PlainsEncounterPlanner.definition_for_behavior(id).duplicate(true)
	actor.definition.patrol_half_width = 85 if id == "charger" else 30 if id == "diver" else 0
	world.add_child(enemy)
	policy.bind_damageable(&"enemy", actor.damageable, actor.health)
	actor.bind_encounter(controller, policy, life, &"enemy", [])
	behavior = actor.attack_behavior
	behavior.cooldown = 0
	var contact := DemoContactEmitter.new()
	contact.controller = controller
	contact.policy = policy
	contact.source_id = &"enemy_contact"
	contact.half_size = actor.definition.collision_size / 2.0 + Vector2.ONE
	enemy.add_child(contact)
	await frames(2)
func floor_rect(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
func run() -> void:
	for id: String in ["charger", "diver", "sentry"]:
		await fixture(id)
		check(behavior.state == &"telegraph", id + " enters visible telegraph before attack")
		check(actor.health.current == 3 and controller.motor.tuning.projectile_damage == 1, "baseline enemies require three unmodified hits, not bonus HP")
		await frames(maxi(1, int(actor.definition.telegraph_duration * 60) - 5))
		check(controller.actor_resources.health.current == 5, id + " warning itself does not hurt player")
		await frames(38)
		check(controller.actor_resources.health.current < 5, id + " attack really reaches stationary player through formal damage")
		var hp := controller.actor_resources.health.current
		await frames(4)
		check(controller.actor_resources.health.current == hp, id + " contact/projectile does not bypass repeat-hit iframe")
		check(absf(actor.motor.global_position.x - behavior.home.x) <= actor.definition.patrol_half_width + 0.1, id + " attack remains inside recorded body leash")
		await fixture(id, true)
		controller.router.request_action(&"jump")
		controller.router.set_move_axis(1)
		await frames(40)
		controller.router.set_move_axis(0)
		await frames(35)
		check(controller.actor_resources.health.current == 5, id + " real one-jump Motor movement evades committed attack")
		await fixture(id)
		life.invalidate_actor()
		await frames(3)
		check(behavior.state == &"recovery" and behavior._serial == 0, id + " segment epoch cancels old windup without restarting health")
		check(actor.health.current == 3 and behavior.cooldown > 0, id + " cancellation preserves recovery debt")
	await fixture("sentry")
	await frames(43)
	check(behavior._serial == 1, "sentry releases a real projectile once after warning")
	var shots := behavior._projectiles.duplicate()
	life.invalidate_actor()
	await frames(2)
	check(shots.all(func(shot): return not is_instance_valid(shot) or shot.spent), "segment return disposes already emitted seeds")
	await fixture("sentry")
	floor_rect(Rect2(440, 300, 15, 100))
	await frames(3)
	behavior.locked_direction = Vector2.RIGHT
	behavior._fire()
	await frames(35)
	check(controller.actor_resources.health.current == 5, "real wall blocks real swept seed projectile")
	check(behavior._projectiles.all(func(shot): return not is_instance_valid(shot) or shot.spent), "wall consumes projectile rather than tunnelling")
	await fixture("sentry")
	behavior._fire()
	var dying_shots := behavior._projectiles.duplicate()
	actor.health.apply_damage(ActorResourceRequest.new(&"kill", actor.health.epoch, 3, actor.health.get_instance_id()))
	check(dying_shots.all(func(shot): return not is_instance_valid(shot) or shot.spent), "owner death immediately cancels emitted attack")
	await fixture("charger")
	var platform := world.get_child(0) as StaticBody2D
	platform.position.x = 210
	(platform.get_child(0) as CollisionShape2D).shape.size.x = 420
	await frames(2)
	var before := actor.motor.global_position
	check(not actor.motor.move_attack(Vector2(80, 0), true, 0.1) and actor.motor.global_position == before, "charger refuses unsupported landing rather than flying off a ledge")
	await fixture("diver")
	await frames(58)
	life.invalidate_actor()
	player.reset_at(Vector2(650, 382))
	floor_rect(Rect2(350, 329, 130, 10))
	await frames(200)
	check(behavior.state == &"blocked", "blocked return has finite recovery deadline and never teleports through terrain")
	await fixture("sentry")
	behavior._fire()
	life.end()
	await frames(2)
	check(behavior._projectiles.is_empty(), "leaving stage cancels local attack and old shots")
	if is_instance_valid(world): world.free()
	await app_pause()
	print("PLAINS ENEMY ATTACKS: %s assertions, %s failures" % [assertions, failures])
	quit(1 if failures else 0)

func app_pause() -> void:
	var app := preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(2)
	check(app.start_plains("enemy-pause-proof"), "real app starts behavior-enabled plains")
	await frames(6)
	var stage := app.stage as GeneratedDemoStage
	check(not stage.enemies.is_empty(), "pause proof has real generated enemies")
	var source := stage.enemies[0].get_node("Actor") as EnemyActor
	var attack := source.attack_behavior
	attack._set_state(&"telegraph")
	attack.locked_direction = Vector2.RIGHT
	attack._fire()
	var health_before := source.health.current
	var shots := attack._projectiles.duplicate()
	app._pause_for_menu()
	check(paused and attack.state == &"recovery" and attack.cooldown > 0, "real app menu pause cancels old telegraph and retains recovery debt")
	check(shots.all(func(shot): return not is_instance_valid(shot) or shot.spent), "real app pause disposes pending attack projectiles")
	check(source.health.current == health_before, "pause does not reset enemy health")
	app._resume_from_menu()
	await frames(3)
	check(attack.state == &"recovery" and attack._projectiles.is_empty(), "resume cannot replay frozen attack")
	app.abandon_run()
	await frames(3)
	app.free()
