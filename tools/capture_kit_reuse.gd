extends SceneTree
const OUTPUT := "res://build/kit-reuse/"
var scene: Node2D
func _initialize() -> void: run.call_deferred()
func shot(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT+file)==OK)
func run() -> void:
	root.size = Vector2i(1280,720)
	scene = load("res://game/presentation/experiments/kit_reuse/room.tscn").instantiate()
	root.add_child(scene)
	while not scene.ready_to_capture: await process_frame
	var trace: Array = []
	for id: String in ["passage","shaft","hall"]:
		scene.show_room(id)
		scene.set_profile("flat")
		await shot(id+"-flat.png")
		scene.middle.hide()
		await shot(id+"-flat-no-middle.png")
		scene.set_profile("depth")
		await shot(id+"-depth.png")
		scene.light.enabled = false
		await shot(id+"-light-off.png")
		scene.light.enabled = true
		scene.structure.hide()
		scene.ground.hide()
		scene.actor.hide()
		scene.middle.show()
		await shot(id+"-layers-exposed.png")
		scene.middle.hide()
		scene.structure.show();scene.ground.show();scene.actor.show()
		scene.camera.zoom = Vector2.ONE*1.6
		scene.set_view(Vector2(scene.layout.hero_foot[0]+140,scene.layout.hero_foot[1]-100))
		await shot(id+"-zoom1.6.png")
		scene.camera.zoom = Vector2.ONE
		scene.set_view(Vector2(scene.layout.camera[0],scene.layout.camera[1]))
		if "--stills" in OS.get_cmdline_user_args(): continue
		var frames_dir := OUTPUT+id+"-frames"
		DirAccess.make_dir_recursive_absolute(frames_dir)
		for existing: String in DirAccess.get_files_at(frames_dir):
			if existing.ends_with(".png"): assert(DirAccess.remove_absolute(frames_dir+"/"+existing)==OK)
		for frame: int in range(96):
			var at: Vector2 = scene.path_at(float(frame)/95.0)
			scene.set_view(at)
			trace.append({"room":id,"frame":frame,"camera":[scene.camera.position.x,scene.camera.position.y],"middle":[scene.middle.position.x,scene.middle.position.y],"zoom":scene.camera.zoom.x})
			await shot(id+"-frames/%04d.png"%frame)
		# Overscan probes beyond the declared tour, both layers independently.
		for offset: Vector2 in [Vector2(-160,-120),Vector2(160,120)]:
			scene.set_view(Vector2(scene.layout.camera[0],scene.layout.camera[1])+offset)
			await shot(id+"-overscan-"+str(int(offset.x))+".png")
	var report_file := "stills.json" if "--stills" in OS.get_cmdline_user_args() else "capture.json"
	var file := FileAccess.open(OUTPUT+report_file,FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames":trace,"fps":12,"formal_gameplay_verified":false,"camera":"scripted coverage path, not WorldCamera","new_unique_paintings":1,"new_room_specific_paintings":0,"shadow_occlusion_verified":false},"\t"))
	print("KIT REUSE: three geometries, ",trace.size()," actual Godot tour frames, shared profile comparison and complete-layer exposure")
	quit()
