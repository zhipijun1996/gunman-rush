extends SceneTree
## ENEMY-FEEDBACK-01: real Router -> ShootAbility -> PlayerProjectile swept
## collision -> Damageable -> FrameDamagePolicy -> HealthState consumers.
## Explicit supported arena spawns; this is not a natural campaign traversal,
## GPU/readability assessment, full DemoApp drop flow, or device measurement.
const INSTALLER = preload("res://scripts/underworld_plains/underworld_actor_installer.gd")
const ENEMY = preload("res://scenes/enemies/patrol_drone.tscn")
const PLAYER = preload("res://scenes/player/player.tscn")
const SOURCES := ["res://resources/enemies/plains_charger.tres", "res://resources/enemies/plains_diver.tres"]
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var world: Node2D
var player: PlayerMotor
var controller: PlayerController
var enemy: EnemyMotor
var actor: EnemyActor
var art: Node2D
var policy: FrameDamagePolicy
var audio: GameAudio
var accepted: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var trace: Array[Dictionary] = []

class ClockProbe extends Node:
	var elapsed := 0.0
	var frames := 0
	func _process(delta: float) -> void:
		elapsed += delta
		frames += 1

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func ticks(count: int, phase: String) -> void:
	for _index: int in count:
		await physics_frame
		await process_frame
		if is_instance_valid(actor):
			trace.append({"phase": phase, "physics_tick": Engine.get_physics_frames(), "HP": actor.health.current, "enemy_position": enemy.position, "player_position": player.position, "health_epoch": actor.health.epoch})

func arena() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 400)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4000, 40)
	shape.shape = box
	floor_body.add_child(shape)
	world.add_child(floor_body)

func setup(path: String, underworld: bool) -> void:
	accepted = []
	shots = []
	trace = []
	world = Node2D.new()
	root.add_child(world)
	audio = GameAudio.new()
	world.add_child(audio)
	arena()
	player = PLAYER.instantiate()
	player.position = Vector2(200, 362)
	world.add_child(player)
	controller = player.get_node("Controller") as PlayerController
	player.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	policy = FrameDamagePolicy.new()
	policy.lifetime = DemoLifetime.new()
	world.add_child(policy)
	enemy = ENEMY.instantiate()
	actor = enemy.get_node("Actor") as EnemyActor
	actor.definition = load(path) as EnemyDefinition
	enemy.position = Vector2(330, 364)
	world.add_child(enemy)
	check(policy.bind_damageable(&"feedback_01_enemy", actor.damageable, actor.health), "actual enemy bound to formal batched damage policy")
	actor.bind_encounter(controller, policy, policy.lifetime, &"feedback_01_enemy", [])
	actor.damageable.damaged.connect(func(context: Dictionary) -> void: accepted.append(context.duplicate()))
	controller.shoot_ability.shot_fired.connect(func(direction: Vector2, id: int) -> void:
		shots.append({"physics_tick": Engine.get_physics_frames(), "id": id, "direction": direction, "muzzle": controller.shoot_ability.last_muzzle}))
	art = enemy.get_node("Presentation") as Node2D
	if underworld:
		var previous: WeakRef = weakref(art)
		var listeners := actor.health.changed.get_connections().size()
		var installed: Dictionary = INSTALLER.install(world)
		check(installed.enemies == 1, "formal installer replaces one existing EnemyPresentation")
		art = enemy.get_node("Presentation") as Node2D
		await ticks(2, "installer_replacement")
		check(previous.get_ref() == null, "formal installer releases old presentation")
		check(actor.health.changed.get_connections().size() == listeners, "replacement leaves one shared feedback listener without accumulating listeners")
		check(art is UnderworldEnemy, "actual installer consumes UnderworldEnemy inheritance chain")
	else:
		check(art is EnemyPresentation, "original scene consumes EnemyPresentation inheritance chain")
	check(art.get("feedback_sample") != null, "selected existing enemy owns shared feedback component")
	await ticks(4, "supported_start")
	check(player.is_on_floor(), "actual Motor has collider support before firing")

func shoot_until_health_changes(phase: String) -> bool:
	# Each intent is a real fresh Router action. No HP or projectile parameters,
	# AI, actor positions, energy balance, or feedback methods are modified.
	var before := actor.health.current
	for _attempt: int in 3:
		while controller.shoot_ability.cooldown_remaining > 0 or controller.shoot_ability.rounds_remaining > 0:
			await ticks(1, phase + "_cooldown")
		var direction := (enemy.global_position - player.global_position).normalized()
		controller.router.aim_direction = direction
		controller.router.request_action(&"shoot_release", direction)
		for _frame: int in 36:
			await ticks(1, phase)
			if actor.health.current < before:
				return true
	return false

