extends Node2D
## Camera, gameplay resources and render responsibilities precede painting.
const CONFIG := "res://config/art/engine_first_2d.json"
const NATIVE := "res://assets/engine_first_2d/native/"
var config: Dictionary
var ready_to_capture := false
var grey_structure: Node2D
var grey_background: Polygon2D
var terrain: TerrainComposer
var hero: Sprite2D
var bell: Sprite2D
var light: PointLight2D
var water: ColorRect
var water_front: ColorRect
var slices: Array[Sprite2D] = []
var clock := 0.0
var animate := false

func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	RenderingServer.set_default_clear_color(Color("23354d"))
	var camera := Camera2D.new()
	camera.name = "FixedProductionScaleCamera"
	camera.position = Vector2(config.camera_position[0],config.camera_position[1])
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2.ONE
	add_child(camera)
	grey_background = polygon([[0,0],[1280,0],[1280,720],[0,720]],Color(config.greybox_colors.background),self)
	grey_background.name = "GreyEnvironment"
	grey_background.z_index = -30
	grey_background.light_mask = 0
	grey_structure = Node2D.new()
	grey_structure.name = "AuthoredStructure"
	grey_structure.z_index = -20
	add_child(grey_structure)
	polygon(config.roof,Color(config.greybox_colors.structure),grey_structure)
	for rect: Array in config.piers:
		polygon([[rect[0],rect[1]],[rect[0]+rect[2],rect[1]],[rect[0]+rect[2],rect[1]+rect[3]],[rect[0],rect[1]+rect[3]]],Color(config.greybox_colors.structure),grey_structure)
	for arch: Dictionary in config.arches:
		var outline: Array = [[arch.left,arch.top_left],[arch.right,arch.top_right]]
		for i: int in range(33):
			var angle := PI*float(i)/32.0
			outline.append([roundf((arch.left+arch.right)*0.5+(arch.right-arch.left)*0.5*cos(angle)),roundf(arch.baseline-arch.rise*sin(angle))])
		polygon(outline,Color(config.greybox_colors.structure),grey_structure)
	var recess: Array = config.alcove.rect
	polygon([[recess[0],recess[1]+recess[3]],[recess[0],recess[1]+38],[recess[0]+28,recess[1]],[recess[0]+recess[2]-28,recess[1]],[recess[0]+recess[2],recess[1]+38],[recess[0]+recess[2],recess[1]+recess[3]]],Color(config.greybox_colors.recess),grey_structure)
	var polygons: Array[Dictionary] = []
	polygons.assign(config.terrain_polygons)
	var groups: Array[Dictionary] = [{"material_id":config.terrain_material,"bare":false,"solids":[] as Array[Rect2],"polygons":polygons}]
	terrain = TerrainComposer.compose({"geometry":TerrainGeometry.plan([] as Array[Rect2],polygons),"groups":groups})
	terrain.name = "ProductionTerrain"
	terrain.z_index = 0
	add_child(terrain)
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UnderworldPlayer.BUILD_PATH))
	var frame := AtlasTexture.new()
	frame.atlas = load("res://assets/underworld_plains/player_animation/states_sheet.png")
	frame.region = Rect2(0,0,80,64)
	hero = Sprite2D.new()
	hero.name = "FormalHero44wu"
	hero.texture = frame
	hero.position = Vector2(config.hero_foot[0],config.hero_foot[1])
	hero.offset = Vector2(0,-26)
	hero.scale = Vector2.ONE*float(config.hero_height_wu)/float(spec.standing_body_source_height)
	hero.z_index = 10
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	hero.material = unlit
	add_child(hero)
	var components: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(config.bell.components))
	var part: Dictionary = components.components.chime
	var bell_frame := AtlasTexture.new()
	bell_frame.atlas = load(str(components.texture))
	bell_frame.region = Rect2(part.region[0],part.region[1],part.region[2],part.region[3])
	bell = Sprite2D.new()
	bell.name = "ExistingFormalBellPresentation"
	bell.texture = bell_frame
	bell.centered = false
	bell.offset = -Vector2(part.pivot[0],part.pivot[1])
	bell.scale = Vector2.ONE*float(config.bell.height)/385.0
	bell.position = Vector2(config.bell.point[0],config.bell.point[1])
	bell.z_index = -8
	bell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(bell)
	var gradient := Gradient.new()
	gradient.set_color(0,Color(1,1,1,1))
	gradient.set_color(1,Color(1,1,1,0))
	var glow := GradientTexture2D.new()
	glow.gradient = gradient
	glow.width = 256
	glow.height = 256
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(.5,.5)
	glow.fill_to = Vector2(1,.5)
	light = PointLight2D.new()
	light.name = "ActualLocalBellLight"
	light.texture = glow
	light.position = Vector2(config.light.point[0],config.light.point[1])
	light.color = Color(config.light.color)
	light.energy = float(config.light.energy)
	light.texture_scale = float(config.light.radius)/128.0
	light.range_item_cull_mask = 1
	add_child(light)
	water = ColorRect.new()
	water.name = "LiveScreenReflection"
	water.position = Vector2(0,config.water.surface_y)
	water.size = Vector2(config.viewport[0],config.viewport[1]-config.water.surface_y)
	water.z_index = -5
	var water_material := ShaderMaterial.new()
	water_material.shader = load("res://game/presentation/experiments/engine_first_2d/water.gdshader")
	water_material.set_shader_parameter("canvas_size",Vector2(config.viewport[0],config.viewport[1]))
	water_material.set_shader_parameter("surface_y",float(config.water.surface_y))
	water_material.set_shader_parameter("water_color",Color(config.water.color))
	water_material.set_shader_parameter("strength",float(config.water.reflection_strength))
	water.material = water_material
	add_child(water)
	water_front = ColorRect.new()
	water_front.name = "ForegroundWater"
	water_front.position = water.position
	water_front.size = water.size
	water_front.z_index = 5
	var front_material := water_material.duplicate() as ShaderMaterial
	front_material.set_shader_parameter("foreground",true)
	front_material.set_shader_parameter("front_start_y",float(config.water.front_start_y))
	front_material.set_shader_parameter("front_full_y",float(config.water.front_full_y))
	water_front.material = front_material
	add_child(water_front)
	if FileAccess.file_exists(NATIVE+"painting.png") and FileAccess.file_exists(NATIVE+"structure-mask.png"):
		for structure: bool in [false,true]:
			var sprite := Sprite2D.new()
			sprite.name = "LitStructureSlice" if structure else "UnlitEnvironmentSlice"
			sprite.texture = load(NATIVE+"painting.png")
			sprite.centered = false
			sprite.z_index = -20 if structure else -21
			sprite.light_mask = 1 if structure else 0
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var material := ShaderMaterial.new()
			material.shader = load("res://game/presentation/experiments/engine_first_2d/slice.gdshader")
			material.set_shader_parameter("structure_mask",load(NATIVE+"structure-mask.png"))
			material.set_shader_parameter("structure",structure)
			sprite.material = material
			add_child(sprite)
			slices.append(sprite)
		grey_background.hide()
		grey_structure.hide()
	await get_tree().process_frame
	await get_tree().process_frame
	ready_to_capture = true

func polygon(points: Array, color: Color, parent: Node) -> Polygon2D:
	var shape := Polygon2D.new()
	var vertices := PackedVector2Array()
	for point: Array in points: vertices.append(Vector2(point[0],point[1]))
	shape.polygon = vertices
	shape.color = color
	shape.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(shape)
	return shape

func _process(delta: float) -> void:
	if not animate: return
	clock += delta
	bell.rotation = sin(clock*1.7)*0.035
	(water.material as ShaderMaterial).set_shader_parameter("clock",clock)
	(water_front.material as ShaderMaterial).set_shader_parameter("clock",clock)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_L: light.enabled = not light.enabled
		KEY_W: water.visible = not water.visible; water_front.visible = water.visible
		KEY_T: terrain.visible = not terrain.visible
		KEY_SPACE: animate = not animate
