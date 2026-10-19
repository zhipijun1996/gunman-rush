class_name PlainsRegionArtPlan
extends RefCounted
## Candidate-only companion to the actual complete formal region Manifest.
## Physics, content, resources and replay remain owned by the formal generator.
const VERSION := "plains-regional-art-v2"
const LANGUAGE_VERSION := "plains-regional-art-v5-bounded-language"
const JOINT_VERSION := "plains-regional-art-v4-environment-program"
const ASSET_CATALOG := "res://resources/visual_development/p1_regional_assets.json"
const ATTEMPTS := 4
const MAX_WORLD_WIDTH := 22000.0
const MAX_WORLD_HEIGHT := 6500.0
const MIN_SURFACE_WIDTH := 20.0

static func generate(seed_value: String, tuning: PlayerTuning, difficulty := "intro", force_family := "", joint_recoil_profile := false, art_language_profile := "") -> Dictionary:
	if seed_value.is_empty() or difficulty not in ["intro","advanced"] or art_language_profile not in ["","bounded_plains_v1"] or (joint_recoil_profile and not art_language_profile.is_empty()):
		return {"ok":false,"error":"Invalid or conflicting regional art generation input","rejections":[]}
	var generator := PlainsRegionGenerator.new()
	generator.root_bell_mode = "v3"
	generator.regional_art_profile = "continuous_plains_v1"
	generator.joint_recoil_profile = joint_recoil_profile
	generator.art_language_profile = art_language_profile
	var rejections: Array = []
	for attempt: int in ATTEMPTS:
		# Reuse the formal topology, semantic routes, recipe allocator, geometry,
		# enemies, reward budgets, shortcut, optional challenges and Boss entrance.
		var manifest := generator._candidate(seed_value,false,force_family,attempt,difficulty)
		if not generator.validate(manifest,tuning):
			rejections.append({"attempt":attempt,"layer":"formal_generation","reason":"Original full-region validation rejected candidate"})
			continue
		var result := compile(manifest)
		if not result.ok:
			rejections.append({"attempt":attempt,"layer":"regional_art_grammar","reason":result.error})
			continue
		var generated := generator._result(manifest)
		generated.regional_art_plan = result.plan
		generated.regional_art_plan.generation = {"attempt":attempt,"attempt_limit":ATTEMPTS,"rejections":rejections.duplicate(true),"fallback_id":""}
		generated.regional_art_plan.plan_hash = plan_hash(generated.regional_art_plan)
		generated.rejections = rejections
		return generated
	return {"ok":false,"error":"No formal full-region candidate expressible by regional art grammar; no unverified fallback","rejections":rejections}

