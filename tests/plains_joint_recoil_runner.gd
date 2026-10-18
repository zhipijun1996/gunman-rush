extends SceneTree
var assertions:=0
var failures: Array[String]=[]
func check(ok:bool,label:String)->void:
	assertions+=1
	if not ok: failures.append(label);print("JOINT CONTRACT FAILURE: ",label)
func overlap_area(points:PackedVector2Array,rect:Rect2)->float:
	var rectangle:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	var area:=0.0
	for loop:PackedVector2Array in Geometry2D.intersect_polygons(points,rectangle):
		var signed:=0.0
		for index:int in loop.size():signed+=loop[index].cross(loop[(index+1)%loop.size()])
		area+=absf(signed)*0.5
	return area
func actual_solid_at(world:Node2D,point:Vector2)->bool:
	var query:=PhysicsPointQueryParameters2D.new()
	query.position=point;query.collision_mask=1
	for hit:Dictionary in world.get_world_2d().direct_space_state.intersect_point(query,32):
		var body:=hit.collider as StaticBody2D
		if body==null:continue
		var owner_id:=body.shape_find_owner(int(hit.shape))
		var owner:=body.shape_owner_get_owner(owner_id)
		if owner is CollisionShape2D and not owner.disabled and not owner.one_way_collision:return true
		if owner is CollisionPolygon2D and not owner.disabled and not owner.one_way_collision:return true
	return false