func rejection_cases() -> void:
	var sample: Variant = art.get("feedback_sample")
	var hit_count := int(sample.accepted_hit_count)
	var death_count := int(sample.accepted_death_count)
	check(not accepted.is_empty(), "real projectile supplies committed damage context")
	if accepted.is_empty():
		return
	var original: Dictionary = accepted[0]
	check(not actor.damageable.receive_damage(original), "same actual projectile event replay rejected")
	var stale := original.duplicate()
	stale.event_id = "feedback_01_stale"
	stale.target_epoch = actor.health.epoch - 1
	check(not actor.damageable.receive_damage(stale), "old target health epoch rejected")
	var friendly := original.duplicate()
	friendly.event_id = "feedback_01_friendly"
	friendly.source_faction = actor.definition.faction
	check(not actor.damageable.receive_damage(friendly), "friendly contact rejected")
	var invalid := original.duplicate()
	invalid.event_id = "feedback_01_nan"
	invalid.amount = NAN
	check(not actor.damageable.receive_damage(invalid), "nonfinite damage rejected")
	var obsolete := DamageRequest.new()
	obsolete.token = policy.lifetime.token()
	obsolete.actor_epoch = policy.lifetime.actor_epoch
	obsolete.health_epoch = actor.health.epoch
	obsolete.target_id = &"feedback_01_enemy"
	obsolete.source_id = &"feedback_01_old_stage"
	obsolete.event_id = &"feedback_01_old_stage"
	policy.lifetime.stage_epoch += 1
	check(not policy.submit(obsolete), "obsolete stage token rejected before HP commit")
	check(int(sample.accepted_hit_count) == hit_count and int(sample.accepted_death_count) == death_count, "all rejected contacts leave feedback counters unchanged")

func pause_feedback(death: bool) -> void:
	var sample: Variant = art.get("feedback_sample")
	var hurt := float(sample.hurt_remaining)
	var elapsed := float(sample.death_elapsed)
	var parent_death := float(art.get("_death")) if art is UnderworldEnemy else -1.0
	paused = true
	for _frame: int in 8:
		await process_frame
	check(float(sample.hurt_remaining) == hurt and float(sample.death_elapsed) == elapsed, "pause freezes shared " + ("death" if death else "hurt") + " clock")
	if art is UnderworldEnemy:
		check(float(art.get("_death")) == parent_death, "pause also preserves inherited read-only death clock")
	paused = false

func slow_time_feedback() -> void:
	# Observe the engine's real process delta alongside presentation. The probe
	# measures simulated seconds, so fixed-FPS scheduling is not treated as a
	# wall-clock/device performance measurement.
	var sample: Variant = art.get("feedback_sample")
	var before := float(sample.hurt_remaining)
	var count := int(sample.accepted_hit_count)
	var probe := ClockProbe.new()
	world.add_child(probe)
	Engine.time_scale = .5
	for _frame: int in 5:
		await process_frame
	var elapsed := probe.elapsed
	var frames := probe.frames
	var after := float(sample.hurt_remaining)
	Engine.time_scale = 1.0
	check(frames > 0 and elapsed > 0 and after > 0, "slow time advances a live bounded hurt through actual process delta")
	check(absf((before - after) - elapsed) < .0001, "shared hurt clock consumes exactly observed scaled engine delta")
	check(int(sample.accepted_hit_count) == count, "changing time scale does not replay accepted hurt")
	trace.append({"phase": "actual_slow_time_process_delta", "scale": .5, "frames": frames, "elapsed": elapsed, "hurt_before": before, "hurt_after": after, "physics_tick": Engine.get_physics_frames()})
	probe.queue_free()

func restored_corpse_case(underworld: bool) -> void:
	var restored: EnemyMotor = ENEMY.instantiate()
	var restored_actor := restored.get_node("Actor") as EnemyActor
	restored_actor.definition = actor.definition
	restored.position = Vector2(800, 364)
	world.add_child(restored)
	check(restored_actor.restore_instance_health(0), "formal restore_instance_health accepts saved dead enemy")
	if underworld:
		INSTALLER.install(world)
	var restored_art := restored.get_node("Presentation") as Node2D
	var sample: Variant = restored_art.get("feedback_sample")
	check(sample != null and sample.restored_terminal, "restored terminal snapshot recognized in selected chain")
	if sample != null:
		check(int(sample.accepted_hit_count) == 0 and int(sample.accepted_death_count) == 0 and not sample.death_active, "saved corpse does not start accepted hurt or death performance")
	await ticks(3, "restored_corpse")
	if sample != null:
		check(not sample.death_active and float(sample.hurt_remaining) == 0, "restored corpse remains silent after normal frame progression")
	restored.queue_free()
	await process_frame
	await process_frame

