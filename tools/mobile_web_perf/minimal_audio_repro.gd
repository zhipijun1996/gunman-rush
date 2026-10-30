extends Node
## Offline diagnostic scene only; never instantiates the game or changes a bus.
var startup := "single"
var player: AudioStreamPlayer
var current_case: Dictionary = {}
var case_events: Array[Dictionary] = []
var process_frames := 0
var startup_buses: Array[Dictionary] = []
var case_start_usec := 0
var case_start_frame := 0

func _ready() -> void:
	startup = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('startup') || 'single'"))
	if startup == "multi":
		GameAudio.ensure_buses()
	startup_buses = _buses()
	_publish()
	JavaScriptBridge.eval("window.MINIMAL_REPRO_READY=true")

func _buses() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in AudioServer.bus_count:
		result.append({"index": index, "name": str(AudioServer.get_bus_name(index)), "send": str(AudioServer.get_bus_send(index)), "volume_db": AudioServer.get_bus_volume_db(index), "mute": AudioServer.is_bus_mute(index)})
	return result

func _process(_delta: float) -> void:
	process_frames += 1
	if is_instance_valid(player) and not current_case.is_empty():
		var policy := str(current_case.get("pause_policy", "none"))
		if policy == "always_false":
			player.stream_paused = false
		elif policy == "guard_false" and player.stream_paused:
			player.stream_paused = false
	var raw: Variant = JavaScriptBridge.eval("(()=>{const c=window.MINIMAL_REPRO_COMMAND||'';window.MINIMAL_REPRO_COMMAND='';return c})()")
	if raw is String and not raw.is_empty():
		var command: Variant = JSON.parse_string(raw)
		if command is Dictionary:
			if command.get("action") == "play": _play_case(command)
			elif command.get("action") == "finish": _finish_case()

func _play_case(command: Dictionary) -> void:
	if is_instance_valid(player):
		player.stop()
		player.queue_free()
	current_case = command.duplicate(true)
	case_events = []
	case_start_usec = Time.get_ticks_usec()
	case_start_frame = process_frames
	player = AudioStreamPlayer.new()
	player.name = "MinimalCoin"
	player.bus = &"Master"
	player.playback_type = int(command.get("playback_type", AudioServer.PLAYBACK_TYPE_SAMPLE))
	player.stream = load("res://assets/audio/kenney/coin.ogg") as AudioStream
	player.volume_db = 0.0
	player.finished.connect(_on_finished.bind(str(command.id)))
	add_child(player)
	case_events.append({"kind": "play_call", "id": command.id, "usec": Time.get_ticks_usec(), "frame": process_frames, "playback_type": player.playback_type, "bus": str(player.bus), "stream": player.stream.resource_path, "stream_length": player.stream.get_length()})
	player.play()
	_publish()
	JavaScriptBridge.eval("window.MINIMAL_REPRO_CASE_STARTED=" + JSON.stringify(str(command.id)))

func _on_finished(id: String) -> void:
	case_events.append({"kind": "finished", "id": id, "usec": Time.get_ticks_usec(), "frame": process_frames})
	_publish()

func _finish_case() -> void:
	var result := {"id": current_case.get("id"), "startup": startup, "command": current_case, "events": case_events, "process_frames": process_frames - case_start_frame, "elapsed_seconds": (Time.get_ticks_usec() - case_start_usec) / 1000000.0, "buses": _buses(), "playing": player.playing if is_instance_valid(player) else false, "position": player.get_playback_position() if is_instance_valid(player) else 0.0}
	JavaScriptBridge.eval("window.MINIMAL_REPRO_RESULTS.push(" + JSON.stringify(result) + ")")
	current_case = {}
	if is_instance_valid(player): player.stop()
	_publish()

func _publish() -> void:
	JavaScriptBridge.eval("window.MINIMAL_REPRO_STATE=" + JSON.stringify({"startup": startup, "startup_buses": startup_buses, "buses": _buses(), "current_case": current_case, "events": case_events, "process_frames": process_frames}) + ";")
