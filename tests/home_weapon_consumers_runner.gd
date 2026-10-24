extends "res://tests/actor_actions_runner.gd"
## Real physics receivers and the original gate/rune policies. No route-completion claim.
var scope: DemoLifetime
var latch: ShotLatch
var accepted: Array[int] = []
var observed: Array[Dictionary] = []

func fixture(at: Vector2 = Vector2(100, 682)) -> void:
	if is_instance_valid(world):
		if is_instance_valid(latch): latch.cancel()
		if scope != null: scope.end()
		check(await load("res://tests/audio_teardown.gd").drain_world(world), "Fixture audio releases")
		world.free()
		await process_frame
	world = Node2D.new()
	root.add_child(world)
	body(Rect2(-500, 700, 2000, 100))
	motor = preload("res://scenes/player/player.tscn").instantiate()
	motor.position = at
	world.add_child(motor)
	controller = motor.get_node("Controller")
	controller.set_physics_process(false)
	controller.enable_shot_energy() # Current D084 policy, not the parent's legacy fixture.
	controller.air_focus_ability.enabled = false
	scope = DemoLifetime.new()
	accepted.clear()
	observed.clear()
	controller.shoot_ability.shot_fired.connect(func(_axis: Vector2, id: int) -> void: accepted.append(id))
	await tick(3)

func add_latch(bell := Vector2(200, 682), backside := false) -> void:
	latch = BacksideShotLatch.new() if backside else ShotLatch.new()
	world.add_child(latch)
	latch.setup(controller, scope, bell, Rect2(330, 500, 20, 200))
	var sink := latch.receiver.damage_sink
	latch.receiver.damage_sink = func(context: Dictionary) -> bool:
		var record := context.duplicate()
		record.erase("on_committed")
		observed.append(record)
		return sink.call(context)
	await tick(2)

func fire(id: StringName, axis := Vector2.RIGHT) -> void:
	check(controller.shoot_ability.equip(load("res://resources/weapons/%s.tres" % id)), "Equip actual base Definition " + str(id))
	controller.router.request_action(&"shoot_release", axis)
	await tick(24)

func context(id: String, shot: int) -> Dictionary:
	return {"event_id":id,"amount":1.0,"session_id":controller.session_id,"shot_id":shot,"source_actor_id":motor.get_instance_id(),"source_faction":&"player","target_actor_id":latch.receiver.actor_id,"target_epoch":latch.health.epoch}

func run() -> void:
	for id: StringName in [&"pulse_gun", &"shadow_shuriken", &"recoil_bomb"]:
		await fixture()
		await add_latch()
		await fire(id)
		check(latch.is_open and latch.open_count == 1 and latch.gate_shape.disabled, "Real " + str(id) + " opens the original physical ShotLatch once")
		check(accepted.size() == 1 and observed.size() == 1 and int(observed[0].shot_id) == accepted[0], "Gate receives exactly the actual accepted shot identity")
		check(controller.combat_energy.current == 0 and controller._air_hit_receipts.is_empty(), "Mechanism produces no enemy combat/air-action refill")
		await fixture()
		await add_latch()
		body(Rect2(112, 560, 16, 140))
		await tick(2)
		await fire(id)
		check(not latch.is_open and latch.open_count == 0, "Adjacent real wall still blocks " + str(id) + " from ringing the far bell")
	await fixture()
	await add_latch(Vector2(500, 682))
	check(not latch.receiver.receive_damage(context("unregistered", 999)), "An unregistered invented shot cannot open the gate")
	await fire(&"recoil_bomb", Vector2.LEFT)
	check(accepted.size() == 1 and not latch._eligible_shots.is_empty(), "Missed base bomb still registers its actual bounded shot")
	var shot := accepted[0]
	await tick(140)
	check(latch._eligible_shots.is_empty() and not latch.receiver.receive_damage(context("expired", shot)), "Original TTL rejects stale accepted bomb identity")
	for invalidation: String in ["actor", "end", "cancel", "death"]:
		await fixture()
		await add_latch(Vector2(500, 682))
		await fire(&"recoil_bomb", Vector2.LEFT)
		check(latch.receiver.receive_damage(context("pending-" + invalidation, accepted[0])), "Existing original sink accepts a current pending identity before " + invalidation)
		var request := latch._pending.duplicate()
		match invalidation:
			"actor": scope.invalidate_actor()
			"end": scope.end()
			"cancel": latch.cancel()
			"death": controller.die()
		latch._commit_open(request)
		check(not latch.is_open and not latch.gate_shape.disabled, "Deferred gate preserves original rejection after " + invalidation)
	await fixture()
	await add_latch(Vector2(200, 682), true)
	(latch as BacksideShotLatch).upper_control = Vector2(-200, 400)
	await fire(&"recoil_bomb")
	check(not latch.is_open, "Real blast cannot bypass backside latch's required firing bank")
	await fixture()
	await add_latch(Vector2(500, 682))
	await fire(&"recoil_bomb", Vector2.LEFT)
	var old_packet := controller.shoot_ability.packet_id
	var runtime := controller.shoot_ability.behavior()
	controller.shoot_ability.equip(preload("res://resources/weapons/pulse_gun.tres"))
	check(not runtime.hit(latch.receiver, old_packet, 999, "stale", false, latch.receiver.get_parent().global_position, Vector2.RIGHT), "Equipment invalidation removes old bomb mechanism authority")
	await fixture(Vector2(100, 500))
	controller.shoot_ability.equip(preload("res://resources/weapons/recoil_bomb.tres"))
	controller.shoot_ability.cooldown_remaining = 1.0 # Explicit rejected-state initialization.
	var before := controller.action_resources.shot_charges
	check(not controller.shoot_ability.try_fire(Vector2.RIGHT, false) and accepted.is_empty() and controller.action_resources.shot_charges == before, "Rejected cooldown request emits no identity and spends nothing")
	await duplicate_blast_and_rune()
	if is_instance_valid(latch): latch.cancel()
	check(await load("res://tests/audio_teardown.gd").drain_world(world), "Final consumer audio releases")
	world.queue_free()
	await process_frame
	print("HOME WEAPON CONSUMERS: %s assertions, %s failures" % [checks, failures])
	quit(1 if failures else 0)

