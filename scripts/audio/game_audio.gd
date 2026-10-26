class_name GameAudio
extends Node
## Local presentation consumer: bounded voices, no gameplay or random-stream writes.
const MAX_VOICES := 12
# Per-origin death timbre; the existing accepted cue still owns timing/pooling.
const CUE_STREAM_OVERRIDES_META := &"audio_cue_stream_overrides"
const CUES := [&"focus_start", &"focus_end", &"enemy_defeat", &"door", &"warning", &"boss_impact", &"click", &"confirm", &"coin", &"note", &"victory", &"jump", &"land", &"step", &"hurt", &"shot", &"impact", &"armour", &"core", &"enemy_shot", &"heal", &"death", &"bell", &"denied", &"roar"]
const REGIONAL_CUE_PATHS := {
	&"forest_wind": "res://assets/forest_bible_v2/audio/forest_wind.wav",
	&"forest_fruit": "res://assets/forest_bible_v2/audio/forest_fruit.wav",
	&"forest_web": "res://assets/forest_bible_v2/audio/forest_web.wav",
}
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
var audio_profile := "original"
var director_events: Array[Dictionary] = []
var director_dropped := 0
var director_preemptions := 0
var _director_bank: Dictionary = {}
var _director_rules: Dictionary = {}
var _director_last: Dictionary = {}
var _director_variants: Dictionary = {}
var _director_clock := 0.0
var _director_random := RandomNumberGenerator.new()
var _director_profiles: Array[String] = ["A", "B"]
var _director_suppressed: Array[StringName] = []

static func ensure_buses() -> void:
	# Unity buses preserve the original mix; candidates can be balanced separately.
	for bus_name: StringName in [&"SFX", &"UI", &"Ambience", &"Music"]:
		if AudioServer.get_bus_index(bus_name) >= 0: continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")

static func cue_event(origin: Node, event_id: StringName, legacy_cue: StringName) -> void:
	if not is_instance_valid(origin) or not origin.is_inside_tree(): return
	var service := origin.get_tree().get_first_node_in_group(&"game_audio") as GameAudio
	if service == null: return
	if service.is_director_event_suppressed(event_id): return
	if service.audio_profile != "original" and service.has_director_event(event_id):
		service.play_director_event(event_id, "", origin)
	else:
		cue(origin, legacy_cue)

static func cue(origin: Node, id: StringName) -> void:
	if not is_instance_valid(origin) or not origin.is_inside_tree(): return
	var service := origin.get_tree().get_first_node_in_group(&"game_audio") as GameAudio
	if service:
		var event_id := service.director_event_for_cue(id)
		if service.is_director_event_suppressed(event_id): return
		if service.audio_profile != "original" and service.has_director_event(event_id):
			service.play_director_event(event_id, "", origin)
			return
		var stream_override: AudioStream
		if id == &"enemy_defeat":
			var overrides: Variant = origin.get_meta(CUE_STREAM_OVERRIDES_META, {})
			if overrides is Dictionary:
				var candidate: Variant = overrides.get(id)
				if candidate is AudioStream: stream_override = candidate
		service.play(id, stream_override)

static func stop_region(origin: Node) -> void:
	if not is_instance_valid(origin) or not origin.is_inside_tree(): return
	var service := origin.get_tree().get_first_node_in_group(&"game_audio") as GameAudio
	if service: service.stop_regional_cues()

static func stop_origin(origin: Node, sustained_only: bool = true) -> void:
	if not is_instance_valid(origin) or not origin.is_inside_tree(): return
	var service := origin.get_tree().get_first_node_in_group(&"game_audio") as GameAudio
	if service: service.stop_director_cues(origin, sustained_only)

static func hook_connected(origin: Node) -> void:
	if not is_instance_valid(origin) or not origin.is_inside_tree(): return
	var service := origin.get_tree().get_first_node_in_group(&"game_audio") as GameAudio
	if service == null: return
	if service.audio_profile == "original" or not service.has_director_event(&"hook_connect"):
		cue(origin, &"bell")
	else:
		service.play_director_event(&"hook_connect", "", origin)
		service.play_director_event(&"hook_pull", "", origin, true)

