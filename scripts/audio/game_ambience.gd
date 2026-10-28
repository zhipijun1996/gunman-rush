class_name GameAmbience
extends Node
## Explicit development audition, owned by GameAudio. No gameplay state writes.
const MAX_BEDS := 2
const MAX_DETAILS := 2
const CROSSFADE_SECONDS := 1.2
var session_volume := 0.7:
	set(value):
		session_volume = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
		if session_volume <= 0.0:
			for voice: AudioStreamPlayer in _beds + _details: voice.stream_paused = true
var profile := "original"
var region := ""
var candidate := ""
var starts: Dictionary = {}
var detail_starts: Dictionary = {}
var _bank: Dictionary = {}
var _beds: Array[AudioStreamPlayer] = []
var _details: Array[AudioStreamPlayer] = []
var _bed_ids: Array[String] = ["", ""]
var _from := PackedFloat32Array([0.0, 0.0])
var _gains := PackedFloat32Array([0.0, 0.0])
var _targets := PackedFloat32Array([0.0, 0.0])
var _elapsed := CROSSFADE_SECONDS
var _clock := 0.0
var _last_detail: Dictionary = {}
var _owner: WeakRef
var _listener: WeakRef
var _death_source: WeakRef
var _death_callback: Callable
var _unlocked := false
var _shutting_down := false
var _playbacks: Array[WeakRef] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_unlocked = not OS.has_feature("web")
	for index: int in MAX_BEDS:
		var voice := AudioStreamPlayer.new()
		voice.name = "AmbienceBed%d" % index
		voice.bus = &"Ambience"
		voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		voice.volume_db = -80.0
		add_child(voice)
		_beds.append(voice)
	for index: int in MAX_DETAILS:
		var voice := AudioStreamPlayer.new()
		voice.name = "AmbienceDetail%d" % index
		voice.bus = &"Ambience"
		voice.volume_db = -80.0
		add_child(voice)
		_details.append(voice)

