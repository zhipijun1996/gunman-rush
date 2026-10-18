class_name PlainsJointRecoilPlan
extends RefCounted
## One semantic challenge source. Collision planes, whole bank volume, visual
## interfaces and protected action space all derive from this source, not Tiles.
const VERSION := "plains-joint-recoil-v4-owned-receiving-mass"
const SOURCE_SHA256 := "7e36f24789d104b23e1c2a33a1ae88e761f24ac978d56170dbb79d812fecb314"
const SOURCE_TEXTURE := "res://assets/visual_development/p1_joint_recoil/whole_banks.png"
const MODULE_ID := "plains_recoil_span"
const BANK_DEPTH := 260.0

static func _base_spec() -> Dictionary:
	return {"version":VERSION,"module_id":MODULE_ID,"landing_planes":[{"id":"departure","bank":"bank_left","a":[0.0,600.0],"b":[300.0,600.0],"minimum_solid_depth":40.0},{"id":"receiving","bank":"bank_right","a":[560.0,600.0],"b":[800.0,600.0],"minimum_solid_depth":40.0}],"inner_cliff_shoulders":{"bank_left":[[300.0,600.0],[300.0,650.0],[296.0,675.0],[284.0,701.0],[263.0,722.0],[252.0,751.0]],"bank_right":[[560.0,600.0],[560.0,650.0],[564.0,686.0],[572.0,722.0],[584.0,758.0]]},"lower_contours":{"bank_left":[[252.0,751.0],[226.0,778.0],[180.0,802.0],[116.0,819.0],[62.0,842.0],[0.0,860.0]],"bank_right":[[584.0,758.0],[610.0,788.0],[652.0,814.0],[702.0,823.0],[756.0,844.0],[800.0,860.0]]},"outer_connections":[{"id":"entry_bank_seam","bank":"bank_left","standing_point":[0.0,600.0],"root_point":[0.0,860.0],"direction":[-1.0,0.0]},{"id":"exit_bank_seam","bank":"bank_right","standing_point":[800.0,600.0],"root_point":[800.0,860.0],"direction":[1.0,0.0]}],"ports":{"entry":[20.0,582.0],"exit":[780.0,582.0]},"protected_action_gap":{"rect":[300.0,0.0,260.0,720.0],"minimum_clear_width":120.0,"actual_clear_width":260.0,"meaning":"original standing gap and full upper flight space; no new support within gap"},"ownership_rect":[0.0,600.0,800.0,260.0],"material_coordinates":{"space":"continuous_world","world_origin":[0.0,0.0],"horizontal_period":780.0,"bank_depth":BANK_DEPTH,"surface_y":600.0}}

