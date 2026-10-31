extends SceneTree
## Native lifecycle fixtures using all eight real scenes and the same
## HealthState.configure(saved initial_current) restoration API as the App.
## Resource transactions below are explicit unit fixtures, not combat/video
## evidence, legal weakpoint opening, natural encounters or HP changes in play.
const BOSSES := ["clockwork_guardian","bellstrider","windkeeper","thorn_guardian","thorn_queen","rootbell_guardian_v2","thorn_queen_v2","thorn_queen_canopy"]
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var world: Node2D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func frames(count: int) -> void:
	for _index: int in count:
		await process_frame

func saved_health(encounter: BossEncounter, terminal: bool) -> HealthDefinition:
	var definition := encounter.definition.health_definition.duplicate(true) as HealthDefinition
	definition.initial_current = 0.0 if terminal else definition.max_health
	return definition

func clear_rendered_cues(motion: BossMotionPresentation) -> bool:
	return motion.warning == 0.0 and motion.action == 0.0 and motion.recovery == 0.0 and motion.hurt == 0.0

func clear_live_cues(motion: BossMotionPresentation) -> bool:
	return clear_rendered_cues(motion) and motion._hurt_left == 0.0 and motion._shot_left == 0.0

func damage(encounter: BossEncounter, id: String, amount: float) -> ActorResourceResult:
	# Exercise the real accepted resource event without inventing any Boss AI
	# weakpoint/window. Damageable eligibility/full fights have other runners.
	return encounter.health.apply_damage(ActorResourceRequest.new(StringName(id),encounter.health.epoch,amount,encounter.health.get_instance_id()))