static func compile(manifest: Dictionary) -> Dictionary:
	if manifest.get("sample",true) or manifest.get("layout_id","") != "connected_region":
		return {"ok":false,"error":"Regional art requires the full connected-region Manifest, never a sample or place chain"}
	var language_candidate: bool = manifest.get("art_language_profile","")=="bounded_plains_v1"
	if language_candidate and manifest.get("joint_recoil_profile",false):return {"ok":false,"error":"Joint legacy and bounded language consumers are exclusive"}
	if language_candidate:
		var language_error := _language_world_error(manifest)
		if not language_error.is_empty():return {"ok":false,"error":language_error}
	if manifest.get("regional_art_profile","")!="continuous_plains_v1": return {"ok":false,"error":"Missing actual pre-embedding regional art profile"}
	for edge: Dictionary in manifest.connections:
		var width:=0.0
		for index: int in edge.get("modules",[]): width+=PlainsRegionGenerator.definition(manifest.nodes[index]).world_bounds.size.x
		if width>2200.0: return {"ok":false,"error":"Horizontal phrase exceeds source expression width budget"}
	if manifest.art_layout.get("landmass_budget_failed",false) or manifest.ground_supports.size()>600:
		return {"ok":false,"error":"Continuous landmass carve exceeds bounded support projection budget"}
	if manifest.has("joint_recoil_error"): return {"ok":false,"error":manifest.joint_recoil_error}
	var joint_modules: Array=[]
	if manifest.get("joint_recoil_profile",false):
		for node: Dictionary in manifest.nodes:
			if node.has("joint_recoil"):
				if not PlainsJointRecoilPlan.errors(node.joint_recoil).is_empty(): return {"ok":false,"error":"Joint recoil semantic source drift"}
				joint_modules.append(PlainsJointRecoilPlan.instantiate(node))
		if joint_modules.size()!=1 or str(joint_modules[0].node_id).begins_with("tutorial"): return {"ok":false,"error":"Joint experiment requires exactly one actual non-tutorial recoil challenge"}
		for joint: Dictionary in joint_modules:
			for piece: Dictionary in joint.get("structural_pieces",[]):
				if not piece.get("placement_feasible",false):return {"ok":false,"error":"Painted vault has no legal common bank interface"}
				for connection: Dictionary in piece.connection_interfaces:
					if not connection.get("valid",false):return {"ok":false,"error":"Painted vault support foot does not intersect its actual owned creek mass"}
			for body: Dictionary in joint.terrain_bodies:
				var polygon:=PackedVector2Array()
				for point: Array in body.points: polygon.append(_point(point))
				for space: Dictionary in joint.region_context.get("protected_actual_airspace",[]):
					var r:=_rect(space.rect)
					var obstacle:=PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
					var intrusion: Array[PackedVector2Array]=Geometry2D.intersect_polygons(polygon,obstacle)
					# The old dock may legitimately touch its existing ferry/actor
					# clearance envelope. Protect ALL newly occupied air, preserving
					# only the exact already-owned original static contact domains.
					for domain: Dictionary in joint.region_context.get("original_owned_static_domains",[]):
						var old_rect:=_rect(domain.rect)
						var old_polygon:=PackedVector2Array([old_rect.position,Vector2(old_rect.end.x,old_rect.position.y),old_rect.end,Vector2(old_rect.position.x,old_rect.end.y)])
						var remaining: Array[PackedVector2Array]=[]
						for piece: PackedVector2Array in intrusion:remaining.append_array(Geometry2D.clip_polygons(piece,old_polygon))
						intrusion=remaining
					if not intrusion.is_empty(): return {"ok":false,"error":"Joint environment introduces solid into protected movement: "+str(space.owner)+" kind="+str(space.get("kind",""))+" source_role="+str(body.get("source_role",""))}
	var values: Array = manifest.get("world_bounds",[])
	if values.size()!=4: return {"ok":false,"error":"Missing formal full-region bounds"}
	var bounds := _rect(values)
	if bounds.size.x > MAX_WORLD_WIDTH or bounds.size.y > MAX_WORLD_HEIGHT:
		return {"ok":false,"error":"Regional extent exceeds admitted art projection budget"}
	var solids: Array = []
	var one_way: Array = []
	var keep_clear: Array = []
	for joint: Dictionary in joint_modules: keep_clear.append_array(joint.keep_clear.duplicate(true))
	var dynamic_surfaces: Array = []
	for space: Dictionary in manifest.get("art_layout",{}).get("protected_airspaces",[]): keep_clear.append(space.duplicate(true))
	for node: Dictionary in manifest.nodes:
		var d := PlainsRegionGenerator.definition(node)
		var offset := _point(node.offset)
		for index: int in d.platforms.size():
			var slab: Rect2 = d.platforms[index]
			var world := Rect2(offset+slab.position,slab.size)
			if not world.has_area() or not is_finite(world.position.x) or not is_finite(world.position.y):
				return {"ok":false,"error":"Invalid physical source rectangle"}
			var row := {"id":str(node.id)+"/platform/"+str(index),"source_node":node.id,"platform_index":index,"rect":_rect_data(world),"one_way":index in d.one_way_platform_indices}
			if row.one_way: one_way.append(row)
			else: solids.append(row)
		for index: int in d.danger_bounds.size():
			keep_clear.append({"owner":node.id,"kind":"danger_readability","rect":_rect_data(Rect2(offset+d.danger_bounds[index].position,d.danger_bounds[index].size).grow(22.0))})
		for ferry: ModuleMovingPlatformDefinition in d.ferries:
			var envelope := ferry.envelope()
			dynamic_surfaces.append({"owner":node.id,"kind":"moving_platform","rect":_rect_data(Rect2(offset+envelope.position,envelope.size))})
			keep_clear.append({"owner":node.id,"kind":"moving_platform_envelope","rect":_rect_data(Rect2(offset+envelope.position,envelope.size).grow(18.0))})
		for saw: ModuleSawDefinition in d.saws:
			var envelope := saw.envelope()
			keep_clear.append({"owner":node.id,"kind":"saw_envelope","rect":_rect_data(Rect2(offset+envelope.position,envelope.size).grow(22.0))})
	for index: int in manifest.ground_supports.size():
		solids.append({"id":"ground_support/"+str(index),"source_node":"ground_support","platform_index":index,"rect":manifest.ground_supports[index].duplicate(),"one_way":false})
	var contours := _exposed_edges(solids)
	var geological_bodies := _geological_bodies(contours)
	var expected_area:=0.0
	for edge: Dictionary in contours:
		if edge.face=="right": expected_area+=float(edge.a[0])*(float(edge.b[1])-float(edge.a[1]))
		elif edge.face=="left": expected_area-=float(edge.a[0])*(float(edge.b[1])-float(edge.a[1]))
	var actual_area:=0.0
	for body: Dictionary in geological_bodies:
		body.points=_rounded_inward(body.polygon) if body.holes.is_empty() else body.polygon.duplicate(true)
		body.source_ids=[]
		var packed := PackedVector2Array()
		for value: Array in body.polygon: packed.append(_point(value))
		for source: Dictionary in solids:
			if Geometry2D.is_point_in_polygon(_rect(source.rect).get_center(),packed): body.source_ids.append(source.id)
		actual_area+=absf(_polygon_area(body.polygon))
		for hole: Array in body.holes: actual_area-=absf(_polygon_area(hole))
	if geological_bodies.is_empty() or absf(expected_area-actual_area)>maxf(0.1,expected_area*0.000001):
		return {"ok":false,"error":"Continuous world volume contours do not preserve the complete collision-bearing union"}
	var surfaces: Array = []
	for edge: Dictionary in contours:
		if edge.face=="top" and float(edge.b[0])-float(edge.a[0]) >= MIN_SURFACE_WIDTH:
			surfaces.append({"id":"surface/"+str(surfaces.size()),"a":edge.a.duplicate(),"b":edge.b.duplicate(),"source_node":edge.source_node,"one_way":false})
	for row: Dictionary in one_way:
		var r := _rect(row.rect)
		surfaces.append({"id":row.id,"a":[r.position.x,r.position.y],"b":[r.end.x,r.position.y],"source_node":row.source_node,"one_way":true})
	# Every visual landing is derived from an existing real surface; decorations
	# get separately protected flight/landing windows rather than new collision.
	for surface: Dictionary in surfaces:
		var a := _point(surface.a)
		var b := _point(surface.b)
		keep_clear.append({"owner":surface.id,"kind":"surface_action_window","rect":[a.x,a.y-72.0,b.x-a.x,72.0]})
	var asset_result := _asset_specs()
	if not asset_result.ok: return asset_result
	var places: Array = []
	var landmarks: Array = []
	for area: Dictionary in manifest.areas:
		var p := _point(area.position)
		var identity := str(area.get("identity","windmill_plateau"))
		var place := {"id":area.id,"position":area.position.duplicate(),"identity":identity,"role":area.role,"ports":area.ports.duplicate(true),"composition":{"focus":[p.x,p.y-90.0],"quiet_action_rect":[p.x-240.0,p.y-170.0,480.0,190.0],"view_radius":660.0,"enclosure":"open" if identity=="windmill_plateau" else "sheltered" if identity=="repair_gallery" else "recessed","grounding":"actual_world_support_only"}}
		places.append(place)
		if area.role in ["merchant","prep","boss"] or (int(area.get("row",-1))==0 and int(area.get("col",-1)) in [0,3]):
			var asset_role := "tree" if identity=="windmill_plateau" and area.role!="merchant" else "shelter"
			var spec: Dictionary=asset_result.specs[asset_role]
			var solution:=_landmark_solution(spec,surfaces,p,float(place.composition.view_radius))
			if not solution.ok: return {"ok":false,"error":"No whole-footprint supported "+asset_role+" placement within actual composition view radius for "+str(area.id)}
			var attachment: Dictionary=solution.attachment
			attachment.merge({"id":"landmark/"+str(area.id),"owner":area.id,"identity":identity,"role":area.role,"asset_role":asset_role,"priority":3 if area.role=="boss" else 2,"support_required":true})
			landmarks.append(attachment)
	var belts: Array = [] if language_candidate else _global_belts(manifest,bounds)
	var topology := {"family":manifest.family,"recipe":manifest.topology.recipe,"areas":manifest.areas.duplicate(true),"connections":manifest.connections.duplicate(true),"cycle_count":manifest.connections.size()-manifest.areas.size()+1,"semantic_routes":manifest.topology.semantic_routes.duplicate(true),"signature":topology_signature(manifest)}
	var plan := {"version":JOINT_VERSION if not joint_modules.is_empty() else VERSION,"schema_version":1,"seed":manifest.seed,"manifest_hash":manifest.manifest_hash,"production_pool":false,"layout_source":"formal_full_region","assets_catalog":ASSET_CATALOG,"assets_catalog_sha256":asset_result.catalog_sha256,"bounds":values.duplicate(),"topology":topology,"solids":solids,"one_way_platforms":one_way,"terrain_edges":contours,"geological_bodies":geological_bodies,"surfaces":surfaces,"dynamic_surfaces":dynamic_surfaces,"keep_clear":keep_clear,"places":places,"landmarks":landmarks,"layer_belts":belts,"global_art":{"world_origin":[0.0,0.0],"light_direction":[-0.7,-0.5],"wind_direction":[-1.0,0.0],"material_coordinate_space":"world","camera_reference":"one_continuous_player_camera","background_policy":"global_belts_not_per_place_reset"},"metrics":{"source_solid_rectangles":solids.size(),"exposed_contour_edges":contours.size(),"actual_surfaces":surfaces.size(),"continuous_bodies":geological_bodies.size(),"union_area":actual_area,"places":places.size(),"landmarks":landmarks.size()}}
	if not joint_modules.is_empty():
		plan.joint_modules=joint_modules
		plan.environment_coverage=manifest.get("environment_coverage",{}).duplicate(true)
		plan.environment_world=manifest.get("environment_world",{}).duplicate(true)
		plan.production_method="environment_program_before_platform_projection_with_legacy_remainder"
		plan.rear_walls=[];plan.rear_openings=[];plan.support_relations=[]
		for joint: Dictionary in joint_modules:
			plan.rear_walls.append_array(joint.rear_walls)
			plan.rear_openings.append_array(joint.rear_openings)
			plan.support_relations.append_array(joint.support_relations)
	if language_candidate:
		plan.version=LANGUAGE_VERSION
		plan.art_language_world=manifest.art_language_world.duplicate(true)
		plan.module_art_expressions=[]
		for node: Dictionary in manifest.nodes:
			if node.has("art_expression"):
				plan.module_art_expressions.append({"node_id":node.id,"offset":node.offset.duplicate(),"expression":node.art_expression.duplicate(true)})
		plan.production_method="pre_embedding_art_language_and_finite_world_landforms"
		plan.front_terrain_scope="existing_collision_union_projection_no_new_interactive_geometry"
		plan.art_status="design_debug_not_art_admission"
		plan.global_art.background_policy="source_owned_finite_landforms_and_exterior_air_no_world_floor_fill"
	plan.plan_hash = plan_hash(plan)
	return {"ok":true,"plan":plan}