func stop_regional_cues() -> void:
	stop_director_cues()
	for voice: AudioStreamPlayer in _voices:
		if REGIONAL_CUE_PATHS.has(voice.get_meta("cue_id", &"")):
			voice.stop()
			voice.stream = null

func _ready() -> void:
	ensure_buses()
	_director_random.randomize()
	_load_director_bank()
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"game_audio")
	for id: StringName in CUES:
		_streams[id] = load("res://assets/audio/kenney/%s.ogg" % id)
	for id: StringName in REGIONAL_CUE_PATHS:
		_streams[id] = load(REGIONAL_CUE_PATHS[id])
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
	if node is BaseButton and not node.get_meta("audio_skip_click", false) and not node.pressed.is_connected(_click): node.pressed.connect(_click)

func _click() -> void:
	# Explicit accepted confirm/denied consumers own candidate UI feedback.
	# A generic BaseButton press cannot also announce a successful transaction.
	if audio_profile == "original" or has_director_event(&"click"): play(&"click")

func _process(delta: float) -> void:
	_clock += delta
	_director_clock += delta / maxf(0.001, Engine.time_scale)
	for voice: AudioStreamPlayer in _voices:
		if not voice.has_meta("director_origin"): continue
		var owner_ref: Variant = voice.get_meta("director_origin")
		if not voice.playing or not owner_ref is WeakRef: continue
		var origin := (owner_ref as WeakRef).get_ref() as Node
		if not is_instance_valid(origin) or not origin.is_inside_tree():
			voice.stop()
			voice.stream = null
	_playbacks = _playbacks.filter(func(reference: WeakRef) -> bool: return reference.get_ref() != null)

func play(id: StringName, stream_override: AudioStream = null) -> bool:
	var event_id := director_event_for_cue(id)
	if is_director_event_suppressed(event_id): return false
	if audio_profile != "original" and has_director_event(event_id):
		return play_director_event(event_id)
	return _play_original(id, stream_override)

func _play_original(id: StringName, stream_override: AudioStream = null) -> bool:
	if _shutting_down or not _streams.has(id) or volume <= 0: return false
	if get_tree().paused and id not in [&"click", &"confirm", &"denied"]: return false
	var interval := 0.16 if id in [&"step", &"denied", &"armour"] else 0.055
	if _clock - float(_last.get(id, -100.0)) < interval: return false
	for voice: AudioStreamPlayer in _voices:
		if voice.playing: continue
		_last[id] = _clock
		played[id] = int(played.get(id, 0)) + 1
		voice.process_mode = Node.PROCESS_MODE_ALWAYS if id in [&"click", &"confirm", &"denied"] else Node.PROCESS_MODE_PAUSABLE
		voice.set_meta("cue_id", id)
		_clear_director_metadata(voice)
		voice.set_meta("audio_priority", 90 if id in [&"hurt", &"death", &"warning", &"enemy_defeat", &"boss_impact"] else 20 if id == &"step" else 50)
		voice.bus = &"Ambience" if REGIONAL_CUE_PATHS.has(id) else &"UI" if id in [&"click", &"confirm", &"denied"] else &"SFX"
		voice.stream = stream_override if stream_override != null else _streams[id]
		var attenuation := 16.0 if id == &"forest_wind" else 11.0 if REGIONAL_CUE_PATHS.has(id) else 18.0 if id == &"step" else 10.0 if id in [&"shot", &"land", &"jump", &"click"] else 7.0
		voice.set_meta("attenuation", attenuation)
		voice.volume_db = linear_to_db(volume) - attenuation
		voice.play()
		if voice.has_stream_playback(): _playbacks.append(weakref(voice.get_stream_playback()))
		return true
	# A/B keeps unselected critical legacy cues audible under candidate load.
	# Original profile deliberately retains its existing full-pool drop policy.
	if audio_profile != "original" and id in [&"death", &"warning", &"boss_impact"]:
		var replaceable: AudioStreamPlayer
		var lowest_priority := 90
		for voice: AudioStreamPlayer in _voices:
			var priority := int(voice.get_meta("audio_priority", 100))
			if priority < lowest_priority:
				replaceable = voice
				lowest_priority = priority
		if replaceable != null:
			replaceable.stop()
			replaceable.stream = null
			director_preemptions += 1
			return _play_original(id, stream_override)
	return false

