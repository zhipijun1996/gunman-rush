extends SceneTree
## Real Ogg playback, independent mixer release and terminal shutdown contract.
var failures := 0
var assertions := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("AUDIO LIFECYCLE: " + label)
func run() -> void:
	var audio := GameAudio.new()
	root.add_child(audio)
	check(audio.play(&"click"), "real Ogg cue creates playback")
	check(not audio._playbacks.is_empty(), "actual playback weak reference tracked")
	# Generate recycled voices before a mix; the service must also retain weak
	# references to stopped playback objects no longer owned by a voice.
	for index: int in 32:
		audio._clock += 1.0
		audio._voices[index % GameAudio.MAX_VOICES].stop()
		check(audio.play(&"land"), "real playback accepted")
	if not "--prove-skip-drain" in OS.get_cmdline_user_args():
		check(await audio.shutdown(), "all backend playbacks actually released within bound")
		check(not audio.play(&"click"), "shutdown rejects fresh cue")
		check(await audio.shutdown(), "shutdown is idempotent")
	audio.free()
	await process_frame
	print("AUDIO LIFECYCLE: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
