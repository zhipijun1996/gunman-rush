extends SceneTree
## Deliberate behavior-change regression: nearest ownership replaces global-first
## routing, and a closing owner never redirects into another world's service.
const Lifecycle = preload("res://game/presentation/audio/world_audio_lifecycle.gd")
var assertions := 0
var failures := 0

class ObservedAudio:
	extends GameAudio
	var region_stops := 0
	var origin_stops := 0
	var hold_close := true
	var close_finished := false
	var close_result := false
	func stop_regional_cues() -> void:
		region_stops += 1
		super.stop_regional_cues()
	func stop_director_cues(origin: Node = null, sustained_only: bool = false, preserve_committed_rewards: bool = false) -> void:
		origin_stops += 1
		super.stop_director_cues(origin,sustained_only,preserve_committed_rewards)
	func begin_observed_close() -> void:
		_observed_close.call_deferred()
	func _observed_close() -> void:
		# Hold an explicit close window so the regression cannot pass merely
		# because AudioServer happened to finish before the next assertion.
		_shutting_down = true
		while hold_close: await get_tree().process_frame
		close_result = await super.shutdown()
		close_finished = true

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("ENTRY AUDIO OWNERS: "+label)

func _audio(parent: Node) -> ObservedAudio:
	var service := ObservedAudio.new()
	parent.add_child(service)
	return service

func _latch(parent: Node) -> ShotLatch:
	var latch := ShotLatch.new()
	latch.set_physics_process(false)
	latch.hide()
	parent.add_child(latch)
	latch._bell_audio = AudioStreamPlayer2D.new()
	latch._bell_audio.stream = ShotLatch.BELL_SOUND
	latch.add_child(latch._bell_audio)
	return latch

func _ownership_case() -> void:
	var world := Node.new()
	root.add_child(world)
	var ancestor := _audio(world) # First global registration deliberately wrong for A.
	var local_host := Node.new()
	world.add_child(local_host)
	var local := _audio(local_host)
	var sibling_host := Node.new()
	world.add_child(sibling_host)
	var sibling := _audio(sibling_host)
	var origin := Node.new()
	local_host.add_child(origin)
	_check(get_first_node_in_group(&"game_audio") == ancestor, "fixture exposes the former global-first masking")
	_check(GameAudio.for_origin(origin) == local, "descendant chooses nearest owned service")
	_check(GameAudio.for_origin(local) == local, "service origin keeps itself as owner")
	GameAudio.cue(origin,&"coin")
	GameAudio.cue_event(origin,&"item_get",&"note")
	paused = true
	GameAudio.cue_committed_reward(origin,&"chest_open",&"confirm")
	paused = false
	_check(local.played.get(&"coin",0) == 1 and local.played.get(&"note",0) == 1 and local.played.get(&"confirm",0) == 1, "cue, semantic event and paused committed reward share the local service")
	_check(ancestor.played.is_empty() and sibling.played.is_empty(), "accepted local events do not reach ancestor or sibling")
	_check(PlainsEnemyAudio._service(origin) == local, "actual plains material consumer resolves locally")
	var bellstrider := BellstriderAudio.new()
	local_host.add_child(bellstrider)
	bellstrider.set("_origin",origin)
	_check(bellstrider._service() == local, "actual Bellstrider consumer resolves locally")
	var windkeeper := WindkeeperPressureAudio.new()
	local_host.add_child(windkeeper)
	windkeeper.set("_origin",origin)
	_check(windkeeper._service() == local, "actual pressure Windkeeper consumer resolves locally")
	var button := Button.new()
	local_host.add_child(button)
	local._observe_button(button) # Re-observation must not add a second callback.
	button.pressed.emit()
	_check(local.played.get(&"click",0) == 1 and ancestor.played.get(&"click",0) == 0 and sibling.played.get(&"click",0) == 0, "one actual button signal reaches only its owner once")
	button.reparent(sibling_host)
	button.pressed.emit()
	_check(local.played.get(&"click",0) == 1 and sibling.played.get(&"click",0) == 1 and ancestor.played.get(&"click",0) == 0, "reparented button follows its current owner at press time")
	button.reparent(local_host)
	GameAudio.stop_region(origin)
	GameAudio.stop_origin(origin)
	_check(local.region_stops == 1 and local.origin_stops == 2 and ancestor.region_stops == 0 and ancestor.origin_stops == 0, "region and origin stop only affect the nearest service")
	var latch := _latch(local_host)
	local.begin_observed_close()
	await process_frame
	await process_frame
	_check(local._shutting_down and not local.close_finished, "fixture holds a real asynchronous closing window")
	_check(GameAudio.for_origin(origin) == local, "closing owner is returned rather than skipped")
	var local_before := local.played.duplicate()
	var ancestor_before := ancestor.played.duplicate()
	var sibling_before := sibling.played.duplicate()
	var ancestor_stops := ancestor.origin_stops
	var sibling_stops := sibling.origin_stops
	GameAudio.cue(origin,&"jump")
	GameAudio.cue_event(origin,&"item_get",&"note")
	GameAudio.cue_committed_reward(origin,&"item_get",&"note")
	GameAudio.hook_connected(origin)
	GameAudio.stop_region(origin)
	GameAudio.stop_origin(origin,false)
	button.pressed.emit()
	latch._play_bell()
	_check(local.played == local_before, "closing service rejects every new cue and button click")
	_check(ancestor.played == ancestor_before and sibling.played == sibling_before and ancestor.origin_stops == ancestor_stops and sibling.origin_stops == sibling_stops, "closing A neither plays nor stops ancestor B or sibling C")
	_check(not latch._bell_audio.has_stream_playback(), "closing owner presence prevents ShotLatch local fallback")
	# Remove only B's service while A remains closing: no unrelated C fallback.
	_check(await ancestor.shutdown(), "ancestor service drains independently")
	ancestor.free()
	_check(GameAudio.for_origin(origin) == local, "closing local owner remains authoritative without ancestor service")
	GameAudio.cue(origin,&"hurt")
	_check(sibling.played == sibling_before, "closing owner never falls through to a sibling service")
	local.hold_close = false
	var deadline := Time.get_ticks_msec()+1500
	while not local.close_finished and Time.get_ticks_msec()<deadline: await process_frame
	_check(local.close_finished and local.close_result, "closing fixture finishes actual service shutdown")
	_check(await Lifecycle.drain_world(world), "all owned fixture backends drain")
	world.free()
	await process_frame

