extends SceneTree
var assertions := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; printerr("TERRAIN CHECK FAILED: "+label)
func run() -> void:
	var masks: Dictionary = {}
	for raw: int in 256:
		var mask := Blob47Rules.canonical_mask(raw)
		masks[mask] = true
		check(mask == Blob47Rules.canonical_mask(mask), "mask normalization idempotent")
	check(masks.size() == 47, "all 256 neighbourhoods map to 47")
	for id: String in TerrainMaterialRegistry.catalog().materials:
		var appearance := TerrainMaterialRegistry.appearance(id)
		check(appearance.texture != null and appearance.tileset != null,"registered resources "+id)
		check(FileAccess.file_exists(TerrainMaterialRegistry.definition(id).provenance),"provenance "+id)
	check(Blob47Rules.occupancy_mask({Vector2i.ZERO:"stone",Vector2i.RIGHT:"earth"},Vector2i.ZERO)==4,"topology ignores material value")
	var all: Array[Rect2] = [Rect2(0,0,192,96)]
	var shared := TerrainGeometry.plan(all,[])
	var first := UnderworldTerrain.build([Rect2(0,0,96,96)],shared,TerrainMaterialRegistry.appearance("windchime_plains"))
	var second := UnderworldTerrain.build([Rect2(96,0,96,96)],shared,TerrainMaterialRegistry.appearance("mill_masonry"))
	check(first.union_edges == second.union_edges,"different materials share one outer boundary")
	check(first.core_cells.has(Vector2i(2,1)),"interior beside material seam stays batched")
	var atlas: Array = UnderworldTerrain.specification().mask_to_atlas["255"]
	check(first.core_layer.get_cell_atlas_coords(Vector2i(2,1)) == Vector2i(int(atlas[0])+16,int(atlas[1])),"material neighbour uses full core not air edge")
	check(not first.core_layer.collision_enabled and not second.core_layer.collision_enabled,"no tile physics duplication")
	first.free();second.free()
	var groups: Array[Dictionary] = [{"material_id":"windchime_plains","solids":all.duplicate(),"polygons":[] as Array[Dictionary],"bare":false}]
	TerrainGeometry.paint_rect(groups,Rect2(79,0,43,96),"mill_masonry")
	groups = TerrainComposer.compact(groups)
	var area := 0.0
	for group: Dictionary in groups:
		for rect: Rect2 in group.solids: area += rect.get_area()
	check(is_equal_approx(area,192*96),"non-grid material painting preserves occupied area")
	var seams := TerrainTransitionResolver.resolve(groups)
	check(seams.size() == 2,"both non-grid material contacts derived")
	for stone_above: bool in [false,true]:
		var stacked: Array[Dictionary]=[{"material_id":"windchime_plains","solids":[Rect2(0,0,192,128)],"polygons":[],"bare":false}]
		TerrainGeometry.paint_rect(stacked,Rect2(0,0 if stone_above else 64,192,64),"mill_masonry")
		var contacts := TerrainTransitionResolver.resolve(TerrainComposer.compact(stacked))
		check(contacts.size()==1 and contacts[0].axis=="horizontal" and contacts[0].stone_on_right==stone_above,"stack orientation selects matching atlas row")
	check(WorldSurfaceStyles.choose("","F","thorn_forest")=="forest_bramble","forest surface uses bramble skin")
	check(WorldSurfaceStyles.choose("","P","mill_masonry")=="metal_spikes","masonry surface overrides plains default")
	check(WorldSurfaceStyles.choose("stone_spikes","F","thorn_forest")=="stone_spikes","explicit appearance wins over regional default")
	check(not WorldSurfaceStyles.error("missing","up").is_empty(),"unknown hazard skin rejected")
	var requests: Array = [{"id":"middle","surface_id":"bare","facing":"up","bounds":[32,-8,96,16]}]
	var bands := TerrainSurfaceResolver.bands(shared.edges,requests)
	check(bands.size() == 1 and bands[0].rect == Rect2(32,0,96,16),"middle three cells replace only exposed top")
	check(TerrainSurfaceResolver.bands(shared.edges,[{"id":"buried","surface_id":"bare","facing":"up","bounds":[32,32,64,16]}]).is_empty(),"buried surface refused by geometry")
	for face: String in ["up","down","left","right"]:
		check(TerrainSurfaceResolver.bands(shared.edges,[{"id":face,"surface_id":"bare","facing":face,"bounds":[-8,-8,208,112]}]).size() == 1,"four exposed directions "+face)
	var paint := {"version":1,"seed":7,"regions":[{"id":"stone","bounds":[32,0,96,96],"material_id":"mill_masonry"}],"surfaces":[]}
	check(TerrainPaint.validate(paint).is_empty(),"valid appearance")
	var invalid := paint.duplicate(true);invalid.regions[0].material_id="missing"
	check(TerrainPaint.validate(invalid)=="terrain_material_unknown","unknown material rejected")
	invalid=paint.duplicate(true);invalid.version=2
	check(TerrainPaint.validate(invalid)=="terrain_version_unknown","unknown version rejected")
	invalid=paint.duplicate(true);invalid.regions.append(invalid.regions[0].duplicate(true))
	check(TerrainPaint.validate(invalid)=="terrain_id_invalid","duplicate identity rejected")
	var ordered := TerrainPaint.ordered([{"id":"z","priority":0},{"id":"a","priority":0}])
	check(ordered[0].id == "a", "tie priority stable across input order")
	var polygon_groups: Array[Dictionary] = [{"material_id":"windchime_plains","solids":[] as Array[Rect2],"polygons":[{"points":[[0,0],[192,0],[192,96],[0,96]]}],"bare":false}]
	TerrainGeometry.paint_rect(polygon_groups,Rect2(32,16,64,32),"mill_masonry")
	var polygon_area := 0.0
	for group: Dictionary in polygon_groups:
		for polygon: Dictionary in group.polygons:
			var points: Array=polygon.points
			var signed_area:=0.0
			for index: int in points.size():
				var a: Array=points[index];var b: Array=points[(index+1)%points.size()]
				signed_area+=float(a[0])*float(b[1])-float(b[0])*float(a[1])
			polygon_area+=absf(signed_area)*.5
	check(is_equal_approx(polygon_area,192*96),"painting inside polygon does not fill hole twice")
	var paint_source: Array[Dictionary] = [{"material_id":"windchime_plains","solids":all.duplicate(),"polygons":[] as Array[Dictionary],"bare":false}, {"material_id":"thorn_forest","solids":[Rect2(256,0,96,96)] as Array[Rect2],"polygons":[] as Array[Dictionary],"bare":false}]
	var paint_geometry := TerrainGeometry.plan([Rect2(0,0,192,96),Rect2(256,0,96,96)],[])
	var composed_paint := TerrainComposer.compose({"geometry":paint_geometry,"groups":paint_source})
	paint.seed = 0
	var forest: Node = composed_paint._layers["thorn_forest/edge"]
	var forest_id := forest.get_instance_id()
	check(composed_paint.replace_paint(paint).is_empty(),"live material update accepted")
	check(composed_paint._layers["thorn_forest/edge"].get_instance_id()==forest_id,"unaffected material nodes retained")
	var stable_layers := composed_paint._layers.duplicate()
	check(composed_paint.replace_paint(invalid)=="terrain_id_invalid" and composed_paint._layers==stable_layers,"rejected paint preserves live nodes")
	check(composed_paint.replace_paint(paint).is_empty() and composed_paint._layers==stable_layers,"identical paint has no node churn")
	composed_paint.free()
	var count := 0
	var construction: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://config/world/construction.json"))
	var contracts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://build/world/contracts.json"))
	for row: Dictionary in construction.rooms:
		var path := "res://config/world/rooms/"+str(row.room_id)+".json"
		if not FileAccess.file_exists(path): continue
		var document := WorldRoomDocument.read(path)
		var before := JSON.stringify(document)
		if count == 0:
			var edited := TerrainPaint.with_paint(document,paint)
			var restored := WorldRoomDocument.instantiate(edited.document)
			check(not restored.has("error"),"schema2 edited appearance creates real room")
			if not restored.has("error"):
				var packed := PackedScene.new();packed.pack(restored.room)
				var roundtrip := WorldRoomDocument.extract(packed)
				check(JSON.stringify(roundtrip.root.properties.terrain_paint)==JSON.stringify(paint),"paint survives complete scene/document roundtrip")
				restored.room.free()
			var bad_doc := document.duplicate(true);bad_doc.root.properties.terrain_paint=invalid
			check(WorldRoomDocument.instantiate(bad_doc).get("error","")=="terrain_id_invalid","runtime loader rejects invalid paint")
		check(TerrainPaint.with_paint(document,invalid).has("error") and JSON.stringify(document)==before,"refused edit leaves document intact "+row.room_id)
		var result := WorldRoomDocument.instantiate(document)
		check(not result.has("error"),"legacy document migration "+row.room_id)
		if result.has("error"): continue
		var room: FixedWorldRoom=result.room
		var original_platforms := room.platforms.duplicate()
		var original_hazards := room.spike_strips.duplicate(true)
		var contract: Dictionary=contracts.rooms.filter(func(c:Dictionary)->bool:return c.room_id==row.room_id)[0]
		room.configure(contract)
		# Same boundary inputs as _ready, without other content side effects.
		var boundary := WorldRoomSpace.boundary_platforms(room.contract.world_geometry,room.doors)
		room.boundary_art_rock = WorldRoomSpace.exterior_fill(room.contract.world_geometry,room.doors)
		room.boundary_art_rock.append_array(boundary)
		room.platforms.append_array(boundary)
		var started := Time.get_ticks_msec()
		var composed := TerrainComposer.build(room)
		check(composed.get_child_count()>0,"formal composed terrain "+row.room_id)
		check(room.platforms.slice(0,original_platforms.size())==original_platforms and room.spike_strips==original_hazards,"geometry and danger unchanged "+row.room_id)
		check(composed.find_children("*","CollisionObject2D",true,false).is_empty(),"composition owns no physics "+row.room_id)
		print("TERRAIN ROOM ",row.room_id," groups=",composed.groups.size()," seams=",composed.seams.size()," ms=",Time.get_ticks_msec()-started)
		composed.free();room.free();count+=1
	check(count==44,"all 44 authored rooms migrated")
	print("TERRAIN MATERIALS: ",assertions," assertions, ",failures," failures")
	quit(1 if failures else 0)
