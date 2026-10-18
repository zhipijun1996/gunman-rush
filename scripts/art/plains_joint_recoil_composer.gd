class_name PlainsJointRecoilComposer
extends "res://scripts/art/plains_regional_composer.gd"
## Candidate opt-in: one shared challenge specification owns physical bank
## polygons, neighbor cuts and the complete painted-bank mesh projection.
const JOINT_CATALOG := "res://resources/visual_development/p1_joint_recoil_assets.json"
const LANDFORM_CATALOG := "res://resources/visual_development/p1_landform_assets.json"
const LANDFORM_SHADER := preload("res://shaders/plains_landform_material.gdshader")
var _landform_catalog: Dictionary = {}

func _build_layers() -> void:
	if (_plan.get("joint_modules",[]) as Array).is_empty():
		super._build_layers()
		return
	# Actual sky and transparent distant geology are already installed by the
	# inherited global background. Do not add the rejected flat wall belts.
	_facts["joint_background"]={"global_painted_background_preserved":true,"middle_wall_belts_retired":true,"per_seed_images":false}
	if _is_landform_plan():
		_build_landform_rear_walls()

func _build_terrain() -> void:
	var modules: Array=_plan.get("joint_modules",[])
	if modules.is_empty():
		super._build_terrain()
		return
	var cuts: Array=[]
	for module: Dictionary in modules:
		for raw: Array in module.get("cutout_rects",[]):cuts.append(_rect(raw))
	var original_plan:=_plan
	var projection:=_plan.duplicate(false)
	projection.geological_bodies=_neighbor_projection(cuts)
	_plan=projection
	super._build_terrain()
	_plan=original_plan
	if _is_landform_plan():
		_build_landform_terrain(modules,cuts)
		return
	_facts["version"]="plains-joint-recoil-consumer-whole-mass-v4"
	_facts["terrain_method"]="source-sealed complete joint bank and receiving landmass ArrayMesh, shared physical and visual specification, all actual triangles bounded; original regional material remains outside explicit candidate ownership"
	_facts["joint_terrain"]=[]
	_facts["joint_cutouts"]=[]
	for cut: Rect2 in cuts:_facts.joint_cutouts.append([cut.position.x,cut.position.y,cut.size.x,cut.size.y])
	if not FileAccess.file_exists(JOINT_CATALOG):
		_facts.omitted.append({"reason":"joint_recoil_catalog_missing","source":JOINT_CATALOG});return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(JOINT_CATALOG))
	if not parsed is Dictionary:
		_facts.omitted.append({"reason":"joint_recoil_catalog_invalid"});return
	var catalog: Dictionary=parsed
	_facts["joint_catalog_path"]=JOINT_CATALOG
	_facts["joint_catalog_sha256"]=FileAccess.get_sha256(JOINT_CATALOG)
	for module: Dictionary in modules:
		for body: Dictionary in module.get("terrain_bodies",[]):
			_install_joint_body(module,body,catalog)

func _is_landform_plan() -> bool:
	for module: Dictionary in _plan.get("joint_modules",[]):
		if str(module.get("render_method",""))=="landform_world_material_v1":return true
	return false

func _load_landform_catalog() -> bool:
	if not _landform_catalog.is_empty():return true
	if not FileAccess.file_exists(LANDFORM_CATALOG):
		_facts.omitted.append({"reason":"landform_catalog_missing","source":LANDFORM_CATALOG});return false
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(LANDFORM_CATALOG))
	if not parsed is Dictionary:
		_facts.omitted.append({"reason":"landform_catalog_invalid"});return false
	_landform_catalog=parsed
	_facts["joint_catalog_path"]=LANDFORM_CATALOG
	_facts["joint_catalog_sha256"]=FileAccess.get_sha256(LANDFORM_CATALOG)
	return true

