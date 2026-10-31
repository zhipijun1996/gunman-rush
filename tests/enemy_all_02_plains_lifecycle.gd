extends SceneTree
## Native lifecycle counterexamples only. These explicit health restores are
## never used by the MovieMaker combat drivers or claimed as real combat.
const IDS := ["patrol_drone", "plains_charger", "plains_diver", "plains_hopper", "plains_sentry", "plains_fan_sentry", "plains_root_bell"]
var checks := 0
var failures: Array[String] = []
var world: Node2D
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)
func run() -> void:
	world = Node2D.new()
	root.add_child(world)
	for id: String in IDS:
		for chain: String in ["scene", "underworld", "root_bell"]:
			if chain == "root_bell" and id != "plains_root_bell": continue
			var motor := preload("res://game/enemies/scenes/patrol_drone.tscn").instantiate() as EnemyMotor
			var actor := motor.get_node("Actor") as EnemyActor
			actor.definition = load("res://resources/enemies/%s.tres" % id) as EnemyDefinition
			if chain != "scene":
				motor.get_node("Presentation").free()
				var replacement: Node2D = UnderworldEnemy.new() if chain == "underworld" else RootBellPresentation.new()
				replacement.name = "Presentation"
				replacement.set("actor", actor)
				motor.add_child(replacement)
			world.add_child(motor)
			actor.set_physics_process(false)
			var host := motor.get_node("Presentation") as Node2D
			var motion: PlainsMotion02 = host.get("body_motion")
			var label := id+"/"+chain
			motion.advance(actor, .2)
			var original_clock := motion.clock
			paused = true
			await process_frame
			check(is_equal_approx(motion.clock, original_clock), label+" paused locomotion clock stays fixed")
			check(actor.restore_instance_health(0.0), label+" actual enemy restore accepts saved terminal")
			check(motion.clock == 0.0 and motion.tension == 0.0 and motion.release == 0.0, label+" terminal initialize clears old epoch immediately while paused")
			check(actor.restore_instance_health(actor.definition.health_definition.max_health), label+" actual restore accepts live state")
			check(not actor.health.terminal and motion.clock == 0.0 and motion.travel == 0.0, label+" live initialize has no old gait")
			if chain == "underworld": check(host.visible and host.modulate.a == 1.0, label+" revived body is visible immediately")
			var revision := host.get("revision_visual") as PlainsRevisionVisual
			if revision != null:
				var rig := revision.rig
				var source := rig.texture
				var bounds := rig.bounds
				motion.advance(actor,.137)
				revision.refresh(0.0)
				var handoff := revision.remains_view()
				check(rig==revision.rig and source==revision.rig.texture and bounds==revision.rig.bounds,label+" live recovery retains the same continuous rig source and anchor")
				check(handoff.rig==rig and (handoff.transform as Transform2D).origin.is_equal_approx(revision.global_position),label+" live and death handoff share actual rig and global foot anchor")
			elif id in ["plains_charger", "plains_diver"]:
				var frames: EnemyFeedback01Frames = host.get("feedback_frames")
				check(frames.canonical_live_texture() == frames.texture(3) and frames.canonical_live_bounds() == frames.bounds(3), label+" H3 exits into exactly the same source/anchor")
				motion.advance(actor, .137)
				host.call("_sync_feedback_body")
				var body: EnemyFeedback01Body = host.get("feedback_body")
				var handoff: Dictionary = host.call("_remains_view")
				check((handoff.transform as Transform2D).origin.is_equal_approx(body.global_position), label+" live and death handoff share actual bob anchor")
			paused = false
			motor.queue_free()
			await process_frame
	world.queue_free()
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://build/enemy_all_02/plains-motion-lifecycle")
	var file := FileAccess.open("res://build/enemy_all_02/plains-motion-lifecycle/runtime.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"native explicit restore fixtures; no gameplay video injection", "checks":checks,"failures":failures},"\t"))
	file.close()
	print("ENEMY ALL 02 PLAINS LIFECYCLE: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
