class_name PlainsJointRecoilPlan
extends RefCounted
## Environment construction precedes its platform projection. A ridge, its
## fissure and the creek gallery share physical and painted world coordinates.
const VERSION := "plains-joint-recoil-v6-ridge-and-creek-child"
const MODULE_ID := "plains_recoil_span"
const BANK_DEPTH := 260.0
const RENDER_METHOD := "landform_world_material_v1"

static func program_for_recipe(recipe: Dictionary, identity: String, edge_id: String, seed_value: String) -> Dictionary:
	var stream:=RunRandomStream.new(seed_value,"region_landform",edge_id,VERSION)
	var fissure:=str(recipe.get("id",""))=="recoil_crossing"
	return {"version":VERSION,"id":edge_id+"/environment","module_id":MODULE_ID,"recipe_id":recipe.get("id",""),"actions":recipe.get("actions",""),"identity":identity,"kind":"meadow_ridge_fissure" if fissure else "rooted_connection","implemented":fissure,"asset_grammar":_vault_grammar() if fissure else {},"source_order":"actions_and_environment_before_span_embedding_and_platform_definition","construction":[{"kind":"meadow_ridge_fissure","material":"grass_over_continuous_bedrock","support":"rear_substrate"},{"kind":"creek_gallery","purpose":"lower_phase_route_without_new_rescue_floor"},{"kind":"rooted_connection","interfaces":"solid_cross_section_and_gallery_opening"}] if fissure else [{"kind":"rooted_connection","implementation":"legacy_remainder_not_converted"}],"ridge_id":"plains/main_bedrock","standing_y":600.0,"launch_length":300.0,"gap_width":260.0,"landing_length":240.0,"projected_cap_depth":24.0,"module_width":800.0,"contour_variant":stream.next_int(3),"material_space":{"space":"world","origin":[0.0,0.0],"pixels_per_world_unit":2.0},"composition":{"sky_fissure":"open_above_recoil","creek":"recessed_arched_gallery","focus":"opposite_sunlit_meadow_lip","quiet_landing":true,"vault_anchor_bias":0.62}}

static func _vault_grammar() -> Dictionary:
	var path:="res://resources/visual_development/p1_landform_assets.json"
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Dictionary:return {"ok":false,"error":"Actual vault family catalog unavailable"}
	var grammar: Dictionary=raw.get("structural_assets",{}).get("rock_vault",{}).duplicate(true)
	if grammar.is_empty() or FileAccess.get_sha256(str(grammar.get("texture","")))!=str(grammar.get("source_sha256","")):return {"ok":false,"error":"Registered vault source unavailable or changed"}
	grammar.family_kind="open_bottom_rock_vault"
	var max_y:=-INF
	for point: Array in grammar.negative_contour_px:max_y=maxf(max_y,float(point[1]))
	var mouth: Array=[]
	for index: int in grammar.negative_contour_px.size():
		if float(grammar.negative_contour_px[index][1])==max_y:mouth.append(index)
	if mouth.size()!=2:return {"ok":false,"error":"Open-bottom vault requires two registered lower mouth interfaces"}
	grammar.open_bottom_port_px={"left_index":mouth[0],"right_index":mouth[1],"left":grammar.negative_contour_px[int(mouth[0])].duplicate(),"right":grammar.negative_contour_px[int(mouth[1])].duplicate(),"direction":[0.0,1.0],"meaning":"open downward exterior interface, not a painted sill"}
	grammar.ok=true
	grammar.catalog_path=path
	grammar.catalog_sha256=FileAccess.get_sha256(path)
	grammar.expression="fixed uniform painted crown/piers and registered negative core; geometry must respect these interfaces"
	return grammar

