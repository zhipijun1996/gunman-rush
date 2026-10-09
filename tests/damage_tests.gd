extends RefCounted

func _health(maximum := 5.0) -> HealthState:
	var definition := HealthDefinition.new()
	definition.resource_id = &"damage_test"
	definition.max_health = maximum
	definition.initial_current = maximum
	var health := HealthState.new()
	health.configure(definition)
	return health

func _request(life: DemoLifetime, health: HealthState, id: StringName, kind: DamageRequest.Kind, amount: float, target := &"player") -> DamageRequest:
	var request := DamageRequest.new()
	request.token = life.token()
	request.actor_epoch = life.actor_epoch
	request.health_epoch = health.epoch
	request.target_id = target
	request.event_id = id
	request.source_id = id
	request.kind = kind
	request.amount = amount
	return request

func run(tree: SceneTree, check: Callable) -> void:
	for reversed: bool in [false, true]:
		var policy := FrameDamagePolicy.new()
		policy.lifetime = DemoLifetime.new()
		var health := _health()
		policy.register_target(&"player", health, true)
		var monster := _request(policy.lifetime, health, &"monster", DamageRequest.Kind.MONSTER, 3.0)
		var hazard := _request(policy.lifetime, health, &"hazard", DamageRequest.Kind.ENVIRONMENT, 1.0)
		policy.submit(hazard if reversed else monster)
		policy.submit(monster if reversed else hazard)
		var batch := policy.resolve_batch()
		check.call(batch.size() == 1 and batch[0].request.kind == DamageRequest.Kind.ENVIRONMENT and health.current == 4.0, "environment priority independent of callback order")
		check.call(not policy.submit(hazard), "same exposure damage cannot replay")
		policy.free()
	var policy := FrameDamagePolicy.new()
	policy.lifetime = DemoLifetime.new()
	var health := _health()
	policy.register_target(&"player", health, true)
	policy.submit(_request(policy.lifetime, health, &"first", DamageRequest.Kind.MONSTER, 1))
	policy.resolve_batch()
	check.call(not policy.submit(_request(policy.lifetime, health, &"second", DamageRequest.Kind.MONSTER, 1)), "monster iframe rejects new monster attack")
	check.call(policy.submit(_request(policy.lifetime, health, &"spikes", DamageRequest.Kind.ENVIRONMENT, 1)), "monster iframe does not shield environment")
	policy.resolve_batch()
	policy.protect_player()
	check.call(not policy.submit(_request(policy.lifetime, health, &"protected", DamageRequest.Kind.ENVIRONMENT, 1)), "return protection separately shields hazards")
	policy.clock += policy.spawn_protection + 0.01
	check.call(policy.submit(_request(policy.lifetime, health, &"newcontact", DamageRequest.Kind.ENVIRONMENT, 1)), "spawn protection expires on game clock")
	policy.resolve_batch()
	var stale := _request(policy.lifetime, health, &"stale", DamageRequest.Kind.MONSTER, 1)
	policy.lifetime.invalidate_actor()
	check.call(not policy.submit(stale), "old actor contact cannot damage after return")
	check.call(not policy.submit(_request(policy.lifetime, health, &"bad", DamageRequest.Kind.MONSTER, NAN)), "invalid damage fails closed")
	policy.free()
	for reversed: bool in [false, true]:
		policy = FrameDamagePolicy.new()
		policy.lifetime = DemoLifetime.new()
		health = _health(1)
		var boss := _health(1)
		policy.register_target(&"player", health, true)
		policy.register_target(&"boss", boss)
		var player_hit := _request(policy.lifetime, health, &"fatal", DamageRequest.Kind.ENVIRONMENT, 1)
		var boss_hit := _request(policy.lifetime, boss, &"boss_fatal", DamageRequest.Kind.MONSTER, 1, &"boss")
		var outcomes := [0, 0]
		policy.player_fatal.connect(func() -> void: outcomes[0] += 1)
		policy.environment_return_requested.connect(func() -> void: outcomes[1] += 1)
		policy.submit(player_hit if reversed else boss_hit)
		policy.submit(boss_hit if reversed else player_hit)
		policy.resolve_batch()
		check.call(health.terminal and boss.terminal and not policy.lifetime.active and outcomes == [1, 0], "all HP commits then simultaneous deaths fail run, never environment return")
		policy.resolve_batch()
		check.call(outcomes == [1, 0], "fatal signal settles once")
		policy.free()
	var world := Node2D.new()
	tree.root.add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(250, 620)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(500, 40)
	collision.shape = shape
	floor_body.add_child(collision)
	world.add_child(floor_body)
	var motor: PlayerMotor = preload("res://scenes/player/player.tscn").instantiate()
	motor.position = Vector2(100, 580)
	world.add_child(motor)
	var controller := motor.get_node("Controller") as PlayerController
	controller.set_physics_process(false)
	await tree.physics_frame
	await tree.physics_frame
	var life := DemoLifetime.new()
	var segment := SegmentRespawn.new()
	segment.configure(controller, life)
	segment.add_anchor(&"entry", Vector2(100, 580))
	segment.add_anchor(&"middle", Vector2(300, 580))
	segment.add_anchor(&"pit", Vector2(700, 580))
	check.call(segment.activate_anchor(&"entry") and segment.activate_anchor(&"middle"), "full volume and three floor rays validate segment anchors")
	check.call(not segment.activate_anchor(&"pit"), "anchor over pit rejected")
	controller.actor_resources.health.apply_damage(ActorResourceRequest.new(&"hurt", controller.actor_resources.health.epoch, 1, controller.actor_resources.health.get_instance_id()))
	controller.actor_resources.stamina.consume_continuous(25, controller.actor_resources.stamina.epoch)
	var stamina := controller.actor_resources.stamina.current
	controller.shoot_ability.cooldown_remaining = 0.23
	controller.action_resources.shot_charges = 0
	controller.jump_ability.used_jumps = 2
	motor.apply_impulse(Vector2(900, -400))
	controller.router.request_action(&"shoot_release", Vector2.DOWN)
	controller.router.request_action(&"jump")
	var old_epoch := life.actor_epoch
	check.call(segment.return_to_anchor(), "surviving player returns to current challenge segment")
	check.call(motor.global_position == Vector2(300, 580) and motor.velocity == Vector2.ZERO and motor.recoil_velocity == Vector2.ZERO, "return uses Motor and clears all movement")
	check.call(controller.actor_resources.health.current == 4 and controller.actor_resources.stamina.current == stamina and is_equal_approx(controller.shoot_ability.cooldown_remaining, 0.23), "return preserves HP, spent stamina, shot cooldown")
	check.call(controller.action_resources.shot_charges == controller.motor.tuning.max_air_shots and controller.jump_ability.used_jumps == 0, "return restores configured action resources")
	check.call(life.actor_epoch == old_epoch + 1 and life.epoch == 1 and life.stage_epoch == 1 and controller.router.consume_actions(1).is_empty(), "only actor epoch changes; pending actions canceled")
	segment.danger_bounds = [Rect2(280, 540, 60, 60)]
	check.call(segment.return_to_anchor() and motor.global_position == Vector2(100, 580), "unsafe newest anchor falls back to previous validated anchor")
	check.call(DemoContactEmitter.segment_intersects_bounds(Vector2(-100, 0), Vector2(100, 0), Rect2(-10, -10, 20, 20)), "swept contact catches fast crossing")
	check.call(not DemoContactEmitter.segment_intersects_bounds(Vector2(-100, 30), Vector2(100, 30), Rect2(-10, -10, 20, 20)), "swept contact rejects separated path")
	world.free()
	print("PASS GROUP: frame damage ordering, selective safe segment return and lifetime")
