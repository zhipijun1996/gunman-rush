extends "res://tools/level_formal_capture.gd"
## The original full formal driver, with an explicit presentation treatment only.
const P1_CATALOG := "res://game/presentation/world/resources/visual_development/p1_candidate.json"
var _p1_selected := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-layout=") or arg=="--p1-random-plains":
			_startup_failed("Formal random layout cannot be replaced or enabled outside the exact catalog treatment")
			return
		if arg.begins_with("--visual-sample="):
			if arg.trim_prefix("--visual-sample=")!=P1_CATALOG:
				_startup_failed("Unsupported formal random presentation catalog")
				return
			_p1_selected=true
	super._initialize()

func make_application() -> DemoApp:
	var application := super.make_application()
	application.p1_random_plains_requested=_p1_selected
	application.avatar_selection_id="p1_girl" if _p1_selected else "courier"
	node_added.connect(_observe_install_node)
	report["visual_sample_treatment"]={"catalog_path":P1_CATALOG if _p1_selected else "","catalog_sha256":FileAccess.get_sha256(P1_CATALOG) if _p1_selected else ""}
	report["visual_layout_treatment"]="original"
	report["p1_random_requested"]=_p1_selected
	report["requested_avatar"] = application.avatar_selection_id
	return application

func _observe_install_node(node: Node) -> void:
	if not _p1_selected or app==null or node.get_parent()!=app.stage:return
	var script := node.get_script() as Script
	if script==null:return
	if script.resource_path=="res://game/presentation/world/art/p1_random_plains_sample.gd":
		report["p1_collision_before_install"]=_collision_rows(app.stage)
		report["p1_collision_observation_boundary"]="SceneTree.node_added before P1 install; presentation.ready after synchronous install, before route input"
	elif script.resource_path=="res://game/presentation/world/art/visual_language_sample.gd" and app.stage.has_meta("p1_random_coverage"):
		node.ready.connect(_after_install,CONNECT_ONE_SHOT)

func _after_install() -> void:
	report["p1_collision_after_install"]=_collision_rows(app.stage)

func _avatar() -> Dictionary:
	var adapter := app.get_meta("avatar_presentation",null) as Node
	return adapter.call("snapshot") if is_instance_valid(adapter) else {}

func make_driver() -> RefCounted:
	var geometry := _collision_rows(app.stage)
	if not _p1_selected:
		report["p1_collision_before_install"]=geometry.duplicate(true)
		report["p1_collision_after_install"]=geometry.duplicate(true)
		report["p1_collision_observation_boundary"]="Unstyled baseline at attach; no P1 install occurred"
	report["p1_geometry_at_attach"]=geometry
	report["p1_random_initial"]=app.stage.get_meta("p1_random_coverage",{}).duplicate(true)
	report["avatar_initial"]=_avatar()
	report.captured_scope["route_scope"]="Original full LevelFormalTrace strategy on ordinary generated map; no two-bank or golden trace; Boss and complete exploration remain unproven"
	return super.make_driver()

func _collision_rows(stage: Node) -> Array:
	var rows: Array=[]
	for node: Node in stage.find_children("*","",true,false):
		if not node is CollisionShape2D and not node is CollisionPolygon2D:continue
		var body := node.get_parent() as CollisionObject2D
		if body==null:continue
		var static_terrain: bool=body is StaticBody2D and ((body.get_parent() is PlatformingModule and not body is ModuleMovingPlatform) or body.get_parent()==app.stage.assembler.ground_supports)
		var transform := (node as Node2D).global_transform
		var row := {"path":str(node.get_path()),"body_class":body.get_class(),"layer":body.collision_layer,"mask":body.collision_mask,"transform":[transform.x.x,transform.x.y,transform.y.x,transform.y.y,transform.origin.x,transform.origin.y],"disabled":node.disabled,"one_way":node.one_way_collision,"static_terrain":static_terrain}
		if node is CollisionPolygon2D:
			row["polygon"]=_pairs(node.polygon)
			row["build_mode"]=node.build_mode
		else:
			var shape: Shape2D=node.shape
			row["shape_class"]=shape.get_class() if shape!=null else "null"
			if shape is RectangleShape2D:row["size"]=[shape.size.x,shape.size.y]
			elif shape is CircleShape2D:row["radius"]=shape.radius
			elif shape is CapsuleShape2D:row.merge({"radius":shape.radius,"height":shape.height})
			elif shape is ConvexPolygonShape2D:row["points"]=_pairs(shape.points)
			elif shape is ConcavePolygonShape2D:row["segments"]=_pairs(shape.segments)
			elif shape is SegmentShape2D:row["segment"]=[[shape.a.x,shape.a.y],[shape.b.x,shape.b.y]]
		rows.append(row)
	return rows

func _pairs(points: PackedVector2Array) -> Array:
	var result: Array=[]
	for point: Vector2 in points:result.append([point.x,point.y])
	return result

func save_report() -> bool:
	var extension: Dictionary={}
	collect_driver_sources("res://tools/p1_random_capture.gd",extension)
	collect_driver_sources("res://tools/p1_random_preview.gd",extension)
	report["capture_extension_sources"]=extension
	if is_instance_valid(app) and is_instance_valid(app.stage) and not report.has("p1_random_final"):
		report["p1_random_final"]=app.stage.get_meta("p1_random_coverage",{}).duplicate(true)
		report["p1_geometry_final"]=_collision_rows(app.stage)
		report["avatar_final"]=_avatar()
		var before: Array=report.get("p1_collision_before_install",[])
		var after: Array=report.get("p1_collision_after_install",[])
		report["p1_install_collision_unchanged"]=not before.is_empty() and before==after
		report["p1_temporal_static_terrain_unchanged"]=report.get("p1_geometry_at_attach",[]).filter(func(row: Dictionary)->bool:return row.static_terrain)==report.p1_geometry_final.filter(func(row: Dictionary)->bool:return row.static_terrain)
		report["p1_collision_scope"]="All actual collider transforms/shapes/layers/masks at synchronous install; static terrain also compared across route. Moving platforms and gameplay toggles remain original simulation, not frozen by this observer."
	return super.save_report()
