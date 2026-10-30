extends SceneTree
## Native component regressions; fixtures select modes/groups explicitly.
## This runner does not claim a natural fight, player evasion, or two-shot timing.
const AUDIO_TEARDOWN := preload("res://tests/audio_teardown.gd")
var assertions := 0
var failures: Array[String] = []
var world: Node2D
var boss: BossMotor
var encounter: BellstriderEncounter
var target: CharacterBody2D
var impacts := 0
var player_contacts := 0


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


func fixture() -> void:
	if is_instance_valid(world):
		encounter.cancel()
		await AUDIO_TEARDOWN.drain_world(world)
		world.free()
		await frames(2)
	world = Node2D.new()
	root.add_child(world)
	var ground := StaticBody2D.new()
	ground.position = Vector2(600, 650)
	var floor_shape := CollisionShape2D.new()
	var floor_rectangle := RectangleShape2D.new()
	floor_rectangle.size = Vector2(1600, 100)
	floor_shape.shape = floor_rectangle
	ground.add_child(floor_shape)
	world.add_child(ground)
	target = CharacterBody2D.new()
	target.collision_layer = 1
	target.collision_mask = 0
	target.position = Vector2(900, 582)
	var target_shape := CollisionShape2D.new()
	var target_rectangle := RectangleShape2D.new()
	target_rectangle.size = Vector2(24, 36)
	target_shape.shape = target_rectangle
	target.add_child(target_shape)
	world.add_child(target)
	boss = preload("res://scenes/bosses/bellstrider.tscn").instantiate()
	boss.position = Vector2(600, 535)
	world.add_child(boss)
	encounter = boss.get_node("Encounter")
	encounter.set_physics_process(false)
	await frames(3)
	check(encounter.configure_arena(100, 1100, target), "real Bellstrider arena configures")
	check(encounter.activate(), "real Bellstrider activates")
	encounter.skip_intro()
	encounter.projectile_created.connect(
		func(shot: BossProjectile) -> void:
			shot.hit.connect(
				func(_body: Node2D, _id: StringName, _amount: float) -> void: player_contacts += 1
			)
	)


func damage(amount: float, id: StringName) -> ActorResourceResult:
	var request := ActorResourceRequest.new()
	request.event_id = id
	request.amount = amount
	request.expected_epoch = encounter.health.epoch
	request.expected_instance_id = encounter.health.get_instance_id()
	return encounter.health.apply_damage(request)


