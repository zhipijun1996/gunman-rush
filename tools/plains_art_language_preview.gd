extends "res://tools/plains_regional_art_preview.gd"
## Same actual game and manual controls. Candidate parameter/consumer preview,
## not artistic gold or a claim that the missing foreground families exist.
var capture_output:=""
func _initialize()->void:
	auto_accept_quit=false
	root.close_requested.connect(close_review)
	review_seed="joint-recoil-01"
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):review_seed=arg.trim_prefix("--seed=")
		elif arg=="--smoke-close":smoke_close=true
		elif arg.begins_with("--capture-output="):capture_output=arg.trim_prefix("--capture-output=")
		else:push_error("Unsupported art-language preview argument");quit(2);return
	if smoke_close and not capture_output.is_empty():push_error("Choose smoke close or rendered capture");quit(2);return
	run.call_deferred()

func make_review_application() -> DemoApp:
	root.title = "失序之钟 · 关卡美术语言参数样板（非艺术准入）"
	var result := DemoApp.new()
	result.set_meta("plains_art_language_candidate","bounded_plains_v1")
	return result

func run()->void:
	if not capture_output.is_empty() and DisplayServer.get_name()=="headless":
		push_error("Actual PNG capture requires rendered display");quit(2);return
	await super.run()
	if capture_output.is_empty() or not is_instance_valid(app) or closing:return
	if DirAccess.dir_exists_absolute(capture_output):
		push_error("Capture refuses existing evidence directory");await close_review();return
	if DirAccess.make_dir_recursive_absolute(capture_output)!=OK:
		push_error("Cannot create capture directory");await close_review();return
	var snapshot:Dictionary=app.stage.call("get_regional_art_snapshot")
	var camera:Camera2D=app._run_camera
	var normal_camera:Dictionary={"position":[camera.global_position.x,camera.global_position.y],"zoom":[camera.zoom.x,camera.zoom.y]}
	for unused:int in 3:await process_frame
	await RenderingServer.frame_post_draw
	var normal_path:=capture_output.path_join("normal_start.png")
	var normal_error:=root.get_texture().get_image().save_png(normal_path)
	var values:Array=snapshot.art_plan.bounds
	var bounds:=Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3])).grow(120.0)
	camera.set_physics_process(false)
	camera.position_smoothing_enabled=false
	camera.global_position=bounds.get_center()
	var fit:=minf(1280.0/bounds.size.x,720.0/bounds.size.y)
	camera.zoom=Vector2.ONE*fit
	camera.force_update_scroll()
	for unused:int in 3:await process_frame
	await RenderingServer.frame_post_draw
	var overview_path:=capture_output.path_join("world_overview_debug.png")
	var overview_error:=root.get_texture().get_image().save_png(overview_path)
	var receipt:Dictionary={"kind":"actual_Godot_parameter_consumer_probe_not_art_admission","root_seed":review_seed,"source_commit":OS.get_environment("REGIONAL_SOURCE_COMMIT"),"scope":"normal_start uses real game camera, player and HUD; overview explicitly changes camera only, no player teleport or route proof; missing front asset families remain unverified","normal_camera":normal_camera,"overview_camera":{"position":[camera.global_position.x,camera.global_position.y],"zoom":fit},"actual_player_position":[app.player.global_position.x,app.player.global_position.y],"actual_snapshot":snapshot,"normal_start":{"path":normal_path,"sha256":FileAccess.get_sha256(normal_path),"error":normal_error},"overview":{"path":overview_path,"sha256":FileAccess.get_sha256(overview_path),"error":overview_error}}
	var file:=FileAccess.open(capture_output.path_join("receipt.json"),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(receipt)+"\n");file.close()
	if normal_error!=OK or overview_error!=OK or file==null:push_error("Art-language rendered evidence failure")
	print("PLAINS ART LANGUAGE RENDER: ",normal_error," ",overview_error)
	await close_review()
