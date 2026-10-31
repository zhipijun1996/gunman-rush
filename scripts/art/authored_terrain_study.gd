extends "res://scripts/art/high_density_terrain_study.gd"
## TERRAIN-DENSITY-04: same authored master and warm emitters; compare 2wu vs1wu.
const AUTHORED_BOUNDARY := preload("res://shaders/authored_boundary.gdshader")
const FINE_SET := preload("res://assets/authored_terrain_study/fine.tres")
const COARSE_SET := preload("res://assets/authored_terrain_study/coarse.tres")
const FINE_SOURCE := preload("res://assets/authored_terrain_study/source_fine.png")
const COARSE_SOURCE := preload("res://assets/authored_terrain_study/source_coarse.png")
const STUDY_LABELS := {"reference":"原版地形 + 暖光", "terrain_coarse":"仅地形粗 · 人物细", "coarse":"全世界粗 + 暖光", "fine":"全世界细 + 暖光"}
var study_mode := "fine"
var art_step := 1.0

func _ready() -> void:
	preset="fine"
	output="res://build/authored_terrain_study/captures"
	for arg: String in OS.get_cmdline_user_args():
		if arg=="--capture": capture=true
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--place="): place=arg.trim_prefix("--place=")
	await open_place(place)
	if capture: await capture_all()
	else:
		make_panel()
		apply_preset(study_mode)

func open_place(value: String) -> void:
	await super.open_place(value)
	for row: Dictionary in terrain_rows:
		var cells: Dictionary={}
		for cell: Vector2i in (row.node as UnderworldTerrain).core_layer.get_used_cells():
			cells[cell]=(row.node as UnderworldTerrain).core_layer.get_cell_atlas_coords(cell)
		row["original_cells"]=cells

func _process(_delta: float) -> void:
	if busy: return
	for entry: Dictionary in actor_anchors.values():
		var actor:=(entry.node as WeakRef).get_ref() as Node2D
		if actor==null: continue
		var parent:=actor.get_parent() as Node2D
		if parent!=null: actor.global_position=parent.to_global(entry.position).snapped(Vector2.ONE*art_step)

func apply_preset(value: String) -> void:
	study_mode=value
	art_step=2.0 if value=="coarse" else 1.0
	for row: Dictionary in terrain_rows:
		var layer: TileMapLayer=(row.node as UnderworldTerrain).core_layer
		for cell: Vector2i in row.original_cells: layer.set_cell(cell,0,row.original_cells[cell])
	# All modes use exactly this same .85 warm-light/occluder/bloom setup.
	# Virtual install_dense_materials below swaps authored art, never old slate.
	super.apply_preset("dense_lamps")
	preset=value
	for item: CanvasItem in world_lighting_nodes:
		if raster_materials.has(item.get_instance_id()):
			(item.material as ShaderMaterial).set_shader_parameter("cell_world_units",art_step)
	for sprite: Sprite2D in sprite_anchors:
		sprite.global_position=(sprite_anchors[sprite] as Vector2).snapped(Vector2.ONE*art_step)
	(grid_layer.get_child(0) as ColorRect).material.set_shader_parameter("block_size",art_step)
	_process(0.0)

func authored_material(original: ShaderMaterial,origin: Vector2) -> ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=AUTHORED_BOUNDARY
	var texture: Texture2D=COARSE_SOURCE if study_mode in ["coarse","terrain_coarse"] else FINE_SOURCE
	material.set_shader_parameter("source_pixels",texture)
	material.set_shader_parameter("source_size",Vector2(texture.get_size()))
	material.set_shader_parameter("art_scale",1.0 if study_mode in ["coarse","terrain_coarse"] else 2.0)
	material.set_shader_parameter("shape_origin",origin)
	if original!=null:
		for key: String in ["shape_origin","face_count","faces","corner_count","corners"]:
			material.set_shader_parameter(key,original.get_shader_parameter(key))
	return material