func shelf(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	collision.shape = rectangle
	body.add_child(collision)
	world.add_child(body)
	return body


func high_arc_case(side: int, elevated: bool) -> void:
	await fixture()
	var config := encounter.definition as BellstriderDefinition
	# A shelf close to the launcher intercepted the former short low arc.
	# The ground target lies beyond its edge, not beneath impossible cover.
	var obstacle := Rect2(700 if side > 0 else 400, 430 if elevated else 470, 100, 20)
	shelf(obstacle)
	var landing := Vector2(600 + side * (360 if elevated else 230), 400 if elevated else 600)
	var destination := Rect2(880 if side > 0 else 160, 400, 160, 20)
	if elevated:
		shelf(destination)
	target.position = landing - Vector2(0, 18)
	await frames(2)
	encounter.direction = side
	encounter._group = {"kind": &"lob", "phase": 1, "return_roll": false, "count": 1}
	encounter.volley = 0
	encounter._enter(&"lob_aim", config.lob_aim_seconds)
	var aim_started := encounter._fight_age
	encounter.physics_tick(config.lob_aim_seconds - .02)
	encounter.physics_tick(.03)
	check(
		encounter.mode == &"lob_lock" and encounter.locked_point.distance_to(landing) < .01,
		(
			"actual launcher locks the authored %s support facing %d"
			% ["raised" if elevated else "ground", side]
		)
	)
	var locked := encounter.locked_point
	var angle := float(encounter._rig_inputs().get("launcher_aim", INF))
	var bell_id := encounter._core.get_instance_id()
	# The player leaves after the visible lock. This also avoids replacing a
	# surface-impact assertion with a legitimate direct hit on the old target.
	target.position = Vector2(600 + side * 460, 582)
	encounter.physics_tick(config.lob_lock_seconds * .45)
	check(
		(
			encounter.locked_point == locked
			and is_equal_approx(float(encounter._rig_inputs().get("launcher_aim", INF)), angle)
		),
		"moving player cannot retarget the locked point or launcher elevation"
	)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(encounter.combat_snapshot()))
	encounter.restore_combat_state(saved)
	check(
		(
			encounter.locked_point == locked
			and absf(float(encounter._rig_inputs().get("launcher_aim", INF)) - angle) < .00001
		),
		"JSON resume preserves locked point and launcher elevation"
	)
	var released := {
		"shot": null,
		"origin": Vector2.INF,
		"tip": Vector2.INF,
		"axis": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"surface_count": 0,
		"surface": Vector2.INF,
		"normal": Vector2.ZERO,
		"local_shocks": 0
	}
	encounter.projectile_created.connect(
		func(shot: BossProjectile) -> void:
			if str(shot.event_id).begins_with("bellstrider_local_ring-"):
				released.local_shocks = int(released.local_shocks) + 1
	)
	encounter.presentation_event.connect(
		func(event: Dictionary) -> void:
			if event.event != &"bellstrider_lob_release":
				return
			var pose := encounter.rig_pose()
			var mount: Transform2D = pose.launcher_transform
			var shot := encounter._projectiles.back() as BellstriderBellProjectile
			released.shot = shot
			released.origin = shot.global_position
			released.tip = boss.to_global(mount * Vector2(25, -3))
			released.axis = (boss.global_transform * mount).x.normalized()
			released.velocity = shot.flight_velocity
			shot.impacted.connect(
				func(point: Vector2, normal: Vector2) -> void:
					released.surface_count = int(released.surface_count) + 1
					released.surface = point
					released.normal = normal
			)
	)
	# The real lock deadline calls Encounter._launch with its actual Definition
	# and rig. No direct aim_landing, duration override or synthetic sweep here.
	encounter.physics_tick(encounter.clock + .001)
	check(encounter._fight_age - aim_started <= .75, "actual aim and locked warning launch within .75seconds")
	var shot := released.shot as BellstriderBellProjectile
	check(is_instance_valid(shot), "actual lock deadline emits a physical thrown bell")
	if not is_instance_valid(shot):
		return
	check(
		(released.origin as Vector2).distance_to(released.tip) < .001,
		"actual thrown bell starts at the shared rig launcher tip"
	)
	check(
		(
			absf((released.axis as Vector2).angle_to((released.velocity as Vector2).normalized()))
			< .03
		),
		"actual initial flight follows the visible barrel within .03 radians"
	)
	check(
		(
			encounter._core.get_instance_id() == bell_id
			and encounter._core.get_parent() == boss
			and encounter._core.collision_layer == 4
		),
		"main upper bell remains installed and damageable after a separate bell launches"
	)
	var crossed_shelf := false
	var cleared_shelf := true
	var launch_frame := Engine.get_physics_frames()
	for tick: int in ceili((encounter.lob_duration_for(locked) + .5) * 60.0):
		if not is_instance_valid(shot) or shot.spent:
			break
		var at := shot.global_position
		if at.x >= obstacle.position.x - shot.radius and at.x <= obstacle.end.x + shot.radius:
			crossed_shelf = true
			cleared_shelf = cleared_shelf and at.y + shot.radius <= obstacle.position.y + .5
		await frames(1)
	check(float(Engine.get_physics_frames() - launch_frame) / 60.0 <= 1.35, "actual thrown bell reaches its support within1.35seconds")
	check(
		crossed_shelf and cleared_shelf,
		"actual configured sweep clears the entire interposed shelf facing %d" % side
	)
	check(
		int(released.surface_count) == 1,
		"actual configured high arc makes exactly one first-surface impact"
	)
	var point: Vector2 = released.surface
	var normal: Vector2 = released.normal
	check(
		(
			absf(point.y - landing.y) < 1.0
			and absf(point.x - locked.x) <= 12.0
			and normal.dot(Vector2.UP) > .95
		),
		(
			"actual first surface is the locked %s beyond the shelf edge facing %d"
			% ["high platform" if elevated else "ground", side]
		)
	)
	check(
		int(released.local_shocks) == 1,
		"one actual surface impact creates exactly one bounded local shock"
	)
	var pose := encounter.rig_pose()
	check(
		(
			encounter._core.get_instance_id() == bell_id
			and encounter._core.transform.is_equal_approx(pose.bell_transform)
		),
		"flight never detaches the main bell or its shared authoritative weak geometry"
	)


