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
var peer: EnemyMotor
var peer_art: UnderworldEnemy
var shared_source_hashes: Dictionary = {}
const SHARED_SOURCE_PATHS := [
	"res://assets/underworld_plains/actors/charger.png",
	"res://assets/underworld_plains/actors/aerial.png",
	"res://scripts/art_foundation/pixel_plains_enemy.gd",
	"res://scripts/art_foundation/windchime_enemy_visual.gd",
	"res://shaders/plains_tile_material.gdshader",
	"res://shaders/pixel_formal_terrain.gdshader",
]

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
	peer = null
	peer_art = null
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
		# A second actual enemy uses its own body material. It receives no fake
		# damage; the first target's real projectile must never flash this peer.
		peer = ENEMY.instantiate()
		(peer.get_node("Actor") as EnemyActor).definition = actor.definition
		peer.position = Vector2(-900, 364)
		world.add_child(peer)
		INSTALLER.install(world)
		peer_art = peer.get_node("Presentation") as UnderworldEnemy
		var target_art := art as UnderworldEnemy
		check(target_art.feedback_body != null and peer_art.feedback_body != null, "both actual selected Underworld instances own body-only flash consumers")
		check(target_art.feedback_body.flash_material != peer_art.feedback_body.flash_material, "actual body ShaderMaterials are distinct per instance")
		check(target_art.feedback_body.flash_material.resource_path.is_empty() and peer_art.feedback_body.flash_material.resource_path.is_empty(), "body flash uses local material instances rather than a shared material resource")
		check(target_art.material == null and peer_art.material == null, "flash material stays on body child, outside telegraphs and health marks")
	else:
		check(art is EnemyPresentation, "original scene consumes EnemyPresentation inheritance chain")
	check(art.get("feedback_sample") != null, "selected existing enemy owns shared feedback component")
	check(art.get("feedback_particles") != null, "both selected inheritance chains own accepted-contact pixel particles")
	check(art.get("feedback_remains") != null, "both selected inheritance chains own lifecycle-bound remains consumer")
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
	var particles := art.get("feedback_particles") as EnemyFeedback01Particles
	var emitted := particles.emitted_bursts
	var serial := int(sample.impact_serial)
	var flash := float(sample.impact_remaining)
	var remains: Variant = art.get("feedback_remains")
	var remains_starts := int(remains.accepted_starts)
	var remains_active := bool(remains.active)
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
	check(particles.emitted_bursts == emitted and int(sample.impact_serial) == serial and float(sample.impact_remaining) == flash, "replay, invalid contacts and old epochs cannot emit particles or restart flash")
	check(int(remains.accepted_starts) == remains_starts and bool(remains.active) == remains_active, "replayed and old-epoch contacts cannot start or duplicate remains")

func pause_feedback(death: bool) -> void:
	var sample: Variant = art.get("feedback_sample")
	var hurt := float(sample.hurt_remaining)
	var elapsed := float(sample.death_elapsed)
	var flash := float(sample.impact_remaining)
	var particles := art.get("feedback_particles") as EnemyFeedback01Particles
	var bursts_before := JSON.stringify(particles._bursts)
	var emitted := particles.emitted_bursts
	var remains: Variant = art.get("feedback_remains")
	var remains_before := remains_snapshot(remains)
	check(particles.active_bursts() > 0, "actual accepted contact has live pixel particles before pause")
	var parent_death := float(art.get("_death")) if art is UnderworldEnemy else -1.0
	paused = true
	for _frame: int in 8:
		await process_frame
	check(float(sample.hurt_remaining) == hurt and float(sample.death_elapsed) == elapsed, "pause freezes shared " + ("death" if death else "hurt") + " clock")
	check(float(sample.impact_remaining) == flash and JSON.stringify(particles._bursts) == bursts_before and particles.emitted_bursts == emitted, "pause freezes actual particle ages and impact flash without another burst")
	check(remains_snapshot(remains) == remains_before, "pause freezes remains age, phase and visual transform during accepted feedback")
	if art is UnderworldEnemy:
		check(float(art.get("_death")) == parent_death, "pause also preserves inherited read-only death clock")
	paused = false

func verify_body_flash_from_actual_hit() -> void:
	if not art is UnderworldEnemy:
		return
	# Body parameters synchronize in _process, whereas HP and particle receipts
	# commit in the physics damage batch. Observe a real following process frame.
	await process_frame
	var target_art := art as UnderworldEnemy
	var sample := target_art.feedback_sample
	check(target_art.feedback_body.material == target_art.feedback_body.flash_material, "actual Underworld body consumes its local ShaderMaterial")
	var actual_flash := float(target_art.feedback_body.flash_material.get_shader_parameter("hit_flash"))
	check(actual_flash > 0 and is_equal_approx(actual_flash, sample.flash_strength()), "actual accepted hit reaches body shader hit_flash in following process frame")
	check(peer_art.feedback_sample.impact_serial == 0 and float(peer_art.feedback_body.flash_material.get_shader_parameter("hit_flash")) == 0, "other actual enemy material remains unflashed by target's accepted projectile")

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

