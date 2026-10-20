extends SceneTree
## Actual generated Stage consumer inventory; no route-completion claim.
var checks:=0
var failures:Array[String]=[]
var inventory:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok and failures.size()<40:failures.append(label);printerr("FAIL: ",label)
func coverage(art:UnderworldTerrain,p:Vector2)->bool:
	for rect:Rect2 in art.union_pieces:
		if rect.has_point(p):return true
	return false
func collider_snapshot(stage:Node)->Array:
	var rows:Array=[]
	for object:Node in stage.find_children("*","CollisionObject2D",true,false):
		var entry:Array=[str(stage.get_path_to(object)),object.collision_layer,object.collision_mask]
		for shape:Node in object.get_children():
			if shape is CollisionShape2D:
				entry.append([shape.position,shape.disabled,shape.one_way_collision,str(shape.shape)])
		rows.append(entry)
	return rows
func inspect(stage:PlainsRegionStage,seed_value:String,map_index:int)->Dictionary:
	check(stage.assembly_ok,"actual Stage assembles "+seed_value)
	check(stage.terrain_art.art is UnderworldTerrain,"actual Stage consumes UnderworldTerrain "+seed_value)
	if not stage.terrain_art.art is UnderworldTerrain:return {}
	var art:=stage.terrain_art.art as UnderworldTerrain
	var before:=collider_snapshot(stage)
	var hash_before:=JSON.stringify(stage.generated.manifest)
	var solids:=stage.terrain_art.collect_solids()
	var reference:=UnderworldTerrain.geometry_plan(solids)
	check(art.union_edges==reference.edges,"actual collected solids equal art canonical boundary")
	check(art.core_layer.tile_set.resource_path==str(UnderworldTerrain.specification().tileset),"actual permanent source TileSet consumed")
	check(art.core_layer.get_used_cells().size()==art.core_cells.size(),"every selected cell consumed by real TileMap")
	var area:=0.0
	for rect:Rect2 in art.union_pieces:area+=rect.get_area()
	var drawing_area:=float(art.core_cells.size())*1024.0
	for rect:Rect2 in art.boundary_pieces:drawing_area+=rect.get_area()
	check(is_equal_approx(area,drawing_area),"true TileMap+adapter drawing area equals disjoint canonical union")
	for rect:Rect2 in solids:
		for u:float in [.001,.25,.5,.75,.999]:
			for v:float in [.001,.25,.5,.75,.999]:
				check(coverage(art,rect.position+rect.size*Vector2(u,v)),"every actual formal body sample in union")
	var id_before:=art.get_instance_id()
	stage.terrain_art.refresh_geometry()
	check(stage.terrain_art.art.get_instance_id()==id_before,"no-op geometry retains art instance")
	check(before==collider_snapshot(stage),"presentation inventory/refresh leaves physical objects unchanged")
	check(hash_before==JSON.stringify(stage.generated.manifest),"presentation inventory/refresh leaves manifest/RNG output unchanged")
	var masks:Dictionary={}
	for key:Vector2i in art.core_cells:
		var coords:=art.core_layer.get_cell_atlas_coords(key)
		masks[str(coords)]=int(masks.get(str(coords),0))+1
	var edge_roles:Dictionary={}
	for edge:Vector4 in art.union_edges:
		var role:="T" if edge.y==edge.w and edge.z>edge.x else "B" if edge.y==edge.w else "L" if edge.w<edge.y else "R"
		edge_roles[role]=int(edge_roles.get(role,0))+1
	var corner_roles:Dictionary={}
	var corner_names:=["TL","TR","BL","BR","iTL","iTR","iBL","iBR"]
	for corner:Vector4 in art.union_corners:
		var role:String=corner_names[int(corner.z)]
		corner_roles[role]=int(corner_roles.get(role,0))+1
	var native_roles:=edge_roles.duplicate();native_roles.merge(corner_roles);native_roles["I"]=1
	return {"native_glyph_roles_from_geometry":native_roles.keys(),"distinct_native_glyph_roles_from_geometry":native_roles.size(),"adapter_corner_inventory":corner_roles,"adapter_edge_inventory":edge_roles,"native_glyph_measurement_scope":"Geometric selection inventory, not fragment-by-fragment shader readback.","seed":seed_value,"map_index":map_index,"manifest_hash":stage.generated.manifest.manifest_hash,"manifest_version":stage.generated.manifest.version,"solids":solids.size(),"union_pieces":art.union_pieces.size(),"tilemap_cells":art.core_cells.size(),"distinct_atlas_coordinates":masks.size(),"atlas_use":masks,"boundary_adapter_pieces":art.boundary_pieces.size(),"union_area":area,"tilemap_area_fraction":float(art.core_cells.size())*1024.0/area,"geometry_only":true,"route_completion":false}
