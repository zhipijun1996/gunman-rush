extends SceneTree
const OUTPUT := "res://build/engine-first-2d/"
func _initialize() -> void: run.call_deferred()
func shot(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(file)==OK)
func assign_owners(node: Node, scene: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene
		assign_owners(child,scene)
func run() -> void:
	root.size = Vector2i(1280,720)
	var scene: Node2D = load("res://game/presentation/experiments/engine_first_2d/room.tscn").instantiate()
	root.add_child(scene)
	while not scene.ready_to_capture: await process_frame
	assert(scene.find_children("*","Node3D",true,false).is_empty())
	if "--clip" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(OUTPUT+"frames")
		for frame: int in range(96):
			var time := float(frame)/12.0
			scene.light.enabled = frame>=24 and frame<72
			scene.bell.rotation = sin(time*1.7)*0.035
			(scene.water.material as ShaderMaterial).set_shader_parameter("clock",time)
			(scene.water_front.material as ShaderMaterial).set_shader_parameter("clock",time)
			await shot(OUTPUT+"frames/%04d.png" % frame)
		print("ENGINE FIRST CLIP:96 actual Godot frames,12fps,off2s/on4s/off2s")
		quit()
		return
	if "--greybox" in OS.get_cmdline_user_args():
		for sprite: Sprite2D in scene.slices: sprite.hide()
		scene.grey_background.show()
		scene.grey_structure.show()
		await shot("res://assets/engine_first_2d/source/godot-greybox.png")
		scene.hero.hide()
		scene.bell.hide()
		scene.light.enabled = false
		scene.water.hide()
		scene.water_front.hide()
		await shot("res://assets/engine_first_2d/source/godot-paint-guide.png")
		scene.terrain.hide()
		scene.grey_background.hide()
		root.transparent_bg = true
		for shape: Polygon2D in scene.grey_structure.get_children(): shape.color = Color.WHITE
		await shot("res://assets/engine_first_2d/native/structure-mask.png")
		print("ENGINE FIRST: actual camera/hero/terrain guide and structural light mask captured before image generation")
	else:
		await shot(OUTPUT+"assembled.png")
		scene.light.enabled = false
		await shot(OUTPUT+"light-off.png")
		scene.light.enabled = true
		scene.water.hide()
		scene.water_front.hide()
		await shot(OUTPUT+"water-off.png")
		scene.light.enabled = false
		scene.terrain.hide()
		scene.hero.hide()
		scene.bell.hide()
		await shot(OUTPUT+"recombined-painting.png")
		scene.light.enabled = true
		scene.terrain.show()
		scene.hero.show()
		scene.bell.show()
		scene.water.show()
		scene.water_front.show()
		var frozen: Node = scene.duplicate()
		frozen.set_script(null)
		assign_owners(frozen,frozen)
		var packed := PackedScene.new()
		assert(packed.pack(frozen)==OK)
		assert(ResourceSaver.save(packed,OUTPUT+"editable.tscn")==OK)
		frozen.free()
		var report := {"viewport":[1280,720],"hero_height_wu":scene.config.hero_height_wu,"config_sha256":FileAccess.get_sha256(scene.CONFIG),"material":scene.config.terrain_material,"formal_gameplay_verified":false,"independent_parallax_verified":false,"structure_mask":"authored and captured before generation","source_pixels":"shared native painting with complementary masks, no per-layer AI redraw"}
		var file := FileAccess.open(OUTPUT+"capture.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
		print("ENGINE FIRST: actual2D frames and effect toggles captured")
	quit()
