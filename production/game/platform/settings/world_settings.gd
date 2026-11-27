class_name WorldSettings
extends RefCounted
## Preferences have their own checked envelope. Replacing a world never touches this slot.
signal changed
const SLOT := "user://player_settings_v1.json"
const PROFILE := "plains04_construction"
static var _current: WorldSettings
var storage := WorldSaveService.new()
var revision := 0
var value: Dictionary = {}
var error := ""
var _session: WeakRef
var _application_suspended := false

static func current() -> WorldSettings:
	if _current == null:
		_current = WorldSettings.new()
		_current.open(SLOT, PROFILE)
	return _current

func open(path: String, profile: String) -> void:
	storage.save_kind = "player_settings"
	storage.key_prefix = "gunman_rush.settings.v1."
	storage.configure(path, OS.has_feature("web"), profile)
	storage.content_version = FileAccess.get_sha256("res://config/input_profile.json")
	storage.payload_validator = valid
	value = {"input": InputProfile.load_default().values.duplicate(true), "volume": 0.7, "reduced": false}
	revision = 0
	error = ""
	var loaded := storage.load_profile()
	if loaded.get("accepted", false):
		revision = int(loaded.revision)
		if not loaded.payload.is_empty():
			value = loaded.payload.duplicate(true)
		elif path == SLOT and profile == PROFILE and not storage.web:
			_import_old_native_slot()
	else:
		error = storage.status
	_apply_audio()

func _import_old_native_slot() -> void:
	var current_dir := OS.get_user_data_dir()
	if current_dir.get_file() != "Gunman Rush Rebuild":
		return
	var old_path := current_dir.get_base_dir().path_join("Gunman Rush").path_join(SLOT.get_file())
	if not FileAccess.file_exists(old_path) and not FileAccess.file_exists(old_path + ".backup"):
		return
	var old := WorldSaveService.new()
	old.configure(old_path, false, PROFILE)
	old.save_kind = storage.save_kind
	old.content_version = storage.content_version
	old.payload_validator = valid
	var result := old.load_profile()
	if result.get("accepted", false) and not result.payload.is_empty():
		if storage.commit(result.payload, int(result.revision)):
			revision = int(result.revision)
			value = result.payload.duplicate(true)
		else:
			error = storage.status

func valid(candidate: Dictionary) -> bool:
	if not candidate.get("input") is Dictionary or not candidate.get("reduced") is bool:
		return false
	var volume: Variant = candidate.get("volume")
	if not (volume is int or volume is float) or not is_finite(volume) or volume < 0 or volume > 1:
		return false
	return InputProfile.new().configure(candidate.input)

func save(candidate: Dictionary) -> bool:
	if not valid(candidate):
		error = "invalid_settings"
		return false
	if not storage.commit(candidate, revision + 1):
		error = storage.status
		return false
	value = candidate.duplicate(true)
	revision += 1
	error = ""
	_apply_audio()
	var session := _session.get_ref() as OrdinaryRoomSession if _session != null else null
	if is_instance_valid(session) and not session.is_queued_for_deletion():
		apply_session(session)
	changed.emit()
	return true

func set_application_suspended(suspended: bool) -> void:
	_application_suspended = suspended
	_apply_audio()

func _apply_audio() -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(0.0001, value.volume)))
	AudioServer.set_bus_mute(master, _application_suspended or value.volume == 0)

func apply_session(session: OrdinaryRoomSession) -> void:
	_session = weakref(session)
	session.controller.router.reconfigure(value.input)
	session.touch_controls.update_layout()
	session.set_meta(&"reduced_vfx", value.reduced)
	session.focus_heal.reduced = value.reduced
	session.focus_vignette.enabled = not value.reduced
	session.camera.reduced_effects = value.reduced
	var motion := session.player.get_node_or_null("MotionFeel") as PlayerMotionFeel
	if motion != null:
		motion.reduced_effects = value.reduced