func _initialize()->void:run.call_deferred()
func run()->void:
	var rows:Array=[]
	var tuning:=PlayerTuning.load_default()
	for root_seed:String in ["joint-recoil-01","joint-recoil-07"]:
		var seed:=PlainsRegionCampaign.seed_for(root_seed,1)
		var plain:=PlainsRegionArtPlan.generate(seed,tuning)
		var joint:=PlainsRegionArtPlan.generate(seed,tuning,"intro","",true)
		check(plain.get("ok",false) and joint.get("ok",false),root_seed+": actual candidate generation")
		if not plain.get("ok",false) or not joint.get("ok",false):continue
		var m:Dictionary=joint.manifest
		var replay:Dictionary=JSON.parse_string(JSON.stringify(m))
		check(PlainsRegionGenerator.new().validate(replay,tuning),root_seed+": original formal JSON Manifest replay")
		var replay_plan:Dictionary=JSON.parse_string(JSON.stringify(joint.regional_art_plan))
		check(PlainsRegionArtPlan.validate_recorded(replay_plan,replay),root_seed+": source-bound companion JSON replay")
		check(plain.manifest.areas==m.areas and plain.manifest.connections==m.connections,root_seed+": complete formal connectivity unchanged")
		check(plain.manifest.enemies==m.enemies and plain.manifest.rewards==m.rewards and plain.manifest.shop==m.shop,root_seed+": actual enemy/reward/shop contracts unchanged")
		check(plain.manifest.stream_positions==m.stream_positions and plain.manifest.streams==m.streams and plain.manifest.spawn==m.spawn and plain.manifest.shot_energy_version==m.shot_energy_version,root_seed+": RNG positions, spawn and energy version unchanged")
		var target:Dictionary={}
		var baseline_target:Dictionary={}
		for node:Dictionary in m.nodes:
			if node.has("joint_recoil"):target=node
		for node:Dictionary in plain.manifest.nodes:
			if node.id==m.joint_recoil_target:baseline_target=node
		check(not target.is_empty() and not str(target.id).begins_with("tutorial"),"One non-tutorial target")
		check(target.offset==baseline_target.offset,"Same geometry location before/after")
		var outside_nodes_unchanged:=true
		for index:int in m.nodes.size():
			if m.nodes[index].id!=target.id:outside_nodes_unchanged=outside_nodes_unchanged and m.nodes[index]==plain.manifest.nodes[index]
		check(outside_nodes_unchanged,"Every non-target module and recorded phase unchanged")
		var context:Dictionary=target.joint_recoil.region_context
		var physical_ownership:Array=[[float(target.offset[0]),float(target.offset[1])+600.0,800.0,260.0],[float(target.offset[0])+560.0,float(target.offset[1])+600.0,600.0,float(context.root_depth)]]
		check(PlainsJointRecoilPlan.instantiate(target).cutout_rects==physical_ownership,"Versioned explicit joint bank+receiving physics ownership")
		check(float(context.receiving_width)==600.0 and float(context.root_depth)>0.0 and float(context.root_depth)<=float(context.available_root_depth),"Receiving source fits actual authorized route clearance")
		check(context.owned_slabs==[{"node_id":target.id,"platform_index":0},{"node_id":target.id,"platform_index":1},{"node_id":context.neighbor_join_node,"platform_index":0}],"Exactly two target caps and one original32px join transfer ownership")
		check(PlainsJointRecoilPlan.clip_supports(plain.manifest.ground_supports,physical_ownership)==m.ground_supports,"Only generated fill inside explicitly authorized domains replaced")
		var original:=PlainsRegionGenerator.definition(baseline_target)
		var changed:=PlainsRegionGenerator.definition(target)
		check(original.platforms==changed.platforms and original.danger_bounds==changed.danger_bounds,"Original flat standing planes and lower danger unchanged")
		var broken:Dictionary=target.joint_recoil.duplicate(true)
		broken.terrain_bodies[0].neighbor_interfaces[0].standing_point[1]+=20
		check(not PlainsJointRecoilPlan.errors(broken).is_empty(),"Unsupported seam height rejected, not hidden by decoration")
		var damaged:Dictionary=m.duplicate(true)
		for bad:Dictionary in damaged.nodes:
			if bad.id==target.id:bad.joint_recoil=broken
		damaged.manifest_hash=PlainsRegionGenerator.new()._hash(damaged)
		var negative_world:=Node2D.new();root.add_child(negative_world)
		var rejector:=PlainsRegionAssembler.new();negative_world.add_child(rejector)
		check(not rejector.build(damaged,tuning).get("ok",false) and rejector.modules.is_empty(),"Actual consumer rejects rehashed unsupported join before installing collision")
		negative_world.queue_free();await process_frame
		var world:=Node2D.new();root.add_child(world)
		var assembler:=PlainsRegionAssembler.new();assembler.region_state=PlainsRegionState.new();world.add_child(assembler)
		check(assembler.build(m,tuning).get("ok",false),"Actual full formal assembler builds joint polygon banks")
		await physics_frame;await process_frame
		var facts:=assembler.joint_collision_snapshot()
		check(facts.size()==2,"Exactly two actual bank polygon owners")
		for fact:Dictionary in facts:
			check(not fact.disabled and not fact.one_way and fact.collision_layer==1,"Actual bank solid collision enabled on original floor layer")
			check(fact.world_points.size()>4,"Actual continuous shoulder/underside collision is not rectangle")
			var world_polygon:=PackedVector2Array()
			for raw:Array in fact.world_points:world_polygon.append(Vector2(raw[0],raw[1]))
			var original_gap:=Rect2(Vector2(float(target.offset[0])+300.0,float(target.offset[1])),Vector2(260.0,720.0))
			check(overlap_area(world_polygon,original_gap)==0.0,"Actual full bank polygon does not narrow original260px protected action gap")
			var dangers_clear:=true
			for danger:Rect2 in original.danger_bounds:dangers_clear=dangers_clear and overlap_area(world_polygon,Rect2(Vector2(target.offset[0],target.offset[1])+danger.position,danger.size))==0.0
			check(dangers_clear,"Actual full bank polygon does not fill original lower damage volume")
			var protected_clear:=true
			for space:Dictionary in context.protected_actual_airspace:
				var raw:Array=space.rect
				protected_clear=protected_clear and overlap_area(world_polygon,Rect2(raw[0],raw[1],raw[2],raw[3]))==0.0
			check(protected_clear,"Actual bank preserves original ferry/saw envelopes and shaft player-path clearance")
			var triangles:=Geometry2D.triangulate_polygon(world_polygon)
			var filled:=not triangles.is_empty()
			for index:int in range(0,triangles.size(),3):
				filled=filled and actual_solid_at(world,(world_polygon[triangles[index]]+world_polygon[triangles[index+1]]+world_polygon[triangles[index+2]])/3.0)
			check(filled,"Actual full-bank triangle-centroid samples hit enabled nononeway solid collision")
			check(fact.build_mode==CollisionPolygon2D.BUILD_SOLIDS and fact.replaced_slabs.size()==3 and fact.replaced_slabs.all(func(row:Dictionary)->bool:return row.get("disabled",false) and not row.get("one_way",true)),"Actual3 original slabs disabled; whole polygons own solid collision")
			var local_polygon:=PackedVector2Array()
			for raw:Array in fact.source.points:local_polygon.append(Vector2(raw[0],raw[1]))
			var slab:Rect2=original.platforms[0 if fact.source.source_role=="bank_left" else 1]
			for x:float in [slab.position.x+0.01,slab.end.x-0.01]:
				for y:float in [600.01,639.99]:check(Geometry2D.is_point_in_polygon(Vector2(x,y),local_polygon),"Entire original40px slab retained inside real physical contour")
		var gap_query:=PhysicsPointQueryParameters2D.new()
		gap_query.position=Vector2(float(target.offset[0])+430.0,float(target.offset[1])+620.0)
		gap_query.collision_mask=1
		check(world.get_world_2d().direct_space_state.intersect_point(gap_query).is_empty(),"Actual physics query confirms no floor closes original action gap")

		var module:PlatformingModule
		for item:PlatformingModule in assembler.modules:
			if item.name==str(target.id).replace("/","_"):module=item
		check(module!=null,"Actual target module found")
		if module!=null:
			for index:int in 2:check((module.get_node("Platform%d/CollisionShape2D"%index) as CollisionShape2D).disabled,"Original parallel rectangle collision disabled")
		var join_shape:=assembler.get_node(str(context.neighbor_join_node).replace("/","_").path_join("Platform0/CollisionShape2D")) as CollisionShape2D
		check(join_shape.disabled and (join_shape.shape as RectangleShape2D).size==Vector2(360,32),"Original32px neighbor cap geometry retained with new single collision owner")
		var right_fact:Dictionary=facts.filter(func(row:Dictionary)->bool:return row.source.source_role=="bank_right")[0]
		var right_polygon:=PackedVector2Array()
		for point:Array in right_fact.world_points:right_polygon.append(Vector2(point[0],point[1]))
		var join_rect:=Rect2(join_shape.global_position-Vector2(180,16),Vector2(360,32))
		var cap_inside:=true
		for x:float in [join_rect.position.x+0.01,join_rect.end.x-0.01]:
			for y:float in [join_rect.position.y+0.01,join_rect.end.y-0.01]:cap_inside=cap_inside and Geometry2D.is_point_in_polygon(Vector2(x,y),right_polygon)
		check(cap_inside,"Complete original32px join cap lies inside new physical receiving mass")
		rows.append({"root_seed":root_seed,"baseline_manifest":plain.manifest,"candidate_manifest":m,"plan":joint.regional_art_plan,"actual_collisions":facts})
		world.queue_free();await process_frame;await process_frame
	var cut:Array=PlainsJointRecoilPlan.clip_supports([[-1.0,600.0,802.0,260.0]],[[0.0,600.0,800.0,260.0]])
	check(cut.size()==2 and float(cut[0][2])==1.0 and float(cut[1][2])==1.0,"Exact clipping preserves both 1px outside ownership strips")
	var file:=FileAccess.open("res://build/plains_joint_recoil/contract.json",FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify({"assertions":assertions,"failures":failures,"actual":rows})+"\n")
	else:check(false,"Can save actual contract")
	print("PLAINS JOINT RECOIL CONTRACT: %d assertions, %d failures"%[assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
