class_name P1RandomPlainsSample
extends Node2D
## Explicit ordinary-region candidate. Reads committed collision geometry; never writes it.
const CATALOG := "res://resources/visual_development/p1_candidate.json"
const FAMILY := "res://resources/visual_development/p1_random_family.json"
const GRAMMAR := preload("res://scripts/art/painted_terrain_grammar.gd")
const PAGE_SHADER := preload("res://scripts/art/p1_random_page.gdshader")
var facts: Dictionary = {}
var _stage: PlainsRegionStage
var _catalog: Dictionary
var _family: Dictionary
var _paint: Node2D
var _baseline: Node2D
var _geometry: Array[Rect2] = []

func install(stage: PlainsRegionStage) -> void:
	_stage=stage
	_catalog=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	_family=JSON.parse_string(FileAccess.get_file_as_string(FAMILY)) if FileAccess.file_exists(FAMILY) else {}
	_refresh()
	_stage.set_meta("visual_language_sample_path",CATALOG)
	var presentation_script := load("res://scripts/art/visual_language_sample.gd") as Script
	var presentation := presentation_script.new() as Node2D
	presentation.call("configure",stage,{"presentation_scope":"formal_random"})
	stage.add_child(presentation)
	var props_path := "res://scripts/art/p1_unity_props.gd"
	if ResourceLoader.exists(props_path):
		var props_script := load(props_path) as Script
		var props := props_script.new() as Node2D
		stage.add_child(props)
		props.call("install",stage)

func _process(_delta: float) -> void:
	if not is_instance_valid(_stage) or not is_instance_valid(_stage.terrain_art):return
	if _baseline!=_stage.terrain_art.art or _geometry!=_stage.terrain_art.authored_solids:_refresh()

func _refresh() -> void:
	if is_instance_valid(_paint):_paint.free()
	_paint=Node2D.new();add_child(_paint)
	_baseline=_stage.terrain_art.art
	_geometry=_stage.terrain_art.authored_solids.duplicate()
	# Baseline remains visible until each complete actual union has valid meshes.
	for child: CanvasItem in _baseline.get_children():child.show()
	var data := PlainsTerrainFamilySampler.inventory(_stage)
	var selected: Array[Dictionary]=[]
	var omitted: Array[Dictionary]=[]
	for group: Dictionary in PlainsTerrainFamilySampler.groups(data.rooted):
		var structural := _rooted_structure(group)
		var result: Dictionary=structural if not structural.is_empty() else _group(group)
		if not result.ok and result.reason in ["page_mesh_coverage_refused","non_simple_or_non_monotone_union","page_has_hole_or_disconnected_solid","vertical_or_degenerate_top"]:
			var union_mesh := P1RandomUnionMesh.build(group,_catalog,_family)
			if union_mesh!=null:
				var original_reason: String=result.reason
				_paint.add_child(union_mesh)
				result=union_mesh.get_meta("facts")
				result["original_contour_refusal"]=original_reason
		if result.ok:
			selected.append(result)
			for child: Node in _baseline.get_children():
				if child is ColorRect and _rect_in_union(Rect2(child.position,child.size),group.parts):child.hide()
				elif child is ColorRect and child.get_meta("family_use","")=="limestone_exposed_fringe":
					var edge_material := child.material as ShaderMaterial
					if edge_material!=null:
						var edges: PackedVector4Array=edge_material.get_shader_parameter("faces")
						if not edges.is_empty() and edges[0] in group.faces:child.hide()
		else:omitted.append(result)
	facts={"status":"ordinary_random_candidate_not_art_admitted","catalog_sha256":FileAccess.get_sha256(CATALOG),"manifest_hash":_stage.generated.manifest.manifest_hash,"selected":selected,"omitted":omitted,"floating_preserved":data.floating.size(),"one_way_preserved":data.one_way.size(),"moving_preserved":_moving_count(),"collision_changed":false,"rng_used":false,"geometry":_rects(_geometry)}
	facts["scenery"]=_scenery(data.rooted)
	facts["structures"]=_structures(data)
	facts["floating_preserved"]=0;facts["one_way_preserved"]=0;facts["moving_preserved"]=0
	for row: Dictionary in facts.structures.omitted:
		if str(row.semantic).begins_with("floating"):facts.floating_preserved+=1
		elif str(row.semantic).begins_with("one_way"):facts.one_way_preserved+=1
		elif str(row.semantic).begins_with("moving"):facts.moving_preserved+=1
	_stage.set_meta("p1_random_coverage",facts)

