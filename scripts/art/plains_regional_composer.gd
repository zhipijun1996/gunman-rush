class_name PlainsRegionalComposer
extends Node2D
## Actual candidate consumer of the complete formal region's world-space plan.
## No collision, layout, supports, Seed or decoration coordinates are authored here.
const CATALOG := "res://resources/visual_development/p1_regional_assets.json"
const DISTANCE_SHADER := preload("res://scripts/art/distant_plains.gdshader")
const GROUND_SHADER := preload("res://shaders/plains_regional_ground.gdshader")
var _stage: Node2D
var _plan: Dictionary
var _catalog: Dictionary
var _facts: Dictionary = {}
var _layers: Array[Dictionary] = []
var _old_background: CanvasLayer
var _background_was_visible := false
var _background_panels: Array[Sprite2D]=[]
var _camera_reference:=Vector2.ZERO

func install(stage: Node2D, plan: Dictionary) -> void:
	_stage=stage
	_plan=plan
	_facts={"version":"plains-regional-consumer-v1","seed":plan.get("seed",""),"manifest_hash":plan.get("manifest_hash",""),"plan_hash":plan.get("plan_hash",""),"production_pool":false,"terrain":[],"objects":[],"layers":[],"omitted":[],"surfaces":plan.get("surfaces",[]).duplicate(true),"renderer_writes_collision":false,"renderer_authored_layout":false,"material_coordinate_space":"world","terrain_method":"complete painted geological material on shared world-union geometry, opaque full-depth volume","rng_used":false}
	if not FileAccess.file_exists(CATALOG):
		_facts.omitted.append({"reason":"regional_catalog_missing"})
		publish_facts();return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not parsed is Dictionary:
		_facts.omitted.append({"reason":"regional_catalog_invalid"})
		publish_facts();return
	_catalog=parsed
	_camera_reference=_rect(plan.bounds).get_center()
	_facts.catalog_path=CATALOG
	_facts.catalog_sha256=FileAccess.get_sha256(CATALOG)
	_build_sky()
	_build_layers()
	_build_terrain()
	_build_landmarks()
	_retire_original_terrain()
	publish_facts()

func _build_sky() -> void:
	var app:=_stage.get_parent()
	if app!=null: _old_background=app.get_node_or_null("PlainsBackground") as CanvasLayer
	if _old_background!=null:
		_background_was_visible=_old_background.visible
		_old_background.hide()
	var layer:=CanvasLayer.new()
	layer.layer=-95
	add_child(layer)
	var backgrounds: Array=_catalog.get("global_background",[])
	if backgrounds.size()!=2:
		_facts.omitted.append({"reason":"global_background_pair_missing"});return
	for index: int in 2:
		var spec: Dictionary=backgrounds[index]
		var texture:=_texture(str(spec.texture))
		if texture==null:continue
		var node:=Sprite2D.new()
		node.name="GlobalPaintedSky" if index==0 else "GlobalTransparentDistantGeology"
		node.centered=false
		node.texture=texture
		var material:=ShaderMaterial.new()
		material.shader=DISTANCE_SHADER
		material.set_shader_parameter("saturation",0.40 if index==0 else 0.42)
		material.set_shader_parameter("mist",0.08 if index==0 else 0.14)
		material.set_shader_parameter("contrast",0.62 if index==0 else 0.78)
		material.set_shader_parameter("softness",0.0)
		material.set_shader_parameter("mist_color",Color("d2ddd9") if index==0 else Color("b7c5bd"))
		node.material=material
		layer.add_child(node)
		_background_panels.append(node)
		_facts.layers.append({"id":spec.id,"source":spec.texture,"source_sha256":FileAccess.get_sha256(str(spec.texture)),"node_path":str(node.get_path()),"instances":1,"source_alpha":"original source; transparent mountain skyline" if index==1 else "opaque sky source covering entire viewport","mapping":"existing PlainsBackground.shared_projection, one full world domain, no per-place reset","camera_coefficient":[0.008,0.004] if index==0 else [0.07,0.018]})

