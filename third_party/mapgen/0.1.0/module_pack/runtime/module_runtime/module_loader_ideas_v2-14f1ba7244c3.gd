extends "module_loader_review_air_v1-8a5d8fb0ad55.gd"
## Original data loader construction, adding only typed existing loop definitions.
const LOOP=preload("install_v1-e73bc68f3203.gd")
const IDEA_DEFINITION=preload("ideas_definition_v1-d97d761201bf.gd")
func _ready() -> void:
	process_physics_priority=1100
	add_to_group(&"foundation_module_packages")
	var folder:=scene_file_path.get_base_dir()
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("godot-package.json")))
	if not manifest is Dictionary or FileAccess.get_sha256(folder.path_join("compiled-content.json"))!=manifest.get("artifacts",{}).get("compiled-content.json","") or FileAccess.get_sha256(folder.path_join("module.mapnote.json"))!=manifest.get("source",{}).get("module_sha256",""):
		setup_error="stale_or_changed_package";push_error(setup_error);return
	var parsed_content: Variant=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("compiled-content.json")))
	if not parsed_content is Dictionary or parsed_content.get("schema","")!="pcg/compiled-module-content/v1":
		setup_error="invalid_compiled_content";push_error(setup_error);return
	content=parsed_content
	var definition:=IDEA_DEFINITION.new();definition.allow_same_port_return=true;definition.module_id=StringName(content.stable_id)
	definition.world_bounds=Rect2(content.world_bounds[0],content.world_bounds[1],content.world_bounds[2],content.world_bounds[3])
	for value: Array in content.platforms:definition.platforms.append(Rect2(value[0],value[1],value[2],value[3]))
	for value: Array in content.hazards:definition.danger_bounds.append(Rect2(value[0],value[1],value[2],value[3]))
	for raw: Dictionary in content.moving_platforms:
		var value:=ModuleMovingPlatformDefinition.new()
		for key: String in ["platform_id","travel_duration","dwell_duration","initial_phase"]:
			if raw.has(key):value.set(key,raw[key])
		for key: String in ["start","finish","size"]:
			if raw.has(key):value.set(key,Vector2(raw[key][0],raw[key][1]))
		definition.ferries.append(value)
	for raw: Dictionary in content.saws:
		var value:=ModuleSawDefinition.new()
		for key: String in ["source_id","radius","period","initial_phase","damage","contact_interval"]:
			if raw.has(key):value.set(key,raw[key])
		for key: String in ["origin","travel"]:
			if raw.has(key):value.set(key,Vector2(raw[key][0],raw[key][1]))
		definition.saws.append(value)
	for raw: Dictionary in content.thorns:
		var value:=PlatformThornDefinition.new()
		for key: String in ["surface_id","platform_index","start_offset","length","depth"]:
			if raw.has(key):value.set(key,raw[key])
		var face: Variant=raw.get("face","top")
		value.face=["top","left","right","bottom"].find(face) if face is String else int(face)
		definition.surface_thorns.append(value)
	for index: Variant in content.one_way_platform_indices:definition.one_way_platform_indices.append(int(index))
	definition.entry_port=PlatformingModulePort.new();definition.entry_port.port_id=&"entry"
	definition.entry_port.position=Vector2(content.entry_port[0],content.entry_port[1])
	definition.exit_port=PlatformingModulePort.new();definition.exit_port.port_id=&"exit"
	definition.exit_port.position=Vector2(content.exit_port[0],content.exit_port[1])
	definition.anchors.append(definition.entry_port.position);definition.anchors.append(definition.exit_port.position)
	LOOP.install(definition,content)
	if not definition.is_valid():setup_error="invalid_original_definition";push_error(setup_error);return
	module=PlatformingModule.new();module.name="Content";module.definition=definition;module.authoring_debug=false;add_child(module)
	for index: Variant in content.wall_platform_indices:module.get_node("Platform"+str(int(index))).add_to_group(&"wall_climbable")