func _load_director_bank() -> void:
	configure_candidate_bank("res://assets/audio/director_candidates/manifest.json", "res://config/audio_director/runtime.json")

func has_director_event(event_id: StringName) -> bool:
	return not event_id.is_empty() and _director_bank.has(event_id)

func is_director_event_suppressed(event_id: StringName) -> bool:
	return event_id in _director_suppressed

func set_audition_focus(event_id: StringName) -> void:
	# Explicit lab-only isolation. The normal game never calls this method.
	# Both original and candidates isolate the same accepted damage layer.
	_director_suppressed.clear()
	if event_id == &"enemy_hit": _director_suppressed.append(&"enemy_hurt")
	elif event_id == &"enemy_hurt": _director_suppressed.append(&"enemy_hit")

func configure_candidate_bank(manifest_path: String, rules_path: String) -> bool:
	if _shutting_down or not FileAccess.file_exists(manifest_path) or not FileAccess.file_exists(rules_path): return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var rules: Variant = JSON.parse_string(FileAccess.get_file_as_string(rules_path))
	if not manifest is Dictionary or not rules is Dictionary: return false
	var bank: Dictionary = {}
	var profiles: Array[String] = []
	var declared_profiles: Variant = manifest.get("profiles", {"A": "A", "B": "B"})
	if not declared_profiles is Dictionary: return false
	for id: Variant in declared_profiles:
		if str(id) not in ["A", "B", "C"]: return false
		profiles.append(str(id))
	if profiles.is_empty(): return false
	for event: Dictionary in manifest.get("events", []):
		var id := StringName(event.get("id", ""))
		if id.is_empty() or bank.has(id): return false
		bank[id] = event
	if bank.is_empty() or not rules.get("events") is Dictionary: return false
	set_audio_profile("original")
	_director_bank = bank
	_director_profiles = profiles
	_director_rules = rules.events
	_director_variants.clear()
	_director_last.clear()
	return true

func set_audio_profile(profile: String) -> bool:
	if profile != "original" and profile not in _director_profiles: return false
	if profile != "original" and _director_bank.is_empty(): return false
	if profile == audio_profile: return true
	# A/B switches are review operations: old tails must not contaminate the next.
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		voice.stream = null
		_clear_director_metadata(voice)
	_director_last.clear()
	_last.clear()
	audio_profile = profile
	return true

func director_event_for_cue(id: StringName) -> StringName:
	match id:
		&"shot": return &"shot"
		&"enemy_defeat": return &"enemy_death"
		&"jump", &"land", &"hurt", &"coin", &"heal", &"confirm", &"denied": return id
		&"click": return &"click" if has_director_event(&"click") else &""
		&"note": return &"reward"
	return &""

