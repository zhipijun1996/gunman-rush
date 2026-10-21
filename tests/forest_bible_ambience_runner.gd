extends SceneTree
## Actual local Node/GameAudio service contracts. Dummy audio is not listening,
## a rendered animation review, formal campaign coverage, or device evidence.
var checks: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var diagnostics: Array[Dictionary] = []
var failures := 0
var world: Node2D
var audio: GameAudio
var actor: Node2D
var ambience: ForestBibleAmbience
var output_dir := "build/region_bible_v2/ambience/native"

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output_dir = argument.trim_prefix("--output-dir=")
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"label":label,"passed":ok})
	if not ok:
		failures += 1
		print("FAIL: ", label)

func frames(count: int) -> void:
	for index: int in count: await process_frame

func fixture(layout := "forest-bible-world-v15") -> void:
	await cleanup()
	world = Node2D.new()
	root.add_child(world)
	audio = GameAudio.new()
	world.add_child(audio)
	actor = Node2D.new()
	actor.position = Vector2(100, 100)
	world.add_child(actor)
	ambience = ForestBibleAmbience.new()
	ambience.configure({"layout_version":layout,"platforms":[{"one_way":true,"rect":[250,150,120,16]}],"hook_anchors":[{"position":[380,100]}]}, actor)
	world.add_child(ambience)
	await frames(2)

func cleanup() -> void:
	paused = false
	if is_instance_valid(audio): check(await audio.shutdown(), "fixture actual audio playback releases before world teardown")
	if is_instance_valid(world): world.queue_free()
	world = null
	audio = null
	actor = null
	ambience = null
	await frames(2)

func count_cue(id: StringName) -> int:
	return int(audio.played.get(id, 0))

func regional_playbacks() -> Array[WeakRef]:
	var result: Array[WeakRef] = []
	for voice: AudioStreamPlayer in audio._voices:
		if GameAudio.REGIONAL_CUE_PATHS.has(voice.get_meta("cue_id", &"")) and voice.has_stream_playback():
			result.append(weakref(voice.get_stream_playback()))
	return result

func wait_release(references: Array[WeakRef]) -> bool:
	var deadline := Time.get_ticks_msec()+1000
	while references.any(func(reference: WeakRef) -> bool: return reference.get_ref() != null):
		if Time.get_ticks_msec() >= deadline: return false
		await process_frame
	return true

func regional_stopped() -> bool:
	for voice: AudioStreamPlayer in audio._voices:
		if GameAudio.REGIONAL_CUE_PATHS.has(voice.get_meta("cue_id", &"")) and (voice.playing or voice.stream != null): return false
	return true

func voice_for(id: StringName) -> AudioStreamPlayer:
	for voice: AudioStreamPlayer in audio._voices:
		if voice.get_meta("cue_id", &"") == id: return voice
	return null

func pool_case() -> void:
	await fixture()
	check(audio._voices.size() == 12 and audio.get_child_count() == 12, "actual service creates exactly twelve voice nodes")
	check(GameAudio.CUES.size() == 25 and GameAudio.REGIONAL_CUE_PATHS.size() == 3, "regional sources preserve original twenty-five cues")
	for id: StringName in GameAudio.REGIONAL_CUE_PATHS:
		var stream: AudioStream = audio._streams.get(id)
		check(stream != null and stream.resource_path == GameAudio.REGIONAL_CUE_PATHS[id], "actual regional stream loaded " + str(id))
	var ids: Array[StringName] = [&"forest_wind",&"forest_fruit",&"forest_web",&"focus_start",&"focus_end",&"enemy_defeat",&"door",&"warning",&"boss_impact",&"click",&"confirm",&"coin"]
	for id: StringName in ids:
		check(audio.play(id) and count_cue(id) == 1, "actual pool accepts and counts " + str(id))
		var voice := voice_for(id)
		check(voice != null and voice.playing and voice.has_stream_playback() and voice.stream == audio._streams[id], "actual live voice retains matching cue_id and playback " + str(id))
	check(not audio.play(&"note") and count_cue(&"note") == 0, "thirteenth simultaneous cue is dropped without count")
	check(audio._voices.size() == 12 and audio.get_child_count() == 12, "pool saturation does not allocate a thirteenth voice")
	var tags: Array[String] = []
	for voice: AudioStreamPlayer in audio._voices: tags.append(str(voice.get_meta("cue_id", &"")))
	check(not tags.has("") and tags.size() == 12, "every occupied voice has an actual cue_id tag")
	cases.append({"id":"pool","voices":audio._voices.size(),"loaded_regional":GameAudio.REGIONAL_CUE_PATHS.size(),"tags":tags,"played":audio.played.duplicate()})