static func source_spec(region_context: Dictionary = {}) -> Dictionary:
	var spec:=_base_spec()
	# Actual final source measurements, sealed to the unaltered PNG. Only
	# non-standing contour/paint registration is calibrated; the original
	# complete 40px slabs, 260px action gap and outer seams stay invariant.
	var samples: Array=[[110,803,1156],[150,800,1155],[190,799,1155],[219,788,1166],[250,715,1227],[300,634,1299],[340,598,1327],[380,571,1361],[420,547,1385],[460,526,1415],[500,507,1426],[540,493,1464],[580,485,1483],[620,507,1472],[660,525,1462],[700,560,1443],[740,578,1422],[780,615,1388],[820,645,1367]]
	var refs: Dictionary={"bank_left":[49.0,110.0,754.0,710.0],"bank_right":[1156.0,110.0,613.0,710.0]}
	var curves: Dictionary={}
	for role: String in ["bank_left"]:
		var ref: Array=refs[role]
		var left:=0.0 if role=="bank_left" else 560.0
		var width:=300.0 if role=="bank_left" else 240.0
		var top_inner:=left+width if role=="bank_left" else left
		var source_inner:=float(ref[0])+float(ref[2]) if role=="bank_left" else float(ref[0])
		var source_outer:=float(ref[0]) if role=="bank_left" else float(ref[0])+float(ref[2])
		var inner: Array=[[top_inner,600.0],[top_inner,640.0]]
		# Keep the original solid's complete inner face visible. The 219px
		# painted edge is registered to the 40px end through an explicit UV
		# control, rather than transparently cutting six world pixels away.
		var inner_uv: Array=[[source_inner,110.0],[788.0 if role=="bank_left" else 1166.0,219.0]]
		for row: Array in samples:
			if int(row[0])<=219: continue
			var source_x:=float(row[1] if role=="bank_left" else row[2])
			var world_y:=600.0+(float(row[0])-110.0)/710.0*BANK_DEPTH
			var source_at_solid_end:=788.0 if role=="bank_left" else 1166.0
			var upper_correction:=top_inner-(left+(source_at_solid_end-float(ref[0]))/float(ref[2])*width)
			# Distribute the <=6 world-pixel original-slab correction over the
			# complete lower depth, avoiding a high-shear UV triangle directly
			# below the preserved slab. The measured bottom flare stays exact.
			var recovery:=clampf((860.0-world_y)/220.0,0.0,1.0)
			inner.append([left+(source_x-float(ref[0]))/float(ref[2])*width+upper_correction*recovery,world_y])
			inner_uv.append([source_x,float(row[0])])
		var points: Array=[]
		var visual: Array=[]
		var uv: Array=[]
		var grass_top:=600.0+(10.0-110.0)/710.0*BANK_DEPTH
		if role=="bank_left":
			points.append([left,600.0]);points.append_array(inner.duplicate(true));points.append([left,860.0])
			visual.append([left,grass_top]);uv.append([source_outer,10.0])
			visual.append([top_inner,grass_top]);uv.append([source_inner,10.0])
			visual.append_array(inner.duplicate(true));uv.append_array(inner_uv.duplicate(true))
			visual.append([left,860.0]);uv.append([source_outer,820.0])
		else:
			points.append([left,600.0]);points.append([left+width,600.0]);points.append([left+width,860.0])
			var reverse_inner: Array=inner.duplicate(true);reverse_inner.reverse()
			var reverse_uv: Array=inner_uv.duplicate(true);reverse_uv.reverse()
			points.append_array(reverse_inner.slice(0,reverse_inner.size()-1))
			visual.append([left,grass_top]);uv.append([source_inner,10.0])
			visual.append([left+width,grass_top]);uv.append([source_outer,10.0])
			visual.append([left+width,860.0]);uv.append([source_outer,820.0])
			visual.append_array(reverse_inner);uv.append_array(reverse_uv)
		curves[role]={"physical_points":points,"local_visual_points":visual,"source_uv_px":uv,"physical_reference_rect_px":ref.duplicate(),"source_sha256":SOURCE_SHA256,"source_texture":SOURCE_TEXTURE,"render_mesh":_row_mesh(visual,uv,role)}
		spec.inner_cliff_shoulders[role]=inner.slice(0,5)
		spec.lower_contours[role]=inner.slice(4)
	if not region_context.is_empty():
		curves.bank_right=_receiving_curve(region_context)
		spec.ownership_rects=[spec.ownership_rect.duplicate(),[560.0,600.0,float(region_context.receiving_width),float(region_context.root_depth)]]
		spec.outer_connections[1].standing_point=[560.0+float(region_context.receiving_width),600.0]
		spec.outer_connections[1].root_point=[560.0+float(region_context.receiving_width),600.0+float(region_context.root_depth)]
		spec.outer_connections[1].neighbor_join_node=region_context.neighbor_join_node
		spec.receiving_region_context=region_context.duplicate(true)
	spec.bank_contours=curves
	spec.paint_registration={"source_sha256":SOURCE_SHA256,"source_texture":SOURCE_TEXTURE,"source_dimensions":[1816,866],"physical_reference_rects_px":refs,"measured_inner_contour_samples_px":samples,"source_standing_y_px":110.0,"source_visual_top_y_px":10.0,"original_solid_depth_world":40.0,"method":"source-measured lower flare plus explicit upper-cliff UV correspondence; physical planes and action gap unchanged"}
	if not region_context.is_empty(): spec.paint_registration.scope="bank_left"
	return spec

