extends SceneTree
## Formal map2/App consumers with explicit initial positioning and stationary
## Boss/recovery fixtures. Ordinary Router shots, real projectiles, original
## FramePolicy/health/Motor are used. Not natural traversal or whole-battle proof.
const TEARDOWN := preload("res://tests/audio_teardown.gd")
var assertions := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var app: Variant
var encounter: Variant
var manifest := ""
var player_damage: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var spawned: Array[Dictionary] = []

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
			check(JSON.stringify(app.stage.generated.manifest) == manifest, "controlled App cases preserve formal generated Manifest")
		app.abandon_run()
		check(await TEARDOWN.drain_world(app), "formal App audio/world drains")
		app.free()
	app = null
	encounter = null
	await ticks(2)

func relocate(point: Vector2, label: String) -> void:
	app.lifetime.invalidate_actor()
	app.controller.router.clear("windkeeper_pressure_explicit_initial_position")
	app.controller.router.activate_device(&"keyboard_mouse")
	app.player.reset_at(point)
	observations.append({"fixture": label, "initial_position": point, "actor_epoch": app.lifetime.actor_epoch, "tick": Engine.get_physics_frames()})

func record_batch(batch: Array[DamageResult]) -> void:
	for result: DamageResult in batch:
		if result.request.target_id == &"player":
			player_damage.append({"source": String(result.request.source_id), "event": String(result.request.event_id), "HP_lost": result.hp_lost, "direction": result.request.hit_direction, "tick": Engine.get_physics_frames()})

func setup() -> bool:
	await cleanup()
	player_damage.clear()
	shots.clear()
	spawned.clear()
	app = load("res://game/application/demo_app.gd").new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_debug_region(&"plains", 2, "windkeeper-pressure-formal-01"), "declared map2 debug entry uses actual App formal stage factory")
	for index: int in 3600:
		if not app._stage_pending and app.stage is PlainsRegionStage and app.stage.assembly_ok and app._can_interact(): break
		await ticks(1)
	check(not app._stage_pending and app.stage is PlainsRegionStage and app.stage.assembly_ok, "formal map2 assembles with unchanged generator")
	if app._stage_pending or not app.stage is PlainsRegionStage or not app.stage.assembly_ok: return false
	check(app.stage.map_index == 2 and app.director.region_map_index == 2, "actual stage and director both identify Plains map2")
	manifest = JSON.stringify(app.stage.generated.manifest)
	encounter = app.stage.boss.get_node("Encounter")
	check(encounter.get_script().resource_path == "res://game/bosses/windkeeper/windkeeper_pressure_encounter.gd", "formal BossFactory route instantiates current pressure encounter")
	check(encounter.definition.resource_path == "res://resources/bosses/windkeeper_storm.tres", "formal consumer retains authoritative storm Definition entry")
	check(encounter.health.capacity == 60 and encounter.health.current == 60, "formal current resource starts requested60HP")
	var boss: BossMotor = app.stage.boss
	var x := boss.global_position.x - 230.0
	var query := PhysicsRayQueryParameters2D.create(Vector2(x, boss.global_position.y + 25), Vector2(x, boss.global_position.y + 230), 1, [app.player.get_rid()])
	var support: Dictionary = app.player.get_world_2d().direct_space_state.intersect_ray(query)
	check(not support.is_empty(), "explicit initial counter position has actual map support")
	if support.is_empty(): return false
	relocate((support.position as Vector2) - Vector2(0, 18), "actual map2 arena entry on unchanged ground")
	await ticks(3)
	check(app.player.is_on_floor(), "real PlayerMotor settles on actual support")
	check(app._boss_started and encounter.active and app._in_boss_core(), "ordinary arena entry starts current formal encounter")
	if not app._boss_started or not encounter.active: return false
	for index: int in 360:
		if encounter.mode != &"intro": break
		await ticks(1)
	check(encounter.mode != &"intro" and encounter.accepts_combat_damage(), "actual original intro finishes without HP/clock injection")
	encounter.cancel_pending_attacks()
	encounter.set_physics_process(false)
	check(app.policy.player_clock() >= app.policy._protected_until, "hurt test begins after unchanged spawn immunity")
	app.policy.batch_resolved.connect(record_batch)
	app.controller.shoot_ability.shot_fired.connect(func(direction: Vector2, shot_id: int) -> void:
		shots.append({"id": shot_id, "direction": direction, "tick": Engine.get_physics_frames(), "position": app.player.global_position, "mode": String(encounter.mode), "Boss_HP": encounter.health.current, "grounded": app.player.is_on_floor()}))
	encounter.projectile_created.connect(func(projectile: BossProjectile) -> void:
		spawned.append({"event": String(projectile.event_id), "mode": String(encounter.mode), "tick": Engine.get_physics_frames()}))
	return true

func aim_direction() -> Vector2:
	var target: Vector2 = app.stage.boss.global_position + encounter.core_offset()
	var pointer: Vector2 = app.player.get_canvas_transform() * target
	return app.player.get_node("KeyboardMouseAdapter").world_direction(pointer)