func remains_snapshot(remains: Variant) -> Dictionary:
	return {"active": bool(remains.active), "settled": bool(remains.settled), "restored": bool(remains.restored), "age": float(remains.age), "phase": str(remains.phase), "position": remains.global_position, "rotation": remains.rotation, "scale": remains.scale, "visible": remains.visible, "starts": int(remains.accepted_starts)}

func active_remains_in(stage_node: Node) -> int:
	var count := 0
	for child: Node in stage_node.get_children():
		if child is EnemyFeedback01Remains and child.active:
			count += 1
	return count

func bounded_real_death_case(remains: Variant, _lethal_position: Vector2) -> void:
	# v5 explicitly replaces the rejected persistent-corpse contract. The real
	# lethal event was observed active above; after normal recovery it is spent.
	check(not remains.active and not remains.visible and remains.settled and remains.phase == &"spent" and int(remains.accepted_starts) == 1, "one real accepted explosion finishes inside the normal recovery window")
	check(remains.get_parent() == world and remains.get_parent() != art, "short death effect remains independent from inherited presentation visibility")
	check(active_remains_in(world) == 0, "spent explosion leaves no persistent corpse or active stage effect")
	check(remains.find_children("*", "CollisionObject2D", true, false).is_empty(), "short death explosion creates no gameplay collision object")
	var clock := ClockProbe.new()
	world.add_child(clock)
	await ticks(75, "spent_explosion_stays_absent_over_one_second")
	check(clock.elapsed > 1 and not remains.active and not remains.visible and remains.phase == &"spent", "accepted explosion stays absent after more than one real scaled process second")
	if art is UnderworldEnemy:
		check(float(art.get("_death")) >= .65 and not art.visible, "inherited parent death clock and .65 second visibility remain authoritative")
	var frozen := remains_snapshot(remains)
	paused = true
	for _frame: int in 8: await process_frame
	check(remains_snapshot(remains) == frozen and not remains.visible, "spent death effect stays absent during pause")
	paused = false
	var starts := int(remains.accepted_starts)
	if not accepted.is_empty():
		check(not actor.damageable.receive_damage(accepted.back()), "spent explosion rejects actual lethal context replay")
	check(active_remains_in(world) == 0 and int(remains.accepted_starts) == starts, "terminal replay cannot restart explosion or create persistent remains")
	trace.append({"phase": "bounded_actual_death_explosion", "observed_seconds": clock.elapsed, "effect": remains_snapshot(remains), "physics_tick": Engine.get_physics_frames()})
	clock.queue_free()

