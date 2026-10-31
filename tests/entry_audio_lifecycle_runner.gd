extends SceneTree
## Production drain contract; --studies also drives all four real Study scenes.
const Lifecycle = preload("res://game/presentation/audio/world_audio_lifecycle.gd")
const Shim = preload("res://tests/audio_teardown.gd")
const FALLBACK_STREAM = preload("res://assets/audio/bgm/the_kindred_hearth.mp3")
var failures := 0
var assertions := 0

class FailingAudio:
	extends GameAudio
	var budgets: Array[int] = []
	func shutdown(timeout_msec: int = 1000) -> bool:
		budgets.append(timeout_msec)
		return false

class ObservedMusic:
	extends GameMusic
	var budgets: Array[int] = []
	func shutdown(timeout_msec: int = 1000) -> bool:
		budgets.append(timeout_msec)
		return await super.shutdown(timeout_msec)

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("ENTRY AUDIO LIFECYCLE: " + label)

func _fallback(parent: Node) -> AudioStreamPlayer2D:
	var voice := AudioStreamPlayer2D.new()
	voice.stream = FALLBACK_STREAM
	parent.add_child(voice)
	voice.play()
	return voice

# Keep observations weak: the test must never hold the actual playback
# while asking the service or fallback owner to release it.
func _playback_reference(voice: AudioStreamPlayer2D) -> WeakRef:
	var playback: AudioStreamPlayback = voice.get_stream_playback()
	return weakref(playback)

func _owned_release(use_shim: bool) -> void:
	var world := Node.new()
	var outside := Node.new()
	root.add_child(world)
	root.add_child(outside)
	var audio := GameAudio.new()
	world.add_child(audio)
	_check(audio.play(&"click"), "actual owned SFX starts")
	var music := ObservedMusic.new()
	music.volume_source = audio
	world.add_child(music)
	_check(music.request_track(&"home"), "actual owned music starts")
	var fallback := _fallback(world)
	_check(fallback.has_stream_playback(), "actual owned fallback playback exists")
	var backend: WeakRef = _playback_reference(fallback)
	var sibling_audio := GameAudio.new()
	outside.add_child(sibling_audio)
	_check(sibling_audio.play(&"click"), "unrelated sibling SFX starts")
	var sibling_fallback := _fallback(outside)
	# A 2D play request starts in internal physics, after physics_frame.
	# Same-frame stop has a separately recorded original engine limitation.
	await physics_frame
	await physics_frame
	var started := Time.get_ticks_msec()
	var released: bool
	if use_shim: released = await Shim.drain_world(world,1000)
	else: released = await Lifecycle.drain_world(world,1000)
	_check(released, ("shim" if use_shim else "production") + " observes owned backend release")
	_check(audio._shutting_down and music._shutting_down, "both owned services are terminal")
	_check(not audio.play(&"click") and not music.request_track(&"plains"), "drained services reject new work")
	_check(backend.get_ref() == null and fallback.stream == null, "fallback uses actual weak playback release and clears its stream")
	_check(music.budgets.size() == 1 and music.budgets[0] >= 0 and music.budgets[0] <= 1000, "music receives remaining original total budget")
	_check(Time.get_ticks_msec()-started < 1500, "successful drain stays within budget plus scheduling margin")
	_check(not sibling_audio._shutting_down and sibling_fallback.stream == FALLBACK_STREAM, "drain leaves sibling service and fallback ownership untouched")
	_check(await Lifecycle.drain_world(world), "repeated drain is idempotent")
	_check(await Lifecycle.drain_world(outside), "sibling separately drains its own backend")
	world.free()
	outside.free()

func _failure_contract() -> void:
	var world := Node.new()
	root.add_child(world)
	var audio := FailingAudio.new()
	world.add_child(audio)
	var music := ObservedMusic.new()
	world.add_child(music)
	var voice := _fallback(world)
	var backend: WeakRef = _playback_reference(voice)
	await physics_frame
	await physics_frame
	_check(not await Lifecycle.drain_world(world,0), "service failure propagates false without extending zero budget")
	_check(audio.budgets == [0], "failed service receives exactly the exhausted budget")
	_check(music.budgets.is_empty(), "original failure short-circuit does not proceed to music")
	_check(voice.stream == null, "fallback stop still precedes service failure")
	# A held weak-reference target forces the original wait timeout path,
	# independently of AudioServer release speed on this machine.
	var held := RefCounted.new()
	var pending: Array[WeakRef] = [weakref(held)]
	var receipt := {"started_msec":Time.get_ticks_msec()-1000,"pending":pending,"owners":[]}
	_check(not await Shim.wait_fallback_release(receipt,0), "shim preserves expired-budget failure")
	held = null
	_check(await Lifecycle.wait_fallback_release(receipt,0), "already-released receipt succeeds even with exhausted budget")
	var cleanup: Array[WeakRef] = [backend]
	_check(await Lifecycle.wait_fallback_release({"started_msec":Time.get_ticks_msec(),"pending":cleanup,"owners":[]}), "failed test world fallback eventually releases")
	world.free()

func _split_release() -> void:
	var world := Node.new()
	root.add_child(world)
	var voice := _fallback(world)
	_check(voice.has_stream_playback(), "split-release consumer starts real playback")
	var receipt: Dictionary = Shim.stop_fallback_voices(world)
	_check(receipt.has("started_msec") and receipt.has("pending") and receipt.has("owners") and receipt.pending.size() == 1, "shim retains the original split receipt format")
	_check(voice.stream == null, "split stop clears stream before freeing world")
	world.queue_free()
	await process_frame
	_check(await Shim.wait_fallback_release(receipt), "split wait works after the world leaves the tree")

func _studies() -> void:
	for entry: String in ["light_study","pixel_light_study","high_density_terrain_study","authored_terrain_study"]:
		var packed := load("res://scenes/dev/"+entry+".tscn") as PackedScene
		var study := packed.instantiate()
		root.add_child(study)
		var deadline := Time.get_ticks_msec()+15000
		while bool(study.get("busy")) and Time.get_ticks_msec()<deadline:
			await process_frame
		await process_frame
		var app := study.get("app") as DemoApp
		_check(not bool(study.get("busy")) and is_instance_valid(app) and is_instance_valid(app.home_scene), entry+" actual default Home opens")
		_check(not app.meta_persistence_enabled, entry+" retains memory-only Meta")
		for place: String in ["plains","home"]:
			var previous: WeakRef = weakref(app)
			await study.call("open_place",place)
			app = study.get("app") as DemoApp
			_check(previous.get_ref() == null, entry+" frees previous real App after drain")
			_check(is_instance_valid(app) and (is_instance_valid(app.stage) if place == "plains" else is_instance_valid(app.home_scene)), entry+" opens real "+place+" consumer")
		app.abandon_run()
		_check(await Lifecycle.drain_world(app), entry+" final actual App drains")
		study.free()
		await process_frame

func _run() -> void:
	await _owned_release(false)
	await _owned_release(true)
	await _failure_contract()
	await _split_release()
	if "--studies" in OS.get_cmdline_user_args(): await _studies()
	print("ENTRY AUDIO LIFECYCLE: %d assertions, %d failures" % [assertions,failures])
	quit(1 if failures else 0)