static func bind_vertical_programs(manifest: Dictionary) -> void:
	manifest.environment_world={"id":"plains/main_bedrock","kind":"continuous_regional_rear_substrate","physics":false,"surface_horizon_rule":"main_meadow_standing_plus_36_world_units","surface_horizon_world_y":54.0,"coverage":"entire_formal_region_bounds_plus_normal_camera_overdraw","camera_overdraw_world":1024.0,"openings":"only_explicit_sky_fissures_and_daylight_outlets","layer_relation":"distant_rear_bedrock_behind_independent_front_traversal_air","material_space":{"space":"world","origin":[0.0,0.0],"pixels_per_world_unit":2.0}}
	# Pair action/environment sentences by topology BEFORE any spans, positions
	# or module Definitions. IDs and Seed-specific coordinates do not select it.
	for upper: Dictionary in manifest.connections:
		if upper.get("design_recipe",{}).get("id","")!="recoil_crossing":continue
		var upper_area: Dictionary={}
		for area: Dictionary in manifest.areas:
			if area.id==upper.a:upper_area=area;break
		for lower: Dictionary in manifest.connections:
			if lower.get("design_recipe",{}).get("id","")!="controlled_ferry":continue
			var lower_area: Dictionary={}
			for area: Dictionary in manifest.areas:
				if area.id==lower.a:lower_area=area;break
			if lower_area.is_empty() or int(lower_area.col)!=int(upper_area.col) or int(lower_area.row)!=int(upper_area.row)+1:continue
			manifest.environment_target_edge=upper.id
			upper.environment_program.regional_substrate_id=manifest.environment_world.id
			upper.environment_program.children=[{"edge_id":lower.id,"kind":"creek_gallery","relation":"below_same_ridge","topology_delta":[0,1]}]
			lower.environment_program={"version":VERSION,"id":lower.id+"/creek_environment","parent_program_id":upper.environment_program.id,"module_id":"plains_bell_ferry_control","recipe_id":"controlled_ferry","actions":lower.design_recipe.actions,"kind":"creek_gallery","implemented":true,"ridge_id":upper.environment_program.ridge_id,"standing_y":300.0,"launch_length":200.0,"gap_width":400.0,"landing_length":200.0,"projected_cap_depth":32.0,"module_width":800.0,"material_space":upper.environment_program.material_space.duplicate(true),"construction":[{"kind":"grounded_creek_banks","no_gap_floor":true},{"kind":"existing_controlled_ferry","preserve_mechanism":true}],"source_order":"paired_topology_environment_before_span_and_definition"}
			return

