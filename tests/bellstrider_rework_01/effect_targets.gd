extends SceneTree
## Native item-module fixture with the actual Bellstrider receivers and physical
## queries. The existing isolated ModuleHost supplies item ownership/damage; this
## is not an App/FrameDamagePolicy integration or natural-combat recording.
const ITEM_FIXTURE := preload("res://tests/item_v5_actives_runner.gd")
const COMBAT_FIXTURE := preload("res://tests/combat_tests.gd")
const AUDIO_TEARDOWN := preload("res://tests/audio_teardown.gd")
var assertions := 0
var failures: Array[String] = []
var fixture: Variant
var host: Variant
var active_effects: ItemActiveEffects
var companions: ItemCompanionEffects
var boss: BossMotor
var encounter: BellstriderEncounter
var armour: Damageable
var bell: Damageable
var armour_impacts: Array[Vector2] = []


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)


func frames(count: int) -> void:
	for index: int in count:
		await physics_frame


func fresh() -> void:
	if active_effects != null:
		active_effects.clear()
	if companions != null:
		companions.clear()
	if fixture != null and is_instance_valid(fixture.world):
		encounter.cancel()
		check(await AUDIO_TEARDOWN.drain_world(fixture.world), "fixture audio drains")
		fixture.world.free()
		await frames(2)
	fixture = COMBAT_FIXTURE.new()
	fixture.tree = self
	await fixture.fixture(Vector2(80, 150))
	host = ITEM_FIXTURE.ModuleHost.new()
	host.world = fixture.world
	host.controller = fixture.controller
	active_effects = ItemActiveEffects.new()
	companions = ItemCompanionEffects.new()
	active_effects.configure(host)
	companions.configure(host)
	boss = preload("res://scenes/bosses/bellstrider.tscn").instantiate()
	boss.position = Vector2(300, 135)
	fixture.world.add_child(boss)
	encounter = boss.get_node("Encounter")
	encounter.set_physics_process(false)
	await frames(3)
	check(
		encounter.configure_arena(0, 500, fixture.motor) and encounter.activate(),
		"actual Bellstrider activates"
	)
	encounter._enter(&"observe", 30.0)
	encounter._update_combat_shapes()
	await frames(2)
	armour = boss.get_node("Damageable")
	bell = encounter._core.get_node("Damageable")
	armour_impacts.clear()
	encounter.armour_hit.connect(func(point: Vector2) -> void: armour_impacts.append(point))
	# Deliberately retain armour in the isolated host list: consumers must guard
	# their own locks/budgets even when handed a cached or unfiltered candidate.
	host.targets_list.append(boss)
	host.targets_list.append(encounter._core)


func equip(id: StringName) -> Dictionary:
	var definition := ItemCatalogV5.get_item(id)
	var params := definition.parameters_for_level(1)
	host.equipment[id] = params
	return params


func entity(id: StringName, kind: StringName, point: Vector2, key: StringName) -> Dictionary:
	var params := equip(id)
	var entry := active_effects._spawn(id, kind, point, Vector2.RIGHT, key, params)
	entry.projectile_index = 0
	entry.budget_multiplier = 1.0
	return entry


func ordinary(point: Vector2) -> Damageable:
	var body := (
		fixture.body(Rect2(point - Vector2(6, 6), Vector2(12, 12)), &"enemy") as StaticBody2D
	)
	body.collision_layer = 2
	var receiver := body.get_node("Damageable") as Damageable
	receiver.max_health = 100.0
	receiver.reset()
	host.targets_list.append(body)
	return receiver


func view_at(point: Vector2) -> ItemV5Entity:
	var view := ItemV5Entity.new()
	fixture.world.add_child(view)
	view.global_position = point
	return view


