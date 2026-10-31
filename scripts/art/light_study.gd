extends Node
## LIGHT-STUDY-01: opt-in live art experiment, no production source/asset edits.
## Capture mode uses positioned stills of the real App. It makes no route claim.
const SEED := "level-design-v2-baseline/08"
const GRADE := preload("res://shaders/light_study.gdshader")
const PRESETS := {
	"dawn": {
		"stone_dark":"344b51", "stone_light":"87968a", "grass_dark":"507c43", "grass_light":"dcdf8b",
		"sky_top":"3985ac", "sky_bottom":"f7e6bb", "middle":["708e96","adc3b5"], "near":["476570","819d91"]},
	"jade": {
		"stone_dark":"102a3a", "stone_light":"497678", "grass_dark":"247d67", "grass_light":"9ee7ab",
		"sky_top":"0d2444", "sky_bottom":"488f91", "middle":["29465e","507d84"], "near":["192f43","395963"]},
	"lilac": {
		"stone_dark":"303450", "stone_light":"77748b", "grass_dark":"368d87", "grass_light":"c6e8cc",
		"sky_top":"484f89", "sky_bottom":"e7b3a2", "middle":["787b9e","b6a5b9"], "near":["494e76","8a809c"]}
}
var app: DemoApp
var preset := "jade"
var place := "home"
var capture := false
var output := "res://build/light_study"
var originals: Dictionary = {}
var nodes: Array[CanvasItem] = []
var experiments: Node2D
var panel: CanvasLayer
var busy := false
var evidence: Array[Dictionary] = []
var backdrops: Dictionary = {}
var boundary_shader: Shader

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--capture": capture = true
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--place="): place = arg.trim_prefix("--place=")
	await open_place(place)
	if capture:
		await capture_all()
	else:
		make_panel()
		apply_preset(preset)

func open_place(value: String) -> void:
	busy = true
	if is_instance_valid(app):
		app.abandon_run()
		await WorldAudioLifecycle.drain_world(app)
		app.free()
		await get_tree().process_frame
	originals.clear(); nodes.clear(); backdrops.clear()
	place = value
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	add_child(app)
	if place == "home": app._show_home()
	else: assert(app.start_plains(SEED))
	# UI binding and visibility run in _process; physics ticks alone can leave
	# the initial hidden-boss template on screen in a frozen capture.
	for tick: int in 8:
		await get_tree().physics_frame
		await get_tree().process_frame
	inventory(app)
	experiments = Node2D.new()
	experiments.name = "LightStudyLocalGlows"
	if place == "home": app.home_scene.add_child(experiments)
	else: app.stage.add_child(experiments)
	busy = false

func inventory(node: Node) -> void:
	if node is UnderworldParallax: backdrops[node] = (node as UnderworldParallax).layer_specs.duplicate(true)
	if node is CanvasItem:
		var item := node as CanvasItem
		if item is Sprite2D or item is TileMapLayer or item is PlainsWoodPlatformArt.PixelOneWayPaint or (item is ColorRect and item.material is ShaderMaterial):
			nodes.append(item)
			originals[item.get_instance_id()] = item.material
	for child: Node in node.get_children(): inventory(child)

