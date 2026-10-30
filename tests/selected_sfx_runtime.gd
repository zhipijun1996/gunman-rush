extends SceneTree
## Real formal scene and existing audio dispatch; no natural campaign/PCM/device claim.
const RUNTIME := preload("res://scripts/audio/selected_sfx_runtime.gd")
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

func frames(count: int = 3) -> void:
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
	print("SELECTED_SFX_RUNTIME checks=%d failures=%d" % [checks, failures.size()])
	quit.call_deferred(0 if failures.is_empty() else 1)

func exercise() -> void:
	root.size = Vector2i(1280, 720)
	check(RUNTIME.source_validation_error().is_empty(), "Exact retained selection/manifest/rules/user evidence bytes validate")
	var selection: Dictionary = RUNTIME.read_json(RUNTIME.SELECTION_PATH)
	var manifest: Dictionary = RUNTIME.read_json(RUNTIME.MANIFEST_PATH)
	var rules: Dictionary = RUNTIME.read_json(RUNTIME.RULES_PATH)
	check(selection.explicit_choices.size() == 13 and selection.events.size() == 14, "Thirteen explicit choices plus one original bomb-explosion derivation")
	check(RUNTIME.selection_validation_error(selection, manifest, rules).is_empty(), "All14 exact profiles and11 actual imported resource fingerprints validate")
	var bad := selection.duplicate(true)
	bad.event_profiles.erase("coin")
	check(not RUNTIME.selection_validation_error(bad, manifest, rules).is_empty(), "Missing selected event is rejected")
	bad = selection.duplicate(true)
	bad.event_profiles["jump"] = "A"
	check(not RUNTIME.selection_validation_error(bad, manifest, rules).is_empty(), "Unselected jump cannot enter the proposal")
	bad = selection.duplicate(true)
	bad.events[0].candidate_sha256 = "0".repeat(64)
	check(not RUNTIME.selection_validation_error(bad, manifest, rules).is_empty(), "Wrong selected source SHA is rejected")
	bad = selection.duplicate(true)
	bad.events[0].candidate_path = "res://assets/audio/director_v3/heal_a.wav"
	check(not RUNTIME.selection_validation_error(bad, manifest, rules).is_empty(), "Another actual candidate path cannot masquerade as the selected coin")
	bad = selection.duplicate(true)
	bad.events[1] = bad.events[0].duplicate(true)
	check(not RUNTIME.selection_validation_error(bad, manifest, rules).is_empty(), "Duplicate event cannot hide a missing selection")
	check(not RUNTIME.candidate_validation_error("res://assets/audio/director_v3/unselected.wav", "0".repeat(64)).is_empty(), "Unknown imported audio is rejected before loading")

	var other := DemoApp.new()
	other.meta_persistence_enabled = false
	root.add_child(other)
	await frames()
	var other_audio: Variant = local_audio(other)
	check(other_audio != null and other_audio.audio_profile == "original", "Earlier programmatic App remains original")
	var packed := load("res://scenes/demo/demo.tscn") as PackedScene
	var app := packed.instantiate() as DemoApp
	packed = null
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(6)
	var helper: Variant
	for child: Node in app.get_children():
		if child.get_script() == RUNTIME: helper = child
	var audio: Variant = local_audio(app)
	check(helper != null, "Actual demo.tscn contains its real SelectedSfxRuntime child")
	if helper == null:
		await TEARDOWN.drain_world(app)
		await TEARDOWN.drain_world(other)
		app.free()
		other.free()
		return
	check(helper.validation_ok and helper.configurations == 1, "Formal startup selection configured exactly once")
	var accepted_hurt: Variant = RUNTIME.read_json(RUNTIME.HURT_SELECTION_PATH)
	check(accepted_hurt is Dictionary and accepted_hurt.profile == "A" and accepted_hurt.candidate_id == "hurt_feedback_06_a", "Latest user choice names exact accepted hurt A")
	check(FileAccess.get_sha256(RUNTIME.HURT_SELECTION_PATH) == RUNTIME.PINNED_JSON[RUNTIME.HURT_SELECTION_PATH], "Actual accepted choice file is pinned before formal assembly")
	check(helper._hurt_audition == accepted_hurt.profile and audio._candidate_revisions[&"hurt"].id == accepted_hurt.candidate_id, "Formal default consumes the accepted choice ledger")
	check(audio != other_audio and helper.snapshot().audio_owner_id == audio.get_instance_id(), "Only the direct formal App service is selected, never the earlier global-group service")
	check(audio.audio_profile == "selected" and audio._voices.size() == 12, "Formal profile selected with unchanged12-voice pool")
	check(helper.snapshot().event_profiles == selection.event_profiles, "Runtime consumes exact original14-event mapping")
	check(helper.snapshot().candidate_imports_verified == 11, "Snapshot reports actual11 imported resource guards")
	for id: String in selection.event_profiles:
		check(audio.director_profile_for_event(StringName(id)) == selection.event_profiles[id], "Actual profile: " + id)
	check(audio.director_profile_for_event(&"jump") == "original" and audio.director_profile_for_event(&"land") == "original", "Jump/land preserve original motion consumers")
	check(GameMusic.TRACKS.size() == 5, "Five original BGM options retained")
	var music_id: int = app._music.get_instance_id()
	var track: StringName = app._music.requested_track
	var music_starts: Dictionary = app._music.starts.duplicate(true)
	for row: Dictionary in selection.events:
		if row.runtime_mode != "candidate": continue
		audio.stop_director_cues()
		check(audio.play_director_event(StringName(row.event_id), "", app), "Existing dispatch accepts selected " + row.event_id)
		var played: Dictionary = audio.director_events.back()
		if row.event_id == "hurt":
			check(played.candidate == "hurt_feedback_06_a" and played.path in RUNTIME.HURT_CANDIDATES.A.variants, "Latest explicit rejection revises hurt without mutating the frozen C choice")
		else:
			check(played.candidate == row.candidate_id and played.path == row.candidate_path, "Actual candidate/path matches selection: " + row.event_id)
	check(app._music.get_instance_id() == music_id and app._music.requested_track == track and app._music.starts == music_starts, "Selected SFX dispatch never changes/restarts BGM")
	var configured: int = helper.configurations
	var event_count: int = audio.director_events.size()
	helper._attach()
	check(helper.configurations == configured and audio.director_events.size() == event_count, "Repeated attach does not reconfigure bank or clear accepted events")
	audio.stop_director_cues()
	app.menu.requested_enter_home.emit()
	await frames(5)
	check(is_instance_valid(app.home_scene) and audio.audio_profile == "selected", "Actual Home uses the selected service")
	check(app.start_plains("selected-sfx-plains"), "Actual formal Plains starts")
	await frames(6)
	check(app.stage is PlainsRegionStage and audio.audio_profile == "selected" and helper.configurations == 1, "Plains retains the same selected bank without reattachment")
	app.abandon_run()
	await frames(10)
	check(app.start_debug_region(&"thorn_forest", 1, "selected-sfx-forest"), "Existing explicit debug entry supplies real Forest consumer")
	await frames(6)
	check(app.stage is ThornForestRegionStage and audio.audio_profile == "selected" and helper.configurations == 1, "Forest retains the same selected bank without reattachment")
	check(other_audio.audio_profile == "original", "Other App remains original through formal transitions")
	check(not helper.is_processing(), "Normal entry has no per-frame SFX telemetry")
	await TEARDOWN.drain_world(app)
	await TEARDOWN.drain_world(other)
	app.free()
	other.free()
