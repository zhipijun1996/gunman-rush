class_name FixedWorldProvider
extends RefCounted
## Owned build output is the only runtime content source; no docs or mapgen access.
const BUNDLE := "res://build/world/runtime.json"
const WORKBENCH_CATALOG := "res://build/workbench/preview-world.json"
const WORKBENCH_SCOPE := "res://config/workbench/rooms.json"
var data: Dictionary = {}
var error := ""
var _room_actions: Dictionary={}
var _workbench_base: Dictionary = {}
var _workbench_drafts: Dictionary = {}
var _workbench_catalog: Dictionary = {}
var _editor_documents: Dictionary = {}
var workbench_catalog_error := ""

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
	return {"room":row,"scene":packed,"document":document,"entry":entry,"content_version":data.content_version,"draft":_workbench_drafts.get(request.room_id,{})}

static func point(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

static func rect(value: Array) -> Rect2:
	return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))

func workbench_base_version() -> String:
	return str((_workbench_base if not _workbench_base.is_empty() else data).get("content_version", ""))

func workbench_available_room_ids() -> Array:
	var catalog := _preview_catalog()
	return (catalog.get("rooms", {}) if not catalog.is_empty() else data.get("rooms", {})).keys()

func workbench_formal_room_ids() -> Array:
	return (_workbench_base if not _workbench_base.is_empty() else data).get("rooms", {}).keys()

func _preview_catalog() -> Dictionary:
	if not _workbench_catalog.is_empty() and _workbench_catalog.get("base_content_version") == workbench_base_version(): return _workbench_catalog
	workbench_catalog_error = ""
	if not FileAccess.file_exists(WORKBENCH_CATALOG):
		workbench_catalog_error = "preview_catalog_missing"
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORKBENCH_CATALOG))
	if not parsed is Dictionary or parsed.get("schema") != 1 or parsed.get("base_content_version") != workbench_base_version():
		workbench_catalog_error = "preview_catalog_version_mismatch"
		return {}
	if not parsed.get("rooms") is Dictionary or not parsed.get("actions") is Array or not parsed.get("demo_services") is Dictionary or not parsed.get("map_rooms") is Array or not parsed.get("npcs") is Array:
		workbench_catalog_error = "preview_catalog_invalid"
		return {}
	# This packaged catalog is compiled from the same canonical sources. A web
	# draft may select a packaged scene, but cannot introduce a script/resource path.
	var formal: Dictionary = _workbench_base if not _workbench_base.is_empty() else data
	var bindings: Variant = parsed.get("construction_scene_bindings")
	if not bindings is Dictionary or parsed.get("construction_sha256") != formal.get("sources", {}).get("construction.json"):
		workbench_catalog_error = "preview_scene_bindings_invalid"
		return {}
	var expected: Dictionary = {}
	for id: Variant in bindings:
		if not id is String or not bindings[id] is String:
			workbench_catalog_error = "preview_scene_bindings_invalid"
			return {}
		if id.begins_with("P-R"): expected[id] = bindings[id]
	if FileAccess.file_exists(WORKBENCH_SCOPE):
		var scope: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORKBENCH_SCOPE))
		if not scope is Dictionary or scope.get("schema") != 1 or not scope.get("additional_room_ids") is Array or parsed.get("scope_sha256") != FileAccess.get_sha256(WORKBENCH_SCOPE):
			workbench_catalog_error = "preview_scope_invalid"
			return {}
		for id: Variant in scope.additional_room_ids:
			if not id is String or not bindings.has(id) or expected.has(id):
				workbench_catalog_error = "preview_scope_invalid"
				return {}
			expected[id] = bindings[id]
	elif not str(parsed.get("scope_sha256", "")).is_empty():
		workbench_catalog_error = "preview_scope_missing"
		return {}
	for id:String in formal.get("rooms",{}):
		if not bindings.has(id) or bindings[id]!=formal.rooms[id].scene_ref:
			workbench_catalog_error="preview_scene_bindings_invalid"
			return {}
		expected[id]=bindings[id]
	if expected.is_empty() or parsed.rooms.size() != expected.size() or bindings.size() != expected.size():
		workbench_catalog_error = "preview_catalog_incomplete"
		return {}
	for id: String in formal.get("rooms", {}):
		if not expected.has(id):
			workbench_catalog_error = "preview_catalog_incomplete"
			return {}
	for id: String in expected:
		var expected_path := str(expected[id])
		var row: Variant = parsed.rooms.get(id)
		if not row is Dictionary or row.get("room_id") != id or row.get("scene_ref") != expected_path or not expected_path.begins_with("res://") or not ResourceLoader.exists(expected_path):
			workbench_catalog_error = "preview_scene_not_packaged:"+id
			return {}
	_workbench_catalog = parsed
	return _workbench_catalog