func run()->void:
	var tuning:=PlayerTuning.load_default()
	var original_tuning_hash:=FileAccess.get_sha256("res://config/player_tuning.json")
	for seed_index:int in 10:
		var seed_value:="underworld-formal/%d"%seed_index
		var consumer:=DemoApp.new();consumer.meta_persistence_enabled=false;root.add_child(consumer)
		check(consumer.start_plains(seed_value),"actual formal App starts")
		for frame:int in 4:await physics_frame
		for map_index:int in [1,2]:
			if map_index==2:
				consumer.director.stage_index=2;consumer.director.region_map_index=2;consumer._load_stage()
				for frame:int in 4:await physics_frame
			var stage:=consumer.stage as PlainsRegionStage
			check(stage.map_index==map_index,"actual formal consumer selects requested region map")
			inventory.append(inspect(stage,seed_value,map_index))
			print("UNDERWORLD_FORMAL_CONSUMER ",JSON.stringify(inventory[-1]))
		if not await load("res://tests/audio_teardown.gd").drain_world(consumer):check(false,"actual App inventory audio drained")
		consumer.free()
		for frame:int in 4:await process_frame
	check(original_tuning_hash==FileAccess.get_sha256("res://config/player_tuning.json"),"unique tuning unchanged")
	# Explicit lifecycle fixture: select actual second map via DemoApp, invoke
	# actual committed Boss break callback, and observe study refresh. Not play.
	var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	check(app.start_debug_region(&"plains",2,"underworld-break-refresh"),"actual App starts second map for break fixture")
	for frame:int in 4:await physics_frame
	var stage:=app.stage as PlainsRegionStage
	var art_before:=stage.terrain_art.art as UnderworldTerrain
	var old_id:=art_before.get_instance_id()
	var old_solids:=stage.terrain_art.authored_solids.duplicate()
	var arena_nodes:=stage.find_children("*","WindkeeperArena",true,false)
	check(arena_nodes.size()==1,"actual second-map Boss bound one arena consumer")
	var break_receipt:Dictionary={}
	if arena_nodes.size()==1:
		var arena:=arena_nodes[0] as WindkeeperArena
		var cut_probe:=arena.module.position+Vector2(645,640)
		check(coverage(art_before,cut_probe),"actual bridge middle drawn before actual break")
		var refreshes: Array[int]=[0]
		stage.terrain_art.geometry_changed.connect(func() -> void:refreshes[0]+=1)
		arena._break_ground()
		# The actual observer runs in _process, independently of physics ticks.
		# Wait for its accepted event, never invoke refresh from the fixture.
		for frame:int in 8:
			if refreshes[0]>0:break
			await process_frame
		check(refreshes[0]==1,"actual geometry observer emitted one committed refresh")
		var art_after:=stage.terrain_art.art as UnderworldTerrain
		check(arena.broken,"actual arena callback committed")
		check(art_after.get_instance_id()!=old_id,"geometry observer replaced actual material after break")
		check(stage.terrain_art.authored_solids!=old_solids,"geometry observer collected changed real bodies")
		check(not coverage(art_after,cut_probe),"broken bridge middle is no longer painted")
		check(stage.terrain_art.authored_solids==stage.terrain_art.collect_solids(),"refresh uses current actual geometry")
		break_receipt={"actual_app":true,"map_index":2,"explicit_callback_fixture":true,"route_completion":false,"manifest_hash":stage.generated.manifest.manifest_hash,"before_solids":old_solids.size(),"after_solids":stage.terrain_art.authored_solids.size(),"probe":cut_probe,"after_tilemap_cells":art_after.core_cells.size()}
	if not await load("res://tests/audio_teardown.gd").drain_world(app):check(false,"actual App audio teardown drained")
	app.free()
	for frame:int in 4:await process_frame
	var result:={"checks":checks,"failures":failures,"consumers":inventory,"break_fixture":break_receipt,"scope":"20 actual formal Stage geometries and one App Boss lifecycle callback fixture; no real route traversal, aesthetic/device/full gameplay approval."}
	DirAccess.make_dir_recursive_absolute("res://build/underworld_plains/terrain")
	FileAccess.open("res://build/underworld_plains/terrain/formal_result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("UNDERWORLD_FORMAL_TERRAIN checks=",checks," failures=",failures.size()," consumers=",inventory.size())
	quit(0 if failures.is_empty() else 1)
