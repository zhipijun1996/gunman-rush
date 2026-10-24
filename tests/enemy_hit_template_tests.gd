extends SceneTree
## Real existing scenes and Damageable transactions. Explicit isolated combat
## fixtures, not natural campaign traversal, complete Boss fights or GPU review.
const PLAINS := ["patrol_drone", "plains_charger", "plains_diver", "plains_hopper", "plains_sentry", "plains_fan_sentry", "plains_root_bell"]
const FOREST := ["forest_bark_beetle", "forest_swing_pod", "forest_lantern", "forest_seed_sentry", "forest_thread_spider", "forest_crossbranch", "forest_bible_weaver"]
const BOSSES := ["clockwork_guardian", "bellstrider", "windkeeper", "thorn_guardian", "thorn_queen", "rootbell_guardian_v2", "thorn_queen_v2", "thorn_queen_canopy"]
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var world: Node2D
var audio: GameAudio

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func packet(receiver: Damageable, id: String, amount: float, point: Vector2, direction := Vector2.RIGHT) -> Dictionary:
	return {"event_id":id, "amount":amount, "source_faction":&"player", "source_actor_id":-1, "target_actor_id":receiver.actor_id, "target_epoch":receiver.damage_epoch, "hit_point":point, "hit_direction":direction}

func ticks(count: int) -> void:
	for _index: int in count: await process_frame

func ordinary(id: String, chain: String) -> void:
	var source := "res://scenes/enemies/%s.tscn" % (id if id in FOREST else "patrol_drone")
	var motor := (load(source) as PackedScene).instantiate() as EnemyMotor
	var actor := motor.get_node("Actor") as EnemyActor
	actor.definition = load("res://resources/enemies/%s.tres" % id) as EnemyDefinition
	if chain != "scene":
		motor.get_node("Presentation").free()
		var visual: Node2D = UnderworldEnemy.new() if chain == "underworld" else RootBellPresentation.new()
		visual.name = "Presentation"
		visual.set("actor", actor)
		motor.add_child(visual)
	world.add_child(motor)
	actor.set_physics_process(false)
	var host := motor.get_node("Presentation") as Node2D
	var script_before: Script = host.get_script()
	var material_before := host.material
	var generic: EnemyHitTemplate = host.get_meta(EnemyHitTemplate.METADATA) as EnemyHitTemplate if host.has_meta(EnemyHitTemplate.METADATA) else null
	var sample := generic.sample if generic != null else host.get("feedback_sample") as EnemyFeedback01
	var label := id + "/" + chain
	check(sample != null, label + " owns the shared accepted-hit state")
	if sample == null:
		motor.queue_free(); await ticks(2); return
	var particles := generic.particles if generic != null else host.get("feedback_particles") as EnemyFeedback01Particles
	check(not particles.is_processing(), label + " no idle particle polling")
	if generic != null: check(not generic.is_processing(), label + " no idle hit polling")
	var position_before := motor.position
	var context := packet(actor.damageable, label+"/hit", minf(1, actor.health.current*.5), motor.global_position, Vector2(actor.brain.direction,0))
	check(actor.damageable.receive_damage(context), label + " real Damageable accepts nonlethal damage")
	check(sample.accepted_hit_count == 1 and sample.flash_strength() > 0 and sample.pose() != Vector2.ONE, label + " one committed hit starts common time/pose")
	check(particles.emitted_bursts == 1, label + " one accepted hit starts one directional contact burst")
	check(motor.position == position_before and host.get_script() == script_before and host.material == material_before, label + " hit changes neither position, species renderer nor host material")
	if generic != null:
		check(generic.tint() != Color.WHITE and generic.tint(Color(.4,.6,.5,.35)).a == Color(.4,.6,.5,.35).a, label + " common body highlight preserves source alpha")
	check(not actor.damageable.receive_damage(context) and sample.accepted_hit_count == 1 and particles.emitted_bursts == 1, label + " duplicate accepted packet produces no second feedback")
	var wrong := packet(actor.damageable,label+"/wrong_epoch",1,motor.global_position)
	wrong.target_epoch = actor.damageable.damage_epoch-1
	check(not actor.damageable.receive_damage(wrong) and sample.accepted_hit_count == 1, label + " stale target epoch cannot start feedback")
	paused = true
	var held := sample.hurt_remaining
	await ticks(3)
	check(sample.hurt_remaining == held, label + " pause retains common accepted hit clock")
	check(actor.restore_instance_health(actor.health.capacity), label + " real restore consumer initializes current health epoch")
	check(sample.hurt_remaining == 0 and sample.flash_strength() == 0 and particles.active_bursts() == 0 and host.material == material_before, label + " paused restoration clears all hit state without touching material")
	paused = false
	context = packet(actor.damageable,label+"/lethal",actor.health.current,motor.global_position,Vector2(actor.brain.direction,0))
	check(actor.damageable.receive_damage(context) and actor.health.terminal, label + " lethal packet retains existing death eligibility")
	check(sample.accepted_death_count == 1 and host.get_script() == script_before, label + " death is observed once without replacing species death renderer")
	if generic != null:
		check(generic.pose() == Vector2.ONE and generic.tint(Color(.2,.4,.6,.7)) == Color(.2,.4,.6,.7), label + " generic template imposes no terminal body pose or tint")
	check(not actor.damageable.receive_damage(context) and sample.accepted_death_count == 1, label + " terminal replay cannot start another death")
	cases.append({"kind":"ordinary", "id":id, "chain":chain, "renderer":(script_before as Script).resource_path, "shared_state":true, "independent_death":true})
	motor.queue_free(); await ticks(2)

