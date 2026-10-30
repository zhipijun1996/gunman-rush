class_name SelectedSfxRuntime
extends Node
## Formal-scene assembly only. Original choices/assets and shared12-voice service remain authoritative.
const SELECTION_PATH := "res://config/audio_director/selected/selected.json"
const MANIFEST_PATH := "res://assets/audio/director_v3/manifest.json"
const RULES_PATH := "res://config/audio_director/v3/runtime.json"
const HURT_FEEDBACK := {
	"id": "hurt_feedback_05",
	"variants": ["res://assets/audio/feedback_05/hurt_1.wav", "res://assets/audio/feedback_05/hurt_2.wav"]
}
const PINNED_JSON := {
	"res://config/audio_director/selected/selected.json": "ad1074fbf5f3756a1881aaefed302c3cb26871cfd51cde63c18909f1de130483",
	"res://assets/audio/director_v3/manifest.json": "27f20e502fe0c1e14769f86f19876e1d5402aed7eefedb99fc26e618e266b77f",
	"res://config/audio_director/v3/runtime.json": "506aad8bad117fd3953c51e09e8812d6184514a0746e8e0397d94d11a5facc58",
	"res://config/audio_director/selected/user-20261028.json": "56a0dd359fe5c53169794e28dcd7f333cea686d9f1d147ca70d3a3419d2ed072",
	"res://config/audio_director/selected/reels-user-20261028.json": "ac08d83ecadb0ef390779b2dba2045a9750b2ecbd88d4ebb8f8e51f5fc05e69a"
}
# Frozen transport fingerprints, not a second event/profile selection table.
# Source WAVs are QOA imports in shipped PCKs; verify the actual imported bytes.
const IMPORTED_CANDIDATES := {
  "res://assets/audio/director_v3/coin_a.wav": {
    "path": "res://.godot/imported/coin_a.wav-5a2263decb591717afe805fb8db2bcf6.sample",
    "sha256": "71e2b0c747b35251b2a5b3cf31beb3b519ea5901628f2fda53d617bc0a0db76c",
    "bytes": 3843
  },
  "res://assets/audio/director_v3/heal_a.wav": {
    "path": "res://.godot/imported/heal_a.wav-309ea4be16b163b223ee4003ecb770e7.sample",
    "sha256": "bc06ccfdb5d651bb8a88a68e8995a7b313dfdd1595143ab17331e72a0751dac0",
    "bytes": 10059
  },
  "res://assets/audio/director_v3/chest_open_a.wav": {
    "path": "res://.godot/imported/chest_open_a.wav-aefab7e287cc8e7f5385348ac9a6b3cd.sample",
    "sha256": "618a90da631523704992631a0aea1a3595096239dec53d19ee235adb6f471963",
    "bytes": 10731
  },
  "res://assets/audio/director_v3/item_get_c.wav": {
    "path": "res://.godot/imported/item_get_c.wav-d2540101ce439b8599306cc84ef5fcf2.sample",
    "sha256": "17c2594d94cfcfbf9b45e916ea32cd5c6aeee2c8b6ec0a74d29143dab7b93ea1",
    "bytes": 32627
  },
  "res://assets/audio/director_v3/click_c.wav": {
    "path": "res://.godot/imported/click_c.wav-e8f612a4aa48721f394c536fb017391a.sample",
    "sha256": "bd5807afda6fdfc0ae36ebedb117dde7e05be349154e9729e0b66db35b39c918",
    "bytes": 1731
  },
  "res://assets/audio/director_v3/confirm_c.wav": {
    "path": "res://.godot/imported/confirm_c.wav-9026cd54dc05c508b212cf7c4a85cbfb.sample",
    "sha256": "8773486471ba12eba9a6f8ac1bd86c934d79ca3f67895e4ac86e472ee12d5d72",
    "bytes": 2259
  },
  "res://assets/audio/director_v3/denied_c.wav": {
    "path": "res://.godot/imported/denied_c.wav-b4b0cd10e1cfddaefe8adc6b77cff200.sample",
    "sha256": "7260f9de467e6fad08293ed6919ab92399f165f09697501b838e90151799a7e9",
    "bytes": 2651
  },
  "res://assets/audio/director_v3/enemy_hit_b.wav": {
    "path": "res://.godot/imported/enemy_hit_b.wav-f9e39ad6481b4859ae89e5bc4e7f9342.sample",
    "sha256": "ad1d6d26b42e1f273554bd08fcd6da62cd415208b6441d7ebfda34320e3d4474",
    "bytes": 2515
  },
  "res://assets/audio/director_v3/enemy_hurt_b.wav": {
    "path": "res://.godot/imported/enemy_hurt_b.wav-b5ae0801518df37ac1aa1cb4f964f43e.sample",
    "sha256": "65a550e5e18d659ffc9d5fe6190de1b5ddf7504430d0a790f73d8f1ba89700a5",
    "bytes": 2387
  },
  "res://assets/audio/director_v3/hurt_c.wav": {
    "path": "res://.godot/imported/hurt_c.wav-d0cc8e3f8d9359fedad8474f04922d18.sample",
    "sha256": "e60746356196984af4cceb63f11b8227d48cd8dc4f532a3a7dd2c5ee269c862d",
    "bytes": 3539
  },
  "res://assets/audio/director_v3/shot_pulse_a.wav": {
    "path": "res://.godot/imported/shot_pulse_a.wav-590667a6f5386e601d620573434bff31.sample",
    "sha256": "a68a6cce1b373063131838dca92ea2d1c99c2fb00c03b28b3c6bbb0c92130bd7",
    "bytes": 2195
  }
}

