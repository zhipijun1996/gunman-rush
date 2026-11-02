extends "res://experiments/terrain/art/light_study.gd"
## PIXEL-LIGHT-STUDY-02: the original palette, one world raster, real local lights.
## Inherits only real App construction, teardown and static capture mechanics.
const PIXEL_GRID := preload("res://shaders/pixel_grid_study.gdshader")
const LOCAL_LIGHT := preload("res://shaders/local_light_study.gdshader")
const LOCAL_PIXEL := preload("res://shaders/local_pixel_study.gdshader")
const LABELS := {"original":"原版", "aligned":"仅像素对齐", "lamps":"对齐 + 暖灯", "cool":"对齐 + 冷暖光"}
var grid_layer: CanvasLayer
var light_texture: GradientTexture2D
var light_sockets: Array[Dictionary] = []
var world_lighting_nodes: Array[CanvasItem] = []
var lighting_materials: Dictionary = {}
var source_points: Array[Dictionary] = []
var light_records: Array[Dictionary] = []
var capture_options: Array[String] = ["original","aligned","lamps","cool"]
var label_layer: CanvasLayer
var label_homes: Array[Dictionary] = []
var raster_materials: Dictionary = {}
var sprite_anchors: Dictionary = {}
var actor_anchors: Dictionary = {}
var raster_light_shader: Shader

func _ready() -> void:
	preset = "aligned"
	output = "res://build/pixel_light_study"
	await super._ready()

func open_place(value: String) -> void:
	if is_instance_valid(grid_layer): grid_layer.free()
	restore_world_labels()
	if is_instance_valid(label_layer): label_layer.free()
	label_homes.clear()
	light_sockets.clear(); world_lighting_nodes.clear(); lighting_materials.clear()
	raster_materials.clear(); sprite_anchors.clear(); actor_anchors.clear()
	await super.open_place(value)
	var world: Node = app.home_scene if place == "home" else app.stage
	collect_world(world)
	build_asset_rasters()
	build_sockets(world)
	grid_layer = CanvasLayer.new()
	grid_layer.layer = 1 # Above world/focus, below the existing App HUD at layer 2.
	add_child(grid_layer)
	var quad := ColorRect.new()
	quad.size = Vector2(1280,720)
	quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new(); material.shader = PIXEL_GRID
	quad.material = material; grid_layer.add_child(quad)
	grid_layer.hide()
	# World labels also need to stay readable. Their shared world transform is
	# preserved, but they render after the raster pass just like the HUD.
	label_layer = CanvasLayer.new()
	label_layer.layer = 2; label_layer.follow_viewport_enabled = true
	add_child(label_layer)
	var labels: Array[Node] = []
	find_world_labels(world, labels)
	for label: Node in labels:
		var home := label.get_parent()
		label_homes.append({"node":label,"parent":home})
		label.reparent(label_layer, true)

func find_world_labels(node: Node, labels: Array[Node]) -> void:
	if node is CanvasLayer: return
	if node is Label: labels.append(node)
	for child: Node in node.get_children(): find_world_labels(child,labels)

func restore_world_labels() -> void:
	for row: Dictionary in label_homes:
		if is_instance_valid(row.node) and is_instance_valid(row.parent):
			(row.node as Node).reparent(row.parent,true)
	label_homes.clear()

func collect_world(node: Node) -> void:
	# UI lives in its own canvas; do not rasterize or relight text and controls.
	if node is CanvasLayer: return
	if node is CanvasItem:
		var item := node as CanvasItem
		world_lighting_nodes.append(item)
		lighting_materials[item.get_instance_id()] = item.material
	for child: Node in node.get_children(): collect_world(child)

func build_asset_rasters() -> void:
	# Native TileMap and exact-boundary terrain already use 16px / 32wu.
	# High-resolution sprite/actor sources receive a stable *item-local* 2wu
	# sampling grid before the final world raster. Original images are retained.
	for item: CanvasItem in world_lighting_nodes:
		if item.material != null: continue
		if not (item is Sprite2D or item is UnderworldPlayer or item is UnderworldEnemy): continue
		var material := ShaderMaterial.new()
		material.shader = LOCAL_PIXEL
		raster_materials[item.get_instance_id()] = material
		if item is Sprite2D: sprite_anchors[item] = (item as Sprite2D).global_position
		elif item is Node2D: actor_anchors[item.get_instance_id()] = {"node":weakref(item),"position":(item as Node2D).position}

func _process(_delta: float) -> void:
	if preset == "original" or busy: return
	for entry: Dictionary in actor_anchors.values():
		var actor := (entry.node as WeakRef).get_ref() as Node2D
		if actor == null: continue
		var parent := actor.get_parent() as Node2D
		if parent == null: continue
		var unsnapped := parent.to_global(entry.position)
		actor.global_position = unsnapped.snapped(Vector2(2,2))

