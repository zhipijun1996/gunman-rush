extends SceneTree
## MovieMaker soundtrack, never a post-produced replacement audio track.
const LAB := preload("res://scenes/dev/audio_ambience_lab.tscn")
const FPS := 60
const SEGMENT_FRAMES := 1560
var folder := "res://build/audio_ambience_01/capture"
var movie_frame := 0
var segments: Array[Dictionary] = []
var frame_trace: Array[Dictionary] = []
var failures: Array[String] = []
var events: Array[Dictionary] = []
var active_profile := ""
var active_region := ""
var lifecycle_only := false

func _initialize() -> void:
	RenderingServer.frame_post_draw.connect(func() -> void: movie_frame += 1)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder = arg.trim_prefix("--output=")
		if arg == "--lifecycle-only": lifecycle_only = true
	run.call_deferred()

func run() -> void:
	# Keep the original 1280x720 logical camera/input composition while
	# MovieMaker renders fewer actual pixels on this software-only executor.
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if lifecycle_only:
		await run_lifecycle()
		return
	for region: String in ["plains", "forest"]:
		for profile: String in ["original", "A", "B"]:
			active_profile = profile
			active_region = region
			var lab := LAB.instantiate() as AudioAmbienceLab
			lab.capture_mode = true
			lab.lab_profile = profile
			root.add_child(lab)
			if not lab.lab_ready or not await lab.open_region(region):
				failures.append("Region did not start: " + region + "/" + profile)
				lab.free()
				continue
			# Fixed transport preroll on every identical fresh formal world.
			for unused: int in 90: await physics_frame
			lab.controller.router.clear("ambience_capture_begin")
			lab.controller.jump_ability.jumped.connect(func() -> void: event("jump"))
			lab.controller.landed.connect(func() -> void: event("land"))
			lab.controller.shoot_ability.shot_fired.connect(func(_direction: Vector2, _id: int) -> void: event("shot"))
			var first_frame := movie_frame
			var first_event := events.size()
			var actual_frames: Array[int] = []
			var manifest_hash: String = (lab.stage as GeneratedDemoStage).generated.manifest.manifest_hash
			for index: int in SEGMENT_FRAMES:
				if not is_instance_valid(lab.player) or lab.director.state != DemoRunDirector.State.IN_STAGE:
					failures.append("Formal scene ended early: " + region + "/" + profile)
					break
				lab.set_capture_phase("静听风与植被 · 同 Seed / 同输入" if index < 300 else "真实行走 / 起跳 / 落地 / 原枪反冲" if index < 900 else "环境单听 · BGM 原生淡出后关闭")
				lab.controller.router.set_move_axis(1.0 if index >= 300 and index < 326 else -1.0 if index >= 326 and index < 352 else 0.0)
				if index == 420: lab.controller.router.set_jump_held(&"ambience_capture", true)
				if index == 432: lab.controller.router.set_jump_held(&"ambience_capture", false)
				if index == 470: lab.controller.router.request_action(&"shoot_release", Vector2.DOWN)
				if index == 650: lab.controller.router.set_jump_held(&"ambience_capture", true)
				if index == 662: lab.controller.router.set_jump_held(&"ambience_capture", false)
				if index == 900: lab.environment_only = true
				await physics_frame
				if not is_instance_valid(lab.player): break
				var at := lab.player.global_position
				var screen := lab.player.get_global_transform_with_canvas().origin
				var snapshot: Dictionary = lab.lab_audio.ambience.snapshot()
				actual_frames.append(movie_frame)
				frame_trace.append({"region":region,"profile":profile,"index":index,"movie_frame":movie_frame,"physics_tick":Engine.get_physics_frames(),"position":[at.x,at.y],"screen":[screen.x,screen.y],"hp":lab.controller.actor_resources.health.current,"grounded":lab.player.is_on_floor(),"music_track":String(lab._music.requested_track),"ambience":snapshot})
			var end_frame := movie_frame
			segments.append({"region":region,"profile":profile,"start_frame":first_frame,"end_frame":end_frame,"frames":actual_frames.size(),"manifest_hash":manifest_hash,"events":events.slice(first_event),"ambience":lab.lab_audio.ambience.snapshot(),"bgm_mix_end_frame":first_frame+900,"environment_only_start_frame":first_frame+960})
			lab.controller.router.clear("ambience_capture_end")
			if not await lab._music.shutdown(): failures.append("Music playback did not drain")
			if not await lab.lab_audio.shutdown(): failures.append("Audio playback did not drain")
			lab.free()
			for unused: int in 4: await process_frame
	DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder.path_join("trace.json"), FileAccess.WRITE).store_string(JSON.stringify({"task":"AUDIO-AMBIENCE-01","version":"audio-ambience-capture-v1","fps":FPS,"seed":AudioAmbienceLab.REVIEW_SEED,"rendering":{"actual_window":[root.size.x,root.size.y],"logical_content":[root.content_scale_size.x,root.content_scale_size.y],"viewport_rect":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"scale_mode":"canvas_items"},"scope":"Formal generated maps from unchanged DemoApp; forest developer entry; automatic router inputs; no natural full-route or device claim","segments":segments,"trace":frame_trace,"events":events,"failures":failures,"movie_clock":{"index_base":0,"frames_drawn_before_quit":movie_frame}}))
	print("AUDIO_AMBIENCE_CAPTURE segments=%s failures=%s" % [segments.size(), failures.size()])
	quit(0 if failures.is_empty() and segments.size() == 6 else 1)

