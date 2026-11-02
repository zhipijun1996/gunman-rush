extends "res://tools/level_formal_capture.gd"
## Opt-in observer of an existing formal stage; never requests golden geometry.
var _candidate: Node2D
const CATALOG := "res://game/presentation/world/resources/visual_development/painted_terrain_candidate.json"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-sample=") and arg.trim_prefix("--visual-sample=")!=CATALOG:
			_startup_failed("Unsupported explicit formal painted catalog")
			return
		if arg.begins_with("--visual-layout="):
			_startup_failed("Formal painted adapter preserves the existing formal layout")
			return
	super._initialize()

func make_driver() -> RefCounted:
	report["painted_formal_collision_before"]=_collision_rows(app.stage)
	var inventory := PlainsTerrainFamilySampler.inventory(app.stage)
	var rows: Array=[]
	for group: Dictionary in PlainsTerrainFamilySampler.groups(inventory.rooted):
		var parts: Array=[]
		for rect: Rect2 in group.parts: parts.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
		var faces: Array=[]
		for face: Vector4 in group.faces: faces.append([face.x,face.y,face.z,face.w])
		rows.append({"parts":parts,"faces":faces})
	report["painted_formal_inventory"]={"rooted_groups":rows,"floating_count":inventory.floating.size(),"one_way_count":inventory.one_way.size(),"manifest_hash":app.stage.generated.manifest.manifest_hash}
	# Both adapter and catalog are explicit; the same adapter without a catalog
	# is the baseline for temporal A/E on identical formal geometry.
	var sample := CATALOG if "--visual-sample="+CATALOG in OS.get_cmdline_user_args() else ""
	if not sample.is_empty():
		_candidate=load("res://experiments/terrain/art/painted_formal_terrain_sample.gd").new()
		app.stage.add_child(_candidate)
		_candidate.call("install",app.stage)
		report["painted_formal_treatment"]=_candidate.call("measured_nodes")
	report["painted_formal_collision_after_install"]=_collision_rows(app.stage)
	report["visual_sample_treatment"]={"catalog_path":sample,"catalog_sha256":FileAccess.get_sha256(sample) if not sample.is_empty() else ""}
	report["visual_layout_treatment"]="original"
	report.captured_scope["route_scope"]="Only two nearest existing thin banks: real outbound, grounded lookback and return; not full growth route or map completion"
	return preload("res://tests/painted_formal_local_trace.gd").new()

func _collision_rows(node: Node) -> Array:
	var rows: Array=[]
	for shape: Node in node.find_children("*","CollisionShape2D",true,false):
		if shape.get_parent() is StaticBody2D and shape.shape is RectangleShape2D:
			var body: Node=shape.get_parent()
			var is_terrain: bool=(body.get_parent() is PlatformingModule and not body is ModuleMovingPlatform) or body.get_parent()==app.stage.assembler.ground_supports
			rows.append({"path":str(shape.get_path()),"position":[shape.global_position.x,shape.global_position.y],"size":[shape.shape.size.x,shape.shape.size.y],"one_way":shape.one_way_collision,"disabled":shape.disabled,"static_terrain":is_terrain})
	return rows

func save_report() -> bool:
	var extension: Dictionary={}
	collect_driver_sources("res://tools/painted_formal_capture.gd",extension)
	report["capture_extension_sources"]=extension
	if is_instance_valid(app) and is_instance_valid(app.stage):
		report["painted_formal_collision_final"]=_collision_rows(app.stage)
		report["painted_formal_install_collision_unchanged"]=report.get("painted_formal_collision_before",[])==report.get("painted_formal_collision_after_install",[])
		var before: Array=report.get("painted_formal_collision_before",[]).filter(func(row: Dictionary)->bool:return row.static_terrain)
		var after: Array=report.painted_formal_collision_final.filter(func(row: Dictionary)->bool:return row.static_terrain)
		report["painted_formal_static_terrain_unchanged"]=before==after
		report["painted_formal_collision_scope"]="All collision properties equal at install; only module static terrain and generated ground-support bodies compared across time. Moving ferries and latch transitions remain original simulation and require temporal A/E."
	return super.save_report()
