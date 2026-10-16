@tool
extends EditorExportPlugin
## The preset is the one explicit raw-file list. Family manifests bind its bytes.
## add_file never skips/remaps the normal Texture2D export/imported derivatives.
var editor_tree: SceneTree

func _get_name() -> String:
	return "RuntimeSourcePngBytes"

static func source_plan(includes: String, excludes: String) -> Dictionary:
	var sources: Array[String] = []
	var pattern := RegEx.new()
	pattern.compile("^assets/(region_production_v3/spaces/[a-z0-9_]+/source|production_repair/rooted_plants_v1/raw)\\.png$")
	for entry: String in includes.split(",", false):
		var path := entry.strip_edges()
		if not (path.begins_with("assets/region_production_v3/spaces/") or path.begins_with("assets/production_repair/")) or not path.ends_with(".png"): continue
		if pattern.search(path) == null:
			return {"ok": false, "error": "Raw PNG include must be one explicit canonical family source: " + path}
		for excluded: String in excludes.split(",", false):
			if path.matchn(excluded.strip_edges()):
				return {"ok": false, "error": "Raw PNG include conflicts with export exclusion: " + path}
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
