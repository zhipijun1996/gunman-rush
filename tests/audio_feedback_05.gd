extends SceneTree
## Real formal App and original resource transactions; no audible/device claim.
const TEARDOWN := preload("res://tests/audio_teardown.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures.append(reason)
		push_error(reason)

func frames(count: int) -> void:
	for unused: int in count:
		await physics_frame
		await process_frame

func local_audio(app: DemoApp) -> Variant:
	for child: Node in app.get_children():
		var source := child.get_script() as Script
		while source != null:
			if source.resource_path == "res://scripts/audio/game_audio.gd": return child
			source = source.get_base_script()
	return null

func run() -> void:
	await exercise()
	await frames(4)
	print("AUDIO_FEEDBACK_05 checks=%d failures=%d" % [checks, failures.size()])
	quit.call_deferred(0 if failures.is_empty() else 1)

func exercise() -> void:
	root.size = Vector2i(1280, 720)
	var music := GameMusic.new()
	root.add_child(music)
	music._unlocked = false # Native gesture-state fixture, not browser permission.
	check(music.request_track(&"home") and int(music.starts.get(&"home", 0)) == 1, "Title issues player play before a gesture; browser autoplay policy stays with Godot")
	var active := music._ids.find(&"home")
	check(active >= 0 and music._voices[active].playing, "Initial title request owns the existing Home MP3 player immediately")
	check(is_equal_approx(music._gains[active], 1.0) and is_equal_approx(music._voices[active].volume_db, linear_to_db(GameMusic.MUSIC_GAIN * 0.7)), "Initial title player retains original mix gain")
	await frames(2)
	var elapsed_before := music._elapsed
	var cancelled := InputEventScreenTouch.new()
	cancelled.pressed = true
	cancelled.canceled = true
	music._input(cancelled)
	check(not music._unlocked and int(music.starts.get(&"home", 0)) == 1 and music._elapsed == elapsed_before, "Cancelled touch cannot mark activation or restart the requested title music")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	music._input(click)
	check(music._unlocked and music._voices[active].playing, "Accepted gesture records activation without replacing the already requested player")
	check(music._elapsed == elapsed_before and int(music.starts.get(&"home", 0)) == 1, "Real gesture does not reset the existing track or crossfade clock")
	music._input(click)
	music.request_track(&"home")
	check(music.starts.get(&"home", 0) == 1, "Repeated title/Home gestures never restart the same BGM")
	check(music.request_track(&"plains"), "Later region music request accepted")
	var next := music._ids.find(&"plains")
	check(next >= 0 and music._gains[next] == 0.0 and music._gains[active] == 1.0, "Later track still begins its original crossfade")
	check(await music.shutdown(), "Standalone music drain stays within original budget")
	music.free()

	var packed := load("res://scenes/demo/demo.tscn") as PackedScene
	var app := packed.instantiate() as DemoApp
	packed = null
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(6)
	check(app.menu.visible_panel == &"title" and app._music.requested_track == &"home" and int(app._music.starts.get(&"home", 0)) == 1, "Actual formal title immediately requests its existing BGM")
	check(app.menu._root.find_child("TitleEnableMusic", true, false) == null, "Title has no separate music activation button")
	var original_subtitle := false
	for node: Node in app.menu._root.find_children("*", "Label", true, false):
		if (node as Label).text == "风铃未息，旅途再启。": original_subtitle = true
	check(original_subtitle, "Original title subtitle is restored")
	var audio: Variant = local_audio(app)
	check(audio != null and audio.audio_profile == "selected" and audio._voices.size() == 12, "Real formal scene retains selected profile/shared12 voices")
	check(audio._selected_profiles.get("hurt") == "C" and audio._candidate_revisions.has(&"hurt"), "Frozen choice stays C; latest feedback is a separately named playback revision")
	check(not audio.configure_candidate_revision(&"missing_event", {"id":"bad", "variants":["res://assets/audio/feedback_05/hurt_1.wav"]}), "Revision cannot invent an unregistered event")
	check(not audio.configure_candidate_revision(&"hurt", {"id":"bad", "variants":["res://missing.wav"]}), "Missing revision stream rejected before changing current revision")
	app.menu.requested_enter_home.emit()
	await frames(20)
	check(app._music.requested_track == &"home" and int(app._music.starts.get(&"home", 0)) == 1, "Formal Home reuses the title track without restarting")
	var health: HealthState = app.home_scene.controller.actor_resources.health
	var before: int = audio.director_events.size()
	var request := ActorResourceRequest.new(&"feedback05/hurt", health.epoch, 1.0, health.get_instance_id())
	var result := health.apply_damage(request)
	check(result.status == ActorResourceResult.Status.APPLIED and result.amount_applied == -1.0, "Original HP transaction applies the explicit hurt fixture")
	check(audio.director_events.size() == before + 1, "One accepted HP loss emits exactly one hero hurt")
	var event: Dictionary = audio.director_events.back()
	check(event.id == &"hurt" and event.candidate == "hurt_feedback_06_a" and event.path == "res://assets/audio/feedback_06/hurt_a.wav", "Actual hero HP event uses the separately named new fracture/air audition A")
	health.apply_damage(request)
	check(audio.director_events.size() == before + 1, "Damage replay adds no hurt")
	await frames(12)
	audio.stop_director_cues()
	audio._director_last.erase(&"hurt")
	check(audio.play_director_event(&"hurt", "C", app), "Explicit old-C audition remains available")
	check(audio.director_events.back().candidate == "hurt_c" and audio.director_events.back().path == "res://assets/audio/director_v3/hurt_c.wav", "Historical C has not been overwritten by the revision")
	for profile: String in ["A", "B", "C"]:
		audio.stop_director_cues()
		audio._director_last.erase(&"hurt")
		var candidate: Dictionary = SelectedSfxRuntime.HURT_CANDIDATES[profile]
		check(audio.configure_candidate_revision(&"hurt", candidate), "Separate damage direction configures: " + profile)
		check(audio.play_director_event(&"hurt", "", app), "Existing shared dispatch accepts damage direction: " + profile)
		check(audio.director_events.back().candidate == candidate.id and audio.director_events.back().path == candidate.variants[0], "Actual damage path matches declared direction: " + profile)
		var playing := false
		for voice: AudioStreamPlayer in audio._voices:
			if voice.playing and voice.get_meta("director_event", &"") == &"hurt" and voice.stream.resource_path == candidate.variants[0]: playing = true
		check(playing and audio._voices.size() == 12, "Actual stream plays in unchanged12 pool: " + profile)
	check(not audio.configure_candidate_revision(&"hurt", {"id":"bad", "variants":["res://missing.wav"]}) and audio._candidate_revisions[&"hurt"].id == "hurt_feedback_06_c", "Invalid candidate keeps last valid direction")
	audio.configure_candidate_revision(&"hurt", SelectedSfxRuntime.HURT_CANDIDATES.A)
	audio.stop_director_cues()
	var walls: int = int(audio.played.get(&"weapon_wall", 0))
	check(app.home_scene.controller.shoot_ability.try_fire(Vector2.DOWN, app.home_scene.player.is_on_floor()), "Actual Home shot launches a normal projectile toward the real floor")
	await frames(35)
	check(int(audio.played.get(&"weapon_wall", 0)) > walls, "Real floor collision reaches solid-contact feedback")
	check(audio.weapon_clips[&"wall"].size() == 3 and audio.weapon_clips[&"wall"].all(func(clip: AudioStream) -> bool: return clip.resource_path == "res://assets/audio/feedback_05/wall_1.wav"), "Inherited three wall slots all alias the one selected authored take")
	for voice: AudioStreamPlayer in audio._voices:
		voice.stop()
		voice.stream = null
	audio._last_wall = -100.0
	check(audio.weapon_cue(&"wall", app.get_instance_id(), "rate-fixture", 17.0), "First bounded wall cue accepted")
	check(not audio.weapon_cue(&"wall", app.get_instance_id(), "rate-fixture", 17.0), "Same-frame wall flood is rejected by presentation cooldown")
	audio._last_wall = -100.0
	check(audio.weapon_cue(&"wall", app.get_instance_id(), "rate-fixture2", 17.0), "Second wall voice can be accepted after interval")
	audio._last_wall = -100.0
	check(not audio.weapon_cue(&"wall", app.get_instance_id(), "rate-fixture3", 17.0), "Wall never exceeds two concurrent voices")
	var wall_serial: int = audio._weapon_serial
	for slot: int in 3:
		for voice: AudioStreamPlayer in audio._voices:
			voice.stop()
			voice.stream = null
		audio._last_wall = -100.0
		check(audio.weapon_cue(&"wall", app.get_instance_id(), "single-take-fixture", 17.0), "Single wall take works at inherited serial slot %d" % slot)
		check(audio.weapon_events.back().variant == (wall_serial + slot) % 3 and audio._voices[0].stream.resource_path == "res://assets/audio/feedback_05/wall_1.wav" and is_equal_approx(audio._voices[0].volume_db, linear_to_db(audio.volume) - 17.0), "Compatibility slot keeps fixed source and original attenuation")
	# Explicit load fixture: a successful mechanism must outrank twelve steps.
	for voice: AudioStreamPlayer in audio._voices:
		voice.stop()
		voice.stream = audio._streams[&"bell"]
		voice.set_meta("cue_id", &"step")
		voice.set_meta("audio_priority", 20)
		voice.play()
	var preemptions: int = audio.director_preemptions
	check(audio.play(&"mechanism_bell") and audio.director_preemptions == preemptions + 1, "Mechanism can reclaim a low-priority voice under pool saturation")
	check(audio._voices.size() == 12, "Mechanism audibility does not grow the pool")
	paused = true
	check(not audio.play(&"mechanism_bell"), "World pause still prevents an uncommitted mechanism cue")
	paused = false
	audio.volume = 0.0
	check(not audio.play(&"mechanism_bell"), "Session mute still prevents a mechanism cue")
	audio.volume = 0.7
	check(await TEARDOWN.drain_world(app), "Real App voices and BGM release cleanly")
	app.free()