func _landform_source(role: String,family: String="materials") -> Dictionary:
	if not _load_landform_catalog():return {}
	var spec: Dictionary=(_landform_catalog.get(family,{}) as Dictionary).get(role,{})
	var path:=str(spec.get("texture",""))
	if path.is_empty() or not FileAccess.file_exists(path):
		_facts.omitted.append({"reason":"landform_handpainting_not_bound","role":role});return {}
	var actual_sha:=FileAccess.get_sha256(path)
	if str(spec.get("source_sha256",""))!=actual_sha:
		_facts.omitted.append({"reason":"landform_paint_source_sha_mismatch","role":role,"source":path});return {}
	var texture:=_texture(path)
	if texture==null:return {}
	var dimensions:=Vector2(texture.get_width(),texture.get_height())
	var expected: Array=spec.get("source_dimensions",[])
	if expected.size()!=2 or dimensions!=_pair(expected):
		_facts.omitted.append({"reason":"landform_paint_dimensions_mismatch","role":role,"source":path});return {}
	var region:=_rect(spec.get("region_px",[0.0,0.0,dimensions.x,dimensions.y]))
	if not region.has_area() or not Rect2(Vector2.ZERO,dimensions).encloses(region):
		_facts.omitted.append({"reason":"landform_paint_region_invalid","role":role});return {}
	return {"role":role,"texture":texture,"source":path,"sha256":actual_sha,"dimensions":dimensions,"region":region,"spec":spec.duplicate(true)}

func _build_landform_terrain(modules: Array,cuts: Array) -> void:
	_facts["version"]="plains-joint-recoil-landform-consumer-v5"
	_facts["terrain_method"]="environment-program volume polygons with uniform world-space handpaint density and explicit standing/shoulder/arch faces; no old rectangle paint adaptation"
	_facts["joint_terrain"]=[]
	_facts["joint_structural_pieces"]=[]
	_facts["joint_cutouts"]=[]
	for cut: Rect2 in cuts:_facts.joint_cutouts.append([cut.position.x,cut.position.y,cut.size.x,cut.size.y])
	var core:=_landform_source("rock_core")
	var surface:=_landform_source("meadow_transition")
	var wall:=_landform_source("cave_transition")
	if core.is_empty() or surface.is_empty() or wall.is_empty():return
	for module: Dictionary in modules:
		for body: Dictionary in module.get("terrain_bodies",[]):
			_install_landform_volume(module,body,core,surface,wall)
		for piece: Dictionary in module.get("structural_pieces",[]):
			_install_landform_structure(module,piece)

