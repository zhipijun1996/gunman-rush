class_name PlainsBackground
extends CanvasLayer
## Finite painted panorama, atmospheric perspective, independent camera parallax.
## No periodic tiling: the source paintings have no approved seamless edges.
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/painterly_v2/background/sky.png"),
	preload("res://assets/painterly_v2/background/hills.png"),
	preload("res://assets/painterly_v2/background/meadow.png"),
]
const DISTANCE_SHADER: Shader = preload("res://scripts/art/distant_plains.gdshader")
const SCROLL: Array[float] = [0.06, 0.22, 0.43]
const OVERSCAN: Array[float] = [1.35, 1.55, 1.8]
@export var atmospheric_effects := true
var surface: Node2D
var panels: Array[Sprite2D] = []
var _last_transform := Transform2D()
var _last_size := Vector2.ZERO
var _origin := Vector2.ZERO
var _has_origin := false

func _ready() -> void:
	layer = -100
	process_mode = Node.PROCESS_MODE_ALWAYS
	surface = Node2D.new()
	add_child(surface)
	for index: int in TEXTURES.size():
		var panel := Sprite2D.new()
		panel.texture = TEXTURES[index]
		if atmospheric_effects:
			var shader_material := ShaderMaterial.new()
			shader_material.shader = DISTANCE_SHADER
			shader_material.set_shader_parameter("saturation", [0.08, 0.12, 0.23][index])
			shader_material.set_shader_parameter("mist", [0.30, 0.42, 0.29][index])
			shader_material.set_shader_parameter("softness", [1.8, 2.0, 1.0][index])
			panel.material = shader_material
		surface.add_child(panel)
		panels.append(panel)
	_update_panels()

func _process(_delta: float) -> void:
	var current := get_viewport().get_canvas_transform()
	var size := get_viewport().get_visible_rect().size
	if current != _last_transform or size != _last_size:
		_update_panels()

static func panel_rect(size: Vector2, offset: Vector2, index: int) -> Rect2:
	var factor := maxf(size.x / 1672.0, size.y / 941.0) * OVERSCAN[index]
	var extent := Vector2(1672, 941) * factor
	var margin := (extent - size) * 0.5
	# Monotonic finite drift instead of tiny sinusoidal oscillation. Distinct
	# layers visibly travel at different rates, then ease before panel edges.
	var desired := offset * SCROLL[index]
	var drift := Vector2(desired.x / sqrt(1.0 + pow(desired.x / maxf(1.0, margin.x), 2.0)), desired.y / sqrt(1.0 + pow(desired.y / maxf(1.0, margin.y), 2.0)))
	return Rect2(-margin - drift, extent)

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
		var rect := panel_rect(_last_size, center - _origin, index)
		panels[index].position = rect.get_center()
		panels[index].scale = rect.size / Vector2(1672, 941)
