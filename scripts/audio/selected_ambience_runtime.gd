class_name SelectedAmbienceRuntime
extends Node
## Formal-scene assembly only. Programmatic DemoApp and developer Labs stay opt-in.
const REGION_SELECTION := "res://config/audio_director/ambience/user-selected.json"
const HOME_SELECTION := "res://config/audio_director/home/user-selected.json"
const REGION_MANIFEST := "res://assets/audio/ambience_v1/manifest.json"
const HOME_MANIFEST := "res://assets/audio/ambience_v1/home/manifest.json"
const REGION_OUTPUTS := {
	"plains_a": "res://assets/audio/ambience_v1/plains_a.ogg",
	"plains_b": "res://assets/audio/ambience_v1/plains_b.ogg",
	"forest_a": "res://assets/audio/ambience_v1/forest_a.ogg",
	"forest_b": "res://assets/audio/ambience_v1/forest_b.ogg",
	"plains_chime_a": "res://assets/audio/ambience_v1/plains_chime_a.wav",
	"plains_chime_b": "res://assets/audio/ambience_v1/plains_chime_b.wav",
	"forest_wood": "res://assets/audio/ambience_v1/forest_wood.wav",
	"forest_leaf": "res://assets/audio/ambience_v1/forest_leaf.wav",
}
const BEDS := {"plains": "res://assets/audio/ambience_v1/plains_a.ogg", "forest": "res://assets/audio/ambience_v1/forest_a.ogg"}
var active_context := ""
var context_epoch := 0
var configurations := 0
var validation_ok := false
var validation_error := "not attached"
var _app: WeakRef
var _audio: WeakRef
var _owner: WeakRef
var _controller: WeakRef
var _home_life: HomeAmbienceAudition
var _context_key := ""
var _dead_context := ""
var _failed_context := ""
var _expected_path := ""
var _death_callback: Callable
var _exit_callback: Callable
var _probe_enabled := false
var _next_probe_msec := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	if OS.has_feature("web"): _probe_enabled = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('audio_probe') === '1'"))
	_attach.call_deferred()

static func _read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null

static func _fingerprint(path: String, expected: Variant) -> bool:
	return expected is String and expected.length() == 64 and FileAccess.file_exists(path) and FileAccess.get_sha256(path) == expected

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _render_table(manifest: Dictionary, outputs: Dictionary) -> bool:
	var renders: Variant = manifest.get("renders")
	if not renders is Array or renders.size() != outputs.size(): return false
	var found: Dictionary = {}
	for row: Variant in renders:
		if not row is Dictionary: return false
		var id: Variant = row.get("id")
		if not id is String or not outputs.has(id) or found.has(id) or row.get("path") != outputs[id]: return false
		if not _fingerprint(outputs[id], row.get("sha256")): return false
		var bytes: Variant = row.get("bytes")
		if not _number(bytes) or float(bytes) <= 0.0 or floorf(float(bytes)) != float(bytes): return false
		var file := FileAccess.open(outputs[id], FileAccess.READ)
		if file == null: return false
		var actual_bytes := file.get_length()
		file.close()
		if actual_bytes != int(bytes): return false
		found[id] = true
	return true

