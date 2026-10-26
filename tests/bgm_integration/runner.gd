extends SceneTree
## Real App/stage/Boss lifecycle, with explicit placement and lethal policy
## fixtures. This is not natural traversal, a listening test, or Web/device proof.
var checks := 0
var failures := 0
var observations: Array[Dictionary] = []
var loop_observations: Array[Dictionary] = []
var app: DemoApp

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("BGM FAIL: " + label)

func frames(count: int = 3) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func playback_ref(voice: AudioStreamPlayer) -> WeakRef:
	# End this non-async stack before waiting: a get_stream_playback() call
	# temporary in an awaiting function can itself keep the backend alive.
	return weakref(voice.get_stream_playback())

func wait_until(predicate: Callable, timeout_msec: int = 60000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while not predicate.call():
		if Time.get_ticks_msec() >= deadline: return false
		await frames(1)
	return true

func observe(label: String) -> void:
	var voices: Array[Dictionary] = []
	for voice: AudioStreamPlayer in app._music._voices:
		voices.append({"playing": voice.playing, "stream": voice.stream.resource_path if voice.stream != null else "", "position": voice.get_playback_position(), "volume_db": voice.volume_db, "bus": String(voice.bus)})
	var boss: BossEncounter
	if is_instance_valid(app.stage) and is_instance_valid(app.stage.boss): boss = app.stage.boss.get_node("Encounter") as BossEncounter
	observations.append({"label": label, "track": String(app._music.requested_track), "region": String(app.active_region_id), "map": app.director.region_map_index, "director_state": app.director.state, "boss_active": boss.active if boss != null else false, "boss_terminal": boss.health.terminal if boss != null else false, "boss_scene": app.stage.boss.scene_file_path if boss != null else "", "paused": paused, "voices": voices, "starts": app._music.starts.duplicate()})

func wait_audio_wall(seconds: float) -> void:
	# Audio mixing follows real time. SceneTreeTimer can consume a long frame's
	# delta from before timer creation and expire before this wall interval.
	var deadline := Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < deadline:
		await process_frame

func audio_clock(voice: AudioStreamPlayer) -> Dictionary:
	# Keep the real playback reference inside this synchronous stack only;
	# never retain a backend across await or the original one-second teardown.
	var playback: AudioStreamPlayback = voice.get_stream_playback() if voice.has_stream_playback() else null
	return {"monotonic_usec":Time.get_ticks_usec(),"playing":voice.playing,"position":voice.get_playback_position(),"backend_position":playback.get_playback_position() if playback else -1.0,"loop_count":playback.get_loop_count() if playback else -1,"since_mix":AudioServer.get_time_since_last_mix(),"to_next_mix":AudioServer.get_time_to_next_mix(),"mix_rate":AudioServer.get_mix_rate(),"process_frame":Engine.get_process_frames()}

func gate_and_loop_checks() -> void:
	# Native fixture for the deferred Web policy; actual browser activation is
	# separately unverified. Window.push_input follows the real input callback.
	var music := GameMusic.new()
	root.add_child(music)
	music._unlocked = false
	check(music.request_track(&"home"), "valid deferred title track accepted")
	await frames()
	check(music.starts.is_empty() and not music._voices[0].playing, "locked service queues track without starting audio")
	var canceled := InputEventScreenTouch.new()
	canceled.pressed = true
	canceled.canceled = true
	root.push_input(canceled, true)
	await frames()
	check(not music._unlocked, "canceled touch is not an unlock gesture")
	var gesture := InputEventKey.new()
	gesture.physical_keycode = KEY_SHIFT
	gesture.pressed = true
	root.push_input(gesture, true)
	await frames()
	check(music._unlocked and int(music.starts.get(&"home", 0)) == 1, "actual Window key input starts deferred music once")
	gesture.pressed = false
	root.push_input(gesture, true)
	var started := music.starts.duplicate()
	check(music.request_track(&"home") and music.starts == started, "same-track request preserves actual playback")
	check(not music.request_track(&"missing") and music.requested_track == &"home", "unknown track cannot replace current request")
	await create_timer(1.0, true, false, true).timeout
	check(music.request_track(&"forest"), "second track accepted")
	await frames(2)
	check(music._voices[0].playing and music._voices[1].playing, "transition overlaps two real streaming MP3 players")
	check(music.request_track(&"home") and int(music.starts.get(&"home", 0)) == 1, "rapid return reuses still-playing original track without restart")
	await create_timer(1.0, true, false, true).timeout
	check(music._voices.filter(func(v: AudioStreamPlayer) -> bool: return v.playing).size() == 1, "finished crossfade releases faded player's stream")
	for id: StringName in [&"home", &"plains", &"plains_boss", &"forest", &"forest_boss"]:
		music.request_track(id)
		await frames()
		var voice := music._voices[music._ids.find(id)]
		check(voice.stream is AudioStreamMP3 and voice.stream.loop and voice.stream.get_length() > 150.0, "real imported long MP3 loops: " + String(id))
		# Hash files before seeking, so evidence I/O cannot extend the wrap deadline.
		var source_sha := FileAccess.get_sha256(voice.stream.resource_path)
		var import_sha := FileAccess.get_sha256(voice.stream.resource_path+".import")
		var before := audio_clock(voice)
		var length := voice.stream.get_length()
		voice.seek(length - 0.05)
		var queued := audio_clock(voice)
		await wait_audio_wall(0.2)
		var after := audio_clock(voice)
		loop_observations.append({"track":String(id),"length":length,"seek_target":length-0.05,"stream":voice.stream.resource_path,"source_sha256":source_sha,"import_sha256":import_sha,"configured_loop":voice.stream.loop,"before":before,"queued":queued,"after":after,"actual_wall_usec":after.monotonic_usec-queued.monotonic_usec})
		check(voice.playing and voice.get_stream_playback().get_loop_count() > 0, "actual MP3 playback wraps at original track end: " + String(id))
	check(await music.shutdown(), "standalone music backend releases within original one-second bound")
	music.free()
	await frames()
	var departing := GameMusic.new()
	root.add_child(departing)
	departing.request_track(&"home")
	await frames()
	var voice := departing._voices[departing._ids.find(&"home")]
	var playback := playback_ref(voice)
	departing.free() # Exercise normal _exit_tree, without the optional shutdown API.
	check(await wait_until(func() -> bool: return playback.get_ref() == null, 1000), "normal owner exit also releases MP3 backend without explicit shutdown")

func settings_checks() -> void:
	app.toggle_pause()
	await frames()
	check(paused and app.menu.visible_panel == &"build", "real pause opens the backpack without resuming music")
	var starts := app._music.starts.duplicate()
	await create_timer(0.3, true, false, true).timeout
	check(app._music._duck <= GameMusic.PAUSE_GAIN + 0.01 and app._music.starts == starts, "pause ducks continuous music without restarting")
	app.menu.show_settings(true)
	await frames()
	var volume: HSlider
	var mute: CheckButton
	for control: Node in app.menu._root.find_children("*", "Control", true, false):
		if control is HSlider and control.get_meta("focus_key", "") == "audio_volume": volume = control
		if control is CheckButton and control.text.begins_with("Mute audio"): mute = control
	check(volume != null and mute != null, "existing actual settings controls present")
	if volume != null:
		volume.value = 0.25 # Explicit native Control signal fixture, no new UI API.
		await frames()
		check(app._music.volume_source.volume == 0.25, "existing volume slider reaches original SFX service")
		var quiet := true
		for voice: AudioStreamPlayer in app._music._voices:
			if voice.playing and voice.volume_db > -30.0: quiet = false
		check(quiet, "music also consumes existing total volume and pause attenuation")
	if mute != null:
		mute.button_pressed = true
		await frames()
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "existing mute control mutes shared Master bus including music")
		mute.button_pressed = false
		await frames()
		check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "existing control unmutes without new audio state")
	if volume != null: volume.value = 0.7
	app.menu.close_panel()
	await frames()
	check(not paused and app._music.starts == starts, "resume preserves same music playback")
	check(app._music.volume_source._voices.size() == GameAudio.MAX_VOICES and app._music._voices.size() == 2, "music does not occupy or grow the original SFX voice pool")