var validation_ok := false
var validation_error := "not attached"
var configurations := 0
var _audio: WeakRef
var _owner: WeakRef
var _probe_enabled := false
var _probe_timer: Timer

static func read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null

static func source_validation_error() -> String:
	for path: String in PINNED_JSON:
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != PINNED_JSON[path]:
			return "selected SFX source fingerprint rejected: " + path
	return ""

static func candidate_validation_error(path: String, source_sha: String) -> String:
	if not IMPORTED_CANDIDATES.has(path): return "unknown selected candidate path"
	if source_sha.length() != 64: return "missing selected source SHA"
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path) != source_sha: return "selected source WAV SHA rejected"
	var contract: Dictionary = IMPORTED_CANDIDATES[path]
	var imported := ConfigFile.new()
	if imported.load(path + ".import") != OK or imported.get_value("remap", "path", "") != contract.path:
		return "selected import path rejected"
	if not FileAccess.file_exists(contract.path) or FileAccess.get_sha256(contract.path) != contract.sha256:
		return "selected imported resource SHA rejected"
	var file := FileAccess.open(contract.path, FileAccess.READ)
	if file == null: return "selected imported resource unavailable"
	var length := file.get_length()
	file.close()
	if length != int(contract.bytes): return "selected imported resource length rejected"
	var stream := load(path) as AudioStreamWAV
	return "" if stream != null else "selected candidate is not an imported WAV"

static func selection_validation_error(selection: Variant, manifest: Variant, rules: Variant) -> String:
	if not selection is Dictionary or not manifest is Dictionary or not rules is Dictionary: return "selected SFX JSON types rejected"
	if selection.get("candidate_version") != "audio-director-v3" or manifest.get("version") != "audio-director-v3" or rules.get("version") != "audio-director-v3": return "selected SFX version rejected"
	var profiles: Variant = selection.get("event_profiles")
	var selected_rows: Variant = selection.get("events")
	var bank_rows: Variant = manifest.get("events")
	if not profiles is Dictionary or profiles.size() != 14 or not selected_rows is Array or selected_rows.size() != 14 or not bank_rows is Array or bank_rows.size() != 14: return "complete14-event selection required"
	if not rules.get("events") is Dictionary or rules.events.size() != 14 or rules.get("voices") != GameAudio.MAX_VOICES: return "original12-voice rules required"
	if profiles.has("jump") or profiles.has("land"): return "jump/land must retain original consumers"
	var seen: Dictionary = {}
	for row: Variant in selected_rows:
		if not row is Dictionary: return "invalid selected event row"
		var id: Variant = row.get("event_id")
		var profile: Variant = row.get("profile")
		if not id is String or seen.has(id) or not profiles.has(id) or profiles[id] != profile or not rules.events.has(id): return "selected event/profile identity rejected"
		seen[id] = true
		var event: Dictionary = {}
		for value: Variant in bank_rows:
			if value is Dictionary and value.get("id") == id: event = value
		if event.is_empty(): return "selected event missing from actual bank"
		if profile == "original":
			if row.get("runtime_mode") != "original" or row.get("candidate_path") != null or row.get("candidate_sha256") != null: return "original selection changed to candidate"
			continue
		if profile not in ["A", "B", "C"] or row.get("runtime_mode") != "candidate": return "selected profile rejected"
		var candidate_id: String = str(id) + "_" + str(profile).to_lower()
		if row.get("candidate_id") != candidate_id: return "selected candidate identity rejected"
		var candidate: Dictionary = {}
		for value: Variant in event.get("candidates", []):
			if value is Dictionary and value.get("id") == candidate_id: candidate = value
		var path: Variant = row.get("candidate_path")
		var source_sha: Variant = row.get("candidate_sha256")
		if not path is String or not source_sha is String or candidate.get("path") != path or candidate.get("variants") != [path]: return "selected candidate path/variants rejected"
		var render_match := false
		for render: Variant in candidate.get("renders", []):
			if render is Dictionary and render.get("path") == path and render.get("sha256") == source_sha: render_match = true
		if not render_match: return "selected candidate source SHA differs from frozen manifest"
		var error := candidate_validation_error(path, source_sha)
		if not error.is_empty(): return error
	return ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	if OS.has_feature("web"):
		_probe_enabled = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('audio_probe') === '1'"))
	_attach.call_deferred()