func workbench_snapshot() -> Dictionary:
	return {"data":data.duplicate(true), "base":_workbench_base.duplicate(true), "drafts":_workbench_drafts.duplicate(true), "editor_documents":_editor_documents.duplicate(true)}

func restore_workbench_snapshot(snapshot: Dictionary) -> void:
	data = snapshot.data.duplicate(true)
	_workbench_base = snapshot.base.duplicate(true)
	_workbench_drafts = snapshot.drafts.duplicate(true)
	_editor_documents = snapshot.get("editor_documents", {}).duplicate(true)
	_index_actions()

func restore_workbench_base() -> void:
	if not _workbench_base.is_empty(): data = _workbench_base.duplicate(true)
	_workbench_base.clear()
	_workbench_drafts.clear()
	_editor_documents.clear()
	_index_actions()

func install_editor_project(project: Dictionary, selected: String, verified_behavior_hash := "") -> String:
	var base: Dictionary = _workbench_base if not _workbench_base.is_empty() else data
	var compiled := WorldEditorRuntime.compile(base, project, selected, verified_behavior_hash)
	if compiled.has("error"): return str(compiled.error)
	if _workbench_base.is_empty(): _workbench_base = data.duplicate(true)
	data = compiled.runtime
	_editor_documents = compiled.documents
	_workbench_drafts.clear()
	_index_actions()
	return ""

func _index_actions() -> void:
	_room_actions.clear()
	for action: Dictionary in data.get("actions", []):
		if not _room_actions.has(action.room_id): _room_actions[action.room_id] = []
		_room_actions[action.room_id].append(action)