static func definition_from_program(program: Dictionary) -> PlatformingModuleDefinition:
	var result:=RandomStageGenerator.new().definition_for(str(program.get("module_id",MODULE_ID)),false,false).duplicate(true) as PlatformingModuleDefinition
	result.platforms.clear()
	var y:=float(program.standing_y)
	var launch:=float(program.launch_length)
	var receiving:=launch+float(program.gap_width)
	result.platforms.append(Rect2(0.0,y,launch,float(program.projected_cap_depth)))
	result.platforms.append(Rect2(receiving,y,float(program.landing_length),float(program.projected_cap_depth)))
	result.definition_version=6
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
	fronts.append_array(_creek_fronts(context,program,bottom))
	var regional: Dictionary=context.regional_substrate
	var rear_left:=float(regional.bounds_local[0])
	var rear_right:=rear_left+float(regional.bounds_local[2])
	var rear_top:=float(regional.surface_horizon_local_y)
	var rear_polygon: Array=[[rear_left,rear_top],[rear_right,rear_top],[rear_right,bottom],[rear_left,bottom]]
	var roof:=y+depth*0.86
	var child: Dictionary=context.creek_children[0]
	var child_program: Dictionary=child.program
	var child_origin:=_point(child.offset_local)
	var water_left:=child_origin.x+float(child_program.launch_length)
	var water_right:=water_left+float(child_program.gap_width)
	var creek: Array=[[-180.0,roof+40.0],[80.0,roof],[launch,roof+38.0],[receive,roof+24.0],[end-100.0,roof],[end+180.0,roof+55.0],[end+180.0,lower_y],[water_right,lower_y],[water_right,bottom],[water_left,bottom],[water_left,lower_y],[-180.0,lower_y]]
	var sky: Array=[[launch-4.0,y-40.0],[receive+4.0,y-40.0],[receive+22.0,roof+75.0],[launch-22.0,roof+75.0]]
	var grammar: Dictionary=program.asset_grammar
	var source_anchor:=_point(grammar.source_anchor)
	var scale:=float(grammar.allowed_scale[0])
	# Constrain the shared composition by the ACTUAL painted foot interfaces.
	# The vault is not squeezed onto an already chosen octagonal window.
	var feet: Array=grammar.bottom_connections_px
	var dx_left:=(float(feet[0][0])-source_anchor.x)*scale
	var dx_right:=(float(feet[1][0])-source_anchor.x)*scale
	var low:=maxf(child_origin.x+16.0-dx_left,water_right+16.0-dx_right)
	var high:=minf(water_left-16.0-dx_left,child_origin.x+float(child_program.module_width)+float(child.receiving_extension)-16.0-dx_right)
	var window_center:=roundf(lerpf(low,high,float(program.composition.vault_anchor_bias)))
	var vault_anchor:=Vector2(window_center,lower_y+minf(70.0,float(child.front_root_depth)*0.45+5.0))
	var registered_core:=_map_source_points(grammar.negative_contour_px,source_anchor,vault_anchor,scale)
	var left_mouth: Array=registered_core[int(grammar.open_bottom_port_px.left_index)]
	var right_mouth: Array=registered_core[int(grammar.open_bottom_port_px.right_index)]
	var terminal_y:=bottom+64.0
	var lower_left: Array=[left_mouth[0],terminal_y]
	var lower_right: Array=[right_mouth[0],terminal_y]
	var extension: Array=[left_mouth.duplicate(),lower_left,lower_right,right_mouth.duplicate()]
	var daylight: Array=registered_core.slice(0,int(grammar.open_bottom_port_px.left_index)+1)
	daylight.append(lower_left);daylight.append(lower_right)
	daylight.append_array(registered_core.slice(int(grammar.open_bottom_port_px.right_index)))
	var open_port: Dictionary={"left":left_mouth.duplicate(),"right":right_mouth.duplicate(),"direction":[0.0,1.0],"destination":"regional_creek_valley_exterior","terminal_y":terminal_y,"regional_bottom_y":bottom,"collision":false,"source_left_px":grammar.open_bottom_port_px.left.duplicate(),"source_right_px":grammar.open_bottom_port_px.right.duplicate()}
	var connections: Array=[]
	for index: int in feet.size():
		var point:=(_point(feet[index])-source_anchor)*scale+vault_anchor
		var volume:="creek_left" if index==0 else "creek_right"
		var connected:=false
		for front: Dictionary in fronts:
			if front.volume_id==volume:connected=Geometry2D.is_point_in_polygon(point,_packed(front.points))
		connections.append({"source_px":feet[index].duplicate(),"local_anchor":[point.x,point.y],"volume_id":volume,"kind":"painted_vault_pier_into_owned_creek_bedrock","valid":connected})
	var structural_pieces: Array=[{"id":"creek_rock_vault","asset_role":"rock_vault","source_anchor":grammar.source_anchor.duplicate(),"local_anchor":[vault_anchor.x,vault_anchor.y],"uniform_scale":scale,"negative_contour_px":grammar.negative_contour_px.duplicate(true),"negative_topology":"open_bottom_exterior_port","source_outline_px":grammar.source_outline_px.duplicate(true),"connection_interfaces":connections,"volume_id":"plains/main_bedrock","layer":"rear_vault","source_sha256":grammar.source_sha256,"placement_feasible":low<=high,"feasible_anchor_interval":[low,high]}]
	var openings: Array=[{"id":"sky_fissure","kind":"sky_fissure","points":sky,"collision":false},{"id":"creek_daylight_arch","kind":"open_bottom_daylight_exit","points":daylight,"registered_negative_core":registered_core,"open_bottom_port":open_port,"extension_polygon":extension,"collision":false}]
	# Front walkable air is NOT a hole through the rear substrate. Split the
	# substrate at the daylight window before clipping, yielding simple pieces
	# rather than misinterpreting a clockwise hole loop as another solid.
	var pieces: Array[PackedVector2Array]=[_packed([rear_polygon[0],[window_center,rear_top],[window_center,bottom],rear_polygon[3]]),_packed([[window_center,rear_top],rear_polygon[1],rear_polygon[2],[window_center,bottom]])]
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
		walls.append({"id":"rear_substrate/"+str(walls.size()),"volume_id":"plains/main_bedrock","points":_arrays(piece),"root_y":bottom,"root_contact_length":root_contact,"anchored_to_root":root_contact>0.0,"collision":false,"layer":"rear_substrate","depth_role":"distant_low_contrast_regional_bedrock","regional_substrate_id":regional.id,"surface_horizon_local_y":rear_top,"coverage_policy":regional.coverage,"material_space":program.material_space.duplicate(true),"geometry_source":"environment_program_ridge_minus_gallery_and_fissure"})
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
	var ownership: Array=[[0.0,y,launch,depth],[receive,y,width,depth]]
	for front: Dictionary in fronts:
		if not str(front.source_role).begins_with("creek_"):continue
		var bounds_min:=Vector2(INF,INF);var bounds_max:=Vector2(-INF,-INF)
		for point: Array in front.points:bounds_min=bounds_min.min(_point(point));bounds_max=bounds_max.max(_point(point))
		ownership.append([bounds_min.x,bounds_min.y,bounds_max.x-bounds_min.x,bounds_max.y-bounds_min.y])
	return {"version":VERSION,"module_id":MODULE_ID,"environment_program":program,"landing_planes":[{"id":"departure","bank":"ridge_left","a":[0.0,y],"b":[launch,y],"minimum_solid_depth":program.projected_cap_depth},{"id":"receiving","bank":"ridge_right","a":[receive,y],"b":[receive+float(program.landing_length),y],"minimum_solid_depth":program.projected_cap_depth}],"ports":{"entry":[20.0,y-18.0],"exit":[780.0,y-18.0]},"protected_action_gap":{"rect":[launch,0.0,float(program.gap_width),720.0],"minimum_clear_width":120.0,"actual_clear_width":program.gap_width},"regional_substrate":regional,"front_volumes":fronts,"front_voids":[{"id":"creek_gallery","kind":"creek_gallery","points":creek,"collision":false,"meaning":"foreground_traversal_air_with_continuous_rear_bedrock"}],"rear_walls":walls,"rear_openings":openings,"structural_pieces":structural_pieces,"support_relations":supports,"ownership_rects":ownership,"material_coordinates":program.material_space.duplicate(true)}