func install_dense_materials() -> void:
	if study_mode=="reference": return
	for row: Dictionary in terrain_rows:
		var terrain:=row.node as UnderworldTerrain
		var coarse_terrain:=study_mode in ["coarse","terrain_coarse"]
		terrain.core_layer.tile_set=COARSE_SET if coarse_terrain else FINE_SET
		terrain.core_layer.scale=Vector2.ONE*(2.0 if coarse_terrain else 1.0)
		var surface:=ShaderMaterial.new();surface.shader=LOCAL_LIGHT
		terrain.core_layer.material=surface
		assert(terrain.core_layer.tile_set.tile_size.x*terrain.core_layer.scale.x==32)
		for cell: Vector2i in row.original_cells:
			var coord: Vector2i=row.original_cells[cell]
			coord.x+=posmod(cell.x,3)*8
			terrain.core_layer.set_cell(cell,0,coord)
		for child: Node in terrain.get_children():
			if not child is ColorRect or not child.has_meta("exact_union_piece"): continue
			var quad:=child as ColorRect
			quad.material=authored_material(lighting_materials[quad.get_instance_id()],quad.global_position)
	for item: CanvasItem in world_lighting_nodes:
		if not item is PlainsWoodPlatformArt.PixelOneWayPaint: continue
		var paint:=item as PlainsWoodPlatformArt.PixelOneWayPaint
		var rect:=Rect2(paint.bounds.position,Vector2(paint.bounds.size.x,minf(6,paint.bounds.size.y)))
		var origin:=paint.global_position+rect.position
		var material:=authored_material(null,origin)
		var faces:=PackedVector4Array([Vector4(origin.x,origin.y,origin.x+rect.size.x,origin.y)])
		faces.resize(64)
		material.set_shader_parameter("face_count",1)
		material.set_shader_parameter("faces",faces)
		material.set_shader_parameter("corner_count",0)
		var quad:=ColorRect.new();quad.position=rect.position;quad.size=rect.size
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
			var fixed_lights: Array[Dictionary]=[]
			for style: String in ["reference","terrain_coarse","coarse","fine"]:
				apply_preset(style)
				if fixed_lights.is_empty(): fixed_lights=light_records.duplicate(true)
				else: assert(fixed_lights==light_records,"All comparison modes must retain identical emitters")
				for frame: int in 3: await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var path:=output+"/"+str(window.id)+"_"+style+".png"
				assert(get_viewport().get_texture().get_image().save_png(path)==OK)
				evidence.append({"window":window.id,"preset":style,"path":path,"position":[window.position.x,window.position.y],"seed":SEED,"manifest":app.stage.generated.manifest.manifest_hash if place=="plains" else "fixed-home","tile_px":32 if style=="fine" else 16,"world_tile_wu":32,"world_art_step":art_step,"material":"original" if style=="reference" else "shared authored master; coarse derived from fine","light_emitters":light_records.duplicate(true),"positioned_still":true})
				print("AUTHORED_CAPTURE "+path)
	FileAccess.open(output+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"task":"TERRAIN-DENSITY-04","labels":STUDY_LABELS,"captures":evidence,"scope":"20 real Godot positioned stills; equal warm emitters and geometry; new authored47 master; coarse2wu vs fine1wu whole-world sampling plus terrain-only coarse control; HUD sharp; not motion/device/full-game migration"},"  "))
	print("AUTHORED_DONE screenshots=%d"%evidence.size())
	busy=true;restore_world_labels();clear_overlays()
	app.abandon_run()
	await WorldAudioLifecycle.drain_world(app)
	get_tree().quit()

func make_panel() -> void:
	panel=CanvasLayer.new();panel.layer=110;add_child(panel)
	var bar:=HBoxContainer.new();bar.position=Vector2(200,670);panel.add_child(bar)
	for id: String in ["reference","terrain_coarse","coarse","fine"]:
		var button:=Button.new();button.text=STUDY_LABELS[id];bar.add_child(button)
		button.add_theme_font_override("font",UnderworldUI.FONT)
		button.pressed.connect(func() -> void:apply_preset(id))
	for id: String in ["home","plains"]:
		var button:=Button.new();button.text=id.to_upper();bar.add_child(button)
		button.pressed.connect(func() -> void:
			if busy:return
			await open_place(id)
			apply_preset(study_mode))