func fire_once(label: String) -> void:
	check(app.controller.router.request_action(&"shoot_release", aim_direction()), "real Router accepts " + label)
	await ticks(2)

func two_shot_recovery() -> void:
	if not await setup(): return
	# Explicit completed-group fixture. From here the actual Encounter clock and
	# all Player input/projectile/resource/motion processing run normally.
	encounter._enter(&"recover", encounter._config().group_recovery_seconds)
	encounter.set_physics_process(true)
	var start := Engine.get_physics_frames()
	var hp: float = encounter.health.current
	var player_hp: float = app.controller.actor_resources.health.current
	var player_start: Vector2 = app.player.global_position
	var recoil_samples: Array[Dictionary] = []
	await ticks(5)
	await fire_once("first ordinary counter shot")
	check(shots.size() == 1, "first input becomes an actual weapon shot")
	recoil_samples.append({"tick": Engine.get_physics_frames(), "position": app.player.global_position, "recoil_remaining": app.player.recoil_burst_remaining, "recoil_velocity": app.player.recoil_velocity})
	check(app.player.recoil_burst_remaining > 0 and app.player.recoil_velocity.length() > 0, "first counter shot produces actual original Motor recoil")
	var clock_after_first: float = encounter.clock
	await ticks(18)
	await fire_once("second ordinary counter shot")
	check(shots.size() == 2, "second input becomes an actual weapon shot")
	recoil_samples.append({"tick": Engine.get_physics_frames(), "position": app.player.global_position, "recoil_remaining": app.player.recoil_burst_remaining, "recoil_velocity": app.player.recoil_velocity})
	check(app.player.recoil_burst_remaining > 0 and app.player.recoil_velocity.length() > 0, "second counter shot also produces actual original Motor recoil")
	check(encounter.mode == &"recover" and encounter.clock < clock_after_first, "ordinary counter hits do not restart recovery or change current action")
	app.controller.router.set_source_axis(&"keyboard_mouse", -1)
	for index: int in 60:
		await ticks(1)
		if encounter.mode != &"recover": break
	app.controller.router.set_source_axis(&"keyboard_mouse", 0)
	check(shots.size() == 2 and shots.all(func(row: Dictionary) -> bool: return row.mode == "recover"), "two actual shots are fired in the declared recovery")
	check(encounter.health.current <= hp - 2, "two real base projectiles remove actual Boss HP through formal damage routing")
	check(app.player.global_position.x < player_start.x - 30, "two actual recoil motions and normal withdrawal move player away")
	check(app.controller.actor_resources.health.current == player_hp, "controlled two-shot-and-withdrawal run does not debit player health")
	var unsafe_releases := spawned.filter(func(row: Dictionary) -> bool: return row.mode == "recover")
	check(unsafe_releases.is_empty(), "declared recovery never releases fresh unannounced attacks")
	observations.append({"case": "controlled actual two-shot recovery", "start_tick": start, "end_tick": Engine.get_physics_frames(), "shots": shots.duplicate(true), "recoil": recoil_samples, "player_start": player_start, "player_end": app.player.global_position, "HP_before": hp, "HP_after": encounter.health.current, "spawned": spawned.duplicate(true), "scope": "actual shots/recoil/withdrawal in explicit recovery fixture; does not establish full natural dodging or third-shot risk"})

func physical_projectile_hurt() -> void:
	if not await setup(): return
	# Disclosed entity fixture, physical flight and the production App callback.
	# No hit emission, player HP debit or direct damage submission is invoked.
	var shot := WindkeeperPressureProjectile.new()
	shot.configure(encounter.definition, &"windkeeper-pressure/formal-physical-seed", Vector2.RIGHT, app.player, app.stage.boss)
	shot.bind_attack(encounter, encounter.attack_epoch)
	shot.speed = encounter._config().seed_speed
	shot.lifetime = 2
	app._boss_projectile_created(shot)
	app.stage.add_child(shot)
	shot.global_position = app.player.global_position - Vector2(90, 0)
	var hp: float = app.controller.actor_resources.health.current
	for index: int in 40:
		await ticks(1)
		if not player_damage.is_empty(): break
	check(player_damage.size() == 1 and app.controller.actor_resources.health.current == hp - 1, "real flying seed commits one HP through actual App")
	check(not player_damage.is_empty() and player_damage[0].source == "boss_projectile" and player_damage[0].event == "windkeeper-pressure/formal-physical-seed", "formal accepted request retains actual projectile event and source")
	check(app.player.damage_remaining > 0, "accepted physical seed starts actual Motor hurt response")
	observations.append({"case": "formal real projectile hurt", "HP_before": hp, "HP_after": app.controller.actor_resources.health.current, "results": player_damage.duplicate(true), "hurt_remaining": app.player.damage_remaining})

