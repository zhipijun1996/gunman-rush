class_name PlainsJointRecoilPlan
extends RefCounted
## Environment construction precedes its platform projection. A ridge, its
## fissure and the creek gallery share physical and painted world coordinates.
const VERSION := "plains-joint-recoil-v5-landform-first"
const MODULE_ID := "plains_recoil_span"
const BANK_DEPTH := 260.0
const RENDER_METHOD := "landform_world_material_v1"

static func program_for_recipe(recipe: Dictionary, identity: String, edge_id: String, seed_value: String) -> Dictionary:
	var stream:=RunRandomStream.new(seed_value,"region_landform",edge_id,VERSION)
	var fissure:=str(recipe.get("id",""))=="recoil_crossing"
	return {"version":VERSION,"id":edge_id+"/environment","recipe_id":recipe.get("id",""),"actions":recipe.get("actions",""),"identity":identity,"kind":"meadow_ridge_fissure" if fissure else "rooted_connection","implemented":fissure,"source_order":"actions_and_environment_before_span_embedding_and_platform_definition","construction":[{"kind":"meadow_ridge_fissure","material":"grass_over_continuous_bedrock","support":"rear_substrate"},{"kind":"creek_gallery","purpose":"lower_phase_route_without_new_rescue_floor"},{"kind":"rooted_connection","interfaces":"solid_cross_section_and_gallery_opening"}] if fissure else [{"kind":"rooted_connection","implementation":"legacy_remainder_not_converted"}],"ridge_id":"plains/main_bedrock","standing_y":600.0,"launch_length":300.0,"gap_width":260.0,"landing_length":240.0,"projected_cap_depth":24.0,"module_width":800.0,"contour_variant":stream.next_int(3),"material_space":{"space":"world","origin":[0.0,0.0],"pixels_per_world_unit":2.0},"composition":{"sky_fissure":"open_above_recoil","creek":"recessed_arched_gallery","focus":"opposite_sunlit_meadow_lip","quiet_landing":true}}

static func definition_from_program(program: Dictionary) -> PlatformingModuleDefinition:
	var result:=RandomStageGenerator.new().definition_for(MODULE_ID,false,false).duplicate(true) as PlatformingModuleDefinition
	result.platforms.clear()
	var y:=float(program.standing_y)
	var launch:=float(program.launch_length)
	var receiving:=launch+float(program.gap_width)
	result.platforms.append(Rect2(0.0,y,launch,float(program.projected_cap_depth)))
	result.platforms.append(Rect2(receiving,y,float(program.landing_length),float(program.projected_cap_depth)))
	result.definition_version=5
	return result

static func definition_from_spec(spec: Dictionary) -> PlatformingModuleDefinition:
	return definition_from_program(spec.environment_program)

