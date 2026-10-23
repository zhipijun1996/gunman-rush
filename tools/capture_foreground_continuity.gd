extends "res://tools/capture_depth_frame.gd"
## Bounded formal Home / two Plains maps / two seeds; positioned diagnostics.
func _initialize() -> void:
	output="res://build/foreground_continuity_08/captures"
	task_id="FOREGROUND-CONTINUITY-08"
	run_capture.call_deferred()

func foreground(node: Node) -> Node:
	if node.get_script()!=null and str(node.get_script().resource_path).ends_with("underworld_foreground.gd"):return node
	for child: Node in node.get_children():
		var found:=foreground(child)
		if found!=null:return found
	return null

func settled(id: String,point: Vector2,center: Vector2) -> void:
	var fg:=foreground(app)
	check(fg!=null,"actual foreground consumer exists")
	if is_instance_valid(app.home_scene):
		app.home_scene.player.position=point
		app.home_scene.camera.position=center
		app.home_scene.camera.force_update_scroll()
	else:
		app.controller.return_to_segment(point)
		app._run_camera.position=center
		app._run_camera.force_update_scroll()
	refresh(app)
	fg.set_process(true)
	for i: int in 80:await process_frame
	fg.set_process(false)
	await capture(id,point,center)
	rows[-1]["foreground"]=fg.call("receipt")

func run_capture() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	await new_app("home",1,"")
	await settled("home",Vector2(440,414),Vector2(640,310))
	await settled("home_east",Vector2(2920,414),Vector2(2640,310))
	for seed_value: String in ["level-design-v2-baseline/08","fine-space-05/highland"]:
		for map_index: int in [1,2]:
			await new_app("plains",map_index,seed_value)
			var stage:=app.stage as PlainsRegionStage
			await settled("%s_m%d"%[seed_value.get_file(),map_index],stage.spawn,stage.spawn+Vector2(120,-40))
	FileAccess.open(output+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"task":task_id,"scope":"six positioned formal windows; not traversal/combat or full region acceptance","failures":failures,"captures":rows},"  "))
	app.abandon_run();await load("res://tests/audio_teardown.gd").drain_world(app)
	app.free()
	for i: int in 4:await process_frame
	print("FOREGROUND_CAPTURE_DONE count=%d failures=%d"%[rows.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)