func install_workbench_draft(draft: Dictionary) -> String:
	if str(draft.get("base_content_version", "")) != workbench_base_version(): return "base_content_version_mismatch"
	var id := str(draft.get("room_id", ""))
	var formal: Dictionary = _workbench_base if not _workbench_base.is_empty() else data
	var catalog := _preview_catalog()
	var packaged: Dictionary = catalog.get("rooms", formal.get("rooms", {}))
	if not packaged.has(id): return "room_not_packaged"
	var next_data: Dictionary = data.duplicate(true)
	if not catalog.is_empty() and not bool(next_data.get("workbench_preview", false)):
		for key: String in ["rooms", "actions", "demo_services", "npcs", "map_rooms"]:
			next_data[key] = catalog[key].duplicate(true)
		next_data["workbench_preview"] = true
	var changed_geometry := draft.has("runtime")
	if draft.has("runtime"):
		if not draft.runtime is Dictionary: return "runtime_invalid"
		var runtime: Dictionary = draft.runtime
		if runtime.get("schema") != 1 or not runtime.get("rooms") is Dictionary or not runtime.get("actions") is Array: return "runtime_invalid"
		if str(runtime.get("content_version", "")).length() != 64: return "runtime_version_invalid"
		if runtime.rooms.size() != packaged.size(): return "runtime_room_scope_mismatch"
		for room_id: String in runtime.rooms:
			if not packaged.has(room_id): return "runtime_room_not_packaged"
			if not runtime.rooms[room_id] is Dictionary or runtime.rooms[room_id].get("scene_ref") != packaged[room_id].scene_ref: return "runtime_scene_binding_changed"
		if not runtime.get("start") is Dictionary or not runtime.start.get("room") is String or not packaged.has(runtime.start.room): return "runtime_start_invalid"
		if not runtime.get("map_rooms") is Array or runtime.map_rooms.size() != packaged.size(): return "runtime_map_scope_mismatch"
		# A compiled replacement may change geometry, but its scene scope and
		# component membership still belong to the packaged source catalog.
		var expected_components: Dictionary = {}
		for map_row: Dictionary in catalog.get("map_rooms", formal.get("map_rooms", [])):
			expected_components[str(map_row.id)] = str(map_row.get("map_component", formal.start.room))
		if expected_components.size() != packaged.size(): return "runtime_map_source_invalid"
		var seen_map_rooms: Dictionary = {}
		for map_row: Variant in runtime.map_rooms:
			if not map_row is Dictionary or not map_row.get("id") is String: return "runtime_map_scope_mismatch"
			var map_id := str(map_row.id)
			if not expected_components.has(map_id) or seen_map_rooms.has(map_id): return "runtime_map_scope_mismatch"
			if str(map_row.get("map_component", formal.start.room)) != expected_components[map_id]: return "runtime_map_component_changed"
			seen_map_rooms[map_id] = true
		for action: Variant in runtime.actions:
			if not action is Dictionary or not action.get("room_id") is String or not action.get("id") is String: return "runtime_action_invalid"
		next_data = runtime.duplicate(true)
		next_data["workbench_preview"] = true
	if not draft.get("room_drafts", {}) is Dictionary: return "related_drafts_invalid"
	var updates: Dictionary = draft.get("room_drafts", {}).duplicate(true)
	var selected: Dictionary = draft.duplicate(true)
	selected.erase("room_drafts")
	selected.erase("runtime")
	updates[id] = selected
	var next_drafts: Dictionary = _workbench_drafts.duplicate(true)
	for room_id: String in updates:
		if not next_data.rooms.has(room_id) or not packaged.has(room_id): return "room_not_packaged:"+room_id
		if not updates[room_id] is Dictionary: return "related_draft_invalid"
		var update: Dictionary = updates[room_id]
		update["schema"] = draft.get("schema", 1)
		update["room_id"] = room_id
		update["revision"] = draft.revision
		update["base_content_version"] = draft.base_content_version
		if update.has("contract"):
			if not update.contract is Dictionary: return "contract_invalid"
			if str(update.contract.get("room_id", "")) != room_id or update.contract.get("scene_ref") != packaged[room_id].scene_ref: return "contract_identity_changed"
			next_data.rooms[room_id] = update.contract.duplicate(true)
			changed_geometry = true
		if update.has("geometry"):
			if not update.geometry is Dictionary: return "geometry_invalid"
			var adapted := WorldWorkbenchGeometry.apply(next_data.rooms[room_id], update.geometry)
			if adapted.has("error"): return str(adapted.error)+":"+room_id
			next_data.rooms[room_id] = adapted.room
			changed_geometry = true
		var row: Dictionary = next_data.rooms[room_id]
		row["preview_only"] = not formal.rooms.has(room_id)
		if not row.get("world_geometry") is Dictionary or not row.get("doors") is Array: return "contract_geometry_missing"
		if not row.world_geometry.get("boundary") is Array or not WorldRoomDraft.rectangle(row.world_geometry.get("bounds_world_units")): return "contract_geometry_invalid"
		var packed := load(str(packaged[room_id].scene_ref)) as PackedScene
		if packed == null: return "scene_missing"
		var probe := packed.instantiate() as FixedWorldRoom
		if probe == null: return "scene_type_invalid"
		var problem := WorldRoomDraft.apply(probe, update)
		if not problem.is_empty():
			probe.free()
			return problem
		var normalized := WorldRoomDraft.extract(probe)
		probe.free()
		normalized["draft_hash"] = JSON.stringify(normalized, "", true).sha256_text()
		normalized["geometry_hash"] = JSON.stringify({"geometry":row.world_geometry,"doors":row.doors}, "", true).sha256_text()
		var previous: Dictionary = _workbench_drafts.get(room_id, {})
		if int(previous.get("revision", -1)) == int(draft.revision):
			if previous.get("draft_hash") != normalized.draft_hash or previous.get("geometry_hash") != normalized.geometry_hash: return "revision_content_conflict:"+room_id
		normalized["revision"] = int(draft.revision)
		normalized["base_content_version"] = workbench_base_version()
		next_drafts[room_id] = normalized
	if changed_geometry:
		var geometry_error := WorldWorkbenchGeometry.refresh_map(next_data)
		if not geometry_error.is_empty(): return geometry_error
	if _workbench_base.is_empty(): _workbench_base = data.duplicate(true)
	data = next_data
	_workbench_drafts = next_drafts
	_index_actions()
	return ""

func workbench_draft_hash(id: String) -> String:
	return str(_workbench_drafts.get(id, {}).get("draft_hash", ""))