func configure(manifest: Dictionary) -> bool:
	if _shutting_down or manifest.get("version") != "audio-ambience-v1": return false
	var regions: Variant = manifest.get("regions")
	if not regions is Dictionary or regions.is_empty() or regions.size() > 8: return false
	var proposed: Dictionary = {}
	for region_key: Variant in regions:
		if not region_key is String or region_key.is_empty(): return false
		var entry: Variant = regions[region_key]
		if not entry is Dictionary: return false
		var profiles: Variant = entry.get("profiles")
		if not profiles is Dictionary or profiles.is_empty(): return false
		var resolved: Dictionary = {}
		for profile_key: Variant in profiles:
			if profile_key not in ["A", "B"]: return false
			var row: Variant = profiles[profile_key]
			if not row is Dictionary: return false
			var path: Variant = row.get("bed")
			var gain: Variant = row.get("gain_db", 0.0)
			if not _valid_path(path, ".ogg") or not _valid_number(gain, -40.0, 0.0): return false
			var stream := load(path) as AudioStreamOggVorbis
			if stream == null: return false
			var detail_rows: Variant = row.get("details", [])
			if not detail_rows is Array or detail_rows.size() > 8: return false
			var resolved_details: Dictionary = {}
			for detail: Variant in detail_rows:
				if not detail is Dictionary: return false
				var id: Variant = detail.get("id")
				var detail_path: Variant = detail.get("path")
				var detail_gain: Variant = detail.get("gain_db", 0.0)
				var interval: Variant = detail.get("min_interval", 8.0)
				var distance: Variant = detail.get("max_distance", 720.0)
				if not id is String or id.is_empty() or resolved_details.has(id): return false
				if not _valid_path(detail_path) or not _valid_number(detail_gain, -40.0, 0.0): return false
				if not _valid_number(interval, 0.2, 120.0) or not _valid_number(distance, 32.0, 2000.0): return false
				var imported_detail := load(detail_path) as AudioStream
				if not imported_detail is AudioStreamWAV and not imported_detail is AudioStreamOggVorbis: return false
				var detail_stream := imported_detail.duplicate() as AudioStream
				if detail_stream is AudioStreamWAV: (detail_stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
				if detail_stream is AudioStreamOggVorbis: (detail_stream as AudioStreamOggVorbis).loop = false
				resolved_details[id] = {"stream": detail_stream, "path": detail_path, "gain_db": float(detail_gain), "min_interval": float(interval), "max_distance": float(distance)}
			# Duplicate before enabling loop: never mutate the imported resource.
			var loop_stream := stream.duplicate() as AudioStreamOggVorbis
			loop_stream.loop = true
			loop_stream.loop_offset = 0.0
			resolved[profile_key] = {"stream": loop_stream, "path": path, "gain_db": float(gain), "details": resolved_details}
		proposed[region_key] = resolved
	clear()
	_bank = proposed
	return true

func _valid_path(value: Variant, extension: String = "") -> bool:
	if not value is String or not value.begins_with("res://assets/audio/ambience_v1/") or ".." in value: return false
	if not extension.is_empty() and not value.ends_with(extension): return false
	return ResourceLoader.exists(value)

func _valid_number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

func select_region(region_id: String, selected_profile: String, origin: Node, listener: Node2D) -> bool:
	if _shutting_down: return false
	if selected_profile == "original":
		clear()
		return true
	if not _bank.has(region_id) or not _bank[region_id].has(selected_profile): return false
	if not is_instance_valid(origin) or not origin.is_inside_tree() or not is_instance_valid(listener) or not listener.is_inside_tree(): return false
	if region == region_id and profile == selected_profile and _owner != null and _owner.get_ref() == origin and _listener != null and _listener.get_ref() == listener: return true
	# A new owner cannot inherit detail tails or cooldowns from the old stage.
	_stop_details()
	_disconnect_death()
	_owner = weakref(origin)
	_listener = weakref(listener)
	if listener.has_signal(&"died"):
		_death_source = weakref(listener)
		_death_callback = clear
		listener.connect(&"died", _death_callback)
	region = region_id
	profile = selected_profile
	candidate = "%s_%s" % [region, profile.to_lower()]
	if _unlocked: _transition()
	return true

func _transition() -> void:
	var row: Dictionary = _bank[region][profile]
	var slot := _bed_ids.find(candidate)
	if slot < 0:
		slot = 0 if _gains[0] <= _gains[1] else 1
		var voice := _beds[slot]
		voice.stop()
		voice.stream = row.stream
		voice.set_meta("source_path", row.path)
		voice.set_meta("gain_db", row.gain_db)
		voice.volume_db = -80.0
		voice.stream_paused = get_tree().paused or session_volume <= 0.0
		_bed_ids[slot] = candidate
		_gains[slot] = 0.0
		voice.play()
		_remember(voice)
		starts[candidate] = int(starts.get(candidate, 0)) + 1
	_targets.fill(0.0)
	_targets[slot] = 1.0
	_from = _gains.duplicate()
	_elapsed = 0.0

func _input(event: InputEvent) -> void:
	if _unlocked or _shutting_down: return
	var gesture: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed and not event.canceled) or (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed)
	if gesture:
		_unlocked = true
		if not candidate.is_empty() and _valid_context(): _transition()

func _valid_context() -> bool:
	var origin := _owner.get_ref() as Node if _owner != null else null
	var listener := _listener.get_ref() as Node2D if _listener != null else null
	return is_instance_valid(origin) and origin.is_inside_tree() and is_instance_valid(listener) and listener.is_inside_tree()

func _process(delta: float) -> void:
	if _shutting_down: return
	if not candidate.is_empty() and not _valid_context():
		clear()
		return
	var is_paused := get_tree().paused
	for voice: AudioStreamPlayer in _beds: voice.stream_paused = is_paused
	for voice: AudioStreamPlayer in _details: voice.stream_paused = is_paused
	if is_paused: return
	var real_delta := delta / maxf(0.001, Engine.time_scale)
	_clock += real_delta
	_elapsed = minf(CROSSFADE_SECONDS, _elapsed + real_delta)
	for index: int in _beds.size():
		_gains[index] = lerpf(_from[index], _targets[index], _elapsed / CROSSFADE_SECONDS)
		var voice := _beds[index]
		var linear := session_volume * _gains[index] * db_to_linear(float(voice.get_meta("gain_db", 0.0)))
		voice.volume_db = linear_to_db(maxf(0.00001, linear))
		voice.stream_paused = session_volume <= 0.0
		if _elapsed >= CROSSFADE_SECONDS and _targets[index] == 0.0:
			voice.stop()
			voice.stream = null
			_bed_ids[index] = ""
	var listener := _listener.get_ref() as Node2D if _listener != null else null
	for voice: AudioStreamPlayer in _details:
		if not voice.playing or not is_instance_valid(listener): continue
		var at: Vector2 = voice.get_meta("world_position", Vector2.ZERO)
		var max_distance := float(voice.get_meta("max_distance", 720.0))
		var attenuation := clampf(1.0 - listener.global_position.distance_to(at) / max_distance, 0.0, 1.0)
		voice.volume_db = linear_to_db(maxf(0.00001, session_volume * attenuation * db_to_linear(float(voice.get_meta("gain_db", 0.0)))))
		voice.stream_paused = session_volume <= 0.0
		voice.set_meta("attenuation", attenuation)
	_playbacks = _playbacks.filter(func(reference: WeakRef) -> bool: return reference.get_ref() != null)

