extends SceneTree
## Adversarial checks for the task consumer only, through its public controls.
var checks := 0
var errors: Array[String] = []
var app: PlayerMotionCandidatePreview

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: errors.append(label)

func wait_ready() -> void:
	for unused: int in 180:
		await physics_frame
		if is_instance_valid(app.motion_visual): return
	errors.append("actual formal candidate readiness timeout")

func run() -> void:
	var measured: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/player_presentation_01/motion_v1/idle_fall.json"))
	var exported: Dictionary = JSON.parse_string(JSON.stringify(preload("res://resources/player_presentation_01/motion_clip_data.gd").DATA))
	check(measured == exported,"export-safe clips exactly match measured JSON with normalized JSON number types")
	var profile := PlayerMotionCandidateProfile.new()
	check(profile.valid(),"default cosmetic profile valid")
	for bad: float in [INF,NAN,-1.0,0.0,0.61]:
		profile.landing_seconds = bad
		check(not profile.valid(),"invalid duration rejected")
	profile.landing_seconds = 0.32
	profile.takeoff_particles = 17
	check(not profile.valid(),"out-of-budget emission rejected")
	app = preload("res://scenes/dev/player_presentation_01/motion_candidate.tscn").instantiate()
	root.add_child(app)
	await wait_ready()
	if errors.size() > 0:
		await finish()
		return
	var visual := app.motion_visual
	var old_actor: WeakRef = weakref(app.player)
	app.controller.router.activate_device(&"gamepad")
	app.controller.router.set_jump_held(&"lifecycle",true)
	for unused: int in 4: await physics_frame
	check(visual.accepted_jumps == 1 and not visual._dust.is_empty(),"real accepted jump emits live dust")
	var particles := visual._dust.duplicate(true)
	var point := app.player.position
	paused = true
	for unused: int in 4: await process_frame
	check(visual._dust == particles and app.player.position == point,"active dust and Motor pause together")
	paused = false
	app.set_motion_enabled(false)
	check(visual._dust.is_empty(),"disabled candidate clears particles")
	app.set_motion_enabled(true)
	check(visual._dust.is_empty(),"re-enable does not replay accepted event")
	var accepted := visual.accepted_jumps
	app.controller.router.request_action(&"jump")
	for unused: int in 3: await physics_frame
	check(visual.accepted_jumps == accepted,"rejected airborne intent emits no fake jump dust")
	var generation := app._restart_generation
	app.restart_sample()
	app.restart_sample()
	check(app._restart_generation == generation + 1,"duplicate async restart is ignored")
	app.return_full_game()
	for unused: int in 160: await physics_frame
	check(not app.lifetime.active and not is_instance_valid(app.motion_visual),"Home cancels pending restart without stale candidate")
	check(old_actor.get_ref() == null,"old real actor released after cancellation")
	app.restart_sample()
	await wait_ready()
	check(is_instance_valid(app.motion_visual) and app.motion_visual._dust.is_empty() and app.motion_visual.accepted_jumps == 0,"new run starts without old effects or counters")
	var replacement := app.motion_visual
	replacement.profile = profile
	replacement.set_candidate_enabled(true)
	check(not replacement.candidate_enabled and replacement._dust.is_empty(),"invalid task profile falls back and clears effects")
	await finish()

func finish() -> void:
	if is_instance_valid(app):
		check(await load("res://tests/audio_teardown.gd").drain_world(app),"actual audio owners release")
		app.free()
	for unused: int in 4: await process_frame
	for error: String in errors: printerr(error)
	print("MOTION LIFECYCLE: checks=",checks," errors=",errors.size())
	quit(0 if errors.is_empty() else 1)
