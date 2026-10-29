extends SceneTree
## Bounded transport/lifecycle checks; not an aesthetic or real-device approval.
class Listener:
	extends Node2D
	signal died
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures.append(reason)
		push_error(reason)

func ticks(count: int = 3) -> void:
	for unused: int in count: await process_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	var audio := GameAudio.new()
	root.add_child(audio)
	var origin := Node.new()
	var listener := Listener.new()
	root.add_child(origin)
	root.add_child(listener)
	await ticks()
	check(audio.audio_profile == "original" and audio.ambience == null, "Formal default neither changes original nor allocates ambience voices")
	check(audio._voices.size() == 12, "Existing twelve SFX voices remain unchanged")
	check(not audio.configure_ambience("res://missing-ambience.json"), "Missing manifest refused without allocation")
	check(audio.configure_ambience("res://assets/audio/ambience_v1/manifest.json"), "Actual source manifest configures an explicit audition component")
	var ambience := audio.ambience
	if ambience == null:
		await audio.shutdown()
		audio.free()
		origin.free()
		listener.free()
		print("AUDIO_AMBIENCE_RUNTIME checks=%d failures=%d" % [checks, failures.size()])
		quit(1)
		return
	check(ambience._beds.size() == 2 and ambience._details.size() == 2, "Continuous crossfade budget is explicitly two beds plus two details")
	check(audio.set_ambience_region("plains", "A", origin, listener), "Explicit plains A selects actual stream")
	await ticks()
	check(ambience.candidate == "plains_a" and ambience.starts.get("plains_a", 0) == 1, "Actual candidate start is observable")
	check(ambience._beds.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and voice.stream is AudioStreamOggVorbis and (voice.stream as AudioStreamOggVorbis).loop), "Actual Vorbis bed loops on Ambience bus")
	check(ambience._beds.all(func(voice: AudioStreamPlayer) -> bool: return voice.bus == &"Ambience"), "No bus/mix mutation")
	check(audio.set_ambience_region("plains", "A", origin, listener), "Repeated same request is accepted")
	check(ambience.starts.get("plains_a", 0) == 1, "Repeated request does not restart loop")
	check(not audio.set_ambience_region("no-region", "A", origin, listener), "Unknown region refused atomically")
	check(not audio.set_ambience_region("plains", "Z", origin, listener), "Unknown profile refused atomically")
	check(ambience.candidate == "plains_a", "Rejected selection preserves prior audition")
	var invalid := {"version": "audio-ambience-v1", "regions": {"plains": {"profiles": {"A": {"bed": "res://missing.ogg", "gain_db": 0.0}}}}}
	check(not ambience.configure(invalid), "Invalid source path refused before resource load")
	check(ambience.candidate == "plains_a", "Bad reconfigure preserves active bed and original bank")
	invalid.regions.plains.profiles.A.bed = "res://assets/audio/ambience_v1/plains_a.ogg"
	for bad: Variant in [NAN, INF, true, 1.0, -41.0, "0"]:
		invalid.regions.plains.profiles.A.gain_db = bad
		check(not ambience.configure(invalid), "Malformed/unbounded gain refused: %s" % str(bad))
	check(audio.set_ambience_region("forest", "B", origin, listener), "Cross-region selection starts forest B")
	await ticks()
	check(ambience._beds.filter(func(voice: AudioStreamPlayer) -> bool: return voice.playing).size() <= 2, "Rapid transition cannot allocate extra beds")
	check(ambience.starts.get("forest_b", 0) == 1, "Actual forest start recorded")
	check(not ambience.play_detail("unknown", Vector2.ZERO), "Unknown positioned detail refused")
	check(not ambience.play_detail("forest_wood", Vector2(NAN, 0)), "Invalid world coordinates refused")
	check(not ambience.play_detail("forest_wood", Vector2(10000, 0)), "Distant sound source is inaudible and not started")
	check(ambience.play_detail("forest_wood", listener.global_position + Vector2(100, 0)), "Actual wood detail starts at supplied source position")
	check(not ambience.play_detail("forest_wood", listener.global_position), "Same-frame repeated detail is limited")
	check(ambience.play_detail("forest_leaf", listener.global_position + Vector2(80, 0)), "Actual leaf detail uses second bounded voice")
	check(ambience._details.filter(func(voice: AudioStreamPlayer) -> bool: return voice.playing).size() == 2, "Only two detail voices are active")
	await ticks()
	check(ambience._details.all(func(voice: AudioStreamPlayer) -> bool: return float(voice.get_meta("attenuation", 0)) > 0.0 and float(voice.get_meta("attenuation", 0)) < 1.0), "Actual listener distance updates detail attenuation")
	paused = true
	await ticks()
	check(ambience._beds.all(func(voice: AudioStreamPlayer) -> bool: return voice.stream_paused), "Pause suspends continuous playback")
	check(not ambience.play_detail("missing", Vector2.ZERO), "Pause refuses detail onset")
	var old_elapsed := ambience._elapsed
	await ticks()
	check(ambience._elapsed == old_elapsed, "Pause freezes crossfade instead of silently completing it")
	paused = false
	await ticks()
	audio.volume = 0.0
	check(ambience._beds.all(func(voice: AudioStreamPlayer) -> bool: return voice.stream_paused), "Existing session zero volume immediately mutes candidate beds")
	audio.volume = 0.7
	await ticks()
	check(ambience._beds.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and not voice.stream_paused), "Unmute resumes bed without restart")
	var old_listener := listener
	listener = Listener.new()
	root.add_child(listener)
	check(audio.set_ambience_region("forest", "B", origin, listener), "Listener replacement is accepted")
	old_listener.died.emit()
	check(ambience.candidate == "forest_b", "Old listener death cannot clear the new context")
	old_listener.free()
	listener.died.emit()
	check(ambience.candidate.is_empty() and ambience._beds.all(func(voice: AudioStreamPlayer) -> bool: return not voice.playing), "Accepted current listener death clears sustained audio immediately")
	check(audio.set_ambience_region("plains", "B", origin, listener), "Scene can restart an explicit audition")
	origin.free()
	await ticks()
	check(ambience.candidate.is_empty(), "Origin unload cancels all candidate sound")
	origin = Node.new()
	root.add_child(origin)
	check(audio.set_ambience_region("plains", "A", origin, listener), "Fresh origin can select")
	listener.free()
	await ticks()
	check(ambience.candidate.is_empty(), "Missing listener cancels stale spatial context")
	listener = Listener.new()
	root.add_child(listener)
	check(audio.set_ambience_region("forest", "A", origin, listener), "Fresh listener can select")
	audio.stop_regional_cues()
	check(ambience.candidate.is_empty(), "Existing region lifecycle clears explicit ambience too")
	check(audio.set_ambience_region("plains", "A", origin, listener), "Can audition again after region clear")
	check(audio.set_ambience_region("plains", "original", origin, listener), "Original comparison clears candidate without replacing legacy cues")
	check(ambience.candidate.is_empty(), "Original profile has no new ambience bed")
	check(audio.set_ambience_region("forest", "A", origin, listener), "Final shutdown has actual ongoing sound")
	check(await audio.shutdown(), "Actual backend playback references released within bounded shutdown")
	check(not audio.set_ambience_region("forest", "B", origin, listener), "Shutdown refuses late restart")
	check(ambience._beds.all(func(voice: AudioStreamPlayer) -> bool: return voice.stream == null), "Shutdown releases bed resource ownership")
	check(audio._voices.size() == 12, "Transport did not grow existing SFX pool")
	audio.free()
	origin.free()
	listener.free()
	await ticks()
	print("AUDIO_AMBIENCE_RUNTIME checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