static func selections_valid(regions: Variant, home: Variant) -> bool:
	if not regions is Dictionary or not home is Dictionary: return false
	if regions.get("version") != "audio-ambience-v1" or regions.get("mix_revision") != "quiet-02" or regions.get("manifest_path") != REGION_MANIFEST.trim_prefix("res://"): return false
	if not _fingerprint(REGION_MANIFEST, regions.get("manifest_sha256")): return false
	if home.get("mode") != "life" or home.get("content_version") != "audio-home-v1" or home.get("mix_revision") != "home-quiet-01" or home.get("manifest_path") != HOME_MANIFEST.trim_prefix("res://"): return false
	if not _fingerprint(HOME_MANIFEST, home.get("manifest_sha256")): return false
	var regional_manifest: Variant = _read_json(REGION_MANIFEST)
	var home_manifest: Variant = _read_json(HOME_MANIFEST)
	if not regional_manifest is Dictionary or not home_manifest is Dictionary: return false
	if not _render_table(regional_manifest, REGION_OUTPUTS) or not _render_table(home_manifest, HomeAmbienceAudition.DETAIL_PATHS): return false
	var choices: Variant = regions.get("events")
	if not choices is Array or choices.size() != 2: return false
	var seen: Dictionary = {}
	for choice: Variant in choices:
		if not choice is Dictionary: return false
		var region: Variant = choice.get("region")
		if not region is String or not BEDS.has(region) or seen.has(region): return false
		if choice.get("profile") != "A" or choice.get("candidate_id") != region + "_a" or choice.get("path") != BEDS[region]: return false
		if not _fingerprint(BEDS[region], choice.get("sha256")): return false
		if regional_manifest.regions[region].profiles.A.bed != BEDS[region]: return false
		seen[region] = true
	var bed: Variant = home.get("bed")
	if not bed is Dictionary or bed.get("path") != BEDS.plains or not _fingerprint(BEDS.plains, bed.get("sha256")): return false
	if bed.get("selection_path") != REGION_SELECTION.trim_prefix("res://") or not _fingerprint(REGION_SELECTION, bed.get("selection_sha256")): return false
	if bed.get("manifest_path") != REGION_MANIFEST.trim_prefix("res://") or bed.get("manifest_sha256") != regions.manifest_sha256: return false
	if not _number(bed.get("runtime_gain_db")) or float(bed.runtime_gain_db) != -2.0 or home_manifest.regions.home.profiles.A.bed != BEDS.plains or home_manifest.regions.home.profiles.A.gain_db != bed.runtime_gain_db: return false
	var takes: Variant = home.get("point_takes")
	if not takes is Array or takes.size() != HomeAmbienceAudition.DETAIL_PATHS.size(): return false
	seen.clear()
	for take: Variant in takes:
		if not take is Dictionary: return false
		var id: Variant = take.get("id")
		if not id is String or not HomeAmbienceAudition.DETAIL_PATHS.has(id) or seen.has(id): return false
		if take.get("path") != HomeAmbienceAudition.DETAIL_PATHS[id] or not _fingerprint(HomeAmbienceAudition.DETAIL_PATHS[id], take.get("sha256")): return false
		seen[id] = true
	var schedule: Variant = home.get("schedule")
	if not schedule is Dictionary or schedule.get("runtime_source") != "scripts/audio/home_ambience_audition.gd": return false
	var interval: Variant = schedule.get("source_interval_seconds")
	if not interval is Array or interval.size() != 2 or not _number(interval[0]) or not _number(interval[1]): return false
	if float(interval[0]) != HomeAmbienceAudition.INTERVAL_MIN or float(interval[1]) != HomeAmbienceAudition.INTERVAL_MAX: return false
	return _number(schedule.get("global_gap_seconds")) and float(schedule.global_gap_seconds) == HomeAmbienceAudition.GLOBAL_GAP and _number(schedule.get("max_simultaneous_life_cues")) and float(schedule.max_simultaneous_life_cues) == 1.0

func _attach() -> void:
	if not is_inside_tree(): return
	var app := get_parent() as DemoApp
	if app == null:
		validation_error = "formal ambience requires its direct DemoApp parent"
		return
	var audio: GameAudio
	for child: Node in app.get_children():
		if not child is GameAudio: continue
		if audio != null:
			validation_error = "ambiguous App-owned GameAudio services"
			return
		audio = child as GameAudio
	if audio == null:
		validation_error = "no direct App-owned GameAudio service"
		return
	if not selections_valid(_read_json(REGION_SELECTION), _read_json(HOME_SELECTION)):
		validation_error = "selected manifest/mode/media/schedule fingerprint validation rejected"
		return
	_app = weakref(app)
	_audio = weakref(audio)
	validation_ok = true
	validation_error = ""
	set_process(true)
	_process(0.0)

