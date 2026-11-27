@tool
extends EditorPlugin

class WorldDataExport extends EditorExportPlugin:
	const ROOT := "res://config/imported_world/"
	var current := PackedStringArray()
	var rooms := PackedStringArray()

	func _get_name() -> String:
		return "PlayableWorldData"

	func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
		rooms.clear()
		var bindings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "bindings.json"))
		for room: Dictionary in bindings.rooms.values():
			rooms.append(room.document_path)
		current.clear()
		var lock: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "current.lock.json"))
		for field: String in ["content_path", "manifest_path"]:
			current.append(ROOT + str(lock[field]))

	func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
		if path.begins_with("res://rooms/world/") and path.ends_with(".json") and path not in rooms:
			skip()
		elif path.begins_with(ROOT + "releases/") and path not in current:
			skip()

var exporter := WorldDataExport.new()

func _enter_tree() -> void:
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
