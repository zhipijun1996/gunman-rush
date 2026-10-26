extends SceneTree
var movie_frames_drawn := 0
var movie_origin_process := 0
var smoke := false
var folder := "res://build/audio_director_v3/reels"
var reel := "coin"
func _initialize() -> void:
	movie_origin_process = Engine.get_process_frames()
	RenderingServer.frame_post_draw.connect(_movie_frame_completed)
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--smoke": smoke = true
		if arg.begins_with("--reel="): reel = arg.trim_prefix("--reel=")
		if arg.begins_with("--output="): folder = arg.trim_prefix("--output=")
	start.call_deferred()
func start() -> void:
	root.size = Vector2i(1280, 720)
	if smoke:
		var audio := GameAudio.new()
		root.add_child(audio)
		var title := Label.new()
		title.text = "REAL GODOT MOVIE + NATIVE AUDIO SMOKE"
		title.position = Vector2(120, 280)
		title.add_theme_font_size_override("font_size", 32)
		root.add_child(title)
		for frame: int in 120:
			if frame == 30: GameAudio.cue(title, &"coin")
			await physics_frame
		await audio.shutdown()
		audio.free()
		title.free()
		print("AUDIO_REELS_SMOKE frames=120")
		quit()
		return
	var lab: Node = load("res://scenes/dev/audio_director_reels.tscn").instantiate()
	lab.movie_frame_clock = func() -> int: return movie_frames_drawn
	root.add_child(lab)
	for unused: int in 240:
		await physics_frame
		if lab.lab_ready: break
	if not lab.lab_ready:
		push_error("Audio reels fixture did not become ready")
		quit(1)
		return
	await lab.capture_reel(reel, folder)
	await lab._music.shutdown()
	await lab.lab_audio.shutdown()
	lab.free()
	for unused: int in 4: await process_frame
	var trace_path := folder.path_join("trace.json")
	var trace: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(trace_path))
	trace["movie_clock"] = {"kind": "RenderingServer.frame_post_draw count, installed before first draw", "origin_process_frame": movie_origin_process, "frames_drawn_before_quit": movie_frames_drawn, "index_base": 0}
	FileAccess.open(trace_path, FileAccess.WRITE).store_string(JSON.stringify(trace))
	print("AUDIO_REELS_CAPTURE reel=%s complete=true" % reel)
	quit()

func _movie_frame_completed() -> void:
	movie_frames_drawn += 1