func far_approach_case() -> void:
	await fixture()
	boss.position.x = 250.0
	target.position = Vector2(1000, 582)
	var config := encounter.definition as BellstriderDefinition
	var rng := str(encounter.combat_snapshot().rng_state)
	var start := boss.position.x
	encounter._select_group()
	check(
		(
			encounter.mode == &"approach"
			and int(encounter.combat_metrics().groups_started) == 0
			and encounter._group.is_empty()
		),
		"far target enters chase before any attack group exists"
	)
	check(
		str(encounter.combat_snapshot().rng_state) == rng and encounter._recent_groups.is_empty(),
		"far approach spends neither RNG nor attack recency"
	)
	var first_speed := 0.0
	var ramped := true
	var previous_speed := 0.0
	var weak_open := true
	for tick: int in 18:
		encounter.physics_tick(1.0 / 60.0)
		var speed := absf(boss.velocity.x)
		if tick == 0:
			first_speed = speed
		ramped = ramped and speed >= previous_speed - .001 and speed <= config.chase_speed + .001
		previous_speed = speed
		weak_open = (
			weak_open and encounter._core.collision_layer == 4 and encounter.accepts_combat_damage()
		)
		await frames(1)
	check(
		(
			first_speed > 0
			and first_speed < config.chase_speed
			and ramped
			and is_equal_approx(previous_speed, 180.0)
		),
		"actual chase motor accelerates from rest to configured 180 speed"
	)
	check(
		boss.position.x > start and boss.position.x - start < config.chase_speed * .3,
		"actual chase displacement includes its acceleration ramp"
	)
	check(weak_open, "upper bell remains damageable throughout real chase movement")
	var pose := encounter.rig_pose()
	check(
		absf(float(pose.wheel_angle) * float(pose.wheel_radius) - (boss.position.x - start)) < .001,
		"chase wheel rotation follows measured actual motor travel"
	)
	check(
		(
			str(encounter.combat_snapshot().rng_state) == rng
			and int(encounter.combat_metrics().groups_started) == 0
		),
		"long approach still owns no random group before engagement"
	)
	for tick: int in 240:
		if encounter.mode != &"approach":
			break
		encounter.physics_tick(1.0 / 60.0)
		await frames(1)
	check(
		absf(target.position.x - boss.position.x) <= config.approach_distance * .85 + .01,
		"actual chase reaches the declared engagement range"
	)
	check(
		(
			int(encounter.combat_metrics().groups_started) == 1
			and encounter._recent_groups.size() == 1
			and str(encounter.combat_snapshot().rng_state) != rng
		),
		"engagement chooses exactly one real weighted group"
	)
	var plan := encounter._group.duplicate(true)
	var chosen_rng := str(encounter.combat_snapshot().rng_state)
	target.position += Vector2(-180, -100)
	encounter.physics_tick(.05)
	check(
		(
			encounter._group == plan
			and str(encounter.combat_snapshot().rng_state) == chosen_rng
			and int(encounter.combat_metrics().groups_started) == 1
		),
		"first announced group remains fixed when player position changes"
	)


