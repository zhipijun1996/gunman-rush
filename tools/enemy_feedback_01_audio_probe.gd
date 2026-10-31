extends "res://tests/enemy_feedback_01_formal.gd"
## Read-only audio observation on the exact real App/projectile/drop fixture.
## This leaf changes no cue, stream, volume, cooldown, gameplay or audio service.
## It never invokes the parent run(), whose original report remains untouched.
var audio_rows: Array[Dictionary] = []
var _previous_played: Dictionary = {}

func ticks(count: int, phase: String) -> void:
	for _frame: int in count:
		await super.ticks(1, phase)
		var service := root.get_tree().get_first_node_in_group(&"game_audio") as GameAudio
		if service == null: continue
		var changes: Dictionary = {}
		for cue: Variant in service.played:
			var increment := int(service.played[cue]) - int(_previous_played.get(cue, 0))
			if increment > 0: changes[String(cue)] = increment
		var voices: Array[Dictionary] = []
		for voice: AudioStreamPlayer in service._voices:
			if not voice.playing: continue
			voices.append({"cue": String(voice.get_meta("cue_id", &"")), "volume_db": voice.volume_db,
				"position_seconds": voice.get_playback_position(), "process_mode": voice.process_mode,
				"stream_path": voice.stream.resource_path if voice.stream != null else ""})
		var row := {"tick": Engine.get_physics_frames(), "phase": phase, "played": service.played.duplicate(true),
			"new_played": changes, "voices": voices, "paused": paused, "voice_count": voices.size()}
		audio_rows.append(row)
		_previous_played = service.played.duplicate(true)
		if not trace.is_empty(): trace.back().audio = row.duplicate(true)

func run() -> void:
	var output_path := "res://build/enemy_feedback_01/audio-probe-%s.json" % Time.get_ticks_usec()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
	if FileAccess.file_exists(output_path):
		printerr("AUDIO PROBE refuses to overwrite existing evidence: ", output_path)
		quit(1)
		return
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_plains("enemy-feedback-01-formal"), "audio probe starts same actual default consumer")
	var ready := await stage_ready("audio_probe_default_start")
	check(ready, "audio observation begins after actual asynchronous readiness")
	if ready:
		app.player.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
		app.controller.shoot_ability.shot_fired.connect(func(direction: Vector2, id: int) -> void:
			shots.append({"id": id, "tick": Engine.get_physics_frames(), "direction": direction,
				"muzzle": app.controller.shoot_ability.last_muzzle, "player": app.player.position}))
		var stage := app.stage as PlainsRegionStage
		original_manifest = JSON.stringify(stage.generated.manifest)
		for index: int in stage.enemies.size():
			var actor := stage.enemies[index].get_node("Actor") as EnemyActor
			inventory.append({"id": stage.enemy_manifest[index].id, "stable_id": String(actor.definition.stable_id),
				"behavior": String(actor.definition.behavior_id), "position": stage.enemies[index].position})
		for stable_id: StringName in TARGETS: await verify_target(stable_id)
		await verify_actual_reload()
	app.abandon_run()
	check(await load("res://tests/audio_teardown.gd").drain_world(app), "probe drains original audio backend")
	app.free()
	for _frame: int in 4: await process_frame
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("AUDIO PROBE cannot write evidence: ", output_path)
		quit(1)
		return
	file.store_string(JSON.stringify({"task": "ENEMY-FEEDBACK-01", "checks": checks, "failures": failures,
		"ready": ready_receipts, "inventory": inventory, "targets": results, "shots": shots,
		"accepted_events": events, "trace": trace, "audio_rows": audio_rows,
		"scope": "Original real DemoApp and GameAudio observed after each frame; explicit initial player positioning, no stream/event/mix override",
		"limits": ["played increments measure accepted cue starts, not perceived loudness or clipping",
			"software fixed-FPS cannot measure device latency", "active voice playback follows AudioServer wall clock",
			"No listening or subjective quality verdict from counters"]}, "\t"))
	file.close()
	print("ENEMY_FEEDBACK_01_AUDIO_PROBE checks=%d failures=%d output=%s" % [checks, failures.size(), output_path])
	quit(0 if failures.is_empty() else 1)
