extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func ticks(count: int) -> void:
	for i: int in count: await physics_frame

func run() -> void:
	var region := "thorn_forest"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("region="): region = argument.trim_prefix("region=")
	var session: OrdinaryRoomSession
	if region == "thorn_forest":
		session = preload("res://tests/perception_demo.tscn").instantiate()
		root.add_child(session)
	else:
		session = OrdinaryRoomSession.new()
		root.add_child(session)
		var doc := WorldRoomDocument.read("res://tests/perception_demo.json")
		doc.root.properties.region_id = region
		doc.root.properties.terrain_material = region
		doc.entities.charm = {"id":"charm","definition_id":"interaction.sound_lure","definition_version":1,"properties":{"position":[214,325]}}
		doc.entities.lantern = {"id":"lantern","definition_id":"environment.local_light","definition_version":1,"properties":{"position":[136,344],"light_radius":64}}
		var error := session.open(doc)
		if not error.is_empty():
			printerr(error)
			quit(1)
			return
		if "graybox" not in OS.get_cmdline_user_args(): add_regional_stage(session,region)
	if "graybox" in OS.get_cmdline_user_args():
		for layer in get_nodes_in_group("review_scenery"): layer.hide()
	var camera := root.get_camera_2d()
	if camera: camera.zoom = Vector2.ONE*1.45
	await ticks(32)
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(44)
	session.controller.router.set_move_axis(1)
	for i: int in 340:
		if session.player.position.x > 1010: break
		await physics_frame
	session.controller.router.set_move_axis(0)
	await ticks(35)
	var nodes := session.room.element_runtime.nodes
	var completed: bool = nodes.gate.active and session.player.position.x > 1010 and nodes.mat.serial == 1
	print("PERCEPTION SHOWCASE region=",region," gate=",nodes.gate.active," x=",snappedf(session.player.position.x,0.1)," sounds=",nodes.mat.serial," received=",nodes.flower.accepted)
	await session.audio_service.shutdown()
	session.free()
	quit(0 if completed else 1)

## Review scenery lives with the project art masters, outside the shipped gameplay project.
## A standalone export can still run the same room without these optional plates.
func art_texture(path: String) -> Texture2D:
	var full := ProjectSettings.globalize_path("res://").path_join("../art/world-art-v2/assets/pixel").path_join(path)
	if not FileAccess.file_exists(full): return null
	var img := Image.load_from_file(full)
	return ImageTexture.create_from_image(img) if img != null else null

func add_regional_stage(session: OrdinaryRoomSession, region: String) -> void:
	var plate := art_texture("v2/"+region+"_v2.png")
	if plate == null:
		var prefix: String = {"gear_city":"gear","mushroom_caverns":"mushroom","ember_depths":"ember"}.get(region,region)
		plate = art_texture(prefix+"-background.png")
	if plate != null:
		var distance := CanvasLayer.new()
		distance.layer = -10
		session.add_child(distance)
		var view := TextureRect.new()
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		view.self_modulate = Color(.56,.61,.66)
		view.texture = plate
		distance.add_child(view)
	for i in 3:
		var texture_art := art_texture("v2/"+region+("_near_v2.png" if i==2 else "_mid_v2.png"))
		if texture_art == null: continue
		var prop := Sprite2D.new()
		prop.texture = texture_art
		prop.position = Vector2([95,565,1055][i],384-texture_art.get_height()*.5)
		prop.flip_h = i == 1
		prop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		prop.self_modulate = Color(.48,.54,.60) if i != 2 else Color(.59,.64,.65)
		prop.z_index = -3
		session.add_child(prop)
