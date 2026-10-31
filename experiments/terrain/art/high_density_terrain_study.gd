extends "res://experiments/terrain/art/pixel_light_study.gd"
## HIGH-DENSITY-TERRAIN-03: increase terrain density; retain detailed game sprites.
const DENSE_CORE := preload("res://shaders/dense_tile_core.gdshader")
const DENSE_BOUNDARY := preload("res://shaders/dense_tile_boundary.gdshader")
const DENSE_SET := preload("res://assets/high_density_terrain_study/terrain_32.tres")
const DENSE_MASTER := preload("res://assets/high_density_terrain_study/master_256.png")
const DENSE_FIELD := preload("res://assets/high_density_terrain_study/edges_32.png")
const DENSE_LABELS := {"original":"原版16px Tile", "low_grid":"上轮低密度对齐", "dense":"32px Tile · 保留细节", "dense_lamps":"32px Tile + 暖灯"}
var terrain_rows: Array[Dictionary] = []
var overlays: Array[Node] = []

func _ready() -> void:
	preset="dense"
	output="res://build/high_density_terrain_study/captures"
	for arg: String in OS.get_cmdline_user_args():
		if arg=="--capture": capture=true
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--place="): place=arg.trim_prefix("--place=")
	await open_place(place)
	if capture: await capture_all()
	else:
		make_panel()
		apply_preset(preset)

func open_place(value: String) -> void:
	clear_overlays()
	terrain_rows.clear()
	await super.open_place(value)
	var world: Node=app.home_scene if place=="home" else app.stage
	collect_dense_terrain(world)

func collect_dense_terrain(node: Node) -> void:
	if node is UnderworldTerrain:
		var terrain:=node as UnderworldTerrain
		terrain_rows.append({"node":terrain,"tileset":terrain.core_layer.tile_set,"scale":terrain.core_layer.scale})
	for child: Node in node.get_children(): collect_dense_terrain(child)

func _process(_delta: float) -> void:
	if preset=="original" or busy: return
	var step:=Vector2(2,2) if preset in ["low_grid","aligned"] else Vector2.ONE
	for entry: Dictionary in actor_anchors.values():
		var actor:=(entry.node as WeakRef).get_ref() as Node2D
		if actor==null: continue
		var parent:=actor.get_parent() as Node2D
		if parent!=null: actor.global_position=parent.to_global(entry.position).snapped(step)

func clear_overlays() -> void:
	for item: Node in overlays:
		if is_instance_valid(item): item.free()
	overlays.clear()

func apply_preset(value: String) -> void:
	clear_overlays()
	for row: Dictionary in terrain_rows:
		var terrain:=row.node as UnderworldTerrain
		terrain.core_layer.tile_set=row.tileset
		terrain.core_layer.scale=row.scale
	if value=="low_grid":
		for material: ShaderMaterial in raster_materials.values(): material.set_shader_parameter("cell_world_units",2.0)
		(grid_layer.get_child(0) as ColorRect).material.set_shader_parameter("block_size",2.0)
		super.apply_preset("aligned")
		preset=value
		return
	preset=value
	for child: Node in experiments.get_children(): child.free()
	for item: CanvasItem in world_lighting_nodes:
		item.material=lighting_materials[item.get_instance_id()]
		if value!="original" and raster_materials.has(item.get_instance_id()):
			var material:=raster_materials[item.get_instance_id()] as ShaderMaterial
			material.set_shader_parameter("cell_world_units",1.0)
			item.material=material
	for sprite: Sprite2D in sprite_anchors:
		sprite.global_position=sprite_anchors[sprite] if value=="original" else (sprite_anchors[sprite] as Vector2).snapped(Vector2.ONE)
	for entry: Dictionary in actor_anchors.values():
		var actor:=(entry.node as WeakRef).get_ref() as Node2D
		if actor!=null: actor.position=entry.position
	grid_layer.visible=value!="original"
	(grid_layer.get_child(0) as ColorRect).material.set_shader_parameter("block_size",1.0)
	light_records.clear()
	for backdrop: UnderworldParallax in backdrops: backdrop._update()
	if value=="original": return
	_process(0.0)
	if value=="dense_lamps":
		super.install_lit_materials()
		for item: CanvasItem in world_lighting_nodes:
			if raster_materials.has(item.get_instance_id()): (item.material as ShaderMaterial).set_shader_parameter("cell_world_units",1.0)
		var ambient:=CanvasModulate.new(); ambient.color=Color(.98,.98,1)
		experiments.add_child(ambient)
		install_occluders()
		preset="lamps"
		for socket: Dictionary in light_sockets: add_lamp(socket)
		preset=value
	install_dense_materials()

