extends SceneTree
## Explicit local silhouette feedback, not actual App/HUD or traversal approval.
var output := "/tmp/forest-place-golden"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output)
	var rows: Array = []
	var failures: Array = []
	for variant: int in [0,1]:
		var room := preload("res://scripts/demo/forest_exploration_place_lab.gd").new()
		room.place_variant = variant
		root.add_child(room)
		for unused: int in 12: await physics_frame
		paused = true
		for port: String in ["entry","crown","cache","lower_return"]:
			var point: Array = room.manifest.ports[port].position
			room.player.position = Vector2(point[0],point[1])
			room.camera.position = room.player.position+Vector2(80.0,-80.0)
			room.camera.force_update_scroll()
			room.queue_redraw()
			for unused: int in 3: await process_frame
			await RenderingServer.frame_post_draw
			var filename := "v%s_%s.png" % [variant,port]
			if root.get_texture().get_image().save_png(output+"/"+filename) != OK: failures.append(filename)
			rows.append({"image":filename,"variant":variant,"port":port,"pose":point,"scope":"explicit_local_silhouette_no_App_HUD_no_traversal"})
		paused = false
		if not await preload("res://tests/audio_teardown.gd").drain_world(room): failures.append("audio_teardown")
		room.free()
		for unused: int in 3: await process_frame
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"failures":failures}))
	print("FOREST PLACE SILHOUETTE: %s images / %s failures" % [rows.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)
