extends SceneTree
## M0 positioned formal frames only. Never evidence of Motor traversal.
const OUT := "res://build/plains_golden_01/m0/pixels/"
var samples: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUT)
	var app := DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	if not app.start_plains("underworld-formal-integrated"):
		push_error("M0 formal entry refused")
		quit(1)
		return
	for frame: int in 8: await physics_frame
	var stage := app.stage as PlainsRegionStage
	if stage == null or not stage.assembly_ok:
		push_error("M0 formal assembly failed")
		quit(1)
		return
	var points: Array[Dictionary] = [{"id":"spawn", "at":stage.spawn}]
	for area: Dictionary in stage.generated.manifest.areas:
		if str(area.role) == "junction":
			points.append({"id":"junction", "at":Vector2(area.position[0],area.position[1])-Vector2(0,18), "area":area})
			break
	for latch: Dictionary in stage.generated.manifest.shot_latch_plan.latches:
		var module := stage.assembler.modules[int(latch.node_index)]
		points.append({"id":"bell_approach", "at":module.world_entry(), "module":String(module.definition.module_id)})
		break
	if points.size() != 3:
		push_error("M0 missing distinct formal observation windows")
		quit(1)
		return
	for point: Dictionary in points:
		app.controller.return_to_segment(point.at)
		for frame: int in 8: await physics_frame
		app._run_camera.snap_to_target()
		app._run_camera.force_update_scroll()
		await process_frame
		await RenderingServer.frame_post_draw
		var path := OUT+str(point.id)+".png"
		if root.get_texture().get_image().save_png(path) != OK:
			push_error("M0 screenshot failed")
			quit(1)
			return
		var camera := app._run_camera
		samples.append({"id":point.id,"requested_fixture_position":[point.at.x,point.at.y],"actual_position":[app.player.position.x,app.player.position.y],"camera_center":[camera.get_screen_center_position().x,camera.get_screen_center_position().y],"zoom":[camera.zoom.x,camera.zoom.y],"image":path,"fixture":true,"traversal_claim":false})
	var receipt := {"task":"PLAINS-GOLDEN-01","seed":app.director.seed,"map_index":stage.map_index,"manifest_seed":stage.generated.manifest.seed,"manifest_hash":stage.generated.manifest.manifest_hash,"content_version":stage.generated.manifest.version,"resolution":[1280,720],"input":"no Router requests; positioned observation only","initial_fixture_spawn_override":true,"resource_or_health_override":false,"enemies_enabled":true,"capabilities":Array(app.campaign.abilities),"samples":samples}
	app.abandon_run()
	var drained: bool = await load("res://tests/audio_teardown.gd").drain_world(app)
	app.free()
	for frame: int in 6: await process_frame
	receipt["audio_drained"] = drained
	FileAccess.open(OUT+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify(receipt,"  "))
	print("PLAINS_GOLDEN_M0 samples=%d teardown=%s traversal=false" % [samples.size(),drained])
	quit(0 if drained else 1)
