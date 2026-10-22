extends SceneTree
## Actual v17 App screenshots at explicit staged poses. Never traversal evidence.
const AUDIO := preload("res://tests/audio_teardown.gd")
var output := "res://build/region_bible_v2/forest-variety-golden"
var rows: Array[Dictionary] = []
var failures: Array[String] = []
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output)
	for map_index: int in [1,2]:
		var app := DemoApp.new()
		app.meta_persistence_enabled = false
		root.add_child(app)
		if not app.start_debug_region(&"thorn_forest",map_index,"forest-depth-hollow-00",ThornForestRegionGenerator.DEPTH_VERSION,"forest-varied-bible-v17"):
			failures.append("actual_v17_entry_rejected_map_%s" % map_index)
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
		var poses: Array[String] = ["arrival","varied_entry_rest","varied_double_window__entry","varied_double_window__crown","varied_double_window__inner_root","varied_l_hollow__cache","varied_l_hollow__lower_rejoin"]
		for id: String in poses:
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
			rows.append({"image":name,"map_index":map_index,"area":id,"pose":[point.x,point.y],"layout":stage.generated.manifest.layout_version,"manifest_hash":stage.generated.manifest.manifest_hash,"world_bounds":stage.generated.manifest.world_bounds,"shared_family":"UnderworldTerrain + UnderworldPlayer","scope":"explicit static composition fixture, no natural traversal or device approval"})
		paused = false
		if not await AUDIO.drain_world(app): failures.append("audio_teardown")
		app.free()
		for unused: int in 3: await process_frame
	FileAccess.open(output+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"actual_v17_static_App_composition_only","rows":rows,"failures":failures},"\t"))
	print("FOREST VARIED GOLDEN: %s images / %s failures" % [rows.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)