func _rooted_structure(group: Dictionary) -> Dictionary:
	var bounds: Rect2=group.bounds
	var kind := "column" if bounds.size.x<=48 and bounds.size.y>=bounds.size.x*2 else "bridge" if bounds.size.y<=40 and bounds.size.x>=bounds.size.y*3 else ""
	if kind.is_empty() or not _rect_in_union(bounds,group.parts):return {}
	var node := P1StructureArt.make(bounds,kind)
	if node==null:return {}
	_paint.add_child(node)
	return {"ok":true,"bounds":_rect(bounds),"reason":"","method":"actual narrow rooted solid structural family","structure":node.get_meta("p1_structure"),"pages":[]}

func _hide_solid(rect: Rect2) -> void:
	var parts: Array[Rect2]=[rect]
	for child: Node in _baseline.get_children():
		if child is ColorRect and _rect_in_union(Rect2(child.position,child.size),parts):child.hide()
		elif child is CanvasItem and child.get_meta("physical_rect",Rect2())==rect:child.hide()

func _structures(data: Dictionary) -> Dictionary:
	var applied: Array[Dictionary]=[]
	var omitted: Array[Dictionary]=[]
	for row: Dictionary in data.one_way:
		var module := get_node(str(row.module_path)) as PlatformingModule
		for child: Node in module.get_children():
			if child is CanvasItem and child.get_meta("platform_index",-1)==int(row.platform_index):child.show()
		var node := P1StructureArt.make(row.rect,"bridge")
		if node==null:omitted.append({"semantic":"one_way","rect":_rect(row.rect)});continue
		_paint.add_child(node)
		for child: Node in module.get_children():
			if child is CanvasItem and child.get_meta("platform_index",-1)==int(row.platform_index):child.hide()
		var record: Dictionary=node.get_meta("p1_structure");record["semantic"]="one_way_pass_through_unchanged";applied.append(record)
	for row: Dictionary in data.floating:
		var rect: Rect2=row.rect
		var kind := "column" if rect.size.x<=48 and rect.size.y>rect.size.x else "floating" if rect.size.x>=rect.size.y else ""
		if kind.is_empty():omitted.append({"semantic":"floating_unknown_shape","rect":_rect(rect)});continue
		var node := P1StructureArt.make(rect,kind)
		if node==null:omitted.append({"semantic":"floating_source_refused","rect":_rect(rect)});continue
		_paint.add_child(node);_hide_solid(rect)
		var record: Dictionary=node.get_meta("p1_structure");record["semantic"]="static_solid_floating";applied.append(record)
	for module: PlatformingModule in _stage.assembler.modules:
		for ferry: ModuleMovingPlatform in module.moving_platforms:
			if ferry.has_meta("p1_structure_node") and is_instance_valid(ferry.get_meta("p1_structure_node")):
				applied.append((ferry.get_meta("p1_structure_node") as Node).get_meta("p1_structure"));continue
			var node := P1StructureArt.make(Rect2(-ferry.definition.size/2.0,ferry.definition.size),"bridge")
			if node==null:omitted.append({"semantic":"moving_source_refused"});continue
			if is_instance_valid(ferry.painted_art):ferry.painted_art.hide()
			ferry.add_child(node);ferry.painted_art=node;ferry.set_meta("p1_structure_node",node);ferry.queue_redraw()
			var record: Dictionary=node.get_meta("p1_structure");record["semantic"]="moving_body_local_original_carrier";record["body_path"]=str(ferry.get_path());applied.append(record)
	return {"applied":applied,"omitted":omitted,"physics_changed":false,"one_way_count":data.one_way.size(),"floating_count":data.floating.size(),"moving_count":_moving_count()}