func encounter_checks(region_id: StringName, map_index: int) -> void:
	var expected := &"forest" if region_id == &"thorn_forest" else &"plains"
	var accepted := app.start_plains("bgm-integration/plains") if region_id == &"plains" and map_index == 1 else app.start_debug_region(region_id, map_index, "bgm-integration/" + String(region_id))
	check(accepted, "actual App entry accepts " + String(region_id) + str(map_index))
	var ready := await wait_until(func() -> bool: return is_instance_valid(app.stage) and app.stage.assembly_ok and not app._stage_pending)
	check(ready, "actual generated stage is ready for " + String(region_id) + str(map_index))
	if not ready: return
	await frames()
	check(app._music.requested_track == expected, "real exploration selects regional track before Boss activation")
	observe("exploration")
	if region_id == &"plains" and map_index == 1: await settings_checks()
	var region := app.stage as PlainsRegionStage
	app.player.reset_at(region.boss_arena.get_center()) # Explicit placement fixture.
	var boss := region.boss.get_node("Encounter") as BossEncounter
	check(await wait_until(func() -> bool: return boss.active and app._boss_started, 5000), "real App arena activates actual Boss")
	await frames()
	var boss_track := &"forest_boss" if region_id == &"thorn_forest" else &"plains_boss"
	check(app._music.requested_track == boss_track, "actual Boss activation selects proper Boss music")
	observe("boss_started")
	var starts := app._music.starts.duplicate()
	await frames(5)
	check(app._music.starts == starts, "repeated actual Boss frames never restart same track")
	var request := DamageRequest.new()
	request.token = app.lifetime.token()
	request.actor_epoch = app.lifetime.actor_epoch
	request.health_epoch = boss.health.epoch
	request.target_id = &"boss"
	request.source_id = &"explicit_bgm_settlement_fixture"
	request.event_id = app._next_id("bgm_fixture_defeat")
	request.amount = boss.health.current
	check(app.policy.submit(request), "real policy accepts explicit lethal Boss settlement fixture")
	check(await wait_until(func() -> bool: return boss.health.terminal, 5000), "actual Boss health commits defeat")
	await frames()
	check(app._music.requested_track == expected and not boss.active, "actual Boss defeat returns to exploration music")
	observe("boss_defeated")
	if region_id == &"thorn_forest" and map_index == 2:
		# The fast settlement fixture can still be inside normal spawn/monster
		# protection. Wait for the real policy clock; never disable that guard.
		app.player.reset_at(region.spawn)
		var eligible := await wait_until(func() -> bool: return is_instance_valid(app.policy) and app.policy.clock >= maxf(app.policy._protected_until, app.policy._monster_until), 5000)
		check(eligible, "actual player protection expires before lethal fixture")
		if eligible and is_instance_valid(app.controller):
			var death := DamageRequest.new()
			death.token = app.lifetime.token()
			death.actor_epoch = app.lifetime.actor_epoch
			death.health_epoch = app.controller.actor_resources.health.epoch
			death.target_id = &"player"
			death.source_id = &"explicit_bgm_death_fixture"
			death.event_id = app._next_id("bgm_fixture_death")
			death.amount = app.controller.actor_resources.health.current
			check(app.policy.submit(death), "original policy accepts eligible lethal player fixture")
	else:
		app.abandon_run()
	check(await wait_until(func() -> bool: return app.director.state == DemoRunDirector.State.HOME and app.menu.visible_panel == &"run_end", 5000), "real run settlement returns to Home result page")
	await frames()
	check(app._music.requested_track == &"home", "death/abandon returns music to Home")
	observe("returned_home")

