extends SceneTree
## Mixed-profile transport on the real inherited service, not a sound-quality vote.
## The developer must explicitly configure and enable selected; gameplay defaults
## and the current original weapon/motion generators remain the authority.
const V3_BANK := "res://assets/audio/director_v3/manifest.json"
const V3_RULES := "res://config/audio_director/v3/runtime.json"
const V1_BANK := "res://assets/audio/director_candidates/manifest.json"
const V1_RULES := "res://config/audio_director/runtime.json"
const CHOICES := {
	"coin": "A", "heal": "A", "chest_open": "A", "item_get": "C",
	"click": "C", "confirm": "C", "denied": "C",
	"enemy_hit": "B", "enemy_hurt": "B", "hurt": "C",
	"shot_pulse": "A", "shot_shuriken": "original",
	"shot_bomb": "original", "bomb_explode": "original",
}
var checks := 0
var failures: Array[String] = []
var audio: PlayerWeaponFeelAudioV2
var owner: Node

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures.append(reason)
		push_error(reason)

func silence() -> void:
	# Exercise real comparison switches, preserving the explicitly configured map.
	audio.set_audio_profile("original")
	audio.set_audio_profile("selected")

func active_event(id: StringName) -> Array[AudioStreamPlayer]:
	var voices: Array[AudioStreamPlayer] = []
	for voice: AudioStreamPlayer in audio._voices:
		if voice.playing and voice.get_meta("director_event", &"") == id: voices.append(voice)
	return voices

func active_original(id: StringName, bank: Array) -> bool:
	return audio._voices.any(func(voice: AudioStreamPlayer) -> bool:
		return voice.playing and voice.get_meta("cue_id", &"") == id and bank.has(voice.stream))

func expect_candidate(id: StringName, profile: String, action: Callable) -> void:
	silence()
	var before := audio.director_events.size()
	action.call()
	var candidate_id := "%s_%s" % [id, profile.to_lower()]
	check(audio.director_events.size() == before + 1 and str(audio.director_events.back().candidate) == candidate_id, "Mixed selected dispatch chooses exactly %s" % candidate_id)
	var voices := active_event(id)
	check(voices.size() == 1 and str(voices[0].stream.resource_path).begins_with("res://assets/audio/director_v3/" + candidate_id), "Actual pooled playback loads the selected %s file" % candidate_id)