static func source_spec(context: Dictionary = {}) -> Dictionary:
	var program: Dictionary=context.get("environment_program",{}).duplicate(true)
	if program.is_empty():return {}
	var y:=float(program.standing_y)
	var launch:=float(program.launch_length)
	var receive:=launch+float(program.gap_width)
	var end:=receive+float(context.receiving_width)
	# The gallery and front ridge thickness are authored together. Lower-route
	# clearance bounds the arch; no source PNG or old slab chooses this contour.
	var depth:=minf(float(context.available_root_depth)-10.0,245.0+float(program.contour_variant)*16.0)
	depth=maxf(110.0,depth)
	var left: Array=[[0.0,y],[launch,y],[launch,y+30.0],[launch-9.0,y+61.0],[launch-31.0,y+91.0],[launch-59.0,y+depth*0.62],[launch-97.0,y+depth*0.78],[launch-151.0,y+depth*0.91],[0.0,y+depth]]
	var width:=end-receive
	var right: Array=[[receive,y],[end,y],[end,y+depth*0.94],[end-width*0.18,y+depth],[end-width*0.39,y+depth*0.91],[end-width*0.62,y+depth*0.78],[receive+width*0.23,y+depth*0.58],[receive+39.0,y+95.0],[receive+13.0,y+56.0],[receive,y+29.0]]
	var fronts: Array=[]
	for row: Dictionary in [{"id":"ridge_left","source_role":"meadow_ridge_left","points":left,"surface":[[0.0,y],[launch,y]]},{"id":"ridge_right","source_role":"meadow_ridge_right","points":right,"surface":[[receive,y],[end,y]]}]:
		var faces: Array=[]
		for index: int in row.points.size():
			var kind:="standing" if index==0 else "outer_connection" if (row.id=="ridge_left" and index==row.points.size()-1) or (row.id=="ridge_right" and index==1) else "shoulder" if index in [1,2,3,row.points.size()-1] else "cave_roof"
			faces.append({"a":row.points[index].duplicate(),"b":row.points[(index+1)%row.points.size()].duplicate(),"kind":kind,"volume_id":row.id})
		fronts.append({"id":row.id,"volume_id":row.id,"source_role":row.source_role,"points":row.points,"local_points":row.points.duplicate(true),"local_visual_points":row.points.duplicate(true),"surface_profile":row.surface,"exposed_faces":faces,"geometry_source":"environment_program","material_space":program.material_space.duplicate(true),"material_coordinates":program.material_space.duplicate(true),"neighbor_interfaces":[{"id":row.id+"/outer","standing_point":[0.0 if row.id=="ridge_left" else end,y],"root_point":[0.0 if row.id=="ridge_left" else end,y+depth],"direction":[-1.0 if row.id=="ridge_left" else 1.0,0.0],"kind":"continuous_bedrock_section"}]})
	var lower_y:=float(context.get("lower_standing_local_y",y+float(context.available_root_depth)+float(context.lower_action_headroom)))
	var bottom:=float(context.get("world_base_local_y",lower_y+550.0))
	var rear_polygon: Array=[[-360.0,y-5.0],[end+360.0,y-5.0],[end+360.0,bottom],[-360.0,bottom]]
	var roof:=y+depth*0.86
	var creek: Array=[[-180.0,roof+40.0],[80.0,roof],[launch,roof+38.0],[receive,roof+24.0],[end-100.0,roof],[end+180.0,roof+55.0],[end+180.0,lower_y+140.0],[-180.0,lower_y+140.0]]
	var sky: Array=[[launch-4.0,y-40.0],[receive+4.0,y-40.0],[receive+22.0,roof+75.0],[launch-22.0,roof+75.0]]
	var window_center:=receive+width*0.57
	var daylight: Array=[[window_center-96.0,lower_y+70.0],[window_center-100.0,lower_y-130.0],[window_center-76.0,lower_y-210.0],[window_center-24.0,lower_y-248.0],[window_center+34.0,lower_y-244.0],[window_center+86.0,lower_y-205.0],[window_center+108.0,lower_y-122.0],[window_center+106.0,lower_y+70.0]]
	var openings: Array=[{"id":"sky_fissure","kind":"sky_fissure","points":sky,"collision":false},{"id":"creek_daylight_arch","kind":"daylight_arch","points":daylight,"collision":false}]
	# Front walkable air is NOT a hole through the rear substrate. Split the
	# substrate at the daylight window before clipping, yielding simple pieces
	# rather than misinterpreting a clockwise hole loop as another solid.
	var pieces: Array[PackedVector2Array]=[_packed([rear_polygon[0],[window_center,y-5.0],[window_center,bottom],rear_polygon[3]]),_packed([[window_center,y-5.0],rear_polygon[1],rear_polygon[2],[window_center,bottom]])]
	for opening: Dictionary in openings:
		var next: Array[PackedVector2Array]=[]
		for piece: PackedVector2Array in pieces:next.append_array(Geometry2D.clip_polygons(piece,_packed(opening.points)))
		pieces=next
	var walls: Array=[]
	for piece: PackedVector2Array in pieces:
		var root_contact:=0.0
		for index: int in piece.size():
			var a:=piece[index];var b:=piece[(index+1)%piece.size()]
			if absf(a.y-bottom)<0.01 and absf(b.y-bottom)<0.01:root_contact+=absf(b.x-a.x)
		walls.append({"id":"rear_substrate/"+str(walls.size()),"volume_id":"plains/main_bedrock","points":_arrays(piece),"root_y":bottom,"root_contact_length":root_contact,"anchored_to_root":root_contact>0.0,"collision":false,"layer":"rear_substrate","material_space":program.material_space.duplicate(true),"geometry_source":"environment_program_ridge_minus_gallery_and_fissure"})
	var supports: Array=[]
	for front: Dictionary in fronts:
		var overlap_area:=0.0
		var overlaps: Array=[]
		for wall: Dictionary in walls:
			if not wall.anchored_to_root:continue
			for polygon: PackedVector2Array in Geometry2D.intersect_polygons(_packed(front.points),_packed(wall.points)):
				var area:=absf(_area(polygon))
				overlap_area+=area
				overlaps.append(_arrays(polygon))
		front.support_id="plains/main_bedrock"
		supports.append({"from_volume":front.volume_id,"to_volume":"plains/main_bedrock","kind":"rear_bedrock_overlap","overlap_polygons":overlaps,"overlap_area":overlap_area,"valid":overlap_area>100.0,"rear_roots_at_world_base":overlap_area>100.0})
	return {"version":VERSION,"module_id":MODULE_ID,"environment_program":program,"landing_planes":[{"id":"departure","bank":"ridge_left","a":[0.0,y],"b":[launch,y],"minimum_solid_depth":program.projected_cap_depth},{"id":"receiving","bank":"ridge_right","a":[receive,y],"b":[receive+float(program.landing_length),y],"minimum_solid_depth":program.projected_cap_depth}],"ports":{"entry":[20.0,y-18.0],"exit":[780.0,y-18.0]},"protected_action_gap":{"rect":[launch,0.0,float(program.gap_width),720.0],"minimum_clear_width":120.0,"actual_clear_width":program.gap_width},"front_volumes":fronts,"front_voids":[{"id":"creek_gallery","kind":"creek_gallery","points":creek,"collision":false,"meaning":"foreground_traversal_air_with_continuous_rear_bedrock"}],"rear_walls":walls,"rear_openings":openings,"support_relations":supports,"ownership_rects":[[0.0,y,launch,depth],[receive,y,width,depth]],"material_coordinates":program.material_space.duplicate(true)}

