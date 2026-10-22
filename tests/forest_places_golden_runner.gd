extends SceneTree
## Actual v18 App screenshots at explicit staged poses. Never traversal evidence.
const AUDIO := preload("res://tests/audio_teardown.gd")
var output := "res://build/region_bible_v2/forest-variety-golden"
var rows: Array[Dictionary] = []
var failures: Array[String] = []
var expanded := false
var family := ""
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg == "--expanded": expanded = true
		elif arg.begins_with("--family="): family = arg.trim_prefix("--family=")
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output)
	for map_index: int in [1,2]:
		var app := DemoApp.new()
		app.meta_persistence_enabled = false
		root.add_child(app)
		if not app.start_debug_region(&"thorn_forest",map_index,"forest-places-00" if map_index==1 else "forest-places-01",ThornForestRegionGenerator.DEPTH_VERSION,"forest-exploration-places-v18"):
			failures.append("actual_v18_entry_rejected_map_%s" % map_index)
			await AUDIO.drain_world(app)
			app.free()
			continue
		for unused: int in 12: await physics_frame
		if not app.stage is ThornForestRegionStage or not app.stage.assembly_ok:
			failures.append("stage_not_assembled_map_%s" % map_index)
			await AUDIO.drain_world(app)
			app.free()
			continue
		var stage := app.stage as ThornForestRegionStage
		if not is_instance_valid(stage.forest_terrain) or not app.player.get_node_or_null("PixelPlainsActor") is UnderworldPlayer:
			failures.append("shared_family_missing_map_%s" % map_index)
		var poses: Array[String] = ["C","places_double_window__entry","places_double_window__crown","places_seven__entry","places_seven__crown","places_seven__cache","places_seven__lower_return","prep"]
		if expanded:
			for area: Dictionary in stage.generated.manifest.areas:
				var id := str(area.id)
				if id in ["places_z__entry","places_z__pocket","places_z__cache","places_z__crown","places_z__failure","places_fallen__entry","places_fallen__inside","places_fallen__cache","places_fallen__exit","places_backbranch__west_entry","places_backbranch__entry","places_backbranch__crown","places_backbranch__normal_onward","places_backbranch__failure"]:
					poses.append(id)
		for id: String in poses:
			if not family.is_empty() and not id.begins_with("places_"+family+"__"): continue
			var found := false
			var point := Vector2.ZERO
			for area: Dictionary in stage.generated.manifest.areas:
				if str(area.id) == id:
					point = Vector2(area.position[0],area.position[1])
					found = true
					break
			if not found:
				failures.append("missing_staged_area:"+id)
				continue
			app.controller.router.clear("explicit_static_v17_composition")
			paused = true
			app.player.global_position = point
			app._run_camera.snap_to_target()
			app._run_camera.force_update_scroll()
			stage.queue_redraw()
			if is_instance_valid(stage.ambience): stage.ambience.queue_redraw()
			app._process(0.0)
			for unused: int in 3: await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var name := "map%s_%s.png" % [map_index,id]
			if image.save_png(output+"/"+name) != OK: failures.append("screenshot_write:"+name)
			rows.append({"image":name,"map_index":map_index,"area":id,"pose":[point.x,point.y],"layout":stage.generated.manifest.layout_version,"manifest_hash":stage.generated.manifest.manifest_hash,"actual_seed":stage.generated.manifest.seed,"world_bounds":stage.generated.manifest.world_bounds,"shared_family":"UnderworldTerrain + UnderworldPlayer","scope":"explicit static composition fixture, no natural traversal or device approval"})
		paused = false
		if not await AUDIO.drain_world(app): failures.append("audio_teardown")
		app.free()
		for unused: int in 3: await process_frame
	FileAccess.open(output+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"actual_v18_static_App_composition_only","rows":rows,"failures":failures},"\t"))
	print("FOREST PLACES GOLDEN: %s images / %s failures" % [rows.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)