func shooter_at(point: Vector2) -> PlayerController:
	var player := preload("res://scenes/player/player.tscn").instantiate() as PlayerMotor
	player.position = point
	world.add_child(player)
	var controller := player.get_node("Controller") as PlayerController
	controller.set_physics_process(false)
	await frames(2)
	controller.physics_tick(1.0 / 60.0)
	return controller


func half_health_during_chase() -> void:
	await fixture()
	boss.position.x = 250.0
	target.position = Vector2(1000, 582)
	encounter._select_group()
	var rng := str(encounter.combat_snapshot().rng_state)
	check(
		damage(20.0, &"half-during-chase").accepted(),
		"explicit component transaction reaches half health during real chase"
	)
	encounter.physics_tick(.01)
	check(
		(
			encounter.stage_phase == 2
			and encounter.mode == &"phase_transition"
			and encounter._group.is_empty()
		),
		"half health begins pressure transition immediately when no attack group is committed"
	)
	check(
		(
			int(encounter.combat_metrics().groups_started) == 0
			and str(encounter.combat_snapshot().rng_state) == rng
			and encounter.accepts_combat_damage()
		),
		"pressure prelude consumes no attack selection and keeps the upper bell vulnerable"
	)


func hull_case(side: int) -> void:
	await fixture()
	encounter.direction = side
	encounter._enter(&"neck", (encounter.definition as BellstriderDefinition).exposed_seconds)
	encounter.physics_tick(.3)
	await frames(2)
	var pose := encounter.rig_pose()
	var hull := boss.get_node("CollisionShape2D") as CollisionShape2D
	check(
		(
			hull.shape is ConvexPolygonShape2D
			and (
				(hull.shape as ConvexPolygonShape2D).points
				== PackedVector2Array(BellstriderRigPose.HULL_POINTS)
			)
		),
		"physical hull uses the exact shared painted eight-point bevel"
	)
	check(
		hull.transform.is_equal_approx(pose.body_transform),
		"physical hull follows the lowered recovery body transform"
	)
	check(
		encounter._armour_wheels.size() == 2, "physical carriage has exactly two real wheel shapes"
	)
	if encounter._armour_wheels.size() != 2:
		return
	for index: int in 2:
		var wheel := encounter._armour_wheels[index]
		var expected: Transform2D = pose.left_wheel if index == 0 else pose.right_wheel
		check(
			(
				wheel.shape is CircleShape2D
				and is_equal_approx((wheel.shape as CircleShape2D).radius, float(pose.wheel_radius))
				and wheel.transform.is_equal_approx(expected)
			),
			"actual wheel circle radius and position match the shared rig"
		)
	var config := encounter.definition as BellstriderDefinition
	check(
		encounter._contact_shape.transform.is_equal_approx(
			pose.body_transform * Transform2D(0, config.contact_offset)
		),
		"contact geometry follows the same recovery body pose"
	)
	# At 115wu behind the carriage, the old full rectangle occupied clear air
	# above the bevel. Use the actual ground actor, centre ray and real bullet.
	var controller := await shooter_at(Vector2(boss.position.x - side * 115.0, 582))
	var aim := boss.to_global(encounter.core_offset())
	var query := PhysicsRayQueryParameters2D.create(
		controller.motor.global_position, aim, 4, [controller.motor.get_rid()]
	)
	query.collide_with_areas = true
	var first := world.get_world_2d().direct_space_state.intersect_ray(query)
	check(
		first.get("collider") == encounter._core,
		"near rear ground diagonal reaches the bell before any physical armour"
	)
	var hp := encounter.health.current
	var pointer := controller.motor.get_canvas_transform() * aim
	var direction: Vector2 = controller.motor.get_node("KeyboardMouseAdapter").world_direction(
		pointer
	)
	check(
		controller.shoot_ability.try_fire(direction, controller.motor.is_on_floor()),
		"actual base weapon accepts the near rear ground shot"
	)
	await frames(20)
	check(
		is_equal_approx(encounter.health.current, hp - 1.0),
		"real near rear projectile passes visible bevel air and damages only the bell"
	)
	controller.shoot_ability.clear_projectiles()
	controller.motor.free()
	var wheel := encounter._armour_wheels[0]
	var wheel_point := wheel.global_position
	var away := signf(wheel_point.x - boss.global_position.x)
	controller = await shooter_at(wheel_point + Vector2(away * 90, 3))
	query = PhysicsRayQueryParameters2D.create(
		controller.motor.global_position, wheel_point, 4, [controller.motor.get_rid()]
	)
	query.collide_with_areas = true
	first = world.get_world_2d().direct_space_state.intersect_ray(query)
	var shape_owner: Object
	if first.get("collider") == boss:
		shape_owner = boss.shape_owner_get_owner(boss.shape_find_owner(int(first.shape)))
	check(
		first.get("collider") == boss and shape_owner == wheel,
		"actual outer wheel ray first contacts the wheel collision shape"
	)
	var armour_hits := [0]
	encounter.armour_hit.connect(func(_point: Vector2) -> void: armour_hits[0] += 1)
	hp = encounter.health.current
	pointer = controller.motor.get_canvas_transform() * wheel_point
	direction = controller.motor.get_node("KeyboardMouseAdapter").world_direction(pointer)
	check(
		controller.shoot_ability.try_fire(direction, controller.motor.is_on_floor()),
		"actual base weapon accepts the physical wheel shot"
	)
	await frames(20)
	check(
		encounter.health.current == hp and armour_hits[0] == 1,
		"actual wheel projectile emits one armour response and changes no Boss HP"
	)
	controller.shoot_ability.clear_projectiles()
	controller.motor.free()