func expected_physical_contact(start: Vector2, finish: Vector2) -> Dictionary:
	# Observe current hull/wheel geometry before the tested impact. The item
	# footprint has three real rays, so a bevel may contact an edge ray first.
	# This never calls the tested module's _contact or reads its feedback.
	var tuning := ItemV5Entity.read_tuning()
	var half_width := float(tuning.projection.collision_radius_px)
	var across := (finish - start).normalized().orthogonal() * half_width
	var best: Dictionary = {}
	for offset: Vector2 in [Vector2.ZERO, across, -across]:
		var query := PhysicsRayQueryParameters2D.create(
			start + offset, finish + offset, 0xFFFFFFFF, [fixture.motor.get_rid()]
		)
		query.collide_with_areas = true
		var hit: Dictionary = fixture.world.get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var reported: Vector2 = hit.position - offset
		var distance := start.distance_squared_to(reported)
		if best.is_empty() or distance < float(best.distance):
			best = {
				"collider": hit.collider,
				"point": reported,
				"surface": hit.position,
				"distance": distance
			}
	return best


func run() -> void:
	await fresh()
	check(
		not armour.can_receive_effects() and bell.can_receive_effects(),
		"only real upper bell is eligible for item effects"
	)
	check(
		encounter._core.is_in_group(&"grapple_target") and not boss.is_in_group(&"grapple_target"),
		"only the actual weakpoint is a grapple target"
	)
	var hp := encounter.health.current
	var throw := entity(&"G14", &"throw", boss.global_position, &"armour-explosion")
	active_effects._explode_throw(throw, armour)
	check(
		throw.spent and encounter.health.current == hp and host.events.is_empty(),
		"G14 armour collision cannot become primary or seed a chain to the bell"
	)
	check(
		armour_impacts.is_empty(),
		"AoE primary discovery never synthesizes a physical armour impact"
	)
	await fresh()
	hp = encounter.health.current
	throw = entity(&"G14", &"throw", Vector2(150, 165), &"physical-armour-throw")
	var tuning := ItemV5Entity.read_tuning()
	var throw_finish := (
		Vector2(150, 165)
		+ (
			Vector2.RIGHT
			* minf(float(tuning.projection.throw_range_px), float(tuning.projection.speed))
		)
	)
	var throw_contact := expected_physical_contact(Vector2(150, 165), throw_finish)
	active_effects._step_throw(throw, 1.0)
	check(
		throw.spent and encounter.health.current == hp and armour_impacts.size() == 1,
		"actual thrown-item chassis collision emits one armour response without HP loss"
	)
	check(
		(
			throw_contact.get("collider") == boss
			and not armour_impacts.is_empty()
			and armour_impacts[0].distance_to(throw_contact.get("point", Vector2.INF)) < .01
		),
		"thrown-item armour response uses the real surface contact point"
	)
	active_effects._step_throw(throw, 1.0)
	check(armour_impacts.size() == 1, "spent thrown item cannot replay a physical armour response")
	await fresh()
	var main := ordinary(Vector2(250, 105))
	await frames(2)
	hp = encounter.health.current
	throw = entity(&"G14", &"throw", main.get_parent().global_position, &"armour-before-chain")
	active_effects._explode_throw(throw, main)
	check(
		main.health < 100 and encounter.health.current < hp,
		"G14 skips closer rejected armour and spends its chain on the real bell"
	)
	check(
		host.events.size() == 2 and int(host.events[1].receiver) == bell.get_instance_id(),
		"one G14 chain slot produces one eligible weakpoint hit"
	)
	await fresh()
	var behind := ordinary(Vector2(420, 165))
	await frames(2)
	var wheel := entity(&"P24", &"flywheel", Vector2(150, 165), &"solid-armour-wheel")
	var wheel_finish := (
		Vector2(150, 165)
		+ Vector2.RIGHT * minf(float(wheel.params.range_px), float(tuning.projection.speed))
	)
	var wheel_contact := expected_physical_contact(Vector2(150, 165), wheel_finish)
	hp = encounter.health.current
	active_effects._step_flywheel(wheel, 1.0)
	check(
		wheel.phase == &"returning" and (wheel.visual as Node2D).global_position.x < 230,
		"physical flywheel turns back at the real chassis"
	)
	check(
		(wheel.hits as Dictionary).is_empty() and (wheel.target_hits as Dictionary).is_empty(),
		"rejected physical armour spends no flywheel target budget"
	)
	check(
		behind.health == 100 and encounter.health.current == hp and host.events.is_empty(),
		"physical flywheel does not tunnel through armour to a farther target"
	)
	check(armour_impacts.size() == 1, "actual flywheel chassis collision emits one armour response")
	check(
		(
			wheel_contact.get("collider") == boss
			and not armour_impacts.is_empty()
			and armour_impacts[0].distance_to(wheel_contact.get("point", Vector2.INF)) < .01
		),
		"flywheel armour response uses the real surface contact point"
	)
	active_effects._step_flywheel(wheel, 1.0)
	check(
		armour_impacts.size() == 1 and encounter.health.current == hp,
		"flywheel departure does not poll or repeat the armour response"
	)
	await fresh()
	var origin := encounter._core.global_position - Vector2(40, 0)
	wheel = entity(&"P24", &"flywheel", origin, &"weak-refused-once")
	hp = encounter.health.current
	host.reject_deals = 1
	active_effects._step_flywheel(wheel, 80.0 / 520.0)
	check(
		encounter.health.current == hp and (wheel.target_hits as Dictionary).is_empty(),
		"refused weakpoint request does not consume a flywheel hit"
	)
	wheel.ignored = []
	wheel.travelled = 0.0
	(wheel.visual as Node2D).global_position = origin
	active_effects._step_flywheel(wheel, 80.0 / 520.0)
	check(
		encounter.health.current < hp and (wheel.target_hits as Dictionary).size() == 1,
		"same flywheel keeps its real weakpoint budget after a refusal"
	)
	await fresh()
	equip(&"G08")
	host.marks[armour.get_instance_id()] = &"invalid-armour-mark"
	var chosen := companions._target(Vector2(80, 135))
	check(
		not chosen.is_empty() and chosen.receiver == bell,
		"marked armour cannot preempt an eligible companion target"
	)
	var drone := {
		"visual": view_at(Vector2(80, 135)),
		"id": &"P14",
		"ratio": 1.0,
		"attack_sequence": 0,
		"map": host.map_id,
		"session": fixture.controller.session_id,
		"weapon_epoch": fixture.controller.shoot_ability.weapon_epoch
	}
	var candidates := companions._patrol_candidates(drone)
	check(
		candidates.size() == 1 and candidates[0].receiver == bell,
		"patrol ranking removes armour before mark priority and per-target caps"
	)
	companions._set_lock(drone, {"receiver": armour, "mark_key": &"invalid-armour-mark"})
	check(int(drone.target_lock_id) == 0, "new patrol lock cannot cache rejected armour")
	drone.target_lock = weakref(armour)
	drone.target_lock_id = armour.get_instance_id()
	drone.target_lock_epoch = armour.damage_epoch
	check(
		companions._locked_target(drone).is_empty() and int(drone.target_lock_id) == 0,
		"legacy cached armour lock is discarded before firing"
	)
	companions._fire(drone, {"receiver": armour, "node": boss})
	check(
		(
			int(drone.attack_sequence) == 0
			and companions._pending_marks.is_empty()
			and host.events.is_empty()
		),
		"cached rejected armour reserves no sequence or first-mark credit"
	)
	companions._set_lock(drone, {"receiver": bell, "mark_key": &""})
	encounter._enter(&"intro", 2.0)
	encounter._update_combat_shapes()
	check(
		companions._locked_target(drone).is_empty() and int(drone.target_lock_id) == 0,
		"real weakpoint losing combat eligibility invalidates its cached lock"
	)
	active_effects.clear()
	companions.clear()
	encounter.cancel()
	check(await AUDIO_TEARDOWN.drain_world(fixture.world), "final fixture audio drains")
	fixture.world.free()
	print("BELLSTRIDER_EFFECT_TARGETS assertions=", assertions, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
