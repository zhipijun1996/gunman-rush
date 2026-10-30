extends SceneTree
## Development fixture in the actual formal App. MovieMaker owns the soundtrack.
const APP := preload("res://scenes/demo/demo.tscn")
const VERSION := "audio-feedback-capture-v1"
var folder := "res://build/audio_feedback_05/capture"
var smoke := false
var app: DemoApp
var audio: GameAudio
var caption: Label
var phase := "title"
var events: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var segments: Array[Dictionary] = []
var failures: Array[String] = []
var segment_start := 0
var segment_tick := 0
var active_controller: PlayerController

func _initialize() -> void:
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder = arg.trim_prefix("--output=")
		if arg == "--scene-smoke": smoke = true
	run.call_deferred()

func record(id: String, data: Dictionary = {}) -> void:
	events.append({"id":id,"phase":phase,"movie_frame":Engine.get_frames_drawn(),"physics_tick":Engine.get_physics_frames(),"data":data})

func require(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func begin_segment(id: String, text: String) -> void:
	phase = id
	caption.text = text
	segment_start = Engine.get_frames_drawn()
	segment_tick = Engine.get_physics_frames()
	record("segment_begin", {"caption":text})

func end_segment() -> void:
	segments.append({"id":phase,"start_frame":segment_start,"end_frame":Engine.get_frames_drawn(),"first_physics_tick":segment_tick,"last_physics_tick":Engine.get_physics_frames(),"caption_rect":[caption.position.x,caption.position.y,caption.size.x,caption.size.y]})

func watch(controller: PlayerController) -> void:
	active_controller = controller
	controller.jump_ability.jumped.connect(func() -> void: record("jump", {"source":str(controller.get_path())}))
	controller.landed.connect(func() -> void: record("land", {"source":str(controller.get_path())}))
	controller.shoot_ability.shot_fired.connect(func(direction: Vector2, shot_id: int) -> void:
		record("shot", {"source":str(controller.get_path()),"shot_id":shot_id,"direction":[direction.x,direction.y]})
		for projectile: PlayerProjectile in controller.shoot_ability.get_projectiles():
			if projectile.shot_id != shot_id or projectile.has_meta("audio_feedback_watched"): continue
			projectile.set_meta("audio_feedback_watched", true)
			projectile.terrain_impacted.connect(func(point: Vector2, direction_hit: Vector2) -> void: record("terrain_impact", {"shot_id":shot_id,"position":[point.x,point.y],"direction":[direction_hit.x,direction_hit.y]})))
	controller.actor_resources.health.changed.connect(func(result: ActorResourceResult) -> void: record("health_changed", {"source":str(controller.get_path()),"status":result.status,"operation":String(result.operation),"amount_applied":result.amount_applied,"event_id":String(result.event_id),"hp":result.snapshot.current}))

func take_sample() -> void:
	var row: Dictionary = {"phase":phase,"movie_frame":Engine.get_frames_drawn(),"physics_tick":Engine.get_physics_frames(),"music_track":String(app._music.requested_track),"music_voices":[],"played":audio.played.duplicate(true),"director_events":audio.director_events.duplicate(true),"voices":[]}
	for voice: AudioStreamPlayer in app._music._voices:
		row.music_voices.append({"path":voice.stream.resource_path if voice.stream != null else "","playing":voice.playing,"paused":voice.stream_paused,"volume_db":voice.volume_db,"position":voice.get_playback_position()})
	for voice: AudioStreamPlayer in audio._voices:
		if voice.playing: row.voices.append({"path":voice.stream.resource_path if voice.stream != null else "","cue":String(voice.get_meta("cue_id", &"")),"event":String(voice.get_meta("director_event", &"")),"playing":voice.playing,"paused":voice.stream_paused,"volume_db":voice.volume_db,"position":voice.get_playback_position()})
	if is_instance_valid(active_controller):
		var motor := active_controller.motor
		var screen := motor.get_global_transform_with_canvas().origin
		row.player = {"position":[motor.global_position.x,motor.global_position.y],"screen":[screen.x,screen.y],"hp":active_controller.actor_resources.health.current,"grounded":motor.is_on_floor()}
	samples.append(row)

func wait_frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		take_sample()

func fixture_position(position: Vector2, reason: String) -> void:
	app.controller.router.clear("audio_feedback_position_fixture")
	app.player.reset_motion()
	app.player.global_position = position
	if is_instance_valid(app._run_camera):
		app._run_camera.snap_to_target()
		app._run_camera.force_update_scroll()
	record("position_fixture", {"reason":reason,"position":[position.x,position.y],"source":str(app.player.get_path())})

func bell_stand(point: Vector2) -> Vector2:
	# A positioning fixture still stands on actual stage collision. It does not
	# install a fake platform, turn gravity off, or submit a fake projectile hit.
	for side: float in [-100.0, 100.0, -150.0, 150.0]:
		var origin := point + Vector2(side, -80)
		var query := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(0, 900), 1)
		var hit := app.get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var floor_point: Vector2 = hit.position
			record("actual_floor_fixture", {"floor":[floor_point.x,floor_point.y],"collider":str((hit.collider as Node).get_path())})
			return floor_point + Vector2(0, -18)
	failures.append("No actual collision floor near the real bell")
	return point + Vector2(-100, 0)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	app = APP.instantiate() as DemoApp
	app.meta_persistence_enabled = false
	root.add_child(app)
	for child: Node in app.get_children():
		if child is GameAudio: audio = child as GameAudio
	if audio == null:
		failures.append("Actual formal App GameAudio missing")
		await finish()
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(16, 8)
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(caption)
	# Enter a steady MovieWriter frame cadence before the first chapter anchor.
	for unused: int in 2: await physics_frame
	var selected := app.get_node("SelectedSfxRuntime") as SelectedSfxRuntime
	record("formal_sfx_assembly", selected.snapshot())
	require(selected.validation_ok and audio.audio_profile == "selected", "Actual formal SelectedSfxRuntime did not validate")
	begin_segment("title", "开发音频验收 · 正式标题 / 原 BGM · 原生连续音轨")
	await wait_frames(30 if smoke else 180)
	end_segment()
	begin_segment("home_startup", "正式标题开始操作 · 创建真实家园 / 原 BGM")
	app.menu._start_title_adventure()
	await wait_frames(2)
	end_segment()
	require(is_instance_valid(app.home_scene), "Actual title action did not create HomeScene")
	if not is_instance_valid(app.home_scene):
		await finish()
		return
	watch(app.home_scene.controller)
	begin_segment("home", "真实家园 · 自动输入跳跃 / 对地射击 · 一次生命事务 fixture")
	if smoke:
		await wait_frames(120)
	else:
		for index: int in 720:
			var home := app.home_scene
			if index == 90: home.controller.router.request_action(&"jump")
			if index == 210: home.controller.router.primary_release(Vector2.DOWN)
			if index == 330:
				var health := home.controller.actor_resources.health
				var result := health.apply_damage(ActorResourceRequest.new(&"audio-feedback-movie-hurt", health.epoch, 1.0, health.get_instance_id()))
				record("hurt_fixture_commit", {"status":result.status,"amount_applied":result.amount_applied,"hp":health.current,"scope":"Direct APPLIED on the real Home HealthState; development fixture, not an enemy attack"})
				require(result.status == ActorResourceResult.Status.APPLIED and result.amount_applied == -1.0, "Real Home hurt transaction did not apply once")
			if index == 450:
				caption.text = "真实家园 · 定位 fixture：靠左墙射击 · 不改伤害 / 碰撞规则"
				home.controller.router.clear("audio_feedback_wall_fixture")
				home.player.reset_motion()
				home.player.global_position = Vector2(40, HomeScene.FLOOR_Y - 18)
				record("position_fixture", {"reason":"actual Home left wall","position":[40,HomeScene.FLOOR_Y-18]})
			if index == 462: home.controller.router.primary_release(Vector2.LEFT)
			await wait_frames(1)
	end_segment()
	active_controller = null
	begin_segment("plains_startup", "开发固定种子入口 · 正式风铃平原生成 / 原 BGM")
	var accepted := app.start_debug_region(&"plains", 1, "audio-feedback-05/20261030")
	record("formal_debug_entry", {"accepted":accepted,"seed":"audio-feedback-05/20261030","natural_progression":false})
	for index: int in 180:
		await wait_frames(1)
		if app.stage is PlainsRegionStage and (app.stage as PlainsRegionStage).assembly_ok and is_instance_valid(app.controller): break
	require(accepted and app.stage is PlainsRegionStage and (app.stage as PlainsRegionStage).assembly_ok, "Formal PlainsRegionStage did not assemble")
	end_segment()
	if not app.stage is PlainsRegionStage:
		await finish()
		return
	watch(app.controller)
	var region := app.stage as PlainsRegionStage
	record("formal_stage", {"source":str(region.get_path()),"manifest_hash":region.generated.manifest.get("manifest_hash", ""),"latches":region.shot_latches.size(),"chests":region.chests.size()})
	begin_segment("bell", "真实关卡风铃 · 定位 fixture + 实际子弹碰撞 · 非自然通关")
	var latch: ShotLatch
	for candidate: ShotLatch in region.shot_latches:
		if not candidate.is_open and candidate.sequence_offset.is_zero_approx():
			latch = candidate
			break
	require(latch != null, "No real single-stage ShotLatch available")
	if latch != null:
		latch.opened.connect(func() -> void:
			var actual_source := latch.to_global(latch.bell_position)
			record("bell_opened", {"source":str(latch.get_path()),"position":[actual_source.x,actual_source.y],"path":latch.BELL_SOUND.resource_path,"gain_db":latch._bell_audio.volume_db,"playing":latch._bell_audio.playing}))
		var stand := bell_stand(latch.to_global(latch.bell_position))
		fixture_position(stand, "real existing ShotLatch; support from actual terrain ray")
		for index: int in (120 if smoke else 360):
			if index in [2, 92, 182] and not latch.is_open:
				fixture_position(stand, "retry real projectile aim at actual bell")
				app.controller.router.primary_release((latch.to_global(latch.bell_position) - app.player.global_position).normalized())
			await wait_frames(1)
		if not smoke: require(latch.open_count > 0, "Real projectile did not open actual ShotLatch")
	else: await wait_frames(120 if smoke else 360)
	end_segment()
	begin_segment("chest", "真实关卡宝箱 · 定位 fixture / 正式交互与选择提交 · 原生开箱 / 获得音")
	var chest_index := -1
	for index: int in region.chests.size():
		if not region.chests[index].claimed and str(region.chests[index].get("reward_mode", "")) != "resources":
			chest_index = index
			break
	require(chest_index >= 0, "No unclaimed real item chest available")
	if chest_index >= 0:
		var chest: Dictionary = region.chests[chest_index]
		fixture_position(chest.position, "actual generated item chest " + str(chest.id))
		for index: int in (120 if smoke else 720):
			if index == 2: app.interact()
			if index == 122 and not smoke:
				var option := StringName()
				if app._region_offer != null:
					for item: ItemDefinition in app._region_offer.candidates:
						if not item is ResourceRewardChoice:
							option = item.stable_id
							break
				var submitted := not option.is_empty() and app._claim_modal_item(option)
				record("chest_choice_submitted", {"chest_id":str(chest.id),"item_id":String(option),"accepted":submitted,"source":str(region.get_path())})
				require(submitted, "Actual chest item choice was not queued")
			if index == 134 and not smoke:
				var claimed := bool(chest.claimed) and region.region_state.claimed.has(chest.id)
				record("chest_claim_committed", {"chest_id":str(chest.id),"claimed":claimed,"director_events":audio.director_events.duplicate(true)})
				require(claimed, "Actual chest ownership/claimed ledger did not commit")
			await wait_frames(1)
	else: await wait_frames(120 if smoke else 720)
	end_segment()
	await finish()