static func _receiving_curve(context: Dictionary) -> Dictionary:
	# Explicitly owned replacement of generated fill, not a fit to its obsolete
	# rectangular silhouette. Source pixels now generate BOTH the actual root
	# polygon and the complete painting mesh. Original caps remain contained.
	var deep: bool=context.variant=="deep_root"
	var ref: Array=[48.0,110.0,854.0,715.0] if deep else [992.0,110.0,782.0,455.0]
	var samples: Array=[[110,48,901],[160,48,901],[210,48,901],[240,48,901],[260,89,900],[280,100,900],[300,105,900],[340,133,900],[380,142,900],[420,175,900],[460,189,890],[500,207,889],[540,254,899],[580,272,898],[620,277,897],[660,255,894],[700,243,900],[740,198,900],[780,172,900],[820,158,900]] if deep else [[110,992,1774],[160,992,1774],[210,992,1774],[240,1001,1774],[260,1076,1774],[280,1094,1774],[300,1163,1774],[340,1215,1772],[380,1288,1772],[420,1324,1774],[460,1351,1774],[500,1430,1774],[540,1451,1774],[550,1455,1774],[560,1460,1773],[565,1465,1773]]
	var width:=float(context.receiving_width)
	var depth:=float(context.root_depth)
	var left_rows: Array=[];var right_rows: Array=[]
	var left_uv: Array=[];var right_uv: Array=[]
	for row: Array in samples:
		var y:=600.0+(float(row[0])-float(ref[1]))/float(ref[3])*depth
		left_rows.append([560.0+(float(row[1])-float(ref[0]))/float(ref[2])*width,y])
		var right_x:=560.0+width if float(row[0])<=240.0 else 560.0+(float(row[2])-float(ref[0]))/float(ref[2])*width
		right_rows.append([right_x,y])
		left_uv.append([float(row[1]),float(row[0])]);right_uv.append([float(row[2]),float(row[0])])
	var physical: Array=[left_rows[0].duplicate()]
	physical.append_array(right_rows.duplicate(true))
	for index: int in range(left_rows.size()-1,0,-1): physical.append(left_rows[index].duplicate())
	var grass_y:=600.0+(10.0-float(ref[1]))/float(ref[3])*depth
	var visual: Array=[[560.0,grass_y],[560.0+width,grass_y]]
	var boundary_uv: Array=[[float(ref[0]),10.0],[float(ref[0])+float(ref[2]),10.0]]
	visual.append_array(right_rows.duplicate(true));boundary_uv.append_array(right_uv.duplicate(true))
	for index: int in range(left_rows.size()-1,-1,-1): visual.append(left_rows[index].duplicate());boundary_uv.append(left_uv[index].duplicate())
	var vertices: Array=[[560.0,grass_y],[560.0+width,grass_y]]
	var uv: Array=boundary_uv.slice(0,2).duplicate(true)
	var indices: Array=[]
	for index: int in left_rows.size():
		vertices.append(left_rows[index].duplicate());vertices.append(right_rows[index].duplicate())
		uv.append(left_uv[index].duplicate());uv.append(right_uv[index].duplicate())
		var previous:=index*2
		indices.append_array([previous,previous+1,previous+2,previous+1,previous+3,previous+2])
	return {"physical_points":physical,"local_visual_points":visual,"source_uv_px":boundary_uv,"physical_reference_rect_px":ref,"source_sha256":"306f21e3e0239327ab68bb279b6bf5895b03606f318aaa7a12c07912b23a3c57","source_texture":"res://assets/visual_development/p1_joint_recoil/connected_receiving_banks_v2.png","variant":context.variant,"material_coordinates":{"space":"source_registered_whole_mass","world_origin":[0.0,0.0],"bank_depth":depth,"surface_y":600.0},"surface_profile":[[560.0,600.0],[560.0+width,600.0]],"source_contour_samples_px":samples,"render_mesh":{"method":"owned_source_contour_cross_section_mesh","vertices":vertices,"source_uv_px":uv,"indices":indices,"row_count":left_rows.size()+1,"source_generates_collision":true}}