func build_sockets(world: Node) -> void:
	if place == "home":
		# Observed window/lantern centers in the actual home_props source PNG.
		var source_sockets := {
			"character":[Vector2(168,381),Vector2(462,354)],
			"upgrade":[Vector2(829,425),Vector2(975,341)],
			"achievements":[Vector2(1197,370),Vector2(1098,377)]}
		for entry: Dictionary in app.home_scene.world.specification.slots:
			if not source_sockets.has(str(entry.id)): continue
			var asset: Dictionary = app.home_scene.world.specification.assets[str(entry.building)]
			var factor := float(entry.building_height)/float(asset.opaque_height)
			for pixel: Vector2 in source_sockets[str(entry.id)]:
				var local := pixel-Vector2(asset.region[0],asset.region[1])-Vector2(asset.foot[0],asset.foot[1])
				var point := Vector2(float(entry.x),float(entry.y))+local*factor
				light_sockets.append({"position":point,"host":str(entry.id),"kind":"existing_window_or_lantern","radius":150.0})
	collect_prop_sockets(world)

func collect_prop_sockets(node: Node) -> void:
	if node is UnderworldScenery:
		var props: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/underworld_plains/decor/chime_props.json")).regions
		for row: Dictionary in (node as UnderworldScenery).placements:
			var kind := str(row.kind)
			if not props[kind].has("light_anchor"): continue
			var source: Dictionary = props[kind]
			var point: Vector2 = row.bounds.position+Vector2(source.light_anchor[0],source.light_anchor[1])*float(row.scale)
			light_sockets.append({"position":point,"host":kind,"kind":"existing_prop_lantern","radius":130.0})
	if node is ShotLatch:
		var latch := node as ShotLatch
		if is_instance_valid(latch.bell_body):
			light_sockets.append({"position":latch.bell_body.global_position,"host":str(latch.name),"kind":"existing_copper_bell","radius":145.0})
	for child: Node in node.get_children(): collect_prop_sockets(child)

func apply_preset(value: String) -> void:
	preset = value
	for child: Node in experiments.get_children(): child.free()
	for item: CanvasItem in world_lighting_nodes:
		item.material = lighting_materials[item.get_instance_id()]
		if value != "original" and raster_materials.has(item.get_instance_id()):
			item.material = raster_materials[item.get_instance_id()]
	for sprite: Sprite2D in sprite_anchors:
		sprite.global_position = sprite_anchors[sprite] if value == "original" else (sprite_anchors[sprite] as Vector2).snapped(Vector2(2,2))
	for entry: Dictionary in actor_anchors.values():
		var actor := (entry.node as WeakRef).get_ref() as Node2D
		if actor != null: actor.position = entry.position
	if value != "original": _process(0.0)
	grid_layer.visible = value != "original"
	light_records.clear()
	for backdrop: UnderworldParallax in backdrops: backdrop._update()
	if value in ["original","aligned"]: return
	install_lit_materials()
	var ambient := CanvasModulate.new()
	ambient.color = Color(.98,.98,1) if value == "lamps" else Color(.76,.84,1)
	experiments.add_child(ambient)
	install_occluders()
	if value == "cool":
		var sky_fill := DirectionalLight2D.new()
		sky_fill.color = Color("9bcaff")
		sky_fill.energy = .23
		experiments.add_child(sky_fill)
	for row: Dictionary in light_sockets:
		add_lamp(row)

func install_lit_materials() -> void:
	var surface := ShaderMaterial.new(); surface.shader = LOCAL_LIGHT
	if raster_light_shader == null:
		raster_light_shader = Shader.new()
		raster_light_shader.code = LOCAL_PIXEL.code + "\nvoid light()" + LOCAL_LIGHT.code.get_slice("void light()",1)
	var adapted: Dictionary = {}
	for item: CanvasItem in world_lighting_nodes:
		var old: Material = lighting_materials[item.get_instance_id()]
		if old == null:
			if raster_materials.has(item.get_instance_id()):
				var material := ShaderMaterial.new(); material.shader = raster_light_shader
				item.material = material
			else: item.material = surface
		elif old is ShaderMaterial:
			var original := old as ShaderMaterial
			# Existing source-native terrain was unshaded, so Godot point lights
			# could never affect it. Adapt only this live experimental instance.
			if "underworld_terrain.gdshader" not in original.shader.resource_path: continue
			var material := original.duplicate() as ShaderMaterial
			var key := original.shader.resource_path
			if not adapted.has(key):
				var shader := Shader.new()
				shader.code = original.shader.code.replace("render_mode unshaded;", "") + "\n" + LOCAL_LIGHT.code.get_slice("void light()",1).insert(0,"void light()")
				adapted[key] = shader
			material.shader = adapted[key]
			item.material = material

func install_occluders() -> void:
	var world: Node = app.home_scene if place == "home" else app.stage
	var pieces: Array[Rect2] = []
	collect_occlusion(world, pieces)
	for rect: Rect2 in pieces:
		var polygon := OccluderPolygon2D.new()
		polygon.polygon = PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
		var occluder := LightOccluder2D.new()
		occluder.occluder = polygon
		experiments.add_child(occluder)

