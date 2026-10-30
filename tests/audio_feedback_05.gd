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
	music._unlocked = false # Native emulation only; real browser is separate.
	check(music.request_track(&"home") and music.starts.is_empty(), "Locked music queues Home without pretending browser permission")
	var cancelled := InputEventScreenTouch.new()
	cancelled.pressed = true
	cancelled.canceled = true
	music._input(cancelled)
	check(not music._unlocked and music.starts.is_empty(), "Cancelled touch cannot unlock/start music")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	music._input(click)
	var active := music._ids.find(&"home")
	check(active >= 0 and music._voices[active].playing, "Accepted title gesture starts existing Home BGM synchronously")
	check(is_equal_approx(music._gains[active], 1.0) and is_equal_approx(music._voices[active].volume_db, linear_to_db(GameMusic.MUSIC_GAIN * 0.7)), "First track starts at original mix gain before another frame/Home construction")
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
	var audio: Variant = local_audio(app)
	check(audio != null and audio.audio_profile == "selected" and audio._voices.size() == 12, "Real formal scene retains selected profile/shared12 voices")
	check(audio._selected_profiles.get("hurt") == "C" and audio._candidate_revisions.has(&"hurt"), "Frozen choice stays C; latest feedback is a separately named playback revision")
	check(not audio.configure_candidate_revision(&"missing_event", {"id":"bad", "variants":["res://assets/audio/feedback_05/hurt_1.wav"]}), "Revision cannot invent an unregistered event")
	check(not audio.configure_candidate_revision(&"hurt", {"id":"bad", "variants":["res://missing.wav"]}), "Missing revision stream rejected before changing current revision")
	app.menu.requested_enter_home.emit()
	await frames(20)
	var health: HealthState = app.home_scene.controller.actor_resources.health
	var before: int = audio.director_events.size()
	var request := ActorResourceRequest.new(&"feedback05/hurt", health.epoch, 1.0, health.get_instance_id())
	var result := health.apply_damage(request)
	check(result.status == ActorResourceResult.Status.APPLIED and result.amount_applied == -1.0, "Original HP transaction applies the explicit hurt fixture")
	check(audio.director_events.size() == before + 1, "One accepted HP loss emits exactly one hero hurt")
	var event: Dictionary = audio.director_events.back()
	check(event.id == &"hurt" and event.candidate == "hurt_feedback_05" and event.path in ["res://assets/audio/feedback_05/hurt_1.wav", "res://assets/audio/feedback_05/hurt_2.wav"], "Actual hero HP event uses the new soft-body source")
	health.apply_damage(request)
	check(audio.director_events.size() == before + 1, "Damage replay adds no hurt")
	await frames(12)
	audio.stop_director_cues()
	audio._director_last.erase(&"hurt")
	check(audio.play_director_event(&"hurt", "C", app), "Explicit old-C audition remains available")
	check(audio.director_events.back().candidate == "hurt_c" and audio.director_events.back().path == "res://assets/audio/director_v3/hurt_c.wav", "Historical C has not been overwritten by the revision")
	audio.stop_director_cues()
	var walls: int = int(audio.played.get(&"weapon_wall", 0))
	check(app.home_scene.controller.shoot_ability.try_fire(Vector2.DOWN, app.home_scene.player.is_on_floor()), "Actual Home shot launches a normal projectile toward the real floor")
	await frames(35)
	check(int(audio.played.get(&"weapon_wall", 0)) > walls, "Real floor collision reaches solid-contact feedback")
	check(audio.weapon_clips[&"wall"][0].resource_path == "res://assets/audio/feedback_05/wall_1.wav", "Formal wall family binds the licensed new stone/air takes")
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
