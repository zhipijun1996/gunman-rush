@tool
extends EditorExportPlugin
## The preset is the one explicit raw-file list. Family manifests bind its bytes.
## add_file never skips/remaps the normal Texture2D export/imported derivatives.
var editor_tree: SceneTree
const SELECTED_AUDIO_SOURCES: Array[String] = [
	"assets/audio/ambience_v1/plains_a.ogg", "assets/audio/ambience_v1/plains_b.ogg",
	"assets/audio/ambience_v1/forest_a.ogg", "assets/audio/ambience_v1/forest_b.ogg",
	"assets/audio/ambience_v1/plains_chime_a.wav", "assets/audio/ambience_v1/plains_chime_b.wav",
	"assets/audio/ambience_v1/forest_wood.wav", "assets/audio/ambience_v1/forest_leaf.wav",
	"assets/audio/ambience_v1/home/home_cloth_1.wav", "assets/audio/ambience_v1/home/home_cloth_2.wav",
	"assets/audio/ambience_v1/home/home_wood_1.wav", "assets/audio/ambience_v1/home/home_wood_2.wav",
	"assets/audio/ambience_v1/home/home_tools_1.wav", "assets/audio/ambience_v1/home/home_tools_2.wav",
	"assets/audio/ambience_v1/home/home_page_1.wav", "assets/audio/ambience_v1/home/home_page_2.wav",
]
const UNDERWORLD_SOURCES: Array[String] = [
	"assets/underworld_plains/backgrounds/far.png",
	"assets/underworld_plains/backgrounds/middle.png",
	"assets/underworld_plains/backgrounds/near.png",
	"assets/underworld_plains/terrain/source.png",
	"assets/underworld_plains/decor/chime_props.png",
	"assets/underworld_plains/decor/native_underworld.png",
	"assets/underworld_plains/decor/identity_props.png",
]

func _get_name() -> String:
	return "RuntimeSourcePngBytes"

static func underworld_source_contract() -> Dictionary:
	# Existing production records bind six delivered images; the terrain record
	# separately binds its native source. No new runtime manifest is required.
	var result: Dictionary = {}
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json"))
	if not catalog is Dictionary or not catalog.get("assets") is Array: return {}
	for record: Dictionary in catalog.assets:
		var path := str(record.get("path", ""))
		if path not in UNDERWORLD_SOURCES: continue
		if result.has(path): return {}
		result[path] = str(record.get("sha256", ""))
	var terrain: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/underworld_plains/terrain/terrain_build.json"))
	if not terrain is Dictionary or str(terrain.get("source_texture", "")).trim_prefix("res://") != UNDERWORLD_SOURCES[3]: return {}
	result[UNDERWORLD_SOURCES[3]] = str(terrain.get("source_sha256", ""))
	return result

static func source_plan(includes: String, excludes: String, underworld_bindings: Variant = null) -> Dictionary:
	var sources: Array[String] = []
	var underworld: Dictionary = underworld_source_contract() if underworld_bindings == null else underworld_bindings
	var pattern := RegEx.new()
	pattern.compile("^assets/(region_production_v3/spaces/[a-z0-9_]+/source|production_repair/rooted_plants_v1/raw)\\.png$")
	for entry: String in includes.split(",", false):
		var path := entry.strip_edges()
		var is_underworld := path.begins_with("assets/underworld_plains/")
		if not (is_underworld or path.begins_with("assets/region_production_v3/spaces/") or path.begins_with("assets/production_repair/")) or not path.ends_with(".png"): continue
		if (is_underworld and path not in UNDERWORLD_SOURCES) or (not is_underworld and pattern.search(path) == null):
			return {"ok": false, "error": "Raw PNG include must be one explicit canonical family source: " + path}
		for excluded: String in excludes.split(",", false):
			if path.matchn(excluded.strip_edges()):
				return {"ok": false, "error": "Raw PNG include conflicts with export exclusion: " + path}
		if is_underworld:
			var expected := str(underworld.get(path, ""))
			if expected.length() != 64 or FileAccess.get_sha256("res://" + path) != expected:
				return {"ok": false, "error": "Underworld raw PNG differs from its existing production SHA256: " + path}
			if path not in sources: sources.append(path)
			continue
		var family_path := "res://" + path.get_base_dir().path_join("family.json")
		if not FileAccess.file_exists(family_path):
			return {"ok": false, "error": "Raw PNG lacks its real family manifest: " + path}
		var family: Variant = JSON.parse_string(FileAccess.get_file_as_string(family_path))
		if not family is Dictionary or str(family.get("path", "")).trim_prefix("res://") != path:
			return {"ok": false, "error": "Raw PNG differs from its family source path: " + path}
		var digest := str(family.get("sha256", ""))
		if digest.length() != 64 or FileAccess.get_sha256("res://" + path) != digest:
			return {"ok": false, "error": "Raw PNG differs from its family SHA256: " + path}
		if path not in sources: sources.append(path)
	return {"ok": true, "sources": sources}

