extends "res://tools/plains_joint_recoil_preview.gd"
## Actual rendered whole-world diagnostic. Zoomed overview is NOT gameplay camera proof.
var output_dir := "res://build/plains_joint_recoil/overview_01"
func _initialize() -> void:
	auto_accept_quit = false
	root.close_requested.connect(close_review)
	review_seed = "joint-recoil-01"
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
	var snapshot: Dictionary = app.stage.call("get_joint_recoil_snapshot")
	var initial_camera := {"position":[app._run_camera.global_position.x,app._run_camera.global_position.y],"zoom":[app._run_camera.zoom.x,app._run_camera.zoom.y]}
	for unused: int in 3: await process_frame
	await RenderingServer.frame_post_draw
	var normal_path := output_dir.path_join("normal_start.png")
	var normal_error := root.get_texture().get_image().save_png(normal_path)
	var raw: Array = snapshot.art_plan.bounds
	if not snapshot.art_plan.get("joint_modules",[]).is_empty():
		var target: Dictionary=snapshot.art_plan.joint_modules[0]
		var offset: Array=target.get("offset",[1960.0,-582.0])
		raw=[float(offset[0])-300.0,float(offset[1])+100.0,1400.0,900.0]
	var bounds := Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3])).grow(120.0)
	app._run_camera.set_physics_process(false)
	app._run_camera.position_smoothing_enabled = false
	app._run_camera.global_position = bounds.get_center()
	var fit := minf(1280.0/bounds.size.x,720.0/bounds.size.y)
	app._run_camera.zoom = Vector2.ONE*fit
	app._run_camera.force_update_scroll()
	for unused: int in 3: await process_frame
	await RenderingServer.frame_post_draw
	var overview_path := output_dir.path_join("actual_target_overview.png")
	var overview_error := root.get_texture().get_image().save_png(overview_path)
	var target_camera:={"position":[app._run_camera.global_position.x,app._run_camera.global_position.y],"zoom":fit}
	var region_raw:Array=snapshot.art_plan.bounds
	var region_bounds:=Rect2(region_raw[0],region_raw[1],region_raw[2],region_raw[3]).grow(120.0)
	app._run_camera.global_position=region_bounds.get_center()
	var region_fit:=minf(1280.0/region_bounds.size.x,720.0/region_bounds.size.y)
	app._run_camera.zoom=Vector2.ONE*region_fit
	app._run_camera.force_update_scroll()
	for unused:int in 3:await process_frame
	await RenderingServer.frame_post_draw
	var region_path:=output_dir.path_join("actual_whole_region_overview.png")
	var region_error:=root.get_texture().get_image().save_png(region_path)
	var receipt := {"kind":"actual_Godot_rendered_diagnostic","root_seed":review_seed,"source_commit":OS.get_environment("REGIONAL_SOURCE_COMMIT"),"scope":"normal_start is actual normal camera; target_overview and whole_region_overview are explicitly diagnostic changed camera zoom/position; no player teleport or route proof","normal_camera":initial_camera,"target_overview_camera":target_camera,"region_overview_camera":{"position":[app._run_camera.global_position.x,app._run_camera.global_position.y],"zoom":region_fit},"actual_player_position":[app.player.global_position.x,app.player.global_position.y],"actual_snapshot":snapshot,"normal_start":{"path":normal_path,"sha256":FileAccess.get_sha256(normal_path),"error":normal_error},"target_overview":{"path":overview_path,"sha256":FileAccess.get_sha256(overview_path),"error":overview_error},"whole_region_overview":{"path":region_path,"sha256":FileAccess.get_sha256(region_path),"error":region_error}}
	var file := FileAccess.open(output_dir.path_join("receipt.json"),FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(receipt)+"\n")
	if normal_error!=OK or overview_error!=OK or region_error!=OK or file==null: push_error("Regional overview image/archive failure")
	print("PLAINS JOINT RECOIL OVERVIEW: ",normal_error," ",overview_error)
	await close_review()