func boss(id: String) -> void:
	var path := "res://scenes/bosses/%s.tscn" % id
	if not ResourceLoader.exists(path):
		check(false,"Missing actual Boss scene " + path); return
	var motor := (load(path) as PackedScene).instantiate() as BossMotor
	world.add_child(motor)
	var encounter := motor.get_node("Encounter") as BossEncounter
	encounter.set_physics_process(false)
	var host := motor.get_node("Presentation") as Node2D
	var template: EnemyHitTemplate = host.get_meta(EnemyHitTemplate.METADATA) as EnemyHitTemplate if host.has_meta(EnemyHitTemplate.METADATA) else null
	check(template != null,id + " Boss uses the same common hit template")
	if template == null: motor.queue_free(); await ticks(2); return
	var renderer: Script = host.get_script()
	var initial_material := host.material
	var inactive := packet(encounter.damageable,id+"/inactive",1,motor.global_position)
	if encounter is WindkeeperEncounter or encounter is ThornForestEncounter:
		check(not encounter.damageable.receive_damage(inactive) and template.sample.accepted_hit_count == 0,id + " inactive/armour refusal produces no common hurt")
	# Explicit vulnerable fixtures: exercise the real Damageable gates without
	# claiming traversal, phase opening or complete battle validation.
	encounter.active = true
	if encounter is WindkeeperEncounter:
		encounter.mode = &"exposed"
		encounter.core_open = true
	if encounter is ThornForestEncounter:
		encounter.mode = &"exposed"
		encounter.core_open = true
	var context := packet(encounter.damageable,id+"/accepted",minf(1,encounter.health.current*.5),motor.global_position,Vector2.DOWN)
	var accepted := (encounter.damageable as WindkeeperDamageable).receive_core(context) if encounter.damageable is WindkeeperDamageable and not (encounter as WindkeeperEncounter).continuous_combat() else encounter.damageable.receive_damage(context)
	check(accepted,id + " actual vulnerable receiver accepts hit")
	check(template.sample.accepted_hit_count == 1 and template.tint() != Color.WHITE,id + " accepted Boss hit shares common state/tint")
	check(template.pose() == Vector2.ONE and host.material == initial_material and host.get_script() == renderer,id + " Boss weakpoint transform, material and species renderer remain owned by Boss")
	var serial := template.sample.impact_serial
	if encounter.damageable is WindkeeperDamageable and not (encounter as WindkeeperEncounter).continuous_combat():
		(encounter.damageable as WindkeeperDamageable).receive_core(context)
	else: encounter.damageable.receive_damage(context)
	check(template.sample.impact_serial == serial,id + " duplicate Boss hit cannot replay feedback")
	var lethal := packet(encounter.damageable,id+"/lethal",encounter.health.current,motor.global_position,Vector2.DOWN)
	var killed := (encounter.damageable as WindkeeperDamageable).receive_core(lethal) if encounter.damageable is WindkeeperDamageable and not (encounter as WindkeeperEncounter).continuous_combat() else encounter.damageable.receive_damage(lethal)
	check(killed and encounter.health.terminal and template.sample.accepted_death_count == 1,id + " actual lethal receiver commits its existing Boss death once")
	check(template.tint(Color(.3,.4,.5,.6)) == Color(.3,.4,.5,.6) and template.pose() == Vector2.ONE and host.material == initial_material and host.get_script() == renderer,id + " common template imposes no Boss death pose, tint, material or replacement renderer")
	cases.append({"kind":"boss", "id":id, "accepted":accepted, "renderer":(renderer as Script).resource_path, "scope":"explicit vulnerable actual receiver, not complete battle"})
	motor.queue_free(); await ticks(2)

func run() -> void:
	world = Node2D.new(); root.add_child(world)
	audio = GameAudio.new(); world.add_child(audio)
	for id: String in PLAINS:
		await ordinary(id,"scene")
		await ordinary(id,"underworld")
	for id: String in FOREST: await ordinary(id,"scene")
	await ordinary("plains_root_bell","root_bell")
	for id: String in BOSSES: await boss(id)
	check(await load("res://tests/audio_teardown.gd").drain_world(world),"actual audio playback ownership releases within original teardown budget")
	world.queue_free(); await ticks(2)
	var out := {"task":"MAIN-PLAYTEST-FEEDBACK-20261024", "scope":"all current ordinary species/render chains and existing Boss receiver fixtures; no visual/device/player approval", "checks":checks, "failures":failures, "cases":cases}
	DirAccess.make_dir_recursive_absolute("res://build/enemy_hit_template")
	var file := FileAccess.open("res://build/enemy_hit_template/runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(out,"\t"));file.close()
	print("ENEMY HIT TEMPLATE: %s assertions, %s failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
