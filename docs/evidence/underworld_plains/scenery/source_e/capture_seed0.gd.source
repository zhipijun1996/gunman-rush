extends SceneTree
## Positioned visual inspection of the real formal consumer; not route traversal.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	var app := DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	await process_frame
	app.start_plains("underworld-formal/0")
	var map_index := 2 if "--scenery-map=2" in OS.get_cmdline_user_args() else 1
	if map_index==2:
		app.director.stage_index=2
		app._load_stage()
	for n: int in 10: await physics_frame
	var stage := app.stage as PlainsRegionStage
	if stage == null or not stage.assembly_ok: push_error("Real formal stage failed"); quit(1); return
	var rays: Array[Dictionary] = []
	for sprite: Node in stage.get_node("PixelRegionScenery").get_children():
		if not sprite is Sprite2D or not sprite.has_meta("landmark"): continue
		var bounds := Rect2(sprite.global_position,sprite.texture.get_size()*sprite.global_scale)
		var foot := Vector2(bounds.get_center().x,bounds.end.y)
		var hit := app.player.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(foot-Vector2(0,1),foot+Vector2(0,3),1))
		var ok := not hit.is_empty() and hit.collider is StaticBody2D
		rays.append({"identity":sprite.get_meta("landmark").identity,"actual_bottom_center":foot,"hit_static_body":ok,"collider":str(hit.collider.get_path()) if ok else ""})
		if not ok: push_error("Actual landmark bottom-center misses static support");quit(1);return
	var points: Array[Dictionary] = [{"id":"spawn","position":stage.spawn}]
	for role: String in ["junction","creek"]:
		for area: Dictionary in stage.generated.manifest.areas:
			if str(area.role)==role:
				points.append({"id":role,"position":Vector2(float(area.position[0]),float(area.position[1]))-Vector2(0,18)})
				break
	if points.size()<3: points.append({"id":"middle","position":stage.merchant_position})
	for area: Dictionary in stage.generated.manifest.areas:
		if str(area.get("identity",""))=="creek_well":
			points.append({"id":"deep_creek","position":Vector2(float(area.position[0]),float(area.position[1]))-Vector2(0,18)})
			break
	var local := stage.get_node("PixelRegionScenery/PlainsRegionComposition") as UnderworldLocalComposition
	if local!=null and not local.compositions.is_empty():
		var root_values: Array=local.compositions[0].virtual_root
		points.append({"id":"local_creek_well","position":Vector2(root_values[0]+300,root_values[1]-140)})
	var dressing := stage.get_node("PixelRegionScenery") as UnderworldScenery
	for item: Dictionary in dressing.identity_items:
		var foot: Array=item.foot
		points.append({"id":"identity_"+str(item.identity),"position":Vector2(foot[0]+160,foot[1]-18)})
	var receipt: Array[Dictionary] = []
	for point: Dictionary in points:
		app.controller.return_to_segment(point.position)
		for n: int in 10: await physics_frame
		# Explicit camera cut for positional art inspection. The normal gameplay
		# spring remains unchanged; a previous fixture must not crop this image.
		app._run_camera.snap_to_target()
		app._run_camera.force_update_scroll()
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://build/underworld_plains/golden_"+("map2_" if map_index==2 else "")+str(point.id)+".png"
		var err := root.get_texture().get_image().save_png(path)
		if err!=OK: push_error("GPU screenshot failed");quit(1);return
		var parallax := app.get_node("PixelPlainsParallax") as UnderworldParallax
		var scenery := stage.get_node("PixelRegionScenery") as UnderworldScenery
		receipt.append({"point":point,"camera_center":app._run_camera.get_screen_center_position(),"layers":parallax.measured_nodes(),"decor":scenery.presentation_manifest,"local_compositions":local.compositions if local!=null else [],"local_issues":local.actual_issues() if local!=null else [],"image":path,"traversal_claim":false})
	var f := FileAccess.open("res://build/underworld_plains/scenery_"+("map2_" if map_index==2 else "")+"golden_receipts.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema":"underworld-golden-scenery-v1","actual_formal_consumer":true,"fixture":true,"seed":"underworld-formal/0","map":map_index,"grounded_landmark_rays":rays,"samples":receipt},"\t"))
	f.close()
	app.free()
	for n: int in 4: await process_frame
	print("Underworld actual golden scenery windows: ",receipt.size())
	quit(0)