func _install_landform_volume(module: Dictionary,body: Dictionary,core: Dictionary,surface: Dictionary,wall: Dictionary) -> void:
	var polygon:=_points(body.get("visual_points",body.get("points",[])))
	var indices:=Geometry2D.triangulate_polygon(polygon)
	if polygon.size()<3 or indices.is_empty():
		_facts.omitted.append({"reason":"landform_volume_cannot_triangulate","body_id":body.get("id","")});return
	var material_space: Dictionary=body.get("material_space",{})
	var density:=float(material_space.get("pixels_per_world_unit",0.0))
	var admitted_density:=float(_landform_catalog.get("pixels_per_world_unit",0.0))
	if density<=0.0 or not is_equal_approx(density,admitted_density):
		_facts.omitted.append({"reason":"landform_world_paint_density_mismatch","body_id":body.get("id",""),"requested":density,"admitted":admitted_density});return
	var boundaries:=PackedVector4Array()
	var frames:=PackedVector4Array()
	var receipts: Array=[]
	var arc:=0.0
	for face: Dictionary in body.get("exposed_faces",[]):
		var kind:=str(face.get("kind",""))
		if kind=="outer_connection":continue
		if kind not in ["standing","shoulder","cave_roof"]:
			_facts.omitted.append({"reason":"landform_unknown_exposed_face","kind":kind,"body_id":body.get("id","")});return
		var a:=_pair(face.get("a",[]));var b:=_pair(face.get("b",[]))
		var tangent: Vector2=(b-a).normalized()
		if tangent.length_squared()<0.5:continue
		var normal:=Vector2(-tangent.y,tangent.x)
		var midpoint: Vector2=(a+b)*0.5
		if not Geometry2D.is_point_in_polygon(midpoint+normal*0.25,polygon):normal=-normal
		if not Geometry2D.is_point_in_polygon(midpoint+normal*0.25,polygon):
			_facts.omitted.append({"reason":"landform_face_has_no_material_interior","body_id":body.get("id",""),"face":face});return
		boundaries.append(Vector4(a.x,a.y,b.x,b.y))
		frames.append(Vector4(normal.x,normal.y,arc,1.0 if kind=="standing" else 2.0))
		receipts.append({"a":[a.x,a.y],"b":[b.x,b.y],"kind":kind,"inward_normal":[normal.x,normal.y],"arc_world":arc,"volume_id":body.get("volume_id","")})
		arc+=(b-a).length()
	if boundaries.size()>64:
		_facts.omitted.append({"reason":"landform_boundary_material_budget_exceeded","actual":boundaries.size(),"body_id":body.get("id","")});return
	var boundary_count:=boundaries.size()
	boundaries.resize(64);frames.resize(64)
	var material:=ShaderMaterial.new()
	material.shader=LANDFORM_SHADER
	material.set_shader_parameter("core_paint",core.texture)
	material.set_shader_parameter("surface_paint",surface.texture)
	material.set_shader_parameter("wall_paint",wall.texture)
	material.set_shader_parameter("world_origin",_pair(material_space.get("origin",[0.0,0.0])))
	material.set_shader_parameter("pixels_per_world_unit",density)
	material.set_shader_parameter("core_dimensions",core.dimensions)
	material.set_shader_parameter("surface_dimensions",surface.dimensions)
	material.set_shader_parameter("surface_region",_region_vector(surface.region))
	material.set_shader_parameter("wall_dimensions",wall.dimensions)
	material.set_shader_parameter("wall_region",_region_vector(wall.region))
	var surface_registration:=_face_depth_registration(surface)
	var wall_registration:=_face_depth_registration(wall)
	if surface_registration==Vector3.ZERO or wall_registration==Vector3.ZERO:return
	material.set_shader_parameter("surface_depth_registration",surface_registration)
	material.set_shader_parameter("wall_depth_registration",wall_registration)
	material.set_shader_parameter("boundary_segments",boundaries)
	material.set_shader_parameter("boundary_frames",frames)
	material.set_shader_parameter("boundary_count",boundary_count)
	var mesh:=_landform_mesh(polygon,indices,density)
	var node:=MeshInstance2D.new()
	node.name="LandformVolume_"+str(body.get("id","")).validate_node_name()
	node.mesh=mesh;node.material=material;node.z_index=-2
	add_child(node)
	var installed: Array=mesh.surface_get_arrays(0)
	var actual: Array=[]
	for point: Vector2 in installed[Mesh.ARRAY_VERTEX]:
		var world: Vector2=node.global_transform*point
		actual.append([world.x,world.y])
	var sources: Array=[]
	for spec: Dictionary in [core,surface,wall]:sources.append(_source_receipt(spec))
	var actual_surface_registration: Vector3=material.get_shader_parameter("surface_depth_registration")
	var actual_wall_registration: Vector3=material.get_shader_parameter("wall_depth_registration")
	var receipt: Dictionary={"id":body.get("id",""),"module_id":module.get("node_id",""),"volume_id":body.get("volume_id",""),"source_role":body.get("source_role",""),"source":core.source,"source_sha256":core.sha256,"source_dimensions":[core.dimensions.x,core.dimensions.y],"paint_sources":sources,"shared_physical_polygon":body.get("points",[]),"actual_world_polygon":actual,"actual_mesh_vertices":actual,"actual_mesh_indices":Array(installed[Mesh.ARRAY_INDEX]),"shared_surface_profile":body.get("surface_profile",[]),"neighbor_interfaces":body.get("neighbor_interfaces",[]),"source_exposed_faces":body.get("exposed_faces",[]),"installed_face_frames":receipts,"actual_paint_depth_registration":{"standing":[actual_surface_registration.x,actual_surface_registration.y,actual_surface_registration.z],"side_and_intrados":[actual_wall_registration.x,actual_wall_registration.y,actual_wall_registration.z],"paint_sampling":"world x phase; continuous finite-boundary distances; opaque pigment mixing; no per-edge texture rotation"},"material_space":material_space.duplicate(true),"actual_aspect_warp":1.0,"admitted_aspect_warp":1.0,"node_path":str(node.get_path()),"mapping":"landform_world_material_v1","collision_written":false,"physical_geometry_source":"same environment-program volume; physical installation belongs to assembler"}
	_facts.joint_terrain.append(receipt)
	_facts.terrain.append(receipt.duplicate(true))

func _build_landform_rear_walls() -> void:
	_facts["joint_rear_walls"]=[]
	_facts["joint_rear_openings"]=[]
	var source:=_landform_source("rear_substrate")
	if source.is_empty():return
	for module: Dictionary in _plan.get("joint_modules",[]):
		var openings: Array=module.get("rear_openings",[])
		for opening: Dictionary in openings:_facts.joint_rear_openings.append(opening.duplicate(true))
		for wall: Dictionary in module.get("rear_walls",[]):
			var polygon:=_points(wall.get("points",[]))
			var closes_opening:=false
			for opening: Dictionary in openings:
				var hole:=_points(opening.get("points",opening.get("polygon",[])))
				if hole.size()<3:continue
				for overlap: PackedVector2Array in Geometry2D.intersect_polygons(polygon,hole):
					if absf(_polygon_area(overlap))>0.05:closes_opening=true
			if closes_opening:
				_facts.omitted.append({"reason":"landform_rear_wall_closes_source_opening","id":wall.get("id","")});continue
			# The generator owns rear-wall decomposition. A renderer must not
			# independently invent a cave or fill a hole returned as a contour.
			_install_rear_piece(module,wall,polygon,source)

