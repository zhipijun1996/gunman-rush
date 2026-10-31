class_name HomeAmbienceAudition
extends Node
## Development-only composition of real Home NPC anchors and existing GameAudio.
## These static NPCs have no action-frame signal: this is sparse place Foley.
const MANIFEST_PATH := "res://assets/audio/ambience_v1/home/manifest.json"
const SELECTION_PATH := "res://config/audio_director/ambience/user-selected.json"
const SELECTED_MANIFEST_PATH := "res://assets/audio/ambience_v1/manifest.json"
const BED_PATH := "res://assets/audio/ambience_v1/plains_a.ogg"
const DETAIL_PATHS := {
	"home_cloth_1": "res://assets/audio/ambience_v1/home/home_cloth_1.wav",
	"home_cloth_2": "res://assets/audio/ambience_v1/home/home_cloth_2.wav",
	"home_wood_1": "res://assets/audio/ambience_v1/home/home_wood_1.wav",
	"home_wood_2": "res://assets/audio/ambience_v1/home/home_wood_2.wav",
	"home_tools_1": "res://assets/audio/ambience_v1/home/home_tools_1.wav",
	"home_tools_2": "res://assets/audio/ambience_v1/home/home_tools_2.wav",
	"home_page_1": "res://assets/audio/ambience_v1/home/home_page_1.wav",
	"home_page_2": "res://assets/audio/ambience_v1/home/home_page_2.wav",
}
const FAMILIES := {"character": "cloth", "upgrade": "wood", "arms": "tools", "achievements": "page"}
const INTERVAL_MIN := 12.0
const INTERVAL_MAX := 22.0
const GLOBAL_GAP := 6.0
const PRESENTATION_SEED := 1213156677
const MAX_EVENTS := 64
var _home: WeakRef
var _audio: WeakRef
var _controller: WeakRef
var _sources: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _random := RandomNumberGenerator.new()
var _clock := 0.0
var _global_due := 0.0
var _mode := "original"
var _suspended := false
var _manifest_ready := false
var _death_callback: Callable
var _exit_callback: Callable

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func configure(home: HomeScene, audio: GameAudio, mode: String = "life") -> bool:
	if not is_inside_tree() or mode not in ["original", "bed", "life"]: return false
	if not is_instance_valid(home) or not home.is_inside_tree() or not is_instance_valid(home.world) or not is_instance_valid(home.player) or not is_instance_valid(home.controller): return false
	if not is_instance_valid(audio) or not audio.is_inside_tree() or audio.get_tree() != home.get_tree(): return false
	if not validate_manifest(_read_json(MANIFEST_PATH)) or not _selection_matches(): return false
	var prior_audio := _audio_node()
	if not audio.configure_ambience(MANIFEST_PATH): return false
	# Do not strand an old live service when this audition is rebound.
	# Clear it only after the new proposal succeeds, preserving failed proposals.
	if is_instance_valid(prior_audio) and prior_audio != audio and _owns_component(): prior_audio.clear_ambience()
	_disconnect_signals()
	_home = weakref(home)
	_audio = weakref(audio)
	_controller = weakref(home.controller)
	_manifest_ready = true
	_random.seed = PRESENTATION_SEED
	_clock = 0.0
	_global_due = 0.0
	_events.clear()
	_sources.clear()
	var found_slots: Dictionary = {}
	for child: Node in home.world.get_children():
		if not child is Sprite2D or not child.has_meta(&"home_function") or not child.has_meta(&"home_root"): continue
		var slot_id := str(child.get_meta(&"home_function"))
		if not FAMILIES.has(slot_id) or found_slots.has(slot_id) or not _active_keeper(home, slot_id): continue
		var foot: Variant = child.get_meta(&"home_root")
		if not foot is Vector2 or not foot.is_finite(): continue
		found_slots[slot_id] = true
		var family := str(FAMILIES[slot_id])
		_sources.append({"slot_id": slot_id, "family": family, "event_ids": ["home_%s_1" % family, "home_%s_2" % family], "sprite": weakref(child), "root": foot, "due": 0.0, "variant_next": 0, "missed": 0})
	_sources.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.slot_id) < str(b.slot_id))
	_death_callback = _on_death
	_exit_callback = stop
	home.controller.died.connect(_death_callback)
	home.tree_exiting.connect(_exit_callback)
	_mode = "original"
	set_process(true)
	return set_mode(mode)

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func validate_manifest(value: Variant) -> bool:
	# Validate actual consumed identities; this is not an unused preload list.
	if not value is Dictionary or value.get("version") != "audio-ambience-v1" or value.get("task") != "AUDIO-HOME-01": return false
	var regions: Variant = value.get("regions")
	if not regions is Dictionary or regions.size() != 1 or not regions.has("home"): return false
	var region: Variant = regions.home
	if not region is Dictionary: return false
	var profiles: Variant = region.get("profiles")
	if not profiles is Dictionary or profiles.size() != 1 or not profiles.has("A"): return false
	var row: Variant = profiles.A
	if not row is Dictionary or row.get("bed") != BED_PATH: return false
	var details: Variant = row.get("details")
	if not details is Array or details.size() != DETAIL_PATHS.size(): return false
	var found: Dictionary = {}
	for detail: Variant in details:
		if not detail is Dictionary: return false
		var id: Variant = detail.get("id")
		if not id is String or not DETAIL_PATHS.has(id) or found.has(id): return false
		if detail.get("path") != DETAIL_PATHS[id]: return false
		found[id] = true
	return true