func finish() -> void:
	paused = false
	var trace := {"task":"AUDIO-FEEDBACK-05","version":VERSION,"fps":60,"smoke":smoke,"scope":"Continuous real demo.tscn with formal SelectedSfxRuntime/SelectedAmbienceRuntime; explicit debug seed, position and real HealthState fixtures; no dubbed audio or natural-campaign claim","rendering":{"actual_window":[root.size.x,root.size.y],"logical_content":[root.content_scale_size.x,root.content_scale_size.y]},"segments":segments,"samples":samples,"events":events,"failures":failures,"movie_clock":{"frames_drawn_before_quit":Engine.get_frames_drawn()}}
	FileAccess.open(folder.path_join("trace.json"), FileAccess.WRITE).store_string(JSON.stringify(trace))
	# The driver owns this actual App and drains its original audio before free.
	if is_instance_valid(app):
		if is_instance_valid(app._music):
			if not await app._music.shutdown(): failures.append("Actual music did not drain")
		if is_instance_valid(audio):
			if not await audio.shutdown(): failures.append("Actual SFX/ambience did not drain")
		app.free()
	for unused: int in 4: await process_frame
	trace.failures = failures
	trace.movie_clock.frames_drawn_before_quit = Engine.get_frames_drawn()
	FileAccess.open(folder.path_join("trace.json"), FileAccess.WRITE).store_string(JSON.stringify(trace))
	print("AUDIO_FEEDBACK_CAPTURE smoke=%s failures=%s" % [smoke,failures.size()])
	quit(0 if failures.is_empty() else 1)