func _install_rear_piece(module: Dictionary,wall: Dictionary,polygon: PackedVector2Array,source: Dictionary) -> void:
	var indices:=Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty():
		_facts.omitted.append({"reason":"landform_rear_wall_invalid","id":wall.get("id","")});return
	var space: Dictionary=wall.get("material_space",{})
	var density:=float(space.get("pixels_per_world_unit",0.0))
	if density<=0.0:
		_facts.omitted.append({"reason":"landform_rear_wall_density_missing","id":wall.get("id","")});return
	var node:=Polygon2D.new()
	node.name="LandformRearSubstrate_"+str(wall.get("id","")).validate_node_name()
	node.polygon=polygon
	var uv:=PackedVector2Array()
	var origin:=_pair(space.get("origin",[0.0,0.0]))
	for point: Vector2 in polygon:uv.append((point-origin)*density)
	node.uv=uv;node.texture=source.texture
	node.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	var projection: Dictionary=_landform_catalog.get("rear_projection",{})
	var material:=ShaderMaterial.new()
	material.shader=LANDFORM_SHADER
	material.set_shader_parameter("core_paint",source.texture)
	material.set_shader_parameter("core_dimensions",source.dimensions)
	material.set_shader_parameter("world_origin",origin)
	material.set_shader_parameter("pixels_per_world_unit",density)
	material.set_shader_parameter("boundary_count",0)
	material.set_shader_parameter("paint_contrast",float(projection.get("contrast",0.55)))
	material.set_shader_parameter("paint_saturation",float(projection.get("saturation",0.85)))
	material.set_shader_parameter("paint_mist",float(projection.get("mist",0.08)))
	material.set_shader_parameter("paint_mist_color",Color(str(projection.get("mist_color","899a9a"))))
	node.material=material
	node.z_index=-12
	add_child(node)
	var actual: Array=[]
	for point: Vector2 in node.polygon:
		var world: Vector2=node.global_transform*point
		actual.append([world.x,world.y])
	_facts.joint_rear_walls.append({"id":wall.get("id",""),"module_id":module.get("node_id",""),"volume_id":wall.get("volume_id",""),"source":source.source,"source_sha256":source.sha256,"source_dimensions":[source.dimensions.x,source.dimensions.y],"actual_world_polygon":actual,"node_path":str(node.get_path()),"collision_written":false,"mapping":"source-owned cave rear substrate; openings stay transparent; uniform world paint scale","material_space":space.duplicate(true),"actual_material_projection":{"contrast":material.get_shader_parameter("paint_contrast"),"saturation":material.get_shader_parameter("paint_saturation"),"mist":material.get_shader_parameter("paint_mist"),"world_origin":[origin.x,origin.y],"world_pixels_per_unit":material.get_shader_parameter("pixels_per_world_unit"),"changes_alpha":false}})