static func _language_world_error(manifest: Dictionary) -> String:
	# Generated inline units must bind to the independently supplied real node;
	# an expression's own geometry is not proof of its source Definition.
	for node: Dictionary in manifest.get("nodes",[]):
		if not node.has("art_expression"):continue
		var expression: Variant=node.art_expression
		if not expression is Dictionary:return "Invalid module art expression for "+str(node.get("id",""))
		var expression_issues: Array=PlainsArtLanguage.expression_errors(expression,node)
		if not expression_issues.is_empty():return "Module art expression/source rejected for "+str(node.get("id",""))+": "+str(expression_issues)
	var world: Variant=manifest.get("art_language_world",{})
	if not world is Dictionary or not world.get("ok",false):return "Missing pre-embedding bounded art world"
	if world.get("finite_landforms",[]).is_empty() or world.get("open_valleys",[]).is_empty():return "Bounded language requires finite masses and exterior air"
	var ids: Dictionary={}
	for body: Dictionary in world.finite_landforms:
		if str(body.get("id","")).is_empty() or ids.has(str(body.id)):return "Duplicate or absent finite landform identity"
		ids[str(body.id)]=true
		if body.get("collision",true) or body.get("layer","")!="rear_landform":return "Finite painting cannot silently become interactive geometry"
		var polygon:=PackedVector2Array()
		for value: Array in body.get("points",[]):polygon.append(_point(value))
		if polygon.size()<3 or Geometry2D.triangulate_polygon(polygon).is_empty():return "Finite landform source cannot triangulate"
		for valley: Dictionary in world.open_valleys:
			var air:=PackedVector2Array()
			for value: Array in valley.get("points",[]):air.append(_point(value))
			if air.size()<3 or Geometry2D.triangulate_polygon(air).is_empty():return "Exterior air source cannot triangulate"
			if not Geometry2D.intersect_polygons(polygon,air).is_empty():return "Finite mountain intrudes declared exterior air"
	return ""

