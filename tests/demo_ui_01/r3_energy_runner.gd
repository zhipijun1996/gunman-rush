extends SceneTree

const GEAR := preload("res://tests/gear_inventory_support.gd")
## R3 current contract. Real Controller/Router/Ability/Resource consumers;
## explicit placement/resource-edge fixtures, not natural play or device proof.
var checks := 0
var failures := 0
var ledger: Array[Dictionary] = []
var world: Node2D
var player: PlayerMotor
var actor: PlayerController
var target: StaticBody2D
var target_health: HealthState
var policy: FrameDamagePolicy
var life: DemoLifetime

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	ledger.append({"label": label, "passed": ok})
	if not ok:
		failures += 1
		printerr("R3 ENERGY FAIL: " + label)

func frames(count: int = 2) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func fixture() -> void:
	paused = false
	if is_instance_valid(world): world.free()
	check(is_equal_approx(Engine.time_scale, 1.0), "previous actor teardown releases time-scale ownership")
	world = Node2D.new()
	root.add_child(world)
	player = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(200, -1000)
	world.add_child(player)
	actor = player.get_node("Controller")
	actor.set_physics_process(false)
	player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	var gamepad := player.get_node_or_null("GamepadAdapter")
	if gamepad != null: gamepad.set_physics_process(false)
	check(actor.enable_shot_energy(), "current default time-energy policy configures")
	check(not actor.shot_energy.definition.shooting_consumes_energy and actor.shot_energy.definition.resource_id == &"time_energy_v2", "default enable binds explicit v2 Definition")
	check(actor.air_focus_ability.stamina_state == actor.actor_resources.stamina, "focus and displayed actor stamina have one real resource identity")
	life = DemoLifetime.new()
	policy = FrameDamagePolicy.new()
	policy.lifetime = life
	world.add_child(policy)
	policy.register_target(&"player", actor.actor_resources.health, true)
	target = StaticBody2D.new()
	target.position = player.position + Vector2(0, 450)
	target.collision_layer = 4
	world.add_child(target)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 40
	shape.shape = circle
	target.add_child(shape)
	var receiver := Damageable.new()
	receiver.name = "Damageable"
	receiver.actor_id = target.get_instance_id()
	receiver.faction = &"enemy"
	target.add_child(receiver)
	target_health = HealthState.new()
	var definition := HealthDefinition.new()
	definition.resource_id = &"r3_target_fixture"
	definition.max_health = 100
	definition.initial_current = 100
	target_health.configure(definition)
	receiver.bind_health(target_health)
	policy.bind_damageable(&"target", receiver, target_health)
	await frames()

func step(real_seconds: float) -> void:
	# Exercise the actual Controller path, including conversion from scaled
	# physics delta to the AirFocus real-second clock. Automatic ticks are off.
	actor._physics_process(real_seconds * Engine.time_scale)

func spend_to(amount: float) -> void:
	var state := actor.actor_resources.stamina
	state.consume_continuous(maxf(0, state.current - amount), state.epoch)

func shot(direction: Vector2 = Vector2.DOWN) -> bool:
	actor.shoot_ability.advance(1)
	return actor.shoot_ability.try_fire(direction, false)

func held_aim(mode: StringName) -> void:
	actor.router.aim_mode = mode
	actor.router.set_aim(&"keyboard_mouse", Vector2.RIGHT, true)

func present_ring(hud: DemoGameHud) -> void:
	hud._process(0.0)
	if hud.time_ring.has_method("_process"): hud.time_ring.call("_process", 0.0)