func _selection_matches() -> bool:
	var selected: Variant = _read_json(SELECTION_PATH)
	if not selected is Dictionary or selected.get("manifest_sha256") != FileAccess.get_sha256(SELECTED_MANIFEST_PATH): return false
	var events: Variant = selected.get("events")
	if not events is Array: return false
	for event: Variant in events:
		if not event is Dictionary or event.get("region") != "plains": continue
		return event.get("profile") == "A" and event.get("candidate_id") == "plains_a" and event.get("path") == BED_PATH and event.get("sha256") == FileAccess.get_sha256(BED_PATH)
	return false

func _active_keeper(home: HomeScene, slot_id: String) -> bool:
	for entry: Dictionary in home.world.specification.slots:
		if str(entry.id) == slot_id: return bool(entry.active) and not str(entry.keeper).is_empty()
	return false

func _home_node() -> HomeScene:
	return _home.get_ref() as HomeScene if _home != null else null

func _audio_node() -> GameAudio:
	return _audio.get_ref() as GameAudio if _audio != null else null

func _owns_component() -> bool:
	var audio := _audio_node()
	var home := _home_node()
	return is_instance_valid(audio) and is_instance_valid(home) and is_instance_valid(audio.ambience) and audio.ambience._owner != null and audio.ambience._owner.get_ref() == home

func set_mode(mode: String) -> bool:
	if not _manifest_ready or mode not in ["original", "bed", "life"]: return false
	var home := _home_node()
	var audio := _audio_node()
	if not is_instance_valid(home) or not home.is_inside_tree() or not is_instance_valid(audio) or not is_instance_valid(home.player): return false
	if mode == "original":
		if _owns_component(): audio.clear_ambience()
	else:
		if not audio.set_ambience_region("home", "A", home, home.player): return false
		if is_instance_valid(audio.ambience): audio.ambience._stop_details()
	_mode = mode
	_suspended = false
	_schedule_all()
	return true

func _schedule_all() -> void:
	for row: Dictionary in _sources: row.due = _clock + _random.randf_range(INTERVAL_MIN, INTERVAL_MAX)

func _source_position(row: Dictionary) -> Vector2:
	var home := _home_node()
	var sprite := (row.sprite as WeakRef).get_ref() as Sprite2D
	if not is_instance_valid(home) or not is_instance_valid(home.world) or not is_instance_valid(sprite) or not sprite.is_inside_tree() or sprite.get_parent() != home.world: return Vector2.INF
	return home.world.to_global(row.root as Vector2)

func _visible_source(row: Dictionary, point: Vector2) -> bool:
	var sprite := (row.sprite as WeakRef).get_ref() as Sprite2D
	if not is_instance_valid(sprite) or not sprite.is_visible_in_tree() or not point.is_finite(): return false
	var screen := get_viewport().get_canvas_transform() * point
	return get_viewport().get_visible_rect().has_point(screen)

func _stop_details() -> void:
	var audio := _audio_node()
	if _owns_component(): audio.ambience._stop_details()