func bridge_transition_escape() -> void:
	if not await setup(): return
	var arena_consumer: WindkeeperArena
	for child: Node in encounter.get_children():
		if child is WindkeeperArena: arena_consumer = child as WindkeeperArena
	check(arena_consumer != null and arena_consumer.module.definition.platforms.size() >= 4,
		"formal phase3 owns actual bridge and three existing shelf surfaces")
	if arena_consumer == null or arena_consumer.module.definition.platforms.size() < 4: return
	var slab := Rect2()
	var farthest := -1.0
	for index: int in [1, 2, 3]:
		var candidate: Rect2 = arena_consumer.module.definition.platforms[index]
		var point := arena_consumer.module.to_global(Vector2(candidate.get_center().x, candidate.position.y))
		var gap := absf(point.x - app.stage.boss.global_position.x)
		if gap > farthest: farthest = gap; slab = candidate
	var floor_rect: Rect2 = arena_consumer.module.definition.platforms[0]
	# The new guardian actually mounts a shelf before breaking the bridge.
	# Select a different real shelf for this disclosed ordinary-jump fixture;
	# the former centre-shelf fixture overlapped that real landing and failed
	# with contact then a fall (support-formal-fixture-02.json is retained).
	var local_start := Vector2(slab.end.x - 18, floor_rect.position.y - 18)
	var initial: Vector2 = arena_consumer.module.to_global(local_start)
	relocate(initial, "ground below a real shelf away from the guardian landing before break warning")
	await ticks(3)
	var player_hp: float = app.controller.actor_resources.health.current
	check(app.player.is_on_floor() and not arena_consumer.broken,
		"actual central ground is supported and unbroken before transition")
	check(player_damage.is_empty(), "disclosed initial floor position is outside live Boss contact")
	# Only the Boss phase trigger is a declared authoritative resource fixture.
	# Player HP/resources/abilities and the real transition/break clocks remain.
	var target_hp: float = encounter.health.capacity * encounter._config().phase_three_health - 1
	var request := ActorResourceRequest.new(&"explicit-formal-third-phase-fixture", encounter.health.epoch,
		encounter.health.current - target_hp, encounter.health.get_instance_id())
	check(encounter.health.apply_damage(request).accepted(),
		"explicit phase3 fixture reaches health band through original Boss transaction")
	encounter.set_physics_process(true)
	await ticks(1)
	check(encounter.stage_phase == 3 and encounter.mode == &"phase_transition" and not arena_consumer.broken,
		"real phase3 warning precedes the actual bridge removal")
	app.controller.router.set_jump_held(&"keyboard_mouse", true)
	var reached := false
	var trace: Array[Dictionary] = []
	for index: int in 180:
		await ticks(1)
		var feet: Vector2 = arena_consumer.module.to_local(app.player.global_position) + Vector2(0,18)
		trace.append({"tick": Engine.get_physics_frames(), "position": app.player.global_position,
			"grounded": app.player.is_on_floor(), "feet_local": feet, "broken": arena_consumer.broken,
			"HP": app.controller.actor_resources.health.current, "state": String(encounter.mode)})
		var on_shelf: bool = (app.player.is_on_floor() and absf(feet.y - slab.position.y) < 2
			and feet.x - 12 >= slab.position.x and feet.x + 12 <= slab.end.x)
		if arena_consumer.broken and on_shelf:
			reached = true
			break
	app.controller.router.set_jump_held(&"keyboard_mouse", false)
	check(arena_consumer.broken and reached,
		"one real held jump reaches existing central shelf before ground disappears")
	check(app.controller.jump_ability.used_jumps <= 1,
		"actual escape never requires an ungranted extra jump")
	check(app.controller.actor_resources.health.current == player_hp,
		"actual warning-jump-break sequence does not debit player HP")
	var environment_hits := player_damage.filter(func(row: Dictionary) -> bool:
		return float(row.HP_lost) > 0 and (str(row.source).contains("fall") or str(row.source).contains("bounds")))
	check(environment_hits.is_empty(), "real bridge removal does not force an environment return")
	observations.append({"case": "actual bridge warning escape", "Boss_HP_transaction_fixture": true,
		"initial": initial, "actual_shelf": slab, "reached_after_break": reached, "trace": trace,
		"player_damage": player_damage.duplicate(true), "scope": "controlled phase trigger and initial position; ordinary base held jump, actual WindkeeperArena bridge geometry and original player damage rules"})

func run() -> void:
	await two_shot_recovery()
	await physical_projectile_hurt()
	await bridge_transition_escape()
	await cleanup()
	DirAccess.make_dir_recursive_absolute("res://build/windkeeper_pressure_01")
	var file := FileAccess.open("res://build/windkeeper_pressure_01/formal_app.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"assertions": assertions, "failures": failures, "observations": observations,
		"scope": "actual map2 debug entry and formal App/Factory/Router/projectile/FramePolicy/Motor; disclosed initial positions and completed-group fixture; not natural traversal or complete fight/two-vs-three risk approval"}, "\t"))
	file.close()
	print("WINDKEEPER PRESSURE FORMAL APP: ", assertions, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
