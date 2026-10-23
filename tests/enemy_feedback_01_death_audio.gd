extends "res://tests/enemy_feedback_01_tests.gd"
## v7 tests actual Router/projectile deaths and the existing GameAudio voice pool.
## Metadata-only fixtures test ownership/disposal, never simulate accepted death.
## Stream identity, cue count and pause/lifetime evidence do not sign listening,
## timbre, mixing, loudness, player preference or physical-device sound quality.
const TASK_WAV := "res://assets/audio/enemy_feedback_01/death_burst.wav"
var audio_rows: Array[Dictionary] = []
var ownership_rows: Array[Dictionary] = []

func configured_stream(origin: Node) -> AudioStream:
	var value: Variant = origin.get_meta(GameAudio.CUE_STREAM_OVERRIDES_META,{})
	return value.get(&"enemy_defeat") as AudioStream if value is Dictionary else null

func metadata_ownership_cases() -> void:
	var origin := Node.new()
	root.add_child(origin)
	var prior := AudioStreamWAV.new()
	var unrelated := AudioStreamGenerator.new()
	origin.set_meta(GameAudio.CUE_STREAM_OVERRIDES_META,{&"enemy_defeat":prior,&"shot":unrelated})
	var helper := EnemyFeedback01DeathAudio.new()
	helper.configure(origin)
	helper.configure(origin)
	check(configured_stream(origin) != null and configured_stream(origin).resource_path == TASK_WAV, "idempotent helper configuration selects task stream without playing audio")
	var during: Dictionary = origin.get_meta(GameAudio.CUE_STREAM_OVERRIDES_META)
	during[&"late_other_entry"] = unrelated
	origin.set_meta(GameAudio.CUE_STREAM_OVERRIDES_META,during)
	helper.dispose()
	var restored: Dictionary = origin.get_meta(GameAudio.CUE_STREAM_OVERRIDES_META)
	check(restored.get(&"enemy_defeat") == prior and restored.get(&"shot") == unrelated and restored.get(&"late_other_entry") == unrelated, "helper disposal restores prior owned entry and preserves unrelated late metadata")
	check(helper.get("_origin") == null and helper.get("_previous") == null, "disposed helper releases origin and previous-value references")
	helper.configure(origin)
	var replacement := AudioStreamWAV.new()
	var external: Dictionary = origin.get_meta(GameAudio.CUE_STREAM_OVERRIDES_META)
	external[&"enemy_defeat"] = replacement
	origin.set_meta(GameAudio.CUE_STREAM_OVERRIDES_META,external)
	helper.dispose()
	check(configured_stream(origin) == replacement, "stale helper cleanup cannot overwrite a later owner's metadata entry")
	var empty_origin := Node.new()
	root.add_child(empty_origin)
	helper.configure(empty_origin)
	helper.dispose()
	check(not empty_origin.has_meta(GameAudio.CUE_STREAM_OVERRIDES_META), "dispose removes task-only metadata when origin originally had no entry")
	# Both helpers select the same cached STREAM. A stream-equality-only CAS
	# cannot identify the current owner; overlap must use the weak owner token.
	var overlap := Node.new()
	root.add_child(overlap)
	overlap.set_meta(GameAudio.CUE_STREAM_OVERRIDES_META,{&"enemy_defeat":prior,&"shot":unrelated})
	var older := EnemyFeedback01DeathAudio.new()
	var newer := EnemyFeedback01DeathAudio.new()
	older.configure(overlap)
	newer.configure(overlap)
	older.dispose()
	var owner_after_old: WeakRef = overlap.get_meta(EnemyFeedback01DeathAudio.OWNER_META,null) as WeakRef
	check(configured_stream(overlap) == EnemyFeedback01DeathAudio.STREAM and owner_after_old != null and owner_after_old.get_ref() == newer, "older cleanup cannot remove the newer owner even when both use the same cached task stream")
	check(older.get("_origin") == null, "displaced older audio helper releases its origin reference")
	newer.dispose()
	var overlap_restored: Dictionary = overlap.get_meta(GameAudio.CUE_STREAM_OVERRIDES_META,{})
	check(overlap_restored.get(&"enemy_defeat") == prior and overlap_restored.get(&"shot") == unrelated and not overlap.has_meta(EnemyFeedback01DeathAudio.OWNER_META), "final overlapping cleanup restores external prior stream and other key without resurrecting inactive older profile")
	older.configure(overlap)
	newer.configure(overlap)
	newer.dispose()
	var resumed_owner: WeakRef = overlap.get_meta(EnemyFeedback01DeathAudio.OWNER_META,null) as WeakRef
	check(resumed_owner != null and resumed_owner.get_ref() == older and configured_stream(overlap) == EnemyFeedback01DeathAudio.STREAM, "reverse cleanup resumes the still-live predecessor's owned profile")
	older.dispose()
	check(configured_stream(overlap) == prior and not overlap.has_meta(EnemyFeedback01DeathAudio.OWNER_META), "reverse overlapping cleanup ultimately restores the external original stream")
	overlap.queue_free()
	var freed_origin := Node.new()
	root.add_child(freed_origin)
	helper.configure(freed_origin)
	var origin_reference: WeakRef = weakref(freed_origin)
	freed_origin.queue_free()
	await process_frame
	await process_frame
	helper.dispose()
	check(origin_reference.get_ref() == null and helper.get("_origin") == null, "disposal after origin unload has no retained Actor/Node reference")
	ownership_rows.append({"prior_entry_restored":restored.get(&"enemy_defeat") == prior,"unrelated_entry_preserved":restored.get(&"late_other_entry") == unrelated,"external_new_owner_preserved":configured_stream(origin) == replacement,"no_cue_invocations":true,"scope":"metadata ownership only; never a simulated accepted death"})
	origin.queue_free()
	empty_origin.queue_free()
	await process_frame
	await process_frame