func _scenery(rooted: Array[Rect2]) -> Dictionary:
	var blocked := PlainsRegionScenery.protection(_stage)
	var candidates: Array[Vector4]=[]
	for group: Dictionary in PlainsTerrainFamilySampler.groups(rooted):
		for edge: Vector4 in group.faces:
			if edge.z>edge.x:candidates.append(edge)
	var placed: Array[Dictionary]=[]
	var omitted: Array[Dictionary]=[]
	for area: Dictionary in _stage.generated.manifest.areas:
		if str(area.get("role","")) not in ["junction","merchant"]:continue
		var component := "shelter" if str(area.role)=="merchant" else "tree"
		var spec: Dictionary=_catalog.components[component]
		var scale_value := 0.0
		for entry: Dictionary in _catalog.placements:
			if str(entry.component)==component:scale_value=float(entry.scale)
		var bbox: Array=spec.alpha128_bbox
		var pivot := Vector2(spec.pivot[0],spec.pivot[1])
		var origin := Vector2(area.position[0],area.position[1])
		var width := float(bbox[2]-bbox[0])*scale_value
		var found := false
		for edge: Vector4 in candidates:
			if edge.z-edge.x<width+16 or absf(edge.y-origin.y)>240:continue
			for offset: float in [-220,220,-340,340]:
				var x := clampf(origin.x+offset,edge.x-(float(bbox[0])-pivot.x)*scale_value+8,edge.z-(float(bbox[2])-pivot.x)*scale_value-8)
				if absf(x-origin.x)>480:continue
				var foot := Vector2(x,edge.y+5)
				var visible := Rect2(foot+(Vector2(bbox[0],bbox[1])-pivot)*scale_value,Vector2(bbox[2]-bbox[0],bbox[3]-bbox[1])*scale_value)
				if blocked.any(func(rect: Rect2)->bool:return rect.intersects(visible.grow(8))):continue
				var atlas := AtlasTexture.new();atlas.atlas=load(str(spec.texture)) as Texture2D
				atlas.region=Rect2(spec.region[0],spec.region[1],spec.region[2],spec.region[3]);atlas.filter_clip=true
				var sprite := Sprite2D.new();sprite.texture=atlas;sprite.centered=false
				sprite.offset=-pivot;sprite.position=foot;sprite.scale=Vector2.ONE*scale_value
				sprite.z_as_relative=false;sprite.z_index=-4;_paint.add_child(sprite)
				blocked.append(visible.grow(80));found=true
				placed.append({"area_id":area.id,"component":component,"foot":[foot.x,foot.y],"support_edge":[edge.x,edge.y,edge.z,edge.w],"visible_bounds":_rect(visible),"source":spec.texture})
				break
			if found:break
		if not found:omitted.append({"area_id":area.id,"component":component,"reason":"no_clear_actual_static_support"})
	# This subtree is cosmetic composition only. Functional merchant/chests,
	# pickups, map and interactables live elsewhere and remain untouched.
	for child: Node in _stage.get_children():
		if child is PlainsRegionScenery:child.hide()
	return {"placed":placed,"omitted":omitted,"legacy_cosmetic_scenery_replaced":true,"functional_objects_preserved":true}

func _moving_count() -> int:
	var count := 0
	for module: PlatformingModule in _stage.assembler.modules:count+=module.moving_platforms.size()
	return count

