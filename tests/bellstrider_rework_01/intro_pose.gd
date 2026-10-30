extends SceneTree
## Actual scenes and their installed BossArrivalPresentation. Intro progress is
## an explicit fixture; no process frame may hide a stale offset at admission.
const BELLSTRIDER := preload("res://scenes/bosses/bellstrider.tscn")
const WINDKEEPER := preload("res://scenes/bosses/windkeeper.tscn")
const AUDIO_TEARDOWN := preload("res://tests/audio_teardown.gd")
var assertions := 0
var failures: Array[String] = []
var world: Node2D
var motor: BossMotor
var encounter: WindkeeperEncounter
var presentation: Node2D
var arrival: BossArrivalPresentation


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)


func frames(count: int) -> void:
	for index: int in count:
		await process_frame


func fixture(machine: bool) -> void:
	paused = false
	if is_instance_valid(world):
		encounter.cancel()
		check(await AUDIO_TEARDOWN.drain_world(world), "fixture audio drains")
		world.free()
		await frames(2)
	world = Node2D.new()
	root.add_child(world)
	var target := Node2D.new()
	target.position = Vector2(900, 582)
	world.add_child(target)
	motor = (BELLSTRIDER if machine else WINDKEEPER).instantiate()
	motor.position = Vector2(600, 535)
	world.add_child(motor)
	encounter = motor.get_node("Encounter")
	presentation = motor.get_node("Presentation")
	encounter.set_physics_process(false)
	presentation.set_process(false)
	# Arrival is genuinely installed by the production presentation, deferred.
	await frames(3)
	arrival = null
	for child: Node in motor.get_children():
		if child is BossArrivalPresentation and child.subject == presentation:
			arrival = child as BossArrivalPresentation
	check(is_instance_valid(arrival), "actual scene installs its arrival subject")
	if not is_instance_valid(arrival):
		return
	arrival.set_process(false)
	check(
		encounter.configure_arena(100, 1100, target) and encounter.activate(),
		"actual scene activates intro"
	)
	# .32 is the default arrival's maximum offset: ±18wu rolling or -60wu
	# nonrolling. Neither the production helper nor the subject is replaced.
	encounter.clock = encounter.intro_duration * .68
	if encounter is BellstriderEncounter:
		var machine_encounter := encounter as BellstriderEncounter
		machine_encounter._fight_age = encounter.intro_duration * .32
		machine_encounter._state_age = encounter.intro_duration * .32
	encounter._update_combat_shapes()
	arrival._process(0.0)
	check(is_equal_approx(arrival.progress, .32), "actual arrival reads forced intro progress .32")
	check(
		not encounter.accepts_combat_damage() and encounter._core.collision_layer == 0,
		"intro choreography is not vulnerable"
	)


func anchors_match() -> bool:
	var machine := encounter as BellstriderEncounter
	var pose := machine.rig_pose()
	var bell_transform: Transform2D = pose.bell_transform
	var drawn := presentation.to_global(bell_transform.origin)
	return drawn.distance_to(machine._core.global_position) < .001


func skip_at_peak(while_paused: bool, side: int) -> void:
	await fixture(true)
	if not is_instance_valid(arrival):
		return
	encounter.direction = side
	encounter._update_combat_shapes()
	arrival._process(0.0)
	check(
		(
			is_equal_approx(presentation.position.x, 18.0 * side)
			and is_zero_approx(presentation.position.y)
		),
		"actual rolling arrival has an 18wu subject offset before skip"
	)
	check(not anchors_match(), "fixture actually reproduces the displaced intro draw anchor")
	var frame := Engine.get_process_frames()
	var health := encounter.health.current
	var origin := motor.global_position
	paused = while_paused
	encounter.skip_intro()
	# Deliberately no await, arrival callback, presentation callback, or manual
	# shape refresh between skip and these admission-boundary observations.
	check(Engine.get_process_frames() == frame, "skip observed before any process frame")
	check(
		encounter.mode == &"observe" and encounter.accepts_combat_damage(),
		"actual skip synchronously admits combat"
	)
	check(
		presentation.position.is_zero_approx() and anchors_match(),
		"rendered bell and real core coincide immediately after skip"
	)
	check(
		encounter.health.current == health and motor.global_position == origin,
		"synchronous visual settle changes neither HP nor motor position"
	)
	check(paused == while_paused, "skip preserves actual tree pause state")
	paused = false


func normal_completion() -> void:
	await fixture(true)
	if not is_instance_valid(arrival):
		return
	check(
		absf(presentation.position.x) > 17.9,
		"normal-completion fixture starts at the actual arrival peak"
	)
	var frame := Engine.get_process_frames()
	encounter.physics_tick(encounter.clock + .001)
	check(
		Engine.get_process_frames() == frame,
		"natural intro deadline observed before a process frame"
	)
	check(
		encounter.mode == &"observe" and encounter._core.collision_layer == 4,
		"actual intro deadline enables the weakpoint"
	)
	check(
		presentation.position.is_zero_approx() and anchors_match(),
		"normal intro completion has no residual draw/core offset"
	)


func unchanged_windkeeper() -> void:
	await fixture(false)
	if not is_instance_valid(arrival):
		return
	check(
		is_equal_approx(presentation.position.y, -60.0),
		"actual Windkeeper keeps its existing nonrolling arrival"
	)
	encounter.skip_intro()
	check(
		is_equal_approx(presentation.position.y, -60.0),
		"Bellstrider-specific synchronous settle leaves Windkeeper unchanged"
	)
	arrival._process(.01)
	check(
		is_equal_approx(presentation.position.y, -54.0),
		"existing Windkeeper arrival still eases toward zero at 600wu per second"
	)


func run() -> void:
	await skip_at_peak(false, 1)
	await skip_at_peak(false, -1)
	await skip_at_peak(true, 1)
	await skip_at_peak(true, -1)
	await normal_completion()
	await unchanged_windkeeper()
	paused = false
	encounter.cancel()
	check(await AUDIO_TEARDOWN.drain_world(world), "final fixture audio drains")
	world.free()
	print("BELLSTRIDER_INTRO_POSE assertions=", assertions, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
