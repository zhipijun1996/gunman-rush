extends RefCounted

func request(state: ActorResourceState, id: StringName, amount: float) -> ActorResourceRequest:
	return ActorResourceRequest.new(id, state.epoch, amount, state.get_instance_id())

func health_definition(maximum := 5.0, initial := 5.0) -> HealthDefinition:
	var result := HealthDefinition.new()
	result.resource_id = &"resource_test_health"
	result.max_health = maximum
	result.initial_current = initial
	return result

func run(tree: SceneTree, check: Callable) -> void:
	var health := HealthState.new()
	var definition := health_definition()
	check.call(health.configure(definition), "valid health definition creates independent state")
	var other := HealthState.new()
	other.configure(definition)
	var notifications: Array[ActorResourceResult] = []
	health.changed.connect(func(result: ActorResourceResult) -> void: notifications.append(result))
	var hit := request(health, &"hit-1", 2.0)
	var result := health.apply_damage(hit)
	check.call(result.accepted() and result.amount_applied == -2.0 and health.current == 3.0 and other.current == 5.0, "shared definition does not share health state")
	check.call(notifications.size() == 1 and notifications[0].snapshot.current == 3.0, "health emits a typed post-commit snapshot")
	result.snapshot.current = 999.0
	notifications[0].snapshot.capacity = 999.0
	var retry := health.apply_damage(hit)
	check.call(retry.status == ActorResourceResult.Status.REPLAY and retry.snapshot.current == 3.0 and retry.snapshot.capacity == 5.0 and notifications.size() == 1, "retry is read-only; mutated UI/results cannot corrupt receipt")
	check.call(health.apply_damage(request(health, &"hit-1", 1.0)).status == ActorResourceResult.Status.CONFLICT and health.current == 3.0, "same event with different amount is rejected")
	check.call(health.heal(hit).status == ActorResourceResult.Status.CONFLICT and health.current == 3.0, "event cannot be reused for another operation")
	check.call(other.apply_damage(hit).status == ActorResourceResult.Status.STALE and other.current == 5.0, "matching epochs cannot apply another actor's request")
	health.heal(request(health, &"heal", 1.0))
	check.call(health.current == 4.0 and health.capacity == 5.0, "healing changes current health only")
	health.set_max(request(health, &"max-up", 8.0))
	check.call(health.current == 4.0 and health.capacity == 8.0, "increasing maximum health does not silently heal")
	health.set_max(request(health, &"max-down", 2.0))
	check.call(health.current == 2.0 and health.capacity == 2.0, "decreasing maximum health clamps current health")
	definition.max_health = 20.0
	definition.initial_current = 20.0
	check.call(health.capacity == 2.0 and other.capacity == 5.0, "definition editing does not mutate live instances")
	var detached := health.snapshot()
	detached.current = -100.0
	check.call(health.current == 2.0, "snapshot mutations cannot alter resource state")
	for amount: float in [-1.0, 0.0, NAN, INF]:
		check.call(health.apply_damage(request(health, StringName("bad-%s" % amount), amount)).status == ActorResourceResult.Status.INVALID and health.current == 2.0, "invalid damage rejected without side effects: %s" % amount)
	check.call(not health.configure(health_definition(-1.0, 0.0)) and health.current == 2.0, "invalid health configuration preserves state")
	check.call(not health.configure(health_definition(5.0, 6.0)), "initial health above maximum is rejected")
	health.apply_damage(request(health, &"lethal", 50.0))
	check.call(health.current == 0.0 and health.terminal, "overkill clamps to zero and marks terminal health")
	check.call(health.heal(request(health, &"revive", 2.0)).status == ActorResourceResult.Status.TERMINAL and health.current == 0.0, "healing cannot revive terminal health")
	check.call(health.set_max(request(health, &"revive-max", 10.0)).status == ActorResourceResult.Status.TERMINAL, "maximum changes cannot revive terminal health")
	var old_request := request(health, &"delayed", 1.0)
	health.configure(health_definition())
	check.call(health.apply_damage(old_request).status == ActorResourceResult.Status.STALE and health.current == 5.0, "new lifetime rejects old delayed resource requests")

	var tuning := PlayerTuning.load_default()
	var stamina := StaminaState.new()
	var stamina_definition := StaminaDefinition.from_focus_prototype(tuning)
	stamina.configure(stamina_definition)
	var independent := StaminaState.new()
	independent.configure(stamina_definition)
	check.call(stamina.capacity == tuning.focus_stamina_capacity and stamina_definition.clock_domain == StaminaDefinition.ClockDomain.REAL, "prototype adapter uses sole tuning source and explicit real-time clock")
	stamina.try_consume(request(stamina, &"spend", 40.0))
	check.call(stamina.current == 60.0 and independent.current == 100.0 and health.current == 5.0, "stamina consumption is independent of health and other actors")
	check.call(stamina.try_consume(request(stamina, &"too-much", 61.0)).status == ActorResourceResult.Status.INSUFFICIENT and stamina.current == 60.0, "insufficient stamina refuses atomically")
	stamina.grant(request(stamina, &"refill", 1000.0))
	check.call(stamina.current == 100.0 and stamina.capacity == 100.0, "stamina grants clamp to capacity")
	stamina.try_consume(request(stamina, &"all", 100.0))
	check.call(stamina.current == 0.0 and not stamina.terminal, "empty stamina is not death")
	stamina.grant(request(stamina, &"recover", 5.0))
	check.call(stamina.current == 5.0, "empty stamina can recover explicitly")
	var stale_epoch := stamina.epoch
	stamina.configure(stamina_definition)
	check.call(stamina.grant_continuous(1.0, stale_epoch).status == ActorResourceResult.Status.STALE, "continuous pulses reject old resource epoch")
	stamina.consume_continuous(10.0, stamina.epoch)
	check.call(stamina.current == 90.0, "explicit synchronous focus pulse uses the same state API")
	check.call(stamina.consume_continuous(100.0, stamina.epoch).status == ActorResourceResult.Status.INSUFFICIENT and stamina.current == 90.0, "continuous consume also refuses overspend")
	for amount: float in [-1.0, NAN, INF]:
		check.call(stamina.grant(request(stamina, StringName("invalid-%s" % amount), amount)).status == ActorResourceResult.Status.INVALID and stamina.current == 90.0, "invalid stamina grants rejected: %s" % amount)
	var invalid_stamina := StaminaDefinition.new()
	check.call(not stamina.configure(invalid_stamina) and stamina.current == 90.0, "invalid stamina definition preserves existing state")

	var fixture := preload("res://tests/combat_tests.gd").new()
	fixture.tree = tree
	await fixture.fixture()
	await fixture.ticks(30) # Grounded default one-jump actor, not an implicit airborne second jump.
	var controller: PlayerController = fixture.controller
	var resources := controller.actor_resources
	var focus := controller.air_focus_ability
	check.call(focus.stamina_state == resources.stamina and resources.health.current == 5.0, "player scene composes health and shared prototype stamina")
	var hud := ActorResourcesHud.new()
	fixture.world.add_child(hud)
	hud.bind(resources, focus)
	resources.health.apply_damage(request(resources.health, &"hud-damage", 1.0))
	check.call(hud.health_bar.value == 4.0 and hud.health_label.text == "HP 4/5", "HUD observes health changes without applying gameplay")
	focus.advance(0.5, false, true)
	check.call(resources.stamina.current == 77.5 and hud.stamina_bar.value == 77.5, "focus and HUD share one stamina value")
	focus.stop()
	resources.stamina.try_consume(request(resources.stamina, &"empty-fixture", resources.stamina.current))
	var before_hp := resources.health.current
	controller.router.set_move_axis(1.0)
	controller.router.request_action(&"jump")
	await fixture.ticks(1)
	check.call(controller.jump_ability.used_jumps > 0 and controller.motor.normal_velocity.y < 0.0 and resources.stamina.current == 0.0, "zero stamina does not block movement or jumping")
	controller.router.request_action(&"shoot_release", Vector2.DOWN)
	await fixture.ticks(1)
	var actions := controller.action_resource_view.snapshot()
	check.call(controller.shoot_ability.get_projectiles().size() == 1 and controller.motor.recoil_burst_remaining > 0.0 and actions.shots_remaining == 1, "zero stamina still permits release-shot projectile and recoil with action charge")
	check.call(resources.stamina.current == 0.0 and resources.health.current == before_hp, "normal action chain adds no stamina or health cost")
	actions.shots_remaining = 999
	check.call(controller.action_resources.shot_charges == 1, "action snapshot cannot mutate existing counter owners")
	controller.queue_grant(1)
	await fixture.ticks(1)
	check.call(controller.action_resources.shot_charges == 2 and resources.stamina.current == 0.0, "shot recharge cannot refill stamina")
	resources.stamina.grant(request(resources.stamina, &"stamina-only", 5.0))
	check.call(controller.action_resources.shot_charges == 2 and controller.jump_ability.used_jumps > 0 and resources.stamina.current == 5.0, "stamina grant cannot refill jumps or shot counters")
	var old_hp := request(resources.health, &"stale-after-retry", 1.0)
	controller.reset_at(Vector2(80, 150))
	check.call(resources.health.current == 5.0 and resources.stamina.current == 100.0 and hud.health_bar.value == 5.0, "explicit historical restart resets independent state and notifies HUD")
	check.call(resources.health.apply_damage(old_hp).status == ActorResourceResult.Status.STALE, "historical restart invalidates old health requests")
	hud.unbind()
	resources.health.apply_damage(request(resources.health, &"unbound", 1.0))
	check.call(hud.health_bar.value == 5.0, "HUD teardown disconnects local resource observers")
	fixture.world.free()
	check.call(Engine.time_scale == 1.0, "new module teardown cannot leak focus time scaling")
	print("PASS GROUP: modular health/stamina, typed receipts, independent state and real action chain")