func _rect_in_union(rect: Rect2,parts: Array[Rect2]) -> bool:
	# Exact for axis-aligned source solids: partition at every member edge.
	# AABB containment would wrongly erase a disconnected slab inside an L gap.
	var xs: Array[float]=[rect.position.x,rect.end.x]
	var ys: Array[float]=[rect.position.y,rect.end.y]
	for part: Rect2 in parts:
		for x: float in [part.position.x,part.end.x]:
			if x>rect.position.x and x<rect.end.x and x not in xs:xs.append(x)
		for y: float in [part.position.y,part.end.y]:
			if y>rect.position.y and y<rect.end.y and y not in ys:ys.append(y)
	xs.sort();ys.sort()
	for x: int in xs.size()-1:
		for y: int in ys.size()-1:
			var center := Vector2((xs[x]+xs[x+1])*.5,(ys[y]+ys[y+1])*.5)
			if not parts.any(func(part: Rect2)->bool:return part.has_point(center)):return false
	return true

func _group(group: Dictionary) -> Dictionary:
	var result := {"ok":false,"bounds":_rect(group.bounds),"reason":""}
	var outline := _outline(group.faces)
	var top := _top(group.faces)
	if outline.is_empty() or top.is_empty():result.reason="non_simple_or_non_monotone_union";return result
	if group.bounds.size.y<float(_catalog.terrain.grammar.lip_world_depth):result.reason="thinner_than_painted_lip";return result
	var variants: Array=_family.get("sections",[])
	if variants.is_empty() or _family.get("status","")!="source_measured_candidate":result.reason="finite_connection_family_missing_or_uncalibrated";return result
	var container := Node2D.new();_paint.add_child(container)
	var pages: Array[Dictionary]=[]
	var start := float(top[0][0])
	var finish := float(top[-1][0])
	var index := 0
	while start<finish-.001:
		var variant: Dictionary=variants[index%variants.size()]
		var spec: Dictionary=_catalog.terrain.grammar.duplicate(true)
		for key: String in variant:spec[key]=variant[key]
		if _family.has("visible_underside"):spec.visible_underside=_family.visible_underside.duplicate(true)
		if not ResourceLoader.exists(str(spec.texture)):
			container.free();result.reason="required_section_missing";return result
		var texture := load(str(spec.texture)) as Texture2D
		var ppu := float(spec.source_pixels_per_world_unit)
		var margin := float(_family.get("source_margin",24))
		var capacity := (texture.get_width()-margin*2)/ppu
		# A page is finite at the original local scale. No whole-bank compression.
		var page_top := _slice_top(top,start,finish,capacity)
		if page_top.size()<2:container.free();result.reason="finite_page_cannot_advance";return result
		var end := float(page_top[-1][0])
		if end<=start+.001:container.free();result.reason="vertical_or_degenerate_top";return result
		var clip := PackedVector2Array([Vector2(start,group.bounds.position.y-100),Vector2(end,group.bounds.position.y-100),Vector2(end,group.bounds.end.y+1),Vector2(start,group.bounds.end.y+1)])
		var pieces := Geometry2D.intersect_polygons(_packed(outline),clip)
		if pieces.size()!=1:container.free();result.reason="page_has_hole_or_disconnected_solid";return result
		var key := "page_%s"%index
		var page_outline: Array=[]
		for p: Vector2 in pieces[0]:page_outline.append([p.x,p.y])
		spec.source_x_offsets={key+"_shore":margin};spec.face_patches=[]
		var ends: Dictionary={}
		if index==0:ends.left=spec.ends.left
		if end>=finish-.001:ends.right=spec.ends.right
		spec.ends=ends
		var grammar := GRAMMAR.new()
		grammar.configure({"solid_polygons":[{"id":key+"_shore","points":page_outline}],"top_polylines":[{"id":key+"_grass","points":page_top}]},spec)
		container.add_child(grammar)
		var measurement := grammar.measured_nodes()
		if measurement.banks.size()!=1 or not measurement.banks[0].coverage.all_samples_match_actual_solid:
			container.free();result.reason="page_mesh_coverage_refused";return result
		var overlap := minf(float(_family.get("overlap_world",80)),(end-start)*.2)
		for mesh: MeshInstance2D in grammar.get_children():
			var material := ShaderMaterial.new();material.shader=PAGE_SHADER
			if mesh.material is ShaderMaterial and spec.has("visible_underside"):
				material.set_shader_parameter("has_underside",true)
				for parameter: String in ["underside","bottom_profile","bank_bottom","bank_left","source_start","source_pixels_per_world_unit","underside_size","blend_top","blend_bottom"]:
					material.set_shader_parameter(parameter,(mesh.material as ShaderMaterial).get_shader_parameter(parameter))
			material.set_shader_parameter("fade_start",start)
			material.set_shader_parameter("fade_width",overlap if index>0 else 0.0)
			mesh.material=material
		pages.append({"source":spec.texture,"source_sha256":FileAccess.get_sha256(str(spec.texture)),"x_span":[start,end],"source_span":measurement.banks[0].source_span,"overlap":overlap if index>0 else 0,"external_ends":ends.keys(),"coverage":measurement.banks[0].coverage})
		if end>=finish-.001:break
		start=end-overlap;index+=1
		if index>128:container.free();result.reason="finite_page_budget_exceeded";return result
	result.ok=true;result.reason="";result.pages=pages;result.source_reuse_explicit=true
	return result

