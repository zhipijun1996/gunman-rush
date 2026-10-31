extends SceneTree
## Isolated legal initial-spawn fixture over actual generated formal geometry.
## Not evidence that the normal route reaches the banks' undersides.
const PLAYER := preload("res://game/player/player.tscn")
var output := "res://build/painted_terrain/underside_head"
var world: Node2D
var results: Array=[]
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output)
	for source_column: int in [768,896]:
		await probe(source_column)
	var file := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"two isolated initial-spawn PlayerMotor fixtures below existing generated banks; not normal-route arrival","results":results}));file.close()
	if results.size()!=2:quit(1);return
	print("PASS: painted underside head fixture: two real scheduled PlayerMotor ceiling contacts; calibrated source columns bound to physical bottom")
	quit()
func probe(source_column: int) -> void:
	world=Node2D.new();root.add_child(world)
	var tuning := PlayerTuning.load_default()
	var generated := PlainsRegionGenerator.new().generate(PlainsRegionCampaign.seed_for("level-design-v2-baseline/08",1),tuning,false,"","intro")
	assert(generated.ok)
	var assembler := PlainsRegionAssembler.new()
	assembler.region_state=PlainsRegionState.new();assembler.region_state.bind_map(str(generated.manifest.manifest_hash));world.add_child(assembler)
	assert(assembler.build(generated.manifest,tuning).ok)
	var solids: Array[Rect2]=[]
	for module: PlatformingModule in assembler.modules:
		module.terrain_candidate_preview=true;module.queue_redraw()
		for i: int in module.definition.platforms.size():
			if i not in module.definition.one_way_platform_indices:solids.append(Rect2(module.position+module.definition.platforms[i].position,module.definition.platforms[i].size))
	solids.append_array(assembler.ground_supports.columns);assembler.ground_supports.hide()
	var groups := PlainsTerrainFamilySampler.groups(solids)
	var spawn := Vector2(generated.manifest.spawn[0],generated.manifest.spawn[1])
	groups.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.bounds.get_center().distance_to(spawn)<b.bounds.get_center().distance_to(spawn))
	var group: Dictionary=groups[1]
	var bounds: Rect2=group.bounds
	var adapter := load("res://experiments/terrain/art/painted_formal_terrain_sample.gd").new() as Node2D
	var outline: Array=adapter.call("_outline",group.faces);adapter.free()
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://game/presentation/world/resources/visual_development/painted_terrain_candidate.json"))
	var spec: Dictionary=catalog.terrain.grammar.duplicate(true);spec.source_x_offsets={"head_shore":287};spec.face_patches=[];spec.visible_underside=catalog.formal_second_space.visible_underside
	var grammar := load("res://game/presentation/world/art/painted_terrain_grammar.gd").new() as Node2D
	grammar.call("configure",{"solid_polygons":[{"id":"head_shore","points":outline}],"top_polylines":[{"id":"head_grass","points":[[bounds.position.x,bounds.position.y],[bounds.end.x,bounds.position.y]]}]},spec);world.add_child(grammar)
	var x := bounds.position.x+(source_column-float(spec.visible_underside.source_start))/float(spec.source_pixels_per_world_unit)
	var floor_body := StaticBody2D.new();floor_body.position=Vector2(x,bounds.end.y+110)
	var floor_shape := CollisionShape2D.new();var rectangle := RectangleShape2D.new();rectangle.size=Vector2(160,20);floor_shape.shape=rectangle;floor_body.add_child(floor_shape);world.add_child(floor_body)
	var player := PLAYER.instantiate() as PlayerMotor
	player.position=Vector2(x,bounds.end.y+70);world.add_child(player)
	player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	var controller := player.get_node("Controller") as PlayerController
	var camera := Camera2D.new();camera.position=Vector2(x,bounds.end.y-20);camera.zoom=Vector2.ONE*2;world.add_child(camera);camera.make_current()
	for unused: int in 20:await physics_frame;await process_frame
	assert(player.is_on_floor())
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	controller.router.request_action(&"jump")
	var contact := false
	var contact_y := INF
	for tick: int in 90:
		await physics_frame;await process_frame
		if player.is_on_ceiling():
			contact=true;contact_y=player.position.y-18
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("head_%s.png"%source_column))
			break
	assert(contact,"Normal scheduled Motor must hit actual ceiling")
	assert(absf(contact_y-bounds.end.y)<1,"Head contact must match unchanged formal bottom")
	var original := (load(str(spec.visible_underside.texture)) as Texture2D).get_image()
	var actual_bottom := 0
	for y: int in range(original.get_height()-1,-1,-1):
		if original.get_pixel(source_column,y).a>=128.0/255.0:actual_bottom=y;break
	var metadata := (grammar.call("_bottom_profile",load(str(spec.visible_underside.texture))) as Texture2D).get_image()
	var encoded := metadata.get_pixel(source_column,0)
	var decoded := roundi(encoded.r*255)*256+roundi(encoded.g*255)
	assert(decoded==actual_bottom)
	results.append({"source_column":source_column,"source_alpha128_bottom":actual_bottom,"legacy_constant_bottom_invisible_depth_world":(645.0-actual_bottom)/float(spec.source_pixels_per_world_unit),"calibrated_invisible_depth_world":absf(float(decoded-actual_bottom))/float(spec.source_pixels_per_world_unit),"actual_ceiling_y":bounds.end.y,"player_head_contact_y":contact_y,"actual_body_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"initial_spawn_only":true,"manual_controller_step":false})
	world.free();await process_frame