func _install_landform_structure(module: Dictionary,piece: Dictionary) -> void:
	var role:=str(piece.get("asset_role",""))
	var source:=_landform_source(role,"structural_assets")
	if source.is_empty():return
	var spec: Dictionary=source.spec
	var source_anchor_raw: Array=piece.get("source_anchor",[])
	var world_anchor_raw: Array=piece.get("world_anchor",[])
	var registered_anchor_raw: Array=spec.get("source_anchor",[])
	if source_anchor_raw.size()!=2 or world_anchor_raw.size()!=2 or registered_anchor_raw.size()!=2:
		_facts.omitted.append({"reason":"landform_structure_anchor_missing","piece_id":piece.get("id","")});return
	var anchor:=_pair(source_anchor_raw)
	var world_anchor:=_pair(world_anchor_raw)
	var registered_anchor:=_pair(registered_anchor_raw)
	var scale_factor:=float(piece.get("uniform_scale",0.0))
	var allowed: Array=spec.get("allowed_scale",[])
	if anchor!=registered_anchor or not anchor.is_finite() or not world_anchor.is_finite() or allowed.size()!=2 or not is_finite(scale_factor) or scale_factor<=0.0 or scale_factor<float(allowed[0]) or scale_factor>float(allowed[1]):
		_facts.omitted.append({"reason":"landform_structure_registration_refused","piece_id":piece.get("id",""),"scale":scale_factor});return
	var outline_raw: Array=spec.get("source_outline_px",[])
	var negative_raw: Array=spec.get("negative_contour_px",[])
	var outline:=_points(outline_raw)
	var negative:=_points(negative_raw)
	if outline.size()<3 or negative.size()<3:
		_facts.omitted.append({"reason":"landform_structure_painted_contours_missing","piece_id":piece.get("id","")});return
	if piece.has("negative_contour_px") and piece.negative_contour_px!=negative_raw:
		_facts.omitted.append({"reason":"landform_structure_negative_registration_mismatch","piece_id":piece.get("id","")});return
	for point: Vector2 in outline+negative:
		if not point.is_finite() or point.x<0.0 or point.y<0.0 or point.x>source.dimensions.x or point.y>source.dimensions.y:
			_facts.omitted.append({"reason":"landform_structure_contour_outside_source","piece_id":piece.get("id","")});return
	if str(piece.get("layer","rear_vault"))!="rear_vault":
		_facts.omitted.append({"reason":"landform_structure_unimplemented_layer","piece_id":piece.get("id","")});return
	var node:=Sprite2D.new()
	node.name="LandformPaintedStructure_"+str(piece.get("id",role)).validate_node_name()
	node.texture=source.texture
	node.centered=false
	node.position=world_anchor-anchor*scale_factor
	node.scale=Vector2.ONE*scale_factor
	node.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	node.z_index=-8
	add_child(node)
	var actual_outline: Array=[]
	var actual_negative: Array=[]
	for point: Vector2 in outline:
		var world: Vector2=node.global_transform*point
		actual_outline.append([world.x,world.y])
	for point: Vector2 in negative:
		var world: Vector2=node.global_transform*point
		actual_negative.append([world.x,world.y])
	var actual_anchor: Vector2=node.global_transform*anchor
	var actual_scale: Vector2=node.global_scale
	var actual_connections: Array=[]
	for raw: Array in spec.get("bottom_connections_px",[]):
		var local_connection:=_pair(raw)
		var world_connection: Vector2=node.global_transform*local_connection
		actual_connections.append({"source_px":raw.duplicate(),"actual_world_point":[world_connection.x,world_connection.y]})
	_facts.joint_structural_pieces.append({"id":piece.get("id",""),"module_id":module.get("node_id",""),"volume_id":piece.get("volume_id",""),"asset_role":role,"source":source.source,"source_sha256":source.sha256,"source_dimensions":[node.texture.get_width(),node.texture.get_height()],"source_anchor":[anchor.x,anchor.y],"source_outline_px":outline_raw,"negative_contour_px":negative_raw,"actual_world_anchor":[actual_anchor.x,actual_anchor.y],"actual_world_outline":actual_outline,"actual_world_negative_contour":actual_negative,"actual_uniform_scale":[actual_scale.x,actual_scale.y],"actual_rotation":node.global_rotation,"actual_source_connections":actual_connections,"connection_interfaces":piece.get("connection_interfaces",[]).duplicate(true),"node_path":str(node.get_path()),"layer":"rear_vault","actual_z_index":node.z_index,"mapping":"unaltered independent structural painting; rigid uniform transform; original source alpha; no per-screen image or collision","collision_written":false})

static func _landform_mesh(polygon: PackedVector2Array,indices: PackedInt32Array,density: float) -> ArrayMesh:
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=polygon
	var uv:=PackedVector2Array()
	for point: Vector2 in polygon:uv.append(point*density)
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return mesh

func _face_depth_registration(source: Dictionary) -> Vector3:
	var registration: Dictionary=(source.spec as Dictionary).get("face_projection",{})
	var offset:=float(registration.get("source_depth_offset_px",-1.0))
	var depth:=float(registration.get("valid_depth_px",0.0))
	var fade_start:=float(registration.get("pigment_fade_start_px",-1.0))
	var region: Rect2=source.region
	if offset<0.0 or depth<=0.0 or fade_start<0.0 or fade_start>=depth or offset+depth>region.size.y:
		_facts.omitted.append({"reason":"landform_face_depth_registration_invalid","role":source.role});return Vector3.ZERO
	return Vector3(offset,depth,fade_start)