func _update_background(center: Vector2) -> void:
	var domain:=_rect(_plan.bounds).grow(180.0)
	var rectangles:=PlainsBackground.shared_projection(get_viewport_rect().size,center,domain)
	for index: int in _background_panels.size():
		var node:=_background_panels[index]
		var region: Rect2=rectangles[index]
		node.position=region.position
		node.scale=region.size/node.texture.get_size()

func _build_terrain() -> void:
	var spec: Dictionary=_catalog.get("terrain",{})
	var texture:=_texture(str(spec.get("texture","")))
	if texture==null:return
	var source_sha:=FileAccess.get_sha256(str(spec.texture))
	var geometry: Array=[]
	var sources: Dictionary={}
	for solid: Dictionary in _plan.get("solids",[]):sources[str(solid.id)]=solid
	for body: Dictionary in _plan.get("geological_bodies",[]):
		if (body.get("holes",[]) as Array).is_empty():
			geometry.append(body)
			continue
		# Godot Polygon2D does not triangulate holes. Decompose this exact body
		# into its original collision source rectangles, sharing the same world
		# pigment and global exposed surfaces. Never fill an actual route void.
		for source_id: String in body.get("source_ids",[]):
			if not sources.has(source_id):continue
			var r:=_rect(sources[source_id].rect)
			geometry.append({"id":str(body.id)+"/"+source_id,"points":[[r.position.x,r.position.y],[r.end.x,r.position.y],[r.end.x,r.end.y],[r.position.x,r.end.y]],"source_ids":[source_id],"hole_safe_decomposition":true})
	# The exact original solid rectangles are a conservative projection only;
	# bounded rounded contour bodies, when present, remain owned by the plan.
	if geometry.is_empty():
		for solid: Dictionary in _plan.get("solids",[]):
			var r:=_rect(solid.rect)
			geometry.append({"id":solid.id,"points":[[r.position.x,r.position.y],[r.end.x,r.position.y],[r.end.x,r.end.y],[r.position.x,r.end.y]],"source_ids":[solid.id]})
	geometry=_bounded_chunks(geometry)
	for body: Dictionary in geometry:
		var raw: Array=body.get("points",body.get("polygon",[]))
		var polygon:=_points(raw)
		if polygon.size()<3:
			_facts.omitted.append({"reason":"geological_body_polygon_invalid","id":body.get("id","")});continue
		if Geometry2D.triangulate_polygon(polygon).is_empty():
			_facts.omitted.append({"reason":"geological_body_cannot_triangulate","id":body.get("id","")});continue
		var bounds:=Rect2(polygon[0],Vector2.ZERO)
		for point: Vector2 in polygon:bounds=bounds.expand(point)
		var tops:=PackedVector4Array()
		for edge: Dictionary in _plan.get("terrain_edges",[]):
			if str(edge.face)!="top":continue
			var a:=_pair(edge.a);var b:=_pair(edge.b)
			if b.x<bounds.position.x-350.0 or a.x>bounds.end.x+350.0:continue
			if a.y>bounds.end.y+1.0 or a.y<bounds.position.y-450.0:continue
			tops.append(Vector4(a.x,a.y,b.x,b.y))
		if tops.size()>96:
			_facts.omitted.append({"reason":"local_exposed_surface_shader_budget_exceeded","id":body.get("id","")});continue
		var top_count:=tops.size()
		tops.resize(96)
		var material:=ShaderMaterial.new()
		material.shader=GROUND_SHADER
		material.set_shader_parameter("geological_paint",texture)
		material.set_shader_parameter("exposed_tops",tops)
		material.set_shader_parameter("top_count",top_count)
		material.set_shader_parameter("horizontal_period",float(spec.get("world_period",1160.0)))
		material.set_shader_parameter("painted_depth",float(spec.get("world_depth",260.0)))
		material.set_shader_parameter("source_surface",bounds.position)
		var node:=Polygon2D.new()
		node.name="RegionalGeology_"+str(body.get("id",_facts.terrain.size())).validate_node_name()
		node.polygon=polygon
		node.material=material
		node.z_index=-3
		add_child(node)
		_facts.terrain.append({"id":body.get("id",node.name),"source_ids":body.get("source_ids",[]),"source":spec.texture,"source_sha256":source_sha,"source_dimensions":[texture.get_width(),texture.get_height()],"points":raw,"exposed_top_count":top_count,"node_path":str(node.get_path()),"coordinate_space":"one global world phase","opaque_full_volume":true,"deep_core_mapping":spec.get("deep_core",{}),"hole_safe_decomposition":body.get("hole_safe_decomposition",false),"collision_written":false})
	if _facts.terrain.is_empty():_facts.omitted.append({"reason":"no_regional_terrain_installed"})

