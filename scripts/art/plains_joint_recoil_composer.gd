class_name PlainsJointRecoilComposer
extends "res://scripts/art/plains_regional_composer.gd"
## Candidate opt-in: one shared challenge specification owns physical bank
## polygons, neighbor cuts and the complete painted-bank mesh projection.
const JOINT_CATALOG := "res://resources/visual_development/p1_joint_recoil_assets.json"

func _build_layers() -> void:
	if (_plan.get("joint_modules",[]) as Array).is_empty():
		super._build_layers()
		return
	# Actual sky and transparent distant geology are already installed by the
	# inherited global background. Do not add the rejected flat wall belts.
	_facts["joint_background"]={"global_painted_background_preserved":true,"middle_wall_belts_retired":true,"per_seed_images":false}

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