static func _asset_specs() -> Dictionary:
	if not FileAccess.file_exists(ASSET_CATALOG): return {"ok":false,"error":"Regional attachment source catalog unavailable"}
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(ASSET_CATALOG))
	if not parsed is Dictionary or not parsed.get("objects") is Dictionary: return {"ok":false,"error":"Regional attachment catalog invalid"}
	var specs: Dictionary={}
	for role: String in ["tree","shelter"]:
		var raw: Variant=parsed.objects.get(role)
		if not raw is Dictionary: return {"ok":false,"error":"Actual attachment role unavailable: "+role}
		var spec: Dictionary=raw.duplicate(true)
		var path:=str(spec.get("texture",""))
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=str(spec.get("source_sha256","")): return {"ok":false,"error":"Actual attachment source hash mismatch: "+role}
		var source:=FileAccess.open(path,FileAccess.READ)
		if source==null or source.get_length()<24: return {"ok":false,"error":"Actual attachment PNG source unavailable"}
		source.big_endian=true;source.seek(16)
		var width:=source.get_32();var height:=source.get_32()
		if width<=0 or height<=0 or not spec.get("foundation_px") is Array or spec.foundation_px.is_empty(): return {"ok":false,"error":"Actual attachment dimensions or measured foundation unavailable"}
		spec.source_dimensions=[width,height]
		spec.uniform_scale=float(spec.world_height)/float(height)
		specs[role]=spec
	return {"ok":true,"specs":specs,"catalog_sha256":FileAccess.get_sha256(ASSET_CATALOG)}

