class_name RuntimeMapFrozenSource
extends RefCounted
## Development fixture I/O only. No Python, network, executable paths or RNG.
const ROOT := "res://resources/levels/mapgen_host_v2_01/"
const IDS: Array[String] = ["M16", "M18", "M21"]

static func read_inputs() -> Dictionary:
	var lock: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"input-lock.json"))
	if not lock is Dictionary or lock.get("schema") != "gunman-rush/mapgen-frozen-input/v1" or not lock.get("files") is Dictionary:
		return {"ok":false,"error":"Invalid frozen input lock"}
	var names: Array[String] = ["map.json","bindings.json","selection.json"]
	for id: String in IDS: names.append("content/"+id+".json")
	if lock.files.size() != names.size(): return {"ok":false,"error":"Unexpected frozen input members"}
	var values: Dictionary = {}
	for name: String in names:
		if not FileAccess.file_exists(ROOT+name) or FileAccess.get_sha256(ROOT+name) != lock.files.get(name, ""):
			return {"ok":false,"error":"Frozen input SHA mismatch: "+name}
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+name))
		if not raw is Dictionary: return {"ok":false,"error":"Invalid frozen JSON: "+name}
		values[name] = raw
	if values["map.json"].get("module_package",{}).get("sha256") != lock.get("library_sha256"):
		return {"ok":false,"error":"Frozen library identity mismatch"}
	var contents: Dictionary = {}
	for id: String in IDS: contents["content/"+id+".json"] = values["content/"+id+".json"]
	return {"ok":true,"map":values["map.json"],"content":contents,"bindings":values["bindings.json"],"lock":lock}

static func load_level(request: LevelRequest, binding: String = "seam") -> LevelBuildResult:
	var source := read_inputs()
	if not source.ok:
		var refused := LevelBuildResult.new()
		refused.error = str(source.error)
		return refused
	var point: Variant = source.bindings.get("spawns",{}).get(binding)
	if not LevelContentValidation.point(point):
		var refused := LevelBuildResult.new()
		refused.error = "Unknown slice spawn binding: "+binding
		return refused
	return RuntimeMapV2Provider.load_level(request, source.map, source.content, IDS, Vector2(point[0],point[1]), source.lock.files["map.json"], source.bindings, source.lock, binding)