static func build_local(context: Dictionary = {}) -> Dictionary:
	if context.is_empty() or context.get("environment_program",{}).is_empty():return {"ok":false,"error":"Environment program must exist before the platform projection"}
	var spec:=source_spec(context)
	var platforms: Array=[]
	for plane: Dictionary in spec.landing_planes:platforms.append([plane.a[0],plane.a[1],float(plane.b[0])-float(plane.a[0]),plane.minimum_solid_depth])
	return {"version":VERSION,"module_id":MODULE_ID,"render_method":RENDER_METHOD,"environment_program":spec.environment_program,"region_context":context.duplicate(true),"semantic_source":spec,"terrain_bodies":spec.front_volumes,"front_voids":spec.front_voids,"rear_walls":spec.rear_walls,"rear_openings":spec.rear_openings,"support_relations":spec.support_relations,"cutout_rects":spec.ownership_rects,"keep_clear":[{"kind":"protected_joint_recoil_action_gap","rect":spec.protected_action_gap.rect}],"platforms":platforms}

static func instantiate(node: Dictionary) -> Dictionary:
	var local:=build_local(node.joint_recoil.get("region_context",{}))
	var offset:=_point(node.offset)
	var bodies: Array=[]
	for raw: Dictionary in local.terrain_bodies:
		var body:=raw.duplicate(true)
		body.local_points=raw.points.duplicate(true)
		body.points=_translate_points(raw.points,offset)
		body.visual_points=body.points.duplicate(true)
		body.surface_profile=_translate_points(raw.surface_profile,offset)
		for face: Dictionary in body.exposed_faces:
			face.a=_translate_point(face.a,offset);face.b=_translate_point(face.b,offset)
		for seam: Dictionary in body.neighbor_interfaces:
			seam.standing_point=_translate_point(seam.standing_point,offset);seam.root_point=_translate_point(seam.root_point,offset)
		body.id=str(node.id)+"/"+str(raw.id)
		bodies.append(body)
	var voids: Array=[]
	for raw: Dictionary in local.front_voids:
		var air:=raw.duplicate(true);air.points=_translate_points(raw.points,offset);voids.append(air)
	var walls: Array=[]
	for raw: Dictionary in local.rear_walls:
		var wall:=raw.duplicate(true);wall.local_points=raw.points.duplicate(true);wall.points=_translate_points(raw.points,offset);wall.root_y=float(raw.root_y)+offset.y;walls.append(wall)
	var openings: Array=[]
	for raw: Dictionary in local.rear_openings:
		var opening:=raw.duplicate(true);opening.local_points=raw.points.duplicate(true);opening.points=_translate_points(raw.points,offset);openings.append(opening)
	var supports: Array=[]
	for raw: Dictionary in local.support_relations:
		var relation:=raw.duplicate(true);relation.overlap_polygons=[]
		for polygon: Array in raw.overlap_polygons:relation.overlap_polygons.append(_translate_points(polygon,offset))
		supports.append(relation)
	var cutouts: Array=[]
	for r: Array in local.cutout_rects:cutouts.append([float(r[0])+offset.x,float(r[1])+offset.y,r[2],r[3]])
	var clear: Array=[]
	for row: Dictionary in local.keep_clear:
		var r: Array=row.rect
		clear.append({"kind":row.kind,"owner":node.id,"rect":[float(r[0])+offset.x,float(r[1])+offset.y,r[2],r[3]]})
	return {"version":VERSION,"render_method":RENDER_METHOD,"node_id":node.id,"module_id":MODULE_ID,"offset":node.offset.duplicate(),"region_context":local.region_context,"environment_program":local.environment_program,"semantic_source":local.semantic_source,"terrain_bodies":bodies,"front_voids":voids,"rear_walls":walls,"rear_openings":openings,"support_relations":supports,"cutout_rects":cutouts,"keep_clear":clear+local.region_context.get("protected_actual_airspace",[]).duplicate(true),"derived_platforms":local.platforms,"physics_owner":"actual_environment_program_polygons","production_pool":false}

