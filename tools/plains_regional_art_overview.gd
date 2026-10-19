extends "res://tools/plains_regional_art_preview.gd"
## Actual rendered whole-world diagnostic. Zoomed overview is NOT gameplay camera proof.
var output_dir := "res://build/plains_regional_art/overview_01"
func _initialize() -> void:
	auto_accept_quit = false
	root.close_requested.connect(close_review)
	review_seed = "regional-art-01"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): review_seed = arg.trim_prefix("--seed=")
		elif arg.begins_with("--output-dir="): output_dir = arg.trim_prefix("--output-dir=")
		else: push_error("Unsupported regional overview argument");quit(2);return
	run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Actual overview requires visible rendering display");quit(2);return
	await super.run()
	if not is_instance_valid(app) or not app.stage is PlainsRegionStage: return
	DirAccess.make_dir_recursive_absolute(output_dir)
	var snapshot: Dictionary = app.stage.call("get_regional_art_snapshot")
	var initial_camera := {"position":[app._run_camera.global_position.x,app._run_camera.global_position.y],"zoom":[app._run_camera.zoom.x,app._run_camera.zoom.y]}
	for unused: int in 3: await process_frame
	await RenderingServer.frame_post_draw
	var normal_path := output_dir.path_join("normal_start.png")
	var normal_error := root.get_texture().get_image().save_png(normal_path)
	var raw: Array = snapshot.art_plan.bounds
	var bounds := Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3])).grow(120.0)
	app._run_camera.set_physics_process(false)
	app._run_camera.position_smoothing_enabled = false
	app._run_camera.global_position = bounds.get_center()
	var fit := minf(1280.0/bounds.size.x,720.0/bounds.size.y)
	app._run_camera.zoom = Vector2.ONE*fit
	app._run_camera.force_update_scroll()
	for unused: int in 3: await process_frame
	await RenderingServer.frame_post_draw
	var overview_path := output_dir.path_join("actual_world_overview.png")
	var overview_error := root.get_texture().get_image().save_png(overview_path)
	var receipt := {"kind":"actual_Godot_rendered_diagnostic","root_seed":review_seed,"source_commit":OS.get_environment("REGIONAL_SOURCE_COMMIT"),"scope":"normal_start is actual normal camera; world_overview is explicitly diagnostic changed camera zoom/position; no player teleport or route proof","normal_camera":initial_camera,"overview_camera":{"position":[app._run_camera.global_position.x,app._run_camera.global_position.y],"zoom":fit},"actual_player_position":[app.player.global_position.x,app.player.global_position.y],"actual_snapshot":snapshot,"normal_start":{"path":normal_path,"sha256":FileAccess.get_sha256(normal_path),"error":normal_error},"overview":{"path":overview_path,"sha256":FileAccess.get_sha256(overview_path),"error":overview_error}}
	var file := FileAccess.open(output_dir.path_join("receipt.json"),FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(receipt)+"\n")
	if normal_error!=OK or overview_error!=OK or file==null: push_error("Regional overview image/archive failure")
	print("PLAINS REGIONAL OVERVIEW: ",normal_error," ",overview_error)
	await close_review()