func play_director_event(event_id: StringName, candidate: String = "", origin: Node = null, sustained: bool = false) -> bool:
	if _shutting_down or volume <= 0 or not _director_bank.has(event_id) or is_director_event_suppressed(event_id): return false
	var definition: Dictionary = _director_bank[event_id]
	var selected_profile := candidate if not candidate.is_empty() else audio_profile
	if selected_profile == "original":
		var legacy: Variant = definition.get("legacy_cue", "")
		return _play_original(StringName(legacy)) if legacy is String and not legacy.is_empty() else false
	var candidate_id := "%s_%s" % [event_id, selected_profile.to_lower()] if selected_profile in _director_profiles else selected_profile
	var chosen: Dictionary = {}
	for option: Dictionary in definition.get("candidates", []):
		if str(option.get("id", "")) == candidate_id:
			chosen = option
			break
	if chosen.is_empty(): return false
	var rule: Dictionary = _director_rules.get(str(event_id), {})
	var bus := StringName(rule.get("bus", "SFX"))
	if get_tree().paused and bus != &"UI": return false
	var interval := float(rule.get("interval", 0.055))
	if _director_clock - float(_director_last.get(event_id, -100.0)) < interval: return false
	var priority := int(rule.get("priority", 50))
	var event_count := 0
	var selected: AudioStreamPlayer
	var replaceable: AudioStreamPlayer
	var lowest_priority := priority
	for voice: AudioStreamPlayer in _voices:
		if voice.playing:
			if voice.get_meta("director_event", &"") == event_id: event_count += 1
			var voice_priority := int(voice.get_meta("audio_priority", 100))
			if voice_priority < lowest_priority:
				replaceable = voice
				lowest_priority = voice_priority
		elif selected == null: selected = voice
	if event_count >= int(rule.get("max_voices", 2)):
		director_dropped += 1
		return false
	if selected == null:
		selected = replaceable
		if selected != null:
			selected.stop()
			director_preemptions += 1
	if selected == null:
		director_dropped += 1
		return false
	var paths: Array = chosen.get("variants", [chosen.get("path", "")])
	if paths.is_empty(): return false
	var variant := _director_random.randi_range(0, paths.size() - 1)
	var previous := int(_director_variants.get(candidate_id, -1))
	if paths.size() > 1 and variant == previous:
		variant = (variant + _director_random.randi_range(1, paths.size() - 1)) % paths.size()
	var stream := load(str(paths[variant])) as AudioStream
	if stream == null: return false
	_clear_director_metadata(selected)
	selected.stream = stream
	selected.bus = bus
	selected.process_mode = Node.PROCESS_MODE_ALWAYS if bus == &"UI" else Node.PROCESS_MODE_PAUSABLE
	selected.set_meta("cue_id", StringName("director_" + event_id))
	selected.set_meta("director_event", event_id)
	selected.set_meta("director_family", &"motion" if event_id in [&"jump", &"land"] else &"weapon" if event_id in [&"shot", &"enemy_hit", &"shot_pulse", &"shot_shuriken", &"shot_bomb", &"bomb_explode"] else &"event")
	selected.set_meta("director_sustained", sustained)
	selected.set_meta("audio_priority", priority)
	if is_instance_valid(origin): selected.set_meta("director_origin", weakref(origin))
	var attenuation := float(rule.get("attenuation_db", 8.0))
	selected.set_meta("attenuation", attenuation)
	selected.volume_db = linear_to_db(volume) - attenuation
	selected.play()
	if selected.has_stream_playback(): _playbacks.append(weakref(selected.get_stream_playback()))
	_director_last[event_id] = _director_clock
	_director_variants[candidate_id] = variant
	played[StringName("director_" + event_id)] = int(played.get(StringName("director_" + event_id), 0)) + 1
	director_events.append({"id": event_id, "candidate": candidate_id, "variant": variant, "path": paths[variant], "tick": Engine.get_physics_frames(), "bus": bus, "priority": priority})
	if director_events.size() > 256: director_events.pop_front()
	return true

func stop_director_cues(origin: Node = null, sustained_only: bool = false) -> void:
	for voice: AudioStreamPlayer in _voices:
		if not voice.has_meta("director_event"): continue
		if sustained_only and not bool(voice.get_meta("director_sustained", false)): continue
		if is_instance_valid(origin):
			if not voice.has_meta("director_origin"): continue
			var owner_ref: Variant = voice.get_meta("director_origin")
			if not owner_ref is WeakRef or (owner_ref as WeakRef).get_ref() != origin: continue
		voice.stop()
		voice.stream = null
		_clear_director_metadata(voice)

func _clear_director_metadata(voice: AudioStreamPlayer) -> void:
	for key: StringName in [&"director_event", &"director_origin", &"director_sustained", &"director_family"]:
		if voice.has_meta(key): voice.remove_meta(key)

func stop_director_family(owner_id: int, family: StringName, sustained_only: bool = false) -> void:
	for voice: AudioStreamPlayer in _voices:
		if voice.get_meta("director_family", &"") != family: continue
		if sustained_only and not bool(voice.get_meta("director_sustained", false)): continue
		if not voice.has_meta("director_origin"): continue
		var owner_ref: Variant = voice.get_meta("director_origin")
		if not owner_ref is WeakRef: continue
		var origin := (owner_ref as WeakRef).get_ref() as Node
		if not is_instance_valid(origin) or origin.get_instance_id() != owner_id: continue
		voice.stop()
		voice.stream = null
		_clear_director_metadata(voice)

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