static func selected_audio_contract() -> Dictionary:
	var result: Dictionary = {}
	for manifest_path: String in ["res://assets/audio/ambience_v1/manifest.json", "res://assets/audio/ambience_v1/home/manifest.json"]:
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if not manifest is Dictionary or manifest.get("version") != "audio-ambience-v1": return {}
		var renders: Variant = manifest.get("renders")
		if not renders is Array or renders.size() != 8: return {}
		for row: Variant in renders:
			if not row is Dictionary: return {}
			var path := str(row.get("path", "")).trim_prefix("res://")
			if path not in SELECTED_AUDIO_SOURCES or result.has(path): return {}
			result[path] = {"sha256": row.get("sha256"), "bytes": row.get("bytes")}
	return result if result.size() == SELECTED_AUDIO_SOURCES.size() else {}

static func selected_audio_plan(includes: String, excludes: String, bindings: Variant = null) -> Dictionary:
	var contract: Dictionary = selected_audio_contract() if bindings == null else bindings
	var sources: Array[String] = []
	for entry: String in includes.split(",", false):
		var path := entry.strip_edges()
		if not path.begins_with("assets/audio/ambience_v1/") or not (path.ends_with(".ogg") or path.ends_with(".wav")): continue
		if path not in SELECTED_AUDIO_SOURCES or sources.has(path):
			return {"ok": false, "error": "Selected audio must be one unique explicit raw file: " + path}
		for excluded: String in excludes.split(",", false):
			if path.matchn(excluded.strip_edges()):
				return {"ok": false, "error": "Selected raw audio conflicts with exclusion: " + path}
		var row: Variant = contract.get(path)
		if not row is Dictionary or not row.get("sha256") is String or str(row.sha256).length() != 64:
			return {"ok": false, "error": "Selected raw audio lacks its exact render fingerprint: " + path}
		var count: Variant = row.get("bytes")
		if not (count is int or count is float) or not is_finite(float(count)) or float(count) <= 0 or floorf(float(count)) != float(count):
			return {"ok": false, "error": "Selected raw audio has invalid length: " + path}
		var bytes := FileAccess.get_file_as_bytes("res://" + path)
		if bytes.size() != int(count) or FileAccess.get_sha256("res://" + path) != row.sha256:
			return {"ok": false, "error": "Selected raw audio differs from its render fingerprint: " + path}
		sources.append(path)
	if sources.size() != SELECTED_AUDIO_SOURCES.size():
		return {"ok": false, "error": "Selected audio export requires the complete explicit sixteen-file closure"}
	return {"ok": true, "sources": sources}

func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var preset := get_export_preset()
	var planned := source_plan(preset.get_include_filter(), preset.get_exclude_filter())
	if not planned.ok:
		push_error(str(planned.error))
		editor_tree.quit(1)
		return
	for path: String in planned.sources:
		var bytes := FileAccess.get_file_as_bytes("res://" + path)
		if bytes.is_empty():
			push_error("Runtime raw PNG became unreadable during export: " + path)
			editor_tree.quit(1)
			return
		add_file("res://" + path, bytes, false)
	print("RUNTIME RAW EXPORT: %d source PNGs preserved alongside normal imports" % planned.sources.size())
	var audio := selected_audio_plan(preset.get_include_filter(), preset.get_exclude_filter())
	if not audio.ok:
		push_error(str(audio.error))
		editor_tree.quit(1)
		return
	for path: String in audio.sources:
		var bytes := FileAccess.get_file_as_bytes("res://" + path)
		if bytes.is_empty():
			push_error("Selected raw audio became unreadable during export: " + path)
			editor_tree.quit(1)
			return
		add_file("res://" + path, bytes, false)
	print("SELECTED AUDIO RAW EXPORT: %d original audio files preserved alongside normal imports" % audio.sources.size())