func run() -> void:
	await fixture()
	check(player.tuning.max_air_shots == 1 and actor.action_resources.shot_charges == 1, "formal baseline has one airborne round")
	spend_to(0)
	check(actor.shot_energy.can_fire(), "zero time energy does not reject an otherwise legal shot")
	check(actor.traversal.grant(&"double_jump") and actor.traversal.grant(&"grapple"), "real granted D/H are present in committed-hit refill fixture")
	# Explicit exhausted movement ledger, then real projectile commit below.
	actor.jump_ability.used_jumps = 2
	actor.traversal.hook_used = true
	check(shot(), "real shot fires at zero time energy")
	check(actor.actor_resources.stamina.current == 0 and actor.action_resources.shot_charges == 0, "shot consumes one round and no time energy")
	check(not shot(), "one missed/in-flight round cannot fire a second airborne shot")
	await frames(35)
	check(target_health.current == 99, "swept projectile commits damage against real Damageable")
	check(actor.actor_resources.stamina.current == 0 and actor.received_resource_grants.size() == 1, "committed hit queues exactly one round and no energy refund")
	check(actor.jump_ability.can_air_jump() and not actor.traversal.hook_used, "actual airborne bullet damage restores granted D/H qualifications")
	actor.physics_tick(1.0 / 60)
	check(actor.action_resources.shot_charges == 1 and actor.actor_resources.stamina.current == 0, "next Controller tick applies hit round within one-round cap")
	actor.on_projectile_hit(actor.session_id, 1, true)
	check(actor.received_resource_grants.is_empty(), "same committed shot callback cannot duplicate the round")
	actor.shot_energy.advance(5, true)
	check(actor.actor_resources.stamina.current == 0, "v2 shot policy does not regenerate time energy even on ground")

	for weapon_path: String in ["res://resources/weapons/sustained_laser.tres", "res://resources/weapons/laser_cannon.tres"]:
		for initial_energy: float in [0.0, 60.0]:
			await fixture()
			check(actor.shoot_ability.equip(load(weapon_path) as WeaponDefinition), "real laser equips: " + weapon_path)
			# Disable only the optional slow-time capability to isolate the beam's
			# own primary/continuous costs; no mocked resource or beam consumer.
			actor.air_focus_ability.enabled = false
			spend_to(initial_energy)
			held_aim(&"attack")
			step(1.0 / 60)
			check(actor.shoot_ability.behavior().phase == &"beam", "actual held laser begins independently of time energy: " + weapon_path + "/" + str(initial_energy))
			for index: int in 6: step(1.0 / 60)
			check(actor.shoot_ability.behavior().phase == &"beam" and actor.shoot_ability.behavior()._beam_elapsed > 0, "actual laser continuous advance remains accepted")
			check(actor.actor_resources.stamina.current == initial_energy and actor.action_resources.shot_charges == 0, "laser primary/continuous beam spends one round and no extra time energy")
			actor.router.clear("r3_laser_cancel")
			check(actor.shoot_ability.behavior().phase == &"idle" and Engine.time_scale == 1.0, "laser cancel releases beam and preserves normal clock")

	for mode: StringName in [&"attack", &"grapple"]:
		await fixture()
		if mode == &"grapple": check(actor.traversal.grant(&"grapple"), "real H capability allows hook aiming fixture")
		var focus := actor.air_focus_ability
		actor.router.set_aim(&"keyboard_mouse", Vector2.RIGHT, false)
		step(0.1)
		check(not focus.active and focus.stamina == focus.stamina_state.capacity, "passive direction without held aim does not consume time energy: " + str(mode))
		held_aim(mode)
		var before := focus.stamina
		step(0.1)
		check(focus.active and is_equal_approx(Engine.time_scale, player.tuning.focus_time_scale), "real airborne held aim enters slow time: " + str(mode))
		check(is_equal_approx(before - focus.stamina, player.tuning.focus_stamina_drain * 0.1), "only accepted slow-time real seconds consume shared energy: " + str(mode))
		var after := focus.stamina
		actor.router.set_aim(&"keyboard_mouse", Vector2.RIGHT, false)
		step(0.5)
		check(not focus.active and Engine.time_scale == 1.0 and focus.stamina == after, "release restores normal time with no airborne regeneration: " + str(mode))
		actor.shot_energy.advance(10, false)
		check(focus.stamina == after, "shot policy cannot replenish airborne focus: " + str(mode))

	await fixture()
	held_aim(&"attack")
	step(0.1)
	var before_shot := actor.actor_resources.stamina.current
	check(shot(Vector2.UP), "real release shot is legal after slow aim")
	check(not actor.air_focus_ability.active and Engine.time_scale == 1.0 and actor.actor_resources.stamina.current == before_shot, "accepted shot stops focus without a second energy debit")
	actor.shoot_ability.clear_projectiles()
	actor.router.clear("r3_ground_fixture")
	var floor_body := StaticBody2D.new()
	floor_body.position = player.position + Vector2(0, 100)
	world.add_child(floor_body)
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(900, 24)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)
	await frames()
	for index: int in 90: step(1.0 / 60)
	check(player.is_on_floor() and actor._was_grounded, "ground recovery fixture lands through real Motor collision")
	spend_to(20)
	step(0.5)
	check(is_equal_approx(actor.actor_resources.stamina.current, 20 + player.tuning.focus_stamina_recovery * 0.5), "actual grounded Controller recovers via AirFocus only, without double recovery")
	check(actor.traversal.grant(&"grapple"), "ground availability edge grants real H")
	actor.traversal.hook_used = true # Explicit charge boundary after a grounded cast.
	var ground_hud := DemoGameHud.new()
	world.add_child(ground_hud)
	ground_hud.bind(actor)
	check(ground_hud.hook_icon.visible, "ground H stays visibly available despite last-cast flag, matching request_hook")
	ground_hud.free()
	held_aim(&"attack")
	var ground_before := actor.actor_resources.stamina.current
	step(0.1)
	check(not actor.air_focus_ability.active and actor.actor_resources.stamina.current >= ground_before, "ground held aim never enters or spends slow time")

	await fixture()
	var build := BuildState.new()
	build.configure(actor)
	var baseline_drain := player.tuning.focus_stamina_drain
	var baseline_recovery := player.tuning.focus_stamina_recovery
	var grip := preload("res://resources/items/efficient_grip.tres")
	var echo := preload("res://resources/items/echo_magazine.tres")
	check(GEAR.add_and_equip(build, &"grip", grip) and is_equal_approx(player.tuning.focus_stamina_drain, baseline_drain * 0.8), "actual current grip changes focus drain, not shot cost")
	check(GEAR.add_and_equip(build, &"grip", grip) and is_equal_approx(player.tuning.focus_stamina_drain, baseline_drain * 0.8), "same grip source remains idempotent")
	check(GEAR.add_and_equip(build, &"echo", echo) and is_equal_approx(player.tuning.focus_stamina_recovery, baseline_recovery + 5), "actual current echo changes ground focus recovery")
	check(GEAR.unequip_source(build, &"grip") and player.tuning.focus_stamina_drain == baseline_drain, "removing grip restores sole focus base")
	check(GEAR.unequip_source(build, &"echo") and player.tuning.focus_stamina_recovery == baseline_recovery, "removing echo restores sole recovery base")
	build.clear() # Each numerical fixture starts a fresh ownership case.
	for effect: Dictionary in [
		{"id": "efficient_grip", "stat": &"focus_stamina_drain", "expected": baseline_drain * 0.8},
		{"id": "echo_magazine", "stat": &"focus_stamina_recovery", "expected": baseline_recovery + 5},
		{"id": "braided_cord", "stat": &"focus_stamina_recovery", "expected": baseline_recovery * 1.35},
		{"id": "echo_gold", "stat": &"focus_stamina_recovery", "expected": baseline_recovery + 10},
		{"id": "cooling_fin", "stat": &"focus_rearm_stamina", "expected": player.tuning.focus_rearm_stamina * 0.65},
	]:
		var item := load("res://resources/items/%s.tres" % effect.id) as ItemDefinition
		var stat := StringName(effect.stat)
		var original: float = player.tuning.get(stat)
		check(item != null and item.definition_version == 3 and not ItemPresentation.effects(item).is_empty(), "migrated item has versioned nonempty real effect: " + str(effect.id))
		check(GEAR.add_and_equip(build, &"migrated", item) and is_equal_approx(player.tuning.get(stat), effect.expected), "real current item equip changes the declared focus stat: " + str(effect.id))
		check(GEAR.unequip_source(build, &"migrated") and is_equal_approx(player.tuning.get(stat), original), "real current item unequip restores its exact base: " + str(effect.id))
		build.clear()
	check(shot(Vector2.UP), "capacity-growth fixture consumes initial round")
	actor.shoot_ability.clear_projectiles()
	var magazine := ItemDefinition.new()
	magazine.stable_id = &"r3_capacity_fixture"
	magazine.display_name = "R3 explicit capacity edge fixture"
	var modifier := BuildModifier.new()
	modifier.stat_id = &"max_air_shots"
	modifier.operation = BuildModifier.Operation.ADD
	modifier.value = 1
	magazine.modifiers = [modifier]
	check(GEAR.add_and_equip(build, &"capacity", magazine) and player.tuning.max_air_shots == 2, "real BuildState can increase declared capacity")
	check(actor.action_resources.shot_charges == 0, "capacity growth never gifts current rounds")
	actor.action_resources.advance(false)
	actor.queue_grant(10, actor.session_id)
	actor.physics_tick(1.0 / 60)
	check(actor.action_resources.shot_charges == 1, "same-flight grants retain old one-round flight cap after growth")
	check(GEAR.unequip_source(build, &"capacity") and player.tuning.max_air_shots == 1 and actor.action_resources.shot_charges == 1, "capacity removal clamps without gifting or removing valid current round")
	var health_before := actor.actor_resources.health.current
	check(GEAR.add_and_equip(build, &"hp", preload("res://resources/items/region_health_purple.tres")) and actor.actor_resources.health.capacity > health_before and actor.actor_resources.health.current == health_before, "health capacity growth does not gift healing")

	await fixture()
	actor.jump_ability.advance(0.01, true)
	check(actor.traversal.grant(&"double_jump"), "D grants during the explicit old-one-jump-flight edge")
	actor.jump_ability.advance(0.001, false)
	check(not actor.jump_ability.can_air_jump(), "old one-jump flight cap cannot promise a second jump inside coyote time")
	actor.jump_ability.restore_air_jump()
	check(actor.jump_ability.can_air_jump(), "accepted refill explicitly restores granted second-jump qualification")

	await fixture()
	check(actor.traversal.grant(&"double_jump") and actor.traversal.grant(&"grapple"), "real grapple contact fixture grants D/H")
	actor.jump_ability.used_jumps = 2
	target.position = player.position + Vector2(150, 0)
	target.add_to_group(&"grapple_target")
	await frames()
	check(actor.router.request_action(&"grapple", Vector2.RIGHT), "grapple enters through actual Router action queue")
	var hook_energy := actor.actor_resources.stamina.current
	for index: int in 120:
		actor.physics_tick(1.0 / 60)
		await frames(1)
		if target_health.current < 100 and actor.traversal.state in [&"hook_kick", &"free"]: break
	check(target_health.current < 100, "real hook sweep/pull/contact submits committed target damage")
	check(actor.jump_ability.can_air_jump() and not actor.traversal.hook_used, "real hook contact kick restores granted D/H qualifications")
	check(actor.actor_resources.stamina.current == hook_energy and actor.action_resources.shot_charges == 1, "grapple execution/contact does not debit time energy or gun round")

	await fixture()
	var hud := DemoGameHud.new()
	world.add_child(hud)
	hud.bind(actor)
	var ring := hud.time_ring
	check(ring.actor == actor, "ring binds actual controller, without a shadow resource")
	held_aim(&"attack")
	step(0.1)
	present_ring(hud)
	check(ring.visible and is_equal_approx(ring.fill_ratio, actor.air_focus_ability.stamina_state.current / actor.air_focus_ability.stamina_state.capacity), "visible slow-time ring reads the exact shared resource fraction")
	var center := hud.get_global_transform_with_canvas().affine_inverse() * (player.get_global_transform_with_canvas() * Vector2.ZERO)
	check(ring.screen_center.is_equal_approx(center), "ring follows actual Motor canvas transform, not Controller Node coordinates")
	var remaining := actor.actor_resources.stamina.current
	var serial := actor.shoot_ability._shot_serial
	actor.router.clear("r3_cancel")
	present_ring(hud)
	check(not ring.visible and not actor.air_focus_ability.active and Engine.time_scale == 1.0, "cancel hides ring and releases global slow-time ownership")
	check(actor.actor_resources.stamina.current == remaining and actor.shoot_ability._shot_serial == serial, "cancel does not refund energy or leak a shot")
	held_aim(&"grapple")
	step(0.1)
	actor.router.clear("pause")
	paused = true
	present_ring(hud)
	remaining = actor.actor_resources.stamina.current
	step(0.5)
	check(not ring.visible and actor.actor_resources.stamina.current == remaining and Engine.time_scale == 1.0, "paused Controller neither consumes nor regenerates; ring hides")
	paused = false
	held_aim(&"attack")
	step(0.1)
	actor.die()
	present_ring(hud)
	check(not ring.visible and not actor.air_focus_ability.active and Engine.time_scale == 1.0 and actor.received_resource_grants.is_empty(), "death hides ring and clears pending ownership without stale slow time")
	hud.unbind()
	present_ring(hud)
	check(ring.actor == null and not ring.visible, "unbind clears ring actor reference and presentation")
	world.free()
	# Observe deferred renderer/visual teardown after all resource observations.
	await process_frame
	await process_frame
	var output := "res://build/verification/demo-ui-r3/energy.json"
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var proof := FileAccess.open(output, FileAccess.WRITE)
	if proof == null:
		push_error("Cannot persist R3 energy evidence")
		quit(1)
		return
	proof.store_string(JSON.stringify({"checks": checks, "failures": failures, "ledger": ledger, "scope": "Actual Controller/Router/resource/HUD consumers with explicit fixtures. No device, natural combat, or independent-review claim."}, "\t") + "\n")
	proof.close()
	print("DEMO UI R3 ENERGY: %s checks, %s failures" % [checks, failures])
	quit(1 if failures else 0)