static func _region_vector(region: Rect2) -> Vector4:
	return Vector4(region.position.x,region.position.y,region.size.x,region.size.y)

static func _source_receipt(spec: Dictionary) -> Dictionary:
	return {"role":spec.role,"source":spec.source,"source_sha256":spec.sha256,"source_dimensions":[spec.dimensions.x,spec.dimensions.y],"region_px":[spec.region.position.x,spec.region.position.y,spec.region.size.x,spec.region.size.y],"source_face_projection":(spec.spec as Dictionary).get("face_projection",{}).duplicate(true)}

func _neighbor_projection(cuts: Array) -> Array:
	var bodies: Array=[]
	var sources: Dictionary={}
	for solid: Dictionary in _plan.get("solids",[]):sources[str(solid.id)]=solid
	for body: Dictionary in _plan.get("geological_bodies",[]):
		var polygon:=_points(body.get("points",body.get("polygon",[])))
		if polygon.is_empty():continue
		var bounds:=Rect2(polygon[0],Vector2.ZERO)
		for point: Vector2 in polygon:bounds=bounds.expand(point)
		var intersects:=false
		for cut: Rect2 in cuts:
			if bounds.intersects(cut):intersects=true;break
		if not intersects:
			bodies.append(body);continue
		# Exact source rectangles preserve holes and every neighbor outside the
		# plan-owned bank cut. No backdrop erasure, guessed collar or new floor.
		for source_id: String in body.get("source_ids",[]):
			if not sources.has(source_id):continue
			var fragments: Array=[_rect(sources[source_id].rect)]
			for cut: Rect2 in cuts:
				var next: Array=[]
				for fragment: Rect2 in fragments:next.append_array(_subtract_rect(fragment,cut))
				fragments=next
			for fragment: Rect2 in fragments:
				bodies.append({"id":str(body.id)+"/joint_neighbor/"+str(bodies.size()),"points":[[fragment.position.x,fragment.position.y],[fragment.end.x,fragment.position.y],[fragment.end.x,fragment.end.y],[fragment.position.x,fragment.end.y]],"source_ids":[source_id],"holes":[],"joint_cutout_projection":true})
	return bodies