static func _creek_fronts(context: Dictionary, parent: Dictionary, bottom: float) -> Array:
	var result: Array=[]
	for child: Dictionary in context.creek_children:
		var program: Dictionary=child.program
		var origin:=_point(child.offset_local)
		var y:=origin.y+float(program.standing_y)
		var left:=origin.x
		var gap_left:=left+float(program.launch_length)
		var gap_right:=gap_left+float(program.gap_width)
		var end:=origin.x+float(program.module_width)+float(child.receiving_extension)
		var depth:=float(child.get("front_root_depth",190.0))
		var span:=end-gap_right
		var shapes: Array=[{"side":"left","points":[[left,y],[gap_left,y],[gap_left,y+32.0],[gap_left-48.0,y+32.0],[gap_left-55.0,y+depth*0.43],[gap_left-65.0,y+depth*0.69],[gap_left-80.0,y+depth*0.88],[left+60.0,y+depth],[left,y+depth*0.92]],"surface":[[left,y],[gap_left,y]]},{"side":"right","points":[[gap_right,y],[end,y],[end,y+depth*0.89],[end-span*0.18,y+depth],[end-span*0.43,y+depth*0.94],[gap_right+span*0.28,y+depth*0.73],[gap_right+57.0,y+depth*0.42],[gap_right+48.0,y+32.0],[gap_right,y+32.0]],"surface":[[gap_right,y],[end,y]]}]
		for shape: Dictionary in shapes:
			var id:="creek_"+str(shape.side)
			var faces: Array=[]
			for index: int in shape.points.size():
				var kind:="standing" if index==0 else "outer_connection" if (shape.side=="left" and index==shape.points.size()-1) or (shape.side=="right" and index==1) or (absf(float(shape.points[index][1])-bottom)<0.01 and absf(float(shape.points[(index+1)%shape.points.size()][1])-bottom)<0.01) else "shoulder"
				faces.append({"a":shape.points[index],"b":shape.points[(index+1)%shape.points.size()],"kind":kind,"volume_id":id})
			result.append({"id":id,"volume_id":id,"source_role":id,"child_node_id":child.node_id,"parent_program_id":parent.id,"points":shape.points,"local_points":shape.points.duplicate(true),"local_visual_points":shape.points.duplicate(true),"surface_profile":shape.surface,"exposed_faces":faces,"geometry_source":"paired_creek_program_before_definition","material_space":parent.material_space.duplicate(true),"material_coordinates":parent.material_space.duplicate(true),"neighbor_interfaces":[{"id":id+"/ground_root","standing_point":shape.surface[0],"root_point":[left if shape.side=="left" else end,y+depth*0.92],"direction":[-1.0 if shape.side=="left" else 1.0,0.0],"kind":"grounded_creek_substrate"}]})
	return result

