extends SceneTree
## Three identical real Home walks; native MovieMaker soundtrack only.
const LAB := preload("res://scenes/dev/audio_home_lab.tscn")
const FRAMES := 1560
var folder := "res://build/audio_home_01/capture"
var movie_frame := 0
var probe_only := false
var smoke_only := false
var actions_only := false
var segments: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	RenderingServer.frame_post_draw.connect(func() -> void: movie_frame += 1)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder = arg.trim_prefix("--output=")
		if arg == "--probe": probe_only = true
		if arg == "--scene-smoke": smoke_only = true
		if arg == "--actions-only": actions_only = true
	run.call_deferred()

func make_lab(mode: String) -> AudioHomeLab:
	var lab := LAB.instantiate() as AudioHomeLab
	lab.home_lab_capture = true
	lab.home_lab_mode = mode
	root.add_child(lab)
	return lab

func run() -> void:
	# Headless replaces the early Window size with its 64x64 backend default.
	# Reassert the real project-sized diagnostic window after initialization;
	# the independently verified MovieMaker 960x540 branch stays unchanged.
	if actions_only: root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(folder)
	if probe_only:
		await run_probe()
		return
	var modes: Array[String] = ["original", "bed", "life"]
	if smoke_only:
		modes.clear()
		modes.append("life")
	for mode: String in modes:
		var lab := make_lab(mode)
		if not lab.home_lab_ready:
			failures.append("Real Home failed to start: " + mode)
			lab.free()
			continue
		# Identical fixed preroll for real BGM/crossfade and grounded spawn.
		for unused: int in 90: await physics_frame
		lab.home_scene.controller.router.clear("home_audio_capture_begin")
		var initial: Dictionary = lab.home_audio_snapshot()
		var first_frame := movie_frame
		var first_tick := Engine.get_physics_frames()
		var count := 120 if smoke_only else FRAMES
		for index: int in count:
			if not is_instance_valid(lab.home_scene) or not is_instance_valid(lab.home_scene.player):
				failures.append("Real Home disappeared: " + mode)
				break
			# This initial conservative route guarantees a normal 12–22-second
			# character-area opportunity, then walks past the actual raised
			# upgrade/arms buildings below. Probe receipts may guide one authored
			# fixed route before final capture; never change movement by sound.
			var axis := 1.0 if (index >= 30 and index < 74) or (index >= 1240 and index < 1460) else 0.0
			lab.home_scene.controller.router.set_move_axis(axis)
			lab.set_home_audio_phase("原位置静听 · 生活声遵循正常12–22秒节奏" if index < 1240 else "真实地面走近 / 远离工坊 · 不冒称上楼互动")
			await physics_frame
			var player := lab.home_scene.player
			var screen := player.get_global_transform_with_canvas().origin
			samples.append({"mode":mode,"index":index,"movie_frame":movie_frame,"physics_tick":Engine.get_physics_frames(),"position":[player.global_position.x,player.global_position.y],"screen":[screen.x,screen.y],"grounded":player.is_on_floor(),"hp":lab.home_scene.controller.actor_resources.health.current,"nearest_slot":String(lab.home_scene.nearest_id),"snapshot":lab.home_audio_snapshot()})
		segments.append({"mode":mode,"start_frame":first_frame,"end_frame":movie_frame,"first_physics_tick":first_tick,"frames":count,"initial":initial,"final":lab.home_audio_snapshot(),"caption_rects":[rect(lab._home_audio_title.get_global_rect()),rect(lab._home_audio_phase.get_global_rect())]})
		lab.home_scene.controller.router.clear("home_audio_capture_end")
		lab.home_audition.call("stop")
		if not await lab._music.shutdown(): failures.append("Home music did not drain")
		if not await lab.home_lab_audio.shutdown(): failures.append("Home audio did not drain")
		lab.free()
		for unused: int in 4: await process_frame
	var trace := {"task":"AUDIO-HOME-01","version":"audio-home-capture-v1","fps":60,"kind":"scene-smoke" if smoke_only else "actions" if actions_only else "movie","scope":"Formal DemoApp/HomeScene with unchanged ground movement; upstairs buildings heard from the ground; static NPC-area interior foley, no hammer-animation synchronization claim","rendering":{"actual_window":[root.size.x,root.size.y],"logical_content":[root.content_scale_size.x,root.content_scale_size.y]},"segments":segments,"samples":samples,"failures":failures,"movie_clock":{"index_base":0,"frames_drawn_before_quit":movie_frame}}
	FileAccess.open(folder.path_join("trace.json"),FileAccess.WRITE).store_string(JSON.stringify(trace))
	print("AUDIO_HOME_%s segments=%s failures=%s" % ["SCENE_SMOKE" if smoke_only else "ACTIONS" if actions_only else "CAPTURE",segments.size(),failures.size()])
	quit(0 if failures.is_empty() and segments.size() == modes.size() else 1)

func run_probe() -> void:
	var lab := make_lab("life")
	if not lab.home_lab_ready:
		push_error("AUDIO_HOME_PROBE failed to start actual Home")
		lab.free()
		quit(1)
		return
	for unused: int in 6: await physics_frame
	var snapshot: Dictionary = lab.home_audio_snapshot()
	FileAccess.open(folder.path_join("probe.json"),FileAccess.WRITE).store_string(JSON.stringify(snapshot))
	print("AUDIO_HOME_PROBE " + JSON.stringify(snapshot))
	lab.home_audition.call("stop")
	var clean := await lab._music.shutdown()
	clean = await lab.home_lab_audio.shutdown() and clean
	lab.free()
	for unused: int in 4: await process_frame
	quit(0 if clean else 1)

func rect(value: Rect2) -> Array:
	return [value.position.x,value.position.y,value.size.x,value.size.y]
