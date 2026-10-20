extends SceneTree
## G2 visual fixtures only: a fresh formal App for each observation bank.
## Initial segment placement is explicit; these images do not prove traversal.
var layout := "forest-fruit-routes-v14"
var output := "res://build/forest_revision04/composition"
var map_index := 1
var failures: Array[String] = []
var observations: Array[Dictionary] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--layout="):layout=arg.trim_prefix("--layout=")
		elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--map="):map_index=int(arg.trim_prefix("--map="))
	run.call_deferred()

func frames(count: int) -> void:
	for unused: int in count: await physics_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output)
	for area_id: String in ["root_bay","interwoven_inner","interwoven_deep_basin","interwoven_root_landing"]:
		var app := DemoApp.new()
		app.meta_persistence_enabled=false
		root.add_child(app)
		if not app.start_debug_region(&"thorn_forest",map_index,"forest-depth-00",ThornForestRegionGenerator.DEPTH_VERSION,layout):
			failures.append("debug_entry/"+area_id);app.free();break
		await frames(10)
		var stage := app.stage as ThornForestRegionStage
		if not is_instance_valid(stage) or not stage.assembly_ok:
			failures.append("formal_stage/"+area_id);app.free();break
		var manifest: Dictionary = stage.generated.manifest
		var rows: Array = manifest.areas.filter(func(row: Dictionary) -> bool:return str(row.id)==area_id)
		if rows.size()!=1:
			failures.append("missing_observation_bank/"+area_id);app.free();break
		var point := Vector2(rows[0].position[0],rows[0].position[1])
		if not app.controller.return_to_segment(point):
			failures.append("initial_segment_setup/"+area_id);app.free();break
		app.controller.router.clear("visual_fixture_initial_observation")
		await frames(45)
		if app.stage!=stage or not app.player.is_on_floor():
			failures.append("observation_bank_not_surviving_ground/"+area_id)
		await RenderingServer.frame_post_draw
		var path := output.path_join("map%s_"%map_index+area_id+".png")
		var saved := root.get_texture().get_image().save_png(path)
		if saved!=OK:failures.append("image_write/"+area_id)
		var camera := app._run_camera
		var visible_targets: Array[Dictionary] = []
		for id: String in stage.assembler.hook_targets:
			var target: Node2D = stage.assembler.hook_targets[id]
			var pixel := target.get_global_transform_with_canvas().origin
			if Rect2(Vector2.ZERO,Vector2(root.size)).has_point(pixel):
				visible_targets.append({"id":id,"pixel":[pixel.x,pixel.y],"kind":target.get_script().resource_path})
		observations.append({"bank":area_id,"map_index":map_index,"layout":manifest.layout_version,"manifest_hash":manifest.manifest_hash,"image":path,"body":[app.player.position.x,app.player.position.y],"grounded":app.player.is_on_floor(),"hp":app.controller.actor_resources.health.current,"camera":[camera.get_screen_center_position().x,camera.get_screen_center_position().y],"zoom":camera.zoom.x,"visible_targets":visible_targets,"scope":"fresh_formal_App_initial_segment_visual_fixture;_not_route_completion"})
		app.process_mode=Node.PROCESS_MODE_DISABLED
		app._cancel_enemy_attacks()
		if not await preload("res://tests/audio_teardown.gd").drain_world(app):failures.append("audio_release/"+area_id)
		app.free()
		await process_frame
		await process_frame
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"formal_native_G2_observation_fixtures_not_G1_traversal_or_device_approval","layout":layout,"observations":observations,"failures":failures}));file.close()
	print("FOREST FRUIT COMPOSITION: %s observations, %s failures"%[observations.size(),failures.size()])
	quit(0 if failures.is_empty() and observations.size()==4 else 1)
