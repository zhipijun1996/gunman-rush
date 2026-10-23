class_name GameMusic
extends Node
## App-local music only. It observes accepted game state; it owns no gameplay.
const TRACKS := {
	&"home": preload("res://assets/audio/bgm/the_kindred_hearth.mp3"),
	&"plains": preload("res://assets/audio/bgm/where_the_path_bends.mp3"),
	&"plains_boss": preload("res://assets/audio/bgm/across_the_wooden_sails.mp3"),
	&"forest": preload("res://assets/audio/bgm/vines_beneath_the_canopy.mp3"),
	&"forest_boss": preload("res://assets/audio/bgm/beyond_the_knotted_vines.mp3"),
}
const CROSSFADE_SECONDS := 0.9
const MUSIC_GAIN := 0.16 # About -16 dB before the existing session volume.
const PAUSE_GAIN := 0.5
var volume_source: GameAudio
var requested_track: StringName = &""
var starts: Dictionary = {} # Actual player starts, useful for lifecycle diagnostics.
var _voices: Array[AudioStreamPlayer] = []
var _ids: Array[StringName] = [&"", &""]
var _gains := PackedFloat32Array([0.0, 0.0])
var _from := PackedFloat32Array([0.0, 0.0])
var _targets := PackedFloat32Array([0.0, 0.0])
var _elapsed := CROSSFADE_SECONDS
var _duck := 1.0
var _menu_paused := false
var _unlocked := false
var _shutting_down := false
var _playbacks: Array[WeakRef] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"game_music")
	_unlocked = not OS.has_feature("web")
	for index: int in 2:
		var voice := AudioStreamPlayer.new()
		voice.name = "MusicVoice%s" % index
		voice.bus = &"Master"
		voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		voice.volume_db = -80.0
		add_child(voice)
		_voices.append(voice)
	if _unlocked and not requested_track.is_empty(): _transition(requested_track)

func request_track(id: StringName) -> bool:
	if _shutting_down or (not id.is_empty() and not TRACKS.has(id)): return false
	if id == requested_track: return true
	requested_track = id
	if _unlocked and not _voices.is_empty(): _transition(id)
	return true

func set_menu_paused(value: bool) -> void:
	_menu_paused = value

func _input(event: InputEvent) -> void:
	if _unlocked or _shutting_down: return
	var gesture: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed and not event.canceled) or (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed)
	if not gesture: return
	# Godot's Web audio backend resumes on this same real user gesture. Do not
	# consume the event: the original title/menu/gameplay control still owns it.
	_unlocked = true
	_transition(requested_track)

func _transition(id: StringName) -> void:
	_targets.fill(0.0)
	if not id.is_empty():
		var chosen := _ids.find(id)
		if chosen < 0:
			chosen = 0 if _gains[0] <= _gains[1] else 1
			var voice := _voices[chosen]
			voice.stop()
			voice.stream = TRACKS[id] as AudioStreamMP3
			voice.volume_db = -80.0
			_ids[chosen] = id
			_gains[chosen] = 0.0
			voice.play()
			starts[id] = int(starts.get(id, 0)) + 1
			if voice.has_stream_playback(): _playbacks.append(weakref(voice.get_stream_playback()))
		_targets[chosen] = 1.0
	_from = _gains.duplicate()
	_elapsed = 0.0

func _process(delta: float) -> void:
	if _shutting_down: return
	# Music pitch and transitions use real time, including gameplay slow aim.
	var real_delta := delta / maxf(0.001, Engine.time_scale)
	_elapsed = minf(CROSSFADE_SECONDS, _elapsed + real_delta)
	_duck = move_toward(_duck, PAUSE_GAIN if _menu_paused else 1.0, real_delta * 2.5)
	var blend := _elapsed / CROSSFADE_SECONDS
	var session_volume := volume_source.volume if is_instance_valid(volume_source) else 0.7
	for index: int in _voices.size():
		_gains[index] = lerpf(_from[index], _targets[index], blend)
		var voice := _voices[index]
		voice.volume_db = linear_to_db(maxf(0.00001, MUSIC_GAIN * session_volume * _duck * _gains[index]))
		if blend >= 1.0 and _targets[index] == 0.0 and not _ids[index].is_empty():
			voice.stop()
			voice.stream = null
			_ids[index] = &""
	_playbacks = _playbacks.filter(func(reference: WeakRef) -> bool: return reference.get_ref() != null)

func shutdown(timeout_msec: int = 1000) -> bool:
	_shutting_down = true
	requested_track = &""
	var pending: Array[WeakRef] = _playbacks.duplicate()
	for voice: AudioStreamPlayer in _voices:
		if voice.has_stream_playback(): pending.append(weakref(voice.get_stream_playback()))
		voice.stop()
		voice.stream = null
	var deadline := Time.get_ticks_msec() + timeout_msec
	while pending.any(func(reference: WeakRef) -> bool: return reference.get_ref() != null):
		if Time.get_ticks_msec() >= deadline: return false
		await get_tree().process_frame
	return true

func _exit_tree() -> void:
	_shutting_down = true
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		voice.stream = null
