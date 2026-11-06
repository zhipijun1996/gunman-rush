class_name WorldSettings
extends RefCounted
## Independent user preferences. Uses the same checked I/O with its own kind/key/slot.
var storage:=WorldSaveService.new()
var revision:=0
var value: Dictionary={}
var error:=""
func open(path: String,profile: String) -> void:
	storage.save_kind="player_settings"
	storage.key_prefix="gunman_rush.settings.v1."
	storage.configure(path,OS.has_feature("web"),profile)
	storage.content_version=FileAccess.get_sha256("res://config/input_profile.json")
	storage.payload_validator=valid
	value={"input":InputProfile.load_default().values.duplicate(true),"volume":0.7,"reduced":false}
	var loaded:=storage.load_profile()
	if not loaded.get("accepted",false): error=storage.status;return
	revision=int(loaded.revision)
	if not loaded.payload.is_empty(): value=loaded.payload.duplicate(true)
func valid(candidate: Dictionary) -> bool:
	if not candidate.get("input") is Dictionary or not candidate.get("reduced") is bool: return false
	if not (candidate.get("volume") is int or candidate.get("volume") is float) or not is_finite(candidate.volume) or candidate.volume<0 or candidate.volume>1: return false
	return InputProfile.new().configure(candidate.input)
func save(candidate: Dictionary) -> bool:
	if not valid(candidate): error="invalid_settings";return false
	if not storage.commit(candidate,revision+1): error=storage.status;return false
	value=candidate.duplicate(true);revision+=1;error=""
	return true
func apply(controller: PlayerController) -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.0001,value.volume)))
	if controller!=null: controller.router.reconfigure(value.input)