func _install_joint_body(module: Dictionary,body: Dictionary,catalog: Dictionary) -> void:
	var role:=str(body.get("source_role",""))
	var family: Dictionary=catalog.get("terrain",catalog.get("bodies",{}))
	if not family.has(role):
		_facts.omitted.append({"reason":"joint_complete_bank_source_missing","body_id":body.get("id",""),"role":role});return
	var spec: Dictionary=family[role]
	var variant:=str(body.get("variant",body.get("variant_key","")))
	if not variant.is_empty():
		var variants: Dictionary=spec.get("variants",{})
		if not variants.has(variant):
			_facts.omitted.append({"reason":"joint_connected_mass_variant_missing","body_id":body.get("id",""),"variant":variant});return
		spec=variants[variant]
	var texture:=_texture(str(spec.get("texture","")))
	if texture==null:return
	var source_sha:=FileAccess.get_sha256(str(spec.texture))
	if str(body.get("source_sha256",""))!=source_sha:
		_facts.omitted.append({"reason":"joint_frozen_source_sha_mismatch","body_id":body.get("id","")});return
	var physical_polygon:=_points(body.get("points",[]))
	var polygon:=_points(body.get("visual_points",body.get("points",[])))
	var recorded_mesh: Dictionary=body.get("render_mesh",{})
	var vertices:=_points(recorded_mesh.get("vertices",[]))
	var indices:=PackedInt32Array(recorded_mesh.get("indices",[]))
	if physical_polygon.size()<3 or polygon.size()<3 or vertices.size()<4 or indices.is_empty() or indices.size()%3!=0:
		_facts.omitted.append({"reason":"joint_shared_bank_polygon_invalid","body_id":body.get("id","")});return
	var bounds:=Rect2(physical_polygon[0],Vector2.ZERO)
	for point: Vector2 in physical_polygon:bounds=bounds.expand(point)
	var region_raw: Array=spec.get("source_region_px",[0.0,0.0,float(texture.get_width()),float(texture.get_height())])
	var source:=_rect(spec.get("physical_reference_rect_px",region_raw))
	if not source.has_area() or bounds.size.x<=0.0 or bounds.size.y<=0.0:
		_facts.omitted.append({"reason":"joint_source_reference_invalid","body_id":body.get("id","")});return
	var uv:=PackedVector2Array()
	var explicit: Array=recorded_mesh.get("source_uv_px",[])
	if explicit.size()!=vertices.size():
		_facts.omitted.append({"reason":"joint_versioned_source_uv_missing","body_id":body.get("id","")});return
	uv=_points(explicit)
	for point: Vector2 in uv:
		if not point.is_finite() or point.x<0.0 or point.y<0.0 or point.x>texture.get_width() or point.y>texture.get_height():
			_facts.omitted.append({"reason":"joint_source_uv_outside_original","body_id":body.get("id","")});return
	var scales:=Vector2(bounds.size.x/source.size.x,bounds.size.y/source.size.y)
	var aspect_warp:=maxf(scales.x,scales.y)/maxf(0.000001,minf(scales.x,scales.y))
	var admitted_warp:=minf(1.35,float(spec.get("max_aspect_warp",1.35)))
	for index: int in indices:
		if index<0 or index>=vertices.size():
			_facts.omitted.append({"reason":"joint_frozen_mesh_index_invalid","body_id":body.get("id","")});return
	var triangle_area:=0.0
	for index: int in range(0,indices.size(),3):
		triangle_area+=absf((vertices[indices[index+1]]-vertices[indices[index]]).cross(vertices[indices[index+2]]-vertices[indices[index]]))*0.5
	var boundary_area:=absf(_polygon_area(polygon))
	if absf(triangle_area-boundary_area)>maxf(0.05,boundary_area*0.00001):
		_facts.omitted.append({"reason":"joint_complete_mesh_coverage_invalid","body_id":body.get("id",""),"triangle_area":triangle_area,"boundary_area":boundary_area});return
	var local_warp:=_maximum_triangle_warp(vertices,uv,indices)
	aspect_warp=maxf(aspect_warp,local_warp)
	if not is_finite(aspect_warp) or aspect_warp>admitted_warp:
		_facts.omitted.append({"reason":"joint_whole_painting_aspect_warp_refused","body_id":body.get("id",""),"actual_aspect_warp":aspect_warp,"admitted_aspect_warp":admitted_warp});return
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	var normalized_uv:=PackedVector2Array()
	for point: Vector2 in uv:normalized_uv.append(point/texture.get_size())
	arrays[Mesh.ARRAY_TEX_UV]=normalized_uv
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	var node:=MeshInstance2D.new()
	node.name="JointWholeBank_"+str(body.get("id",role)).validate_node_name()
	node.mesh=mesh
	node.texture=texture
	node.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	node.z_index=-2
	add_child(node)
	var source_uv: Array=[]
	var actual_points: Array=[]
	for point: Vector2 in uv:source_uv.append([point.x,point.y])
	for point: Vector2 in polygon:
		var actual:=node.global_transform*point
		actual_points.append([actual.x,actual.y])
	var actual_vertices: Array=[]
	var installed_arrays: Array=mesh.surface_get_arrays(0)
	for point: Vector2 in installed_arrays[Mesh.ARRAY_VERTEX]:
		var actual:=node.global_transform*point
		actual_vertices.append([actual.x,actual.y])
	var installed_uv_px: Array=[]
	for point: Vector2 in installed_arrays[Mesh.ARRAY_TEX_UV]:
		var pixel:=point*texture.get_size()
		installed_uv_px.append([pixel.x,pixel.y])
	var installed_warp:=_maximum_triangle_warp(_points(actual_vertices),_points(installed_uv_px),PackedInt32Array(installed_arrays[Mesh.ARRAY_INDEX]))
	if not is_finite(installed_warp) or installed_warp>admitted_warp:
		node.hide()
		node.queue_free()
		_facts.omitted.append({"reason":"joint_installed_triangle_warp_refused","body_id":body.get("id",""),"actual_aspect_warp":installed_warp,"admitted_aspect_warp":admitted_warp});return
	aspect_warp=maxf(aspect_warp,installed_warp)
	var receipt: Dictionary={"id":body.get("id",role),"module_id":module.get("node_id",""),"source_role":role,"variant":variant,"source":spec.texture,"source_sha256":FileAccess.get_sha256(str(spec.texture)),"source_dimensions":[texture.get_width(),texture.get_height()],"source_region_px":region_raw,"physical_reference_rect_px":[source.position.x,source.position.y,source.size.x,source.size.y],"shared_physical_polygon":body.get("points",[]),"source_uv_px":source_uv,"actual_world_polygon":actual_points,"actual_mesh_vertices":actual_vertices,"actual_mesh_uv_px":installed_uv_px,"actual_mesh_indices":Array(installed_arrays[Mesh.ARRAY_INDEX]),"triangle_area":triangle_area,"boundary_area":boundary_area,"shared_surface_profile":body.get("surface_profile",[]),"neighbor_interfaces":body.get("neighbor_interfaces",[]),"actual_aspect_warp":aspect_warp,"admitted_aspect_warp":admitted_warp,"node_path":str(node.get_path()),"mapping":"one explicit complete-volume mesh; no per-fragment surface search, mirrored core, alpha strips or texture repeat","collision_written":false,"physical_geometry_source":"same source-derived whole-mass terrain_bodies; explicit candidate physics domain owned by assembler, never renderer"}
	_facts.joint_terrain.append(receipt)
	_facts.terrain.append(receipt.duplicate(true))

