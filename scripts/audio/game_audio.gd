class_name GameAudio
extends Node
## Local presentation consumer: bounded voices, no gameplay or random-stream writes.
const MAX_VOICES := 12
const CUES := [&"focus_start", &"focus_end", &"enemy_defeat", &"door", &"warning", &"boss_impact", &"click", &"confirm", &"coin", &"note", &"victory", &"jump", &"land", &"step", &"hurt", &"shot", &"impact", &"armour", &"core", &"enemy_shot", &"heal", &"death", &"bell", &"denied", &"roar"]
var volume := 0.7:
	set(value):
		volume = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
		for voice: AudioStreamPlayer in _voices:
			voice.volume_db = linear_to_db(maxf(0.0001, volume)) - float(voice.get_meta("attenuation", 7.0))
var played: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _last: Dictionary = {}
var _clock := 0.0
var _shutting_down := false
var _playbacks: Array[WeakRef] = []

static func cue(origin: Node, id: StringName) -> void:
	if not is_instance_valid(origin) or not origin.is_inside_tree(): return
	var service := origin.get_tree().get_first_node_in_group(&"game_audio") as GameAudio
	if service: service.play(id)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"game_audio")
	for id: StringName in CUES:
		_streams[id] = load("res://assets/audio/kenney/%s.ogg" % id)
	for index: int in MAX_VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	get_tree().node_added.connect(_observe_button)
	_observe_subtree(get_tree().root)

func _observe_subtree(node: Node) -> void:
	_observe_button(node)
	for child: Node in node.get_children(): _observe_subtree(child)

func _observe_button(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_click): node.pressed.connect(_click)

func _click() -> void:
	play(&"click")

func _process(delta: float) -> void:
	_clock += delta
	_playbacks = _playbacks.filter(func(reference: WeakRef) -> bool: return reference.get_ref() != null)

func play(id: StringName) -> bool:
	if _shutting_down or not _streams.has(id) or volume <= 0: return false
	if get_tree().paused and id not in [&"click", &"confirm", &"denied"]: return false
	var interval := 0.16 if id in [&"step", &"denied", &"armour"] else 0.055
	if _clock - float(_last.get(id, -100.0)) < interval: return false
	for voice: AudioStreamPlayer in _voices:
		if voice.playing: continue
		_last[id] = _clock
		played[id] = int(played.get(id, 0)) + 1
		voice.process_mode = Node.PROCESS_MODE_ALWAYS if id in [&"click", &"confirm", &"denied"] else Node.PROCESS_MODE_PAUSABLE
		voice.stream = _streams[id]
		var attenuation := 18.0 if id == &"step" else 10.0 if id in [&"shot", &"land", &"jump", &"click"] else 7.0
		voice.set_meta("attenuation", attenuation)
		voice.volume_db = linear_to_db(volume) - attenuation
		voice.play()
		if voice.has_stream_playback(): _playbacks.append(weakref(voice.get_stream_playback()))
		return true
	return false

func shutdown(timeout_msec: int = 1000) -> bool:
	# stop() queues a fade/delete on AudioServer's independent mixing thread.
	# Fixed-FPS hosts can quit before that thread consumes it. Keep only weak
	# references and wait for actual release, with a wall-clock bound.
	_shutting_down = true
	var pending: Array[WeakRef] = _playbacks.duplicate()
	for voice: AudioStreamPlayer in _voices:
		if voice.has_stream_playback(): pending.append(weakref(voice.get_stream_playback()))
		voice.stop()
		voice.stream = null
	_streams.clear()
	var deadline := Time.get_ticks_msec() + timeout_msec
	while pending.any(func(reference: WeakRef) -> bool: return reference.get_ref() != null):
		if Time.get_ticks_msec() >= deadline: return false
		await get_tree().process_frame
	return true

func _exit_tree() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		voice.stream = null
	_streams.clear()