func play_detail(id: String, world_position: Vector2) -> bool:
	if _shutting_down or not _unlocked or candidate.is_empty() or not _valid_context() or get_tree().paused or session_volume <= 0.0 or not world_position.is_finite(): return false
	var rows: Dictionary = _bank[region][profile].details
	if not rows.has(id): return false
	var row: Dictionary = rows[id]
	if _clock - float(_last_detail.get(id, -1000.0)) < float(row.min_interval): return false
	var listener := _listener.get_ref() as Node2D
	var distance := listener.global_position.distance_to(world_position)
	if distance >= float(row.max_distance): return false
	for voice: AudioStreamPlayer in _details:
		if voice.playing: continue
		voice.stream = row.stream
		voice.set_meta("source_path", row.path)
		voice.set_meta("detail_id", id)
		voice.set_meta("world_position", world_position)
		voice.set_meta("max_distance", row.max_distance)
		voice.set_meta("gain_db", row.gain_db)
		var attenuation := 1.0 - distance / float(row.max_distance)
		voice.volume_db = linear_to_db(maxf(0.00001, session_volume * attenuation * db_to_linear(float(row.gain_db))))
		voice.play()
		_remember(voice)
		_last_detail[id] = _clock
		detail_starts[id] = int(detail_starts.get(id, 0)) + 1
		return true
	return false

func _remember(voice: AudioStreamPlayer) -> void:
	if voice.has_stream_playback(): _playbacks.append(weakref(voice.get_stream_playback()))

func _stop_details() -> void:
	for voice: AudioStreamPlayer in _details:
		voice.stop()
		voice.stream = null
	_last_detail.clear()

func _disconnect_death() -> void:
	var source := _death_source.get_ref() as Node if _death_source != null else null
	if is_instance_valid(source) and source.is_connected(&"died", _death_callback): source.disconnect(&"died", _death_callback)
	_death_source = null
	_death_callback = Callable()

func clear() -> void:
	_disconnect_death()
	profile = "original"
	region = ""
	candidate = ""
	_owner = null
	_listener = null
	_targets.fill(0.0)
	_gains.fill(0.0)
	_from.fill(0.0)
	_elapsed = CROSSFADE_SECONDS
	_bed_ids = ["", ""]
	for voice: AudioStreamPlayer in _beds:
		voice.stop()
		voice.stream = null
	_stop_details()

func snapshot() -> Dictionary:
	var beds: Array[Dictionary] = []
	for index: int in _beds.size():
		var voice := _beds[index]
		beds.append({"candidate": _bed_ids[index], "path": str(voice.get_meta("source_path", "")) if voice.stream != null else "", "playing": voice.playing, "paused": voice.stream_paused, "gain": _gains[index], "volume_db": voice.volume_db, "playback_position": voice.get_playback_position()})
	var details: Array[Dictionary] = []
	for voice: AudioStreamPlayer in _details:
		details.append({"id": str(voice.get_meta("detail_id", "")) if voice.stream != null else "", "path": str(voice.get_meta("source_path", "")) if voice.stream != null else "", "playing": voice.playing, "paused": voice.stream_paused, "volume_db": voice.volume_db, "playback_position": voice.get_playback_position()})
	return {"profile": profile, "region": region, "candidate": candidate, "beds": beds, "details": details, "starts": starts.duplicate(), "detail_starts": detail_starts.duplicate(), "unlocked": _unlocked, "max_beds": MAX_BEDS, "max_details": MAX_DETAILS}

func shutdown(timeout_msec: int = 1000) -> bool:
	_shutting_down = true
	var pending: Array[WeakRef] = _playbacks.duplicate()
	for voice: AudioStreamPlayer in _beds + _details:
		if voice.has_stream_playback(): pending.append(weakref(voice.get_stream_playback()))
	clear()
	_bank.clear()
	var deadline := Time.get_ticks_msec() + timeout_msec
	while pending.any(func(reference: WeakRef) -> bool: return reference.get_ref() != null):
		if Time.get_ticks_msec() >= deadline: return false
		await get_tree().process_frame
	return true

func _exit_tree() -> void:
	_shutting_down = true
	clear()
	_bank.clear()