static func _landmark_solution(spec: Dictionary, surfaces: Array, desired: Vector2, radius: float) -> Dictionary:
	var scale:=float(spec.uniform_scale)
	var pivot:=_point(spec.pivot_px)
	var min_dx:=INF;var max_dx:=-INF
	var tolerance:=float(spec.get("foot_tolerance_world",3.0))
	for value: Array in spec.foundation_px:
		var delta:=(_point(value)-pivot)*scale
		min_dx=minf(min_dx,delta.x);max_dx=maxf(max_dx,delta.x)
	var best: Dictionary={}
	var nearest:=INF
	for surface: Dictionary in surfaces:
		if bool(surface.get("one_way",true)): continue
		var a:=_point(surface.a);var b:=_point(surface.b)
		if not is_equal_approx(a.y,b.y): continue
		# Strict horizontal containment of EVERY measured foot on ONE real
		# surface. The old 3-world-unit tolerance is vertical only.
		var low:=a.x-min_dx;var high:=b.x-max_dx
		if low>high: continue
		var low_y:=-INF;var high_y:=INF
		for value: Array in spec.foundation_px:
			var dy:=(_point(value)-pivot).y*scale
			low_y=maxf(low_y,a.y-dy-tolerance)
			high_y=minf(high_y,a.y-dy+tolerance)
		if low_y>high_y: continue
		var inset:=minf(0.01,(high-low)*0.25)
		var y_inset:=(high_y-low_y)*0.0001
		var root:=Vector2(clampf(desired.x,low+inset,high-inset),clampf(a.y,low_y+y_inset,high_y-y_inset))
		var distance:=root.distance_squared_to(desired)
		if distance>radius*radius or distance>=nearest: continue
		var feet: Array=[]
		var extent_min:=Vector2(INF,INF);var extent_max:=Vector2(-INF,-INF)
		for value: Array in spec.foundation_px:
			var foot:=root+(_point(value)-pivot)*scale
			feet.append([foot.x,foot.y]);extent_min=extent_min.min(foot);extent_max=extent_max.max(foot)
		nearest=distance
		best={"surface_id":surface.id,"position":[root.x,root.y],"source_texture":spec.texture,"source_sha256":spec.source_sha256,"source_dimensions":spec.source_dimensions.duplicate(),"pivot_px":spec.pivot_px.duplicate(),"uniform_scale":scale,"foundation_world":feet,"foundation_extent_world":[extent_min.x,extent_min.y,extent_max.x,extent_max.y],"feasible_anchor_interval_world":[low,high],"foot_tolerance_world":tolerance,"require_all_feet_supported":bool(spec.get("require_all_feet_supported",false)),"placement_radius_world":radius}
	return {"ok":not best.is_empty(),"attachment":best}

