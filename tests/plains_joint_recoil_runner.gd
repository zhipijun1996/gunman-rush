extends SceneTree
# PR87 actual frozen manifests: scan/actual.json and contracts/20261018T165911Z.
# Keep the original default and deep-profile digest guard independent of v5.
const PRIOR_MANIFESTS:Dictionary={
	"joint-recoil-01":{"default":"98a71fc9d52471dfbc8ec6b25dfb09d1a1326d158cd9dbc71367966ef0ec2a51","deep":"a8e7bf5fffeb893539711577b0fb7c0809e42c9d425e7f20c48f673e5576d5f8"},
	"joint-recoil-07":{"default":"d5c548f7d177852e42b52cfed73146096e3439ee93162784e2640b5e1f280da3","deep":"29f81cfa36891e15a06e9006c0353d0473a1343106514228f0ff90d3682e5e6d"}
}
var assertions:=0
var failures: Array[String]=[]
var negative_motor:PlayerMotor
var negative_controller:PlayerController
var negative_shots:=0
var negative_continuous:=true
var negative_previous:=Vector2.ZERO
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
func packed(points:Array)->PackedVector2Array:
	var result:=PackedVector2Array()
	for point:Array in points:result.append(Vector2(float(point[0]),float(point[1])))
	return result
func polygon_area(points:PackedVector2Array)->float:
	var area:=0.0
	for index:int in points.size():area+=points[index].cross(points[(index+1)%points.size()])
	return absf(area)*0.5
func verify_environment_support(local:Dictionary)->void:
	var spec:Dictionary=local.semantic_source
	check(spec.environment_program.source_order=="actions_and_environment_before_span_embedding_and_platform_definition","Environment program exists before module geometry projection")
	check(not spec.get("front_voids",[]).is_empty() and spec.front_voids[0].kind=="creek_gallery" and spec.rear_openings.all(func(opening:Dictionary)->bool:return opening.kind!="creek_gallery"),"Traversable creek foreground air is distinct from rear sky opening")
	var rooted_walls:Array=[]
	for wall:Dictionary in spec.rear_walls:
		var points:=packed(wall.points)
		var root_contact:=0.0
		for index:int in points.size():
			var a:=points[index];var b:=points[(index+1)%points.size()]
			if a.y==float(wall.root_y) and b.y==float(wall.root_y):root_contact+=absf(b.x-a.x)
		check(wall.collision==false and (root_contact>0.0)==wall.anchored_to_root and root_contact==float(wall.root_contact_length),"Rear volume actual world-base edge verifies declared anchoring without adding collision")
		if root_contact>0.0:rooted_walls.append(wall)
		for opening:Dictionary in spec.rear_openings:
			var filled_opening:=0.0
			for overlap:PackedVector2Array in Geometry2D.intersect_polygons(points,packed(opening.points)):filled_opening+=polygon_area(overlap)
			check(filled_opening<0.01,"Actual rear substrate geometry keeps its designated sky windows open")
	for front:Dictionary in spec.front_volumes:
		var anchored_overlap:=0.0
		for wall:Dictionary in rooted_walls:
			for overlap:PackedVector2Array in Geometry2D.intersect_polygons(packed(front.points),packed(wall.points)):anchored_overlap+=polygon_area(overlap)
		var relation:Dictionary={}
		for item:Dictionary in spec.support_relations:
			if item.from_volume==front.volume_id:relation=item
		check(not relation.is_empty() and relation.valid and anchored_overlap>100.0 and absf(anchored_overlap-float(relation.overlap_area))<0.01,"Front entity genuinely intersects anchored substrate, rather than declaring a support label")
	var broken:Dictionary=local.duplicate(true)
	broken.rear_walls[0].points=broken.rear_walls[0].points.map(func(point:Array)->Array:return [float(point[0])+10000.0,point[1]])
	check(not PlainsJointRecoilPlan.errors(broken).is_empty(),"Detached backing geometry is rejected even when support labels remain unchanged")

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
func negative_tick(count:int=1)->void:
	for unused:int in count:
		await physics_frame
		negative_controller.physics_tick(1.0/60.0)
		if negative_motor.global_position.distance_to(negative_previous)>30.0:negative_continuous=false
		negative_previous=negative_motor.global_position