func _installed_solid_top_edges() -> Array:
	var edges: Array=super._installed_solid_top_edges()
	var assembler:=_stage.get("assembler") as Node
	if assembler==null:return edges
	for candidate: Node in assembler.find_children("*","CollisionPolygon2D",true,false):
		var shape:=candidate as CollisionPolygon2D
		var body_owner:=shape.get_parent() as StaticBody2D
		if body_owner==null or (body_owner.collision_layer & 1)==0 or shape.disabled or shape.one_way_collision or shape.build_mode!=CollisionPolygon2D.BUILD_SOLIDS:continue
		var polygon:=shape.polygon
		for index: int in polygon.size():
			var a:=shape.global_transform*polygon[index]
			var b:=shape.global_transform*polygon[(index+1)%polygon.size()]
			if absf(a.y-b.y)>0.0001 or absf(a.x-b.x)<0.0001:continue
			# Only real horizontal upward-facing support edges: the installed
			# polygon must contain matter immediately below the actual world edge.
			var below:=shape.global_transform.affine_inverse()*((a+b)*0.5+Vector2(0.0,0.1))
			if not Geometry2D.is_point_in_polygon(below,polygon):continue
			edges.append({"a":a,"b":b,"node_path":str(shape.get_path()),"shape_kind":"actual_enabled_collision_polygon_horizontal_top"})
	return edges

static func _polygon_area(points: PackedVector2Array) -> float:
	var area:=0.0
	for index: int in points.size():area+=(points[index]-points[0]).cross(points[(index+1)%points.size()]-points[0])
	return area*0.5

static func _maximum_triangle_warp(points: PackedVector2Array,uv: PackedVector2Array,indices: PackedInt32Array) -> float:
	var worst:=1.0
	for index: int in range(0,indices.size(),3):
		var a:=indices[index];var b:=indices[index+1];var c:=indices[index+2]
		var u:=uv[b]-uv[a];var v:=uv[c]-uv[a]
		var p:=points[b]-points[a];var q:=points[c]-points[a]
		var determinant:=u.cross(v)
		if absf(determinant)<0.000001 or determinant*p.cross(q)<=0.0:return INF
		var x:=(p*v.y-q*u.y)/determinant
		var y:=(q*u.x-p*v.x)/determinant
		var trace:=x.length_squared()+y.length_squared()
		var area:=x.cross(y)
		var discriminant:=sqrt(maxf(0.0,trace*trace-4.0*area*area))
		var lower:=(trace-discriminant)*0.5
		if lower<=0.0000000001:return INF
		worst=maxf(worst,sqrt((trace+discriminant)*0.5/lower))
	return worst

static func _subtract_rect(source: Rect2,cut: Rect2) -> Array:
	if not source.intersects(cut):return [source]
	var overlap:=source.intersection(cut)
	var fragments: Array=[]
	if overlap.position.y>source.position.y:fragments.append(Rect2(source.position,Vector2(source.size.x,overlap.position.y-source.position.y)))
	if overlap.end.y<source.end.y:fragments.append(Rect2(Vector2(source.position.x,overlap.end.y),Vector2(source.size.x,source.end.y-overlap.end.y)))
	if overlap.position.x>source.position.x:fragments.append(Rect2(Vector2(source.position.x,overlap.position.y),Vector2(overlap.position.x-source.position.x,overlap.size.y)))
	if overlap.end.x<source.end.x:fragments.append(Rect2(Vector2(overlap.end.x,overlap.position.y),Vector2(source.end.x-overlap.end.x,overlap.size.y)))
	return fragments