func one_case(path: String, underworld: bool) -> void:
	await setup(path, underworld)
	var sample: Variant = art.get("feedback_sample")
	if sample == null:
		await cleanup()
		return
	var initial_hp := actor.health.current
	check(await shoot_until_health_changes("projectile_first_hit"), "fresh Router shot causes actual swept projectile accepted HP hit")
	check(actor.health.current == initial_hp - 1, "first actual projectile commits original configured one damage")
	check(int(sample.accepted_hit_count) == 1 and int(sample.accepted_death_count) == 0, "one nonlethal accepted hit produces exactly one shared hurt")
	check(float(sample.hurt_remaining) > 0, "real accepted hit starts bounded shared hurt clock")
	rejection_cases()
	await pause_feedback(false)
	await slow_time_feedback()
	await ticks(40, "hurt_recovery")
	check(float(sample.hurt_remaining) == 0, "hurt clock recovers without another accepted event")
	for _hit: int in ceili(initial_hp) - 1:
		check(await shoot_until_health_changes("projectile_followup"), "further real projectile commits accepted damage")
	check(actor.health.terminal, "real projectiles reach actual terminal HP")
	check(int(sample.accepted_hit_count) == ceili(initial_hp) - 1 and int(sample.accepted_death_count) == 1, "lethal accepted hit has one death and no extra ordinary hurt")
	check(sample.death_active, "real lethal result starts shared death performance")
	await pause_feedback(true)
	var before_count := accepted.size()
	if not accepted.is_empty():
		check(not actor.damageable.receive_damage(accepted.back()), "actual lethal event cannot damage terminal enemy again")
	await ticks(45, "death_recovery")
	check(int(sample.accepted_death_count) == 1 and accepted.size() == before_count, "terminal actor never repeats death or accepted damage")
	var drops := EnemyDropService.new()
	check(drops.configure("enemy-feedback-01", "supported_arena"), "existing formal drop service uses unchanged production config")
	var settled := drops.settle(&"feedback_01_enemy")
	check(not settled.is_empty() and drops.settle(&"feedback_01_enemy").is_empty(), "existing drop ledger settles actual dead enemy identity once")
	await restored_corpse_case(underworld)
	cases.append({"definition": path, "chain": "UnderworldEnemy/PixelPlainsEnemy/WindchimeEnemyVisual" if underworld else "EnemyPresentation", "shots": shots.duplicate(true), "accepted_contexts": accepted.duplicate(true), "trace": trace.duplicate(true), "hurt_count": sample.accepted_hit_count, "death_count": sample.accepted_death_count, "drop": settled, "scope": "actual scene and installer consumers in explicit arena; drop ledger only, not DemoApp settlement integration"})
	var component_weak: WeakRef = weakref(sample)
	sample = null
	await cleanup()
	check(component_weak.get_ref() == null, "unload releases shared component and its HealthState signal ownership")

func cleanup() -> void:
	Engine.time_scale = 1.0
	paused = false
	if is_instance_valid(controller):
		controller.shoot_ability.clear_projectiles()
	check(await audio.shutdown(), "actual bounded audio backend teardown releases playbacks")
	world.queue_free()
	await process_frame
	await process_frame

func run() -> void:
	for path: String in SOURCES:
		for underworld: bool in [false, true]:
			await one_case(path, underworld)
	var output := {"task": "ENEMY-FEEDBACK-01", "checks": checks, "failures": failures, "cases": cases, "scope": "real Router/projectiles and original scenes/formal installer; explicit supported arena, not campaign/GPU/device", "not_verified": ["full DemoApp drop persistence and restart", "natural campaign traversal", "same-instance parent death-clock reset", "visual readability", "device performance"]}
	DirAccess.make_dir_recursive_absolute("res://build/enemy_feedback_01")
	var file := FileAccess.open("res://build/enemy_feedback_01/runtime.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print("ENEMY_FEEDBACK_01 checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
