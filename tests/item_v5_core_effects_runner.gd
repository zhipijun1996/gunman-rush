extends SceneTree
## ITEM-V5-01 focused real Runtime/Controller/resource consumers.
## SETUP: combat-test stage, known catalog ownership, isolated motion resets,
## high-HP targets, and accepted weapon-commit envelopes. Commit envelopes enter
## actual Damageable HP transactions before invoking Controller.on_weapon_damage;
## they are not a natural projectile route or physical-device playtest.
const EQUIP := preload("res://tests/gear_inventory_support.gd")
const DT := 1.0 / 60.0
var assertions := 0
var failures := 0
var fixture: RefCounted
var actor: PlayerController
var build: BuildState
var runtime: ItemRuntime
var lifetime: DemoLifetime
var hit_serial := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func dispose() -> void:
	paused = false
	if runtime != null: runtime.clear()
	if build != null: build.clear()
	if fixture != null and is_instance_valid(fixture.get("world")):
		(fixture.get("world") as Node).free()
	actor = null
	runtime = null
	build = null
	fixture = null

func fresh() -> void:
	dispose()
	fixture = preload("res://tests/combat_tests.gd").new()
	fixture.set("tree", self)
	await fixture.call("fixture", Vector2(80, 150))
	actor = fixture.get("controller") as PlayerController
	lifetime = DemoLifetime.new()
	build = BuildState.new()
	build.configure(actor, lifetime, &"v5_core_effects")
	runtime = ItemRuntime.new()
	runtime.configure(actor, build, lifetime, RunWallet.new())
	runtime.bind_world(fixture.get("world") as Node2D, &"core_effects/map_one")

func ticks(count: int) -> void:
	for unused: int in count:
		await physics_frame
		actor.physics_tick(DT)
		runtime.advance(DT, DT)

func own(id: StringName, source: StringName) -> bool:
	return build.add_item(source, ItemCatalogV5.get_item(id))

func equip(wanted: Array[StringName]) -> bool:
	var sources: Array[StringName] = []
	for id: StringName in wanted:
		var instance := build.inventory.instance_for_definition(id)
		if instance == null: return false
		sources.append(instance.source_id)
	var accepted := EQUIP.equip_sources(build, sources)
	# Production BuildState.changed is deferred; observe its real delivery rather
	# than manually populating Runtime._effects or calling an effect module.
	await process_frame
	await process_frame
	return accepted

func training_target(point: Vector2) -> Damageable:
	var body := Area2D.new()
	body.position = point
	body.collision_layer = 2
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 24)
	collision.shape = shape
	body.add_child(collision)
	var receiver := Damageable.new()
	receiver.name = "Damageable"
	receiver.faction = &"enemy"
	receiver.actor_id = body.get_instance_id()
	body.add_child(receiver)
	(fixture.get("world") as Node).add_child(body)
	var definition := HealthDefinition.new()
	definition.resource_id = StringName("core_target/%s" % receiver.actor_id)
	definition.max_health = 1000.0
	definition.initial_current = 1000.0
	var health := HealthState.new()
	health.configure(definition)
	receiver.bind_health(health)
	return receiver

func accepted_hit(receiver: Damageable, packet: int, skill := false, source_session := -1, weapon_epoch := -1) -> bool:
	hit_serial += 1
	var expected_session := actor.session_id if source_session < 0 else source_session
	var expected_weapon := actor.shoot_ability.weapon_epoch if weapon_epoch < 0 else weapon_epoch
	var shot := hit_serial
	var controller := actor
	return receiver.receive_damage({
		"event_id": "core_accepted/%s" % shot,
		"amount": 1.0, "source_faction": &"player",
		"source_actor_id": actor.motor.get_instance_id(),
		"target_actor_id": receiver.actor_id, "target_epoch": receiver.damage_epoch,
		"skill_attack": skill,
		"on_committed": func() -> void:
			controller.on_weapon_damage(expected_session, packet, shot, false, receiver.actor_id, skill, receiver, expected_weapon)
	})

func ground_sample() -> Dictionary:
	# Isolated motion setup; no assignment to item-derived speed or velocity.
	actor.router.clear("core_motion_fixture")
	actor.motor.reset_at(Vector2(80, 150))
	actor._was_grounded = false
	await ticks(30)
	var grounded := actor.motor.is_on_floor()
	actor.router.set_move_axis(1.0)
	await ticks(30)
	var start := actor.motor.position.x
	var speed := actor.motor.normal_velocity.x
	await ticks(10)
	return {"grounded": grounded and actor.motor.is_on_floor(), "speed": speed, "distance": actor.motor.position.x-start}