static func _packed(values: Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for value: Array in values:result.append(_point(value))
	return result
static func _arrays(values: PackedVector2Array) -> Array:
	var result: Array=[]
	for value: Vector2 in values:result.append([value.x,value.y])
	return result
static func _area(values: PackedVector2Array) -> float:
	var area:=0.0
	for index: int in values.size():area+=values[index].cross(values[(index+1)%values.size()])
	return area*0.5

static func context_for_region(manifest: Dictionary, node: Dictionary) -> Dictionary:
	var offset:=_point(node.offset)
	var standing:=offset.y+600.0
	var seam:=offset.x+800.0
	var neighbor: Dictionary={}
	var neighbor_index:=-1
	for other: Dictionary in manifest.nodes:
		if other.id==node.id or str(other.module_id)!="region_connection": continue
		var d:=PlainsRegionGenerator.definition(other)
		var origin:=_point(other.offset)
		for index: int in d.platforms.size():
			if index in d.one_way_platform_indices: continue
			var slab:=Rect2(origin+d.platforms[index].position,d.platforms[index].size)
			if absf(slab.position.x-seam)<0.00001 and absf(slab.position.y-standing)<0.00001:
				neighbor=other;neighbor_index=index;break
		if not neighbor.is_empty(): break
	if neighbor.is_empty(): return {"ok":false,"error":"Joint receiving source requires an actual solid neighboring join"}
	var definition:=PlainsRegionGenerator.definition(neighbor)
	var original_join: Rect2=definition.platforms[neighbor_index]
	var width:=240.0+original_join.size.x
	if width<300.0 or width>900.0:return {"ok":false,"error":"Environment receiving span outside its bounded ridge construction range"}
	var left:=offset.x+560.0
	var right:=left+width
	var lower_ceiling:=float(manifest.world_bounds[1])+float(manifest.world_bounds[3])
	var protected: Array=[]
	var capability:=MovementCapabilityEnvelope.snapshot(PlayerTuning.load_default())
	if capability.is_empty(): return {"ok":false,"error":"Cannot measure original lower-route movement capability"}
	var headroom:=ceilf(float(capability.held_jump_height))+36.0+12.0
	for other: Dictionary in manifest.nodes:
		if other.id in [node.id,neighbor.id]: continue
		var d:=PlainsRegionGenerator.definition(other)
		var origin:=_point(other.offset)
		# Shaft AABBs contain substantial unused rock-side margins. Their real
		# platforms, ferries, hazards and traced player paths are protected below,
		# rather than freezing those margins as an inviolable rectangular void.
		for slab: Rect2 in d.platforms:
			var floor:=Rect2(origin+slab.position,slab.size)
			if floor.position.y>standing+100.0 and floor.position.x<right and floor.end.x>left:
				lower_ceiling=minf(lower_ceiling,floor.position.y-headroom)
				var action:=Rect2(Vector2(floor.position.x,floor.position.y-headroom),Vector2(floor.size.x,headroom))
				protected.append({"kind":"actual_lower_standing_full_held_jump_clearance","owner":other.id,"rect":[action.position.x,action.position.y,action.size.x,action.size.y]})
		for ferry: ModuleMovingPlatformDefinition in d.ferries:
			var envelope:=ferry.envelope()
			var rect:=Rect2(origin+envelope.position,envelope.size).grow(24.0)
			protected.append({"kind":"actual_ferry_envelope","owner":other.id,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
		for saw: ModuleSawDefinition in d.saws:
			var envelope:=saw.envelope()
			var rect:=Rect2(origin+envelope.position,envelope.size).grow(24.0)
			protected.append({"kind":"actual_saw_envelope","owner":other.id,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	for edge: Dictionary in manifest.connections:
		if str(edge.kind) not in ["stairs","drop"]: continue
		var path: Array=edge.get("path",[])
		for index: int in maxi(0,path.size()-1):
			var a:=_point(path[index]);var b:=_point(path[index+1])
			var rect:=Rect2(a.min(b)-Vector2(24.0,72.0),(a-b).abs()+Vector2(48.0,108.0))
			protected.append({"kind":"actual_shaft_player_path_clearance","owner":edge.id,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	var available:=lower_ceiling-standing
	var variant:="deep_root" if available>=420.0 else "shallow_root" if available>=230.0 else ""
	if variant.is_empty(): return {"ok":false,"error":"No complete receiving source fits the actual lower-route clearance"}
	return {"ok":true,"context":{"neighbor_join_node":neighbor.id,"neighbor_join_platform_index":neighbor_index,"owned_slabs":[{"node_id":node.id,"platform_index":0},{"node_id":node.id,"platform_index":1},{"node_id":neighbor.id,"platform_index":neighbor_index}],"receiving_width":width,"available_root_depth":available,"lower_action_headroom":headroom,"movement_capability":capability,"environment_program":node.get("environment_program",{}).duplicate(true),"lower_standing_local_y":lower_ceiling+headroom-offset.y,"world_base_local_y":float(manifest.world_bounds[1])+float(manifest.world_bounds[3])-offset.y,"root_depth":minf(available-10.0,277.0),"variant":variant,"protected_actual_airspace":protected,"lower_clearance_policy":"actual lower standing surfaces minus measured full held-jump height, 36px actor and 12px margin; actual dynamics/path and input trace independently verified"}}

static func clip_supports(supports: Array, cutouts: Array) -> Array:
	var output: Array=[]
	for raw: Array in supports:
		var pieces: Array[Rect2]=[Rect2(raw[0],raw[1],raw[2],raw[3])]
		for cut: Array in cutouts:
			var obstacle:=Rect2(cut[0],cut[1],cut[2],cut[3])
			var next: Array[Rect2]=[]
			for source: Rect2 in pieces:
				if not source.intersects(obstacle): next.append(source);continue
				var overlap:=source.intersection(obstacle)
				var candidates: Array[Rect2]=[Rect2(source.position,Vector2(overlap.position.x-source.position.x,source.size.y)),Rect2(Vector2(overlap.end.x,source.position.y),Vector2(source.end.x-overlap.end.x,source.size.y)),Rect2(Vector2(overlap.position.x,source.position.y),Vector2(overlap.size.x,overlap.position.y-source.position.y)),Rect2(Vector2(overlap.position.x,overlap.end.y),Vector2(overlap.size.x,source.end.y-overlap.end.y))]
				# Exact clipping keeps even narrow outside ownership strips. The
				# regional mass producer's 12px fragment pruning must not apply.
				for piece: Rect2 in candidates:
					if piece.has_area(): next.append(piece)
			pieces=next
		for piece: Rect2 in pieces: output.append([piece.position.x,piece.position.y,piece.size.x,piece.size.y])
	return output

static func errors(recorded: Dictionary) -> Array[String]:
	var failures: Array[String]=[]
	var expected:=build_local(recorded.get("region_context",{}))
	if JSON.stringify(RandomStageGenerator.new()._canonical(recorded),"",true)!=JSON.stringify(RandomStageGenerator.new()._canonical(expected),"",true): failures.append("Joint semantic source, geometry or interfaces differ from the admitted bounded source")
	return failures

static func _point(value: Array) -> Vector2:return Vector2(float(value[0]),float(value[1]))
static func _translate_point(value: Array, offset: Vector2)->Array:
	# Physics and the actual ArrayMesh both store Vector2 float32 coordinates.
	# Seal the world source through that SAME operation; do not compare a
	# float64 JSON sum against an engine float32 transform with a tolerance.
	var world:=_point(value)+offset
	return [world.x,world.y]
static func _translate_points(values: Array, offset: Vector2)->Array:
	var output: Array=[]
	for value: Array in values: output.append(_translate_point(value,offset))
	return output
