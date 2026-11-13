extends Node2D
## Static composition trial: independently replaceable environment, architecture,
## production terrain and hero. No generated full scene is loaded at runtime.
const ASSETS := "res://assets/art_rule_trial/native/"
var ready_to_capture := false
var config: Dictionary
var terrain: TerrainComposer
var architecture: Sprite2D
var environment: Sprite2D
var hero: Sprite2D
var water: ColorRect
var grayscale: CanvasLayer

func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://config/art/aqueduct_trial.json"))
	RenderingServer.set_default_clear_color(Color("101c30"))
	environment = layer("DistantOrchard", config.environment)
	architecture = layer("ContinuousAqueduct", config.architecture)
	var polygons: Array[Dictionary] = []
	polygons.assign(config.terrain_polygons)
	var groups: Array[Dictionary] = [{"material_id":config.material_id,"bare":false,"solids":[] as Array[Rect2],"polygons":polygons}]
	terrain = TerrainComposer.compose({"geometry":TerrainGeometry.plan([] as Array[Rect2],polygons),"groups":groups})
	terrain.name = "ProductionTerrain"
	terrain.z_index = 0
	add_child(terrain)
	# Reflection is derived from the separate architecture texture, then masked
	# naturally by the actual bank silhouettes drawn in front.
	water = ColorRect.new()
	water.name = "ChannelReflection"
	water.position = Vector2(0,config.water.surface_y)
	water.size = Vector2(config.viewport[0],config.viewport[1]-config.water.surface_y)
	water.z_index = -5
	var reflection := ShaderMaterial.new()
	reflection.shader = load("res://game/presentation/experiments/depth_lab/aqueduct_water.gdshader")
	reflection.set_shader_parameter("architecture", architecture.texture)
	reflection.set_shader_parameter("architecture_offset", architecture.position)
	reflection.set_shader_parameter("canvas_size",Vector2(config.viewport[0],config.viewport[1]))
	reflection.set_shader_parameter("surface_y",float(config.water.surface_y))
	reflection.set_shader_parameter("water_color",Color(config.water.color))
	reflection.set_shader_parameter("strength",float(config.water.reflection_strength))
	water.material = reflection
	add_child(water)
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UnderworldPlayer.BUILD_PATH))
	var frame := AtlasTexture.new()
	frame.atlas = load("res://assets/underworld_plains/player_animation/states_sheet.png")
	frame.region = Rect2(0,0,80,64)
	hero = Sprite2D.new()
	hero.name = "FormalHeroIdle"
	hero.texture = frame
	hero.position = Vector2(config.hero_foot[0],config.hero_foot[1])
	hero.offset = Vector2(0,-26)
	hero.scale = Vector2.ONE * float(config.hero_height_wu)/float(spec.standing_body_source_height)
	hero.z_index = 5
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(hero)
	grayscale = CanvasLayer.new()
	grayscale.name = "GrayscaleInspection"
	grayscale.layer = 10
	var overlay := ColorRect.new()
	overlay.size = Vector2(config.viewport[0],config.viewport[1])
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inspect_material := ShaderMaterial.new()
	inspect_material.shader = load("res://game/presentation/experiments/depth_lab/aqueduct_grayscale.gdshader")
	overlay.material = inspect_material
	grayscale.add_child(overlay)
	add_child(grayscale)
	grayscale.hide()
	await get_tree().process_frame
	await get_tree().process_frame
	ready_to_capture = true

func layer(label: String, definition: Dictionary) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = label
	sprite.texture = load(ASSETS+str(definition.asset))
	sprite.centered = false
	sprite.position = Vector2(definition.position[0],definition.position[1])
	sprite.z_index = int(definition.z)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	return sprite

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_A: architecture.visible = not architecture.visible; water.visible = architecture.visible
		KEY_T: terrain.visible = not terrain.visible
		KEY_E: environment.visible = not environment.visible
		KEY_G: grayscale.visible = not grayscale.visible
