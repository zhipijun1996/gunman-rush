extends SceneTree
## Formal scene assembly + real App consumers. Debug forest entry is explicit.
const TEARDOWN := preload("res://tests/audio_teardown.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

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
	# Check the real script inheritance chain without introducing the test's
	# GameAudio -> GameAmbience member-type compilation cycle. The production
	# assembly separately checks `child is GameAudio` on the same direct owner.
	for child: Node in app.get_children():
		var source := child.get_script() as Script
		while source != null:
			if source.resource_path == "res://game/presentation/audio/game_audio.gd": return child
			source = source.get_base_script()
	return null

func selected_child(app: DemoApp) -> SelectedAmbienceRuntime:
	for child: Node in app.get_children():
		if child is SelectedAmbienceRuntime: return child as SelectedAmbienceRuntime
	return null

func active_beds(audio: Variant) -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	if is_instance_valid(audio.ambience):
		for voice: AudioStreamPlayer in audio.ambience._beds:
			if voice.stream != null: result.append(voice)
	return result

func run() -> void:
	# Unwind the exercise coroutine (PackedScene, typed arrays and script-backed
	# locals) before asking the engine to tear down its resource/type caches.
	await exercise()
	await frames(4)
	print("SELECTED_AMBIENCE_RUNTIME checks=%d failures=%d" % [checks, failures.size()])
	quit.call_deferred(0 if failures.is_empty() else 1)

func exercise() -> void:
	root.size = Vector2i(1280, 720)
	# An earlier group member is deliberately another real App. It must never
	# receive the formal scene's selected audio or affect its chosen service.
	var other := DemoApp.new()
	other.meta_persistence_enabled = false
	root.add_child(other)
	await frames()
	check(selected_child(other) == null, "Programmatic DemoApp stays unchanged and contains no formal assembly")
	var other_audio: Variant = local_audio(other)
	check(is_instance_valid(other_audio) and other_audio.ambience == null, "Independent App initially has no ambience component")
	var packed := load("res://game/application/demo.tscn") as PackedScene
	var app := packed.instantiate() as DemoApp
	packed = null
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(6)
	var helper := selected_child(app)
	var audio: Variant = local_audio(app)
	check(is_instance_valid(helper), "Actual formal demo.tscn instantiates the new selected-ambience child")
	if helper == null:
		await TEARDOWN.drain_world(app)
		await TEARDOWN.drain_world(other)
		app.free()
		other.free()
		return
	check(helper.validation_ok, "Selected modes, pinned manifests and all sixteen actual audio fingerprints validate")
	check(audio != other_audio and int(helper.snapshot().audio_owner_id) == audio.get_instance_id(), "Assembly uses only its direct App-owned service rather than the earlier global-group member")
	check(app.menu.visible_panel == &"title" and helper.active_context.is_empty() and audio.ambience == null, "Initial title remains silent without allocating an ambience pool")
	check(audio.audio_profile == "selected", "Formal selected-SFX assembly coexists with the ambience assembly")
	var regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SelectedAmbienceRuntime.REGION_SELECTION))
	var home_choice: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SelectedAmbienceRuntime.HOME_SELECTION))
	check(SelectedAmbienceRuntime.selections_valid(regions, home_choice), "Actual preserved selection records validate independently")
	var bad := regions.duplicate(true)
	bad.events[0].profile = "B"
	check(not SelectedAmbienceRuntime.selections_valid(bad, home_choice), "Unselected regional profile is refused")
	bad = regions.duplicate(true)
	bad.events[0].sha256 = "0".repeat(64)
	check(not SelectedAmbienceRuntime.selections_valid(bad, home_choice), "Wrong selected-bed fingerprint is refused")
	bad = regions.duplicate(true)
	bad.manifest_sha256 = "0".repeat(64)
	check(not SelectedAmbienceRuntime.selections_valid(bad, home_choice), "Wrong regional manifest fingerprint is refused")
	bad = regions.duplicate(true)
	bad.events[1] = bad.events[0].duplicate(true)
	check(not SelectedAmbienceRuntime.selections_valid(bad, home_choice), "Duplicate region cannot conceal a missing selection")
	var bad_home := home_choice.duplicate(true)
	bad_home.mode = "bed"
	check(not SelectedAmbienceRuntime.selections_valid(regions, bad_home), "Home mode must match the selected life mode")
	bad_home = home_choice.duplicate(true)
	bad_home.point_takes[0].sha256 = "0".repeat(64)
	check(not SelectedAmbienceRuntime.selections_valid(regions, bad_home), "Wrong life-take fingerprint is refused")
	bad_home = home_choice.duplicate(true)
	bad_home.bed.selection_sha256 = "0".repeat(64)
	check(not SelectedAmbienceRuntime.selections_valid(regions, bad_home), "Borrowed Home bed must bind the actual preserved regional selection bytes")
	bad_home = home_choice.duplicate(true)
	bad_home.schedule.max_simultaneous_life_cues = true
	check(not SelectedAmbienceRuntime.selections_valid(regions, bad_home), "Boolean cannot masquerade as the accepted numeric life schedule")
	app.menu.requested_enter_home.emit()
	await frames(6)
	check(is_instance_valid(app.home_scene) and helper.active_context == "home", "Accepted title entry activates real Home life")
	check(helper.snapshot().home_life.mode == "life" and helper.snapshot().expected_path == SelectedAmbienceRuntime.BEDS.plains, "Real Home consumes the selected life mode and quiet plains source")
	check(not active_beds(audio).is_empty() and active_beds(audio).all(func(voice: AudioStreamPlayer) -> bool: return voice.playing and str(voice.get_meta("source_path", "")) == SelectedAmbienceRuntime.BEDS.plains), "Actual Home bed uses the selected source in existing players")
	var configured: int = helper.configurations
	var starts: Dictionary = audio.ambience.starts.duplicate()
	await frames(8)
	check(helper.configurations == configured and audio.ambience.starts == starts, "Observing unchanged Home does not reconfigure or restart its loop")
	app._open_home_codex()
	await frames(4)
	check(paused and app.home_scene.input_blocked and helper.active_context == "home", "Actual Home codex preserves its selected context while paused")
	var paused_beds := active_beds(audio)
	check(not paused_beds.is_empty() and paused_beds.all(func(voice: AudioStreamPlayer) -> bool: return voice.stream_paused), "All actual assigned Home beds pause; idle slots are excluded")
	check(helper.configurations == configured, "Home panel does not restart the bed")
	app._close_home_codex()
	await frames(6)
	check(not paused and helper.active_context == "home" and helper.configurations == configured, "Closing real codex resumes the same bed context")
	audio.volume = 0.0
	await frames()
	check(active_beds(audio).all(func(voice: AudioStreamPlayer) -> bool: return voice.stream_paused), "Existing session mute reaches all selected Home beds")
	audio.volume = 0.7
	await frames()
	check(not active_beds(audio).is_empty() and active_beds(audio).all(func(voice: AudioStreamPlayer) -> bool: return voice.playing and not voice.stream_paused), "Unmute resumes existing assigned Home bed")
	app.home_scene.controller.die()
	check(helper.active_context.is_empty() and audio.ambience.candidate.is_empty(), "Real Home Controller.die immediately clears the selected context")
	configured = helper.configurations
	await frames(5)
	check(helper.active_context.is_empty() and helper.configurations == configured and not helper.snapshot().dead_context.is_empty(), "Dead Home owner cannot restart its bed on the next frame")
	check(app.start_plains("selected-ambience-formal"), "Actual App starts the formal plains consumer")
	await frames(8)
	check(app.stage is PlainsRegionStage and helper.active_context == "plains" and helper.snapshot().expected_path == SelectedAmbienceRuntime.BEDS.plains, "Real plains stage and manifest select regional A")
	check(audio.ambience.candidate == "plains_a" and audio.audio_profile == "selected", "Regional A ambience preserves the separately selected SFX dispatch")
	configured = helper.configurations
	await frames(8)
	check(helper.configurations == configured, "Unchanged plains context does not restart")
	app.controller.die()
	check(helper.active_context.is_empty() and audio.ambience.candidate.is_empty(), "Real stage Controller.die immediately stops regional ambience")
	configured = helper.configurations
	await frames(5)
	check(helper.active_context.is_empty() and helper.configurations == configured, "Dead stage owner cannot restart selected audio")
	app.abandon_run()
	await frames(10)
	check(helper.active_context == "home" and is_instance_valid(app.home_scene), "Actual run cleanup and return create a fresh Home sound context")
	check(app.start_debug_region(&"thorn_forest", 1, "selected-ambience-forest"), "Explicit existing debug entry supplies a real forest consumer")
	await frames(8)
	check(app.stage is ThornForestRegionStage and helper.active_context == "forest" and audio.ambience.candidate == "forest_a", "Real forest type, manifest and App region select forest A")
	check(helper.snapshot().expected_path == SelectedAmbienceRuntime.BEDS.forest, "Forest diagnostic identifies the actual selected source")
	# Predicate-only counterexample: restore both fields before any await, so
	# physics and generation consumers never see this deliberately wrong metadata.
	var stage := app.stage as GeneratedDemoStage
	var original_region: String = str(stage.generated.manifest.region)
	var original_app_region: StringName = app.active_region_id
	stage.generated.manifest.region = "plains"
	app.active_region_id = &"plains"
	check(helper._desired(app).is_empty(), "Forest subclass cannot impersonate PlainsRegionStage by changing two region labels")
	stage.generated.manifest.region = original_region
	app.active_region_id = original_app_region
	configured = helper.configurations
	await frames(5)
	check(helper.active_context == "forest" and helper.configurations == configured, "Restored unchanged forest context remains stable")
	check(other_audio.ambience == null and selected_child(other) == null, "Parallel programmatic App remained untouched through both real regions")
	app.abandon_run()
	await frames(10)
	check(helper.active_context == "home", "Forest owner unload returns audio ownership to the new Home")
	app.menu.show_title()
	await frames(4)
	check(helper.active_context.is_empty() and audio.ambience.candidate.is_empty(), "Title overlay clears selected ambience even if an old Home still exists")
	print("SELECTED_AMBIENCE_SNAPSHOT ", JSON.stringify(helper.snapshot()))
	check(await TEARDOWN.drain_world(app), "Formal App backend audio releases within existing bounded teardown")
	check(await TEARDOWN.drain_world(other), "Parallel App backend audio releases independently")
	app.free()
	other.free()
