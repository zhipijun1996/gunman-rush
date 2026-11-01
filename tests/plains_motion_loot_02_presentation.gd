extends RefCounted
## Controlled real-host ticks. The phase supplier counts Actor snapshot reads;
## no production counters, synthetic FPS claims or replacement renderers.

class ObservedPhase:
	extends EnemyAttackBehavior
	var reads := 0
	func presentation_state() -> Dictionary:
		reads += 1
		return {}

static func run(tree: SceneTree) -> Dictionary:
	var report := {"assertions":0,"failures":[],"checks":[],"samples":[],"scope":"Actual factory and both presentation hosts; explicit phase/velocity inputs, not natural combat or phone FPS"}
	for profile: StringName in [&"scene", &"underworld"]:
		for kind: StringName in [&"patrol", &"charger"]:
			await _host_ticks(tree, report, profile, kind)
	return report

static func _check(report: Dictionary, ok: bool, label: String) -> void:
	report.assertions += 1
	report.checks.append({"label":label,"passed":ok})
	if not ok:
		report.failures.append(label)
		printerr("FAIL: ",label)

static func _host_ticks(tree: SceneTree, report: Dictionary, profile: StringName, kind: StringName) -> void:
	var label := String(profile)+"/"+String(kind)+" presentation tick: "
	var world := Node2D.new()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	tree.root.add_child(world)
	var motor := EnemyFactory.create_for_behavior(kind)
	_check(report, motor != null, label+"actual factory creates body")
	if motor == null:
		world.free()
		return
	world.add_child(motor)
	var actor := motor.get_node("Actor") as EnemyActor
	actor.brain.enabled = false
	if profile == &"underworld":
		_check(report, EnemyPresentationBinding.replace(actor, profile), label+"formal renderer installed")
	var host := motor.get_node("Presentation") as Node2D
	var visual := host.get("revision_visual") as PlainsRevisionVisual
	var motion := host.get("body_motion") as PlainsMotion02
	var lifecycle := host.get("lifecycle") as EnemyPresentationLifecycle
	_check(report, visual != null and motion != null and lifecycle.is_bound(), label+"actual installed lifecycle and revision visual")
	if visual == null or motion == null:
		world.queue_free()
		await tree.process_frame
		return
	var phase := ObservedPhase.new()
	phase.actor = actor
	actor.add_child(phase)
	actor.attack_behavior = phase
	var original_face := actor.brain.direction
	actor.brain.direction = -original_face
	motor.velocity = Vector2(17, -83)
	phase.locked_direction = Vector2(1, -.5).normalized()
	var dt := .04
	var clock_before := motion.clock
	phase.reads = 0
	host.call("_process", dt)
	_check(report, phase.reads == 1, label+"one current Actor snapshot for normal live tick")
	_check(report, is_equal_approx(motion.clock, clock_before+dt), label+"motion advances once")
	_check(report, is_equal_approx(float(visual.pose.vertical), -83.0) and is_equal_approx(float(visual.pose.aim), atan2(-.5, 1)), label+"velocity and aim reach visible pose")
	_check(report, visual.scale.x == float(original_face if kind == &"patrol" else -original_face), label+"patrol retains head-first delay, charger turns immediately")
	_check(report, is_equal_approx(float(visual.pose.turn), (1.0-smoothstep(0, .18, dt))*(-1 if kind == &"patrol" else 1)), label+"turn age integrates once")
	phase.reads = 0
	host.call("_process", .06)
	_check(report, phase.reads == 1 and visual.scale.x == float(-original_face), label+"second tick uses one snapshot and reaches patrol turn boundary")
	host.call("_process", .08)
	_check(report, is_zero_approx(float(visual.pose.turn)), label+"turn blend finishes at its original .18-second boundary")
	actor.brain.direction = original_face
	host.call("_process", .02)
	_check(report, visual.scale.x == float(-original_face if kind == &"patrol" else original_face), label+"new reversal preserves species facing delay")
	actor.brain.direction = -original_face
	host.call("_process", .03)
	_check(report, visual.scale.x == float(-original_face) and is_equal_approx(float(visual.pose.turn), 1.0-smoothstep(0, .18, .03)), label+"rapid reversal restarts only the visible turn clock")
	var before := visual.pose.duplicate(true)
	clock_before = motion.clock
	var was_paused := tree.paused
	tree.paused = true
	host.call("_process", .1)
	_check(report, visual.pose == before and motion.clock == clock_before, label+"paused host does not advance or refresh pose")
	# Same-epoch complete restore remains immediate, even while paused.
	motor.position = Vector2(230, 145)
	motor.velocity = Vector2(0, 57)
	phase.locked_direction = Vector2.RIGHT
	host.call("synchronize_presentation")
	_check(report, motion.clock == clock_before and float(visual.pose.vertical) == 57.0 and float(visual.pose.aim) == 0.0, label+"paused explicit synchronization reads restored state without advancing clocks")
	tree.paused = was_paused
	# Standalone zero-time refresh must not reuse a previous lifecycle snapshot.
	motor.velocity.y = 19
	phase.reads = 0
	visual.refresh(0.0)
	_check(report, phase.reads == 1 and float(visual.pose.vertical) == 19.0 and motion.clock == clock_before, label+"standalone refresh reads fresh state without advancing motion")
	tree.paused = true
	_check(report, actor.restore_instance_health(actor.health.capacity), label+"actual paused health restore starts new epoch")
	_check(report, motion.clock == 0.0 and visual.sample.hurt_remaining == 0.0, label+"epoch initialization clears accepted clocks")
	host.call("_process", dt)
	_check(report, motion.clock == 0.0 and float(visual.pose.clock) == 0.0, label+"paused new epoch synchronizes immediately without a live tick")
	tree.paused = was_paused
	phase.reads = 0
	host.call("_process", dt)
	_check(report, phase.reads == 1 and is_equal_approx(motion.clock, dt), label+"normal tick after reset reuses only its new epoch snapshot")
	before = visual.pose.duplicate(true)
	_check(report, actor.restore_instance_health(0.0), label+"actual terminal restore accepted")
	host.call("_process", dt)
	_check(report, not visual.visible and visual.pose == before, label+"terminal tick preserves last live joints for handoff")
	report.samples.append({"profile":profile,"kind":kind,"scope":"Controlled real factory/lifecycle; no AI or natural combat performance claim"})
	world.queue_free()
	await tree.process_frame
	await tree.process_frame