func pooled_voices(id: StringName) -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for voice: AudioStreamPlayer in audio._voices:
		if voice.get_meta("cue_id",&"") == id and voice.stream != null:
			result.append(voice)
	return result

func real_death_case(path: String, underworld: bool) -> void:
	await setup(path,underworld)
	var helper := art.get("feedback_death_audio") as EnemyFeedback01DeathAudio
	check(helper != null and configured_stream(actor) != null and configured_stream(actor).resource_path == TASK_WAV, "selected actual rendering chain configures task defeat timbre on its EnemyActor")
	var default_shot := audio._streams[&"shot"] as AudioStream
	var default_defeat := audio._streams[&"enemy_defeat"] as AudioStream
	check(default_defeat.resource_path == "res://assets/audio/kenney/enemy_defeat.ogg", "per-origin task stream leaves the shared default defeat stream intact")
	# A real shot's actual audio origin receives an intentionally irrelevant
	# metadata entry. GameAudio must ignore overrides for non-defeat cue IDs.
	var shot_origin := player.get_node("PlayerFeedback")
	shot_origin.set_meta(GameAudio.CUE_STREAM_OVERRIDES_META,{&"shot":configured_stream(actor)})
	check(int(audio.played.get(&"enemy_defeat",0)) == 0, "configured live enemy has no premature defeat cue")
	for hit: int in 2:
		check(await shoot_until_health_changes("v7_real_nonlethal_projectile"), "real Router/projectile supplies nonlethal accepted hit")
		check(int(audio.played.get(&"enemy_defeat",0)) == 0, "nonlethal hit cannot play task death sound")
		check(actor.health.current == actor.health.capacity-float(hit+1), "nonlethal audio observation retains original projectile damage")
	var shot_voices := pooled_voices(&"shot")
	check(not shot_voices.is_empty() and shot_voices.all(func(voice: AudioStreamPlayer) -> bool: return voice.stream == default_shot), "real shot voices keep original shot stream despite unrelated per-origin metadata")
	rejection_cases()
	check(int(audio.played.get(&"enemy_defeat",0)) == 0, "replay, invalid hits and old epochs cannot play premature defeat audio")
	check(await shoot_until_health_changes("v7_real_lethal_projectile"), "third genuine Router projectile commits actual lethal HP")
	check(actor.health.terminal and accepted.size() == 3 and int(audio.played.get(&"enemy_defeat",0)) == 1, "actual EnemyActor terminal transition plays exactly one existing enemy_defeat cue")
	var death_voices := pooled_voices(&"enemy_defeat")
	check(death_voices.size() == 1 and death_voices[0].stream.resource_path == TASK_WAV, "existing bounded voice pool plays task WAV with unchanged enemy_defeat cue ID")
	var pause_row: Dictionary = {}
	if death_voices.size() == 1:
		var voice := death_voices[0]
		check(voice.playing and voice.process_mode == Node.PROCESS_MODE_PAUSABLE, "actual active death voice uses existing world-pausable process mode")
		paused = true
		for _frame: int in 8: await process_frame
		check(not voice.can_process() and audio.can_process() and int(audio.played.get(&"enemy_defeat",0)) == 1, "pause blocks the active world voice without replaying defeat or pausing the audio service")
		pause_row = {"voice_path":str(voice.get_path()),"cue_id":str(voice.get_meta("cue_id")),"stream":voice.stream.resource_path,"playing":voice.playing,"process_mode":voice.process_mode,"can_process_while_paused":voice.can_process(),"stream_paused":voice.stream_paused}
		paused = false
	if not accepted.is_empty():
		check(not actor.damageable.receive_damage(accepted.back()), "actual lethal event replay refused before another cue")
		var old_epoch: Dictionary = accepted.back().duplicate()
		old_epoch.event_id = "v7_old_epoch_after_death"
		old_epoch.target_epoch = actor.health.epoch-1
		check(not actor.damageable.receive_damage(old_epoch), "old-epoch lethal contact refused before another cue")
	check(actor.restore_instance_health(0), "official same-instance saved-dead restore accepted")
	await restored_corpse_case(underworld)
	check(int(audio.played.get(&"enemy_defeat",0)) == 1, "duplicate, old epoch and saved-dead instances cannot replay task defeat audio")
	var listeners_before := actor.health.changed.get_connections().size()
	var damaged_before := actor.damageable.damaged.get_connections().size()
	var previous_helper := helper
	var previous_helper_reference: WeakRef = weakref(previous_helper)
	var installed: Dictionary = INSTALLER.install(world)
	art = enemy.get_node("Presentation") as Node2D
	helper = art.get("feedback_death_audio") as EnemyFeedback01DeathAudio
	await ticks(3,"v7_installer_replacement")
	check(helper != null and configured_stream(actor).resource_path == TASK_WAV, "formal installer retains task per-origin timbre after presentation replacement")
	check(actor.health.changed.get_connections().size() == listeners_before and actor.damageable.damaged.get_connections().size() == damaged_before, "installer replacement does not retain old health or damage listeners")
	if not underworld:
		check(installed.enemies == 1 and previous_helper.get("_origin") == null, "old original-chain helper relinquishes Actor reference during actual installer replacement")
		previous_helper = null
		await process_frame
		check(previous_helper_reference.get_ref() == null, "replaced presentation's old audio helper is released")
	else:
		check(installed.enemies == 0 and helper == previous_helper, "reinstalling current formal presentation preserves its one existing audio helper")
	check(int(audio.played.get(&"enemy_defeat",0)) == 1, "dead presentation replacement never invokes a second defeat cue")
	var meta_before_dispose: Dictionary = actor.get_meta(GameAudio.CUE_STREAM_OVERRIDES_META)
	meta_before_dispose[&"late_other_entry"] = default_shot
	actor.set_meta(GameAudio.CUE_STREAM_OVERRIDES_META,meta_before_dispose)
	enemy.remove_child(art)
	check(helper.get("_origin") == null and configured_stream(actor) == null, "actual host exit clears task-owned override and Actor reference")
	var after_dispose: Dictionary = actor.get_meta(GameAudio.CUE_STREAM_OVERRIDES_META,{})
	check(after_dispose.get(&"late_other_entry") == default_shot, "actual host disposal preserves unrelated per-origin metadata")
	art.queue_free()
	check(audio._streams[&"shot"] == default_shot and audio._streams[&"enemy_defeat"] == default_defeat and audio._voices.size() == GameAudio.MAX_VOICES, "task death timbre keeps original default streams and voice-pool capacity")
	audio_rows.append({"definition":path,"chain":"underworld" if underworld else "original","accepted_contexts":accepted.duplicate(true),"shots":shots.duplicate(true),"played":audio.played.duplicate(),"death_voice_pause":pause_row,"default_shot":default_shot.resource_path,"default_defeat":default_defeat.resource_path,"task_wav":TASK_WAV,"host_disposed_origin_null":helper.get("_origin") == null,"scope":"actual Router/projectile/Actor cue and pooled stream identity; no subjective listening certification"})
	previous_helper = null
	helper = null
	var actor_reference: WeakRef = weakref(actor)
	await cleanup()
	check(actor_reference.get_ref() == null, "actual arena unload releases EnemyActor after task audio cleanup")

func run() -> void:
	await metadata_ownership_cases()
	for path: String in SOURCES:
		for underworld: bool in [false,true]:
			await real_death_case(path,underworld)
	var hashes: Dictionary = {}
	for path: String in ["res://tests/enemy_feedback_01_death_audio.gd","res://scripts/enemies/enemy_feedback_01_death_audio.gd","res://scripts/audio/game_audio.gd","res://scripts/enemies/enemy_actor.gd",TASK_WAV]:
		hashes[path] = FileAccess.get_sha256(path)
	DirAccess.make_dir_recursive_absolute("res://build/enemy_feedback_01/v7")
	var file := FileAccess.open("res://build/enemy_feedback_01/v7/death_audio_runtime.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"task":"ENEMY-FEEDBACK-01","revision":"per_origin_death_audio_v7","checks":checks,"failures":failures,"metadata_ownership":ownership_rows,"actual_deaths":audio_rows,"source_sha256":hashes,"scope":"four real Router/projectile deaths across two species and both presentation chains; existing EnemyActor cue only; stream/pool/pause/restore/unload contract; subjective audio, loudness/mix and device listening unverified"},"\t"))
	file.close()
	print("ENEMY_FEEDBACK_01_DEATH_AUDIO checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
