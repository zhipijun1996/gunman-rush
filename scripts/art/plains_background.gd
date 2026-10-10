class_name PlainsBackground
extends CanvasLayer
## Sky plus two independently drifting painted pasture layers.
## Finite panorama: no claim that source atlas edges are seamless.
static var TEXTURES: Array[Texture2D] = [
	preload("res://assets/plains_v3/background_layers/sky.png"),
	_layer("hills", 280.0),
	_layer("meadow", 410.0),
]
static func _layer(id: String, top: float) -> AtlasTexture:
	var image := load("res://assets/plains_v3/background_layers/" + id + ".png") as Texture2D
	var atlas := AtlasTexture.new()
	atlas.atlas = image
	atlas.region = Rect2(0, top, image.get_width(), image.get_height() - top)
	atlas.filter_clip = true
	return atlas
const DISTANCE_SHADER: Shader = preload("res://scripts/art/distant_plains.gdshader")
const SCROLL: Array[float] = [0.03, 0.16, 0.38]
const OVERSCAN: Array[float] = [1.35, 1.65, 1.95]
@export var atmospheric_effects := true
var surface: Node2D
var panels: Array[Sprite2D] = []
var _last_transform := Transform2D()
var _last_size := Vector2.ZERO
var _origin := Vector2.ZERO
var _has_origin := false
var _materials: Array[ShaderMaterial] = []
func _ready() -> void:
	layer = -100
	process_mode = Node.PROCESS_MODE_ALWAYS
	surface = Node2D.new()
	add_child(surface)
	for index: int in TEXTURES.size():
		var panel := Sprite2D.new()
		panel.texture = TEXTURES[index]
		if atmospheric_effects:
			var material := ShaderMaterial.new()
			material.shader = DISTANCE_SHADER
			material.set_shader_parameter("saturation", [0.70, 0.50, 0.58][index])
			material.set_shader_parameter("mist", [0.18, 0.40, 0.30][index])
			material.set_shader_parameter("softness", [1.0, 1.8, 1.1][index])
			material.set_shader_parameter("mist_color", Color("aebaa4"))
			material.set_shader_parameter("ground_color", [Color("aebaa4"), Color("9ba58d"), Color("929674"), Color("717d59")][index])
			panel.material = material
			_materials.append(material)
		surface.add_child(panel)
		panels.append(panel)
	_update_panels()
func _process(_delta: float) -> void:
	var current := get_viewport().get_canvas_transform()
	var size := get_viewport().get_visible_rect().size
	if current != _last_transform or size != _last_size:
		_update_panels()
static func panel_rect(size: Vector2, offset: Vector2, index: int) -> Rect2:
	var source_size := (TEXTURES[index] as AtlasTexture).atlas.get_size() if TEXTURES[index] is AtlasTexture else TEXTURES[index].get_size()
	var factor := maxf(size.x / source_size.x, size.y / source_size.y) * OVERSCAN[index]
	var extent := source_size * factor
	var margin := (extent - size) * 0.5
	var desired := offset * SCROLL[index]
	var drift := Vector2(desired.x / sqrt(1.0 + pow(desired.x / maxf(1.0, margin.x), 2.0)), desired.y / sqrt(1.0 + pow(desired.y / maxf(1.0, margin.y), 2.0)))
	return Rect2(-margin - drift, extent)
static func landscape_rect(size: Vector2, offset: Vector2, index: int) -> Rect2:
	var coverage := panel_rect(size, offset, index)
	# Pin silhouettes to screen horizon, rather than centering alpha-heavy source
	# canvases: high world cameras retain recognizable meadow/ruin layers.
	var height: float = size.y * [1.0, 0.63, 0.54][index]
	var bottom: float = size.y * [1.0, 0.90, 1.34][index]
	var vertical_drift := clampf(offset.y * SCROLL[index] * 0.10, -size.y * 0.035, size.y * 0.035)
	return Rect2(Vector2(coverage.position.x, bottom - height - vertical_drift), Vector2(coverage.size.x, height))
func _update_panels() -> void:
	_last_transform = get_viewport().get_canvas_transform()
	_last_size = get_viewport().get_visible_rect().size
	if _last_size.x <= 0.0 or _last_size.y <= 0.0:
		return
	var center := _last_transform.affine_inverse() * (_last_size / 2.0)
	if not _has_origin:
		_origin = center
		_has_origin = true
	for index: int in panels.size():
		var rect := panel_rect(_last_size, center - _origin, index) if index == 0 else landscape_rect(_last_size, center - _origin, index)
		panels[index].position = rect.get_center()
		if index > 0 and atmospheric_effects:
			var content_height := rect.size.y
			rect.size.y = maxf(content_height, _last_size.y * 1.42 - rect.position.y)
			var atlas := TEXTURES[index] as AtlasTexture
			var region := atlas.region
			var atlas_size := atlas.atlas.get_size()
			_materials[index].set_shader_parameter("texture_region", Vector4(region.position.x / atlas_size.x, region.position.y / atlas_size.y, region.size.x / atlas_size.x, region.size.y / atlas_size.y))
			_materials[index].set_shader_parameter("content_fraction", content_height / rect.size.y)
			_materials[index].set_shader_parameter("bottom_fade", 0.12)
			panels[index].position = rect.get_center()
		panels[index].scale = rect.size / TEXTURES[index].get_size()