func airborne_speed() -> float:
	actor.router.clear("core_air_fixture")
	actor.motor.reset_at(Vector2(80, -300))
	actor._was_grounded = false
	actor.router.set_move_axis(1.0)
	await ticks(30)
	check(not actor.motor.is_on_floor(), "air-speed control remains genuinely airborne through real Motor steps")
	return actor.motor.normal_velocity.x

func ground_shoes() -> void:
	await fresh()
	var base := actor.motor.tuning.ground_speed
	var baseline := await ground_sample()
	check(baseline.grounded and is_equal_approx(baseline.speed, base), "baseline Controller reaches unchanged ordinary ground speed")
	check(own(&"B28", &"shoes/one"), "B28 ownership enters actual inventory")
	var owned_only := await ground_sample()
	check(is_equal_approx(owned_only.speed, baseline.speed) and is_equal_approx(owned_only.distance, baseline.distance), "backpack shoes cannot change actual run speed or distance")
	check(await equip([&"B28"]), "B28 equips through a paused versioned equipment command")
	var equipped := await ground_sample()
	check(equipped.grounded and is_equal_approx(equipped.speed, base*1.05), "equipped B28 changes real grounded Controller speed by exactly1.05")
	check(is_equal_approx(equipped.distance, baseline.distance*1.05), "B28 changes the actual ten-tick grounded displacement by exactly1.05")
	check(is_equal_approx(await airborne_speed(), base), "B28 does not increase actual airborne steering speed")
	check(await equip([]), "B28 unload command succeeds")
	var removed := await ground_sample()
	check(is_equal_approx(removed.speed, baseline.speed) and is_equal_approx(removed.distance, baseline.distance), "unloading shoes restores real baseline speed and distance")
	check(await equip([&"B28"]), "B28 can be equipped again without new ownership")
	var repeated := await ground_sample()
	check(is_equal_approx(repeated.speed, equipped.speed) and actor.motor.tuning.ground_speed == base, "repeated B28 equipment does not accumulate or modify the sole base tuning")

func resonance_fork() -> void:
	await fresh()
	var first := training_target(Vector2(180, 150))
	var second := training_target(Vector2(230, 150))
	var third := training_target(Vector2(280, 150))
	check(accepted_hit(first, 1) and actor.combat_energy.current == 7, "baseline accepted primary damage grants real seven-point resonance")
	check(own(&"B18", &"fork/one"), "B18 is owned before equipment")
	actor.combat_energy.reset()
	check(accepted_hit(first, 2) and actor.combat_energy.current == 7, "un-equipped B18 produces no additional resonance")
	check(await equip([&"B18"]), "B18 Lv1 enters real Runtime through equipment signal")
	actor.combat_energy.reset()
	check(accepted_hit(first, 3) and actor.combat_energy.current == 9, "B18 Lv1 adds two to an accepted primary target's seven-point grant")
	check(accepted_hit(first, 3) and actor.combat_energy.current == 9, "a second accepted round in the same packet-target cannot duplicate B18 resonance")
	check(accepted_hit(second, 3) and actor.combat_energy.current == 12, "second target shares the real twelve-point total packet cap")
	check(accepted_hit(third, 3) and actor.combat_energy.current == 12, "third accepted target cannot exceed the same packet's twelve-point cap")
	check(accepted_hit(first, 4) and actor.combat_energy.current == 21, "a genuinely new primary packet receives its own resonance budget")
	check(accepted_hit(first, 5, true) and actor.combat_energy.current == 21, "accepted weapon-skill damage cannot gain baseline or B18 resonance")
	check(accepted_hit(first, 6, false, actor.session_id+1) and actor.combat_energy.current == 21, "old or different actor session cannot grant B18 resonance")
	check(accepted_hit(first, 7, false, -1, actor.shoot_ability.weapon_epoch+1) and actor.combat_energy.current == 21, "different weapon epoch cannot grant B18 resonance")
	var identity := build.inventory.instance_for_definition(&"B18").instance_id
	check(own(&"B18", &"fork/two") and build.inventory.instance_for_definition(&"B18").instance_id == identity and build.equipment.snapshot().used == 2, "equipped B18 growth retains one instance and its original gear cost")
	await process_frame
	await process_frame
	actor.combat_energy.reset()
	check(accepted_hit(first, 8) and actor.combat_energy.current == 10, "actual Lv2 upgrade changes one primary target's grant to ten")
	check(own(&"B18", &"fork/three"), "B18 third unique source upgrades the actual owned instance")
	await process_frame
	await process_frame
	actor.combat_energy.reset()
	check(accepted_hit(first, 9) and actor.combat_energy.current == 11, "actual Lv3 upgrade changes one primary target's grant to eleven")
	check(accepted_hit(second, 9) and actor.combat_energy.current == 12, "Lv3 retains the same twelve-point multi-target packet cap")
	check(await equip([]), "B18 can be unloaded after growth")
	actor.combat_energy.reset()
	check(accepted_hit(first, 10) and actor.combat_energy.current == 7, "unloading B18 removes the extra gain from actual committed damage")
	check(await equip([&"B18"]), "B18 can be re-equipped at its persistent level")
	actor.combat_energy.reset()
	check(accepted_hit(first, 11) and actor.combat_energy.current == 11, "re-equipping Lv3 restores eleven once without multiplying the bonus")

