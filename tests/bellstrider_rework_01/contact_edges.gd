extends SceneTree
## Actual DemoApp, Router movement, Motor gravity and automatic frame damage.
## Each boundary has a disclosed initial position/actor epoch. The live Boss AI
## is stopped after its real intro solely to test a stationary vehicle. Phase
## transition is an explicit state fixture. No HP debit, damage submission or
## emitter callback is used to manufacture a hit. This is not a natural fight.
const TEARDOWN := preload("res://tests/audio_teardown.gd")
var app: Variant
var encounter: BellstriderEncounter
var assertions := 0
var failures: Array[String] = []
var contacts: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var manifest := ""


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)


func ticks(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame


func cleanup() -> void:
	paused = false
	if is_instance_valid(app):
		if is_instance_valid(app.stage) and app.stage is PlainsRegionStage:
			check(
				JSON.stringify(app.stage.generated.manifest) == manifest,
				"contact fixture preserves the original generated Manifest"
			)
		app.abandon_run()
		check(await TEARDOWN.drain_world(app), "contact fixture releases original App audio")
		app.free()
	app = null
	encounter = null
	await ticks(2)


func relocate(point: Vector2, label: String) -> void:
	app.lifetime.invalidate_actor()
	app.controller.router.clear("bellstrider_contact_initial_position")
	app.controller.router.activate_device(&"keyboard_mouse")
	app.player.reset_at(point)
	observations.append(
		{
			"fixture": label,
			"point": point,
			"actor_epoch": app.lifetime.actor_epoch,
			"tick": Engine.get_physics_frames()
		}
	)


func axis(value: float) -> void:
	app.controller.router.set_source_axis(&"keyboard_mouse", value)


func actor_rect() -> Rect2:
	var collision := app.player.get_node("CollisionShape2D") as CollisionShape2D
	return collision.global_transform * collision.shape.get_rect()


func floor_point(x: float) -> Vector2:
	var boss: BossMotor = app.stage.boss
	var query := PhysicsRayQueryParameters2D.create(
		Vector2(x, boss.global_position.y + 50),
		Vector2(x, boss.global_position.y + 260),
		1,
		[app.player.get_rid()]
	)
	var hit := boss.get_world_2d().direct_space_state.intersect_ray(query)
	check(
		not hit.is_empty() and (hit.get("normal", Vector2.ZERO) as Vector2).dot(Vector2.UP) > .7,
		"initial ground position has actual unchanged floor support"
	)
	return hit.get("position", Vector2.INF)


func record_batch(results: Array[DamageResult]) -> void:
	for result: DamageResult in results:
		if (
			result.request.target_id != &"player"
			or result.request.source_id != &"boss_contact"
			or result.hp_lost <= 0
		):
			continue
		var legacy := (
			encounter._contact_shape.global_transform * encounter._contact_shape.shape.get_rect()
		)
		contacts.append(
			{
				"tick": Engine.get_physics_frames(),
				"HP_lost": result.hp_lost,
				"position": app.player.global_position,
				"actor_bounds": actor_rect(),
				"outside_legacy": not actor_rect().intersects(legacy),
				"mode": String(encounter.mode),
				"kind": int(result.request.kind),
				"source": String(result.request.source_id),
				"event": String(result.request.event_id)
			}
		)


func setup(wait_intro: bool = true) -> bool:
	await cleanup()
	contacts.clear()
	app = load("res://scripts/demo/demo_app.gd").new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(
		app.start_plains("level-design-v2-baseline/08"),
		"actual App starts the formal map for contact"
	)
	for index: int in 3600:
		if not app._stage_pending and app.stage is PlainsRegionStage and app.stage.assembly_ok:
			break
		await ticks(1)
	check(
		not app._stage_pending and app.stage is PlainsRegionStage and app.stage.assembly_ok,
		"actual formal stage assembles for contact"
	)
	if app._stage_pending or not app.stage is PlainsRegionStage or not app.stage.assembly_ok:
		return false
	manifest = JSON.stringify(app.stage.generated.manifest)
	encounter = app.stage.boss.get_node("Encounter") as BellstriderEncounter
	check(
		encounter != null and app._boss_contact.contact_test_provider.is_valid(),
		"actual App binds Bell-only precise contact admission"
	)
	if encounter == null:
		return false
	app.policy.batch_resolved.connect(record_batch)
	var boss: BossMotor = app.stage.boss
	var ground := floor_point(boss.global_position.x - 170.0)
	if not ground.is_finite():
		return false
	relocate(ground - Vector2(0, 18), "actual arena entry before stationary contact fixture")
	await ticks(2)
	check(
		app._boss_started and encounter.active,
		"actual room entry starts the original Boss encounter"
	)
	if wait_intro:
		for index: int in 300:
			if encounter.mode != &"intro":
				break
			await ticks(1)
		check(
			encounter.accepts_combat_damage() and encounter.mode != &"intro",
			"original intro finishes without HP or clock injection"
		)
		encounter.cancel_pending_attacks()
		encounter.set_physics_process(false)
		check(
			app.policy.player_clock() >= app.policy._protected_until,
			"stationary contact samples start after unchanged spawn immunity"
		)
	return true


func ground_side(side: int, phase: bool = false) -> void:
	if not await setup():
		return
	if phase:
		encounter._enter(
			&"phase_transition",
			(encounter.definition as BellstriderDefinition).phase_warning_seconds
		)
		encounter._update_combat_shapes()
	var bounds := encounter.body_contact_rect()
	var x := bounds.position.x - 28.0 if side < 0 else bounds.end.x + 28.0
	var ground := floor_point(x)
	if not ground.is_finite():
		return
	relocate(ground - Vector2(0, 18), "outside %s wheel before Router approach" % side)
	await ticks(2)
	var hp: float = app.controller.actor_resources.health.current
	check(contacts.is_empty(), "standing outside the real wheel does not hurt")
	axis(-float(side))
	for index: int in 45:
		await ticks(1)
		if not contacts.is_empty():
			break
	axis(0)
	check(
		contacts.size() == 1 and app.controller.actor_resources.health.current == hp - 1.0,
		"actual Router movement into stationary vehicle commits one contact hit"
	)
	check(
		not contacts.is_empty() and bool(contacts[0].outside_legacy),
		"actual outer-wheel contact hurts before the old narrow rectangle overlaps"
	)
	check(
		(
			not contacts.is_empty()
			and int(contacts[0].kind) == DamageRequest.Kind.MONSTER
			and str(contacts[0].source) == "boss_contact"
		),
		"wheel hit retains the original App monster-contact policy route"
	)
	if phase:
		check(
			(
				encounter.body_contact_enabled()
				and not contacts.is_empty()
				and contacts[0].mode == "phase_transition"
			),
			"real copper contact remains dangerous during phase pressure transition"
		)
	observations.append(
		{
			"case": "ground side",
			"side": side,
			"phase_fixture": phase,
			"contacts": contacts.duplicate(true)
		}
	)


func roof() -> void:
	if not await setup():
		return
	var boss: BossMotor = app.stage.boss
	relocate(
		boss.global_position + Vector2(0, -85),
		"fall through clear bell/mast space toward chassis roof"
	)
	var hp: float = app.controller.actor_resources.health.current
	axis(0)
	await ticks(8)
	check(
		contacts.is_empty() and app.controller.actor_resources.health.current == hp,
		"clear bell and mast space does not deal body contact damage"
	)
	for index: int in 30:
		await ticks(1)
		if not contacts.is_empty():
			break
	check(
		contacts.size() == 1 and app.controller.actor_resources.health.current == hp - 1.0,
		"actual Motor fall onto copper roof commits one body contact hit"
	)
	check(
		not contacts.is_empty() and bool(contacts[0].outside_legacy),
		"roof contact hurts above the old contact rectangle"
	)
	observations.append({"case": "roof fall", "contacts": contacts.duplicate(true)})


func bevel_air() -> void:
	if not await setup():
		return
	var boss: BossMotor = app.stage.boss
	# At this corner the actor rectangle touches the broad AABB but clears the
	# real bevel and wheel. Run outward immediately; gravity remains real.
	relocate(boss.global_position + Vector2(-80, -20), "clear outer bevel corner")
	check(
		actor_rect().intersects(encounter.body_contact_rect()),
		"bevel negative actually overlaps broad contact bounds"
	)
	var origin: Vector2 = app._boss_contact.global_position
	var position: Vector2 = app.player.global_position
	check(
		not encounter.body_contact_sweep(origin, position - origin, position, Vector2(12, 18)),
		"precise copper geometry rejects the empty bevel corner"
	)
	var hp: float = app.controller.actor_resources.health.current
	axis(-1)
	await ticks(20)
	axis(0)
	check(
		contacts.is_empty() and app.controller.actor_resources.health.current == hp,
		"actual Router retreat through bevel air never submits contact damage"
	)


func inactive_or_intro(intro: bool) -> void:
	if not await setup(not intro):
		return
	var boss: BossMotor = app.stage.boss
	if not intro:
		encounter.cancel()
	var hp: float = app.controller.actor_resources.health.current
	axis(1)
	await ticks(39)
	axis(0)
	await ticks(6)
	check(
		absf(app.player.global_position.x - boss.global_position.x) < 45.0,
		"negative contact case actually walks inside the vehicle footprint"
	)
	check(
		(
			not encounter.body_contact_enabled()
			and contacts.is_empty()
			and app.controller.actor_resources.health.current == hp
		),
		"intro or inactive copper cannot hurt the real moving player"
	)
	if intro:
		check(
			encounter.mode == &"intro" and app.policy.player_clock() >= app.policy._protected_until,
			"intro exclusion is observed after ordinary spawn protection expires"
		)


func hook_scope() -> void:
	if not await setup():
		return
	check(
		app.controller.traversal.grant(&"grapple"),
		"disclosed real traversal grant enables hook protection fixture"
	)
	var bell: Vector2 = encounter._core.global_position
	relocate(bell + Vector2(-170, 0), "actual Router hook toward the installed bell")
	var direction: Vector2 = (bell - app.player.global_position - Vector2(0, -6)).normalized()
	check(
		app.controller.router.request_action(&"grapple", direction),
		"actual Router accepts the hook input"
	)
	var protected := false
	for index: int in 90:
		await ticks(1)
		if app.controller.traversal.protects_contact(app.stage.boss):
			protected = true
			break
	check(
		protected and app.controller.traversal.hook_target == encounter._core,
		"genuine hook retains canonical own-body contact protection"
	)
	var unrelated := Node2D.new()
	app.stage.add_child(unrelated)
	check(
		not app.controller.traversal.protects_contact(unrelated),
		"genuine own-body hook never protects unrelated contact"
	)
	check(
		contacts.is_empty(),
		"new App contact provider does not introduce an own-body hit during the genuine hook"
	)
	unrelated.queue_free()


func dead_vehicle() -> void:
	if not await setup():
		return
	var boss: BossMotor = app.stage.boss
	var fired := [0]
	app.controller.shoot_ability.shot_fired.connect(
		func(_aim: Vector2, _id: int) -> void: fired[0] += 1
	)
	for shot: int in 40:
		for tick: int in 120:
			var desired := boss.global_position.x - 230.0
			axis(clampf((desired - app.player.global_position.x) / 30.0, -1, 1))
			var energy_ready: bool = (
				app.controller.shot_energy == null or app.controller.shot_energy.can_fire()
			)
			if (
				absf(desired - app.player.global_position.x) < 12.0
				and app.player.is_on_floor()
				and app.controller.shoot_ability.cooldown_remaining <= 0.0
				and energy_ready
			):
				break
			await ticks(1)
		axis(0)
		var hp: float = encounter.health.current
		var point: Vector2 = encounter._core.global_position
		var pointer: Vector2 = app.player.get_canvas_transform() * point
		var direction: Vector2 = app.player.get_node("KeyboardMouseAdapter").world_direction(
			pointer
		)
		check(
			app.controller.router.request_action(&"shoot_release", direction),
			"real Router accepts a base shot for terminal contact fixture"
		)
		for tick: int in 45:
			await ticks(1)
			if encounter.health.current < hp:
				break
		check(
			encounter.health.current == hp - 1.0,
			"terminal fixture uses a real base projectile instead of direct HP debit"
		)
	check(
		encounter.health.terminal and fired[0] == 40,
		"forty actual base shots create the terminal vehicle"
	)
	encounter.set_physics_process(true)
	var player_hp: float = app.controller.actor_resources.health.current
	for tick: int in 90:
		if absf(app.player.global_position.x - boss.global_position.x) < 40.0:
			break
		axis(signf(boss.global_position.x - app.player.global_position.x))
		await ticks(1)
	axis(0)
	check(
		absf(app.player.global_position.x - boss.global_position.x) < 40.0,
		"actual Router movement reaches the dead carriage"
	)
	check(
		(
			not encounter.body_contact_enabled()
			and contacts.is_empty()
			and app.controller.actor_resources.health.current == player_hp
		),
		"actual terminal carriage remains harmless to physical contact"
	)


func run() -> void:
	await ground_side(-1)
	await ground_side(1)
	await ground_side(-1, true)
	await roof()
	await bevel_air()
	await inactive_or_intro(true)
	await inactive_or_intro(false)
	await hook_scope()
	await dead_vehicle()
	await cleanup()
	DirAccess.make_dir_recursive_absolute("res://build/bellstrider_rework_01")
	var file := FileAccess.open(
		"res://build/bellstrider_rework_01/contact_edges.json", FileAccess.WRITE
	)
	file.store_string(
		JSON.stringify(
			{
				"assertions": assertions,
				"failures": failures,
				"observations": observations,
				"scope":
				(
					"actual App contact with normal Router/Motor and automatic frame damage; "
					+ "initial positions, actor epochs, stationary AI and explicit phase state; "
					+ "forty real base shots for death; no direct HP debit or manual emitter tick. "
					+ "Unchanged weapon_routes covers hook projectile/unrelated damage negatives."
				)
			},
			"\t"
		)
	)
	file.close()
	print("BELLSTRIDER_CONTACT_EDGES assertions=", assertions, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
