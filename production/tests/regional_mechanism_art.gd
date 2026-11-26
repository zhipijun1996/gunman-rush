extends SceneTree
## Same ordinary room, player input and camera in every regional hardware set.
## Pass capture=/absolute/path to save a fixed 60 Hz sequence sampled at 30 fps.
var failures := 0
var capture := ""
var seen := {}
var part_signatures := {}

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr(message)

func put(doc: Dictionary, kind: String, id: String, pos: Vector2, settings := {}) -> void:
	var instance := WorldElementCatalog.instantiate_definition(kind,id,pos)
	doc.entities.merge(instance.entities)
	doc.entities[id].properties.merge(settings,true)

func room_document(region: String) -> Dictionary:
	var doc := WorldRoomDocument.read("res://tests/assembly_room.json")
	doc.entities.erase("patrol")
	doc.root.properties.terrain_material = region
	doc.root.properties.region_id = region
	doc.entities.gate.properties.bounds = [396,254,32,130]
	doc.entities.bell.properties.state_scope = "attempt"
	doc.entities.gate.properties.state_scope = "attempt"
	put(doc,"interaction.sign","notice",Vector2(114,352))
	put(doc,"environment.local_light","lantern",Vector2(338,344),{"light_radius":74})
	put(doc,"platform.rotating_beam","beam",Vector2(553,325),{"beam_length":94,"rotation_mode":"continuous"})
	put(doc,"recovery.anchor","anchor",Vector2(102,288))
	return doc

func backdrop(session: OrdinaryRoomSession, region: String) -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join("../art/world-art-v2/assets/pixel")
	var path := dir.path_join("v2/"+region+"_v2.png")
	if not FileAccess.file_exists(path):
		var prefix: String = {"gear_city":"gear","ember_depths":"ember","mushroom_caverns":"mushroom"}.get(region,region)
		path = dir.path_join(prefix+"-background.png")
	var img := Image.load_from_file(path)
	expect(img != null and not img.is_empty(),region+" has an art plate")
	if img == null or img.is_empty(): return
	var layer := CanvasLayer.new()
	layer.layer = -10
	session.add_child(layer)
	var view := TextureRect.new()
	layer.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.texture = ImageTexture.create_from_image(img)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.modulate = Color(.49,.53,.56)

func check_native_parts(region: String, sheet: Texture2D) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(sheet.resource_path))
	for part: String in MechanismRegionArt.FRAMES:
		var tile := image.get_region(Rect2i(MechanismRegionArt.FRAMES[part]))
		expect(tile.get_used_rect().has_area(), region+" empty "+part)
		var signature := Marshalls.raw_to_base64(tile.get_data())
		var unique: Dictionary = part_signatures.get_or_add(part,{})
		expect(not unique.has(signature),region+" duplicates "+part)
		unique[signature] = region
		if part == "mount":
			var extent := tile.get_size()-Vector2i.ONE
			var transparent_corner := false
			for x in [0,extent.x]:
				for y in [0,extent.y]:
					if tile.get_pixel(x,y).a < .1: transparent_corner = true
			expect(transparent_corner,region+" mount has an opaque matte")

func check_region(region: String) -> void:
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var problem := session.open(room_document(region))
	expect(problem.is_empty(),region+" "+problem)
	if not problem.is_empty():
		session.free()
		return
	var bell: Node2D = session.room.element_runtime.nodes.bell
	var gate: WorldElementGate = session.room.element_runtime.nodes.gate
	var beam: Node2D = session.room.element_runtime.nodes.beam
	var sheet := MechanismRegionArt.sheet(bell)
	expect(MechanismRegionArt.region_id(beam)==region,region+" reaches beam")
	expect(sheet == MechanismRegionArt.sheet(gate) and sheet.get_size()==Vector2(148,36),region+" shared hardware")
	expect(not seen.has(sheet.resource_path),region+" has its own hardware")
	seen[sheet.resource_path] = true
	check_native_parts(region,sheet)
	var output := capture.path_join(region)
	if not capture.is_empty():
		backdrop(session,region)
		var camera := Camera2D.new()
		camera.position = Vector2(352,315)
		camera.zoom = Vector2(2.0,2.0)
		session.add_child(camera)
		camera.make_current()
		DirAccess.make_dir_recursive_absolute(output)
	for tick in (144 if not capture.is_empty() else 64):
		await physics_frame
		if tick==20: session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
		if not capture.is_empty() and tick % 2==0:
			await RenderingServer.frame_post_draw
			var frame := root.get_texture().get_image()
			expect(frame.save_jpg(output.path_join("%03d.jpg" % (tick/2)),.93)==OK,"saving "+region)
	expect(gate.active,region+" real shot opens linked gate")
	await session.audio_service.shutdown()
	session.free()

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("capture="): capture = arg.trim_prefix("capture=")
	var regional_sheets: Dictionary = WorldElementCatalog.catalog().mechanism_regions
	expect(regional_sheets.size()==16,"sixteen registered regions")
	for region: String in regional_sheets:
		await check_region(region)
	print("REGIONAL MECHANISM ART failures=",failures," regions=",seen.size())
	quit(0 if failures==0 else 1)
