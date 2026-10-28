class_name MetaSaveService
extends RefCounted

const SCHEMA_VERSION := 3
const CONTENT_VERSION := "plains_meta_2"
# This is a stable storage location, not the envelope format version. Renaming
# the existing local Web key would hide the user's actual v2 notes/profile.
const WEB_KEY := "gunman_rush.plains_meta.v2"
var path := ""
var web := false
var status := "memory_only"
var blocked := false
var profile_id := "local"

func configure(save_path: String, use_web: bool = OS.has_feature("web"), selected_profile_id: String = "local") -> void:
	path = save_path
	web = use_web
	profile_id = selected_profile_id
	blocked = profile_id.is_empty() or not profile_id.is_valid_identifier()
	status = "invalid_profile_id" if blocked else "configured"

func load_profile() -> Dictionary:
	if blocked and status == "invalid_profile_id":
		return {"accepted":false,"reason":status}
	var primary := _read(false)
	if primary.is_empty() and not _exists(false):
		var backup := _read(true)
		if backup.is_empty() and not _exists(true):
			status = "new_profile"
			return {"accepted": true, "payload": {}, "revision": 0}
		return _load_text(backup, true)
	var result := _load_text(primary, false)
	# Future schemas must not be overwritten with an older backup.
	if result.get("accepted", false) or result.get("reason", "") in ["future_schema", "future_content"]:
		return result
	var backup_result := _load_text(_read(true), true)
	if backup_result.get("accepted", false):
		blocked = false
		return backup_result
	blocked = true
	status = "recovery_failed"
	return {"accepted": false, "reason": status}

func commit(payload: Dictionary, revision: int) -> bool:
	if blocked or path.is_empty() or revision < 1:
		status = "write_blocked"
		return false
	var envelope := {"schema_version": SCHEMA_VERSION, "content_version": CONTENT_VERSION, "profile_id": profile_id, "profile_revision": revision, "payload": payload.duplicate(true)}
	envelope["checksum"] = canonical_json(envelope).sha256_text()
	var encoded := JSON.stringify(envelope)
	if web:
		var script := "(()=>{try {const k=%s,v=%s;const old=localStorage.getItem(k);if(old!==null){if(%s)localStorage.setItem(k+'.backup',old);else localStorage.setItem(k+'.corrupt',old);}localStorage.setItem(k,v);return localStorage.getItem(k)===v;}catch(e){return false;}})()" % [JSON.stringify(web_storage_key()), JSON.stringify(encoded), "true" if _decode(_read(false)).get("accepted", false) else "false"]
		if not bridge_boolean(JavaScriptBridge.eval(script)):
			status = "web_storage_rejected"
			return false
	else:
		var temp := path + ".tmp"
		var file := FileAccess.open(temp, FileAccess.WRITE)
		if file == null:
			status = "open_failed"
			return false
		file.store_string(encoded)
		file.flush()
		var file_error := file.get_error()
		file.close()
		if file_error != OK or FileAccess.get_file_as_string(temp) != encoded:
			status = "write_verification_failed"
			return false
		var old := _read(false)
		# Never replace a valid backup with a corrupted primary.
		if not old.is_empty() and _decode(old).get("accepted", false):
			if DirAccess.copy_absolute(path, path + ".backup") != OK:
				status = "backup_failed"
				return false
		elif _exists(false):
			if DirAccess.copy_absolute(path, path + ".corrupt") != OK:
				status = "preserve_corrupt_failed"
				return false
		if DirAccess.rename_absolute(temp, path) != OK:
			status = "rename_failed"
			return false
	status = "saved"
	return true

func _read(backup: bool) -> String:
	if web:
		var key := web_storage_key() + (".backup" if backup else "")
		var value: Variant = JavaScriptBridge.eval("(()=>{try{return localStorage.getItem(%s)||'';}catch(e){return '__STORAGE_REJECTED__';}})()" % JSON.stringify(key))
		return str(value) if value != null else "__STORAGE_REJECTED__"
	var target := path + (".backup" if backup else "")
	return FileAccess.get_file_as_string(target) if FileAccess.file_exists(target) else ""