static func build_local(context: Dictionary = {}) -> Dictionary:
	if context.is_empty() or context.get("environment_program",{}).is_empty():return {"ok":false,"error":"Environment program must exist before the platform projection"}
	var spec:=source_spec(context)
	var platforms: Array=[]
	for plane: Dictionary in spec.landing_planes:platforms.append([plane.a[0],plane.a[1],float(plane.b[0])-float(plane.a[0]),plane.minimum_solid_depth])
	return {"version":VERSION,"module_id":MODULE_ID,"render_method":RENDER_METHOD,"environment_program":spec.environment_program,"region_context":context.duplicate(true),"semantic_source":spec,"terrain_bodies":spec.front_volumes,"front_voids":spec.front_voids,"rear_walls":spec.rear_walls,"rear_openings":spec.rear_openings,"structural_pieces":spec.structural_pieces,"support_relations":spec.support_relations,"cutout_rects":spec.ownership_rects,"keep_clear":[{"kind":"protected_joint_recoil_action_gap","rect":spec.protected_action_gap.rect}],"platforms":platforms}

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
		var opening:=raw.duplicate(true)
		opening.local_points=raw.points.duplicate(true);opening.points=_translate_points(raw.points,offset)
		if raw.has("registered_negative_core"):
			opening.registered_negative_core=_translate_points(raw.registered_negative_core,offset)
			opening.extension_polygon=_translate_points(raw.extension_polygon,offset)
			opening.open_bottom_port.left=_translate_point(raw.open_bottom_port.left,offset)
			opening.open_bottom_port.right=_translate_point(raw.open_bottom_port.right,offset)
			opening.open_bottom_port.terminal_y=float(raw.open_bottom_port.terminal_y)+offset.y
			opening.open_bottom_port.regional_bottom_y=float(raw.open_bottom_port.regional_bottom_y)+offset.y
		openings.append(opening)
	var pieces: Array=[]
	for raw: Dictionary in local.structural_pieces:
		var piece:=raw.duplicate(true)
		piece.world_anchor=_translate_point(raw.local_anchor,offset)
		for contact: Dictionary in piece.connection_interfaces:
			contact.world_anchor=_translate_point(contact.local_anchor,offset)
		pieces.append(piece)
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
	return {"version":VERSION,"render_method":RENDER_METHOD,"node_id":node.id,"module_id":MODULE_ID,"offset":node.offset.duplicate(),"region_context":local.region_context,"environment_program":local.environment_program,"semantic_source":local.semantic_source,"terrain_bodies":bodies,"front_voids":voids,"rear_walls":walls,"rear_openings":openings,"structural_pieces":pieces,"support_relations":supports,"cutout_rects":cutouts,"keep_clear":clear+local.region_context.get("protected_actual_airspace",[]).duplicate(true),"derived_platforms":local.platforms,"physics_owner":"actual_environment_program_polygons","production_pool":false}