func _top(faces: PackedVector4Array) -> Array:
	var runs: Array[Vector4]=[]
	for edge: Vector4 in faces:
		if edge.z>edge.x:runs.append(edge)
	runs.sort_custom(func(a: Vector4,b: Vector4)->bool:return a.x<b.x)
	var result: Array=[]
	for edge: Vector4 in runs:
		if not result.is_empty() and absf(float(result[-1][0])-edge.x)>.001:return []
		if result.is_empty() or result[-1]!=[edge.x,edge.y]:result.append([edge.x,edge.y])
		result.append([edge.z,edge.w])
	return result

func _slice_top(top: Array,start: float,finish: float,budget: float) -> Array:
	var result: Array=[]
	var used := 0.0
	for i: int in top.size()-1:
		var a := Vector2(top[i][0],top[i][1]);var b := Vector2(top[i+1][0],top[i+1][1])
		if b.x<start or a.x>finish:continue
		if a.x<start and b.x>a.x:a=a.lerp(b,(start-a.x)/(b.x-a.x))
		if result.is_empty():result.append([a.x,a.y])
		var length := a.distance_to(b)
		if used+length>budget:b=a.lerp(b,(budget-used)/maxf(length,.001))
		result.append([b.x,b.y]);used+=length
		if used>=budget or b.x>=finish:break
	return result

func _outline(faces: PackedVector4Array) -> Array:
	if faces.is_empty():return []
	var remaining := Array(faces);var edge: Vector4=remaining.pop_front()
	var result: Array=[[edge.x,edge.y]];var cursor := Vector2(edge.z,edge.w)
	while not remaining.is_empty():
		var found := false
		for i: int in remaining.size():
			edge=remaining[i]
			if cursor==Vector2(edge.x,edge.y):result.append([edge.x,edge.y]);cursor=Vector2(edge.z,edge.w);remaining.remove_at(i);found=true;break
		if not found:return []
	return result if cursor==Vector2(result[0][0],result[0][1]) else []

func _packed(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p: Array in points:result.append(Vector2(p[0],p[1]))
	return result
func _rect(r: Rect2) -> Array:return [r.position.x,r.position.y,r.size.x,r.size.y]
func _rects(rects: Array[Rect2]) -> Array:
	var result: Array=[]
	for r: Rect2 in rects:result.append(_rect(r))
	return result
func measured_nodes() -> Dictionary:return facts.duplicate(true)
