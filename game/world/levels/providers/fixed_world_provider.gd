class_name FixedWorldProvider
extends RefCounted
## Owned build output is the only runtime content source; no docs or mapgen access.
const BUNDLE := "res://build/world/runtime.json"
var data: Dictionary = {}
var error := ""
var _room_actions: Dictionary={}

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
	var packed := load(str(row.scene_ref)) as PackedScene
	if packed == null: return {"error":"scene_missing"}
	var entry: Dictionary = {}
	if not request.entry_door_id.is_empty():
		for door: Dictionary in row.doors:
			if door.id == request.entry_door_id: entry = door
		if entry.is_empty(): return {"error":"entry_missing"}
	return {"room":row,"scene":packed,"entry":entry,"content_version":data.content_version}

static func point(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

static func rect(value: Array) -> Rect2:
	return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))