static func _row_mesh(visual: Array, source_uv: Array, role: String) -> Dictionary:
	# The same measured boundary and source coordinates, with wide cross-bank
	# sections instead of skinny boundary ears. No physics or UV is changed.
	var rows: Array=[]
	var row_uv: Array=[]
	var outer_x:=float(visual[0][0] if role=="bank_left" else visual[1][0])
	var outer_uv_x:=float(source_uv[0][0] if role=="bank_left" else source_uv[1][0])
	if role=="bank_left":
		rows=visual.slice(1,visual.size()-1)
		row_uv=source_uv.slice(1,source_uv.size()-1)
	else:
		rows=[visual[0].duplicate()]
		row_uv=[source_uv[0].duplicate()]
		var reversed_rows: Array=visual.slice(3);reversed_rows.reverse()
		var reversed_uv: Array=source_uv.slice(3);reversed_uv.reverse()
		rows.append_array(reversed_rows);row_uv.append_array(reversed_uv)
	var vertices: Array=[]
	var uv: Array=[]
	var indices: Array=[]
	for index: int in rows.size():
		var inner: Array=rows[index]
		var inner_uv: Array=row_uv[index]
		var outer: Array=[outer_x,inner[1]]
		var outer_uv: Array=[outer_uv_x,inner_uv[1]]
		if role=="bank_left":
			vertices.append(outer);vertices.append(inner.duplicate())
			uv.append(outer_uv);uv.append(inner_uv.duplicate())
		else:
			vertices.append(inner.duplicate());vertices.append(outer)
			uv.append(inner_uv.duplicate());uv.append(outer_uv)
		if index>0:
			var previous: int=(index-1)*2
			indices.append_array([previous,previous+1,previous+2,previous+1,previous+3,previous+2])
	return {"method":"versioned_cross_bank_row_mesh","vertices":vertices,"source_uv_px":uv,"indices":indices,"row_count":rows.size(),"boundary_unchanged":true,"physics_unchanged":true}

static func definition_from_spec(spec: Dictionary) -> PlatformingModuleDefinition:
	var original:=RandomStageGenerator.new().definition_for(MODULE_ID,false,false)
	var result:=original.duplicate(true) as PlatformingModuleDefinition
	result.platforms.clear()
	for plane: Dictionary in spec.landing_planes:
		var a:=_point(plane.a);var b:=_point(plane.b)
		result.platforms.append(Rect2(a,Vector2(b.x-a.x,float(plane.minimum_solid_depth))))
	# All non-geometric challenge requirements, damage, ports and timing remain
	# the original admitted resource. No tuning or capability is invented here.
	return result

static func build_local(region_context: Dictionary = {}) -> Dictionary:
	if region_context.is_empty(): return {"ok":false,"error":"A joint receiving mass requires its actual neighboring standing surfaces and lower-route context"}
	var spec:=source_spec(region_context)
	var bodies: Array=[]
	for plane: Dictionary in spec.landing_planes:
		var curve: Dictionary=spec.bank_contours[plane.bank]
		bodies.append({"id":plane.bank,"source_role":plane.bank,"points":curve.physical_points.duplicate(true),"local_visual_points":curve.local_visual_points.duplicate(true),"source_uv_px":curve.source_uv_px.duplicate(true),"source_sha256":curve.source_sha256,"source_texture":curve.source_texture,"variant":curve.get("variant",""),"source_contour_samples_px":curve.get("source_contour_samples_px",[]),"physical_reference_rect_px":curve.physical_reference_rect_px.duplicate(),"render_mesh":curve.render_mesh.duplicate(true),"surface_profile":curve.get("surface_profile",[plane.a.duplicate(),plane.b.duplicate()]).duplicate(true),"neighbor_interfaces":spec.outer_connections.filter(func(row: Dictionary)->bool:return row.bank==plane.bank).duplicate(true),"material_coordinates":curve.get("material_coordinates",spec.material_coordinates).duplicate(true)})
	return {"version":VERSION,"module_id":MODULE_ID,"region_context":region_context.duplicate(true),"semantic_source":spec,"terrain_bodies":bodies,"cutout_rects":spec.get("ownership_rects",[spec.ownership_rect.duplicate()]).duplicate(true),"keep_clear":[{"kind":"protected_joint_recoil_action_gap","rect":spec.protected_action_gap.rect.duplicate()}],"platforms":definition_from_spec(spec).platforms.map(func(r: Rect2)->Array:return [r.position.x,r.position.y,r.size.x,r.size.y])}