func collect_occlusion(node: Node, pieces: Array[Rect2]) -> void:
	if node is UnderworldTerrain:
		for rect: Rect2 in (node as UnderworldTerrain).union_pieces:
			pieces.append(Rect2(rect.position+(node as Node2D).global_position,rect.size))
	for child: Node in node.get_children(): collect_occlusion(child,pieces)

func lamp_texture() -> GradientTexture2D:
	if light_texture != null: return light_texture
	light_texture = GradientTexture2D.new()
	light_texture.width = 256; light_texture.height = 256
	light_texture.fill = GradientTexture2D.FILL_RADIAL
	light_texture.fill_from = Vector2(.5,.5); light_texture.fill_to = Vector2(1,.5)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0,.12,.35,.7,1])
	gradient.colors = PackedColorArray([Color.WHITE,Color(.92,.92,.92,1),Color(.55,.55,.55,1),Color(.12,.12,.12,1),Color(0,0,0,1)])
	light_texture.gradient = gradient
	return light_texture

func add_lamp(row: Dictionary) -> void:
	var light := PointLight2D.new()
	light.position = row.position
	light.texture = lamp_texture()
	light.texture_scale = float(row.radius)/128.0
	light.color = Color("ffbc69") if preset == "lamps" else Color("ffd59d")
	light.energy = .85 if preset == "lamps" else 1.0
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	light.shadow_filter_smooth = 1.5
	light.range_z_min = -100; light.range_z_max = 100
	experiments.add_child(light)
	# Small optical bloom belongs to this same emitter; the large light pool
	# above still uses Godot's real shadow-aware PointLight2D.
	var bloom := Sprite2D.new()
	bloom.texture = lamp_texture()
	bloom.position = row.position
	bloom.scale = Vector2.ONE*.22
	bloom.modulate = Color(light.color,.16)
	bloom.z_index = 20
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	bloom.material = additive
	experiments.add_child(bloom)
	light_records.append({"host":row.host,"kind":row.kind,"position":[light.position.x,light.position.y],"radius":row.radius,"energy":light.energy,"native_point_light":true,"occlusion":"actual terrain rectangles, no new collision"})

func capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	for location: String in ["home","plains"]:
		if place != location: await open_place(location)
		freeze(app)
		var windows: Array[Dictionary]
		if place == "home":
			windows = [{"id":"home","position":Vector2(440,414),"camera":Vector2(640,310)},{"id":"home_gate","position":Vector2(2920,414),"camera":Vector2(2640,310)}]
		else:
			var stage := app.stage as PlainsRegionStage
			windows = [{"id":"plains_spawn","position":stage.spawn}]
			for area: Dictionary in stage.generated.manifest.areas:
				if str(area.get("role","")) == "junction":
					windows.append({"id":"plains_junction","position":Vector2(area.position[0],area.position[1])-Vector2(0,18)})
					break
			for socket: Dictionary in light_sockets:
				if socket.kind == "existing_copper_bell":
					windows.append({"id":"plains_bell","position":socket.position+Vector2(-140,50)})
					break
		for window: Dictionary in windows:
			if place == "home":
				app.home_scene.player.position = window.position
				app.home_scene.camera.position = window.camera
				app.home_scene.camera.force_update_scroll()
			else:
				app.controller.return_to_segment(window.position)
				app._run_camera.snap_to_target(); app._run_camera.force_update_scroll()
			for style: String in capture_options:
				apply_preset(style)
				for frame: int in 3: await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var path := output+"/"+str(window.id)+"_"+style+".png"
				assert(get_viewport().get_texture().get_image().save_png(path) == OK)
				evidence.append({"window":window.id,"preset":style,"path":path,"position":[window.position.x,window.position.y],"seed":SEED,"manifest":app.stage.generated.manifest.manifest_hash if place == "plains" else "fixed-home","world_pixel_step":2 if style != "original" else 0,"lighting":light_records.duplicate(true),"positioned_still":true})
				print("PIXEL_LIGHT_CAPTURE "+path)
	FileAccess.open(output+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"task":"PIXEL-LIGHT-STUDY-02","labels":LABELS,"captures":evidence,"scope":"Real App; frozen positioned stills; world raster only; original albedo and layouts; opt-in point lights; no traversal/full QA/device claim"},"  "))
	print("PIXEL_LIGHT_DONE screenshots=%d"%evidence.size())
	busy = true
	restore_world_labels()
	app.abandon_run()
	await WorldAudioLifecycle.drain_world(app)
	get_tree().quit()

func make_panel() -> void:
	panel = CanvasLayer.new(); panel.layer = 110; add_child(panel)
	var bar := HBoxContainer.new(); bar.position = Vector2(310,670); panel.add_child(bar)
	for id: String in ["original","aligned","lamps","cool"]:
		var button := Button.new(); button.text = LABELS[id]; bar.add_child(button)
		button.add_theme_font_override("font",UnderworldUI.FONT)
		button.pressed.connect(func() -> void: apply_preset(id))
	for id: String in ["home","plains"]:
		var button := Button.new(); button.text = id.to_upper(); bar.add_child(button)
		button.pressed.connect(func() -> void:
			if busy: return
			await open_place(id)
			apply_preset(preset))