func drones() -> Array:
	return runtime.get("_companions").call("snapshot")

func assembly_threshold_and_s01() -> void:
	await fresh()
	check(own(&"B18", &"assembly/fork") and own(&"P15", &"assembly/box") and await equip([&"B18", &"P15"]), "S01 pair fits five slots through actual inventory and equipment")
	var target := training_target(Vector2(180, 150))
	await physics_frame
	for packet: int in range(20, 29):
		check(accepted_hit(target, packet), "S01 earning fixture commits actual primary target HP for packet%s" % packet)
	check(actor.combat_energy.current == 81 and drones().is_empty(), "nine B18 primary packets earn81 but earning alone never summons P15")
	check(runtime.spend_energy(44, &"assembly/spend44", false) and actor.combat_energy.current == 37 and drones().is_empty() and float(runtime.state(&"P15").spent_remainder) == 44, "real44-point spend persists remainder below current45-point threshold")
	check(runtime.spend_energy(1, &"assembly/spend1", false) and actor.combat_energy.current == 36 and drones().size() == 1 and float(runtime.state(&"P15").spent_remainder) == 0, "45th actually debited point summons exactly one real temporary companion")
	check(not runtime.spend_energy(1, &"assembly/spend1", false) and actor.combat_energy.current == 36 and drones().size() == 1, "replayed spend receipt neither charges again nor duplicates the companion")
	check(not runtime.spend_energy(80, &"assembly/poor", false) and actor.combat_energy.current == 36 and drones().size() == 1 and float(runtime.state(&"P15").spent_remainder) == 0, "insufficient real resonance cannot contribute fictional spend or create a companion")
	for packet: int in range(30, 34): accepted_hit(target, packet)
	check(actor.combat_energy.current == 72, "new accepted B18 packets refill the same real combat currency")
	check(runtime.spend_energy(45, &"assembly/second", false) and actor.combat_energy.current == 27 and drones().size() == 2, "second real45-point threshold reaches the two-companion field cap")
	check(actor.combat_energy.grant("assembly/cap_fixture", 100) == 73, "explicit fixture top-up uses the capacity-limited real grant transaction")
	check(runtime.spend_energy(90, &"assembly/full_field", false) and actor.combat_energy.current == 10 and drones().size() == 2 and float(runtime.state(&"P15").spent_remainder) == 0, "full field consumes real90 but does not store complete hidden summon thresholds")
	var before := target.health
	var energy := actor.combat_energy.current
	runtime.advance(1.51, 1.51)
	check(is_equal_approx(before-target.health, runtime.base_damage()*0.35*2), "both actual temporary companions damage the real target at0.35D each")
	check(actor.combat_energy.current == energy and drones().size() == 2 and float(runtime.state(&"P15").spent_remainder) == 0, "S01 companion-derived damage returns no B18 energy and creates no recursive summons")
	runtime.advance(6.5, 6.5)
	check(drones().is_empty(), "temporary companions actually expire after eight world seconds")
	runtime.advance(2.0, 2.0)
	check(drones().is_empty() and actor.combat_energy.current == energy, "expired full-field thresholds cannot respawn a banked companion or mint resonance")
	actor.combat_energy.grant("assembly/remainder_fixture", 60)
	check(runtime.spend_energy(20, &"assembly/partial", false) and float(runtime.state(&"P15").spent_remainder) == 20, "new incomplete spend remains persistent owned progress")
	check(await equip([&"B18"]), "P15 unloads while B18 remains equipped")
	check(runtime.spend_energy(25, &"assembly/while_unloaded", false) and float(runtime.state(&"P15").spent_remainder) == 20 and drones().is_empty(), "spending while P15 is in backpack cannot advance or summon its effect")
	check(await equip([&"B18", &"P15"]) and drones().is_empty() and float(runtime.state(&"P15").spent_remainder) == 20, "re-equipping restores incomplete progress without a free summon")
	check(runtime.spend_energy(24, &"assembly/reloaded24", false) and drones().is_empty() and float(runtime.state(&"P15").spent_remainder) == 44, "reloaded progress still waits for the actual45th spent point")
	actor.combat_energy.grant("assembly/last_fixture", 10)
	check(runtime.spend_energy(1, &"assembly/reloaded1", false) and drones().size() == 1 and float(runtime.state(&"P15").spent_remainder) == 0, "one final real debit completes retained progress exactly once")