func installer_dead_remains_case() -> void:
	# Independent actual scene fixture limits the installer to this stage. Saved
	# terminal initialization is a reconstruction test, never projectile evidence.
	var fixture := Node2D.new()
	world.add_child(fixture)
	var body: EnemyMotor = ENEMY.instantiate()
	var owner := body.get_node("Actor") as EnemyActor
	owner.definition = actor.definition
	body.position = Vector2(1250, 364)
	fixture.add_child(body)
	check(owner.restore_instance_health(0), "installer fixture restores a real saved dead actor")
	await ticks(2, "installer_saved_dead_original")
	var previous := body.get_node("Presentation") as EnemyPresentation
	var old_host: WeakRef = weakref(previous)
	var old_remains: WeakRef = weakref(previous.feedback_remains)
	check(not previous.feedback_remains.active and not previous.feedback_remains.visible and previous.feedback_remains.restored and active_remains_in(fixture) == 0, "original dead snapshot creates no replay or persistent corpse")
	var installed: Dictionary = INSTALLER.install(fixture)
	check(installed.enemies == 1, "actual installer replaces one dead original presentation")
	await ticks(3, "installer_saved_dead_replacement")
	var replacement := body.get_node("Presentation") as UnderworldEnemy
	check(old_host.get_ref() == null and old_remains.get_ref() == null, "dead installer replacement releases old host and its stage sibling remains")
	check(not replacement.feedback_remains.active and not replacement.feedback_remains.visible and replacement.feedback_remains.restored and replacement.feedback_remains.settled and replacement.feedback_remains.accepted_starts == 0 and active_remains_in(fixture) == 0, "dead installer replacement stays spent without explosion replay or corpse")
	check(replacement.feedback_particles.emitted_bursts == 0 and replacement.feedback_sample.flash_strength() == 0, "installer dead reconstruction does not replay flash or particles")
	var new_remains: WeakRef = weakref(replacement.feedback_remains)
	fixture.queue_free()
	await process_frame
	await process_frame
	check(new_remains.get_ref() == null, "unloading installer fixture releases replacement stage sibling remains")

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
	var particles := restored_art.get("feedback_particles") as EnemyFeedback01Particles
	var sample: Variant = restored_art.get("feedback_sample")
	var remains: Variant = restored_art.get("feedback_remains")
	check(sample != null and sample.restored_terminal, "restored terminal snapshot recognized in selected chain")
	if sample != null:
		check(int(sample.accepted_hit_count) == 0 and int(sample.accepted_death_count) == 0 and not sample.death_active, "saved corpse does not start accepted hurt or death performance")
		check(sample.impact_serial == 0 and sample.flash_strength() == 0 and particles.emitted_bursts == 0 and particles.active_bursts() == 0, "restored corpse creates neither accepted flash nor pixel burst")
		check(not remains.active and not remains.visible and remains.restored and remains.settled and remains.accepted_starts == 0, "saved terminal snapshot stays absent without replaying accepted explosion")
	await ticks(3, "restored_corpse")
	if sample != null:
		check(not sample.death_active and float(sample.hurt_remaining) == 0, "restored corpse remains silent after normal frame progression")
		check(particles.emitted_bursts == 0 and particles.active_bursts() == 0 and sample.flash_strength() == 0, "saved dead snapshot stays particle-free and flash-free after frame progression")
		check(not remains.visible and not remains.active and remains.get_parent() == world, "saved dead snapshot leaves no visible corpse or active death effect")
	check(restored_actor.restore_instance_health(restored_actor.health.capacity), "official health initialization accepts restored live snapshot")
	await process_frame
	check(not remains.active and not remains.visible and particles.active_bursts() == 0, "restoring actor alive clears its persistent corpse without an extra performance")
	var remains_weak: WeakRef = weakref(remains)
	remains = null
	restored.queue_free()
	await process_frame
	await process_frame
	check(remains_weak.get_ref() == null, "restored instance unload releases its inactive remains sibling")