func _app_node() -> DemoApp:
	return _app.get_ref() as DemoApp if _app != null else null

func _audio_node() -> GameAudio:
	return _audio.get_ref() as GameAudio if _audio != null else null

func _desired(app: DemoApp) -> Dictionary:
	if is_instance_valid(app.menu) and app.menu.visible_panel == &"title": return {}
	if app.director.state == DemoRunDirector.State.HOME:
		var home := app.home_scene
		if is_instance_valid(home) and home.is_inside_tree() and home.is_visible_in_tree() and is_instance_valid(home.player) and is_instance_valid(home.controller) and not home.controller.actor_resources.health.terminal:
			return {"kind": "home", "owner": home, "player": home.player, "controller": home.controller, "path": BEDS.plains}
		return {}
	if app.director.state != DemoRunDirector.State.IN_STAGE or not app.lifetime.active or not is_instance_valid(app.stage) or not app.stage.is_inside_tree() or not app.stage.is_visible_in_tree() or not app.stage is GeneratedDemoStage: return {}
	if not is_instance_valid(app.player) or not is_instance_valid(app.controller) or not app.controller.active or app.controller.actor_resources.health.terminal: return {}
	var stage := app.stage as GeneratedDemoStage
	if not stage.assembly_ok: return {}
	var manifest: Variant = stage.generated.get("manifest")
	if not manifest is Dictionary: return {}
	var region: Variant = manifest.get("region")
	if region == "plains" and stage is PlainsRegionStage and not stage is ThornForestRegionStage and app.active_region_id == &"plains":
		return {"kind": "plains", "owner": stage, "player": app.player, "controller": app.controller, "path": BEDS.plains}
	if region == "thorn_forest" and stage is ThornForestRegionStage and app.active_region_id == &"thorn_forest":
		return {"kind": "forest", "owner": stage, "player": app.player, "controller": app.controller, "path": BEDS.forest}
	return {}

func _key(context: Dictionary) -> String:
	return "%s/%s/%s/%s" % [context.kind, (context.owner as Node).get_instance_id(), (context.player as Node).get_instance_id(), (context.controller as Node).get_instance_id()]

func _process(_delta: float) -> void:
	_publish_probe()
	var app := _app_node()
	var audio := _audio_node()
	if not is_instance_valid(app) or not app.is_inside_tree() or not is_instance_valid(audio) or not audio.is_inside_tree() or audio.get_parent() != app or audio._shutting_down:
		_clear_context()
		set_process(false)
		return
	var desired := _desired(app)
	if desired.is_empty():
		if not _context_key.is_empty(): _clear_context()
		return
	var key := _key(desired)
	if key == _dead_context or key == _failed_context: return
	if key == _context_key:
		if is_instance_valid(audio.ambience) and audio.ambience.candidate == ("home_a" if active_context == "home" else active_context + "_a"): return
		# Existing regional cleanup can clear a bed; recover this same live
		# context once, rather than leaving it silent until the next scene.
	_activate(desired, key)

func _inherit_verified_web_unlock() -> void:
	if not OS.has_feature("web"): return
	var app := _app_node()
	var audio := _audio_node()
	# GameMusic exists from App boot and observes the real first gesture before
	# a Home-created ambience component exists. Reuse that actual unlock only.
	if not is_instance_valid(app._music) or not app._music._unlocked or not is_instance_valid(audio.ambience) or audio.ambience._unlocked: return
	audio.ambience._unlocked = true
	if not audio.ambience.candidate.is_empty() and audio.ambience._valid_context(): audio.ambience._transition()

