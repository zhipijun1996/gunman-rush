class_name RuntimeMapGenerationProfile
extends RefCounted
## One typed, locked input read reused for session seed and source begin.
const DATA := preload("res://addons/mapgen/data_json.gd")
const LOCK_PATH := "res://config/mapgen_candidate.json"

static func read_profile(key: String = "conformance") -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOCK_PATH))
	if not value is Dictionary: return {"ok":false,"error":"Invalid candidate lock"}
	var lock: Dictionary = value
	if not lock.get(key) is Dictionary: return {"ok":false,"error":"Unknown locked generation input profile: "+key}
	var profile: Dictionary = lock[key]
	for name: String in ["request","config"]:
		if not profile.get(name) is Dictionary: return {"ok":false,"error":"Missing profile input: "+name}
		var item: Dictionary = profile[name]
		if not item.get("path") is String or not item.get("sha256") is String or not FileAccess.file_exists(item.path) or FileAccess.get_sha256(item.path)!=item.sha256:
			return {"ok":false,"error":"Locked profile input SHA mismatch: "+name}
	var request: Dictionary = DATA.parse(FileAccess.get_file_as_string(profile.request.path))
	var config: Dictionary = DATA.parse(FileAccess.get_file_as_string(profile.config.path))
	if not request.ok or not config.ok or not request.value is Dictionary or not config.value is Dictionary:
		return {"ok":false,"error":"Invalid typed algorithm inputs"}
	if not request.value.get("seed") is int: return {"ok":false,"error":"Profile seed must remain an actual integer"}
	return {"ok":true,"error":"","lock":lock,"request":request.value,"config":config.value,"seed":str(request.value.seed)}