func pause_case() -> void:
	await fixture()
	for index: int in 200:
		if ambience._clock >= 2.85: break
		await frames(1)
	check(ambience._clock >= 2.85 and ambience._clock < 3.0 and count_cue(&"forest_wind") == 0, "real node approaches its first wind before pause")
	paused = true
	var frozen := ambience._clock
	var before := audio.played.duplicate()
	ambience.notify_fruit(actor.global_position)
	ambience.notify_web(actor.global_position)
	check(not audio.play(&"forest_wind"), "service rejects a new regional world voice while paused")
	await frames(30)
	check(ambience._clock == frozen and audio.played == before, "real paused frames freeze local wind clock and start no world sounds")
	check(audio.play(&"click"), "same paused service still accepts original UI click")
	paused = false
	for index: int in 30:
		if count_cue(&"forest_wind") > 0: break
		await frames(1)
	check(count_cue(&"forest_wind") == 1 and ambience._clock >= 3.0, "resumed real process starts exactly one due wind")
	await frames(30)
	check(count_cue(&"forest_wind") == 1, "wind does not restart on subsequent adjacent process frames")
	cases.append({"id":"pause","frozen_clock":frozen,"resume_clock":ambience._clock,"wind_count":count_cue(&"forest_wind"),"ui_click_count":count_cue(&"click")})

func event_case() -> void:
	await fixture()
	var at := actor.global_position
	for rejected: Vector2 in [at+Vector2(801,0), Vector2.INF, Vector2(NAN,0)]:
		ambience.notify_fruit(rejected)
		ambience.notify_web(rejected)
	check(count_cue(&"forest_fruit") == 0 and count_cue(&"forest_web") == 0 and ambience._bursts.is_empty(), "far and nonfinite events cannot start audio or bursts")
	ambience.notify_fruit(at+Vector2(800,0))
	check(count_cue(&"forest_fruit") == 1 and ambience._bursts.size() == 1, "nearby accepted fruit event starts one actual cue and burst")
	ambience.notify_fruit(at)
	check(count_cue(&"forest_fruit") == 1 and ambience._bursts.size() == 1, "same-frame fruit repeats are bounded")
	await frames(16)
	ambience.set_reduced_effects(true)
	check(ambience._bursts.is_empty() and ambience._reduced, "reduced setting clears an already live burst")
	ambience.notify_fruit(at)
	ambience.notify_web(at)
	ambience.notify_web(at)
	check(count_cue(&"forest_fruit") == 2 and count_cue(&"forest_web") == 1 and ambience._bursts.is_empty(), "reduced mode keeps accepted SFX but starts no burst and web repeats are bounded")
	ambience.set_reduced_effects(false)
	await frames(16)
	ambience.notify_fruit(at)
	check(ambience._bursts.size() == 1 and count_cue(&"forest_fruit") == 3, "restored effects accept a new event after cooldown")
	await frames(50)
	check(ambience._bursts.is_empty(), "real process reclaims expired event bursts")
	cases.append({"id":"events","fruit_count":count_cue(&"forest_fruit"),"web_count":count_cue(&"forest_web"),"remaining_bursts":ambience._bursts.size()})
	ambience.configure({"layout_version":"forest-fruit-routes-v14"}, actor)
	var disabled_before := audio.played.duplicate()
	ambience.notify_fruit(at)
	ambience.notify_web(at)
	await frames(190)
	check(ambience._clock == 0.0 and not ambience.is_processing() and audio.played == disabled_before, "historical layout remains disabled through real frames and event calls")
	cases.append({"id":"historical_disabled","clock":ambience._clock,"played_unchanged":audio.played == disabled_before})

func observe_audio(label: String) -> void:
	# Passive diagnostics: never stop/start voices or advance either clock.
	var voices: Array[Dictionary] = []
	var free_voices: int = 0
	for voice: AudioStreamPlayer in audio._voices:
		if not voice.playing: free_voices += 1
		voices.append({"instance_id":voice.get_instance_id(),"cue_id":str(voice.get_meta("cue_id", &"")),"playing":voice.playing,"stream_paused":voice.stream_paused,"stream_path":voice.stream.resource_path if voice.stream != null else "","stream_instance_id":voice.stream.get_instance_id() if voice.stream != null else 0,"playback_id":voice.get_stream_playback().get_instance_id() if voice.has_stream_playback() else 0,"process_mode":voice.process_mode})
	var stream_ids: Array[String] = []
	for id: Variant in audio._streams.keys(): stream_ids.append(str(id))
	stream_ids.sort()
	var row: Dictionary = {"label":label,"wall_msec":Time.get_ticks_msec(),"process_frames":Engine.get_process_frames(),"service_instance_id":audio.get_instance_id(),"service_inside_tree":audio.is_inside_tree(),"service_shutting_down":audio._shutting_down,"tree_paused":paused,"service_clock":audio._clock,"ambience_clock":ambience._clock if is_instance_valid(ambience) else -1.0,"ambience_processing":ambience.is_processing() if is_instance_valid(ambience) else false,"volume":audio.volume,"stream_ids":stream_ids,"free_voices":free_voices,"played":audio.played.duplicate(),"last_cue_clocks":audio._last.duplicate(),"voices":voices}
	diagnostics.append(row)
	print("FOREST BIBLE AMBIENCE AUDIO SNAPSHOT: ", JSON.stringify(row))

