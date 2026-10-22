extends SceneTree
## Actual formal consumers; positioning/camera sweeps are diagnostic, not routes.
var app: DemoApp
var output := "res://build/fine_space_05/captures"
var quick := false
var rows: Array[Dictionary]=[]
var failures: Array[String]=[]

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg=="--quick": quick=true
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	run_capture.call_deferred()

func check(value: bool,label: String) -> void:
	if not value: failures.append(label);printerr("SPACE_FAIL "+label)

func new_app(region: String,map_index: int,seed_value: String) -> void:
	if is_instance_valid(app):
		app.abandon_run()
		await load("res://tests/audio_teardown.gd").drain_world(app)
		app.free();await process_frame
	app=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	await process_frame
	if region=="home":app._show_home()
	else:check(app.start_debug_region(StringName(region),map_index,seed_value),"real formal debug entry accepted")
	for i: int in 8:
		await physics_frame
		await process_frame
	freeze(app)

func freeze(node: Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child: Node in node.get_children():freeze(child)

func refresh(node: Node) -> void:
	if node is UnderworldParallax:(node as UnderworldParallax)._update()
	if node.get_script()!=null and str(node.get_script().resource_path).ends_with("underworld_presentation.gd"):node.call("refresh")
	for child: Node in node.get_children():refresh(child)

func capture(id: String,position: Vector2,camera_position: Vector2=Vector2.INF) -> void:
	var camera: Camera2D
	if is_instance_valid(app.home_scene):
		app.home_scene.player.position=position
		camera=app.home_scene.camera
		camera.position=camera_position if camera_position.is_finite() else position
	else:
		app.controller.return_to_segment(position)
		camera=app._run_camera
		if camera_position.is_finite():camera.position=camera_position
		else:app._run_camera.snap_to_target()
	camera.force_update_scroll();refresh(app)
	for i: int in 3:await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+id+".png")==OK,"actual PNG saved "+id)
	var record: Dictionary={"id":id,"position":[position.x,position.y],"camera":[camera.get_screen_center_position().x,camera.get_screen_center_position().y],"viewport":[root.size.x,root.size.y],"positioned_still":true,"presentation":[],"parallax":[]}
	collect(app,record)
	if app.stage is PlainsRegionStage:
		record["seed"]=app.director.seed;record["map_index"]=app.director.region_map_index
		record["manifest"]=(app.stage as PlainsRegionStage).generated.manifest.manifest_hash
		record["geometry_solids"]=PlainsRegionScenery.solid_supports(app.stage as PlainsRegionStage).size()
	rows.append(record)
	print("SPACE_CAPTURE "+id)

func collect(node: Node,record: Dictionary) -> void:
	if node is UnderworldParallax and (node as UnderworldParallax).visible:
		record.parallax.append_array((node as UnderworldParallax).measured_nodes())
	if node.get_script()!=null and str(node.get_script().resource_path).ends_with("underworld_presentation.gd"):record.presentation.append(node.call("receipt"))
	if node is UnderworldTerrain:
		var terrain:=node as UnderworldTerrain
		check(terrain.core_layer.tile_set.tile_size==Vector2i(32,32) and terrain.core_layer.scale==Vector2.ONE,"formal native32 terrain/grid1")
	if node is UnderworldHomeWorld:
		record["home_placements"]=(node as UnderworldHomeWorld).placements.duplicate(true)
	for child: Node in node.get_children():collect(child,record)

func run_capture() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	await new_app("home",1,"")
	await capture("home",Vector2(440,414),Vector2(640,310))
	if not quick:
		await capture("home_east",Vector2(2920,414),Vector2(2640,310))
		await capture("home_upper",Vector2(880,222),Vector2(1020,230))
	var seeds: Array[String]=["level-design-v2-baseline/08","fine-space-05/valley","fine-space-05/highland"]
	if quick:seeds.resize(1)
	for seed_index: int in seeds.size():
		for map_index: int in ([1] if quick else [1,2]):
			await new_app("plains",map_index,seeds[seed_index])
			var stage:=app.stage as PlainsRegionStage
			if stage==null:check(false,"formal stage exists");continue
			var prefix: String="s%d_m%d_"%[seed_index,map_index]
			await capture(prefix+"spawn",stage.spawn)
			if not quick:
				var low: Dictionary=stage.generated.manifest.areas[0]
				var high: Dictionary=low
				for area: Dictionary in stage.generated.manifest.areas:
					if float(area.position[1])>float(low.position[1]):low=area
					if float(area.position[1])<float(high.position[1]):high=area
				await capture(prefix+"high",Vector2(high.position[0],high.position[1])-Vector2(0,18))
				await capture(prefix+"low",Vector2(low.position[0],low.position[1])-Vector2(0,18))
				for area: Dictionary in stage.generated.manifest.areas:
					if str(area.get("role",""))=="junction":
						await capture(prefix+"junction",Vector2(area.position[0],area.position[1])-Vector2(0,18));break
				if seed_index==0:
					for latch: Node in stage.assembler.find_children("*","Node2D",true,false):
						if latch is ShotLatch:
							await capture(prefix+"bell",(latch as ShotLatch).to_global((latch as ShotLatch).bell_position)+Vector2(-140,50));break
	await new_app("thorn_forest",1,"fine-space-05/baseline")
	if app.stage is PlainsRegionStage:await capture("forest",app.stage.spawn)
	else:check(false,"shared forest renderer remains live")
	FileAccess.open(output+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"task":"FINE-SPACE-05","scope":"real formal App positioned stills across seeds/maps; not human traversal/motion/device/art acceptance","failures":failures,"captures":rows},"  "))
	app.abandon_run();await load("res://tests/audio_teardown.gd").drain_world(app)
	app.free()
	for i: int in 4:await process_frame
	print("SPACE_CAPTURE_DONE count=%d failures=%d"%[rows.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)
