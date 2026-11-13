class_name FixedWorldProvider
extends RefCounted
## Owned build output is the only runtime content source; no docs or mapgen access.
const BUNDLE := "res://build/world/runtime.json"
const PREVIEW_CATALOG := "res://build/preview/preview-world.json"
const PREVIEW_SCOPE := "res://config/editor/preview_rooms.json"
var data: Dictionary = {}
var error := ""
var _room_actions: Dictionary={}
var _preview_base: Dictionary = {}
var _preview_data: Dictionary = {}
var _editor_documents: Dictionary = {}
var preview_catalog_error := ""

func open(path: String = BUNDLE) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema") != 1 or not parsed.get("rooms") is Dictionary or not parsed.get("actions") is Array or str(parsed.get("content_version", "")).length() != 64:
		error = "invalid_world_bundle"
		return false
	data = parsed
	_room_actions.clear()
	for action: Dictionary in data.actions:
		if not _room_actions.has(action.room_id): _room_actions[action.room_id]=[]
		_room_actions[action.room_id].append(action)
	return true

func room(id: String) -> Dictionary:
	return data.get("rooms", {}).get(id, {})

func actions_in(room_id: String) -> Array:
	return _room_actions.get(room_id,[])

func action(id: String) -> Dictionary:
	for row: Dictionary in data.get("actions", []):
		if row.id == id: return row
	return {}

func resolve(request: LevelRequest) -> Dictionary:
	var row := room(request.room_id)
	if row.is_empty(): return {"error":"room_not_implemented"}
	if not request.expected_hash.is_empty() and request.expected_hash != data.content_version: return {"error":"content_version_mismatch"}
	var document_path := str(row.get("document_ref", ""))
	var packed: PackedScene
	var document: Dictionary = {}
	if _editor_documents.has(request.room_id):
		document = _editor_documents[request.room_id]
	elif not document_path.is_empty():
		document = WorldRoomDocument.read(document_path)
		if document.has("error"): return document
	else:
		packed = load(str(row.scene_ref)) as PackedScene
		if packed == null: return {"error":"scene_missing"}
	var entry: Dictionary = {}
	if not request.entry_door_id.is_empty():
		for door: Dictionary in row.doors:
			if door.id == request.entry_door_id: entry = door
		if entry.is_empty(): return {"error":"entry_missing"}
	return {"room":row,"scene":packed,"document":document,"entry":entry,"content_version":data.content_version}

static func point(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

static func rect(value: Array) -> Rect2:
	return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))

func preview_base_version() -> String:
	return str((_preview_base if not _preview_base.is_empty() else data).get("content_version", ""))

func preview_available_room_ids() -> Array:
	var catalog := _preview_catalog()
	return (catalog.get("rooms", {}) if not catalog.is_empty() else data.get("rooms", {})).keys()

func preview_formal_room_ids() -> Array:
	return (_preview_base if not _preview_base.is_empty() else data).get("rooms", {}).keys()

func _preview_catalog() -> Dictionary:
	if not _preview_data.is_empty() and _preview_data.get("base_content_version") == preview_base_version(): return _preview_data
	preview_catalog_error = ""
	if not FileAccess.file_exists(PREVIEW_CATALOG):
		preview_catalog_error = "preview_catalog_missing"
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_CATALOG))
	if not parsed is Dictionary or parsed.get("schema") != 1 or parsed.get("base_content_version") != preview_base_version():
		preview_catalog_error = "preview_catalog_version_mismatch"
		return {}
	if not parsed.get("rooms") is Dictionary or not parsed.get("actions") is Array or not parsed.get("demo_services") is Dictionary or not parsed.get("map_rooms") is Array or not parsed.get("npcs") is Array:
		preview_catalog_error = "preview_catalog_invalid"
		return {}
	# This packaged catalog is compiled from the same canonical sources. A web
	# draft may select a packaged scene, but cannot introduce a script/resource path.
	var formal: Dictionary = _preview_base if not _preview_base.is_empty() else data
	var bindings: Variant = parsed.get("construction_scene_bindings")
	if not bindings is Dictionary or parsed.get("construction_sha256") != formal.get("sources", {}).get("construction.json"):
		preview_catalog_error = "preview_scene_bindings_invalid"
		return {}
	var expected: Dictionary = {}
	for id: Variant in bindings:
		if not id is String or not bindings[id] is String:
			preview_catalog_error = "preview_scene_bindings_invalid"
			return {}
		if id.begins_with("P-R"): expected[id] = bindings[id]
	if FileAccess.file_exists(PREVIEW_SCOPE):
		var scope: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_SCOPE))
		if not scope is Dictionary or scope.get("schema") != 1 or not scope.get("additional_room_ids") is Array or parsed.get("scope_sha256") != FileAccess.get_sha256(PREVIEW_SCOPE):
			preview_catalog_error = "preview_scope_invalid"
			return {}
		for id: Variant in scope.additional_room_ids:
			if not id is String or not bindings.has(id) or expected.has(id):
				preview_catalog_error = "preview_scope_invalid"
				return {}
			expected[id] = bindings[id]
	elif not str(parsed.get("scope_sha256", "")).is_empty():
		preview_catalog_error = "preview_scope_missing"
		return {}
	for id:String in formal.get("rooms",{}):
		if not bindings.has(id) or bindings[id]!=formal.rooms[id].scene_ref:
			preview_catalog_error="preview_scene_bindings_invalid"
			return {}
		expected[id]=bindings[id]
	if expected.is_empty() or parsed.rooms.size() != expected.size() or bindings.size() != expected.size():
		preview_catalog_error = "preview_catalog_incomplete"
		return {}
	for id: String in formal.get("rooms", {}):
		if not expected.has(id):
			preview_catalog_error = "preview_catalog_incomplete"
			return {}
	for id: String in expected:
		var expected_path := str(expected[id])
		var row: Variant = parsed.rooms.get(id)
		if not row is Dictionary or row.get("room_id") != id or row.get("scene_ref") != expected_path or not expected_path.begins_with("res://") or not ResourceLoader.exists(expected_path):
			preview_catalog_error = "preview_scene_not_packaged:"+id
			return {}
	_preview_data = parsed
	return _preview_data

func preview_snapshot() -> Dictionary:
	return {"data":data.duplicate(true), "base":_preview_base.duplicate(true), "editor_documents":_editor_documents.duplicate(true)}

func restore_preview_snapshot(snapshot: Dictionary) -> void:
	data = snapshot.data.duplicate(true)
	_preview_base = snapshot.base.duplicate(true)
	_editor_documents = snapshot.get("editor_documents", {}).duplicate(true)
	_index_actions()

func restore_preview_base() -> void:
	if not _preview_base.is_empty(): data = _preview_base.duplicate(true)
	_preview_base.clear()
	_editor_documents.clear()
	_index_actions()

func install_editor_project(project: Dictionary, selected: String, verified_behavior_hash := "") -> String:
	var base: Dictionary = _preview_base if not _preview_base.is_empty() else data
	var compiled := WorldEditorRuntime.compile(base, project, selected, verified_behavior_hash)
	if compiled.has("error"): return str(compiled.error)
	if _preview_base.is_empty(): _preview_base = data.duplicate(true)
	data = compiled.runtime
	_editor_documents = compiled.documents
	_index_actions()
	return ""

func _index_actions() -> void:
	_room_actions.clear()
	for action: Dictionary in data.get("actions", []):
		if not _room_actions.has(action.room_id): _room_actions[action.room_id] = []
		_room_actions[action.room_id].append(action)