func _bounded_chunks(bodies: Array) -> Array:
	# Spatial render partition only: source polygons, world material and exposed
	# physical surfaces stay shared. Chunk edges never acquire grass or caps.
	var output: Array=[]
	for body: Dictionary in bodies:
		var polygon:=_points(body.get("points",body.get("polygon",[])))
		if polygon.size()<3:continue
		var bounds:=Rect2(polygon[0],Vector2.ZERO)
		for point: Vector2 in polygon:bounds=bounds.expand(point)
		if bounds.size.x<=1024.0:
			output.append(body);continue
		var start:=floorf(bounds.position.x/1024.0)*1024.0
		while start<bounds.end.x:
			var end:=start+1024.0
			var clip:=PackedVector2Array([Vector2(start,bounds.position.y-1.0),Vector2(end,bounds.position.y-1.0),Vector2(end,bounds.end.y+1.0),Vector2(start,bounds.end.y+1.0)])
			for part: PackedVector2Array in Geometry2D.intersect_polygons(polygon,clip):
				var raw: Array=[]
				for point: Vector2 in part:raw.append([point.x,point.y])
				var item:=body.duplicate(true)
				item.id=str(body.id)+"/render_chunk/"+str(output.size())
				item.points=raw
				item.render_partition_only=true
				output.append(item)
			start=end
	return output

func _build_layers() -> void:
	var bounds:=_rect(_plan.bounds)
	for belt: Dictionary in _plan.get("layer_belts",[]):
		var line:=_points(belt.world_polyline)
		if line.size()<2:continue
		var polygon:=line.duplicate()
		polygon.append(Vector2(line[-1].x,bounds.end.y+2200.0))
		polygon.append(Vector2(line[0].x,bounds.end.y+2200.0))
		var node:=Polygon2D.new()
		node.name="GlobalBelt_"+str(belt.id).validate_node_name()
		node.polygon=polygon
		var index:=int(belt.get("depth",0))
		var colors: Array=_catalog.get("belt_colors",["b4c6c0","94b3a9","759b90"])
		var tint:=Color(str(colors[mini(index,colors.size()-1)]))
		var paint_spec: Dictionary=_catalog.get("middle_belt_paint",{})
		var paint:=_texture(str(paint_spec.get("texture","")))
		if paint==null:continue
		var tops:=PackedVector4Array()
		for point_index: int in line.size()-1:
			tops.append(Vector4(line[point_index].x,line[point_index].y,line[point_index+1].x,line[point_index+1].y))
		var top_count:=tops.size()
		tops.resize(96)
		var material:=ShaderMaterial.new()
		material.shader=GROUND_SHADER
		material.set_shader_parameter("geological_paint",paint)
		material.set_shader_parameter("exposed_tops",tops)
		material.set_shader_parameter("top_count",top_count)
		material.set_shader_parameter("horizontal_period",float(paint_spec.get("world_period",1160.0))*2.7)
		material.set_shader_parameter("painted_depth",float(paint_spec.get("world_depth",260.0))*3.5)
		material.set_shader_parameter("atmospheric_color",tint)
		material.set_shader_parameter("atmospheric_mix",0.56+float(2-index)*0.09)
		material.set_shader_parameter("quiet_background",true)
		node.material=material
		node.z_index=-70+index*10
		add_child(node)
		_layers.append({"node":node,"depth":float(belt.parallax)})
		_facts.layers.append({"id":belt.id,"node_path":str(node.get_path()),"world_polyline":belt.world_polyline,"depth_factor":belt.parallax,"reset_per_place":false,"source":paint_spec.texture,"source_sha256":FileAccess.get_sha256(str(paint_spec.texture)),"geometry_source":"shared plan global geological silhouette","paint_mapping":"whole volume painting, enlarged world phase and atmospheric color","hand_painted_source":true})
