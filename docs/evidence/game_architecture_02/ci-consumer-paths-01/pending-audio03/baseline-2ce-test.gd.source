extends SceneTree
## Accepted formal focus/weapon events plus a bounded real-collision bell fixture.
## No natural campaign, audible mix, browser or physical-device acceptance claim.
const TEARDOWN := preload("res://tests/audio_teardown.gd")
const PLAYER := preload("res://scenes/player/player.tscn")
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

func played_total(audio: Variant) -> int:
	var total := 0
	for value: Variant in audio.played.values(): total += int(value)
	return total

func fixture_frames(controller: PlayerController, count: int) -> void:
	for unused: int in count:
		await physics_frame
		controller.physics_tick(1.0 / 60.0)
		await process_frame

func run() -> void:
	await exercise()
	await frames(4)
	print("AUDIO_FIX_03 checks=%d failures=%d" % [checks, failures.size()])
	quit.call_deferred(0 if failures.is_empty() else 1)

func exercise() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/demo/demo.tscn") as PackedScene
	var app := packed.instantiate() as DemoApp
	packed = null
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(6)
	var audio: Variant = local_audio(app)
	check(audio != null and audio.audio_profile == "selected" and audio._voices.size() == 12, "Real formal assembly retains selected profile and original12-voice pool")
	var selection: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/audio_director/selected/selected.json"))
	check(audio._selected_profiles == selection.event_profiles, "All14 retained workshop choices remain exact")
	check(audio.director_profile_for_event(&"shot_pulse") == "A", "Selected Pulse A remains active")
	check(GameMusic.TRACKS.size() == 5, "Five original BGM options remain")
	app.menu.requested_enter_home.emit()
	await frames(16)
	var controller := app.home_scene.controller
	var motor := app.home_scene.player
	check(controller.shoot_ability.weapon.id == &"pulse_gun", "Fresh formal Home uses actual original pulse weapon")
	var music_id: int = app._music.get_instance_id()
	var music_starts: Dictionary = app._music.starts.duplicate(true)
	controller.router.request_action(&"jump")
	await frames(8)
	check(not motor.is_on_floor(), "Actual Home Router jump creates the airborne focus fixture")
	var focus := controller.air_focus_ability
	var before_focus: int = played_total(audio)
	var focus_start: int = int(audio.played.get(&"focus_start", 0))
	var focus_end: int = int(audio.played.get(&"focus_end", 0))
	focus.advance(0.05, false, true)
	check(focus.active and is_equal_approx(Engine.time_scale, motor.tuning.focus_time_scale), "Accepted airborne aim still starts original slow time")
	check(played_total(audio) == before_focus, "Entering actual focus adds no sound")
	focus.stop()
	check(not focus.active and is_equal_approx(Engine.time_scale, 1.0), "Aim cancellation restores original time scale")
	check(played_total(audio) == before_focus, "Leaving actual focus adds no sound")
	focus.advance(0.05, false, true)
	var event_begin: int = audio.director_events.size()
	var before_shot: int = played_total(audio)
	check(controller.shoot_ability.try_fire(Vector2.DOWN, false), "Actual airborne pulse shot is accepted")
	check(not focus.active and is_equal_approx(Engine.time_scale, 1.0), "Accepted shot ends focus without altering its gameplay contract")
	check(motor.recoil_burst_remaining > 0.0 and motor.recoil_velocity.y < 0.0, "Original physical upward recoil still executes")
	var events: Array = audio.director_events.slice(event_begin)
	check(events.size() == 1 and events[0].id == "shot_pulse" and events[0].candidate == "shot_pulse_a" and events[0].path == "res://assets/audio/director_v3/shot_pulse_a.wav", "One accepted shot retains exact selected Pulse A without an extra recoil event")
	check(played_total(audio) == before_shot + 1 and int(audio.played.get(&"focus_start", 0)) == focus_start and int(audio.played.get(&"focus_end", 0)) == focus_end, "Aim exit and recoil add no extra cue to the selected shot")
	check(app._music.get_instance_id() == music_id and app._music.starts == music_starts, "Aim/shot audio changes do not restart or replace BGM")
	controller.router.clear("audio-fix-fixture")
	controller.active = false
	controller.set_physics_process(false)

	# Isolated geometry only; the existing formal selected service owns audio.
	# Offset from Home so unrelated authored geometry cannot intercept this shot.
	var world := Node2D.new()
	world.position = Vector2(10000, 6000)
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(250, 620)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(500, 40)
	shape.shape = rect
	floor_body.add_child(shape)
	world.add_child(floor_body)
	var actor := PLAYER.instantiate() as PlayerMotor
	actor.position = Vector2(120, 582)
	world.add_child(actor)
	var fixture_controller := actor.get_node("Controller") as PlayerController
	fixture_controller.set_physics_process(false)
	var lifetime := DemoLifetime.new()
	var latch := ShotLatch.new()
	world.add_child(latch)
	latch.setup(fixture_controller, lifetime, Vector2(270, 535), Rect2(460, 330, 24, 270))
	await fixture_frames(fixture_controller, 6)
	check(latch.BELL_SOUND == GameAudio.MECHANISM_BELL_SOUND and latch._bell_audio.stream == GameAudio.MECHANISM_BELL_SOUND, "Mechanism and isolated fallback bind the exact existing plains_chime_a source")
	check(audio._streams[&"mechanism_bell"] == GameAudio.MECHANISM_BELL_SOUND, "Formal service registers dedicated mechanism cue independently of selected14-event bank")
	var rings: int = int(audio.played.get(&"mechanism_bell", 0))
	var old_bell: int = int(audio.played.get(&"bell", 0))
	check(fixture_controller.shoot_ability.try_fire(Vector2.UP, true), "Real miss fixture fires an accepted projectile")
	await fixture_frames(fixture_controller, 25)
	check(not latch.is_open and int(audio.played.get(&"mechanism_bell", 0)) == rings, "A real shot that misses the mechanism does not ring")
	var aim := (latch.to_global(latch.bell_position) - actor.global_position).normalized()
	check(fixture_controller.shoot_ability.try_fire(aim, true), "Real bell-directed projectile is accepted")
	await fixture_frames(fixture_controller, 25)
	check(latch.is_open and latch.open_count == 1 and int(audio.played.get(&"mechanism_bell", 0)) == rings + 1, "Actual projectile collision commits one opening and one dedicated chime")
	check(audio._voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and voice.get_meta("cue_id", &"") == &"mechanism_bell" and voice.stream == GameAudio.MECHANISM_BELL_SOUND), "Accepted mechanism uses the new source in the unchanged shared pool")
	check(int(audio.played.get(&"bell", 0)) == old_bell and not latch._bell_audio.playing, "Formal chime neither plays generic hook bell nor doubles the fallback voice")
	var duplicate := {"request_epoch": latch._request_epoch, "token": lifetime.token(), "session": fixture_controller.session_id, "health_epoch": latch.health.epoch}
	latch._commit_open(duplicate)
	check(latch.open_count == 1 and int(audio.played.get(&"mechanism_bell", 0)) == rings + 1, "Rejected duplicate committed request cannot ring again")
	var cancelled := ShotLatch.new()
	world.add_child(cancelled)
	cancelled.setup(fixture_controller, lifetime, Vector2(350, 535), Rect2(480, 330, 12, 270))
	cancelled.cancel()
	var cancelled_request := {"request_epoch": cancelled._request_epoch, "token": lifetime.token(), "session": fixture_controller.session_id, "health_epoch": cancelled.health.epoch}
	cancelled._commit_open(cancelled_request)
	check(not cancelled.is_open and int(audio.played.get(&"mechanism_bell", 0)) == rings + 1, "Cancelled mechanism's deferred request adds no chime")
	paused = true
	check(not audio.play(&"mechanism_bell"), "SceneTree pause blocks new world chimes")
	paused = false
	var volume: float = audio.volume
	audio.volume = 0.0
	check(not audio.play(&"mechanism_bell"), "Session mute blocks new chimes")
	audio.volume = volume
	check(audio._voices.size() == 12 and audio._selected_profiles == selection.event_profiles, "New mechanism feedback preserves shared budget and all existing selections")
	fixture_controller.active = false
	fixture_controller.shoot_ability.clear_projectiles()
	latch.cancel()
	lifetime.end()
	check(await TEARDOWN.drain_world(world), "Isolated fallback voices drain within existing teardown budget")
	world.free()
	check(await TEARDOWN.drain_world(app), "Formal SFX/BGM drain within existing teardown budget")
	app.free()
