extends SceneTree
var output := "res://build/region_production_v3/ivy_attachment/gpu"
func _initialize() -> void: run.call_deferred()
func wait_stage(app: DemoApp) -> void:
	for unused: int in 120:
		await physics_frame
		await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage: return
func find_composition(node: Node) -> PlainsRegionComposition:
	if node is PlainsRegionComposition: return node
	for child: Node in node.get_children():
		var found := find_composition(child)
		if found!=null: return found
	return null
func run() -> void:
	root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output)
	var pose: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://build/region_production_v3/ivy_attachment/pose.json"))
	var app:=DemoApp.new()
	app.meta_persistence_enabled=false
	root.add_child(app)
	app.start_plains(pose.root_seed)
	await wait_stage(app)
	app.lifetime.stage_epoch+=1
	app.lifetime.actor_epoch+=1
	app.director._enter_stage(2,&"boss")
	app._stage_entered(DemoRunResult.new())
	await wait_stage(app)
	var stage:=app.stage as PlainsRegionStage
	var candidate:=find_composition(stage)
	var manifest_before:=JSON.stringify(stage.generated.manifest)
	var old_script:=GDScript.new()
	old_script.source_code=FileAccess.get_file_as_string("res://build/region_production_v3/ivy_attachment/plains_region_composition.before.source").replace("class_name PlainsRegionComposition\n","")
	if old_script.reload()!=OK: printerr("old renderer reconstruction compile failed");quit(1);return
	var old: Node2D=old_script.new()
	old.name="HistoricalIvyComposition"
	old.call("configure",stage.generated.manifest,candidate.supports,candidate.protected_regions)
	candidate.get_parent().add_child(old)
	paused=true
	app.player.global_position=Vector2(pose.player[0],pose.player[1])
	var camera:=root.get_camera_2d()
	camera.zoom=Vector2(pose.zoom[0],pose.zoom[1])
	var rows: Array[Dictionary]=[]
	for index: int in 3:
		var offset: Vector2=[Vector2.ZERO,Vector2(-150,0),Vector2(120,-100)][index]
		camera.global_position=Vector2(pose.camera[0],pose.camera[1])+offset
		camera.reset_smoothing()
		camera.force_update_scroll()
		for variant: String in ["before","candidate"]:
			old.visible=variant=="before"
			candidate.visible=variant=="candidate"
			await RenderingServer.frame_post_draw
			var file:=output+"/window_"+str(index)+"_"+variant+".png"
			var error:=root.get_texture().get_image().save_png(file)
			rows.append({"window":index,"variant":variant,"file":file,"save_error":error,"actual_camera":PlainsSemanticLandscape.pair(camera.get_screen_center_position()),"actual_player":PlainsSemanticLandscape.pair(app.player.global_position),"scope":"Paused real formal world at same actual recorded native pose; historical renderer compiled in isolation, only class_name removed; not normal traversal or exact video-frame replay"})
	var report: Dictionary={"rows":rows,"pose":pose,"manifest_unchanged":manifest_before==JSON.stringify(stage.generated.manifest),"manifest_hash":stage.generated.manifest.manifest_hash,"ivy_attachments":candidate.compositions.filter(func(c: Dictionary) -> bool:return c.get("asset_id","")=="ivy"),"ivy_omitted":candidate.ivy_omitted,"issues":candidate.ivy_attachment_issues(),"baseline_source_sha256":FileAccess.get_sha256("res://build/region_production_v3/ivy_attachment/plains_region_composition.before.source"),"candidate_source_sha256":FileAccess.get_sha256("res://scripts/art/plains_region_composition.gd")}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report)+"\n")
	file.close()
	app.free()
	await process_frame
	print("IVY STATIC: ",report.issues," attachments=",report.ivy_attachments.size())
	quit(0 if report.issues.is_empty() and report.manifest_unchanged else 1)