func _attach() -> void:
	if validation_ok: return
	var app := get_parent() as DemoApp
	if app == null or not is_inside_tree():
		validation_error = "selected SFX requires its direct DemoApp owner"
		_publish_probe()
		return
	var service: GameAudio
	for child: Node in app.get_children():
		if child is GameAudio:
			if service != null:
				validation_error = "ambiguous direct App-owned GameAudio"
				_publish_probe()
				return
			service = child as GameAudio
	if service == null or service._shutting_down:
		validation_error = "missing active direct App-owned GameAudio"
		_publish_probe()
		return
	validation_error = source_validation_error()
	var selection: Variant = read_json(SELECTION_PATH)
	if validation_error.is_empty(): validation_error = selection_validation_error(selection, read_json(MANIFEST_PATH), read_json(RULES_PATH))
	if not validation_error.is_empty():
		_publish_probe()
		return
	# All byte/path/profile validation precedes any change to the live bank.
	if not service.configure_candidate_bank(MANIFEST_PATH, RULES_PATH) or not service.configure_selected_profiles(selection.event_profiles) or not service.configure_candidate_revision(&"hurt", HURT_FEEDBACK) or not service.set_audio_profile("selected"):
		validation_error = "existing GameAudio rejected validated selected proposal"
		_publish_probe()
		return
	_audio = weakref(service)
	_owner = weakref(app)
	validation_ok = true
	validation_error = ""
	configurations += 1
	if _probe_enabled:
		_probe_timer = Timer.new()
		_probe_timer.wait_time = 1.0
		_probe_timer.ignore_time_scale = true
		_probe_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		_probe_timer.timeout.connect(_publish_probe)
		add_child(_probe_timer)
		_probe_timer.start()
	_publish_probe()

func snapshot() -> Dictionary:
	var audio := _audio.get_ref() as GameAudio if _audio != null else null
	var owner := _owner.get_ref() as Node if _owner != null else null
	var profiles: Dictionary = {}
	var events: Array = []
	if is_instance_valid(audio):
		for id: Variant in audio._selected_profiles: profiles[str(id)] = audio.director_profile_for_event(StringName(id))
		events = audio.director_events.slice(maxi(0, audio.director_events.size() - 16)).duplicate(true)
	return {"version": "selected-sfx-runtime-v1", "validation_ok": validation_ok, "validation_error": validation_error, "configurations": configurations, "audio_profile": audio.audio_profile if is_instance_valid(audio) else "", "event_profiles": profiles, "candidate_revisions": audio._candidate_revisions.duplicate(true) if is_instance_valid(audio) else {}, "director_events": events, "owner_app_id": owner.get_instance_id() if is_instance_valid(owner) else 0, "audio_owner_id": audio.get_instance_id() if is_instance_valid(audio) else 0, "selection_path": SELECTION_PATH, "selection_sha256": PINNED_JSON[SELECTION_PATH], "manifest_path": MANIFEST_PATH, "manifest_sha256": PINNED_JSON[MANIFEST_PATH], "rules_path": RULES_PATH, "rules_sha256": PINNED_JSON[RULES_PATH], "candidate_imports_verified": IMPORTED_CANDIDATES.size() if validation_ok else 0}

func _publish_probe() -> void:
	if not _probe_enabled or not OS.has_feature("web"): return
	JavaScriptBridge.eval("window.SELECTED_SFX_SNAPSHOT = Object.freeze(" + JSON.stringify(snapshot()) + ");")