func fixture(id: String) -> void:
	paused = true
	var path := "res://scenes/bosses/%s.tscn" % id
	var body := (load(path) as PackedScene).instantiate() as BossMotor
	var encounter := body.get_node("Encounter") as BossEncounter
	encounter.set_physics_process(false)
	encounter.definition = encounter.definition.duplicate(true) as BossDefinition
	# A real cold loaded terminal scene: Encounter._ready configures zero
	# before Presentation._ready binds its motion observer.
	encounter.definition.health_definition = saved_health(encounter,true)
	world.add_child(body)
	var host := body.get_node("Presentation") as Node2D
	var motion := host.get("motion") as BossMotionPresentation
	check(motion != null,id+" actual presentation owns BossMotionPresentation")
	if motion == null:
		body.queue_free()
		await frames(2)
		return
	check(encounter.health.terminal and motion.death == 1.0 and clear_live_cues(motion),id+" cold bind already terminal is immediately settled while paused")
	await frames(3)
	check(motion.death == 1.0 and motion.mode_age == 0.0,id+" paused cold terminal never starts a fall clock")
	var initial_epoch := encounter.health.epoch
	check(encounter.health.configure(saved_health(encounter,false)),id+" native live restore configure accepted")
	check(encounter.health.epoch > initial_epoch and not encounter.health.terminal and motion.death == 0.0 and clear_live_cues(motion),id+" paused live restore resets terminal pose and all pending cues synchronously")
	var nonlethal := damage(encounter,id+"/native-nonlethal",encounter.health.current*.25)
	check(nonlethal.status == ActorResourceResult.Status.APPLIED and motion._hurt_left > 0.0,id+" actual accepted nonlethal resource commit starts hurt")
	var held_hurt := motion._hurt_left
	await frames(3)
	check(motion._hurt_left == held_hurt and motion.death == 0.0,id+" paused accepted hurt does not advance")
	check(encounter.health.configure(saved_health(encounter,true)),id+" native saved terminal restore configure accepted")
	check(motion.death == 1.0 and clear_live_cues(motion) and motion.mode_age == 0.0,id+" paused terminal restore settles immediately and clears previous hurt")
	await frames(3)
	check(motion.death == 1.0 and clear_live_cues(motion),id+" paused restored terminal retains settled pose")
	# Independently exercise a missed initialize notification / epoch fallback.
	# The authoritative resource still changes through its real configure API.
	var observer := Callable(motion,"_health_changed")
	encounter.health.changed.disconnect(observer)
	check(encounter.health.configure(saved_health(encounter,false)),id+" missed-notification live restore accepted")
	motion.sample(encounter,0.0)
	check(motion._epoch == encounter.health.epoch and motion.death == 0.0 and clear_live_cues(motion),id+" live epoch fallback clears old terminal pose")
	check(encounter.health.configure(saved_health(encounter,true)),id+" missed-notification dead restore accepted")
	motion.sample(encounter,0.0)
	check(motion._epoch == encounter.health.epoch and motion.death == 1.0 and clear_live_cues(motion),id+" dead epoch fallback settles without replay")
	encounter.health.changed.connect(observer)
	check(encounter.health.configure(saved_health(encounter,false)),id+" native live restoration before lethal case accepted")
	# A newly accepted lethal transaction in the current epoch differs from
	# a restored terminal snapshot: it must retain the existing .55s motion.
	var lethal_epoch := encounter.health.epoch
	var lethal := damage(encounter,id+"/native-lethal",encounter.health.current)
	check(lethal.status == ActorResourceResult.Status.APPLIED and encounter.health.terminal and encounter.health.epoch == lethal_epoch and motion.death == 0.0,id+" new accepted lethal commit retains an unplayed death transition")
	await frames(3)
	check(motion.death == 0.0,id+" accepted death remains unadvanced during pause")
	paused = false
	await frames(3)
	check(motion.death > 0.0 and motion.death < 1.0 and clear_rendered_cues(motion),id+" unpaused current-epoch death starts transition and overrides live cues")
	paused = true
	var held_death := motion.death
	var held_age := motion.mode_age
	await frames(3)
	check(motion.death == held_death and motion.mode_age == held_age,id+" pause freezes in-progress accepted death clock")
	paused = false
	await create_timer(.65).timeout
	check(motion.death == 1.0 and clear_live_cues(motion),id+" accepted death reaches settled terminal pose")
	var probe := BossMotionPresentation.new()
	probe.bind(encounter)
	check(probe.death == 1.0 and clear_live_cues(probe),id+" observer rebound after actual death is immediately settled")
	var health_callback := Callable(probe,"_health_changed")
	var shot_callback := Callable(probe,"_projectile_created")
	check(encounter.health.changed.is_connected(health_callback) and encounter.projectile_created.is_connected(shot_callback),id+" observer owns its two signal subscriptions")
	probe.dispose(encounter)
	probe.dispose(encounter)
	check(not encounter.health.changed.is_connected(health_callback) and not encounter.projectile_created.is_connected(shot_callback) and probe._meshes.is_empty(),id+" repeated dispose releases subscriptions and mesh cache")
	paused = true
	check(encounter.health.configure(saved_health(encounter,false)),id+" native live restore after probe disposal accepted")
	check(probe.death == 1.0 and motion.death == 0.0,id+" disposed observer ignores later epoch while real presentation resets")
	cases.append({"scene":path,"scope":"native real-scene HealthState lifecycle fixture; not combat or video","restore_terminal_settled":true,"accepted_death_animated":true,"pause_epoch_dispose":true})
	paused = false
	var health_state := encounter.health
	body.queue_free()
	await frames(2)
	check(not health_state.changed.is_connected(observer) and motion._meshes.is_empty(),id+" actual scene teardown releases its observer and mesh cache")

func run() -> void:
	world = Node2D.new()
	root.add_child(world)
	world.add_child(GameAudio.new())
	for id: String in BOSSES:
		await fixture(id)
	paused = false
	check(await load("res://tests/audio_teardown.gd").drain_world(world),"native fixture audio teardown respects original release budget")
	world.queue_free()
	await frames(2)
	var result := {"task":"ENEMY-ALL-02","scope":"native eight-scene BossMotion lifecycle fixture only; no video, full-fight or visual approval","checks":checks,"failures":failures,"cases":cases}
	DirAccess.make_dir_recursive_absolute("res://build/enemy_all_02/boss-motion-lifecycle")
	var file := FileAccess.open("res://build/enemy_all_02/boss-motion-lifecycle/runtime.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("ENEMY ALL 02 BOSS MOTION LIFECYCLE: %s assertions, %s failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