func _unowned_fallback() -> void:
	var sibling_world := Node.new()
	root.add_child(sibling_world)
	var unrelated := _audio(sibling_world)
	var standalone := Node.new()
	root.add_child(standalone)
	var latch := _latch(standalone)
	_check(GameAudio.for_origin(latch) == null, "unowned standalone origin cannot borrow unrelated sibling world")
	latch._play_bell()
	_check(latch._bell_audio.has_stream_playback() and unrelated.played.is_empty(), "actual standalone latch keeps its existing local fallback")
	await physics_frame
	await physics_frame
	_check(await Lifecycle.drain_world(standalone), "started local fallback releases with original lifecycle")
	_check(await Lifecycle.drain_world(sibling_world), "unrelated service separately drains")
	standalone.free()
	sibling_world.free()

func _click_count(audio: GameAudio) -> int:
	var count := int(audio.played.get(&"click",0))
	for event: Dictionary in audio.director_events:
		if event.get("id") == &"click": count += 1
	return count

func _cloud_case(path: String, expects_app: bool) -> void:
	var preview := CloudPreviewBootstrap.new()
	preview.entry = "scene"
	preview.entry_scene = path
	root.add_child(preview)
	for _frame: int in 8: await process_frame
	_check(is_instance_valid(preview.custom_scene), path+" instantiates its actual scene")
	var audio := GameAudio.for_origin(preview.custom_scene) as GameAudio
	_check(audio != null, path+" has its scoped service")
	if expects_app:
		var app := preview.custom_scene as DemoApp
		_check(app != null and not app.meta_persistence_enabled and preview.custom_audio == null, path+" owns audio and keeps save isolation without duplicate generic service")
		_check(audio.get_parent() == app and audio._voices.size() == 12, path+" retains one owned twelve-voice service")
		if path == "res://game/application/demo.tscn":
			_check(audio is PlayerWeaponFeelAudioV2 and audio.audio_profile == "selected", "formal scene retains its exact selected audio assembly")
			app._show_home()
			var actor := app.home_scene.player
			var feel := actor.get_node_or_null("WeaponFeel") as PlayerWeaponFeel
			_check(feel != null and feel.audio == audio, "real formal player weapon consumer binds the App's V2 service")
			var buttons: Array[Node] = preview.banner.find_children("*","Button",true,false)
			_check(buttons.size() == 1, "Cloud host retains its actual menu affordance")
			var clicks := _click_count(audio)
			(buttons[0] as Button).pressed.emit()
			_check(_click_count(audio) == clicks+1, "host control explicitly delegates exactly one click to the active entry")
			_check(is_instance_valid(preview.app) and not preview.app.meta_persistence_enabled, "host menu signal reconstructs the real save-isolated App")
			for _frame: int in 2: await process_frame
	else:
		_check(preview.custom_scene is ActionStudio and audio == preview.custom_audio, "standalone ActionStudio still borrows its bootstrap service")
	_check(await Lifecycle.drain_world(preview), path+" drains before fixture release")
	preview.free()
	await process_frame

func _run() -> void:
	await _ownership_case()
	await _unowned_fallback()
	await _cloud_case("res://game/application/demo.tscn",true)
	await _cloud_case("res://experiments/motion/entries/action_studio.tscn",false)
	if "--auditions" in OS.get_cmdline_user_args():
		for path: String in ["audio/entries/audio_home_lab", "audio/entries/audio_ambience_lab", "audio/entries/audio_director_lab", "audio/entries/audio_director_lab_v2", "audio/entries/audio_director_reels", "motion/entries/motion_candidate", "motion/entries/landing_feel", "motion/entries/weapon_feel", "motion/entries/weapon_feel_v2"]:
			await _cloud_case("res://experiments/"+path+".tscn",true)
	print("ENTRY AUDIO OWNERS: %d assertions, %d failures" % [assertions,failures])
	quit(1 if failures else 0)