func _process(delta: float) -> void:
	var home := _home_node()
	var audio := _audio_node()
	if not is_instance_valid(home) or not home.is_inside_tree() or not home.is_visible_in_tree() or not is_instance_valid(audio) or not is_instance_valid(home.player):
		stop()
		return
	if _mode != "life": return
	if not _owns_component():
		stop()
		return
	# A Home panel can block input and pause the tree in the same frame.
	# Drop life tails first, so unpausing cannot resume a pre-panel sound.
	if home.input_blocked:
		_stop_details()
		_suspended = true
		return
	if get_tree().paused:
		_suspended = true
		return
	_clock += delta / maxf(0.001, Engine.time_scale)
	if _suspended:
		_suspended = false
		_schedule_all()
		_global_due = _clock + GLOBAL_GAP
		return
	for row: Dictionary in _sources:
		if _clock < float(row.due): continue
		# Every due request is consumed, even distant/hidden/busy/quiet ones.
		# There is no backlog waiting to fire when the player arrives.
		row.due = _clock + _random.randf_range(INTERVAL_MIN, INTERVAL_MAX)
		var position := _source_position(row)
		if not _visible_source(row, position) or _clock < _global_due:
			row.missed = int(row.missed) + 1
			continue
		if audio.ambience._details.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing):
			row.missed = int(row.missed) + 1
			continue
		var ids: Array = row.event_ids
		var event_id := str(ids[int(row.variant_next)])
		if not audio.ambience.play_detail(event_id, position):
			row.missed = int(row.missed) + 1
			continue
		row.variant_next = 1 - int(row.variant_next)
		_global_due = _clock + GLOBAL_GAP
		_record(event_id, row, position, audio, home)

func _record(event_id: String, row: Dictionary, position: Vector2, audio: GameAudio, home: HomeScene) -> void:
	for index: int in audio.ambience._details.size():
		var voice := audio.ambience._details[index]
		if not voice.playing or str(voice.get_meta("detail_id", "")) != event_id: continue
		_events.append({"event_id": event_id, "path": str(voice.get_meta("source_path", "")), "slot": str(row.slot_id), "world_position": [position.x, position.y], "listener_position": [home.player.global_position.x, home.player.global_position.y], "distance": home.player.global_position.distance_to(position), "volume_db": voice.volume_db, "clock": _clock, "physics_tick": Engine.get_physics_frames(), "voice_index": index, "scope": "sparse NPC-place Foley; static keeper has no action-frame signal"})
		if _events.size() > MAX_EVENTS: _events.pop_front()
		return

func snapshot() -> Dictionary:
	var anchors: Array[Dictionary] = []
	var home := _home_node()
	var audio := _audio_node()
	for row: Dictionary in _sources:
		var point := _source_position(row)
		anchors.append({"slot_id": row.slot_id, "family": row.family, "event_ids": (row.event_ids as Array).duplicate(), "npc_position": [point.x, point.y] if point.is_finite() else [], "source_position": [point.x, point.y] if point.is_finite() else [], "due": row.due, "variant_next": row.variant_next, "missed": row.missed, "visible": _visible_source(row, point)})
	return {"mode": _mode, "clock": _clock, "global_due": _global_due, "interval_min": INTERVAL_MIN, "interval_max": INTERVAL_MAX, "global_gap": GLOBAL_GAP, "presentation_seed": PRESENTATION_SEED, "source_anchors": anchors, "events": _events.duplicate(true), "input_blocked": home.input_blocked if is_instance_valid(home) else false, "audio": audio.ambience.snapshot() if is_instance_valid(audio) and is_instance_valid(audio.ambience) else {}}

func _disconnect_signals() -> void:
	var home := _home_node()
	var controller := _controller.get_ref() as PlayerController if _controller != null else null
	if is_instance_valid(controller) and controller.died.is_connected(_death_callback): controller.died.disconnect(_death_callback)
	if is_instance_valid(home) and home.tree_exiting.is_connected(_exit_callback): home.tree_exiting.disconnect(_exit_callback)
	_death_callback = Callable()
	_exit_callback = Callable()

func _on_death() -> void:
	stop()

func stop() -> void:
	var audio := _audio_node()
	if _owns_component(): audio.clear_ambience()
	_disconnect_signals()
	_mode = "original"
	_manifest_ready = false
	_home = null
	_audio = null
	_controller = null
	set_process(false)

func _exit_tree() -> void:
	stop()
