extends "res://tools/audio_feedback_capture.gd"
## Reuse the formal feedback producer's observer/movie-clock helpers.
## Only these audition transactions are fixtures; the live Motor is unchanged.
const HURT_VERSION := "audio-hurt-feedback-capture-v1"
var active_hurt_candidate := ""

func take_sample() -> void:
	super.take_sample()
	var row: Dictionary = samples.back()
	row.hurt_candidate = active_hurt_candidate
	if is_instance_valid(app.home_scene):
		row.camera = [app.home_scene.camera.position.x, app.home_scene.camera.position.y]

func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	app = APP.instantiate() as DemoApp
	app.meta_persistence_enabled = false
	root.add_child(app)
	for child: Node in app.get_children():
		if child is GameAudio: audio = child as GameAudio
	if audio == null:
		failures.append("Actual formal App GameAudio is missing")
		await finish()
		return
	var layer := CanvasLayer.new()
	layer.layer = 125
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(240, 12)
	caption.size = Vector2(820, 32)
	caption.clip_text = true
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(caption)
	for unused: int in 2: await physics_frame
	var selected := app.get_node_or_null("SelectedSfxRuntime") as SelectedSfxRuntime
	require(selected != null and selected.validation_ok and audio.audio_profile == "selected", "Actual formal selected SFX assembly did not validate")
	if selected != null: record("formal_sfx_assembly", selected.snapshot())
	begin_segment("title", "正式标题 · 2 秒无输入 / 原 BGM · 原生连续录音")
	record("title_without_input", {"injected_input_count":0,"scope":"Native title observation; browser autoplay policy is separately validated"})
	await wait_frames(120)
	end_segment()
	begin_segment("home_startup", "正式开始操作 · 创建真实家园 / 保留原 BGM")
	app.menu._start_title_adventure()
	await wait_frames(2)
	end_segment()
	require(is_instance_valid(app.home_scene), "Actual title action did not create HomeScene")
	if not is_instance_valid(app.home_scene):
		await finish()
		return
	watch(app.home_scene.controller)
	begin_segment("home_actions", "真实家园 · 自动输入跳落 / 对地射击 · wall_1 固定音色")
	for index: int in 360:
		if index == 30: app.home_scene.controller.router.request_action(&"jump")
		if index == 180: app.home_scene.controller.router.primary_release(Vector2.DOWN)
		await wait_frames(1)
	end_segment()
	var health := app.home_scene.controller.actor_resources.health
	var initial_health := health.current
	for letter: String in ["a", "b", "c"]:
		active_hurt_candidate = "hurt_feedback_06_" + letter
		var path := "res://assets/audio/feedback_06/hurt_%s.wav" % letter
		begin_segment("hurt_" + letter, "受伤候选 %s · 生命事务 fixture / 非自然敌击 · 段后恢复 1HP" % letter.to_upper())
		var configured := audio.configure_candidate_revision(&"hurt", {"id":active_hurt_candidate,"variants":[path]})
		record("hurt_candidate_configured", {"candidate_id":active_hurt_candidate,"path":path,"accepted":configured,"controller":str(active_controller.get_path()),"health_instance":health.get_instance_id()})
		require(configured, "Hurt candidate could not be configured: " + path)
		for index: int in 240:
			if index == 45:
				var result := health.apply_damage(ActorResourceRequest.new(StringName("audio-feedback-06-damage-" + letter), health.epoch, 1.0, health.get_instance_id()))
				record("hurt_fixture_commit", {"candidate_id":active_hurt_candidate,"path":path,"status":result.status,"amount_applied":result.amount_applied,"hp":health.current,"health_instance":health.get_instance_id(),"scope":"Actual Home HealthState.apply_damage; explicit 1HP fixture, not an enemy attack"})
				require(result.status == ActorResourceResult.Status.APPLIED and result.amount_applied == -1.0 and not health.terminal, "Hurt fixture did not apply one nonterminal HP: " + letter)
			if index == 210:
				var restored := health.heal(ActorResourceRequest.new(StringName("audio-feedback-06-restore-" + letter), health.epoch, 1.0, health.get_instance_id()))
				record("health_restore_fixture", {"candidate_id":active_hurt_candidate,"status":restored.status,"amount_applied":restored.amount_applied,"hp":health.current,"health_instance":health.get_instance_id(),"scope":"Explicit end-of-segment 1HP restoration through the original HealthState.heal API for equal audition conditions"})
				require(restored.status == ActorResourceResult.Status.APPLIED and restored.amount_applied == 1.0 and health.current == initial_health, "Original heal transaction did not restore audition HP: " + letter)
			await wait_frames(1)
		end_segment()
	await finish()

func finish() -> void:
	paused = false
	var trace := {"task":"AUDIO-FEEDBACK-06","version":HURT_VERSION,"fps":60,"scope":"Continuous formal title/Home MovieMaker soundtrack; real Router jump/shot and collision; three explicit HealthState damage/heal fixtures in the same camera. No dubbed audio, enemy-attack, browser-autoplay or physical-device claim.","rendering":{"actual_window":[root.size.x,root.size.y],"logical_content":[root.content_scale_size.x,root.content_scale_size.y]},"segments":segments,"samples":samples,"events":events,"failures":failures,"movie_clock":{"frames_drawn_before_quit":Engine.get_frames_drawn()}}
	FileAccess.open(folder.path_join("trace.json"), FileAccess.WRITE).store_string(JSON.stringify(trace))
	if is_instance_valid(app):
		if is_instance_valid(app._music) and not await app._music.shutdown(): failures.append("Actual music did not drain")
		if is_instance_valid(audio) and not await audio.shutdown(): failures.append("Actual SFX/ambience did not drain")
		app.free()
	for unused: int in 4: await process_frame
	trace.failures = failures
	trace.movie_clock.frames_drawn_before_quit = Engine.get_frames_drawn()
	FileAccess.open(folder.path_join("trace.json"), FileAccess.WRITE).store_string(JSON.stringify(trace))
	print("AUDIO_HURT_FEEDBACK_CAPTURE failures=%s" % failures.size())
	quit(0 if failures.is_empty() else 1)
