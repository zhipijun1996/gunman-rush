extends "res://tests/enemy_feedback_01_tests.gd"
## v8: latest user rejected the v7 custom sound. The existing EnemyActor cue
## must play its original pooled stream once. No task sound is approved here.
## Counts/identity/pause/lifecycle do not certify subjective listening quality.
const OVERRIDES_META := &"audio_cue_stream_overrides"
const OWNER_META := &"enemy_feedback_01_death_audio_owner"
const DEFAULT_DEFEAT := "res://assets/audio/kenney/enemy_defeat.ogg"
var audio_rows: Array[Dictionary] = []

func no_task_audio(origin: Node) -> bool:
	var overrides: Variant = origin.get_meta(OVERRIDES_META, {})
	return (not overrides is Dictionary or not overrides.has(&"enemy_defeat")) and not origin.has_meta(OWNER_META)

func pooled_voices(id: StringName) -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for voice: AudioStreamPlayer in audio._voices:
		if voice.get_meta("cue_id", &"") == id and voice.stream != null:
			result.append(voice)
	return result

func real_death_case(path: String, underworld: bool) -> void:
	await setup(path, underworld)
	check(no_task_audio(actor), "selected actual rendering chain does not install the rejected task death-stream override")
	var default_shot := audio._streams[&"shot"] as AudioStream
	var default_defeat := audio._streams[&"enemy_defeat"] as AudioStream
	check(default_defeat.resource_path == DEFAULT_DEFEAT, "existing default enemy_defeat stream is restored")
	check(int(audio.played.get(&"enemy_defeat", 0)) == 0, "live enemy has no premature defeat cue")
	for hit: int in 2:
		check(await shoot_until_health_changes("v8_real_nonlethal_projectile"), "real Router projectile supplies original nonlethal accepted hit")
		check(int(audio.played.get(&"enemy_defeat", 0)) == 0, "nonlethal hit never plays defeat sound")
		check(actor.health.current == actor.health.capacity-float(hit+1), "audio observation preserves original projectile damage")
	var shot_voices := pooled_voices(&"shot")
	check(not shot_voices.is_empty() and shot_voices.all(func(voice: AudioStreamPlayer) -> bool: return voice.stream == default_shot), "real shot voices retain the original shot stream")
	rejection_cases()
	check(int(audio.played.get(&"enemy_defeat", 0)) == 0, "replay, invalid hits and old epochs cannot play premature defeat audio")
	check(await shoot_until_health_changes("v8_real_lethal_projectile"), "third genuine Router projectile commits actual lethal HP")
	check(actor.health.terminal and accepted.size() == 3 and int(audio.played.get(&"enemy_defeat", 0)) == 1, "actual EnemyActor terminal transition plays exactly one existing enemy_defeat cue")
	var death_voices := pooled_voices(&"enemy_defeat")
	check(death_voices.size() == 1 and death_voices[0].stream == default_defeat and death_voices[0].stream.resource_path == DEFAULT_DEFEAT, "existing bounded voice pool plays original defeat stream, without the rejected custom WAV")
	var pause_row: Dictionary = {}
	if death_voices.size() == 1:
		var voice := death_voices[0]
		check(voice.playing and voice.process_mode == Node.PROCESS_MODE_PAUSABLE, "actual active death voice uses world-pausable process mode")
		paused = true
		for _frame: int in 8: await process_frame
		check(not voice.can_process() and audio.can_process() and int(audio.played.get(&"enemy_defeat", 0)) == 1, "pause blocks active world voice without replaying defeat or pausing audio service")
		pause_row = {"stream": voice.stream.resource_path, "playing": voice.playing, "process_mode": voice.process_mode, "can_process_while_paused": voice.can_process(), "stream_paused": voice.stream_paused}
		paused = false
	if not accepted.is_empty():
		check(not actor.damageable.receive_damage(accepted.back()), "actual lethal event replay refused before another cue")
		var old_epoch: Dictionary = accepted.back().duplicate()
		old_epoch.event_id = "v8_old_epoch_after_death"
		old_epoch.target_epoch = actor.health.epoch-1
		check(not actor.damageable.receive_damage(old_epoch), "old-epoch lethal contact refused before another cue")
	check(actor.restore_instance_health(0), "official same-instance saved-dead restore accepted")
	await restored_corpse_case(underworld)
	check(int(audio.played.get(&"enemy_defeat", 0)) == 1, "duplicate, old epoch and saved-dead instances cannot replay default defeat audio")
	var listeners_before := actor.health.changed.get_connections().size()
	var damaged_before := actor.damageable.damaged.get_connections().size()
	var old_host: WeakRef = weakref(art)
	var installed: Dictionary = INSTALLER.install(world)
	art = enemy.get_node("Presentation") as Node2D
	await ticks(3, "v8_installer_replacement")
	check(no_task_audio(actor), "formal installer replacement retains original death cue without task metadata")
	check(actor.health.changed.get_connections().size() == listeners_before and actor.damageable.damaged.get_connections().size() == damaged_before, "installer replacement retains no old health or damage listener")
	check((installed.enemies == 0 and old_host.get_ref() == art) if underworld else (installed.enemies == 1 and old_host.get_ref() == null), "actual installer is idempotent for current host and releases replaced original host")
	check(int(audio.played.get(&"enemy_defeat", 0)) == 1, "dead presentation replacement never invokes a second defeat cue")
	enemy.remove_child(art)
	check(no_task_audio(actor), "actual host exit leaves no task override or audio ownership metadata on the Actor")
	art.queue_free()
	check(audio._streams[&"shot"] == default_shot and audio._streams[&"enemy_defeat"] == default_defeat and audio._voices.size() == GameAudio.MAX_VOICES, "default streams and existing voice-pool capacity remain intact")
	audio_rows.append({"definition": path, "chain": "underworld" if underworld else "original", "accepted_contexts": accepted.duplicate(true), "shots": shots.duplicate(true), "played": audio.played.duplicate(), "death_voice_pause": pause_row, "default_shot": default_shot.resource_path, "default_defeat": default_defeat.resource_path, "no_task_audio_metadata": no_task_audio(actor), "scope": "actual Router/projectile/Actor cue and original pooled stream; no subjective listening certification"})
	var actor_reference: WeakRef = weakref(actor)
	await cleanup()
	check(actor_reference.get_ref() == null, "arena unload releases EnemyActor without task audio ownership")

func run() -> void:
	for path: String in SOURCES:
		for underworld: bool in [false, true]:
			await real_death_case(path, underworld)
	var hashes: Dictionary = {}
	for path: String in [get_script().resource_path, "res://scripts/audio/game_audio.gd", "res://scripts/enemies/enemy_actor.gd", DEFAULT_DEFEAT]:
		hashes[path] = FileAccess.get_sha256(path)
	DirAccess.make_dir_recursive_absolute("res://build/enemy_feedback_01/v8")
	var file := FileAccess.open("res://build/enemy_feedback_01/v8/death_audio_runtime.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"task": "ENEMY-FEEDBACK-01", "revision": "frames_persistent_corpse_and_original_audio_v8", "checks": checks, "failures": failures, "actual_deaths": audio_rows, "source_sha256": hashes, "changed_expectation": "Latest user explicitly rejected custom death sound: verify original default once; v7 custom metadata ownership assertions remain historical evidence only.", "scope": "four real Router/projectile deaths across two species and both chains; default stream/pool/pause/restore/unload; listening quality unverified"}, "\t"))
	file.close()
	print("ENEMY_FEEDBACK_01_DEATH_AUDIO checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