func _load_text(encoded: String, recovered: bool) -> Dictionary:
	var result := _decode(encoded)
	if result.get("accepted", false):
		status = "recovered_backup" if recovered else "loaded"
	else:
		status = result.get("reason", "invalid_save")
		blocked = true
	return result

func _decode(encoded: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(encoded) != OK:
		return {"accepted": false, "reason": "invalid_save"}
	var data: Variant = parser.data
	if not data is Dictionary or not data.get("payload") is Dictionary:
		return {"accepted": false, "reason": "invalid_save"}
	if not data.get("schema_version") is float and not data.get("schema_version") is int:
		return {"accepted": false, "reason": "invalid_save"}
	if float(data.schema_version) != int(data.schema_version):
		return {"accepted": false, "reason": "invalid_save"}
	var schema := int(data.get("schema_version", 0))
	if schema > SCHEMA_VERSION:
		return {"accepted": false, "reason": "future_schema"}
	if not data.get("profile_revision") is float and not data.get("profile_revision") is int:
		return {"accepted": false, "reason": "invalid_save"}
	if schema in [2,SCHEMA_VERSION] and data.get("content_version") != ("plains_meta_1" if schema == 2 else CONTENT_VERSION):
		return {"accepted": false, "reason": "future_content"}
	if schema not in [1, 2, SCHEMA_VERSION] or float(data.get("profile_revision", 0)) != int(data.get("profile_revision", 0)) or int(data.get("profile_revision", 0)) < 1:
		return {"accepted": false, "reason": "invalid_save"}
	if (schema >= 2 and data.get("profile_id") != profile_id) or (schema == 1 and profile_id != "local"):
		return {"accepted":false,"reason":"profile_mismatch"}
	var unsigned: Dictionary = data.duplicate(true)
	unsigned.erase("checksum")
	var expected := canonical_json(data.payload).sha256_text() if schema == 1 else canonical_json(unsigned).sha256_text()
	if data.get("checksum", "") != expected:
		return {"accepted": false, "reason": "invalid_save"}
	var payload: Dictionary = data.payload.duplicate(true)
	if schema == 1:
		# v1 profile had no permanent upgrade map; migration is pure data.
		if not payload.has("upgrades"):
			payload["upgrades"] = {}
	if schema < SCHEMA_VERSION:
		# Pure additive migration. Domain validation still belongs to MetaProgression.
		for field: String in ["discovered_items","unlocked_home_items"]:
			if not payload.has(field): payload[field] = []
		if not payload.has("selected_home_item"): payload.selected_home_item = ""
		if not payload.has("item_progress_version"): payload.item_progress_version = 1
	return {"accepted": true, "payload": payload, "revision": int(data.profile_revision), "migrated": schema < SCHEMA_VERSION, "source_schema_version":schema}

func _exists(backup: bool) -> bool:
	if web:
		var key := web_storage_key() + (".backup" if backup else "")
		return bridge_boolean(JavaScriptBridge.eval("(()=>{try{return localStorage.getItem(%s)!==null;}catch(e){return true;}})()" % JSON.stringify(key)))
	return FileAccess.file_exists(path + (".backup" if backup else ""))

func web_storage_key() -> String:
	return WEB_KEY if profile_id == "local" else WEB_KEY + ".slot." + profile_id.uri_encode()

static func canonical_json(value: Variant) -> String:
	return JSON.stringify(_normalize(value))

static func _normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var normalized := {}
		for key: Variant in value:
			normalized[str(key)] = _normalize(value[key])
		return normalized
	if value is Array:
		var normalized := []
		for item: Variant in value:
			normalized.append(_normalize(item))
		return normalized
	if value is float and is_finite(value) and value == int(value):
		return int(value)
	return value

static func bridge_boolean(value: Variant) -> bool:
	# Godot Web may expose JS booleans as an integer, not a GDScript bool.
	# Avoid mixed-type equality and never accept strings or general truthiness.
	if value is bool:
		return value
	if value is int:
		return value == 1
	return false
