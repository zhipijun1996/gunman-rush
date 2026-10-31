extends SceneTree
## Sound transport and semantic dispatch only. Formal actions are covered by Lab.
var checks := 0
var failures: Array[String] = []
var audio: PlayerWeaponFeelAudioV2

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures.append(reason)
		push_error(reason)

func ticks(count: int) -> void:
	for unused: int in count: await process_frame

func fresh(profile: String = "A") -> void:
	audio.set_audio_profile("original")
	audio.set_audio_profile(profile)
	await ticks(8)

func active_event(id: StringName) -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for voice: AudioStreamPlayer in audio._voices:
		if voice.playing and voice.get_meta("director_event", &"") == id: result.append(voice)
	return result

func run() -> void:
	root.size = Vector2i(1280, 720)
	audio = PlayerWeaponFeelAudioV2.new()
	root.add_child(audio)
	var owner := Node.new()
	root.add_child(owner)
	await ticks(3)
	check(audio.audio_profile == "original", "Production default remains original")
	check(audio._voices.size() == GameAudio.MAX_VOICES, "Original shared pool stays twelve voices")
	for bus: StringName in [&"SFX", &"UI", &"Ambience", &"Music"]:
		var index := AudioServer.get_bus_index(bus)
		check(index > 0 and AudioServer.get_bus_send(index) == &"Master" and is_zero_approx(AudioServer.get_bus_volume_db(index)), "Unity %s bus exists without changing the mix" % bus)
	var original_streams := audio._streams.duplicate()
	var override := load("res://assets/audio/kenney/bell.ogg") as AudioStream
	owner.set_meta(GameAudio.CUE_STREAM_OVERRIDES_META, {&"enemy_defeat": override})
	GameAudio.cue(owner, &"enemy_defeat")
	check(audio._voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.stream == override), "Original origin-specific death override still owns the actual pooled stream")
	check(not audio.set_audio_profile("invalid"), "Unknown profile is refused")
	check(audio.set_audio_profile("A"), "Explicit A profile loads the actual candidate manifest")
	check(not audio.play_director_event(&"hook_pull", "original"), "Original has no dedicated traction layer; null legacy metadata is refused without a resource error")
	check(audio._streams == original_streams, "Candidate selection does not replace original bank resources")
	check(audio._voices.all(func(voice: AudioStreamPlayer) -> bool: return not voice.playing), "Profile switch clears old comparison tails")
	check(audio.play_director_event(&"shot"), "Actual shot candidate starts")
	check(not audio.play_director_event(&"shot"), "Same-frame high-frequency duplicate is limited")
	var first_variant := int(audio.director_events.back().variant)
	audio.stop_director_cues()
	await ticks(8)
	check(audio.play_director_event(&"shot"), "Shot can play again after its cooldown")
	check(int(audio.director_events.back().variant) != first_variant, "Two-input bank prevents consecutive repeated variants")
	await fresh()
	check(audio.motion_cue(&"jump", .5, owner.get_instance_id()), "Existing movement entry dispatches candidate")
	check(audio.weapon_cue(&"pulse", owner.get_instance_id(), "accepted-shot"), "Existing pulse entry dispatches one candidate")
	check(active_event(&"jump").size() == 1 and active_event(&"shot").size() == 1 and active_event(&"recoil").is_empty(), "Motion and basic gun share pool; recoil is integrated without a duplicate voice")
	audio.stop_motion(owner.get_instance_id())
	check(active_event(&"jump").is_empty() and active_event(&"shot").size() == 1, "Movement cleanup cannot swallow weapon feedback")
	audio.stop_weapon(owner.get_instance_id())
	check(active_event(&"shot").is_empty(), "Existing owner-based weapon cleanup stops its candidate")
	await fresh()
	GameAudio.cue_event(owner, &"enemy_hurt", &"hurt")
	GameAudio.cue(owner, &"hurt")
	check(active_event(&"enemy_hurt").size() == 1 and active_event(&"hurt").size() == 1, "Committed enemy hurt and player hurt have separate event families")
	await fresh()
	GameAudio.cue(owner, &"enemy_defeat")
	check(active_event(&"enemy_death").size() == 1 and not audio._voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.stream == override), "Opt-in enemy death deliberately chooses candidate instead of also playing old override")
	await fresh()
	GameAudio.hook_connected(owner)
	check(active_event(&"hook_connect").size() == 1 and active_event(&"hook_pull").size() == 1, "Accepted hook connection starts transient and cancellable traction layer")
	GameAudio.stop_origin(owner)
	check(active_event(&"hook_pull").is_empty() and active_event(&"hook_connect").size() == 1, "Hook phase exit stops traction while preserving short connection tail")
	await fresh()
	check(audio.play_director_event(&"hook_pull", "", owner, true), "Origin-owned phase cue starts")
	owner.queue_free()
	await ticks(3)
	check(active_event(&"hook_pull").is_empty(), "Origin unload cancels old phase playback")
	await fresh()
	paused = true
	check(not audio.play_director_event(&"shot"), "Pause refuses new world feedback")
	check(audio.play_director_event(&"denied"), "Pause permits UI feedback")
	check(active_event(&"denied")[0].process_mode == Node.PROCESS_MODE_ALWAYS, "UI player remains processable during pause")
	paused = false
	await fresh()
	var low_stream := load("res://assets/audio/director_candidates/hook_pull_a.wav") as AudioStream
	for voice: AudioStreamPlayer in audio._voices:
		voice.stream = low_stream
		voice.set_meta("audio_priority", 10)
		voice.play()
	check(audio.play_director_event(&"hurt"), "Critical feedback preempts a lower-priority full pool")
	check(audio.director_preemptions == 1 and audio._voices.size() == GameAudio.MAX_VOICES, "Preemption does not allocate a thirteenth voice")
	for voice: AudioStreamPlayer in audio._voices: voice.set_meta("audio_priority", 100)
	check(not audio.play_director_event(&"coin"), "Lower-priority reward cannot steal critical voices")
	check(audio.director_dropped >= 1, "Voice pressure produces an observable bounded drop")
	await fresh()
	for unused: int in 2:
		check(audio.play_director_event(&"shot"), "Configured event concurrency slot starts")
		await ticks(5)
	check(audio.play_director_event(&"shot"), "Third configured shot slot starts")
	await ticks(5)
	check(not audio.play_director_event(&"shot"), "Per-event cap refuses a fourth concurrent shot")
	for profile: String in ["A", "B"]:
		for critical: StringName in [&"death", &"warning", &"boss_impact"]:
			await fresh(profile)
			for voice: AudioStreamPlayer in audio._voices:
				voice.stream = low_stream
				voice.set_meta("audio_priority", 10)
				voice.play()
			var preemptions := audio.director_preemptions
			check(audio.play(critical), "%s retains critical legacy %s under a full low-priority candidate pool" % [profile, critical])
			check(audio.director_preemptions == preemptions + 1 and audio._voices.size() == GameAudio.MAX_VOICES, "Critical legacy %s steals one lower voice without increasing pool capacity" % critical)
			check(audio._voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and voice.get_meta("cue_id", &"") == critical and voice.stream == original_streams[critical]), "Critical %s keeps its genuine original stream" % critical)
	await fresh("original")
	for voice: AudioStreamPlayer in audio._voices:
		voice.stream = low_stream
		voice.set_meta("audio_priority", 10)
		voice.play()
	check(not audio.play(&"death"), "Original profile preserves its existing full-pool drop behavior")
	check(audio._streams == original_streams, "All candidate operations preserve original bank bytes and objects")
	check(await audio.shutdown(), "Actual backend playbacks drain with original bounded teardown")
	audio.queue_free()
	await ticks(3)
	check(get_nodes_in_group(&"game_audio").is_empty(), "Teardown releases the existing service")
	print("AUDIO_DIRECTOR_RUNTIME checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