func event(id: String) -> void:
	events.append({"id":id,"region":active_region,"profile":active_profile,"movie_frame":movie_frame})

func run_lifecycle() -> void:
	var checks: Array[Dictionary] = []
	var lab := LAB.instantiate() as AudioAmbienceLab
	lab.capture_mode = true
	lab.lab_profile = "A"
	root.add_child(lab)
	var started: bool = lab.lab_ready and await lab.open_region("plains")
	checks.append({"id":"actual_formal_plains_started","passed":started})
	if started:
		for unused: int in 90: await physics_frame
		var before: Dictionary = lab.lab_audio.ambience.snapshot()
		checks.append({"id":"actual_plains_bed_playing","passed":before.beds.any(func(v: Dictionary) -> bool: return bool(v.playing))})
		var connected_before := lab.controller.died.get_connections().size()
		lab.set_lab_profile("B")
		lab.set_lab_profile("A")
		checks.append({"id":"real_controller_death_binding_idempotent","passed":lab.controller.died.get_connections().size() == connected_before})
		# Invoke the original controller death transition, not a fake listener
		# signal. This bounded lifecycle test does not claim natural combat death.
		lab.controller.die()
		var after: Dictionary = lab.lab_audio.ambience.snapshot()
		checks.append({"id":"actual_controller_die_clears_all_ambience","passed":not lab.controller.active and str(after.candidate).is_empty() and not after.beds.any(func(v: Dictionary) -> bool: return bool(v.playing))})
	checks.append({"id":"music_shutdown","passed":await lab._music.shutdown()})
	checks.append({"id":"audio_shutdown","passed":await lab.lab_audio.shutdown()})
	lab.free()
	for unused: int in 4: await process_frame
	var passed := checks.all(func(row: Dictionary) -> bool: return bool(row.passed))
	DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder.path_join("lifecycle.json"), FileAccess.WRITE).store_string(JSON.stringify({"task":"AUDIO-AMBIENCE-01","checks":checks,"scope":"Real formal Plains player Controller.die transition; no fake Listener.died or natural combat death claim"}))
	print("AUDIO_AMBIENCE_LIFECYCLE checks=%s failures=%s" % [checks.size(), checks.filter(func(row: Dictionary) -> bool: return not bool(row.passed)).size()])
	quit(0 if passed else 1)