func run() -> void:
	await fixture()
	var definition := encounter.definition as BellstriderDefinition
	check(definition != null and definition.is_valid(), "actual declarative definition validates")
	check(
		encounter.health.capacity == 40 and definition.phase_two_health == .5,
		"forty HP with half-health phase threshold"
	)
	check(
		(
			definition.chase_speed == 180
			and definition.charge_speed == 380
			and definition.phase_two_charge_speed == 420
			and definition.ring_speed == 280
		),
		"actual resource owns movement and wave speeds"
	)
	check(encounter.weakpoint_only(), "upper bell is the only damage receiver capability")
	var contact_bounds := encounter.body_contact_rect()
	var hull := boss.get_node("CollisionShape2D") as CollisionShape2D
	var bounds_fit := contact_bounds.encloses(hull.global_transform*hull.shape.get_rect())
	for wheel: CollisionShape2D in encounter._armour_wheels:
		bounds_fit = bounds_fit and contact_bounds.encloses(wheel.global_transform*wheel.shape.get_rect())
	var weak_shape := encounter._core.get_child(0) as CollisionShape2D
	check(
		bounds_fit and contact_bounds.encloses(weak_shape.global_transform*weak_shape.shape.get_rect()),
		"contact bounds cover chassis, wheels and installed upper bell"
	)
	for side: int in [-1, 1]:
		encounter.direction = side
		for mode: StringName in [
			&"observe",
			&"approach",
			&"roll_warning",
			&"roll",
			&"combo_brake",
			&"combo_turn",
			&"combo_warning",
			&"ring_warning",
			&"rings",
			&"lob_aim",
			&"lob_lock",
			&"lob",
			&"neck",
			&"phase_transition"
		]:
			encounter._enter(mode, 2.0)
			encounter.physics_tick(.04)
			var pose := encounter.rig_pose()
			var expected: Transform2D = pose.bell_transform
			check(
				encounter._core.transform.is_equal_approx(expected),
				"real weak Area and rig match %s facing %d" % [mode, side]
			)
			check(
				encounter._core.collision_layer == 4,
				"upper bell remains damageable in %s facing %d" % [mode, side]
			)
	await fixture()
	# Ground-near, elevated, and camping preferences are relative weights, while
	# all selections remain variable and have a hard consecutive-group bound.
	target.position = Vector2(770, 582)
	var near := encounter.selection_weights()
	check(float(near[&"ring"]) > float(near[&"roll"]), "near-ground weighting favours ring")
	target.position.y = 440
	var high := encounter.selection_weights()
	check(float(high[&"lob"]) > float(high[&"ring"]), "high-ground weighting favours launcher")
	encounter._camp_age = definition.camping_seconds + .1
	check(
		float(encounter.selection_weights()[&"lob"]) > float(high[&"lob"]),
		"fixed standing increases launcher weight"
	)
	target.position = Vector2(640, 582)
	check(
		float(encounter.selection_weights()[&"roll"]) == 0.0,
		"point-blank charge excluded before warning"
	)
	target.position = Vector2(900, 582)
	var previous: StringName = &""
	var repeats := 0
	var types: Dictionary = {}
	for index: int in 80:
		encounter._select_group()
		var kind := StringName(encounter._group.kind)
		repeats = repeats + 1 if kind == previous else 1
		previous = kind
		types[kind] = true
		check(
			repeats <= definition.max_group_repeats,
			"selection never exceeds configured consecutive group limit %d" % index
		)
	check(types.size() == 3, "persistent selector retains three attack types")
	encounter._clear_attacks()
	encounter._group = {
		"kind": &"roll", "phase": 1, "return_roll": false, "roll_index": 0, "count": 1
	}
	encounter._enter(&"roll_warning", .85)
	var plan := encounter._group.duplicate(true)
	damage(20, &"component-half-health")
	var hits := int(encounter.combat_metrics().accepted_hits)
	encounter.physics_tick(.1)
	check(
		encounter.stage_phase == 1 and encounter._phase_pending and encounter._group == plan,
		"half health queues phase without mutating an announced group"
	)
	var age := encounter._state_age
	damage(1, &"component-extra-hit")
	check(
		(
			encounter._state_age == age
			and encounter.mode == &"roll_warning"
			and encounter._group == plan
		),
		"accepted hit never resets or advances an attack clock"
	)
	check(
		int(encounter.combat_metrics().accepted_hits) == hits + 1,
		"only accepted HP-changing transactions count"
	)
	damage(1, &"component-extra-hit")
	check(
		int(encounter.combat_metrics().accepted_hits) == hits + 1,
		"replayed health request never inflates accepted hits"
	)
	var snapshot := encounter.combat_snapshot()
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	encounter._select_group()
	var next_plan := encounter._group.duplicate(true)
	encounter.restore_combat_state(roundtrip)
	check(
		encounter._group == plan, "JSON snapshot restores the announced group without reselecting"
	)
	encounter._select_group()
	check(
		encounter._group == next_plan, "JSON RNG state restores the exact next weighted selection"
	)
	# Lock is fixed despite player movement; second lob owns another aim+lock.
	encounter._group = {"kind": &"lob", "phase": 2, "return_roll": false, "count": 2}
	encounter.volley = 0
	encounter._enter(&"lob_aim", .01)
	encounter.physics_tick(.02)
	var landing := encounter.locked_point
	target.position.x -= 120
	encounter.physics_tick(.1)
	check(
		encounter.mode == &"lob_lock" and encounter.locked_point == landing,
		"locked .35-second launch does not retarget"
	)
	encounter.physics_tick(.3)
	check(
		encounter.mode == &"lob" and encounter.volley == 1,
		"one release follows first independent lock"
	)
	encounter.physics_tick(
		encounter.lob_duration_for(encounter.locked_point) + definition.lob_followup_seconds + .01
	)
	check(
		encounter.mode == &"lob_aim" and encounter.volley == 1,
		"second lob starts a new visible aim stage"
	)
	# A real swept bell physically hits an elevated platform once. Its impact
	# callback is observed; this does not synthesize a player hit or reward.
	encounter._clear_attacks()
	var platform := StaticBody2D.new()
	platform.position = Vector2(820, 450)
	var platform_shape := CollisionShape2D.new()
	var platform_rectangle := RectangleShape2D.new()
	platform_rectangle.size = Vector2(180, 20)
	platform_shape.shape = platform_rectangle
	platform.add_child(platform_shape)
	world.add_child(platform)
	await frames(2)
	var bell := BellstriderBellProjectile.new()
	bell.configure(definition, &"component-physical-lob", Vector2.RIGHT, target, boss)
	bell.bind_attack(encounter, encounter.attack_epoch)
	bell.gravity = definition.lob_gravity
	bell.lifetime = 2.0
	world.add_child(bell)
	bell.global_position = Vector2(620, 500)
	bell.aim_landing(Vector2(820, 440), definition.lob_flight_seconds)
	impacts = 0
	var actual_impact := {"point": Vector2.ZERO}
	bell.impacted.connect(
		func(point: Vector2, _normal: Vector2) -> void:
			impacts += 1
			actual_impact.point = point
	)
	await frames(ceili((definition.lob_flight_seconds + .25) * 60.0))
	check(impacts == 1, "ballistic sweep has exactly one physical surface impact")
	check(
		absf((actual_impact.point as Vector2).y - 440) < 2.0,
		"impact uses real raised support rather than nominal arena floor"
	)
	# Owner epoch invalidation cancels before a delayed physical projectile can
	# emit hit or impact, including its frozen-contact entry point.
	var stale := BellstriderBellProjectile.new()
	stale.configure(definition, &"component-stale-lob", Vector2.LEFT, target, boss)
	stale.bind_attack(encounter, encounter.attack_epoch)
	world.add_child(stale)
	stale.global_position = target.global_position
	var count_before := player_contacts
	stale.hit.connect(
		func(_body: Node2D, _id: StringName, _amount: float) -> void: player_contacts += 1
	)
	encounter.cancel_pending_attacks()
	stale.advance_frozen_contact()
	check(
		stale.spent and player_contacts == count_before,
		"cancelled owner epoch cannot hit during frozen contact"
	)
	# Terminal physics remains alive only for the bounded wreck sequence.
	encounter._on_defeat()
	check(
		(
			not encounter.active
			and not encounter.body_contact_enabled()
			and encounter._core.collision_layer == 0
		),
		"defeat disables attack, contact and upper bell immediately"
	)
	encounter.physics_tick(definition.reward_impact_seconds)
	var metrics := encounter.combat_metrics()
	check(
		float(metrics.death_age) >= definition.reward_impact_seconds,
		"inactive defeat still advances the encounter-owned death clock"
	)
	encounter.physics_tick(1.0)
	encounter.physics_tick(2.0)
	var events: Array = encounter.combat_metrics().events
	check(
		(
			(
				events
				. filter(
					func(row: Dictionary) -> bool: return row.event == &"bellstrider_death_impact"
				)
				. size()
			)
			== 1
		),
		"main wreck impact emitted exactly once"
	)
	check(
		(
			(
				events
				. filter(
					func(row: Dictionary) -> bool: return row.event == &"bellstrider_death_final"
				)
				. size()
			)
			== 1
		),
		"final disabled wreck emitted exactly once"
	)
	check(
		is_equal_approx(encounter._death_age, definition.death_seconds),
		"death clock clamps to final wreck pose"
	)
	await far_approach_case()
	await half_health_during_chase()
	for side: int in [-1, 1]:
		await hull_case(side)
		await high_arc_case(side, true)
		await high_arc_case(side, false)
	encounter.cancel()
	await AUDIO_TEARDOWN.drain_world(world)
	world.free()
	print("BELLSTRIDER_REWORK_COMBAT assertions=", assertions, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