static func landmark_support_errors(landmark: Dictionary, surfaces: Array) -> Array[String]:
	var errors: Array[String]=[]
	var assets:=_asset_specs()
	if not assets.ok: errors.append(str(assets.error));return errors
	var role:=str(landmark.get("asset_role",""))
	if not assets.specs.has(role): errors.append("Unknown actual attachment asset role");return errors
	var spec: Dictionary=assets.specs[role]
	var surface: Dictionary={}
	for row: Dictionary in surfaces:
		if row.id==landmark.get("surface_id",""): surface=row;break
	if surface.is_empty() or bool(surface.get("one_way",true)): errors.append("Actual solid attachment surface unavailable");return errors
	var root:=_point(landmark.position)
	var pivot:=_point(spec.pivot_px)
	var tolerance:=float(spec.get("foot_tolerance_world",3.0))
	for value: Array in spec.foundation_px:
		var foot:=root+(_point(value)-pivot)*float(spec.uniform_scale)
		if foot.x<float(surface.a[0]) or foot.x>float(surface.b[0]) or absf(foot.y-float(surface.a[1]))>tolerance: errors.append("Actual measured attachment foot unsupported")
	return errors

static func plan_hash(plan: Dictionary) -> String:
	var source := plan.duplicate(true)
	source.erase("plan_hash")
	if source.get("version") in [JOINT_VERSION,LANGUAGE_VERSION]: source=RandomStageGenerator.new()._canonical(source)
	return JSON.stringify(source,"",true).sha256_text()

static func validate_recorded(plan: Dictionary, manifest: Dictionary) -> bool:
	if plan.get("version") not in [VERSION,JOINT_VERSION,LANGUAGE_VERSION] or plan.get("manifest_hash")!=manifest.get("manifest_hash") or plan.get("plan_hash")!=plan_hash(plan): return false
	var rebuilt := compile(manifest)
	if not rebuilt.ok: return false
	var a: Dictionary = plan.duplicate(true)
	var b: Dictionary = rebuilt.plan.duplicate(true)
	a.erase("generation");a.erase("plan_hash");b.erase("plan_hash")
	if plan.get("version") in [JOINT_VERSION,LANGUAGE_VERSION]:
		a=RandomStageGenerator.new()._canonical(a);b=RandomStageGenerator.new()._canonical(b)
	return JSON.stringify(a,"",true)==JSON.stringify(b,"",true)

static func topology_signature(manifest: Dictionary) -> String:
	# Actual labelled connectivity and directed lock semantics, not coordinates,
	# content labels, phase, Seed text or object hashes masquerading as topology.
	var edges: Array[String] = []
	for e: Dictionary in manifest.connections:
		var a := str(e.a)
		var b := str(e.b)
		if bool(e.bidirectional) and b<a:
			var previous := a;a=b;b=previous
		edges.append(a+">"+b+":"+str(e.kind)+":"+str(e.condition)+":"+str(e.bidirectional))
	edges.sort()
	return "|".join(edges)

static func _global_belts(manifest: Dictionary, bounds: Rect2) -> Array:
	var columns: Array = manifest.topology.column_positions
	var heights: Array = manifest.topology.terrace_heights
	var result: Array = []
	for index: int in 3:
		var points: Array = []
		points.append([bounds.position.x-1200.0,float(heights[index])+330.0])
		for col: int in columns.size():
			var top := float(heights[index])+290.0
			for area: Dictionary in manifest.areas:
				if int(area.get("col",-1))==col and int(area.get("row",-1))==index: top=float(area.position[1])+170.0
			points.append([float(columns[col]),top])
		points.append([bounds.end.x+1200.0,float(heights[index])+330.0])
		result.append({"id":"regional_belt/"+str(index),"world_polyline":_smooth_belt(points),"parallax":0.18+0.16*index,"depth":index,"role":["remote_weathered_horizon","connected_meadow_backslopes","creek_enclosure"][index],"reset_per_place":false})
	return result