func run() -> void:
	root.size = Vector2i(1280, 720)
	audio = PlayerWeaponFeelAudioV2.new()
	root.add_child(audio)
	owner = Node.new()
	root.add_child(owner)
	await process_frame
	check(audio.audio_profile == "original", "Ready never loads or enables user selections")
	check(not audio.set_audio_profile("selected"), "Selected is unavailable before explicit configuration")
	check(audio.configure_candidate_bank(V3_BANK, V3_RULES), "Explicit V3 bank loads")
	check(not audio.set_audio_profile("selected"), "Loading a bank alone cannot enable selected")
	var choices := CHOICES.duplicate()
	check(audio.configure_selected_profiles(choices), "The uploaded mixed direction map validates")
	check(audio.audio_profile == "original" and audio.director_profile_for_event(&"coin") == "original", "Configuring choices alone leaves original active")
	check(audio.set_audio_profile("selected"), "Selected is enabled only by an explicit profile switch")
	for event: String in CHOICES:
		check(audio.director_profile_for_event(StringName(event)) == CHOICES[event], "Resolver preserves the selected direction for " + event)
	choices["coin"] = "B"
	check(audio.director_profile_for_event(&"coin") == "A", "Caller dictionary mutation cannot change the configured selection")
	check(audio.director_profile_for_event(&"jump") == "original" and audio.director_profile_for_event(&"unknown") == "original", "Missing selected events resolve to original")
	check(audio._voices.size() == GameAudio.MAX_VOICES and audio.get_child_count() == GameAudio.MAX_VOICES, "Selected reuses exactly the existing twelve players")

	expect_candidate(&"coin", "A", func() -> void: GameAudio.cue(owner, &"coin"))
	expect_candidate(&"heal", "A", func() -> void: audio.play(&"heal"))
	expect_candidate(&"chest_open", "A", func() -> void: GameAudio.cue_event(owner, &"chest_open", &"confirm"))
	expect_candidate(&"item_get", "C", func() -> void: GameAudio.cue_event(owner, &"item_get", &"note"))
	expect_candidate(&"click", "C", func() -> void: audio._click())
	expect_candidate(&"confirm", "C", func() -> void: audio.play(&"confirm"))
	expect_candidate(&"denied", "C", func() -> void: GameAudio.cue(owner, &"denied"))
	expect_candidate(&"enemy_hit", "B", func() -> void: audio.weapon_cue(&"hit", owner.get_instance_id(), "committed-hit"))
	expect_candidate(&"enemy_hurt", "B", func() -> void: GameAudio.cue_event(owner, &"enemy_hurt", &"hurt"))
	expect_candidate(&"hurt", "C", func() -> void: GameAudio.cue(owner, &"hurt"))
	expect_candidate(&"shot_pulse", "A", func() -> void: audio.weapon_cue(&"pulse", owner.get_instance_id(), "accepted-pulse", 12, false, &"pulse_gun"))

	for weapon_case: Array in [[&"blade", &"shadow_shuriken"], [&"blast", &"recoil_bomb"], [&"blade", &"fan_shuriken"], [&"pulse", &"triple_machine_gun"]]:
		silence()
		var before := audio.director_events.size()
		var cue_id: StringName = weapon_case[0]
		var weapon_id: StringName = weapon_case[1]
		check(audio.weapon_cue(cue_id, owner.get_instance_id(), "accepted-original", 12, false, weapon_id), "Original selected/fallback weapon entry remains playable: " + weapon_id)
		check(active_original(StringName("weapon_" + cue_id), audio.weapon_clips[cue_id]) and audio.director_events.size() == before, "Original weapon uses its actual three-variant generator, not generic manifest legacy: " + weapon_id)
	silence()
	var bomb_before := audio.director_events.size()
	GameAudio.cue_event(owner, &"shot_bomb", &"")
	check(audio.director_events.size() == bomb_before and audio._voices.all(func(voice: AudioStreamPlayer) -> bool: return not voice.playing), "Original bomb release keeps its original absence of a dedicated throw sound")
	for motion: StringName in [&"jump", &"land", &"heavy"]:
		silence()
		check(audio.motion_cue(motion, .5, owner.get_instance_id()), "Unselected original motion still plays: " + motion)
		check(active_original(StringName("motion_" + motion), PlayerMotionAudio.MOTION[motion]), "Unselected motion keeps its actual original motion family: " + motion)

	# Reject a complete proposal atomically, retaining both selected mapping and
	# active playback. These malformed inputs never touch production bank files.
	silence()
	check(audio.play_director_event(&"coin"), "Selected event starts before invalid proposals")
	var preserved_voice := active_event(&"coin")[0]
	var preserved_stream := preserved_voice.stream
	for invalid: Dictionary in [{"unknown": "A"}, {"coin": "D"}, {"coin": 1}, {1: "A"}, {"coin": "selected"}, {"coin": "a"}, {"coin": null}]:
		check(not audio.configure_selected_profiles(invalid), "Malformed selected proposal is rejected atomically: " + str(invalid))
		check(audio.audio_profile == "selected" and audio.director_profile_for_event(&"coin") == "A" and preserved_voice.playing and preserved_voice.stream == preserved_stream, "Rejected proposal preserves the prior mapping and current playback")
	var candidates: Array = audio._director_bank[&"coin"].candidates
	audio._director_bank[&"coin"].candidates = candidates.filter(func(candidate: Dictionary) -> bool: return candidate.id != "coin_c")
	check(not audio.configure_selected_profiles({"coin": "C"}), "A declared profile without the actual event candidate is rejected")
	check(audio.director_profile_for_event(&"coin") == "A" and preserved_voice.playing, "Missing-candidate rejection does not damage the old valid selection")
	audio._director_bank[&"coin"].candidates = candidates
	check(not audio.configure_candidate_bank("res://absent-selected-bank.json", V3_RULES) and audio.audio_profile == "selected" and preserved_voice.playing, "Failed bank reload is atomic too")

	check(audio.configure_selected_profiles({"confirm": "C", "chest_open": "original"}), "A new selection replaces the old map as one operation")
	check(not preserved_voice.playing and audio.director_profile_for_event(&"coin") == "original", "Selection replacement clears old voices and removes omitted previous choices")
	for fallback_map: Dictionary in [{"confirm": "C", "chest_open": "original"}, {"confirm": "C"}]:
		audio.configure_selected_profiles(fallback_map)
		var before := audio.director_events.size()
		GameAudio.cue_event(owner, &"chest_open", &"confirm")
		check(active_original(&"confirm", [audio._streams[&"confirm"]]) and audio.director_events.size() == before, "Semantic original fallback cannot borrow a different event's selected confirm C")
	check(audio.configure_selected_profiles(CHOICES), "Mixed selection is restored explicitly")
	silence()
	paused = true
	check(not audio.play(&"coin") and not audio.weapon_cue(&"pulse", owner.get_instance_id(), "paused", 12, false, &"pulse_gun"), "Pause blocks selected world and weapon feedback")
	check(audio.play(&"confirm") and active_event(&"confirm")[0].process_mode == Node.PROCESS_MODE_ALWAYS, "Selected C UI feedback remains live while paused")
	check(audio.set_audio_profile("original") and audio._voices.all(func(voice: AudioStreamPlayer) -> bool: return not voice.playing), "Profile switching clears active selected voices even during pause")
	check(audio.set_audio_profile("selected") and audio.director_profile_for_event(&"coin") == "A", "Comparison switching preserves the explicit map for returning to selected")
	paused = false
	check(audio.play_director_event(&"coin", "B", owner), "Explicit candidate argument can audition B despite selected coin A")
	check(str(audio.director_events.back().candidate) == "coin_b" and audio.director_profile_for_event(&"coin") == "A", "Explicit audition does not rewrite the selected direction")
	silence()
	check(audio.play_director_event(&"shot_pulse", "", owner), "Selected weapon candidate tracks an actual origin weak reference")
	owner.queue_free()
	for unused: int in 3: await process_frame
	check(active_event(&"shot_pulse").is_empty(), "Origin removal cleans the selected candidate playback")
	owner = Node.new()
	root.add_child(owner)

	check(audio.configure_candidate_bank(V1_BANK, V1_RULES), "Old bank can be explicitly reconfigured")
	check(audio.audio_profile == "original" and not audio.set_audio_profile("selected"), "Bank replacement clears selected configuration and resets original")
	check(audio.configure_selected_profiles({"coin": "A", "hook_connect": "original", "hook_pull": "B"}) and audio.set_audio_profile("selected"), "Old-bank selected map permits independent connection/pull choices")
	for motion: StringName in [&"jump", &"land", &"heavy"]:
		silence()
		check(audio.motion_cue(motion, .5, owner.get_instance_id()) and active_original(StringName("motion_" + motion), PlayerMotionAudio.MOTION[motion]), "A bank containing motion candidates still falls back to the unselected original generator: " + motion)
	silence()
	GameAudio.hook_connected(owner)
	check(active_original(&"bell", [audio._streams[&"bell"]]) and active_event(&"hook_pull").size() == 1 and active_event(&"hook_connect").is_empty(), "Selected original connection and B traction dispatch independently")
	GameAudio.stop_origin(owner)
	check(active_event(&"hook_pull").is_empty(), "Selected traction keeps existing phase cancellation")
	check(audio.configure_selected_profiles({"hook_connect": "A", "hook_pull": "original"}), "Connection-only selection replaces old traction mapping")
	GameAudio.hook_connected(owner)
	check(active_event(&"hook_connect").size() == 1 and active_event(&"hook_pull").is_empty(), "Selected A connection cannot accidentally start original traction candidate")
	check(audio.configure_selected_profiles({}) and audio.audio_profile == "selected", "Explicit empty selection is a valid all-original comparison")
	check(audio.director_profile_for_event(&"hook_connect") == "original" and audio._voices.all(func(voice: AudioStreamPlayer) -> bool: return not voice.playing), "Empty selection clears previous choices and voices")
	check(audio._voices.size() == GameAudio.MAX_VOICES and audio.get_child_count() == GameAudio.MAX_VOICES, "All selection and bank changes retain exactly twelve voice nodes")
	check(await audio.shutdown(), "Actual backend playbacks drain through the existing bounded lifecycle")
	check(not audio.configure_selected_profiles({"coin": "A"}) and not audio.set_audio_profile("selected"), "Shutdown is terminal for selected configuration and activation")
	audio.free()
	owner.free()
	await process_frame
	check(get_nodes_in_group(&"game_audio").is_empty(), "Selected service teardown leaves no stale service")
	print("AUDIO_DIRECTOR_SELECTED checks=%s failures=%s" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
