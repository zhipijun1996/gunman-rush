extends SceneTree
## Real consumers, deterministic equivalent inputs and native playback provenance.
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, reason: String) -> void:
	checks += 1
	if not value: failures.append(reason); push_error(reason)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var lab := preload("res://experiments/audio/entries/audio_director_reels.tscn").instantiate() as AudioDirectorReels
	root.add_child(lab)
	for unused: int in 240:
		await physics_frame
		if lab.lab_ready: break
	check(lab.lab_ready and lab.lab_audio.has_director_event(&"shot_pulse") and lab.lab_audio.has_director_event(&"chest_open"), "V3 real Home fixture configures explicit V3 bank")
	check(not lab.meta_persistence_enabled and lab.lab_audio._voices.size() == 12, "Fixture saves disabled and original twelve voices reused")
	var audio := lab.lab_audio
	check(audio.director_event_for_weapon_cue(&"pulse", &"pulse_gun") == &"shot_pulse" and audio.director_event_for_weapon_cue(&"blade", &"shadow_shuriken") == &"shot_shuriken" and audio.director_event_for_weapon_cue(&"blast", &"recoil_bomb") == &"bomb_explode", "Exact accepted weapon identities select their own V3 events")
	check(audio.director_event_for_weapon_cue(&"blade", &"fan_shuriken").is_empty() and audio.director_event_for_weapon_cue(&"pulse", &"triple_machine_gun") == &"shot", "Other blade/pulse identities preserve earlier routes")
	audio.set_audio_profile("original")
	var original_count := int(audio.played.get(&"weapon_pulse", 0))
	audio.weapon_cue(&"pulse", lab.get_instance_id(), "original_route", 12, false, &"pulse_gun")
	check(int(audio.played.get(&"weapon_pulse", 0)) == original_count + 1, "Original profile keeps original weapon stream despite V3 bank")
	audio.configure_candidate_bank("res://assets/audio/director_v2/manifest.json", "res://config/audio_director/v2/runtime.json")
	check(audio.director_event_for_weapon_cue(&"pulse", &"pulse_gun") == &"shot" and audio.director_event_for_weapon_cue(&"blade", &"shadow_shuriken").is_empty(), "V2 bank retains earlier pulse/blade routing")
	audio.configure_candidate_bank("res://assets/audio/director_v3/manifest.json", "res://config/audio_director/v3/runtime.json")
	audio.set_audio_profile("A")
	audio.play_director_event(&"shot_pulse", "", lab)
	check(audio._voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and voice.get_meta("director_family", &"") == &"weapon"), "New weapon event uses shared weapon lifetime family")
	audio.stop_weapon(lab.get_instance_id())
	check(not audio._voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and voice.get_meta("director_family", &"") == &"weapon"), "Owner cleanup stops new weapon event family")
	for reel: String in AudioDirectorReels.REELS:
		check(await lab.capture_reel(reel, "res://build/audio_director_v3/reels-runtime/" + reel), "Capture actions finish: " + reel)
		var signatures: Array[Array] = []
		for segment: Dictionary in lab.segments:
			var events: Array = segment.events.map(func(e: Dictionary) -> String: return str(e.event_id))
			var expected: Array = [reel]
			if reel == "ui": expected = ["click", "confirm", "denied"]
			elif reel == "mix": expected = ["coin", "heal", "enemy_hit", "hurt"]
			elif reel == "weapons": expected = ["shot_pulse", "shot_shuriken", "shot_bomb", "bomb_explode"]
			check(expected.all(func(id: String) -> bool: return id in events), "%s %s contains actual expected receipts: %s" % [reel, segment.profile, expected])
			if segment.profile != "original":
				check(expected.all(func(id: String) -> bool: return int(segment.played_delta.get("director_" + id, 0)) == 1), "%s %s actually plays exactly one candidate for each accepted target" % [reel, segment.profile])
			if reel in ["coin", "heal", "chest_open", "item_get"]:
				check(events == expected, "%s %s has only target sound receipt and no preparatory hurt" % [reel, segment.profile])
			if reel in ["chest_open", "item_get"]:
				check(segment.events[0].details.build_count == 1, "%s %s original RewardService adds actual item once" % [reel, segment.profile])
			var sequence: Array = []
			for row: Dictionary in lab.reel_trace:
				if row.profile == segment.profile: sequence.append([row.position, row.hp, row.enemy_hp])
			signatures.append(sequence)
		check(signatures.all(func(seq: Array) -> bool: return seq == signatures[0]), reel + " all four sound profiles retain identical seeded input/position/health sequence")
	check(not lab.lab_audio.has_director_event(&"jump") and not lab.lab_audio.has_director_event(&"land"), "V3 retains original accepted jump and landing family")
	_check_material_audition_policy(audio, lab)
	check(await lab._music.shutdown(), "Original music drains")
	check(await lab.lab_audio.shutdown(), "Original voice pool drains")
	lab.free()
	for unused: int in 4: await process_frame
	check(get_nodes_in_group(&"game_audio").is_empty(), "No stale audio service remains")
	DirAccess.make_dir_recursive_absolute("res://build/audio_director_v3/reels-runtime")
	FileAccess.open("res://build/audio_director_v3/reels-runtime/receipt.json", FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}))
	print("AUDIO_DIRECTOR_REELS checks=%s failures=%s" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check_material_audition_policy(audio: GameAudio, origin: Node) -> void:
	# Direct service-policy fixture supplements the unchanged real-damage reels.
	# No altered Actor identity or synthetic accepted-damage receipt is used.
	var hurt_stream := PlainsEnemyAudio.STREAMS[&"plant_hurt"] as AudioStream
	for profile: String in ["A", "B", "C"]:
		check(audio.set_audio_profile(profile), "%s policy fixture selects the existing candidate profile" % profile)
		audio.set_audition_focus(&"")
		var legacy_before := int(audio.played.get(&"hurt", 0))
		var candidate_before := int(audio.played.get(&"director_enemy_hurt", 0))
		check(audio.play_enemy_material(&"hurt", hurt_stream, origin, &"plains_sentry") and int(audio.played.get(&"hurt", 0)) == legacy_before + 1 and int(audio.played.get(&"director_enemy_hurt", 0)) == candidate_before, "%s without audition focus preserves material hurt" % profile)
		check(audio._voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and voice.stream == hurt_stream and voice.get_meta("director_event", &"") == &"plains_enemy_hurt"), "%s ordinary material route plays the current plant WAV" % profile)
		audio.set_audition_focus(&"enemy_hurt")
		legacy_before = int(audio.played.get(&"hurt", 0))
		check(audio.play_enemy_material(&"hurt", hurt_stream, origin, &"plains_sentry") and int(audio.played.get(&"director_enemy_hurt", 0)) == candidate_before + 1 and int(audio.played.get(&"hurt", 0)) == legacy_before, "%s explicit hurt audition plays one candidate without doubling material" % profile)
		var candidate_id := "enemy_hurt_" + profile.to_lower()
		check(audio.director_events.back().candidate == candidate_id and audio._voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and voice.get_meta("director_event", &"") == &"enemy_hurt" and voice.stream.resource_path == "res://assets/audio/director_v3/" + candidate_id + ".wav"), "%s audition owns the actual selected candidate stream" % profile)
		audio.set_audition_focus(&"")
		check(audio.play_enemy_material(&"hurt", hurt_stream, origin, &"plains_sentry") and int(audio.played.get(&"hurt", 0)) == legacy_before + 1 and int(audio.played.get(&"director_enemy_hurt", 0)) == candidate_before + 1, "%s clearing audition focus restores material playback" % profile)
		audio.set_audition_focus(&"enemy_hit")
		check(not audio.play_enemy_material(&"hurt", hurt_stream, origin, &"plains_sentry") and int(audio.played.get(&"hurt", 0)) == legacy_before + 1 and int(audio.played.get(&"director_enemy_hurt", 0)) == candidate_before + 1, "%s weapon-hit focus still suppresses the body layer" % profile)
	check(audio.set_audio_profile("original"), "Original material audition profile is available")
	audio.set_audition_focus(&"enemy_hurt")
	var original_before := int(audio.played.get(&"hurt", 0))
	var candidates_before := audio.director_events.size()
	check(audio.play_enemy_material(&"hurt", hurt_stream, origin, &"plains_sentry") and int(audio.played.get(&"hurt", 0)) == original_before + 1 and audio.director_events.size() == candidates_before and audio._voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and voice.stream == hurt_stream), "Original hurt audition preserves the current material stream without candidate playback")
	check(audio.set_audio_profile("A"), "Non-hurt policy fixture selects a candidate profile")
	for kind: StringName in [&"death", &"land"]:
		var material_stream := PlainsEnemyAudio.STREAMS[StringName("plant_" + String(kind))] as AudioStream
		var material_event := StringName("plains_enemy_" + String(kind))
		check(audio.play_enemy_material(kind, material_stream, origin, &"plains_sentry") and audio.director_events.size() == candidates_before and audio._voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and voice.stream == material_stream and voice.get_meta("director_event", &"") == material_event), "%s retains species material during explicit hurt audition" % kind)
	audio.set_audition_focus(&"")
	check(audio.configure_selected_profiles({&"enemy_hurt": "B"}) and audio.set_audio_profile("selected"), "Explicit selected profile fixture retains the adopted enemy candidate choice")
	var selected_before := audio.director_events.size()
	var selected_hurt_before := int(audio.played.get(&"hurt", 0))
	check(audio.play_enemy_material(&"hurt", hurt_stream, origin, &"plains_sentry") and int(audio.played.get(&"hurt", 0)) == selected_hurt_before + 1 and audio.director_events.size() == selected_before and audio._voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and voice.stream == hurt_stream), "Selected profile without audition focus keeps the latest species material")
