extends SceneTree
## Export all currently authored rooms, then verify complete static round trips.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := "res://build/editor/rooms"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var construction: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/world/construction.json"))
	var checks: Array = []
	var failed := false
	for row: Dictionary in construction.rooms:
		var path := str(row.scene_ref)
		if not ResourceLoader.exists(path): continue
		var packed := load(path) as PackedScene
		if packed == null: continue
		var doc := WorldRoomDocument.extract(packed)
		if doc.has("error"):
			printerr(row.room_id+": "+str(doc.error))
			failed = true
			continue
		var result := WorldRoomDocument.instantiate(doc)
		if result.has("error"):
			printerr(row.room_id+": "+str(result.error))
			failed = true
			continue
		var restored := PackedScene.new()
		if restored.pack(result.room) != OK:
			result.room.free()
			failed = true
			continue
		result.room.free()
		var actual := WorldRoomDocument.extract(restored)
		# Generated stable IDs are intentionally included in the authoring document,
		# not a second mutable array. Compare the complete static source values.
		var equal: bool = JSON.parse_string(JSON.stringify(doc)) == JSON.parse_string(JSON.stringify(actual))
		checks.append({"room_id":row.room_id, "roundtrip":equal, "entities":doc.entities.size()})
		if not equal:
			printerr(row.room_id+": complete document roundtrip mismatch")
			var debug_file := FileAccess.open(output.path_join(str(row.room_id)+".actual.json"), FileAccess.WRITE)
			debug_file.store_string(JSON.stringify(actual, "\t", true))
			failed = true
		var file := FileAccess.open(output.path_join(str(row.room_id)+".json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(doc, "\t", true)+"\n")
	var receipt := FileAccess.open(output.get_base_dir().path_join("roundtrip.json"), FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"passed":not failed, "rooms":checks}, "\t"))
	var components: Dictionary = {}
	for kind: String in WorldRoomDocument.COMPONENTS:
		var instance := (load(WorldRoomDocument.COMPONENTS[kind]) as Script).new() as Node
		var fields: Dictionary = {}
		for info: Dictionary in instance.get_property_list():
			if int(info.usage) & PROPERTY_USAGE_STORAGE and int(info.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and info.name != "document_ref":
				fields[str(info.name)] = {"type":int(info.type), "hint":str(info.hint_string), "default":WorldRoomDocument.encode(instance.get(info.name))}
		components[kind] = {"id":kind, "script":WorldRoomDocument.COMPONENTS[kind], "fields":fields, "root":kind in ["FixedWorldRoom", "StarbridgeTrialRoom"]}
		instance.free()
	for field: String in WorldRoomDocument.ENTITY_FIELDS: components["array:"+field] = {"id":"array:"+field, "field":field}
	var enemies: Array = []
	for behavior: StringName in EnemyBehaviorRegistry.behavior_ids():
		var definition := EnemyFactory.definition_for_behavior(behavior)
		enemies.append({"id":str(behavior), "health":definition.health_definition.max_health, "size":WorldRoomDocument.encode(definition.collision_size), "aerial":definition.aerial, "definition":EnemyFactory.definition_path_for_behavior(behavior)})
	var catalog := FileAccess.open(output.get_base_dir().path_join("catalog.json"), FileAccess.WRITE)
	catalog.store_string(JSON.stringify({"schema":2, "components":components, "enemies":enemies, "terrain_materials":TerrainMaterialRegistry.catalog()}, "\t", true))
	print("EDITOR DOCUMENTS: ", checks.size(), " rooms, passed=", not failed)
	quit(1 if failed else 0)
