extends SceneTree
## Actual formal scene pixels. Static actor poses are composition fixtures, never traversal.
var output := "res://build/production_repair/art/baseline_01/report.json"
var root_seed := "v3-root-bell-pilot-1"
var rows: Array[Dictionary] = []
var edge_windows:=false
var _source_before:Dictionary={}
const BOUND_SOURCES:=["scripts/art/plains_connected_landscape.gd","scripts/art/plains_region_composition.gd","scripts/art/plains_terrain_family_sampler.gd","scripts/art/plains_tile_composer.gd","shaders/plains_tile_material.gdshader","assets/production_repair/rooted_plants_v1/family.json","assets/production_repair/rooted_plants_v1/raw.png","assets/production_repair/connected_cliff_v2/family.json","assets/production_repair/connected_cliff_v2/raw.png","tests/plains_connected_landscape_runner.gd"]
func bound_sources()->Dictionary:
	var result:Dictionary={}
	for path:String in BOUND_SOURCES:
		if FileAccess.file_exists("res://"+path):result[path]=FileAccess.get_sha256("res://"+path)
	return result
var errors: Array[String] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--root-seed="): root_seed=arg.trim_prefix("--root-seed=")
		if arg=="--edge-windows":edge_windows=true
	run.call_deferred()

func wait_stage(app: DemoApp) -> void:
	for unused: int in 120:
		await physics_frame
		await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage: return

func run() -> void:
	_source_before=bound_sources()
	root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var app:=DemoApp.new()
	app.meta_persistence_enabled=false
	root.add_child(app)
	if not app.start_plains(root_seed): errors.append("formal_start_failed")
	await wait_stage(app)
	app.lifetime.stage_epoch+=1
	app.lifetime.actor_epoch+=1
	app.director._enter_stage(2,&"boss")
	app._stage_entered(DemoRunResult.new())
	await wait_stage(app)
	var stage:=app.stage as PlainsRegionStage
	var manifest_before:=JSON.stringify(stage.generated.manifest)
	var composition:=stage.find_child("PlainsRegionComposition",true,false) as PlainsRegionComposition
	var connected:=stage.find_child("ConnectedLandscape",true,false) as Node2D
	var supports:Array=[]
	for source:Dictionary in composition.landscape.actual_support_sources():
		supports.append({"bounds":PlainsSemanticLandscape.rect_values(source.bounds),"node_path":source.node_path,"members":source.members.map(func(m:Dictionary)->Dictionary:return {"bounds":PlainsSemanticLandscape.rect_values(m.bounds),"node_path":m.node_path,"module_id":m.module_id})})
	var positions:Array[Vector2]=[Vector2(5050,508),Vector2(5290,508),Vector2(5500,508)]
	if edge_windows:positions.append_array([Vector2(4250,508),Vector2(5970,508),Vector2(6040,740)])
	for index:int in positions.size():
		var position:Vector2=positions[index]
		if not is_instance_valid(app.player):errors.append("actor_unavailable_after_static_pose");break
		# Explicit screenshot fixture: replenish before each unrelated static pose.
		# This is neither natural resource acquisition nor no-damage traversal.
		app.controller.actor_resources.health.configure(app.controller.actor_resources.health_definition)
		app.player.reset_at(position)
		if index>=3:
			# Additional perimeter-only static fixtures freeze before combat/void
			# progression, then use the native camera's existing transition snap.
			paused=true
			app._run_camera.snap_to_target()
			app._run_camera.force_update_scroll()
		else:
			for unused:int in 24: await physics_frame;await process_frame
		if not is_instance_valid(app.player):errors.append("actor_lost_during_static_pose");break
		paused=true
		for unused:int in 2: await process_frame
		var camera:=root.get_camera_2d()
		var item:Dictionary={"window":index,"fixture_mode":"native_camera_transition_snap_paused_before_physics" if index>=3 else "24_physics_frames_after_static_reset","requested_actor_position":PlainsSemanticLandscape.pair(position),"actor_actual_position":PlainsSemanticLandscape.pair(app.player.global_position),"camera_center":PlainsSemanticLandscape.pair(camera.get_screen_center_position()),"camera_zoom":PlainsSemanticLandscape.pair(camera.zoom)}
		for variant:String in ["baseline","candidate"]:
			if variant=="candidate" and connected==null:continue
			if connected!=null:connected.call("set_candidate",variant=="candidate")
			await RenderingServer.frame_post_draw
			var path:=output.get_base_dir()+"/window_%s_%s.png"%[index,variant]
			if root.get_texture().get_image().save_png(path)!=OK:errors.append("png_save_failed")
			item[variant]=path
		rows.append(item)
		if connected!=null:connected.call("set_candidate",true)
		paused=false
	var report:Dictionary={"schema_version":1,"artifact_kind":"actual_formal_static_composition_fixture","root_seed":root_seed,"map_index":2,"manifest_hash":stage.generated.manifest.manifest_hash,"manifest":stage.generated.manifest,"source_before":_source_before,"source_after":bound_sources(),"health_fixture":"Health Resource configure before each unrelated pose, no invulnerability or enemy disabling; not natural/no-damage traversal.","actual_static_support_unions":supports,"windows":rows,"errors":errors,"scope":"Real DemoApp, existing gameplay/enemies/HUD/camera, static reset poses; no route traversal, user aesthetic or device acceptance."}
	if bound_sources()!=_source_before:errors.append("bound_visual_source_changed_during_capture")
	if JSON.stringify(stage.generated.manifest)!=manifest_before:errors.append("manifest_modified")
	if connected!=null and connected.has_method("measured_nodes"):report["connected_landscape"]=connected.call("measured_nodes")
	paused=false
	var audio:=get_first_node_in_group(&"game_audio") as GameAudio
	if audio==null or not await audio.shutdown():errors.append("audio_backend_not_released_before_exit")
	app.free()
	for unused:int in 3:await physics_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report)+"\n");file.close()
	print("CONNECTED LANDSCAPE: windows=%s errors=%s"%[rows.size(),errors.size()])
	quit(0 if errors.is_empty() else 1)