func duplicate_blast_and_rune() -> void:
	await fixture(Vector2(100, 500))
	var targets: Array[Damageable] = []
	for point: Vector2 in [Vector2(100, 585), Vector2(120, 585)]:
		var area := Area2D.new()
		area.position = point
		area.collision_layer = 2
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(20, 20)
		shape.shape = rect
		area.add_child(shape)
		var target := Damageable.new()
		target.name = "Damageable"
		target.faction = &"enemy"
		target.max_health = 100
		area.add_child(target)
		world.add_child(area)
		target.damaged.connect(func(value: Dictionary) -> void: observed.append(value.duplicate()))
		targets.append(target)
	var rune := WindkeeperEncounter.new()
	# Original retained directional/rune policy, initialized without a world/AI route.
	rune.definition = preload("res://resources/bosses/legacy/windkeeper_storm_window_v4.tres")
	rune.rune_platform = 1
	rune.chase_segment = 1
	rune.register_rune_shot(controller.session_id, 999)
	check(rune._rune_shots.is_empty(), "Inactive/unopened original rune phase refuses registration")
	rune.active = true
	rune.stage_phase = 3
	rune.mode = &"pier_open"
	controller.shoot_ability.shot_fired.connect(func(_axis: Vector2, id: int) -> void: rune.register_rune_shot(controller.session_id, id))
	await tick(2)
	controller.shoot_ability.equip(preload("res://resources/weapons/recoil_bomb.tres"))
	controller.shoot_ability.shot_fired.connect(func(_axis: Vector2, _id: int) -> void:
		var live := controller.shoot_ability.behavior().current_entities()
		if not live.is_empty():
			controller.shoot_ability.behavior().explode(live[0])
			controller.shoot_ability.behavior().explode(live[0]))
	controller.router.request_action(&"shoot_release", Vector2.DOWN)
	await tick(2)
	check(accepted.size() == 1 and targets[0].health == 98 and targets[1].health == 98, "Repeated callback for the same real bomb still commits one blast per enemy")
	check(controller._air_hit_receipts.size() == 1 and controller.combat_energy.current > 0 and controller.combat_energy.current <= controller.combat_energy.definition.packet_gain_limit, "Two blast targets share one accepted airborne shot and bounded packet combat gains")
	check(observed.size() == 2 and int(observed[0].shot_id) == accepted[0] and observed[0].fired_airborne == true, "Real bomb damage context preserves accepted shot and actual airborne origin")
	if not observed.is_empty():
		var value := observed[0].duplicate()
		rune.stage_phase = 2
		check(rune.accepts_core_direction(value), "Original upper-core guard accepts the actual downward blast direction")
		var sideways := value.duplicate()
		sideways.hit_direction = Vector2.RIGHT
		check(not rune.accepts_core_direction(sideways), "Original upper-core guard still rejects sideways hits")
		rune.stage_phase = 3
		check(rune.accepts_core_direction(value), "Original rune guard recognizes the same actual accepted airborne bomb shot")
		value.fired_airborne = false
		check(not rune.accepts_core_direction(value), "Rune guard still rejects a grounded context")
		value = observed[0].duplicate()
		value.shot_id = 999
		check(not rune.accepts_core_direction(value), "Rune guard still rejects an unregistered shot")
		rune.chase_segment = 2
		check(not rune.accepts_core_direction(observed[0]), "Rune guard still rejects the wrong accepted platform")
	observed.clear()
	rune.free()