func verify_no_shot(world:Node2D,module:PlatformingModule)->void:
	negative_motor=load("res://scenes/player/player.tscn").instantiate() as PlayerMotor
	negative_motor.position=module.world_entry()
	world.add_child(negative_motor)
	negative_controller=negative_motor.get_node("Controller") as PlayerController
	negative_controller.set_physics_process(false)
	negative_motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	negative_shots=0;negative_continuous=true;negative_previous=negative_motor.global_position
	negative_controller.shoot_ability.shot_fired.connect(func(_direction:Vector2,_id:int)->void:negative_shots+=1)
	await negative_tick(3)
	check(negative_motor.is_on_floor(),"New environment actual no-shot fixture starts grounded at real entry")
	var driver:=load("res://tests/branch_module_driver.gd").new() as RefCounted
	driver.set("module",module);driver.set("motor",negative_motor);driver.set("controller",negative_controller);driver.set("tick_callback",negative_tick)
	check(not await driver.call("recoil_span",false),"Original one-jump no-shot input still fails against actual new environment physics")
	check(negative_shots==0 and negative_continuous and negative_motor.global_position.y>module.world_exit().y+100.0,"New environment no-shot negative has zero projectiles, no relocation and misses far bank")
	negative_motor.queue_free();await process_frame