func install_dense_materials() -> void:
	for row: Dictionary in terrain_rows:
		var terrain:=row.node as UnderworldTerrain
		terrain.core_layer.tile_set=DENSE_SET
		terrain.core_layer.scale=Vector2.ONE
		assert(terrain.core_layer.tile_set.tile_size==Vector2i(32,32))
		assert(terrain.core_layer.scale==Vector2.ONE)
		var core:=ShaderMaterial.new(); core.shader=DENSE_CORE
		core.set_shader_parameter("dense_master",DENSE_MASTER)
		core.set_shader_parameter("edge_field",DENSE_FIELD)
		terrain.core_layer.material=core
		for child: Node in terrain.get_children():
			if not child is ColorRect or not (child as ColorRect).has_meta("exact_union_piece"): continue
			var quad:=child as ColorRect
			var original:=lighting_materials[quad.get_instance_id()] as ShaderMaterial
			var material:=ShaderMaterial.new(); material.shader=DENSE_BOUNDARY
			for key: String in ["shape_origin","face_count","faces","corner_count","corners"]:
				material.set_shader_parameter(key,original.get_shader_parameter(key))
			material.set_shader_parameter("dense_master",DENSE_MASTER)
			quad.material=material
	for item: CanvasItem in world_lighting_nodes:
		if not item is PlainsWoodPlatformArt.PixelOneWayPaint: continue
		var paint:=item as PlainsWoodPlatformArt.PixelOneWayPaint
		var rect:=Rect2(paint.bounds.position,Vector2(paint.bounds.size.x,minf(6,paint.bounds.size.y)))
		var origin:=paint.global_position+rect.position
		var material:=ShaderMaterial.new(); material.shader=DENSE_BOUNDARY
		var faces:=PackedVector4Array([Vector4(origin.x,origin.y,origin.x+rect.size.x,origin.y)])
		faces.resize(64)
		material.set_shader_parameter("dense_master",DENSE_MASTER)
		material.set_shader_parameter("shape_origin",origin)
		material.set_shader_parameter("face_count",1)
		material.set_shader_parameter("faces",faces)
		material.set_shader_parameter("corner_count",0)
		var quad:=ColorRect.new(); quad.position=rect.position;quad.size=rect.size
		quad.material=material;quad.z_index=1;quad.mouse_filter=Control.MOUSE_FILTER_IGNORE
		paint.add_child(quad);overlays.append(quad)

func capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	for location: String in ["home","plains"]:
		if place!=location: await open_place(location)
		freeze(app)
		var windows: Array[Dictionary]
		if place=="home":
			windows=[{"id":"home","position":Vector2(440,414),"camera":Vector2(640,310)},{"id":"home_gate","position":Vector2(2920,414),"camera":Vector2(2640,310)}]
		else:
			var stage:=app.stage as PlainsRegionStage
			windows=[{"id":"plains_spawn","position":stage.spawn}]
			for area: Dictionary in stage.generated.manifest.areas:
				if str(area.get("role",""))=="junction":
					windows.append({"id":"plains_junction","position":Vector2(area.position[0],area.position[1])-Vector2(0,18)});break
			for socket: Dictionary in light_sockets:
				if socket.kind=="existing_copper_bell":
					windows.append({"id":"plains_bell","position":socket.position+Vector2(-140,50)});break
		for window: Dictionary in windows:
			if place=="home":
				app.home_scene.player.position=window.position
				app.home_scene.camera.position=window.camera
				app.home_scene.camera.force_update_scroll()
			else:
				app.controller.return_to_segment(window.position)
				app._run_camera.snap_to_target();app._run_camera.force_update_scroll()
			for style: String in ["original","low_grid","dense","dense_lamps"]:
				apply_preset(style)
				for frame: int in 3: await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var path:=output+"/"+str(window.id)+"_"+style+".png"
				assert(get_viewport().get_texture().get_image().save_png(path)==OK)
				evidence.append({"window":window.id,"preset":style,"path":path,"position":[window.position.x,window.position.y],"seed":SEED,"manifest":app.stage.generated.manifest.manifest_hash if place=="plains" else "fixed-home","tile_px":32 if style.begins_with("dense") else 16,"world_tile_wu":32,"units_per_art_pixel":1 if style.begins_with("dense") else 2,"source_sprite_detail":"retained at 1wu sampling" if style.begins_with("dense") else "original" if style=="original" else "previous 2wu quantization","lighting":light_records.duplicate(true),"positioned_still":true})
				print("HIGH_DENSITY_CAPTURE "+path)
	FileAccess.open(output+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"task":"HIGH-DENSITY-TERRAIN-03","labels":DENSE_LABELS,"captures":evidence,"scope":"Real App; same geometry/seed; positioned stills; new 32px native TileSet plus exact-boundary material; high-resolution sprite/background detail retained; not full migration/route/device acceptance"},"  "))
	print("HIGH_DENSITY_DONE screenshots=%d"%evidence.size())
	busy=true;restore_world_labels();clear_overlays()
	app.abandon_run()
	await WorldAudioLifecycle.drain_world(app)
	get_tree().quit()

func make_panel() -> void:
	panel=CanvasLayer.new();panel.layer=110;add_child(panel)
	var bar:=HBoxContainer.new();bar.position=Vector2(160,670);panel.add_child(bar)
	for id: String in ["original","low_grid","dense","dense_lamps"]:
		var button:=Button.new();button.text=DENSE_LABELS[id];bar.add_child(button)
		button.add_theme_font_override("font",UnderworldUI.FONT)
		button.pressed.connect(func() -> void:apply_preset(id))
	for id: String in ["home","plains"]:
		var button:=Button.new();button.text=id.to_upper();bar.add_child(button)
		button.pressed.connect(func() -> void:
			if busy:return
			await open_place(id)
			apply_preset(preset))
