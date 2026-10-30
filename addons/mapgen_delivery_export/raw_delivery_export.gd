@tool
extends EditorExportPlugin
## The editor ignores the immutable vendor tree. Ship its exact original bytes
## so FileAccess hashing and dynamically loaded native scripts work in a PCK.
const ROOT = "res://third_party/mapgen/0.1.0/"
const MANIFEST_SHA256 = "bef5b567fcd367913be474a02df3bdbb62cf8c8d2902c380861055f272e9cbc0"
var editor_tree: SceneTree

func _get_name() -> String:
	return "PinnedMapgenDelivery"

func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	# Each delivery/config path is emitted once as exact source bytes above.
	# A JSON referenced literally by a script can also enter normal dependencies.
	if path.begins_with(ROOT) or path == "res://config/mapgen_930001.json":
		skip()

func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	if FileAccess.get_sha256(ROOT + "manifest.json") != MANIFEST_SHA256:
		push_error("Pinned delivery manifest changed")
		editor_tree.quit(1)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	for relative: String in manifest.files:
		if FileAccess.get_sha256(ROOT + relative) != manifest.files[relative]:
			push_error("Delivery hash mismatch: " + relative)
			editor_tree.quit(1)
			return
	for relative: String in manifest.files:
		add_file(ROOT + relative, FileAccess.get_file_as_bytes(ROOT + relative), false)
	add_file(ROOT + "manifest.json", FileAccess.get_file_as_bytes(ROOT + "manifest.json"), false)
	add_file("res://config/mapgen_930001.json", FileAccess.get_file_as_bytes("res://config/mapgen_930001.json"), false)
	print("MAPGEN RAW EXPORT: ", manifest.files.size() + 1, " original files preserved")