func _build_landmarks() -> void:
	var object_specs: Dictionary=_catalog.get("objects",{})
	for attachment: Dictionary in _plan.get("landmarks",[]):
		var role: String=str(attachment.get("asset_role","shelter" if str(attachment.get("role","")) in ["merchant","prep","boss"] else "tree"))
		if role=="wind_tree":role="tree"
		if role=="belfry":role="shelter"
		if not object_specs.has(role):continue
		var spec: Dictionary=object_specs[role]
		var texture:=_texture(str(spec.get("texture","")))
		if texture==null:continue
		var root:=_pair(attachment.position)
		var factor:=float(spec.get("world_height",320.0))/float(texture.get_height())
		var pivot:=_pair(spec.pivot_px)
		var support_id: String=str(attachment.get("surface_id",""))
		if support_id.is_empty():
			_facts.omitted.append({"reason":"landmark_missing_plan_owned_support","id":attachment.id});continue
		var source_polygon:=_points(spec.get("source_polygon",[]))
		var node:=Polygon2D.new()
		node.name="RootedRegional_"+str(attachment.id).validate_node_name()
		node.polygon=source_polygon
		node.uv=source_polygon
		node.texture=texture
		node.position=root-pivot*factor
		node.scale=Vector2.ONE*factor
		node.z_index=-5
		add_child(node)
		_facts.objects.append({"id":attachment.id,"role":role,"source":spec.texture,"source_sha256":FileAccess.get_sha256(str(spec.texture)),"node_path":str(node.get_path()),"surface_id":support_id,"world_anchor":[root.x,root.y],"uniform_scale":factor,"root_owned_by_plan":true})

func _retire_original_terrain() -> void:
	if _facts.terrain.is_empty():return
	var assembler:=_stage.get("assembler") as Node
	if assembler==null:return
	for module: Node in assembler.get("modules"):
		module.set("terrain_candidate_preview",true)
		module.queue_redraw()
	var supports:=assembler.get("ground_supports") as Node2D
	if is_instance_valid(supports):supports.hide()
	_facts.original_terrain_retired=true
	_facts.original_hazards_enemies_oneways_preserved=true

func _texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		_facts.omitted.append({"reason":"regional_source_texture_missing","source":path});return null
	var result:=load(path) as Texture2D
	if result==null:_facts.omitted.append({"reason":"regional_source_not_texture","source":path})
	return result

func _process(_delta: float) -> void:
	var camera:=get_viewport().get_camera_2d()
	if camera==null:return
	var center:=camera.get_screen_center_position()
	_update_background(center)
	for layer: Dictionary in _layers:
		var node:=layer.node as Node2D
		node.position=(layer.get("base",Vector2.ZERO) as Vector2)+(center-_camera_reference)*(1.0-float(layer.depth))

func _exit_tree() -> void:
	if is_instance_valid(_old_background):_old_background.visible=_background_was_visible

func publish_facts() -> void:
	set_meta("environment_composition",_facts)
	if is_instance_valid(_stage):_stage.set_meta("environment_composition",_facts)

func measured_nodes() -> Dictionary:return _facts.duplicate(true)
static func _pair(value: Array) -> Vector2:return Vector2(float(value[0]),float(value[1]))
static func _rect(value: Array) -> Rect2:return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))
static func _points(values: Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for value: Array in values:result.append(_pair(value))
	return result