static func _smooth_belt(points: Array) -> Array:
	# One bounded smooth horizon over world columns, never per-place resets.
	var output: Array=[]
	for index: int in points.size()-1:
		var a:=_point(points[maxi(0,index-1)])
		var b:=_point(points[index])
		var c:=_point(points[index+1])
		var d:=_point(points[mini(points.size()-1,index+2)])
		for step: int in 8:
			var t:=float(step)/8.0
			var x:=lerpf(b.x,c.x,t)
			var y:=0.5*((2.0*b.y)+(-a.y+c.y)*t+(2.0*a.y-5.0*b.y+4.0*c.y-d.y)*t*t+(-a.y+3.0*b.y-3.0*c.y+d.y)*t*t*t)
			# Keep horizon within source-neighbour envelope to avoid overshooting
			# a deep well and producing an unplanned opaque background wall.
			y=clampf(y,minf(b.y,c.y)-28.0,maxf(b.y,c.y)+28.0)
			output.append([x,y])
	output.append(points[-1].duplicate())
	return output

static func _exposed_edges(solids: Array) -> Array:
	# Exact union boundary: subtract every occluding rectangle from each face.
	# Adjacent slab/support seams disappear; holes and traversable voids remain.
	# No epsilon-expanded physics, fading shoulder strips or new supports.
	var result: Array = []
	var seen: Dictionary = {}
	for row: Dictionary in solids:
		var r := _rect(row.rect)
		for face: String in ["top","right","bottom","left"]:
			var horizontal := face in ["top","bottom"]
			var fixed := r.position.y if face=="top" else r.end.y if face=="bottom" else r.position.x if face=="left" else r.end.x
			var intervals: Array = [[r.position.x,r.end.x] if horizontal else [r.position.y,r.end.y]]
			for other: Dictionary in solids:
				if other.id==row.id: continue
				var o := _rect(other.rect)
				var covers := (o.position.y<fixed and o.end.y>=fixed) if face=="top" else (o.position.y<=fixed and o.end.y>fixed) if face=="bottom" else (o.position.x<fixed and o.end.x>=fixed) if face=="left" else (o.position.x<=fixed and o.end.x>fixed)
				if not covers: continue
				intervals = _subtract(intervals,o.position.x if horizontal else o.position.y,o.end.x if horizontal else o.end.y)
				if intervals.is_empty(): break
			for span: Array in intervals:
				if float(span[1])-float(span[0])<0.00001: continue
				var a: Array = [span[0],fixed] if horizontal else [fixed,span[0]]
				var b: Array = [span[1],fixed] if horizontal else [fixed,span[1]]
				var key := str(a)+">"+str(b)+":"+face
				if seen.has(key): continue
				seen[key]=true
				result.append({"a":a,"b":b,"face":face,"source_node":row.source_node})
	return _coalesce_edges(result)


static func _geological_bodies(edges: Array) -> Array:
	# Trace the exact union's oriented contours into coherent whole volumes.
	# Real underpasses become holes, never a filled rectangle behind a route.
	var directed: Array = []
	var starts: Dictionary = {}
	for edge: Dictionary in edges:
		var a: Array = edge.a.duplicate()
		var b: Array = edge.b.duplicate()
		if edge.face in ["bottom","left"]:
			var previous := a;a=b;b=previous
		var index := directed.size()
		directed.append({"a":a,"b":b})
		var key := _point_key(a)
		if not starts.has(key): starts[key]=[]
		starts[key].append(index)
	var visited: Dictionary = {}
	var loops: Array = []
	for first: int in directed.size():
		if visited.has(first): continue
		var polygon: Array = []
		var current := first
		var start_key := _point_key(directed[first].a)
		var closed := false
		for unused: int in directed.size()+1:
			if visited.has(current): break
			visited[current]=true
			var edge: Dictionary = directed[current]
			polygon.append(edge.a.duplicate())
			var next_key := _point_key(edge.b)
			if next_key==start_key:
				closed=true;break
			var next_index := -1
			var turn := INF
			var incoming := _point(edge.b)-_point(edge.a)
			for candidate: int in starts.get(next_key,[]):
				if visited.has(candidate): continue
				var outgoing := _point(directed[candidate].b)-_point(directed[candidate].a)
				var angle := fposmod(atan2(incoming.cross(outgoing),incoming.dot(outgoing)),TAU)
				if angle<turn: turn=angle;next_index=candidate
			if next_index<0: break
			current=next_index
		if not closed or polygon.size()<4: continue
		var signed_area:=0.0
		for index: int in polygon.size():
			var a:=_point(polygon[index]);var b:=_point(polygon[(index+1)%polygon.size()])
			signed_area+=a.cross(b)
		loops.append({"polygon":polygon,"hole":signed_area<0.0})
	var bodies: Array = []
	for loop: Dictionary in loops:
		if loop.hole: continue
		var bounds := Rect2(_point(loop.polygon[0]),Vector2.ZERO)
		for value: Array in loop.polygon: bounds=bounds.expand(_point(value))
		var holes: Array = []
		var packed := PackedVector2Array()
		for value: Array in loop.polygon: packed.append(_point(value))
		for other: Dictionary in loops:
			if other.hole and Geometry2D.is_point_in_polygon(_point(other.polygon[0]),packed): holes.append(other.polygon)
		bodies.append({"id":"geological_body/"+str(bodies.size()),"polygon":loop.polygon,"holes":holes,"bounds":_rect_data(bounds),"geometry_source":"exact_union_of_formal_solid_platforms_and_collision_bearing_supports","surface_policy":"actual_exposed_top_only","visual_rounding_budget_world":12.0,"rounding_policy":"inward_below_standing_surface_only"})
	return bodies