func _activate(context: Dictionary, key: String) -> void:
	_clear_context()
	var audio := _audio_node()
	var owner := context.owner as Node
	var controller := context.controller as PlayerController
	var accepted := false
	if context.kind == "home":
		if not is_instance_valid(_home_life):
			_home_life = HomeAmbienceAudition.new()
			add_child(_home_life)
		accepted = _home_life.configure(owner as HomeScene, audio, "life")
	else:
		accepted = audio.configure_ambience(REGION_MANIFEST)
		if accepted: accepted = audio.set_ambience_region(str(context.kind), "A", owner, context.player as Node2D)
	if not accepted:
		_failed_context = key
		validation_error = "selected ambience context configuration rejected"
		return
	_owner = weakref(owner)
	_controller = weakref(controller)
	_context_key = key
	active_context = str(context.kind)
	_expected_path = str(context.path)
	configurations += 1
	_dead_context = ""
	_failed_context = ""
	_death_callback = _on_death.bind(context_epoch, key)
	_exit_callback = _on_owner_exit.bind(context_epoch, key)
	controller.died.connect(_death_callback)
	owner.tree_exiting.connect(_exit_callback)
	_inherit_verified_web_unlock()
	_publish_probe(true)

func _disconnect_context() -> void:
	var owner := _owner.get_ref() as Node if _owner != null else null
	var controller := _controller.get_ref() as PlayerController if _controller != null else null
	if is_instance_valid(controller) and controller.died.is_connected(_death_callback): controller.died.disconnect(_death_callback)
	if is_instance_valid(owner) and owner.tree_exiting.is_connected(_exit_callback): owner.tree_exiting.disconnect(_exit_callback)
	_death_callback = Callable()
	_exit_callback = Callable()

func _clear_context() -> void:
	var audio := _audio_node()
	var owner := _owner.get_ref() as Node if _owner != null else null
	_disconnect_context()
	if is_instance_valid(_home_life): _home_life.stop()
	if is_instance_valid(audio) and is_instance_valid(owner) and is_instance_valid(audio.ambience) and audio.ambience._owner != null and audio.ambience._owner.get_ref() == owner: audio.clear_ambience()
	_owner = null
	_controller = null
	_context_key = ""
	active_context = ""
	_expected_path = ""
	context_epoch += 1

func _on_death(epoch: int, key: String) -> void:
	if epoch != context_epoch or key != _context_key: return
	_dead_context = key
	_clear_context()

func _on_owner_exit(epoch: int, key: String) -> void:
	if epoch == context_epoch and key == _context_key: _clear_context()

func _publish_probe(force: bool = false) -> void:
	if not _probe_enabled or not OS.has_feature("web"): return
	if not force and Time.get_ticks_msec() < _next_probe_msec: return
	_next_probe_msec = Time.get_ticks_msec() + 250
	# Diagnostic data only: no callable, input injection or gameplay setter.
	JavaScriptBridge.eval("window.SELECTED_AMBIENCE_SNAPSHOT = Object.freeze(" + JSON.stringify(snapshot()) + ");")

func snapshot() -> Dictionary:
	var audio := _audio_node()
	var owner := _owner.get_ref() as Node if _owner != null else null
	return {"version": "selected-ambience-runtime-v1", "validation_ok": validation_ok, "validation_error": validation_error, "selected_profiles": {"plains": "A", "forest": "A", "home": "life"} if validation_ok else {}, "session_volume": audio.volume if is_instance_valid(audio) else 0.0, "tree_paused": get_tree().paused if is_inside_tree() else false, "active_context": active_context, "context_epoch": context_epoch, "configurations": configurations, "context_key": _context_key, "dead_context": _dead_context, "expected_path": _expected_path, "owner_id": owner.get_instance_id() if is_instance_valid(owner) else 0, "audio_owner_id": audio.get_instance_id() if is_instance_valid(audio) else 0, "sfx_profile": audio.audio_profile if is_instance_valid(audio) else "", "audio": audio.ambience.snapshot() if is_instance_valid(audio) and is_instance_valid(audio.ambience) else {}, "home_life": _home_life.snapshot() if is_instance_valid(_home_life) else {}}

func _exit_tree() -> void:
	_clear_context()
	_app = null
	_audio = null
