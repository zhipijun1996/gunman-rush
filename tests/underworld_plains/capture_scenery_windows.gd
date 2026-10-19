extends SceneTree
## Positioned visual inspection of the real formal consumer; not route traversal.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	var app := DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	await process_frame
	app.start_plains("level-design-v2-baseline/08")
	for n: int in 10: await physics_frame
	var stage := app.stage as PlainsRegionStage
	if stage == null or not stage.assembly_ok: push_error("Real formal stage failed"); quit(1); return
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
	var receipt: Array[Dictionary] = []
	for point: Dictionary in points:
		app.controller.return_to_segment(point.position)
		for n: int in 10: await physics_frame
		await RenderingServer.frame_post_draw
		var path := "res://build/underworld_plains/golden_"+str(point.id)+".png"
		var err := root.get_texture().get_image().save_png(path)
		if err!=OK: push_error("GPU screenshot failed");quit(1);return
		var parallax := app.get_node("PixelPlainsParallax") as UnderworldParallax
		var scenery := stage.get_node("PixelRegionScenery") as UnderworldScenery
		receipt.append({"point":point,"camera_center":app._run_camera.get_screen_center_position(),"layers":parallax.measured_nodes(),"decor":scenery.presentation_manifest,"image":path,"traversal_claim":false})
	var f := FileAccess.open("res://build/underworld_plains/scenery_golden_receipts.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema":"underworld-golden-scenery-v1","actual_formal_consumer":true,"fixture":true,"seed":"level-design-v2-baseline/08","map":1,"samples":receipt},"\t"))
	f.close()
	app.free()
	print("Underworld actual golden scenery windows: ",receipt.size())
	quit(0)