func stop_case() -> void:
	await fixture()
	# This case manually owns cue scheduling. Backend release uses real wall
	# time; fixed-FPS frames during that wait must not schedule extra winds.
	# The preceding pause case independently exercises the live wind clock.
	ambience.set_process(false)
	var manual_clock: float = ambience._clock
	observe_audio("stop_fixture_ready")
	check(audio.play(&"victory"), "selective stop fixture starts an actual original cue")
	var old_voice := voice_for(&"victory")
	var old_stream: AudioStream = old_voice.stream if old_voice != null else null
	for id: StringName in GameAudio.REGIONAL_CUE_PATHS: check(audio.play(id), "selective stop fixture starts " + str(id))
	observe_audio("before_selective_stop")
	var stopped_refs := regional_playbacks()
	check(stopped_refs.size() == 3, "selective stop records three actual weak regional playback references")
	GameAudio.stop_region(ambience)
	observe_audio("after_selective_stop")
	check(regional_stopped(), "static stop_region stops and detaches all regional streams")
	check(old_voice != null and old_voice.playing and old_voice.stream == old_stream, "regional stop preserves an in-flight original cue")
	observe_audio("before_selective_backend_wait")
	check(await wait_release(stopped_refs), "selective stop releases actual regional backend playbacks within wall-clock bound")
	observe_audio("after_selective_backend_wait")
	check(not ambience.is_processing() and ambience._clock == manual_clock and count_cue(&"forest_wind") == 1, "manual selective-stop fixture stays frozen and schedules no new wind during real backend wait")
	check(not audio._shutting_down and audio.play(&"roar"), "regional stop leaves service active for original cues")
	observe_audio("after_original_roar_attempt")
	await frames(8)
	observe_audio("before_regional_restart_attempts")
	for id: StringName in GameAudio.REGIONAL_CUE_PATHS:
		check(audio.play(id), "unload fixture restarts " + str(id))
		observe_audio("after_restart_attempt_"+str(id))
	var unload_refs := regional_playbacks()
	check(unload_refs.size() == 3, "unload observes actual regional playback objects")
	check(ambience._clock == manual_clock and count_cue(&"forest_wind") == 2, "frozen fixture contains exactly two explicit wind starts before unload")
	var ambience_ref: WeakRef = weakref(ambience)
	var count_before := audio.played.duplicate()
	world.remove_child(ambience)
	ambience.free()
	ambience = null
	observe_audio("after_actual_ambience_exit")
	check(regional_stopped(), "actual ambience exit_tree stops and detaches regional voices")
	check(old_voice != null and old_voice.stream == old_stream, "ambience exit leaves original cue stream attached")
	observe_audio("before_unload_backend_wait")
	var released := await wait_release(unload_refs)
	observe_audio("after_unload_backend_wait")
	check(released and ambience_ref.get_ref() == null, "removed ambience and actual regional backend playbacks release")
	await frames(15)
	check(audio.played == count_before, "removed ambience cannot start delayed sounds")
	cases.append({"id":"selective_stop_unload","regional_refs":stopped_refs.size(),"unload_refs":unload_refs.size(),"released":released,"ambience_released":ambience_ref.get_ref() == null,"old_stream_preserved":old_voice != null and old_voice.stream == old_stream})

func actor_case() -> void:
	await fixture()
	check(ambience._actor is WeakRef and ambience._actor_node() == actor, "consumer stores actor as a weak reference")
	var actor_ref: WeakRef = weakref(actor)
	actor.queue_free()
	actor = null
	await frames(2)
	check(actor_ref.get_ref() == null and ambience._actor_node() == null, "actor leaves actual tree while ambience survives without retention")
	ambience.notify_fruit(Vector2(100,100))
	ambience.notify_web(Vector2(100,100))
	await frames(190)
	check(audio.played.is_empty() and ambience._bursts.is_empty(), "missing actor rejects events and autonomous wind without stale reference")
	cases.append({"id":"actor_release","actor_released":actor_ref.get_ref() == null,"played":audio.played.duplicate()})

func _run() -> void:
	await pool_case()
	await pause_case()
	await event_case()
	await stop_case()
	await actor_case()
	await cleanup()
	DirAccess.make_dir_recursive_absolute(output_dir)
	var data := {"assertions":checks.size(),"failures":failures,"checks":checks,"cases":cases,"audio_diagnostics":diagnostics,"scope":"actual local Node and bounded GameAudio; audio listening, rendered AV, campaign and device unverified"}
	var file := FileAccess.open(output_dir.path_join("capture.json"), FileAccess.WRITE)
	if file == null:
		print("FAIL: native capture file could not be opened")
		quit(1)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("FOREST BIBLE AMBIENCE: %s assertions, %s failures" % [checks.size(),failures])
	print("FOREST BIBLE AMBIENCE CLEANUP: released=", str(world == null and audio == null and actor == null and ambience == null))
	quit(0 if failures == 0 else 1)
