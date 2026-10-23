extends SceneTree
## Independent UNIT probe of the metadata interface; no accepted gameplay hits.
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func run() -> void:
	var origin := Node.new()
	root.add_child(origin)
	for entry: Variant in [null, "not-a-dictionary", {}, {&"enemy_defeat":null}, {&"enemy_defeat":"not-a-stream"}]:
		var service := GameAudio.new()
		root.add_child(service)
		if entry != null: origin.set_meta(GameAudio.CUE_STREAM_OVERRIDES_META, entry)
		else: origin.remove_meta(GameAudio.CUE_STREAM_OVERRIDES_META)
		GameAudio.cue(origin, &"enemy_defeat")
		check(int(service.played.get(&"enemy_defeat",0)) == 1 and service._voices[0].stream == service._streams[&"enemy_defeat"], "missing/null/nonDict/invalid candidate uses default stream")
		check(await service.shutdown(), "fallback service releases actual mixer playback")
		service.free()
	var service := GameAudio.new()
	root.add_child(service)
	GameAudio.cue(null, &"enemy_defeat")
	var orphan := Node.new()
	GameAudio.cue(orphan, &"enemy_defeat")
	orphan.free()
	check(service.played.is_empty(), "null and outside-tree origins cannot cue")
	origin.set_meta(GameAudio.CUE_STREAM_OVERRIDES_META,{&"shot":EnemyFeedback01DeathAudio.STREAM})
	GameAudio.cue(origin,&"shot")
	check(service._voices[0].stream == service._streams[&"shot"], "non-defeat cue ignores per-origin override")
	check(not service.play(&"unknown",EnemyFeedback01DeathAudio.STREAM), "override cannot add unknown cue id")
	service.volume = 0
	GameAudio.cue(origin,&"enemy_defeat")
	check(not service.played.has(&"enemy_defeat"), "mute rejects overridden cue")
	service.volume = .7
	origin.set_meta(GameAudio.CUE_STREAM_OVERRIDES_META,{&"enemy_defeat":EnemyFeedback01DeathAudio.STREAM})
	GameAudio.cue(origin,&"enemy_defeat")
	check(int(service.played.get(&"enemy_defeat",0)) == 1 and service._voices[1].stream == EnemyFeedback01DeathAudio.STREAM, "valid override selects actual existing voice")
	GameAudio.cue(origin,&"enemy_defeat")
	check(int(service.played.get(&"enemy_defeat",0)) == 1, "override retains cooldown rejection")
	check(await service.shutdown(), "interface service releases actual playback")
	service.free()
	service = GameAudio.new()
	root.add_child(service)
	var generator := AudioStreamGenerator.new()
	for index: int in GameAudio.MAX_VOICES:
		service._clock += 1.0
		check(service.play(&"enemy_defeat",generator), "unit synthetic long voice fills existing pool")
	service._clock += 1.0
	check(not service.play(&"enemy_defeat",EnemyFeedback01DeathAudio.STREAM) and service._voices.size() == 12 and int(service.played[&"enemy_defeat"]) == 12, "full pool rejects without extra voices or accepted count")
	check(await service.shutdown(), "full pool releases actual mixer playback")
	service.free()
	origin.free()
	await process_frame
	var file := FileAccess.open("res://build/enemy-feedback-01/v7-review/interface-unit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"interface UNIT only; no formal hit or natural campaign"},"\t"))
	file.close()
	print("V7 INTERFACE UNIT: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