static func instantiate(node: Dictionary) -> Dictionary:
	# Replay derives world coordinates from the admitted source, not from JSON-rounded
	# intermediate local curves (which otherwise accumulate a second rounding).
	var local: Dictionary=build_local(node.joint_recoil.get("region_context",{}))
	var offset:=_point(node.offset)
	var bodies: Array=[]
	for body: Dictionary in local.terrain_bodies:
		var result: Dictionary=body.duplicate(true)
		result.local_points=body.points.duplicate(true)
		result.points=_translate_points(body.points,offset)
		result.visual_points=_translate_points(body.local_visual_points,offset)
		result.local_render_mesh=body.render_mesh.duplicate(true)
		result.render_mesh.vertices=_translate_points(body.render_mesh.vertices,offset)
		result.surface_profile=_translate_points(body.surface_profile,offset)
		for seam: Dictionary in result.neighbor_interfaces:
			seam.standing_point=_translate_point(seam.standing_point,offset)
			seam.root_point=_translate_point(seam.root_point,offset)
		result.material_coordinates.world_origin=[0.0,0.0]
		result.material_coordinates.surface_y=600.0+offset.y
		result.id=str(node.id)+"/"+str(body.id)
		bodies.append(result)
	var cutouts: Array=[]
	for r: Array in local.cutout_rects: cutouts.append([float(r[0])+offset.x,float(r[1])+offset.y,r[2],r[3]])
	var clear: Array=[]
	for row: Dictionary in local.keep_clear:
		var r: Array=row.rect
		clear.append({"kind":row.kind,"owner":node.id,"rect":[float(r[0])+offset.x,float(r[1])+offset.y,r[2],r[3]]})
	return {"version":VERSION,"node_id":node.id,"module_id":MODULE_ID,"offset":node.offset.duplicate(),"region_context":local.get("region_context",{}).duplicate(true),"semantic_source":local.semantic_source,"terrain_bodies":bodies,"cutout_rects":cutouts,"keep_clear":clear+local.get("region_context",{}).get("protected_actual_airspace",[]).duplicate(true),"derived_platforms":local.platforms,"physics_owner":"actual_joint_bank_polygons_and_authorized_receiving_mass_in_region_assembler","production_pool":false}

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
	if not is_equal_approx(width,600.0) or not is_equal_approx(original_join.size.y,32.0): return {"ok":false,"error":"Actual receiving standing span cannot be expressed by the bounded 600-wide source family"}
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
	var variant:="deep_root" if available>=498.0 else "shallow_root" if available>=308.0 else ""
	if variant.is_empty(): return {"ok":false,"error":"No complete receiving source fits the actual lower-route clearance"}
	return {"ok":true,"context":{"neighbor_join_node":neighbor.id,"neighbor_join_platform_index":neighbor_index,"owned_slabs":[{"node_id":node.id,"platform_index":0},{"node_id":node.id,"platform_index":1},{"node_id":neighbor.id,"platform_index":neighbor_index}],"receiving_width":width,"available_root_depth":available,"lower_action_headroom":headroom,"movement_capability":capability,"root_depth":498.0 if variant=="deep_root" else 308.0,"variant":variant,"protected_actual_airspace":protected,"lower_clearance_policy":"actual lower standing surfaces minus measured full held-jump height, 36px actor and 12px margin; actual dynamics/path and input trace independently verified"}}

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
static func _translate_point(value: Array, offset: Vector2)->Array:return [float(value[0])+offset.x,float(value[1])+offset.y]
static func _translate_points(values: Array, offset: Vector2)->Array:
	var output: Array=[]
	for value: Array in values: output.append(_translate_point(value,offset))
	return output