func make_grade(style: Dictionary, role: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GRADE
	material.set_shader_parameter("role", role)
	for key: String in ["stone_dark","stone_light","grass_dark","grass_light","sky_top","sky_bottom"]:
		material.set_shader_parameter(key, Color(style[key]))
	return material

func apply_preset(value: String) -> void:
	preset = value
	for child: Node in experiments.get_children(): child.free()
	for item: CanvasItem in nodes:
		item.material = originals[item.get_instance_id()]
		if item is Sprite2D and str(item.name).begins_with("Underworld_"): (item as Sprite2D).region_enabled = false
	for backdrop: UnderworldParallax in backdrops:
		backdrop.layer_specs = backdrops[backdrop].duplicate(true)
		if value != "original":
			backdrop.layer_specs[1].bottom_ratio = .88
			backdrop.layer_specs[2].bottom_ratio = 1.17
		backdrop._update()
	if value == "original": return
	var style: Dictionary = PRESETS[value]
	var terrain := make_grade(style, 0)
	var props := make_grade(style, 2)
	var sky := make_grade(style, 1)
	for item: CanvasItem in nodes:
		var old: Material = originals[item.get_instance_id()]
		if (item is TileMapLayer and item.get_parent() is UnderworldTerrain) or item is PlainsWoodPlatformArt.PixelOneWayPaint:
			item.material = terrain
		elif old is ShaderMaterial and (old as ShaderMaterial).shader.resource_path.ends_with("underworld_terrain.gdshader"):
			# Same native boundary sampler; append exactly the same grading as cells.
			var material := old.duplicate() as ShaderMaterial
			if boundary_shader == null:
				boundary_shader = Shader.new()
				var helper := GRADE.code.get_slice("vec3 terrain_grade",1).get_slice("void fragment()",0)
				boundary_shader.code = (old as ShaderMaterial).shader.code.replace("void fragment(){", "uniform vec4 stone_dark : source_color;\nuniform vec4 stone_light : source_color;\nuniform vec4 grass_dark : source_color;\nuniform vec4 grass_light : source_color;\nvec3 terrain_grade"+helper+"\nvoid fragment(){").replace("COLOR=sample_pixel(region,sample_at);", "COLOR=sample_pixel(region,sample_at); COLOR.rgb=terrain_grade(COLOR.rgb);")
			material.shader = boundary_shader
			for key: String in ["stone_dark","stone_light","grass_dark","grass_light"]: material.set_shader_parameter(key, Color(style[key]))
			item.material = material
		elif item is Sprite2D:
			if str(item.name).begins_with("Underworld_far"):
				item.material = sky
			elif old is ShaderMaterial and (old as ShaderMaterial).shader.resource_path.ends_with("underworld_parallax_edge.gdshader"):
				if str(item.name).begins_with("Underworld_"):
					# Moving a backdrop up exposes its bottom edge. Extend its last
					# source row using clamped sampling so it still covers the viewport.
					var sprite := item as Sprite2D
					sprite.region_enabled = true
					sprite.region_rect = Rect2(Vector2.ZERO,Vector2(sprite.texture.get_width(),sprite.texture.get_height()*1.5))
				var material := old.duplicate() as ShaderMaterial
				var ramp: Array = style.near if str(item.name).begins_with("Underworld_near") else style.middle
				material.set_shader_parameter("fog_shadow", Color(ramp[0]))
				material.set_shader_parameter("fog_highlight", Color(ramp[1]))
				item.material = material
			elif item.get_parent() is UnderworldHomeWorld or item.get_parent() is UnderworldScenery:
				item.material = props
	add_local_glows()

func add_local_glows() -> void:
	# Lights are attached to existing architecture/flowers, never reward markers.
	var texture := GradientTexture2D.new()
	texture.width = 64; texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5); texture.fill_to = Vector2(1,.5)
	var gradient := Gradient.new()
	var color := Color("ffe5a3") if preset == "dawn" else Color("8df8d9") if preset == "jade" else Color("f8b6d1")
	gradient.offsets = PackedFloat32Array([0,.10,.35,1])
	gradient.colors = PackedColorArray([Color(color,.40),Color(color,.15),Color(color,.04),Color(color,0)])
	texture.gradient = gradient
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for item: CanvasItem in nodes:
		if not item is Sprite2D: continue
		var sprite := item as Sprite2D
		var selected := sprite.get_parent() is UnderworldHomeWorld and str(sprite.name).ends_with("_building")
		selected = selected or ((sprite.get_parent() is UnderworldScenery or sprite.get_parent() is UnderworldHomeWorld) and "flowers" in str(sprite.name))
		if not selected: continue
		var glow := Sprite2D.new()
		glow.texture = texture; glow.material = additive
		glow.z_index = -1
		experiments.add_child(glow)
		if sprite.has_meta("home_root"):
			glow.global_position = sprite.get_meta("home_root") + Vector2(0,-35 if str(sprite.name).ends_with("_building") else -8)
		else:
			glow.global_position = sprite.global_position + Vector2(sprite.texture.get_width()*.5,sprite.texture.get_height()*.8)*sprite.scale
		glow.scale = Vector2.ONE*(1.6 if str(sprite.name).ends_with("_building") else .45)

func freeze(node: Node) -> void:
	node.set_physics_process(false)
	node.set_process(false)
	for child: Node in node.get_children(): freeze(child)

func capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	for location: String in ["home","plains"]:
		if place != location: await open_place(location)
		freeze(app)
		var windows: Array[Dictionary] = []
		if place == "home":
			app.home_scene.set_process(false)
			windows = [{"id":"home","position":Vector2(440,414),"camera":Vector2(640,310)}, {"id":"home_gate","position":Vector2(2920,414),"camera":Vector2(2640,310)}]
		else:
			var stage := app.stage as PlainsRegionStage
			windows.append({"id":"plains_spawn","position":stage.spawn})
			for area: Dictionary in stage.generated.manifest.areas:
				if str(area.get("role","")) == "junction":
					windows.append({"id":"plains_junction","position":Vector2(area.position[0],area.position[1])-Vector2(0,18)})
					break
		for window: Dictionary in windows:
			if place == "home":
				app.home_scene.player.position = window.position
				app.home_scene.camera.position = window.camera
				app.home_scene.camera.force_update_scroll()
			else:
				app.controller.return_to_segment(window.position)
				app._run_camera.snap_to_target(); app._run_camera.force_update_scroll()
			for style: String in ["original","dawn","jade","lilac"]:
				apply_preset(style)
				for tick: int in 3: await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var path := output+"/"+str(window.id)+"_"+style+".png"
				assert(get_viewport().get_texture().get_image().save_png(path) == OK)
				evidence.append({"window":window.id,"preset":style,"path":path,"position":[window.position.x,window.position.y],"positioned_still":true,"seed":SEED,"manifest":app.stage.generated.manifest.manifest_hash if place == "plains" else "fixed-home"})
				print("LIGHT_STUDY_CAPTURE "+path)
	FileAccess.open(output+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"task":"LIGHT-STUDY-01","presets":PRESETS,"captures":evidence,"scope":"Real Godot App; positioned frozen stills, no traversal or full QA claim"},"  "))
	print("LIGHT_STUDY_DONE screenshots=%d"%evidence.size())
	app.abandon_run()
	await WorldAudioLifecycle.drain_world(app)
	get_tree().quit()

func make_panel() -> void:
	panel = CanvasLayer.new(); panel.layer = 110; add_child(panel)
	var bar := HBoxContainer.new(); bar.position = Vector2(400,668); panel.add_child(bar)
	for id: String in ["original","dawn","jade","lilac"]:
		var button := Button.new(); button.text = id.to_upper(); bar.add_child(button)
		button.pressed.connect(func() -> void: apply_preset(id))
	for id: String in ["home","plains"]:
		var button := Button.new(); button.text = id.to_upper(); bar.add_child(button)
		button.pressed.connect(func() -> void:
			if busy: return
			await open_place(id)
			apply_preset(preset))