func _initialize()->void:run.call_deferred()
func run()->void:
	var rows:Array=[]
	var tuning:=PlayerTuning.load_default()
	for root_seed:String in ["joint-recoil-01","joint-recoil-07"]:
		var seed:=PlainsRegionCampaign.seed_for(root_seed,1)
		var default_generator:=PlainsRegionGenerator.new()
		default_generator.root_bell_mode="v3"
		var ordinary:=default_generator.generate(seed,tuning,false,"","intro")
		check(ordinary.get("ok",false) and ordinary.manifest.manifest_hash==PRIOR_MANIFESTS[root_seed]["default"],root_seed+": frozen PR87 default Manifest unchanged")
		var plain:=PlainsRegionArtPlan.generate(seed,tuning)
		check(plain.get("ok",false) and plain.manifest.manifest_hash==PRIOR_MANIFESTS[root_seed].deep,root_seed+": frozen PR87 nonjoint deep-profile Manifest unchanged")
		var joint:=PlainsRegionArtPlan.generate(seed,tuning,"intro","",true)
		check(plain.get("ok",false) and joint.get("ok",false),root_seed+": actual candidate generation")
		if not plain.get("ok",false) or not joint.get("ok",false):continue
		var m:Dictionary=joint.manifest
		var replay:Dictionary=JSON.parse_string(JSON.stringify(m))
		check(PlainsRegionGenerator.new().validate(replay,tuning),root_seed+": original formal JSON Manifest replay")
		var replay_plan:Dictionary=JSON.parse_string(JSON.stringify(joint.regional_art_plan))
		check(PlainsRegionArtPlan.validate_recorded(replay_plan,replay),root_seed+": source-bound companion JSON replay")
		var prior_connections:Array=m.connections.duplicate(true)
		for connection:Dictionary in prior_connections:connection.erase("environment_program")
		check(plain.manifest.areas==m.areas and plain.manifest.connections==prior_connections,root_seed+": every original topology/connection field unchanged; only explicit environment program added")
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
		verify_environment_support(target.joint_recoil)
		var physical_ownership:Array=PlainsJointRecoilPlan.instantiate(target).cutout_rects
		check(PlainsJointRecoilPlan.instantiate(target).cutout_rects==target.joint_recoil.cutout_rects.map(func(r:Array)->Array:return [float(r[0])+float(target.offset[0]),float(r[1])+float(target.offset[1]),r[2],r[3]]),"Versioned environment source owns exact world physics domains")
		check(float(context.receiving_width)>0.0 and float(context.root_depth)>0.0 and float(context.root_depth)<=float(context.available_root_depth),"Environment source fits actual authorized route clearance")
		check(context.owned_slabs==[{"node_id":target.id,"platform_index":0},{"node_id":target.id,"platform_index":1},{"node_id":context.neighbor_join_node,"platform_index":0}],"Exactly two target caps and one original32px join transfer ownership")
		var formal_shallow:=PlainsGroundSupports.region_plan(m)
		check(PlainsJointRecoilPlan.clip_supports(formal_shallow,physical_ownership)==m.ground_supports,"v5 explicit whole-region shallow-support baseline is exact formal consumer output minus source ownership")
		check(m.environment_coverage.support_baseline=="formal_shallow_supports" and m.environment_coverage.physics_scope=="whole_region_support_baseline_plus_owned_landform","v5 declares expanded support physics scope instead of claiming local-only replacement")
		var original:=PlainsRegionGenerator.definition(baseline_target)
		var changed:=PlainsRegionGenerator.definition(target)
		var same_standing:=original.platforms.size()==changed.platforms.size()
		for slab_index:int in original.platforms.size():
			same_standing=same_standing and original.platforms[slab_index].position==changed.platforms[slab_index].position and original.platforms[slab_index].size.x==changed.platforms[slab_index].size.x
		check(same_standing and original.danger_bounds==changed.danger_bounds,"Original flat standing lines, widths and lower danger unchanged; v5 explicitly replaces legacy40px slab thickness")
		var broken:Dictionary=target.joint_recoil.duplicate(true)
		broken.terrain_bodies[0].points[0][1]+=20
		check(not PlainsJointRecoilPlan.errors(broken).is_empty(),"Altered entity standing geometry rejected, not hidden by decoration")
		var damaged:Dictionary=m.duplicate(true)
		for bad:Dictionary in damaged.nodes:
			if bad.id==target.id:bad.joint_recoil=broken
		damaged.manifest_hash=PlainsRegionGenerator.new()._hash(damaged)
		var negative_world:=Node2D.new();root.add_child(negative_world)
		var rejector:=PlainsRegionAssembler.new();negative_world.add_child(rejector)
		check(not rejector.build(damaged,tuning).get("ok",false) and rejector.modules.is_empty(),"Actual consumer rejects rehashed source alteration before installing collision")
		negative_world.queue_free();await process_frame
		var world:=Node2D.new();root.add_child(world)
		var assembler:=PlainsRegionAssembler.new();assembler.region_state=PlainsRegionState.new();world.add_child(assembler)
		check(assembler.build(m,tuning).get("ok",false),"Actual full formal assembler builds joint polygon banks")
		await physics_frame;await process_frame
		var facts:=assembler.joint_collision_snapshot()
		check(facts.size()==target.joint_recoil.terrain_bodies.size(),"Exactly one actual polygon owner per environment source entity")
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
			check(fact.build_mode==CollisionPolygon2D.BUILD_SOLIDS and fact.replaced_slabs.size()==context.owned_slabs.size() and fact.replaced_slabs.all(func(row:Dictionary)->bool:return row.get("disabled",false) and not row.get("one_way",true)),"All explicitly owned original slabs disabled; environment polygons own solid collision")
			var exact_source:Dictionary={}
			for body:Dictionary in target.joint_recoil.terrain_bodies:
				if body.source_role==fact.source.source_role:exact_source=body
			check(not exact_source.is_empty() and fact.source==exact_source,"Actual polygon retains exact environment entity source")
		# The old full40px rectangular containment assertion belongs to v4.
		# v5 is explicitly24px compatibility projection with environment-derived
		# exposed sides. Test real24x36 player contact rather than the old slab.
		var player_scene:=load("res://scenes/player/player.tscn") as PackedScene
		var player:=player_scene.instantiate() as PlayerMotor
		var player_shape:=(player.get_node("CollisionShape2D") as CollisionShape2D).shape
		check(player_shape is RectangleShape2D and (player_shape as RectangleShape2D).size==Vector2(24,36),"Actual player collision resource is24x36 rectangle, not an invented capsule")
		var half_height:float=(player_shape as RectangleShape2D).size.y*0.5
		for plane:Dictionary in target.joint_recoil.semantic_source.landing_planes:
			for ratio:float in [0.05,0.5,0.95]:
				var center:=Vector2(float(target.offset[0])+lerpf(float(plane.a[0]),float(plane.b[0]),ratio),float(target.offset[1])+float(plane.a[1])-half_height)
				var query:=PhysicsShapeQueryParameters2D.new()
				query.shape=player_shape;query.collision_mask=1
				query.transform=Transform2D(0.0,center-Vector2(0,0.25))
				var clear_above:=world.get_world_2d().direct_space_state.intersect_shape(query).is_empty()
				query.transform=Transform2D(0.0,center+Vector2(0,0.25))
				check(clear_above and not world.get_world_2d().direct_space_state.intersect_shape(query).is_empty(),"Actual player shape clears above and contacts below each precise standing plane")
		player.free()

		var gap_query:=PhysicsPointQueryParameters2D.new()
		gap_query.position=Vector2(float(target.offset[0])+430.0,float(target.offset[1])+620.0)
		gap_query.collision_mask=1
		check(world.get_world_2d().direct_space_state.intersect_point(gap_query).is_empty(),"Actual physics query confirms no floor closes original action gap")

		var module:PlatformingModule
		for item:PlatformingModule in assembler.modules:
			if item.name==str(target.id).replace("/","_"):module=item
		check(module!=null,"Actual target module found")
		if module!=null:
			for owned:Dictionary in context.owned_slabs:
				var owned_shape:=assembler.get_node(str(owned.node_id).replace("/","_").path_join("Platform%d/CollisionShape2D"%int(owned.platform_index))) as CollisionShape2D
				check(owned_shape!=null and owned_shape.disabled,"Source-owned compatibility rectangle collision disabled")
		var join_shape:=assembler.get_node(str(context.neighbor_join_node).replace("/","_").path_join("Platform0/CollisionShape2D")) as CollisionShape2D
		check(join_shape.disabled and (join_shape.shape as RectangleShape2D).size==Vector2(360,32),"Original32px neighbor cap geometry retained with new single collision owner")
		var join_rect:=Rect2(join_shape.global_position-Vector2(180,16),Vector2(360,32))
		var join_top_solid:=true
		for ratio:float in [0.01,0.5,0.99]:
			join_top_solid=join_top_solid and actual_solid_at(world,Vector2(lerpf(join_rect.position.x,join_rect.end.x,ratio),join_rect.position.y+0.01))
		check(join_top_solid,"Original receiving join standing line is supported by actual new environment solids")

		if module!=null:await verify_no_shot(world,module)
		rows.append({"root_seed":root_seed,"baseline_manifest":plain.manifest,"candidate_manifest":m,"plan":joint.regional_art_plan,"actual_collisions":facts,"support_scope_change":{"prior_deep":plain.manifest.ground_supports,"formal_shallow_before_owned_cutout":formal_shallow,"candidate":m.ground_supports,"scope":m.environment_coverage.physics_scope}})
		world.queue_free();await process_frame;await process_frame
	var cut:Array=PlainsJointRecoilPlan.clip_supports([[-1.0,600.0,802.0,260.0]],[[0.0,600.0,800.0,260.0]])
	check(cut.size()==2 and float(cut[0][2])==1.0 and float(cut[1][2])==1.0,"Exact clipping preserves both 1px outside ownership strips")
	var file:=FileAccess.open("res://build/plains_joint_recoil/contract.json",FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify({"assertions":assertions,"failures":failures,"actual":rows})+"\n")
	else:check(false,"Can save actual contract")
	print("PLAINS JOINT RECOIL CONTRACT: %d assertions, %d failures"%[assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