static func _map_source_points(values: Array, source_anchor: Vector2, anchor: Vector2, scale: float) -> Array:
	var result: Array=[]
	for value: Array in values:
		var point:=(_point(value)-source_anchor)*scale+anchor
		result.append([point.x,point.y])
	return result

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
	var children: Array=[]
	var owned: Array=[{"node_id":node.id,"platform_index":0},{"node_id":node.id,"platform_index":1},{"node_id":neighbor.id,"platform_index":neighbor_index}]
	var child_ids: Array[String]=[]
	for child: Dictionary in manifest.nodes:
		var child_program: Dictionary=child.get("environment_program",{})
		if child_program.get("parent_program_id","")!=node.get("environment_program",{}).get("id","missing"):continue
		var child_offset:=_point(child.offset)-offset
		var child_definition:=PlainsRegionGenerator.definition(child)
		var extension:=0.0
		var join_id:=""
		var join_index:=-1
		var child_seam:=_point(child.offset)+Vector2(float(child_program.module_width),float(child_program.standing_y))
		for candidate: Dictionary in manifest.nodes:
			if str(candidate.module_id)!="region_connection":continue
			var d:=PlainsRegionGenerator.definition(candidate)
			for index: int in d.platforms.size():
				var rect:=Rect2(_point(candidate.offset)+d.platforms[index].position,d.platforms[index].size)
				if index not in d.one_way_platform_indices and rect.position.is_equal_approx(child_seam):
					extension=rect.size.x;join_id=candidate.id;join_index=index;break
			if not join_id.is_empty():break
		var original_slabs: Array=[]
		for index: int in child_definition.platforms.size():
			owned.append({"node_id":child.id,"platform_index":index})
			var rect: Rect2=child_definition.platforms[index]
			original_slabs.append([child_offset.x+rect.position.x,child_offset.y+rect.position.y,rect.size.x,rect.size.y])
		if not join_id.is_empty():owned.append({"node_id":join_id,"platform_index":join_index})
		var dangers: Array=[]
		for rect: Rect2 in child_definition.danger_bounds:dangers.append([child_offset.x+rect.position.x,child_offset.y+rect.position.y,rect.size.x,rect.size.y])
		children.append({"node_id":child.id,"program":child_program.duplicate(true),"offset_local":[child_offset.x,child_offset.y],"receiving_extension":extension,"neighbor_join_node":join_id,"original_slabs":original_slabs,"danger_bounds":dangers,"clear_gap":{"rect":[child_offset.x+float(child_program.launch_length),child_offset.y+float(child_program.standing_y),float(child_program.gap_width),float(manifest.world_bounds[1])+float(manifest.world_bounds[3])-offset.y-child_offset.y-float(child_program.standing_y)],"meaning":"original ferry water gap; no new static rescue floor"}})
		child_ids.append(str(child.id))
	if children.is_empty():return {"ok":false,"error":"Ridge must own its topology-paired lower creek child before embedding"}
	if not node.environment_program.get("asset_grammar",{}).get("ok",false):return {"ok":false,"error":"No registered vault expression grammar before embedding"}
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
	for child: Dictionary in children:
		var child_program: Dictionary=child.program
		var child_origin:=_point(child.offset_local)+offset
		var child_standing:=child_origin.y+float(child_program.standing_y)
		var room:=190.0
		for space: Dictionary in protected:
			var r: Array=space.rect
			if float(r[1])<=child_standing+32.0:continue
			var x:=float(r[0]);var finish:=x+float(r[2])
			var left_hit:=x<child_origin.x+float(child_program.launch_length) and finish>child_origin.x
			var right_hit:=x<child_origin.x+float(child_program.module_width)+float(child.receiving_extension) and finish>child_origin.x+float(child_program.launch_length)+float(child_program.gap_width)
			if left_hit or right_hit:room=minf(room,float(r[1])-child_standing-8.0)
		if room<70.0:return {"ok":false,"error":"Creek front thickness cannot respect the next actual lower route"}
		child.front_root_depth=room
		child.root_policy="curved_foreground_stratum_with_actual_rear_bedrock_overlap_above_next_route_void"
	var grammar: Dictionary=node.environment_program.asset_grammar
	var source_anchor:=_point(grammar.source_anchor)
	var scale:=float(grammar.allowed_scale[0])
	for child: Dictionary in children:
		var p: Dictionary=child.program
		var feet: Array=grammar.bottom_connections_px
		var left_dx:=(float(feet[0][0])-source_anchor.x)*scale
		var right_dx:=(float(feet[1][0])-source_anchor.x)*scale
		var low:=maxf(16.0-left_dx,float(p.launch_length)+float(p.gap_width)+16.0-right_dx)
		var high:=minf(float(p.launch_length)-16.0-left_dx,float(p.module_width)+float(child.receiving_extension)-16.0-right_dx)
		if low>high:return {"ok":false,"error":"Registered painted vault feet cannot join the legal creek banks at fixed family scale"}
	var original_domains: Array=[]
	for owner: Dictionary in owned:
		for original_node: Dictionary in manifest.nodes:
			if original_node.id!=owner.node_id:continue
			var d:=PlainsRegionGenerator.definition(original_node)
			var rect: Rect2=d.platforms[int(owner.platform_index)]
			var origin:=_point(original_node.offset)
			original_domains.append({"node_id":owner.node_id,"platform_index":owner.platform_index,"rect":[origin.x+rect.position.x,origin.y+rect.position.y,rect.size.x,rect.size.y]})
			break
	var world: Dictionary=manifest.get("environment_world",{})
	var margin:=float(world.get("camera_overdraw_world",1024.0))
	var regional_substrate:=world.duplicate(true)
	regional_substrate.bounds_local=[float(manifest.world_bounds[0])-margin-offset.x,float(manifest.world_bounds[1])-offset.y,float(manifest.world_bounds[2])+margin*2.0,float(manifest.world_bounds[3])]
	regional_substrate.surface_horizon_local_y=float(world.get("surface_horizon_world_y",54.0))-offset.y
	var available:=lower_ceiling-standing
	var variant:="deep_root" if available>=420.0 else "shallow_root" if available>=230.0 else ""
	if variant.is_empty(): return {"ok":false,"error":"No complete receiving source fits the actual lower-route clearance"}
	return {"ok":true,"context":{"neighbor_join_node":neighbor.id,"neighbor_join_platform_index":neighbor_index,"regional_substrate":regional_substrate,"owned_slabs":owned,"original_owned_static_domains":original_domains,"child_node_ids":child_ids,"creek_children":children,"receiving_width":width,"available_root_depth":available,"lower_action_headroom":headroom,"movement_capability":capability,"environment_program":node.get("environment_program",{}).duplicate(true),"lower_standing_local_y":lower_ceiling+headroom-offset.y,"world_base_local_y":float(manifest.world_bounds[1])+float(manifest.world_bounds[3])-offset.y,"root_depth":minf(available-10.0,277.0),"variant":variant,"protected_actual_airspace":protected,"lower_clearance_policy":"actual lower standing surfaces minus measured full held-jump height, 36px actor and 12px margin; actual dynamics/path and input trace independently verified"}}

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
