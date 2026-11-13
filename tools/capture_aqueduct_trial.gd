extends SceneTree
func _initialize() -> void: run.call_deferred()
func assign_owners(node: Node, scene: Node) -> void:
	for child: Node in node.get_children():
		child.owner=scene
		assign_owners(child,scene)
func shot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/art-rule-trial/"+label+".png")==OK)
func run() -> void:
	root.size=Vector2i(1280,720)
	var scene: Node2D=load("res://game/presentation/experiments/depth_lab/aqueduct_trial.tscn").instantiate()
	root.add_child(scene)
	while not scene.ready_to_capture: await process_frame
	assert(scene.find_children("*","Node3D",true,false).is_empty())
	assert(root.get_texture().get_image().get_size()==Vector2i(1280,720))
	await shot("assembled")
	scene.grayscale.show()
	await shot("grayscale")
	scene.grayscale.hide()
	scene.architecture.hide()
	scene.water.hide()
	await shot("without-architecture")
	scene.architecture.show()
	scene.water.show()
	scene.terrain.hide()
	scene.hero.hide()
	await shot("without-gameplay-layer")
	scene.terrain.show()
	scene.hero.show()
	await process_frame
	var frozen: Node = scene.duplicate()
	frozen.set_script(null)
	assign_owners(frozen,frozen)
	var packed := PackedScene.new()
	assert(packed.pack(frozen)==OK)
	assert(ResourceSaver.save(packed,"res://build/art-rule-trial/editable.tscn")==OK)
	frozen.free()
	var report: Dictionary = {"renderer":"Godot Node2D / TerrainComposer","viewport":[1280,720],"hero_height_wu":scene.config.hero_height_wu,"material_id":scene.config.material_id,"config_sha256":FileAccess.get_sha256("res://config/art/aqueduct_trial.json"),"architecture_sha256":FileAccess.get_sha256("res://assets/art_rule_trial/native/aqueduct.png"),"environment_sha256":FileAccess.get_sha256("res://assets/art_rule_trial/native/environment.png"),"generated_full_scene_used_at_runtime":false,"formal_gameplay_verified":false,"captures":["assembled","grayscale","without-architecture","without-gameplay-layer"]}
	var record := FileAccess.open("res://build/art-rule-trial/capture.json",FileAccess.WRITE)
	record.store_string(JSON.stringify(report,"\t"))
	record.close()
	print("AQUEDUCT TRIAL CAPTURE: independent layers / formal terrain and hero / 1280x720")
	quit()