func one_case(path: String, underworld: bool) -> void:
	await setup(path, underworld)
	var sample: Variant = art.get("feedback_sample")
	if sample == null:
		await cleanup()
		return
	var particles := art.get("feedback_particles") as EnemyFeedback01Particles
	var remains: Variant = art.get("feedback_remains")
	check(not remains.active and remains.accepted_starts == 0, "live selected actor begins without an active corpse")
	var initial_hp := actor.health.current
	check(await shoot_until_health_changes("projectile_first_hit"), "fresh Router shot causes actual swept projectile accepted HP hit")
	check(actor.health.current == initial_hp - 1, "first actual projectile commits original configured one damage")
	check(int(sample.accepted_hit_count) == 1 and int(sample.accepted_death_count) == 0, "one nonlethal accepted hit produces exactly one shared hurt")
	check(float(sample.hurt_remaining) > 0, "real accepted hit starts bounded shared hurt clock")
	check(sample.flash_strength() > 0 and sample.impact_serial == 1, "first actual accepted HP hit starts one visible impact flash receipt")
	check(particles.emitted_bursts == 1 and particles.active_bursts() == 1, "first real accepted contact creates exactly one live pixel burst in each chain")
	check(not remains.active and remains.accepted_starts == 0, "real nonlethal hit never creates a corpse")
	if not accepted.is_empty() and not particles._bursts.is_empty():
		check(sample.last_event_id == StringName(accepted.back().event_id) and (particles._bursts.back().point as Vector2).is_equal_approx(accepted.back().hit_point), "pixel burst is anchored to the same actual committed projectile receipt and world contact")
	await verify_body_flash_from_actual_hit()
	rejection_cases()
	await pause_feedback(false)
	await slow_time_feedback()
	await ticks(40, "hurt_recovery")
	check(float(sample.hurt_remaining) == 0, "hurt clock recovers without another accepted event")
	check(sample.impact_remaining == 0 and sample.flash_strength() == 0 and particles.active_bursts() == 0 and particles.emitted_bursts == 1, "nonlethal flash and pixel particles clear within the bounded recovery window")
	for _hit: int in ceili(initial_hp) - 1:
		check(await shoot_until_health_changes("projectile_followup"), "further real projectile commits accepted damage")
	check(actor.health.terminal, "real projectiles reach actual terminal HP")
	check(int(sample.accepted_hit_count) == ceili(initial_hp) - 1 and int(sample.accepted_death_count) == 1, "lethal accepted hit has one death and no extra ordinary hurt")
	check(sample.death_active, "real lethal result starts shared death performance")
	var lethal_position := enemy.global_position
	check(remains.active and remains.accepted_starts == 1, "real lethal projectile creates one remains immediately")
	check(sample.flash_strength() > 0 and sample.impact_serial == 3 and particles.emitted_bursts == 3, "third actual accepted projectile starts lethal flash and exactly the third pixel burst")
	check(particles.active_bursts() > 0 and particles.active_bursts() <= EnemyFeedback01Particles.MAX_BURSTS, "lethal particles remain live and within their bounded burst count")
	await verify_body_flash_from_actual_hit()
	await pause_feedback(true)
	var before_count := accepted.size()
	if not accepted.is_empty():
		check(not actor.damageable.receive_damage(accepted.back()), "actual lethal event cannot damage terminal enemy again")
	await ticks(45, "death_recovery")
	check(int(sample.accepted_death_count) == 1 and accepted.size() == before_count, "terminal actor never repeats death or accepted damage")
	check(sample.flash_strength() == 0 and sample.impact_remaining == 0 and particles.active_bursts() == 0 and particles.emitted_bursts == 3, "lethal flash and all pixel bursts end without replay after terminal event rejection")
	await bounded_real_death_case(remains, lethal_position)
	var drops := EnemyDropService.new()
	check(drops.configure("enemy-feedback-01", "supported_arena"), "existing formal drop service uses unchanged production config")
	var settled := drops.settle(&"feedback_01_enemy")
	check(not settled.is_empty() and drops.settle(&"feedback_01_enemy").is_empty(), "existing drop ledger settles actual dead enemy identity once")
	await restored_corpse_case(underworld)
	await installer_dead_remains_case()
	var remains_final := remains_snapshot(remains)
	var stale_context: Dictionary = accepted.back().duplicate() if not accepted.is_empty() else {}
	check(actor.restore_instance_health(actor.health.capacity), "actual dead actor can receive official restored-live snapshot")
	await process_frame
	var starts_after_restore := int(remains.accepted_starts)
	check(not remains.active and not remains.visible, "same-instance restored-live snapshot clears accepted death effect")
	if not stale_context.is_empty():
		check(not actor.damageable.receive_damage(stale_context), "previous lethal health epoch is rejected after restore-live")
	check(int(remains.accepted_starts) == starts_after_restore and not remains.active, "old-epoch lethal receipt cannot resurrect or duplicate cleared corpse")
	cases.append({"definition": path, "chain": "UnderworldEnemy/PixelPlainsEnemy/WindchimeEnemyVisual" if underworld else "EnemyPresentation", "shots": shots.duplicate(true), "accepted_contexts": accepted.duplicate(true), "trace": trace.duplicate(true), "hurt_count": sample.accepted_hit_count, "death_count": sample.accepted_death_count, "impact_serial": sample.impact_serial, "emitted_bursts": particles.emitted_bursts, "active_bursts_at_end": particles.active_bursts(), "spent_death_effect": remains_final, "drop": settled, "scope": "actual scene and installer consumers in explicit arena; drop ledger only, not DemoApp settlement integration"})
	var component_weak: WeakRef = weakref(sample)
	var remains_weak: WeakRef = weakref(remains)
	sample = null
	remains = null
	await cleanup()
	check(component_weak.get_ref() == null, "unload releases shared component and its HealthState signal ownership")
	check(remains_weak.get_ref() == null, "full arena unload releases actual corpse sibling and lifecycle listeners")

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
	for path: String in SHARED_SOURCE_PATHS:
		shared_source_hashes[path] = FileAccess.get_sha256(path)
	for path: String in SOURCES:
		for underworld: bool in [false, true]:
			await one_case(path, underworld)
	for path: String in SHARED_SOURCE_PATHS:
		check(not str(shared_source_hashes[path]).is_empty() and FileAccess.get_sha256(path) == shared_source_hashes[path], "accepted flash and particles leave existing shared source bytes unchanged: " + path)
	var output := {"feedback_revision": "accepted_explosion_v5", "shared_source_sha256": shared_source_hashes, "task": "ENEMY-FEEDBACK-01", "checks": checks, "failures": failures, "cases": cases, "scope": "real Router/projectiles and original scenes/formal installer; explicit supported arena, not campaign/GPU/device", "not_verified": ["full DemoApp drop persistence and restart", "natural campaign traversal", "same-instance parent death-clock reset", "visual readability", "device performance"]}
	DirAccess.make_dir_recursive_absolute("res://build/enemy_feedback_01/v5")
	var file := FileAccess.open("res://build/enemy_feedback_01/v5/runtime.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print("ENEMY_FEEDBACK_01 checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