func retry_check() -> void:
	check(app.director.state == DemoRunDirector.State.HOME and app.menu.visible_panel == &"run_end", "retry starts from the actual settled result page")
	if app.director.state != DemoRunDirector.State.HOME or app.menu.visible_panel != &"run_end": return
	var previous_epoch := app.lifetime.epoch
	var target: Button
	for button: Button in app.menu._root.find_children("*", "Button", true, false):
		if button.text.begins_with("再次出发"): target = button
	check(target != null, "real settled page offers retry button")
	if target == null: return
	await frames()
	app.menu._scroll.ensure_control_visible(target)
	await frames()
	var point := target.get_global_rect().get_center()
	check(target.is_visible_in_tree() and root.get_visible_rect().has_point(point), "retry pointer target is visible in the actual native viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await frames(2)
	var presses: Array[int] = []
	target.pressed.connect(func() -> void: presses.append(1), CONNECT_ONE_SHOT)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await frames(2)
	check(presses.size() == 1, "actual retry pointer dispatch submits exactly once")
	check(await wait_until(func() -> bool: return app.director.state == DemoRunDirector.State.IN_STAGE and app.lifetime.epoch > previous_epoch and is_instance_valid(app.stage) and not app._stage_pending, 5000), "actual pointer retry starts a fresh real run")
	await frames()
	check(app.active_region_id == &"plains" and app._music.requested_track == &"plains", "retry selects fresh Plains exploration instead of stale Forest Boss")
	observe("pointer_retry")
	app.abandon_run()
	await frames(5)

func run() -> void:
	root.size = Vector2i(1280, 720)
	await gate_and_loop_checks()
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames()
	check(app.menu.visible_panel == &"title" and app._music.requested_track == &"home", "ordinary default title owns Home music")
	app._show_home()
	await frames()
	check(is_instance_valid(app.home_scene) and app._music.requested_track == &"home" and int(app._music.starts.get(&"home", 0)) == 1, "actual Home shares title track without restarting")
	for row: Array in [[&"plains", 1], [&"plains", 2], [&"thorn_forest", 1], [&"thorn_forest", 2]]:
		await encounter_checks(row[0], row[1])
	await retry_check()
	check(await app._music.shutdown(), "App music releases actual MP3 playback on shutdown")
	check(not app._music.request_track(&"forest_boss"), "late requests after shutdown cannot resurrect music")
	check(await load("res://tests/audio_teardown.gd").drain_world(app), "existing SFX teardown remains independent")
	var weak_music: WeakRef = weakref(app._music)
	app.free()
	await frames()
	check(weak_music.get_ref() == null and get_nodes_in_group(&"game_music").is_empty(), "App exit frees music service and leaves no stale owner")
	var directory := "res://build/verification/bgm-integration"
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "observations": observations,"loop_observations":loop_observations,"runner_sha256":FileAccess.get_sha256(get_script().resource_path),"music_sha256":FileAccess.get_sha256("res://scripts/audio/game_music.gd"),"audio_driver":AudioServer.get_driver_name(), "scope": "Actual native App/MP3 playback and two generated regions/four Boss instances; explicit position/lethal damage fixtures, native deferred-input fixture; not natural play, listening, browser activation, GPU or physical device acceptance."}, "  "))
	file.close()
	print("BGM INTEGRATION: %s checks, %s failures" % [checks, failures])
	quit(1 if failures else 0)