static func _rounded_inward(polygon: Array) -> Array:
	var result: Array = []
	for index: int in polygon.size():
		var previous := _point(polygon[(index+polygon.size()-1)%polygon.size()])
		var vertex := _point(polygon[index])
		var following := _point(polygon[(index+1)%polygon.size()])
		var incoming := vertex-previous
		var outgoing := following-vertex
		# Keep every real standing plane and its end exactly aligned. Only
		# convex lower corners recede inward into existing collision volume.
		var standing := (absf(incoming.y)<0.00001 and incoming.x>0.0) or (absf(outgoing.y)<0.00001 and outgoing.x>0.0)
		if standing or incoming.cross(outgoing)<=0.0:
			result.append([vertex.x,vertex.y]);continue
		var radius:=minf(12.0,minf(incoming.length(),outgoing.length())*0.25)
		var a:=vertex-incoming.normalized()*radius
		var b:=vertex+outgoing.normalized()*radius
		var midpoint:=a*0.25+vertex*0.5+b*0.25
		result.append([a.x,a.y]);result.append([midpoint.x,midpoint.y]);result.append([b.x,b.y])
	return result

static func _polygon_area(polygon: Array) -> float:
	var area:=0.0
	for index: int in polygon.size(): area+=_point(polygon[index]).cross(_point(polygon[(index+1)%polygon.size()]))
	return area*0.5

static func _point_key(value: Array) -> String:
	return "%.5f,%.5f" % [float(value[0]),float(value[1])]

static func _coalesce_edges(edges: Array) -> Array:
	# Equal-height overlaps are still one surface, not independently drawn caps.
	var groups: Dictionary = {}
	for edge: Dictionary in edges:
		var horizontal: bool = edge.face in ["top","bottom"]
		var fixed := float(edge.a[1] if horizontal else edge.a[0])
		var key := str(edge.face)+":"+str(fixed)
		if not groups.has(key): groups[key]=[]
		groups[key].append(edge)
	var output: Array = []
	for key: String in groups:
		var group: Array = groups[key]
		var horizontal: bool = group[0].face in ["top","bottom"]
		group.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.a[0] if horizontal else a.a[1]) < float(b.a[0] if horizontal else b.a[1]))
		var merged: Array = []
		for edge: Dictionary in group:
			if not merged.is_empty():
				var previous: Dictionary = merged[-1]
				var axis := 0 if horizontal else 1
				if float(edge.a[axis])<=float(previous.b[axis])+0.00001:
					previous.b[axis]=maxf(float(previous.b[axis]),float(edge.b[axis]))
					continue
			merged.append(edge.duplicate(true))
		output.append_array(merged)
	return output

static func _subtract(intervals: Array, low: float, high: float) -> Array:
	var output: Array = []
	for span: Array in intervals:
		var a := float(span[0]);var b := float(span[1])
		if high<=a or low>=b: output.append(span);continue
		if low>a: output.append([a,minf(low,b)])
		if high<b: output.append([maxf(high,a),b])
	return output

static func _rect(value: Array) -> Rect2: return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))
static func _point(value: Array) -> Vector2: return Vector2(float(value[0]),float(value[1]))
static func _rect_data(value: Rect2) -> Array: return [value.position.x,value.position.y,value.size.x,value.size.y]
