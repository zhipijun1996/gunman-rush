extends SceneTree
## Diagnostic regression: immediate 2D play/stop retains Godot 4.7.2's pending
## playback until the voice is freed. Keep that original limitation separate
## from production extraction. Every compared drain uses the original1000ms.
const Original = preload("res://tests/fixtures/audio_lifecycle_2ce4ffa6/audio_teardown.gd")
const Current = preload("res://scripts/audio/world_audio_lifecycle.gd")
const STREAMS = {
	"mp3": preload("res://assets/audio/bgm/the_kindred_hearth.mp3"),
	"ogg": preload("res://assets/audio/kenney/land.ogg")
}
var assertions := 0
var failures := 0
var results: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("ENTRY AUDIO BASELINE COMPARISON: "+label)

func _reference(voice: AudioStreamPlayer2D) -> WeakRef:
	return weakref(voice.get_stream_playback())

func _case(helper: Script, helper_name: String, use_node2d: bool, stream_name: String, allow_physics_start: bool) -> Dictionary:
	var world: Node = Node2D.new() if use_node2d else Node.new()
	root.add_child(world)
	var voice := AudioStreamPlayer2D.new()
	voice.stream = STREAMS[stream_name]
	world.add_child(voice)
	voice.play()
	_check(voice.has_stream_playback(), "fixture owns an actual playback before stop")
	var reference: WeakRef = _reference(voice)
	if allow_physics_start:
		# physics_frame is emitted before nodes' internal physics processing;
		# the second signal proves the first pending-start notification ran.
		await physics_frame
		await physics_frame
	var began := Time.get_ticks_msec()
	var released: bool = await helper.call("drain_world",world,1000)
	var live_after_drain: bool = reference.get_ref() != null
	var row := {"helper":helper_name,"parent":"Node2D" if use_node2d else "Node","stream":stream_name,"physics_started":allow_physics_start,"released":released,"weak_live_after_drain":live_after_drain,"seconds":float(Time.get_ticks_msec()-began)/1000.0,"stream_cleared":voice.stream == null}
	# Owner destruction clears pending setplayback; retain the same weak ref.
	world.queue_free()
	await process_frame
	var refs: Array[WeakRef] = [reference]
	var finally_released: bool = await helper.call("wait_fallback_release",{"started_msec":Time.get_ticks_msec(),"pending":refs,"owners":[]},1000)
	row["released_after_free"] = finally_released
	_check(finally_released and reference.get_ref() == null, "same playback releases after owner destruction")
	results.append(row)
	print("ENTRY AUDIO BASELINE CASE: ",JSON.stringify(row))
	return row

func _run() -> void:
	for use_node2d: bool in [false,true]:
		for stream_name: String in STREAMS:
			for allow_physics_start: bool in [false,true]:
				var old: Dictionary = await _case(Original,"2ce4ffa6",use_node2d,stream_name,allow_physics_start)
				var current: Dictionary = await _case(Current,"production",use_node2d,stream_name,allow_physics_start)
				for key: String in ["released","weak_live_after_drain","stream_cleared","released_after_free"]:
					_check(old[key] == current[key], "original and extracted helper agree on "+key)
				_check(bool(old.released) == allow_physics_start, "baseline preserves the observed immediate-stop limitation and started-voice release")
				_check(bool(old.weak_live_after_drain) != allow_physics_start, "pending backend remains real until destruction, started backend really releases")
	print("ENTRY AUDIO BASELINE COMPARISON RESULTS: ",JSON.stringify(results))
	print("ENTRY AUDIO BASELINE COMPARISON: %d assertions, %d failures" % [assertions,failures])
	quit(1 if failures else 0)