func cast_outcome() -> Dictionary:
	# Explicit independent-cast setup uses the actual legacy reset, which clears
	# motion/input/session receipts; it does not grant or edit equipment/range.
	actor.reset_at(Vector2(80, 80))
	actor.router.grapple_available = true
	var queued := actor.router.request_action(&"grapple", Vector2.RIGHT)
	await ticks(1)
	for unused: int in 60:
		if actor.traversal.state in [&"hook_pull", &"hook_miss"]: break
		await ticks(1)
	return {"queued":queued, "state":actor.traversal.state, "distance":actor.traversal.hook_start.distance_to(actor.traversal.hook_tip), "target":actor.traversal.hook_target}

func long_hook() -> void:
	await fresh()
	check(actor.traversal.grant(&"grapple"), "hook fixture explicitly grants the independent region core capability")
	var base := actor.traversal.definition.hook_range
	var anchor := GrappleAnchor.new()
	anchor.position = Vector2(80+base*1.12, 74)
	(fixture.get("world") as Node).add_child(anchor)
	await physics_frame
	check(anchor.is_in_group(&"grapple_target") and anchor.position.x-80-12 > base, "actual grapple anchor surface lies strictly outside the baseline hook range")
	var baseline := await cast_outcome()
	check(baseline.queued and baseline.state == &"hook_miss" and baseline.target == null and is_equal_approx(baseline.distance, base), "baseline real Router/Traversal cast cannot reach the distant anchor")
	check(own(&"B21", &"hook/one"), "B21 enters ownership without changing core ability")
	var backpack := await cast_outcome()
	check(backpack.state == &"hook_miss" and is_equal_approx(backpack.distance, base), "backpack B21 cannot extend the actual hook sweep")
	check(await equip([&"B21"]), "B21 equips after the independently granted grapple capability")
	var extended := await cast_outcome()
	check(extended.state == &"hook_pull" and extended.target == anchor and extended.distance > base and extended.distance <= base*1.15, "Lv1 real hook sweep now contacts the previously unreachable anchor inside1.15 range")
	check(await equip([]), "B21 unloads through the original equipment transaction")
	var removed := await cast_outcome()
	check(removed.state == &"hook_miss" and removed.target == null and is_equal_approx(removed.distance, base), "unloading B21 removes actual reach and the same anchor becomes unreachable again")
	check(actor.traversal.has_capability(&"grapple") and actor.traversal.definition.hook_range == base, "B21 removal preserves independent grapple rights and unchanged traversal base")

func immortal_health() -> void:
	await fresh()
	var health := actor.actor_resources.health
	var base := health.capacity
	check(own(&"G11", &"immortal/one") and health.capacity == base, "owned G11 has no maximum-HP effect before equipment")
	health.apply_damage(ActorResourceRequest.new(&"immortal/hurt", health.epoch, 2, health.get_instance_id()))
	var current := health.current
	check(await equip([&"G11"]) and health.capacity == base+3 and health.current == current, "G11 adds three real maximum HP without free current healing")
	check(await equip([]) and health.capacity == base and health.current == current, "unloading G11 fully reverses maximum HP without healing")
	check(await equip([&"G11"]) and health.capacity == base+3 and health.current == current, "re-equipping G11 recalculates once from the base without stacking")
	check(health.heal(ActorResourceRequest.new(&"immortal/explicit_heal", health.epoch, 4, health.get_instance_id())).accepted() and health.current > base, "explicit real healing fixture establishes current HP above the unequipped base")
	check(await equip([]) and health.capacity == base and health.current == base, "G11 removal correctly clamps real current HP to the restored base maximum")
	check(await equip([&"G11"]) and health.capacity == base+3 and health.current == base, "post-clamp G11 re-equipment cannot recover lost current HP")

func _run() -> void:
	await ground_shoes()
	await resonance_fork()
	await assembly_threshold_and_s01()
	await long_hook()
	await immortal_health()
	print("UNVERIFIED ITEM-V5 P17: current-sheet charge movement versus pre-existing weapon baseline conflicts; this runner does not certify its behavior or resolve design.")
	dispose()
	lifetime = null
	await process_frame
	await process_frame
	print("ITEM V5 CORE EFFECTS: %s checks, %s failures" % [assertions, failures])
	quit(1 if failures else 0)
